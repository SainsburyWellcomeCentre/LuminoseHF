% calibrate_stage_camera  How a Zaber X/Y move shifts the camera image, for
%   automatic alignment to an animal's reference (Pattern Designer, Align to
%   reference; lhf.cam.align).
%
%   Captures a frame, moves X by +d and -d and Y by +d and -d from the start
%   (d = STEP_UM), captures after each move, measures each image shift on the
%   whole image (lhf.cam.register) and fits the 2x2 matrix C, camera px per um
%   (lhf.cam.fitStageCamera: the stage-camera rotation, each axis's direction
%   and the scale). Returns to the start.
%
%   Before running: a sample with texture (tissue, or a slide with features)
%   in focus and lit (the DMD all on and the laser low, or the room light),
%   and zaber.axes set in luminose_config.yaml. Rerun whenever the camera or the
%   stage is moved or remounted.
%
%   Output: luminoseData/calibration/stage_camera_<stamp>.mat (variable
%   stageCamera, read by lhf.cam.loadStageCalibration; the newest is used).

luminose = LuminoseConstants();

STEP_UM = 100;

cam = rigCamera(luminose);
stages = rigStages(luminose);
closer = onCleanup(@() releaseDevices(stages, cam));

startUm = [stages.x.positionUm(), stages.y.positionUm()];
stages.x.LimitsUm = startUm(1) + [-1 1] * (STEP_UM + 10);
stages.y.LimitsUm = startUm(2) + [-1 1] * (STEP_UM + 10);
fprintf('Start: X %.1f um, Y %.1f um\n', startUm);

reference = cam.capture();
moves = [STEP_UM 0; -STEP_UM 0; 0 STEP_UM; 0 -STEP_UM];
shifts = nan(size(moves));
for k = 1:size(moves, 1)
    stages.x.moveAbsolute(startUm(1) + moves(k, 1));
    stages.y.moveAbsolute(startUm(2) + moves(k, 2));
    r = lhf.cam.register(reference, cam.capture(), 'Downsample', 2);
    if ~r.ok
        warning('calibrate_stage_camera:weak', 'Move %d: registration peak %.3f is low.', k, r.peak);
    end
    shifts(k, :) = r.shiftPx;
    fprintf('  move [%5.0f %5.0f] um -> shift [%7.2f %7.2f] px (peak %.2f, rotation %.2f deg)\n', ...
        moves(k, :), r.shiftPx, r.peak, r.rotationDeg);
end
stages.x.moveAbsolute(startUm(1));
stages.y.moveAbsolute(startUm(2));

stageCamera = lhf.cam.fitStageCamera(moves, shifts);
fprintf('Camera px per um: %.4f (camera.effectivePixelSize_um implies %.4f)\n', ...
    stageCamera.pxPerUm, 1 / luminose.camera.effectivePixelSize_um);
fprintf('Stage X on the camera: %.2f deg; mirrored: %d\n', stageCamera.rotationDeg, det(stageCamera.C) < 0);
fprintf('Residual: rms %.2f px\n', stageCamera.rmsPx);
if abs(stageCamera.pxPerUm * luminose.camera.effectivePixelSize_um - 1) > 0.1
    warning('calibrate_stage_camera:scale', ['The scale is more than 10%% from the camera''s pixel ' ...
        'size: check the registrations above.']);
end

stageCamera.timestamp = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<TNOW1,DATST>
stageCamera.startUm = startUm;
outDir = fullfile(char(luminose.f.luminoseData), 'calibration');
if ~isfolder(outDir), mkdir(outDir); end
matPath = fullfile(outDir, ['stage_camera_' stageCamera.timestamp '.mat']);
save(matPath, 'stageCamera');
fprintf('Saved %s\n', matPath);
clear closer  % releases the stages and the camera (a script's onCleanup only fires when cleared)

function releaseDevices(stages, cam)
    try stages.close(); catch, end
    try cam.disconnect(); catch, end
end

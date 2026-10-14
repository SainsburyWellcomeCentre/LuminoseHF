function [data, messages] = stageCamera(d, s, hooks, luminose)
% lhf.cal.stageCamera  How an X/Y stage move shifts the camera image.
%
%   [data, messages] = lhf.cal.stageCamera(devices, settings, hooks, luminose)
%
%   Run it through lhf.cal.run('stageCamera', ...) or the Calibration window.
%   Captures a reference, moves X by +/- stepUm and Y by +/- stepUm from the start,
%   registers each frame on the reference (lhf.cam.register, the whole image) and fits
%   C, camera px per um (lhf.cam.fitStageCamera). X and Y are kept within the moves
%   (their LimitsUm, put back afterwards) and return to the start however it ends.
%
%   data: stageCamera (lhf.cam.fitStageCamera plus startUm), moves, shifts (camera
%   px), peaks, reference (the first frame). messages: weak registrations, a scale
%   far from the camera's pixel size.
%
% See also lhf.cal.run, lhf.cam.loadStageCalibration, lhf.cam.align

    cam = d.camera;
    stages = d.stage;
    messages = {};
    startUm = [stages.x.positionUm(), stages.y.positionUm()];
    limits = {stages.x.LimitsUm, stages.y.LimitsUm};
    closer = onCleanup(@() backToStart(stages, startUm, limits));
    stages.x.LimitsUm = startUm(1) + [-1 1] * (s.stepUm + 10);
    stages.y.LimitsUm = startUm(2) + [-1 1] * (s.stepUm + 10);

    step(hooks, 0, sprintf('Reference at X %.1f, Y %.1f um', startUm));
    reference = cam.capture();
    hooks.frame(reference);
    moves = [s.stepUm 0; -s.stepUm 0; 0 s.stepUm; 0 -s.stepUm];
    shifts = nan(size(moves));
    peaks = nan(size(moves, 1), 1);
    for k = 1:size(moves, 1)
        step(hooks, k / 5, sprintf('Move %d of 4: X %+.0f, Y %+.0f um', k, moves(k, :)));
        stages.x.moveAbsolute(startUm(1) + moves(k, 1));
        stages.y.moveAbsolute(startUm(2) + moves(k, 2));
        pause(s.settleS);
        frame = cam.capture();
        hooks.frame(frame);
        r = lhf.cam.register(reference, frame, 'Downsample', s.downsample);
        if ~r.ok
            messages{end + 1} = sprintf('Move %d: registration peak %.3f is low.', k, r.peak); %#ok<AGROW>
        end
        shifts(k, :) = r.shiftPx;
        peaks(k) = r.peak;
    end
    clear closer  % back to the start, limits put back

    cal = lhf.cam.fitStageCamera(moves, shifts);
    cal.startUm = startUm;
    try
        if abs(cal.pxPerUm * luminose.camera.effectivePixelSize_um - 1) > 0.1
            messages{end + 1} = sprintf(['%.4f px/um is more than 10%% from the camera''s pixel ' ...
                'size (%.4f): check the registrations.'], cal.pxPerUm, 1 / luminose.camera.effectivePixelSize_um);
        end
    catch
    end
    step(hooks, 1, sprintf('%.4f camera px per um, X at %.1f deg, rms %.2f px', ...
        cal.pxPerUm, cal.rotationDeg, cal.rmsPx));
    data = struct('stageCamera', cal, 'moves', moves, 'shifts', shifts, 'peaks', peaks, ...
        'reference', reference);
end


function backToStart(stages, startUm, limits)
    try stages.x.moveAbsolute(startUm(1)); catch, end
    try stages.y.moveAbsolute(startUm(2)); catch, end
    try stages.x.LimitsUm = limits{1}; catch, end
    try stages.y.LimitsUm = limits{2}; catch, end
end

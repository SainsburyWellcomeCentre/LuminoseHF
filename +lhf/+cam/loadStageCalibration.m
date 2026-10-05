function cal = loadStageCalibration(calibrationFolder)
% lhf.cam.loadStageCalibration  The newest stage-camera calibration, or [] if none.
%
%   cal = lhf.cam.loadStageCalibration(fullfile(luminose.f.luminoseData, 'calibration'))
%
%   Reads the newest stage_camera_<yyyymmdd_HHMMSS>.mat that
%   calibration/calibrate_stage_camera.m saved (variable stageCamera, an
%   lhf.cam.fitStageCamera with timestamp added) and adds cal.file.

    cal = [];
    files = dir(fullfile(char(calibrationFolder), 'stage_camera_*.mat'));
    if isempty(files), return; end
    names = sort({files.name});
    file = fullfile(char(calibrationFolder), names{end});
    m = load(file, 'stageCamera');
    cal = m.stageCamera;
    cal.file = file;
end

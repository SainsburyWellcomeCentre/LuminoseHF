function reg = loadRegistration(calibrationFolder)
% lhf.cam.loadRegistration  The newest camera-DMD calibration, or [] if none.
%
%   reg = lhf.cam.loadRegistration(fullfile(luminose.f.luminoseData, 'calibration'))
%
%   Reads the newest camera_dmd_<yyyymmdd_HHMMSS>.mat that
%   calibration/calibrate_camera_dmd.m saved (variable registration, an
%   lhf.cam.fitRegistration with timestamp, camSize and exposureMs added) and
%   adds reg.file. The timestamp in the name orders them, not the file date.

    reg = [];
    files = dir(fullfile(char(calibrationFolder), 'camera_dmd_*.mat'));
    if isempty(files), return; end
    names = sort({files.name});
    file = fullfile(char(calibrationFolder), names{end});
    m = load(file, 'registration');
    reg = m.registration;
    reg.file = file;
end

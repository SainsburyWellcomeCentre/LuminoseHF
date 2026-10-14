function reg = loadRegistration(calibrationFolder)
% lhf.cam.loadRegistration  The newest camera-DMD calibration, or [] if none.
%
%   reg = lhf.cam.loadRegistration(fullfile(luminose.f.luminoseData, 'calibration'))
%
%   Reads the newest camera_dmd_<yyyymmdd_HHMMSS>.mat that
%   calibration/calibrate_camera_dmd.m saved (variable registration, an
%   lhf.cam.fitRegistration with timestamp, camSize and exposureMs added) and
%   adds reg.file. The timestamp in the name orders them, not the file date.
%   reg maps DMD pixels to full-sensor, unbinned camera pixels (reg.space
%   'sensor'; hamacam.Camera.sensorToFrame gives the frame shown); a file from
%   before that was recorded gets space 'sensor' and a note (it was full frame,
%   binning 1).

    reg = [];
    files = dir(fullfile(char(calibrationFolder), 'camera_dmd_*.mat'));
    if isempty(files), return; end
    names = sort({files.name});
    file = fullfile(char(calibrationFolder), names{end});
    m = load(file, 'registration');
    reg = m.registration;
    reg.file = file;
    if ~isfield(reg, 'space')
        % Before 2026-10-06 the points were frame pixels of a full-sensor, unbinned
        % frame, which are sensor pixels: the same map
        reg.space = 'sensor';
        reg.note = 'calibrated before sensor coordinates were recorded: full frame, binning 1 assumed';
    end
end

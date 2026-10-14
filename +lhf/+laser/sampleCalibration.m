function cal = sampleCalibration(luminose)
% lhf.laser.sampleCalibration  The laser's setpoint against its power at the sample, or [].
%
%   cal = lhf.laser.sampleCalibration()           from the session's or the rig's config
%   cal = lhf.laser.sampleCalibration(luminose)
%
%   An obis.Calibration read from dmd/power_calibration.csv (columns power_setting_mW,
%   power_at_sample_mW), measured out of the objective with every DMD mirror on, so a
%   pattern lighting part of the field puts less on the sample. [] when there is none or it
%   cannot be read. The Laser panel shows it (lhf.devicePanel) and the camera's file names
%   carry it (lhf.laser.powerTag).
%
% See also lhf.laser.powerTag, lhf.devicePanel, obis.Calibration

    cal = [];
    try
        if nargin < 1 || isempty(luminose)
            luminose = configNow();
        end
        cal = obis.Calibration.fromCsv(fullfile(char(luminose.f.luminose_hf), 'dmd', ...
            'power_calibration.csv'));
    catch
    end
end


function config = configNow()
% The protocols' luminose global while a session runs, else the rig's config.
    global luminose %#ok<GVMIS> the protocols' global
    config = luminose;
    if isempty(config)
        config = LuminoseConstants();
    end
end

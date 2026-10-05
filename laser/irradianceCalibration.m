function [irradiance_mWmm2, setpoint_mW] = irradianceCalibration(luminose)
% irradianceCalibration  The power calibration as irradiance at the sample per OBIS setpoint.
%
%   [irradiance_mWmm2, setpoint_mW] = irradianceCalibration(luminose)
%
%   From dmd/power_calibration.csv (power_setting_mW vs power_at_sample_mW;
%   rows with no power at the sample dropped). Irradiance is power at the
%   sample divided by the full projected DMD field area, scaled by
%   luminose.laser.spotGain (see irradianceToSetpoint_mW). Its min and max
%   are the range a pattern's irradiances must lie in (the Pattern Designer
%   shows it).

    % V-7002 DMD is 1024x768; calibrate_power.m uses info.height/info.width
    DMD_ASPECT = 768 / 1024;

    calCsvPath = fullfile(char(luminose.f.luminose_hf), 'dmd', 'power_calibration.csv');
    T = readtable(calCsvPath);
    T = T(T.power_at_sample_mW > 0, :);

    areaAtSample_mm2 = luminose.dmd.projectedDMDlength^2 * DMD_ASPECT;
    spotGain = 1;
    try  % luminose is a LuminoseConstants object (isfield is false on objects) or a struct
        if isfield(luminose.laser, 'spotGain') && ~isempty(luminose.laser.spotGain)
            spotGain = luminose.laser.spotGain;
        end
    catch
    end
    calIrradiance = T.power_at_sample_mW / areaAtSample_mm2 * spotGain;
    irradiance_mWmm2 = calIrradiance;
    setpoint_mW = T.power_setting_mW;
end

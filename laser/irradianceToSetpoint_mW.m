function setpoint_mW = irradianceToSetpoint_mW(irradiance_mWmm2, luminose)
% irradianceToSetpoint_mW  Convert irradiance at the sample to an OBIS power setpoint.
%
%   setpoint_mW = irradianceToSetpoint_mW(irradiance_mWmm2, luminose)
%
%   Interpolates dmd/power_calibration.csv (power_setting_mW vs
%   power_at_sample_mW). Irradiance is power at sample divided by the full
%   projected DMD field area, as in calibration/calibrate_power.m, so it
%   assumes the calibration's full-field illumination is uniform. The DMD is
%   not lit evenly, so that is scaled by luminose.laser.spotGain (measured
%   spot irradiance / full-field irradiance at one setpoint; 1 when unset),
%   making the irradiance the one in the measured spot.
%   Errors if any value lies outside the calibrated range.

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

    lo = min(calIrradiance);
    hi = max(calIrradiance);
    outOfRange = irradiance_mWmm2 < lo | irradiance_mWmm2 > hi;
    if any(outOfRange)
        error('irradianceToSetpoint_mW:OutOfRange', ...
            'Irradiance %s mW/mm^2 outside calibrated range [%.2f, %.2f] mW/mm^2.', ...
            mat2str(irradiance_mWmm2(outOfRange)), lo, hi);
    end

    setpoint_mW = interp1(calIrradiance, T.power_setting_mW, irradiance_mWmm2, 'linear');
end

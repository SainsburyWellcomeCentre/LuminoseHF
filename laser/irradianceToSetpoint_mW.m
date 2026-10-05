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

    [calIrradiance, calSetpoint] = irradianceCalibration(luminose);

    lo = min(calIrradiance);
    hi = max(calIrradiance);
    outOfRange = irradiance_mWmm2 < lo | irradiance_mWmm2 > hi;
    if any(outOfRange)
        error('irradianceToSetpoint_mW:OutOfRange', ...
            'Irradiance %s mW/mm^2 outside calibrated range [%.2f, %.2f] mW/mm^2.', ...
            mat2str(irradiance_mWmm2(outOfRange)), lo, hi);
    end

    setpoint_mW = interp1(calIrradiance, calSetpoint, irradiance_mWmm2, 'linear');
end

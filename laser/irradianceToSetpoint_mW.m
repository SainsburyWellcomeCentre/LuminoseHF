function setpoint_mW = irradianceToSetpoint_mW(irradiance_mWmm2, luminose)
% irradianceToSetpoint_mW  Convert irradiance at the sample to an OBIS power setpoint.
%
%   setpoint_mW = irradianceToSetpoint_mW(irradiance_mWmm2, luminose)
%
%   Interpolates dmd/power_calibration.csv (power_setting_mW vs
%   power_at_sample_mW) through obis.Calibration. Irradiance is power at sample
%   divided by the full projected DMD field area, as in
%   calibration/calibrate_power.m, so it assumes the calibration's full-field
%   illumination is uniform. The DMD is not lit evenly, so that is scaled by
%   luminose.laser.spotGain (measured spot irradiance / full-field irradiance at
%   one setpoint; 1 when unset), making the irradiance the one in the measured
%   spot. Errors (obis:Calibration:outOfRange) if any value lies outside the
%   calibrated range.

    [~, ~, cal] = irradianceCalibration(luminose);
    setpoint_mW = cal.setpointFor(irradiance_mWmm2);
end

function mW = setpoint(irradiance_mWmm2, luminose)
% lhf.laser.setpoint  The OBIS setpoint (mW) for an irradiance at the sample, cached.
%
%   mW = lhf.laser.setpoint(irradiance_mWmm2, luminose)
%   lhf.laser.setpoint('reset')     forget the cache (lhf.laser.open does)
%
%   irradianceToSetpoint_mW reads dmd/power_calibration.csv on every call;
%   each irradiance is converted once per session and remembered, so
%   preparing a trial reads no file. Errors outside the calibrated range.

    persistent cache

    if ischar(irradiance_mWmm2) && strcmp(irradiance_mWmm2, 'reset')
        cache = [];
        return
    end
    if isempty(cache)
        cache = containers.Map('KeyType', 'double', 'ValueType', 'double');
    end
    if ~isKey(cache, irradiance_mWmm2)
        cache(irradiance_mWmm2) = irradianceToSetpoint_mW(irradiance_mWmm2, luminose);
    end
    mW = cache(irradiance_mWmm2);
end

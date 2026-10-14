% read_powermeter  Reads the Thorlabs PM100D once and prints the power (lhf.cal.powerMeter).
%
%   For a quick reading by hand. The Calibration window's Laser power calibration reads
%   the meter at every setpoint itself (Meter PM100D). Set WAVELENGTH_NM to change the
%   meter's correction (0 leaves it), and run again after each change at the laser.
%
% See also lhf.cal.powerMeter, lhf.cal.power

WAVELENGTH_NM = 0;   % e.g. 488 to set the meter's correction; 0 leaves it as it is
N_SAMPLES = 20;      % readings averaged

meter = lhf.cal.powerMeter(WAVELENGTH_NM);
closer = onCleanup(@() meter.close());
fprintf('%s, correction at %g nm\n', meter.idn, meter.wavelengthNm);
[p_mW, sd_mW] = meter.read(N_SAMPLES);
fprintf('Power: %.4f mW (sd %.4f, n = %d)\n', p_mW, sd_mW, N_SAMPLES);
clear closer

% read_powermeter.m  Read the Thorlabs PM100D over USB (VISA/SCPI) and print the power.
%
% USAGE
%   1. Project the spot onto the sensor and set the laser.
%   2. Run this script. It prints the meter's wavelength setting, then the
%      mean and spread of N_SAMPLES readings in mW.
%   3. Run it again (or just the READ section) after changing the laser.
%
% REQUIREMENTS
%   Instrument Control Toolbox and a VISA (NI-VISA, installed with the
%   Thorlabs software). The PM100D must be in its USBTMC/VISA mode; if
%   visadevlist shows nothing, switch it with Thorlabs' "Power Meter Driver
%   Switcher" (PM100D -> PM100D (NI-VISA)). Close Thorlabs Optical Power
%   Monitor first: only one program can hold the meter.

%% -------------------------------------------------------------------------
%  CONFIGURATION
%% -------------------------------------------------------------------------
WAVELENGTH_NM = [];     % set e.g. 473 to change the meter's correction; [] leaves it as is
N_SAMPLES     = 20;     % readings averaged
BACKGROUND_mW = 0;      % subtract a reading taken with the DMD all off (laser on), if measured

%% -------------------------------------------------------------------------
%  Connect
%% -------------------------------------------------------------------------
if ~exist('pm', 'var') || ~isvalid(pm)
    devices = visadevlist;
    isPM = contains(devices.ResourceName, '0x1313') & ...                      % Thorlabs vendor ID
           (contains(devices.Model, 'PM100', 'IgnoreCase', true) | contains(devices.ResourceName, '0x8078'));
    if ~any(isPM)
        disp(devices);
        error('read_powermeter: no PM100D found in visadevlist (see REQUIREMENTS).');
    end
    pm = visadev(devices.ResourceName(find(isPM, 1)));
    pm.Timeout = 5;
    fprintf('Connected: %s\n', strtrim(writeread(pm, '*IDN?')));
end

if ~isempty(WAVELENGTH_NM)
    writeline(pm, sprintf('SENS:CORR:WAV %g', WAVELENGTH_NM));
end
fprintf('Meter wavelength: %g nm\n', str2double(writeread(pm, 'SENS:CORR:WAV?')));
writeline(pm, 'CONF:POW');
writeline(pm, 'SENS:POW:UNIT W');

%% -------------------------------------------------------------------------
%  READ — run this section again after each laser change
%% -------------------------------------------------------------------------
p_mW = zeros(1, N_SAMPLES);
for k = 1:N_SAMPLES
    p_mW(k) = str2double(writeread(pm, 'MEAS:POW?')) * 1000;   % W -> mW
end
p_mW = p_mW - BACKGROUND_mW;
spotArea_mm2 = (57 * 2.2046 / 1024)^2;   % powercal's 57x57-mirror spot (r_px = 28)
fprintf('Power: %.4f mW  (sd %.4f, min %.4f, max %.4f, n=%d)\n', ...
    mean(p_mW), std(p_mW), min(p_mW), max(p_mW), N_SAMPLES);
fprintf('Irradiance in the spot (%.5f mm^2): %.2f mW/mm^2\n', spotArea_mm2, mean(p_mW) / spotArea_mm2);

%% -------------------------------------------------------------------------
%  CLEANUP
%% -------------------------------------------------------------------------
% clear pm

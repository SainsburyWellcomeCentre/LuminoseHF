function meter = powerMeter(wavelengthNm)
% lhf.cal.powerMeter  The Thorlabs PM100D over USB (VISA/SCPI), for the power calibration.
%
%   meter = lhf.cal.powerMeter()               the wavelength correction as it is
%   meter = lhf.cal.powerMeter(wavelengthNm)   sets it first (0 or [] leaves it)
%
%   meter.read(n)        [mean, sd] power in mW of n readings
%   meter.wavelengthNm   the meter's correction wavelength
%   meter.idn            its *IDN? answer
%   meter.close()        releases it
%
%   Needs the Instrument Control Toolbox and a VISA (NI-VISA, with the Thorlabs
%   software), and the PM100D in its USBTMC/VISA mode: if visadevlist shows nothing,
%   switch it with Thorlabs' Power Meter Driver Switcher (PM100D -> PM100D (NI-VISA)).
%   Close Thorlabs Optical Power Monitor first: one program at a time holds the meter.
%
% See also lhf.cal.power, calibration/read_powermeter.m

    if nargin < 1, wavelengthNm = []; end
    devices = visadevlist;
    isPM = contains(devices.ResourceName, '0x1313') & ...   % Thorlabs' vendor ID
        (contains(devices.Model, 'PM100', 'IgnoreCase', true) | contains(devices.ResourceName, '0x8078'));
    if ~any(isPM)
        error('lhf:cal:noPowerMeter', ['No PM100D in visadevlist: is it plugged in, in NI-VISA ' ...
            'mode (Power Meter Driver Switcher), and Optical Power Monitor closed?']);
    end
    pm = visadev(devices.ResourceName(find(isPM, 1)));
    pm.Timeout = 5;
    if ~isempty(wavelengthNm) && wavelengthNm > 0
        writeline(pm, sprintf('SENS:CORR:WAV %g', wavelengthNm));
    end
    writeline(pm, 'CONF:POW');
    writeline(pm, 'SENS:POW:UNIT W');
    meter = struct('idn', strtrim(char(writeread(pm, '*IDN?'))), ...
        'wavelengthNm', str2double(writeread(pm, 'SENS:CORR:WAV?')), ...
        'read', @(n) readPower(pm, n), 'close', @() delete(pm));
end


function [m, sd] = readPower(pm, n)
    p = zeros(1, n);
    for k = 1:n
        p(k) = str2double(writeread(pm, 'MEAS:POW?')) * 1000;   % W -> mW
    end
    m = mean(p);
    sd = std(p);
end

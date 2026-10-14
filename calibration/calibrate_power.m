% calibrate_power  Laser setpoint against power at the sample (Laser power), with the settings it last ran with in the Calibration window, else the defaults.
%
%   The Calibration window (the parameter GUI's Calibrate button, gui/CalibrationApp)
%   runs it with every setting editable, Stop, and Save only once checked. This script
%   runs it from the command line and saves it at once (lhf.cal.run): change a setting
%   with lhf.cal.run('power', luminose, struct('name', value)). See lhf.cal.catalog for
%   what it does, what to set up first and every setting.
%
% See also lhf.cal.run, lhf.cal.catalog, gui/CalibrationApp

luminose = LuminoseConstants();
values = struct();
if ispref('LuminoseHF', 'calibration_power')
    values = getpref('LuminoseHF', 'calibration_power');  % what the window last ran
end
result = lhf.cal.run('power', luminose, values);
fprintf('%s\n', result.messages{:});
fprintf('Saved %s\n', result.files{:});
figure('Name', result.title, 'NumberTitle', 'off', 'Position', [100 100 1000 440]);
lhf.cal.plot(result, gcf);

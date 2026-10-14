function tag = powerTag(laser, cal, pulser)
% lhf.laser.powerTag  The laser's power at the sample as text for a file name.
%
%   tag = lhf.laser.powerTag()                     the rig's shared laser (lhf.device)
%   tag = lhf.laser.powerTag(laser, cal, pulser)   cal: an obis.Calibration or []; pulser:
%                                                  an obis.Pulser or []
%
%   'sample5.1mW' (the setpoint through the power calibration, lhf.laser.sampleCalibration);
%   'setpoint170mW' when the setpoint is outside the calibration or there is none; with
%   '_10Hz20pct' added while the Laser panel pulses; 'laserOff' with emission off; '' when
%   there is no connected laser (nothing is known, so nothing is claimed). The Camera panel
%   adds it to each frame it saves (hamacam's NameTagFcn, set by lhf.devicePanel). It reads
%   what the laser last accepted and sends nothing, so it never interrupts a command.
%   The calibration was measured with every DMD mirror on: a pattern lighting part of the
%   field puts less on the sample.
%
% See also lhf.laser.sampleCalibration, lhf.devicePanel, hamacam.gui.CameraApp

    if nargin == 0
        [laser, cal, pulser] = shared();
    end
    tag = '';
    if isempty(laser) || ~isvalid(laser) || ~strcmp(laser.State, 'Ready')
        return
    end
    pulsing = ~isempty(pulser) && isvalid(pulser) && pulser.Running;
    if ~laser.IsEnabled && ~pulsing
        tag = 'laserOff';
        return
    end
    setpoint = laser.CommandedPowermW;
    if isempty(setpoint)
        return
    end
    try
        tag = sprintf('sample%smW', number(cal.powerFor(setpoint)));
    catch  % no calibration, or the setpoint outside it
        tag = sprintf('setpoint%smW', number(setpoint));
    end
    if pulsing
        tag = sprintf('%s_%sHz%spct', tag, number(pulser.FrequencyHz), number(pulser.DutyPercent));
    end
end


function [laser, cal, pulser] = shared()
% The rig's laser, if one was made (never makes one), the calibration the Laser panel
% shows (else the rig's), and the panel's pulser.
    laser = [];
    cal = [];
    pulser = [];
    if isappdata(0, 'lhfDevices')
        devices = getappdata(0, 'lhfDevices');
        if isfield(devices, 'laser')
            laser = devices.laser;
        end
    end
    if isempty(laser)
        return
    end
    panel = [];
    if isappdata(0, 'lhfDevicePanels')
        panels = getappdata(0, 'lhfDevicePanels');
        if isfield(panels, 'laser') && isvalid(panels.laser)
            panel = panels.laser;
        end
    end
    if ~isempty(panel) && isprop(panel, 'Pulser')
        pulser = panel.Pulser;
        cal = panel.Calibration;
    end
    if isempty(cal)
        cal = lhf.laser.sampleCalibration();
    end
end


function s = number(x)
% Three significant figures, no exponent: 5.1, 53.2, 0.512.
    s = sprintf('%.3g', x);
    if contains(s, 'e')
        s = sprintf('%.0f', x);
    end
end

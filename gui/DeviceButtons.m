function buttons = DeviceButtons(parent, position, colors)
% DeviceButtons  A row of buttons opening each device's own panel (lhf.devicePanel).
%
%   buttons = DeviceButtons(parent, position, colors)
%
%   parent    the parameter GUI's tab (or any figure or panel)
%   position  [x y width height] of the row, pixels
%   colors    the parameter GUI's COLORS (panelBg, textDark); optional
%
%   Camera, Stage, Laser and DMD, each opening (or bringing to the front) the device
%   package's panel: hamacam.app, zaberstage.app, obis.app, DMDController.app; and
%   Calibrate, the rig's calibrations on those devices (gui/CalibrationApp). An error
%   (a device that will not open, the DMD during a session) is shown in a dialog.
    if nargin < 3 || isempty(colors)
        colors = struct('panelBg', [0.94 0.94 0.94], 'textDark', [0 0 0]);
    end
    names = {'camera', 'stage', 'laser', 'dmd', 'calibration'};
    labels = {'Camera', 'Stage', 'Laser', 'DMD', 'Calibrate'};
    tips = {'The Hamamatsu camera''s panel (hamacam.app)', ...
        'The Zaber stage''s panel, X, Y and Z (zaberstage.app)', ...
        'The OBIS laser''s panel (obis.app)', 'The DMD''s panel (DMDController.app)', ...
        'Calibrate the camera-DMD map, stage-camera, Z focus and laser power (CalibrationApp)'};
    gap = 6;
    width = (position(3) - gap * (numel(names) - 1)) / numel(names);
    buttons = gobjects(1, numel(names));
    for k = 1:numel(names)
        buttons(k) = uicontrol(parent, 'Style', 'pushbutton', 'String', labels{k}, ...
            'Position', [position(1) + (k - 1) * (width + gap), position(2), width, ...
            position(4)], 'FontSize', 11, 'FontWeight', 'bold', 'TooltipString', tips{k}, ...
            'BackgroundColor', colors.panelBg, 'ForegroundColor', colors.textDark, ...
            'Callback', @(~, ~) open(names{k}, labels{k}));
    end
end


function open(name, label)
% Opens the panel; an error goes in a dialog, not out of the callback.
    try
        lhf.devicePanel(name);
    catch err
        errordlg(err.message, sprintf('%s panel', label));
    end
end

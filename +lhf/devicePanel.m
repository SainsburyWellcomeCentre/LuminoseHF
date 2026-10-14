function app = devicePanel(name, openers)
% devicePanel  Opens a device's own control panel, or brings it to the front if open.
%
%   app = lhf.devicePanel(name)            name: 'camera', 'stage', 'laser' or 'dmd',
%                                          or 'calibration' (gui/CalibrationApp)
%   app = lhf.devicePanel(name, openers)   openers.(name)() makes the panel (tests)
%
%   The panels are the device packages' own (D16): hamacam.app, zaberstage.app (X, Y
%   and Z), obis.app, DMDController.app, opened from the parameter GUI's device buttons
%   (gui/DeviceButtons.m). Each controls the rig's one object for its device,
%   lhf.device(name), which the Pattern Designer, the protocols and the calibration
%   scripts use too: what the panel does is what they see, and the other way round.
%   Connect and Disconnect on a panel connect and disconnect that shared device; closing
%   the panel leaves it as it is. One panel per device: pressing again brings it to the
%   front. While a session runs the Laser and DMD panels open view only
%   (lhf.lockDevicePanels). A panel opens where the rig's layout puts it (lhf.windowPosition: the camera
%   left of the parameter GUI, the stage below it, the laser left of the stage, the DMD
%   and Calibration left of the camera). Open panels are kept in appdata
%   'lhfDevicePanels'. The Laser panel also shows the power out of the objective for its
%   setpoint, from dmd/power_calibration.csv (measured with every DMD mirror on), and the
%   Camera panel names each frame it saves with that power (lhf.laser.powerTag) and saves
%   into the Bpod subject's luminose_hf_widefield folder (lhf.cam.useSubjectFolder).

    name = validatestring(name, {'camera', 'stage', 'laser', 'dmd', 'calibration'});
    panels = struct();
    if isappdata(0, 'lhfDevicePanels')
        panels = getappdata(0, 'lhfDevicePanels');
    end
    if isfield(panels, name) && isOpen(panels.(name))
        app = panels.(name);
        if ~isempty(app.Figure) && isvalid(app.Figure)
            figure(app.Figure);  % to the front
        end
        if strcmp(name, 'camera') && nargin < 2
            lhf.cam.useSubjectFolder(lhf.subjectName(), app);  % the subject may have changed
        end
        return
    end
    if nargin < 2 || ~isfield(openers, name)
        openers = struct('camera', @() hamacam.app(lhf.device('camera'), ...
                'NameTagFcn', @() lhf.laser.powerTag()), ...
            'stage', @() zaberstage.app(lhf.device('stage')), ...
            'laser', @() obis.app(lhf.device('laser'), 'Calibration', ...
                lhf.laser.sampleCalibration(), ...
                'CalibrationLabel', 'Out of objective'), ...
            'dmd', @() DMDController.app(lhf.device('dmd')), ...
            'calibration', @() CalibrationApp());
    end
    app = openers.(name)();
    try  % the rig's layout (lhf.windowPosition); a panel moved by hand stays where it is
        app.Figure.Position = lhf.windowPosition(name, app.Figure.Position(3:4));
    catch
    end
    panels.(name) = app;
    setappdata(0, 'lhfDevicePanels', panels);
    if strcmp(name, 'camera') && nargin < 2
        lhf.cam.useSubjectFolder(lhf.subjectName(), app);  % <data>/<subject>/luminose_hf_widefield
    end
    if any(strcmp(name, {'laser', 'dmd'})) && isappdata(0, 'lhfSessionRunning') ...
            && getappdata(0, 'lhfSessionRunning')
        try app.lock('session running'); catch, end  % the session drives it (lhf.lockDevicePanels)
    end
end


function tf = isOpen(app)
% Whether a panel kept is still on screen.
tf = ~isempty(app) && isvalid(app) && ~isempty(app.Root) && isvalid(app.Root);
end

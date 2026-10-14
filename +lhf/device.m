function d = device(name, action)
% device  The rig's one object for each device, shared by everything in LuminoseHF.
%
%   d = lhf.device(name)              'camera', 'stage', 'laser' or 'dmd'
%   d = lhf.device(name, 'connect')   the same object, connected if it was not
%   lhf.device(name, d)               use d from now on (tests: a simulated device)
%   lhf.device(name, [])              forget it (the next call makes a new one)
%
%   Each device has one object for the whole MATLAB session, made on first use from
%   luminose_config.yaml, and its own panel controls it (lhf.devicePanel, the parameter
%   GUI's Camera / Stage / Laser / DMD buttons). The Pattern Designer, the protocols
%   (lhf.laser.open, DMDPatternPlayer) and the calibrations (lhf.cal.run, the Calibration
%   window; rigStages) use the same object, so nothing opens a device twice and the panels always
%   show what is happening. Finishing with a device leaves it as it is (a session turns
%   the laser's emission off and halts the DMD); connecting and disconnecting are the
%   panels' to do (or a script's, through the same object).
%
%   camera  hamacam.Camera: luminose.camera's device, adaptor DLL, exposure, averaging
%   stage   struct x, y, z of zaberstage.Stage on one shared port (luminose.zaber.port),
%           each on its device and axis, reversed and kept within its safe_um
%           (rigAxisOptions), and close (disconnects the three, closes the port)
%   laser   obis.Laser on luminose.laser.port, refusing power above laser.maxPower_mW
%   dmd     DMDController.DMD (loads the ALP-5.0 DLL when made)
%
%   The objects are kept in appdata 'lhfDevices'.

    name = validatestring(name, {'camera', 'stage', 'laser', 'dmd'});
    devices = struct();
    if isappdata(0, 'lhfDevices')
        devices = getappdata(0, 'lhfDevices');
    end
    if nargin >= 2 && ~(ischar(action) || isstring(action))
        if isempty(action)
            devices = rmfield(devices, intersect({name}, fieldnames(devices)));
        else
            devices.(name) = action;
        end
        setappdata(0, 'lhfDevices', devices);
        d = action;
        return
    end
    if isfield(devices, name) && isAlive(devices.(name))
        d = devices.(name);
    else
        d = make(name);
        devices.(name) = d;
        setappdata(0, 'lhfDevices', devices);
    end
    if nargin >= 2 && strcmpi(action, 'connect')
        connect(name, d);
    end
end


function tf = isAlive(d)
% Whether a kept object can still be used.
if isstruct(d)
    tf = isfield(d, 'z') && isvalid(d.z);
else
    tf = ~isempty(d) && isvalid(d);
end
end


function d = make(name)
% The device's object from the rig's config, not connected.
luminose = rigConfig();
switch name
    case 'camera'
        cfg = luminose.camera;
        d = hamacam.Camera('DeviceID', cfg.deviceID, 'DllPath', char(cfg.adaptorDllPath), ...
            'ExposureMs', cfg.exposureTime_ms, 'AverageFrames', cfg.nAverageFrames);
    case 'stage'
        stageAxes = luminose.zaber.axes;
        if ~all(isfield(stageAxes, {'x', 'y', 'z'}))
            error('lhf:device:noAxes', ['zaber.axes in luminose_config.yaml must name the ' ...
                'x, y and z axes (device and axis).']);
        end
        transport = zaberstage.transport.MotionLibraryTransport(char(luminose.zaber.port));
        d = struct();
        for axisName = {'x', 'y', 'z'}
            options = rigAxisOptions(stageAxes, axisName{1});
            d.(axisName{1}) = zaberstage.Stage('Transport', transport, ...
                'SharedTransport', true, options{:});
        end
        stages = d;
        d.close = @() closeStages(stages, transport);
    case 'laser'
        cfg = luminose.laser;
        d = obis.Laser('Port', char(cfg.port), 'BaudRate', cfg.baudRate, ...
            'MaxPowermW', cfg.maxPower_mW);
    case 'dmd'
        d = DMDController.DMD();
end
end


function connect(name, d)
% Connects the device unless it already is.
switch name
    case {'camera', 'laser'}
        if ~strcmp(d.State, 'Ready')
            d.connect();
        end
    case 'stage'
        for axisName = {'x', 'y', 'z'}
            if ~strcmp(d.(axisName{1}).State, 'Ready')
                d.(axisName{1}).connect();  % the first opens the shared port
            end
        end
    case 'dmd'
        if isempty(d.device.deviceId)
            d.connect();
        end
end
end


function closeStages(stages, transport)
% Disconnects the three axes and closes their port (they can connect again).
for axisName = {'x', 'y', 'z'}
    stages.(axisName{1}).disconnect();
end
transport.close();
end


function config = rigConfig()
% The protocols' global LuminoseConstants, or the rig's config read now.
global luminose %#ok<GVMIS> the protocols' global (CLAUDE.md, Global variables)
config = luminose;
if isempty(config)
    config = LuminoseConstants();
end
end

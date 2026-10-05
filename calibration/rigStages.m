function stages = rigStages(luminose, transport)
% rigStages  The rig's Zaber X, Y and Z axes, connected on one port (nothing moves).
%
%   stages = rigStages(luminose)
%   stages = rigStages(luminose, transport)   a given transport (tests: simulated)
%
%   Struct x, y, z of zaberstage.Stage (ZaberStage repo), each on its device and
%   axis from luminose.zaber.axes, sharing one transport on luminose.zaber.port
%   ('SharedTransport', true), counted the other way where the axis says
%   reversed: true and kept within its safe_um (rigAxisOptions), and close, a
%   function that disconnects all three and closes the port. Their limits start as
%   each axis's safe range: narrow LimitsUm before moving. Errors if the config does
%   not name all three axes, each with its safe_um.

    axes = luminose.zaber.axes;
    if ~all(isfield(axes, {'x', 'y', 'z'}))
        error('rigStages:noAxes', ['zaber.axes in luminose_config.yaml must name the x, y and z ' ...
            'axes (device and axis): read them on the rig with zaberstage.listDevices or zaberstage.app.']);
    end
    if nargin < 2
        transport = zaberstage.transport.MotionLibraryTransport(char(luminose.zaber.port));
    end
    transport.open();
    stages = struct();
    try
        for name = {'x', 'y', 'z'}
            options = rigAxisOptions(axes, name{1});
            stage = zaberstage.Stage('Transport', transport, 'SharedTransport', true, options{:});
            stage.connect();
            stages.(name{1}) = stage;
        end
    catch err
        closeAll(stages, transport);
        rethrow(err);
    end
    stages.close = @() closeAll(stages, transport);
end

function closeAll(stages, transport)
    for name = {'x', 'y', 'z'}
        if isfield(stages, name{1}), stages.(name{1}).disconnect(); end
    end
    transport.close();
end

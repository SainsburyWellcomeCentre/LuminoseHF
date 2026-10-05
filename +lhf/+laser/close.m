function close()
% lhf.laser.close  Turn emission off and free the laser's serial port, if it is open.
%
%   lhf.laser.close()
%
%   Safe to call when the laser was never opened. Called from each
%   protocol's cleanup, and by lhf.laser.open before connecting.

    global BpodSystem

    if isempty(BpodSystem) || ~isfield(BpodSystem.PluginObjects, 'Laser')
        return
    end
    if isa(BpodSystem.PluginObjects.Laser, 'LaserModel')
        try
            BpodSystem.PluginObjects.Laser.disconnect();  % emission off, frees the port
        catch err
            warning('lhf:laser:disconnect', 'Laser disconnect failed: %s', err.message);
        end
    end
    BpodSystem.PluginObjects = rmfield(BpodSystem.PluginObjects, 'Laser');
end

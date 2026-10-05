function close(keepRecord)
% lhf.laser.close  Turn emission off and free the laser's serial port, if it is open.
%
%   lhf.laser.close()
%   lhf.laser.close(false)   without keeping its record (a laser left by an aborted session)
%
%   Safe to call when the laser was never opened. Called from each
%   protocol's cleanup, and by lhf.laser.open before connecting. The laser's
%   obis record (identity, limits, every command with its time and latency)
%   is kept in BpodSystem.Data.Laser before it is disconnected.

    global BpodSystem

    if nargin < 1
        keepRecord = true;
    end
    if isempty(BpodSystem) || ~isfield(BpodSystem.PluginObjects, 'Laser')
        return
    end
    laser = BpodSystem.PluginObjects.Laser;
    if isa(laser, 'obis.Laser') && isvalid(laser)
        if keepRecord
            BpodSystem.Data.Laser = laser.record();
        end
        laser.disconnect();  % emission off, frees the port; never throws
    end
    BpodSystem.PluginObjects = rmfield(BpodSystem.PluginObjects, 'Laser');
end

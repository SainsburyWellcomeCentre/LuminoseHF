function close(keepRecord)
% lhf.laser.close  Turn the session's laser emission off and let go of it.
%
%   lhf.laser.close()
%   lhf.laser.close(false)   without keeping its record (a laser left by an aborted session)
%
%   Safe to call when the laser was never opened. Called from each
%   protocol's cleanup, and by lhf.laser.open before connecting. Emission is
%   turned off; the laser stays connected, as it is the rig's one laser
%   (lhf.device('laser')) and its panel's to disconnect. The laser's
%   obis record (identity, limits, every command with its time and latency)
%   is kept in BpodSystem.Data.Laser before it is disconnected, with
%   statusAtStart and statusAtEnd (obis.Laser.status: output and setpoint mW,
%   baseplate temperature, status and fault codes).

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
            record = laser.record();
            record.statusAtStart = [];
            if isfield(BpodSystem.PluginObjects, 'LaserStatusAtStart')
                record.statusAtStart = BpodSystem.PluginObjects.LaserStatusAtStart;
            end
            try
                record.statusAtEnd = laser.status();
            catch err
                record.statusAtEnd = struct('error', err.message);
            end
            BpodSystem.Data.Laser = record;
        end
        laser.stopAll();  % emission off; never throws. Stays connected: the panel's
    end
    BpodSystem.PluginObjects = rmfield(BpodSystem.PluginObjects, intersect({'Laser', ...
        'LaserStatusAtStart'}, fieldnames(BpodSystem.PluginObjects)));
end

function close()
% lhf.olf.close  Keep the session's odour deliveries in the data and stop using the worker.
%
%   lhf.olf.close()
%
%   Called from each protocol's cleanup, before the data are saved. Stores the
%   olfactometer.AsyncDelivery record (every delivery with its time, valves and
%   duty, and every worker failure) in BpodSystem.Data.Olfactometer. The worker's
%   pool stays open, so the next session starts warm. Safe to call when no
%   delivery was started.

    global BpodSystem

    if isempty(BpodSystem) || ~isfield(BpodSystem.PluginObjects, 'Olfactometer')
        return
    end
    delivery = BpodSystem.PluginObjects.Olfactometer;
    if isa(delivery, 'olfactometer.AsyncDelivery') && isvalid(delivery)
        BpodSystem.Data.Olfactometer = delivery.record();
        delivery.close();
    end
    BpodSystem.PluginObjects = rmfield(BpodSystem.PluginObjects, 'Olfactometer');
end

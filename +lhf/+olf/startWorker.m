function delivery = startWorker(olfConstants)
% lhf.olf.startWorker  Start odour delivery on one warmed-up worker; returns at once.
%
%   delivery = lhf.olf.startWorker(luminose.olfactometer)
%   ...                                   (parameter GUI, wait for START)
%   lhf.olf.waitWorker(delivery)
%
%   An olfactometer.AsyncDelivery (NIDAQOlfactometer repo), triggered by the state
%   machine's TTL, with the rig's bottle tables (a duty of 0 is the bottle's own,
%   read here once rather than in a soft-code callback). Its one-worker pool and
%   DAQ session start while the parameter GUI is up (daq("ni") in a fresh process
%   can take a minute); lhf.olf.waitWorker, after START, waits for that and raises
%   a warm-up failure before any trial. The delivery is kept in
%   BpodSystem.PluginObjects.Olfactometer for lhf.olf.deliver; lhf.olf.close ends it.

    global BpodSystem

    bottles = olfactometer.Bottles.fromTsv(olfConstants.odourBottlesFile, ...
        olfConstants.odourChemicalsFile);
    delivery = olfactometer.AsyncDelivery(olfConstants, 'Triggered', true, 'Bottles', bottles);
    delivery.start();
    BpodSystem.PluginObjects.Olfactometer = delivery;
end

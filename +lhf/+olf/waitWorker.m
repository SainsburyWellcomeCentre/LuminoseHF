function waitWorker(delivery)
% lhf.olf.waitWorker  Wait for the olfactometer worker's warm-up; raise its error.
%
%   lhf.olf.waitWorker(delivery)   delivery from lhf.olf.startWorker
%
%   Called after START, before the first trial: usually the warm-up finished
%   while the parameter GUI was up and this returns at once.

    delivery.wait();
end

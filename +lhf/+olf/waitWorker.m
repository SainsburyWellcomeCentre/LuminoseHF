function waitWorker(warmup)
% lhf.olf.waitWorker  Wait for the olfactometer worker's warm-up; raise its error.
%
%   lhf.olf.waitWorker(warmup)   warmup from lhf.olf.startWorker
%
%   Called after START, before the first trial: usually the warm-up finished
%   while the parameter GUI was up and this returns at once.

    if ~strcmp(warmup.State, 'finished')
        disp('Waiting for the olfactometer worker (NI-DAQ) to start...');
    end
    fetchOutputs(warmup);  % waits; rethrows a warm-up error
end

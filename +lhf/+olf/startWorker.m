function warmup = startWorker(olfConstants)
% lhf.olf.startWorker  The single-worker pool odour delivery runs on; starts its warm-up.
%
%   warmup = lhf.olf.startWorker(luminose.olfactometer)
%   ...                                   (parameter GUI, wait for START)
%   lhf.olf.waitWorker(warmup)
%
%   Odour delivery runs on a parfeval worker so it doesn't block the
%   state-machine dispatch thread. It must always be the SAME single
%   worker: a larger pool risks two worker processes racing for the one
%   NI-DAQ, and letting parfeval auto-create a pool on the first soft code
%   stalls trial 1 for tens of seconds. So a one-worker pool is made (an
%   open pool of another size is replaced) and its OlfactometerModel and DAQ
%   session are created on it. That warm-up (daq("ni") in a fresh process can
%   take a minute) runs while the parameter GUI is up: this returns its
%   future without waiting, and lhf.olf.waitWorker, after START, waits for
%   it and raises a warm-up failure before any trial runs.

    pool = gcp('nocreate');
    if isempty(pool) || pool.NumWorkers ~= 1
        if ~isempty(pool), delete(pool); end
        pool = parpool(1);
    end
    warmup = parfeval(pool, @lhf.olf.worker, 0, [], [], olfConstants, '');
end

function worker(valves, dutyCycles, olfConstants, errorLog)
% lhf.olf.worker  Play one valve sequence; runs on the single olfactometer pool worker.
%
%   parfeval(pool, @lhf.olf.worker, 0, valves, dutyCycles, olfConstants, errorLog)
%   parfeval(pool, @lhf.olf.worker, 0, [], [], olfConstants, '')   warm-up
%
%   The OlfactometerModel (and its NI-DAQ session) is worker-local, created
%   by the first call (lhf.olf.startWorker's warm-up) and reused by every
%   later call on the same worker. Nothing reports a parfeval error, so
%   errors are appended to errorLog instead.

    global olfModel

    try
        if isempty(olfModel)
            olfModel = OlfactometerModel(olfConstants, true);
        end
        if isempty(valves)
            return  % warm-up: only creates olfModel
        end
        if all(dutyCycles == 0)
            dutyCycles = olfModel.get_odour_dutycycles(valves);
        end
        olfModel.play_valve_sequence(valves, dutyCycles);
    catch ME
        if isempty(errorLog), rethrow(ME); end
        fid = fopen(errorLog, 'a');
        if fid < 0, return; end
        fprintf(fid, '[%s] valves=%s: %s at %s line %d\n', ...
            char(datetime('now', 'Format', 'HH:mm:ss')), mat2str(valves), ME.message, ...
            ME.stack(1).name, ME.stack(1).line);
        fclose(fid);
    end
end

function S = deliver(code, S, info, olfConstants)
% lhf.olf.deliver  Start an odour soft code's delivery on the olfactometer worker.
%
%   S = lhf.olf.deliver(code, S, info, olfConstants)
%
%   Called from a protocol's soft-code handler, in the client process, where
%   S and BpodSystem are valid (a parfeval worker has its own globals and
%   cannot see them). The valves are resolved here (lhf.olf.resolve), recorded
%   in S.GUI.delivered_odours / delivered_dutyCycles, and only the resolved
%   data go to the worker (lhf.olf.worker), which does the blocking hardware
%   call. Returns immediately. lhf.olf.startWorker must have run.

    global BpodSystem

    fixedRows = struct();
    if isfield(BpodSystem.PluginObjects, 'SelectedOdourRow')
        fixedRows = BpodSystem.PluginObjects.SelectedOdourRow;
    end

    [valves, dutyCycles, type] = lhf.olf.resolve(code, S.GUI, info.odourTypes, fixedRows);
    if isempty(valves)
        return
    end
    S.GUI.delivered_odours.(type) = valves;
    S.GUI.delivered_dutyCycles.(type) = dutyCycles;
    pool = gcp('nocreate');
    if isempty(pool)
        % Never let parfeval open a pool here: it takes tens of seconds
        warning('lhf:olf:noPool', 'No olfactometer worker (pool closed): %s odour not delivered.', type);
        return
    end
    parfeval(pool, @lhf.olf.worker, 0, valves, dutyCycles, olfConstants, errorLog());
end

function file = errorLog()
    global BpodSystem
    [folder, name] = fileparts(BpodSystem.Path.CurrentDataFile);
    file = fullfile(folder, [name '_olfactometer_errors.txt']);
end

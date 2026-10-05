function S = deliver(code, S, info, ~)
% lhf.olf.deliver  Start an odour soft code's delivery on the olfactometer worker.
%
%   S = lhf.olf.deliver(code, S, info, luminose.olfactometer)
%
%   Called from a protocol's soft-code handler, in the client process, where S
%   and BpodSystem are valid. The valves are resolved here (lhf.olf.resolve) and
%   sent to the worker through the session's olfactometer.AsyncDelivery
%   (lhf.olf.startWorker), which returns at once; a duty of 0 becomes the
%   bottle's own. The valves and the duty actually sent are recorded in
%   S.GUI.delivered_odours / delivered_dutyCycles. Nothing is thrown: a bad
%   request, a closed pool or a worker failure is written to
%   <data file>_olfactometer_errors.txt (and a missing worker warned about),
%   because a soft-code callback must not stop the session.

    global BpodSystem

    fixedRows = struct();
    if isfield(BpodSystem.PluginObjects, 'SelectedOdourRow')
        fixedRows = BpodSystem.PluginObjects.SelectedOdourRow;
    end

    [valves, dutyCycles, type] = lhf.olf.resolve(code, S.GUI, info.odourTypes, fixedRows);
    if isempty(valves)
        return
    end
    if ~isfield(BpodSystem.PluginObjects, 'Olfactometer')
        warning('lhf:olf:noWorker', 'No olfactometer worker: %s odour not delivered.', type);
        return
    end
    log = errorLog();
    try
        [valves, dutyCycles] = BpodSystem.PluginObjects.Olfactometer.deliver(valves, ...
            dutyCycles, 'ErrorLog', log);
    catch err
        warning('lhf:olf:notDelivered', '%s odour not delivered: %s', type, err.message);
        fid = fopen(log, 'a');
        if fid >= 0
            fprintf(fid, '[%s] %s valves=%s: %s (%s)\n', char(datetime('now', 'Format', ...
                'HH:mm:ss.SSS')), type, mat2str(valves), err.message, err.identifier);
            fclose(fid);
        end
        return
    end
    S.GUI.delivered_odours.(type) = valves;
    S.GUI.delivered_dutyCycles.(type) = dutyCycles;
end

function file = errorLog()
    global BpodSystem
    [folder, name] = fileparts(BpodSystem.Path.CurrentDataFile);
    file = fullfile(folder, [name '_olfactometer_errors.txt']);
end

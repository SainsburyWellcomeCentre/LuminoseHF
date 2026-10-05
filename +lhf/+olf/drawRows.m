function rows = drawRows(GUI, types)
% lhf.olf.drawRows  The odour row each type delivers in one trial.
%
%   rows = lhf.olf.drawRows(S.GUI, types)
%
%   rows.<type>  for each type with a table (S.GUI.valves_<type>): the row
%                drawn with probs_<type> from lhf.random(), row 1 for one row
%
%   PrepareStateMachine draws the rows of the trial it prepares into
%   BpodSystem.PluginObjects.NextOdourRow, so the cue and stimulus states are
%   timed by the sequence the trial delivers (lhf.stimDuration). The trial
%   loop hands them to the soft-code handler (SelectedOdourRow, read by
%   lhf.olf.deliver) after getTrialData, as the DMD handler's 'advance' does:
%   the next trial is prepared before the running one's soft codes arrive.

    rows = struct();
    for k = 1:numel(types)
        type = types{k};
        if ~isfield(GUI, ['valves_' type]), continue; end
        probs = GUI.(['probs_' type]);
        if numel(probs) > 1
            rows.(type) = randsample(lhf.random(), size(GUI.(['valves_' type]), 1), 1, true, probs);
        else
            rows.(type) = 1;
        end
    end
end

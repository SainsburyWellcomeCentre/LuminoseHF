function seconds = stimDuration(GUI, kind, type, which)
% lhf.stimDuration  How long a cue or stimulus lasts, in seconds.
%
%   seconds = lhf.stimDuration(S.GUI, kind, type)             this trial's (PrepareStateMachine)
%   seconds = lhf.stimDuration(S.GUI, kind, type, 'longest')  its longest row (the GUI's preview)
%
%   kind  'Light', 'Sound', 'Odour' or 'Pattern' (the Cue/Stimulus type popups)
%   type  the S.GUI suffix: 'cue', 'CSplus', 'Left', 'Template', ...
%
%   Light, Sound  S.GUI.LightDuration_<type>, SoundDuration_<type>, set in
%                 the type's Light and Sound panels
%   Odour         one olfactometer slot per odour in the row's sequence
%                 (lhf.olf.sequenceDuration); this trial's row is
%                 BpodSystem.PluginObjects.NextOdourRow.<type> (lhf.olf.drawRows)
%   Pattern       the row's design as the DMD plays it (lhf.patternDuration);
%                 this trial's row is BpodSystem.PluginObjects.SelectedPatternRow.<type>.
%                 A row with no design shows nothing and lasts 0; a blank
%                 design (no spots and a blankMs field, in memory) shows
%                 nothing for blankMs.
%
%   The protocols time their cue and stimulus states with it, so the next
%   state (the response window) starts as the stimulus ends.

    global BpodSystem luminose

    longest = nargin > 3 && strcmp(which, 'longest');
    seconds = 0;
    switch kind
        case {'Light', 'Sound'}
            seconds = GUI.([kind 'Duration_' type]);
        case 'Odour'
            table = GUI.(['valves_' type]);
            rows = 1:size(table, 1);
            if ~longest
                rows = 1;
                if isfield(BpodSystem.PluginObjects, 'NextOdourRow') && ...
                   isfield(BpodSystem.PluginObjects.NextOdourRow, type)
                    rows = BpodSystem.PluginObjects.NextOdourRow.(type);
                end
            end
            for r = rows
                seconds = max(seconds, lhf.olf.sequenceDuration(table(r, :), luminose.olfactometer));
            end
        case 'Pattern'
            designs = struct();
            if isfield(BpodSystem.PluginObjects, 'PatternDesigns')
                designs = BpodSystem.PluginObjects.PatternDesigns;
            end
            rows = 1:numel(GUI.(['patternProbs_' type]));
            if ~longest
                rows = 1;
                if isfield(BpodSystem.PluginObjects, 'SelectedPatternRow') && ...
                   isfield(BpodSystem.PluginObjects.SelectedPatternRow, type)
                    rows = BpodSystem.PluginObjects.SelectedPatternRow.(type);
                end
            end
            for r = rows
                seconds = max(seconds, patternRowDuration(designs, type, r, GUI.(['patternExposure_' type])));
            end
        otherwise
            error('lhf:stimDuration:kind', 'Unknown stimulus kind ''%s''.', kind);
    end
end

function seconds = patternRowDuration(designs, type, row, exposureUs)
% A row's design as the DMD plays it; a blank design (no spots, blankMs, as
% powercal's default CS+) shows nothing for blankMs; no design lasts 0.
    global luminose
    seconds = 0;
    design = lhf.patternDesign(designs, luminose.dmd, type, row);
    if ~isempty(design)
        seconds = lhf.patternDuration(design, exposureUs, row);
    elseif isfield(designs, type) && row <= numel(designs.(type)) && ...
           isfield(designs.(type){row}, 'blankMs')
        seconds = designs.(type){row}.blankMs / 1000;
    end
end

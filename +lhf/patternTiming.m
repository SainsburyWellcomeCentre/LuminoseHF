function GUI = patternTiming(GUI, designs, dmdConfig, types)
% lhf.patternTiming  Each pattern row's exposure and frame count, from its design.
%
%   S.GUI = lhf.patternTiming(S.GUI, BpodSystem.PluginObjects.PatternDesigns, luminose.dmd, types)
%
%   For every row of each type (patternProbs_<type>) that has a design
%   (lhf.patternDesign: in memory, else the newest file):
%   patternExposure_<type>(row) = the design's tick (ms) x 1000, in us, and
%   patternNFrames_<type>(row) = its frame count. The DMD shows each frame
%   for the row's exposure, so it must be the tick the design was made with;
%   the Pattern Designer sets both when it saves, and the protocols call this
%   at startup, so a settings file saved before a design changed cannot
%   carry an older exposure. A blank design (no spots) is one frame of its
%   blankMs. Rows without a design keep their values.

    for k = 1:numel(types)
        type = types{k};
        probField = ['patternProbs_' type];
        if ~isfield(GUI, probField), continue; end
        expField = ['patternExposure_' type];
        nFField = ['patternNFrames_' type];
        for row = 1:numel(GUI.(probField))
            [design, blankMs] = lhf.patternDesign(designs, dmdConfig, type, row);
            if isempty(design)
                if blankMs > 0  % a blank: one frame as long as it lasts
                    GUI.(expField)(row) = blankMs * 1000;
                    GUI.(nFField)(row) = 1;
                end
                continue
            end
            GUI.(expField)(row) = design.tickMs * 1000;
            % as DMDPatternPlayer builds it (older files have no nF)
            GUI.(nFField)(row) = ceil(max([design.spots.onset_ms] + [design.spots.dur_ms]) / design.tickMs);
        end
    end
end

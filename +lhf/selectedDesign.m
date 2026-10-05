function design = selectedDesign(patternType)
% lhf.selectedDesign  The design of the row chosen for this trial, or [] for none.
%
%   design = lhf.selectedDesign(patternType)
%
%   The row is BpodSystem.PluginObjects.SelectedPatternRow.<type>, drawn by
%   the protocol's PrepareStateMachine (row 1 if none was drawn); the design
%   comes from lhf.patternDesign (in memory, else the newest file in the
%   type's folder). [] means the row shows nothing.

    global BpodSystem luminose

    designs = struct();
    if isfield(BpodSystem.PluginObjects, 'PatternDesigns')
        designs = BpodSystem.PluginObjects.PatternDesigns;
    end
    row = 1;
    if isfield(BpodSystem.PluginObjects, 'SelectedPatternRow') && ...
       isfield(BpodSystem.PluginObjects.SelectedPatternRow, patternType)
        row = BpodSystem.PluginObjects.SelectedPatternRow.(patternType);
    end
    design = lhf.patternDesign(designs, luminose.dmd, patternType, row);
end

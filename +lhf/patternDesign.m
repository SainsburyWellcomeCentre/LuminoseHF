function design = patternDesign(designs, dmdConfig, patternType, row)
% lhf.patternDesign  One row's pattern design, or [] when the row has none.
%
%   design = lhf.patternDesign(BpodSystem.PluginObjects.PatternDesigns, luminose.dmd, type, row)
%
%   designs  the designs in memory (struct of cells by type; struct() for none)
%
%   The design in memory wins; otherwise the newest designed_<file type>_r<row>_*
%   file (lhf.patternFileType) in lhf.patternFolder (for row 1 also an older file without a row
%   index). A design with no spots counts as none, so [] always means
%   "nothing to show": no DMD sequence and no soft code.
%
%   design fields: spots (x, y, onset_ms, dur_ms, isFixed), tickMs, r_px, nF,
%   and laserIrradiances_mWmm2, laserWeights when the design has laser options

    design = [];
    if isstruct(designs) && isfield(designs, patternType) && row <= numel(designs.(patternType)) ...
            && ~isempty(designs.(patternType){row})
        design = designs.(patternType){row};
    else
        design = loadNewest(lhf.patternFolder(dmdConfig, patternType), lhf.patternFileType(dmdConfig, patternType), row);
    end
    if isempty(design) || ~isfield(design, 'spots') || isempty(design.spots)
        design = [];
    end
end

function design = loadNewest(folder, fileType, row)
    design = [];
    metas = dir(fullfile(folder, sprintf('designed_%s_r%d_*_meta.mat', fileType, row)));
    if row == 1
        allMetas = dir(fullfile(folder, sprintf('designed_%s_*_meta.mat', fileType)));
        hasRow = arrayfun(@(m) ~isempty(regexp(m.name, sprintf('designed_%s_r\\d+_', fileType), 'once')), allMetas);
        metas = [metas; allMetas(~hasRow)];
    end
    if isempty(metas), return; end
    [~, newest] = max([metas.datenum]);
    try
        m = load(fullfile(folder, metas(newest).name));
        for i = 1:numel(m.spots)
            if ~isfield(m.spots(i), 'isFixed'), m.spots(i).isFixed = true; end
        end
        nF = 1;
        if isfield(m, 'nF'), nF = m.nF; end
        design = struct('spots', m.spots, 'tickMs', m.tickMs, 'r_px', m.r_px, 'nF', nF);
        if isfield(m, 'laserIrradiances_mWmm2')  % saved by the Pattern Designer with laser options
            design.laserIrradiances_mWmm2 = m.laserIrradiances_mWmm2;
            design.laserWeights = m.laserWeights;
        end
    catch
    end
end

function dmd_hf_2AFC(code, codes)
% dmd_hf_2AFC  DMD handler for the 2AFC protocol.
%
%   dmd_hf_2AFC('prepare', codes)  build the next trial's sequences for the
%                                    soft codes it sends (PrepareStateMachine)
%   dmd_hf_2AFC('advance')         make them current (after getTrialData)
%   dmd_hf_2AFC('close')           free the sequences and the device
%   dmd_hf_2AFC(code)              soft code: show the current sequence
%
%   Soft-code mapping:
%     8  - cue pattern
%     9  - Left pattern
%    10  - Right pattern
%    11  - halt (sent at GetResponse entry to stop the display)
%    12  - opto pattern
%
%   Sequences are shown in MASTER mode (immediate). Code 11 halts projection
%   (no blank sequence, so no extra synch pulse).
%
%   Log: <luminose_hf repo root>/dmd_hf_2AFC_log.txt

    persistent player

    global S luminose BpodSystem

    logFile = fullfile(char(luminose.f.luminose_hf), 'dmd_hf_2AFC_log.txt');

    try
        if ~ischar(code)
            showCode(player, code, logFile);
            return;
        end
        switch code
            case 'prepare'
                if isempty(codes), return; end
                if isempty(player)
                    player = DMDPatternPlayer();
                    dmd_log(logFile, 'DMD connected');
                end
                for c = codes
                    typeName = codeType(c);
                    if isempty(typeName), continue; end
                    rowIdx = selectedRow(BpodSystem, typeName);
                    design = getDesign(BpodSystem, typeName, rowIdx, luminose.dmd.patternsFolder);
                    if isempty(design)
                        dmd_log(logFile, 'no design found for %s row %d — skipping', typeName, rowIdx);
                        continue;
                    end
                    expVec = S.GUI.(sprintf('patternExposure_%s', typeName));
                    illuTime = expVec(min(rowIdx, numel(expVec)));
                    player.prepareSpots(typeName, design, illuTime);
                    dmd_log(logFile, 'prepared %s row %d illuTime=%.0fus', typeName, rowIdx, illuTime);
                end
            case 'advance'
                if ~isempty(player), player.advance(); end
            case 'close'
                if ~isempty(player), delete(player); end
                player = [];
        end
    catch ME
        dmd_log(logFile, 'ERROR: %s  at %s line %d', ME.message, ME.stack(1).name, ME.stack(1).line);
        if ischar(code), warning('dmd_hf_2AFC(''%s''): %s', code, ME.message); end
    end
end

% -----------------------------------------------------------------------

function showCode(player, code, logFile)
    if code == 11
        % Halt only — projecting a blank sequence would fire its own
        % frame-synch pulse on DMD pin 8 and gate the laser on again.
        if ~isempty(player), player.halt(); end
        dmd_log(logFile, 'DMD halted');
        return;
    end
    typeName = codeType(code);
    if isempty(player) || isempty(typeName) || ~player.show(typeName)
        dmd_log(logFile, 'code %d: nothing prepared', code);
        return;
    end
    dmd_log(logFile, 'displaying %s in MASTER mode (immediate)', typeName);
end

function rowIdx = selectedRow(BpodSystem, typeName)
    rowIdx = 1;
    if isfield(BpodSystem.PluginObjects, 'SelectedPatternRow') && ...
       isfield(BpodSystem.PluginObjects.SelectedPatternRow, typeName)
        rowIdx = BpodSystem.PluginObjects.SelectedPatternRow.(typeName);
    end
end

function typeName = codeType(code)
    switch code
        case 8,  typeName = 'cue';
        case 9,  typeName = 'Left';
        case 10, typeName = 'Right';
        case 12, typeName = 'opto';
        otherwise, typeName = '';
    end
end

function design = getDesign(BpodSystem, typeName, rowIdx, patternsFolder)
    design = [];
    if isfield(BpodSystem.PluginObjects, 'PatternDesigns') && ...
       isfield(BpodSystem.PluginObjects.PatternDesigns, typeName) && ...
       rowIdx <= numel(BpodSystem.PluginObjects.PatternDesigns.(typeName)) && ...
       ~isempty(BpodSystem.PluginObjects.PatternDesigns.(typeName){rowIdx})
        design = BpodSystem.PluginObjects.PatternDesigns.(typeName){rowIdx};
        return
    end
    patternsFolder = char(patternsFolder);
    rowMetas   = dir(fullfile(patternsFolder, sprintf('designed_%s_r%d_*_meta.mat', typeName, rowIdx)));
    legacyMetas = [];
    if rowIdx == 1
        all_m = dir(fullfile(patternsFolder, sprintf('designed_%s_*_meta.mat', typeName)));
        isRow = arrayfun(@(m) ~isempty(regexp(m.name, sprintf('designed_%s_r\\d+_', typeName), 'once')), all_m);
        legacyMetas = all_m(~isRow);
    end
    metas = [rowMetas; legacyMetas];
    if isempty(metas), return; end
    [~, newest] = max([metas.datenum]);
    try
        m = load(fullfile(patternsFolder, metas(newest).name), 'spots', 'tickMs', 'r_px', 'nF');
        for i = 1:numel(m.spots)
            if ~isfield(m.spots(i), 'isFixed'), m.spots(i).isFixed = true; end
        end
        nF = 1; if isfield(m, 'nF'), nF = m.nF; end
        design = struct('spots', m.spots, 'tickMs', m.tickMs, 'r_px', m.r_px, 'nF', nF);
    catch
    end
end

function dmd_log(logFile, fmt, varargin)
    fid = fopen(logFile, 'a');
    if fid < 0, return; end
    fprintf(fid, '[%s] ', datestr(now, 'HH:MM:SS'));
    fprintf(fid, fmt, varargin{:});
    fprintf(fid, '\n');
    fclose(fid);
end

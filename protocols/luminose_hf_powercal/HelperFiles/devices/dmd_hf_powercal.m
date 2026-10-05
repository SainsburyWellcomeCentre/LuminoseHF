function dmd_hf_powercal(code, codes)
% dmd_hf_powercal  DMD handler for the powercal protocol.
%
%   dmd_hf_powercal('prepare', codes)  build the next trial's sequences for the
%                                    soft codes it sends (PrepareStateMachine)
%   dmd_hf_powercal('advance')         make them current (after getTrialData)
%   dmd_hf_powercal('close')           free the sequences and the device
%   dmd_hf_powercal(code)              soft code: show the current sequence
%
%   Soft-code mapping:
%     8  - cue pattern
%     9  - CS+ pattern
%    10  - CS- pattern
%
%   Designs come from lhf.patternDesign: CS+ and CS- from powercal's own
%   files, designed_powercalCSplus_* and designed_powercal_* (see loadPowercalDesigns in luminose_hf_powercal.m, which also
%   sets the defaults: CS+ nothing, CS- a central spot).
%    11  - halt (sent at GetResponse entry to stop the display)
%    12  - opto pattern
%
%   Sequences are shown in MASTER mode (immediate). Code 11 halts projection
%   (no blank sequence, so no extra synch pulse).
%
%   Log: <tempdir>/dmd_hf_powercal_log.txt

    persistent player

    global S luminose BpodSystem

    logFile = fullfile(char(tempdir), 'dmd_hf_powercal_log.txt');

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
                    design = lhf.patternDesign(storedDesigns(BpodSystem), luminose.dmd, typeName, rowIdx);
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
        if ischar(code), warning('dmd_hf_powercal(''%s''): %s', code, ME.message); end
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
        case 9,  typeName = 'CSplus';
        case 10, typeName = 'CSminus';
        case 12, typeName = 'opto';
        otherwise, typeName = '';
    end
end

function designs = storedDesigns(BpodSystem)
    designs = struct();
    if isfield(BpodSystem.PluginObjects, 'PatternDesigns')
        designs = BpodSystem.PluginObjects.PatternDesigns;
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

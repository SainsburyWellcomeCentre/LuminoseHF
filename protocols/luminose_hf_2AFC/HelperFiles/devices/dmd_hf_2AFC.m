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
%   Log: <data file>_dmd_log.txt (lhf.sessionFile), with the trial of each line.
%   What each trial's sequences were is recorded in BpodSystem.PluginObjects.
%   PreparedPatterns, which the protocol keeps as RawEvents.Trial{n}.Actions.Patterns.

    persistent player preparedTrial runningTrial

    global S luminose BpodSystem

    logFile = fullfile(char(luminose.f.luminose_hf), 'dmd_hf_2AFC_log.txt');

    try
        if ~ischar(code)
            showCode(player, code, logFile, runningTrial);
            return;
        end
        switch code
            case 'prepare'
                % What this trial will show, for its record (Actions.Patterns)
                BpodSystem.PluginObjects.PreparedPatterns = struct();
                preparedTrial = NaN;
                if isfield(BpodSystem.PluginObjects, 'PreparingTrial')
                    preparedTrial = BpodSystem.PluginObjects.PreparingTrial;
                end
                if isempty(codes), return; end
                if isempty(player)
                    player = DMDPatternPlayer();
                    dmd_log(logFile, 'DMD connected');
                end
                for c = codes
                    typeName = codeType(c);
                    if isempty(typeName), continue; end
                    rowIdx = selectedRow(BpodSystem, typeName);
                    % The design lhf.stimDuration and lhf.laser.draw used for this trial
                    [design, blankMs] = lhf.patternDesign(storedDesigns(BpodSystem), luminose.dmd, typeName, rowIdx);
                    if isempty(design)  % none, or a blank
                        BpodSystem.PluginObjects.PreparedPatterns.(typeName) = struct('row', rowIdx, ...
                            'shown', false, 'blankMs', blankMs);
                        dmd_log(logFile, 'trial %d: %s row %d has no design: nothing shown', ...
                            preparedTrial, typeName, rowIdx);
                        continue;
                    end
                    expVec = S.GUI.(sprintf('patternExposure_%s', typeName));
                    illuTime = expVec(min(rowIdx, numel(expVec)));
                    info = player.prepareSpots(typeName, design, illuTime);
                    info.row = rowIdx;
                    info.shown = true;
                    for f = {'laserIrradiances_mWmm2', 'laserWeights'}  % the design's power list
                        if isfield(design, f{1}), info.(f{1}) = design.(f{1}); end
                    end
                    BpodSystem.PluginObjects.PreparedPatterns.(typeName) = info;
                    dmd_log(logFile, ['trial %d: prepared %s row %d: %d spots, %d frames of %.0f us ' ...
                        '(%d sub-frames of %d us, synch %d us)%s'], preparedTrial, typeName, rowIdx, ...
                        numel(info.spots), info.nF, illuTime, info.subFrames, info.frameUs, info.synchUs, ...
                        pick(info.reused, ', reused', ''));
                end
            case 'advance'
                if ~isempty(player), player.advance(); end
                runningTrial = preparedTrial;
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

function showCode(player, code, logFile, trial)
    if isempty(trial), trial = NaN; end
    if code == 11
        % Halt only — projecting a blank sequence would fire its own
        % frame-synch pulse on DMD pin 8 and gate the laser on again.
        if ~isempty(player), player.halt(); end
        dmd_log(logFile, 'trial %d: DMD halted', trial);
        return;
    end
    typeName = codeType(code);
    if isempty(player) || isempty(typeName) || ~player.show(typeName)
        dmd_log(logFile, 'trial %d: code %d: nothing prepared', trial, code);
        return;
    end
    dmd_log(logFile, 'trial %d: displaying %s in MASTER mode (immediate)', trial, typeName);
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

function designs = storedDesigns(BpodSystem)
    designs = struct();
    if isfield(BpodSystem.PluginObjects, 'PatternDesigns')
        designs = BpodSystem.PluginObjects.PatternDesigns;
    end
end

function dmd_log(logFile, fmt, varargin)
    fid = fopen(logFile, 'a');
    if fid < 0, return; end
    fprintf(fid, '[%s] ', char(datetime('now', 'Format', 'HH:mm:ss.SSS')));
    fprintf(fid, fmt, varargin{:});
    fprintf(fid, '\n');
    fclose(fid);
end

function v = pick(tf, a, b)
    if tf, v = a; else, v = b; end
end

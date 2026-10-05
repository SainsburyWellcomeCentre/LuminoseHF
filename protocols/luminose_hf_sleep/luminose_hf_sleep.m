function luminose_hf_sleep
    %% clear & setup
    clc;
    warning('off', 'MATLAB:HandleGraphics:ObsoleteProperty:JavaFrame');

    global BpodSystem S luminose sniffDetector
    beep('off'); % native matlab error sounds OFF
    BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler_luminose_hf_sleep';

    %% Define luminose constants
    luminose = LuminoseConstants();
    [dataDir, dataBasename, ~] = fileparts(BpodSystem.Path.CurrentDataFile);
    log_file = fullfile(dataDir, [regexprep(dataBasename, '_Session\d+$', '') '_log.txt']);
    diary(log_file);

    disp('Luminose experiment initialized:');
    disp("=====  Folders =====");
    disp(luminose.f);
    disp("=====  Bpod =====");
    disp(luminose.bpod);
    disp("=====  Olfactometer =====");
    disp(luminose.olfactometer);
    disp("=====  DMD =====");
    disp(luminose.dmd);
    disp("=====  Bonsai =====");
    disp(luminose.bonsai);

    %% Launch bonsai
    launchBonsai = false;
    if luminose.bonsai.launch_bonsai
        choice = questdlg('Launch Bonsai workflow?', 'Launch Bonsai', 'Yes', 'No', 'Yes');
        launchBonsai = strcmp(choice, 'Yes');
    end

    if launchBonsai
        currentDataFile = split(BpodSystem.Path.CurrentDataFile, '\');
        currentFilePrefix = currentDataFile{end};
        luminose.bonsai.currentFilePrefix = currentFilePrefix(1:end-4);
        luminose.bonsai.dataPath = fullfile(join(currentDataFile(1:end-2), '\'), 'Session Videos');
        launch_bonsai(luminose.bonsai.exePath, luminose.bonsai.workflowPath, luminose.bonsai.dataPath, luminose.bonsai.currentFilePrefix);
    end

    %% Configure trials
    % Defaults come from GUIparams; a saved settings file is merged into them
    % (renamed and retired settings: lhf.settingsHistory)
    saved = BpodSystem.ProtocolSettings;
    S = struct();
    GUIparams_luminose_hf_sleep();
    settingsNotes = {};
    if ~isstruct(saved) || isempty(fieldnames(saved))
        restorePatternParams({'opto'}, luminose.dmd.patternsFolder);
    else
        [S, settingsNotes] = lhf.mergeSettings(saved, S, 'sleep');
        cellfun(@(note) fprintf('Settings: %s\n', note), settingsNotes);
    end
    LuminoseParameterGUI_hf_sleep('init', S);
    disp('Waiting for START button...');
    setappdata(BpodSystem.ProtocolFigures.ParameterGUI, 'StartPressed', false);
    while ~getappdata(BpodSystem.ProtocolFigures.ParameterGUI, 'StartPressed')
        pause(0.1);
        if ~ishandle(BpodSystem.ProtocolFigures.ParameterGUI)
            return
        end
    end
    S.GUI = BpodSystem.GUIData.ParameterGUI.LatestGUIParams;
    S = LuminoseParameterGUI_hf_sleep('sync', S);
    disp('START pressed — beginning experiment.');
    sessionCleanup = onCleanup(@cleanup); %#ok<NASGU> runs on normal end and on any error
    BpodSystem.Data.SettingsNotes = settingsNotes;
    % One seed per session, recorded (it seeds the rand/randperm below);
    % S.RandomSeed (edit the settings file) repeats a session once
    requestedSeed = [];
    if isfield(S, 'RandomSeed'), requestedSeed = S.RandomSeed; end
    S.RandomSeed = [];
    BpodSystem.Data.RandomSeed = lhf.random('init', requestedSeed);

    trialTypes = 1 + (rand(1, S.GUI.maxTrials) >= S.GUI.Typeprob);
    BpodSystem.Data.TrialTypes = [];
    if S.GUI.TestPulses
        stimTime = max(S.GUI.patternNFrames_opto .* S.GUI.patternExposure_opto) / 1e6;
        if S.GUI.TestPulsesType == 1
            if S.GUI.SPvariable
                ITI = (1 / S.GUI.SPfrequency) * (1.01 .^ (0:S.GUI.maxTrials-1));
                ITI(ITI > (1 / S.GUI.MaxSPfrequency)) = 1 / S.GUI.MaxSPfrequency;
                ITI = ITI(randperm(length(ITI)))';
                ITI = round(ITI * 1000) / 1000;
            else
                ITI = (1 / S.GUI.SPfrequency) * ones(1, S.GUI.maxTrials);
            end
        elseif S.GUI.TestPulsesType == 2
            if S.GUI.PPvariable
                ITI = (1 / S.GUI.PPfrequency) * (1.01 .^ (0:S.GUI.maxTrials-1));
                ITI(ITI > (1 / S.GUI.MaxPPfrequency)) = 1 / S.GUI.MaxPPfrequency;
                ITI = ITI(randperm(length(ITI)))';
                ITI = round(ITI * 1000) / 1000;
            else
                ITI = (1 / S.GUI.PPfrequency) * ones(1, S.GUI.maxTrials);
            end
        end
    else
        stimTime = 0;
        % Poisson ITI within [ITImin, ITImax]
        lambda = (S.GUI.ITImax - S.GUI.ITImin) / 2; % Target mean for the exponential part
        ITI = zeros(1, S.GUI.maxTrials);
        for i = 1:S.GUI.maxTrials
            val = S.GUI.ITImax + 1;
            while val > (S.GUI.ITImax - S.GUI.ITImin)
                val = exprnd(lambda);
            end
            ITI(i) = round(val + S.GUI.ITImin, 3);
        end
    end

    %% Begin plotting
    BpodNotebook('init');

    %% Configure Flex I/O Channels
    chanSniff = 1; chanPhotodetector = 2; chanFlowmeter = 3; chanNIDAQ = 4;
    channelTypes(1:4) = 4; % Disabled
    channelTypes(chanSniff) = 2; % Analog Input
    channelTypes(chanPhotodetector) = 2; % Analog Input
    channelTypes(chanFlowmeter) = 2; % Analog Input
    channelTypes(chanNIDAQ) = 2; % Digital Input
    BpodSystem.FlexIOConfig.channelTypes = channelTypes;

    sniffDetector = SniffDetector(chanSniff, 500);
    sniffDetector.configure(S.GUI.SniffOnsetThreshold, S.GUI.SniffOffsetThreshold);

    BpodSystem.startAnalogViewer;
    flexioPos = get(BpodSystem.GUIHandles.OscopeFig_Builtin, 'Position');
    flexioPos(1:2) = [30, 65];
    set(BpodSystem.GUIHandles.OscopeFig_Builtin, 'Position', flexioPos);

    %% Assert modules are USB-paired
    BpodSystem.assertModule({'RotaryEncoder'}, [1]);
    R = RotaryEncoderModule(BpodSystem.ModuleUSB.RotaryEncoder1);

    if BpodSystem.Modules.HWVersion_Major(strcmp(BpodSystem.Modules.Name, 'RotaryEncoder1')) < 2
        error('Error: This protocol requires rotary encoder module v2 or newer');
    end

    %% Setup Rotary Encoder module
    R.useAdvancedThresholds = 'off';
    R.startUSBStream;
    BpodSystem.ProtocolFigures.EncoderPlotFig = figure('Position', [1400 1035 350 350], 'name', 'Encoder plot', ...
        'numbertitle', 'off', 'MenuBar', 'none', 'Resize', 'off');
    BpodSystem.GUIHandles.EncoderAxes = axes('Position', [.15 .15 .8 .8]);
    liveEncoderPlot_hf_sleep(BpodSystem.GUIHandles.EncoderAxes, 'init', 0);

    %% Prepare and start first trial
    trialManager = BpodTrialManager;
    sessionStartTic = tic;
    [sma, ~, currentActions] = PrepareStateMachine(S, trialTypes, 1, stimTime, ITI, sessionStartTic);
    sessionStart = datestr(datetime('now'), 'yyyy-mm-dd HH:MM:SS');
    repoDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    [~, gitHash] = system(['git -C "' repoDir '" rev-parse HEAD']);
    BpodSystem.Data.GitHash = strtrim(gitHash);
    trialManager.startTrial(sma);

    %% Main trial loop
    for currentTrial = 1:S.GUI.maxTrials
        try
            t1 = tic;
            S = LuminoseParameterGUI_hf_sleep('sync', S);

            currentTrialType = trialTypes(currentTrial);
            disp(['calculated next trial: ', num2str(toc(t1))]);

            handle_pause_condition(R);

            if currentTrial < S.GUI.maxTrials
                [sma, S, nextActions] = PrepareStateMachine(S, trialTypes, currentTrial+1, stimTime, ITI, sessionStartTic);
                disp(['Session: ', sessionStart, ' | Trial: ', num2str(currentTrial)]);
                SendStateMachine(sma, 'RunASAP');
            end

            RawEvents = trialManager.getTrialData;
            handle_pause_condition(R);

            if currentTrial < S.GUI.maxTrials
                trialManager.startTrial();
            end

            if ~isempty(fieldnames(RawEvents))
                BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
                BpodSystem.Data.TrialSettings(currentTrial).GUI = S.GUI;
                BpodSystem.Data.TrialTypes(currentTrial) = currentTrialType;
                BpodSystem.Data.RawEvents.Trial{currentTrial}.Actions = currentActions;
                BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data);

                % Save rotary encoder data
                if currentTrial == 1
                    eventData = R.readUSBStream(0);
                    if ~isempty(eventData.EventTimestamps)
                        TrialStartTime = eventData.EventTimestamps(1);
                    else
                        TrialStartTime = 0;
                    end
                end
                BpodSystem.Data.EncoderData{currentTrial} = R.readUSBStream(0);

                %% Update plots
                t3 = tic;
                if currentTrial == 1
                    if ~isempty(BpodSystem.Data.EncoderData{currentTrial}.EventTimestamps)
                        NextTrialStartTime = BpodSystem.Data.EncoderData{currentTrial}.EventTimestamps(1);
                    else
                        NextTrialStartTime = TrialStartTime;
                    end
                else
                    TrialStartTime = NextTrialStartTime;
                    if ~isempty(BpodSystem.Data.EncoderData{currentTrial}.EventTimestamps)
                        NextTrialStartTime = BpodSystem.Data.EncoderData{currentTrial}.EventTimestamps(1);
                    end
                end
                BpodSystem.Data.EncoderData{currentTrial}.Times = BpodSystem.Data.EncoderData{currentTrial}.Times - TrialStartTime;
                BpodSystem.Data.EncoderData{currentTrial}.EventTimestamps = ...
                    BpodSystem.Data.EncoderData{currentTrial}.EventTimestamps - TrialStartTime;

                TrialDuration = BpodSystem.Data.TrialEndTimestamp(currentTrial) - BpodSystem.Data.TrialStartTimestamp(currentTrial);
                liveEncoderPlot_hf_sleep(BpodSystem.GUIHandles.EncoderAxes, 'update', 0, BpodSystem.Data.EncoderData{currentTrial}, TrialDuration);
                disp(['Updated rotary encoder plot: ', num2str(toc(t3))]);

                t4 = tic;
                if mod(currentTrial, 5) == 0, SaveBpodSessionData; end
                disp(['Saved data: ', num2str(toc(t4))]);
            end
            if currentTrial < S.GUI.maxTrials
                currentActions = nextActions;
            end
        catch ME
            BpodSystem.Data.StoppedReason = lhf.stopRecord('error', currentTrial, ME);
            disp('=== CRASH ===');
            disp(ME.message);
            for iStack = 1:length(ME.stack)
                disp(['  ', ME.stack(iStack).name, ' line ', num2str(ME.stack(iStack).line)]);
            end
            break
        end
    end
    if ~isfield(BpodSystem.Data, 'StoppedReason')
        if BpodSystem.Status.BeingUsed == 0
            BpodSystem.Data.StoppedReason = lhf.stopRecord('operator', currentTrial);
        else
            BpodSystem.Data.StoppedReason = lhf.stopRecord('completed', S.GUI.maxTrials);
        end
    end
end

%% State machine
function [sma, S, actions] = PrepareStateMachine(S, trialTypes, currentTrial, stimTime, ITI, sessionStartTic)
    global BpodSystem

    onsetDelay = max(0, 1 - toc(sessionStartTic));

    % SelectedPatternRow for each pattern type
    for tCell = {'CSplus', 'CSminus', 'opto'}
        t = tCell{1};
        probField = sprintf('patternProbs_%s', t);
        if isfield(S.GUI, probField)
            probs = max(S.GUI.(probField), 0);
            if sum(probs) > 0
                rIdx = find(rand() <= cumsum(probs/sum(probs)), 1);
            else, rIdx = 1; end
            if ~isfield(BpodSystem.PluginObjects, 'SelectedPatternRow')
                BpodSystem.PluginObjects.SelectedPatternRow = struct(); end
            BpodSystem.PluginObjects.SelectedPatternRow.(t) = rIdx;
        end
    end

    startAction = {'GlobalTimerTrig', 1, 'RotaryEncoder1', ['#' 0], 'AnalogThreshEnable', 1};
    sniffAction = {'RotaryEncoder1', '*Z'};
    stimAction = {'BNC1', 1};
    if S.GUI.TestPulses
        stimAction{end+1} = 'SoftCode'; stimAction{end+1} = 12;
        stimAction{end+1} = 'PWM3'; stimAction{end+1} = S.GUI.Intensity_mask;
        chooseState1 = 'GetSniff';
        trialStartTimer = ITI(currentTrial);
    else
        chooseState1 = 'InterTrialInterval';
        trialStartTimer = ITI(currentTrial) / 2;
    end

    if currentTrial == 1
        sma = NewStateMachine();
        sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', 18000, ...
            'OnsetDelay', onsetDelay, 'Channel', 'PWM5', 'OnMessage', 255, ...
            'OffMessage', 0, 'Loop', 0, 'SendGlobalTimerEvents', 0, 'LoopInterval', 0);
        % unique barcode sent to identify protocol in first trial
        sma = AddState(sma, 'Name', 'Barcode1', ...
            'Timer', normrnd(S.GUI.muBarcodeDur, S.GUI.sigmaBarcodeDur), ...
            'StateChangeConditions', {'Tup', 'Barcode2'}, ...
            'OutputActions', {'BNC1', 1, 'GlobalTimerTrig', 1});
        sma = AddState(sma, 'Name', 'Barcode2', ...
            'Timer', normrnd(S.GUI.muBarcodeDur, S.GUI.sigmaBarcodeDur), ...
            'StateChangeConditions', {'Tup', 'Barcode3'}, ...
            'OutputActions', {'BNC1', 0});
        sma = AddState(sma, 'Name', 'Barcode3', ...
            'Timer', normrnd(S.GUI.muBarcodeDur, S.GUI.sigmaBarcodeDur), ...
            'StateChangeConditions', {'Tup', 'Barcode4'}, ...
            'OutputActions', {'BNC1', 1});
        sma = AddState(sma, 'Name', 'Barcode4', ...
            'Timer', normrnd(S.GUI.muBarcodeDur, S.GUI.sigmaBarcodeDur), ...
            'StateChangeConditions', {'Tup', 'Barcode5'}, ...
            'OutputActions', {'BNC1', 0});
        sma = AddState(sma, 'Name', 'Barcode5', ...
            'Timer', normrnd(S.GUI.muBarcodeDur, S.GUI.sigmaBarcodeDur), ...
            'StateChangeConditions', {'Tup', 'TrialStart'}, ...
            'OutputActions', {'BNC1', 1});
    else
        sma = NewStateMachine();
        sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', 18000, ...
            'OnsetDelay', onsetDelay, 'Channel', 'PWM5', 'OnMessage', 255, ...
            'OffMessage', 0, 'Loop', 0, 'SendGlobalTimerEvents', 0, 'LoopInterval', 0);
    end
    sma = AddState(sma, 'Name', 'TrialStart', ...
        'Timer', trialStartTimer, ...
        'StateChangeConditions', {'Tup', chooseState1}, ...
        'OutputActions', startAction);
    sma = AddState(sma, 'Name', 'GetSniff', ...
        'Timer', 0, ...
        'StateChangeConditions', {'Flex1Trig1', 'DeliverStim'}, ...
        'OutputActions', sniffAction);
    sma = AddState(sma, 'Name', 'DeliverStim', ...
        'Timer', stimTime, ...
        'StateChangeConditions', {'Tup', 'exit'}, ...
        'OutputActions', stimAction);
    sma = AddState(sma, 'Name', 'InterTrialInterval', ...
        'Timer', ITI(currentTrial) / 2, ...
        'StateChangeConditions', {'Tup', 'exit'}, ...
        'OutputActions', {'BNC1', 1});

    actions = struct();
    actions.TrialStart  = startAction;
    actions.GetSniff    = sniffAction;
    actions.DeliverStim = stimAction;
    actions.ITI = {'BNC1', 1};
end

%% Handle pause condition
function handle_pause_condition(R)
    global BpodSystem
    HandlePauseCondition;
    if BpodSystem.Status.BeingUsed == 0
        R.stopUSBStream;
        return
    end
end

%% Cleanup
function cleanup()
    global BpodSystem S luminose sniffDetector %#ok<NUSED>
    BpodSystem.Data.luminose = luminose;
    BpodSystem.Data.GUIMeta = S.GUIMeta;
    BpodSystem.ProtocolSettings = S;
    if ~isfield(BpodSystem.Data, 'StoppedReason')
        BpodSystem.Data.StoppedReason = lhf.stopRecord('unknown', NaN);  % setup error or Ctrl+C
    end
    SaveBpodSessionData;
    SaveBpodProtocolSettings;
    diary off;
    if BpodSystem.Status.BeingUsed == 1
        RunProtocol('Stop');
    end
    % With BpodSystem listed in the base workspace, MATLAB's Workspace browser
    % works through every change the session made to it once the prompt
    % returns, and can run MATLAB out of memory (seen in LuminoseFM).
    evalin('base', 'clear BpodSystem');
end

function restorePatternParams(typeNames, patternsFolder)
    global S BpodSystem
    patternsFolder = char(patternsFolder);
    for i = 1:numel(typeNames)
        t = typeNames{i};
        allMetas = dir(fullfile(patternsFolder, sprintf('designed_%s_*_meta.mat', t)));
        if isempty(allMetas), continue; end
        isRowFile = arrayfun(@(m) ~isempty(regexp(m.name, ...
            sprintf('designed_%s_r\\d+_', t), 'once')), allMetas);
        rowMetas    = allMetas(isRowFile);
        legacyMetas = allMetas(~isRowFile);
        rowIndices = [];
        for j = 1:numel(rowMetas)
            tok = regexp(rowMetas(j).name, sprintf('designed_%s_r(\\d+)_', t), 'tokens', 'once');
            if ~isempty(tok), rowIndices(end+1) = str2double(tok{1}); end %#ok<AGROW>
        end
        rowIndices = unique(rowIndices);
        if ~ismember(1, rowIndices) && ~isempty(legacyMetas)
            rowIndices = [1, rowIndices];
        end
        if isempty(rowIndices), continue; end
        maxRow  = max(rowIndices);
        nFVec   = S.GUI.(sprintf('patternNFrames_%s',  t));
        expVec  = S.GUI.(sprintf('patternExposure_%s', t));
        probVec = S.GUI.(sprintf('patternProbs_%s',    t));
        while numel(nFVec)   < maxRow, nFVec(end+1)   = 1;   end
        while numel(expVec)  < maxRow, expVec(end+1)  = 1e6; end
        while numel(probVec) < maxRow, probVec(end+1) = 0;   end
        if ~isfield(BpodSystem.PluginObjects, 'PatternDesigns')
            BpodSystem.PluginObjects.PatternDesigns = struct(); end
        if ~isfield(BpodSystem.PluginObjects.PatternDesigns, t)
            BpodSystem.PluginObjects.PatternDesigns.(t) = {}; end
        for rowIdx = rowIndices
            rMetas = rowMetas(arrayfun(@(m) ~isempty(regexp(m.name, ...
                sprintf('designed_%s_r%d_', t, rowIdx), 'once')), rowMetas));
            if isempty(rMetas) && rowIdx == 1, rMetas = legacyMetas; end
            if isempty(rMetas), continue; end
            [~, newest] = max([rMetas.datenum]);
            try
                m = load(fullfile(patternsFolder, rMetas(newest).name));
                if ~isfield(m, 'tickMs'), continue; end
                if isfield(m, 'nF'), nF = m.nF;
                else, totalDur = max([m.spots.onset_ms] + [m.spots.dur_ms]);
                    nF = ceil(totalDur / m.tickMs); end
                nFVec(rowIdx)  = nF;
                expVec(rowIdx) = m.tickMs * 1000;
                BpodSystem.PluginObjects.PatternDesigns.(t){rowIdx} = ...
                    struct('spots', m.spots, 'tickMs', m.tickMs, 'r_px', m.r_px, 'nF', nF);
                fprintf('Restored %s row %d: %d frames, tick=%.1fms\n', t, rowIdx, nF, m.tickMs);
            catch
            end
        end
        probVec(:) = 1 / numel(probVec);
        S.GUI.(sprintf('patternNFrames_%s',  t)) = nFVec;
        S.GUI.(sprintf('patternExposure_%s', t)) = expVec;
        S.GUI.(sprintf('patternProbs_%s',    t)) = probVec;
    end
end

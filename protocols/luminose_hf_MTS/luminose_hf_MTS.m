function luminose_hf_MTS
    %% clear & setup
    clc;
    warning('off', 'MATLAB:HandleGraphics:ObsoleteProperty:JavaFrame');

    global BpodSystem S luminose olfModel sniffDetector
    luminose = LuminoseConstants();
    beep('off'); % native matlab error sounds OFF
    BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler_luminose_hf_MTS';

    olfWarmup = lhf.olf.startWorker(luminose.olfactometer);  % warms up while the GUI is open
    [dataDir, dataBasename, ~] = fileparts(BpodSystem.Path.CurrentDataFile);
    log_file = fullfile(dataDir, [regexprep(dataBasename, '_Session\d+$', '') '_log.txt']);
    diary(log_file);

    %% Configure trials
    % Defaults come from GUIparams; a saved settings file is merged into them
    % (renamed and retired settings: lhf.settingsHistory)
    saved = BpodSystem.ProtocolSettings;
    S = struct();
    GUIparams_luminose_hf_MTS();
    settingsNotes = {};
    if ~isstruct(saved) || isempty(fieldnames(saved))
        restorePatternParams({'cue', 'Template', 'Sample', 'opto'}, luminose.dmd.patternsFolder);
    else
        [S, settingsNotes] = lhf.mergeSettings(saved, S, 'MTS');
        cellfun(@(note) fprintf('Settings: %s\n', note), settingsNotes);
    end
    LuminoseParameterGUI_hf_MTS('init', S);
    disp('Waiting for START button...');
    setappdata(BpodSystem.ProtocolFigures.ParameterGUI, 'StartPressed', false);
    while ~getappdata(BpodSystem.ProtocolFigures.ParameterGUI, 'StartPressed')
        pause(0.1);
        if ~ishandle(BpodSystem.ProtocolFigures.ParameterGUI)
            return
        end
    end
    S.GUI = BpodSystem.GUIData.ParameterGUI.LatestGUIParams;
    S = LuminoseParameterGUI_hf_MTS('sync', S);
    disp('START pressed — beginning experiment.');
    lhf.olf.waitWorker(olfWarmup);  % one warmed-up worker for odour delivery
    sessionCleanup = onCleanup(@cleanup); %#ok<NASGU> runs on normal end and on any error
    BpodSystem.Data.SettingsNotes = settingsNotes;
    % One seed per session, recorded; S.RandomSeed (edit the settings file)
    % repeats a session's draws once, then is cleared
    requestedSeed = [];
    if isfield(S, 'RandomSeed'), requestedSeed = S.RandomSeed; end
    S.RandomSeed = [];
    BpodSystem.Data.RandomSeed = lhf.random('init', requestedSeed);
    info = lhf.protocolInfo('MTS');
    % Optional laser: connected only with Laser control ticked (Task tab)
    lhf.laser.open(S, luminose);

    BpodSystem.Data.TrialResponse = [];
    BpodSystem.Data.SniffInhalationOnset_s  = [];
    BpodSystem.Data.SniffInhalationOffset_s = [];
    BpodSystem.Data.TrialOutcome = [];

    nextTrialType = lhf.nextTrialType(BpodSystem.Data, lhf.trialPolicy(S.GUI, info), []);
    currentTrialType = nextTrialType;

    isHabituation = isfield(S.GUI, 'TrainingLevel') && (S.GUI.TrainingLevel == 1);
    if isHabituation
        ITI = repelem(0, S.GUI.maxTrials);
    else
        if S.GUI.VariableITI
            ITI = S.GUI.InterTrialInterval * (1.01 .^ (0:S.GUI.maxTrials-1));
            ITI(ITI > S.GUI.MaxITI) = S.GUI.MaxITI;
            ITI = ITI(randperm(lhf.random(), length(ITI)))';
            ITI = round(ITI * 1000) / 1000;
        else
            ITI = S.GUI.InterTrialInterval * ones(1, S.GUI.maxTrials);
        end
    end

    %% Begin plotting
    % All live plots share one window: one graphics canvas instead of five
    [BpodSystem.ProtocolFigures.LivePlots, plotAxes] = lhf.plot.createFigure();
    lhf.plot.outcome(plotAxes.Outcome, 'init', info, currentTrialType);
    lhf.plot.accuracy(plotAxes.Accuracy, 'init', info);
    lhf.plot.reward(plotAxes.Reward, 'init');
    lhf.plot.responseTime(plotAxes.Response, 'init');
    lhf.plot.encoder(plotAxes.Encoder, 'init', 0);

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
    BpodSystem.assertModule({'HiFi','RotaryEncoder'}, [1 1]);

    H = BpodHiFi(BpodSystem.ModuleUSB.HiFi1);
    R = RotaryEncoderModule(BpodSystem.ModuleUSB.RotaryEncoder1);

    if BpodSystem.Modules.HWVersion_Major(strcmp(BpodSystem.Modules.Name, 'RotaryEncoder1')) < 2
        error('Error: This protocol requires rotary encoder module v2 or newer');
    end

    %% Setup sound
    sf = 192000;
    H.SamplingRate = sf;
    errorSound = GenerateWhiteNoise(sf, S.GUI.NoiseTime, 1, 2);
    H.load(1, errorSound);
    cueSound = GenerateSineWave(sf, S.GUI.Freq_cue, S.GUI.SoundDuration_cue);
    H.load(2, cueSound);
    TimeSoundTemplate = 0:1/sf:S.GUI.SoundDuration_Template;
    TemplateSound = chirp(TimeSoundTemplate, S.GUI.LowFreq_Template, S.GUI.SoundDuration_Template, S.GUI.HighFreq_Template);
    H.load(3, TemplateSound);
    TimeSoundSample = 0:1/sf:S.GUI.SoundDuration_Sample;
    SampleSound = chirp(TimeSoundSample, S.GUI.LowFreq_Sample, S.GUI.SoundDuration_Sample, S.GUI.HighFreq_Sample);
    H.load(4, SampleSound);

    H.HeadphoneAmpEnabled = true; H.HeadphoneAmpGain = 63;
    H.DigitalAttenuation_dB = -60;
    H.push;

    Envelope = 1/(H.SamplingRate*0.001):1/(H.SamplingRate*0.001):1;
    H.AMenvelope = Envelope;

    %% Setup Rotary Encoder module
    if strcmp(S.GUIMeta.ResponseType.String(S.GUI.ResponseType), 'Rotary Encoder')
        R.useAdvancedThresholds = 'on';
        R.setAdvancedThresholds([-35 10 10], [0 1 1], [0 S.GUI.ResponseTime 0.2]);
        R.sendThresholdEvents = 'on';
    else
        R.useAdvancedThresholds = 'off';
    end
    R.startUSBStream;

    %% Prepare and start first trial
    saveOnlinePlotsOnClose();
    trialManager = BpodTrialManager;
    [sma, ~, currentActions] = PrepareStateMachine(S, currentTrialType, 1, ITI);
    dmd_hf_MTS('prepare', dmdSoftCodes(sma));
    dmd_hf_MTS('advance');
    BpodSystem.PluginObjects.SelectedOdourRow = BpodSystem.PluginObjects.NextOdourRow;
    sessionStart = datestr(datetime('now'), 'yyyy-mm-dd HH:MM:SS');
    repoDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    [~, gitHash] = system(['git -C "' repoDir '" rev-parse HEAD']);
    BpodSystem.Data.GitHash = strtrim(gitHash);
    trialManager.startTrial(sma);

    %% Main trial loop
    for currentTrial = 1:S.GUI.maxTrials
        try
            t1 = tic;
            S = LuminoseParameterGUI_hf_MTS('sync', S);

            currentTrialType = nextTrialType;

            if handle_pause_condition(H, R), BpodSystem.Data.StoppedReason = lhf.stopRecord('operator', currentTrial); break; end

            if currentTrial < S.GUI.maxTrials
                nextTrialType = lhf.nextTrialType(BpodSystem.Data, lhf.trialPolicy(S.GUI, info), currentTrialType);
                [sma, S, nextActions] = PrepareStateMachine(S, nextTrialType, currentTrial+1, ITI);
                dmd_hf_MTS('prepare', dmdSoftCodes(sma));
                disp(['Session: ', sessionStart, ' | Trial: ', num2str(currentTrial)]);
                SendStateMachine(sma, 'RunASAP');
            end

            RawEvents = trialManager.getTrialData;
            dmd_hf_MTS('advance');
            BpodSystem.PluginObjects.SelectedOdourRow = BpodSystem.PluginObjects.NextOdourRow;  % odour rows of the trial now starting
            if handle_pause_condition(H, R), BpodSystem.Data.StoppedReason = lhf.stopRecord('operator', currentTrial); break; end

            t2 = tic;
            if strcmp(S.GUIMeta.ResponseType.String(S.GUI.ResponseType), 'Rotary Encoder')
                R.setAdvancedThresholds([-35 10 10], [0 1 1], [0 S.GUI.ResponseTime 0.2]);
            end
            disp(['set RE: ', num2str(toc(t2))]);

            if currentTrial < S.GUI.maxTrials
                trialManager.startTrial();
            end

            if ~isempty(fieldnames(RawEvents))
                BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
                BpodSystem.Data.TrialSettings(currentTrial).GUI = S.GUI;
                BpodSystem.Data.RawEvents.Trial{currentTrial}.Actions = currentActions;
                BpodSystem.Data.TrialTypes(currentTrial) = currentTrialType;
                BpodSystem.Data.LaserIrradiance_mWmm2(currentTrial) = currentActions.LaserIrradiance_mWmm2;
                BpodSystem.Data.LaserSetpoint_mW(currentTrial) = currentActions.LaserSetpoint_mW;

                processedEvents = BpodSystem.Data.RawEvents.Trial{currentTrial};
                BpodSystem.Data.SniffInhalationOnset_s(currentTrial)  = sniffDetector.getOnset(processedEvents);
                BpodSystem.Data.SniffInhalationOffset_s(currentTrial) = sniffDetector.getOffset(processedEvents);
                disp(['Sniff onset: ' num2str(BpodSystem.Data.SniffInhalationOnset_s(currentTrial), '%.3f') ...
                      ' s  offset: ' num2str(BpodSystem.Data.SniffInhalationOffset_s(currentTrial), '%.3f') ' s']);

                [BpodSystem.Data.TrialOutcome(currentTrial), BpodSystem.Data.TrialResponse(currentTrial)] = ...
                    lhf.scoreTrial(BpodSystem.Data.RawEvents.Trial{currentTrial}, currentTrialType, info.task);

                BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data);

                if currentTrial == 1
                    eventData = R.readUSBStream(0);
                    if ~isempty(eventData.EventTimestamps)
                        TrialStartTime = eventData.EventTimestamps(1);
                    else
                        TrialStartTime = 0;
                    end
                end
                BpodSystem.Data.EncoderData{currentTrial} = R.readUSBStream(0);

                t3 = tic;
                lhf.plot.outcome(plotAxes.Outcome, 'update', BpodSystem.Data, nextTrialType);
                disp(['Updated outcome plot: ', num2str(toc(t3))]);

                t4 = tic;
                lhf.plot.accuracy(plotAxes.Accuracy, 'update', BpodSystem.Data);
                disp(['Updated accuracy plot: ', num2str(toc(t4))]);

                t5 = tic;
                lhf.plot.reward(plotAxes.Reward, 'update', BpodSystem.Data);
                disp(['Updated reward plot: ', num2str(toc(t5))]);

                t6 = tic;
                lhf.plot.responseTime(plotAxes.Response, 'update', BpodSystem.Data);
                disp(['Updated response time plot: ', num2str(toc(t6))]);

                t7 = tic;
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
                lhf.plot.encoder(plotAxes.Encoder, 'update', 0, BpodSystem.Data.EncoderData{currentTrial}, TrialDuration);
                disp(['Updated rotary encoder plot: ', num2str(toc(t7))]);
                drawnow nocallbacks  % one redraw of the live-plot window per trial

                t8 = tic;
                if mod(currentTrial, 5) == 0, SaveBpodSessionData; end
                disp(['Saved data: ', num2str(toc(t8))]);
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
        BpodSystem.Data.StoppedReason = lhf.stopRecord('completed', S.GUI.maxTrials);
    end
end

%% State machine
function [sma, S, actions] = PrepareStateMachine(S, currentTrialType, currentTrial, ITI)
    global BpodSystem luminose
    for tCell = {'cue', 'Template', 'Sample', 'opto'}
        t = tCell{1};
        probField = sprintf('patternProbs_%s', t);
        if isfield(S.GUI, probField)
            probs = S.GUI.(probField);
            probs = max(probs, 0);
            if sum(probs) > 0
                rowIdx = find(rand() <= cumsum(probs/sum(probs)), 1);
            else
                rowIdx = 1;
            end
            if ~isfield(BpodSystem.PluginObjects, 'SelectedPatternRow')
                BpodSystem.PluginObjects.SelectedPatternRow = struct();
            end
            BpodSystem.PluginObjects.SelectedPatternRow.(t) = rowIdx;
        end
    end
    % Odour rows of this trial, drawn now so its states are timed by them
    % (the Template and Sample rows are drawn by buildTemplateAction and
    % buildSampleAction)
    BpodSystem.PluginObjects.NextOdourRow = lhf.olf.drawRows(S.GUI, {'cue'});
    cue = S.GUIMeta.CueType.String{S.GUI.CueType};
    response = S.GUIMeta.ResponseType.String{S.GUI.ResponseType};

    startAction = {'BNC1', 1, 'HiFi1', '*', 'RotaryEncoder1', ['#' 0], 'AnalogThreshEnable', 1};
    cueAction = {'RotaryEncoder1', '*Z'}; % one-shot, fired only at Template onset
    cueHoldAction = {}; % level output re-asserted every state so it doesn't drop out
    stimTemplateAction = {'BNC1', 1}; % sync
    stimMatchAction = {'BNC1', 1}; % sync
    delayAction = {};
    isPatternResponse = false;
    isHabituation = isfield(S.GUI, 'TrainingLevel') && (S.GUI.TrainingLevel == 1);
    if isHabituation
        chooseState2 = 'GetResponse';
        chooseStateMatch = 'GetResponse';
        tupAction = 'GetResponse';
        switch currentTrialType
            case 1 % Match
                leftAction = 'Reward'; rightAction = 'GetResponse';
            case 2 % Non-match
                rightAction = 'Reward'; leftAction = 'GetResponse';
        end
    else
        switch cue
            case 'Odour'
                cueHoldAction = {'BNC2', 1};
                startAction{end+1} = 'SoftCode'; startAction{end+1} = 1;
            case 'Pattern'
                cueHoldAction = {'PWM3', S.GUI.Intensity_cue}; % mask
                cueAction{end+1} = 'SoftCode'; cueAction{end+1} = 8;
            case 'Light'
                cueHoldAction = {'PWM3', S.GUI.Intensity_cue};
            case 'Sound'
                cueAction{end+1} = 'HiFi1'; cueAction{end+1} = ['P', 1];
        end

        % Template row/action is drawn fresh each trial (Odour: weighted
        % row draw; Pattern: precomputed above; Light/Sound: single
        % configured value). On Match, the sample is a verbatim replay of
        % the template's own action/code. On Non-match, the sample is
        % drawn via buildSampleAction (for Odour, restricted to the Sample
        % rows checked for this trial's template row).
        [templateAction, templateCode, templateNeedsSniff, templateRowIdx] = buildTemplateAction(S);
        % Cue turns on here (Template onset) rather than in a separate
        % leading state. cueHoldAction (the level-type output — BNC2 for
        % Odour, PWM3 for Light/Pattern) is explicitly re-asserted in Delay
        % and Sample below too, since Bpod does not reliably hold it across
        % states on its own.
        stimTemplateAction = [stimTemplateAction, cueAction, cueHoldAction, templateAction];
        if templateCode == 9
            % Pattern: SoftCode displays immediately (MASTER mode) —
            % fire it in the same state as the pattern itself.
            stimTemplateAction{end+1} = 'SoftCode'; stimTemplateAction{end+1} = templateCode;
        elseif templateCode > 0
            % Odour: dispatch ahead of time so the async valve sequence
            % (parfeval) has lead time before DeliverStimTemplate.
            startAction{end+1} = 'SoftCode'; startAction{end+1} = templateCode;
        end
        if templateNeedsSniff && S.GUI.SniffTrigger, chooseState2 = 'GetSniffTemplate'; else, chooseState2 = 'DeliverStimTemplate'; end

        switch currentTrialType
            case 1 % Match
                sampleAction = templateAction;
                sampleCode = templateCode;
                sampleNeedsSniff = templateNeedsSniff;
            case 2 % Non-match
                [sampleAction, sampleCode, sampleNeedsSniff] = buildSampleAction(S, templateRowIdx);
        end
        stimMatchAction = [stimMatchAction, cueHoldAction, sampleAction];
        delayAction = [delayAction, cueHoldAction];
        if sampleCode == 9 || sampleCode == 10
            % Pattern (replayed Template code 9 on Match, or Sample code 10
            % on Non-match): SoftCode displays immediately (MASTER mode) —
            % fire it in the same state as the pattern itself.
            stimMatchAction{end+1} = 'SoftCode'; stimMatchAction{end+1} = sampleCode;
            isPatternResponse = true;
        elseif sampleCode > 0
            % Odour: dispatch ahead of time so the async valve sequence
            % (parfeval) has lead time before DeliverStimMatch.
            delayAction = [delayAction, {'SoftCode', sampleCode}];
        end
        if sampleNeedsSniff && S.GUI.SniffTrigger, chooseStateMatch = 'GetSniffMatch'; else, chooseStateMatch = 'DeliverStimMatch'; end

        switch currentTrialType
            case 1 % Match
                leftAction = 'Reward';
                if S.GUI.Punishment
                    rightAction = 'Punishment'; tupAction = 'Punishment';
                else
                    rightAction = 'GetResponse'; tupAction = 'InterTrialInterval';
                end
            case 2 % Non-match
                rightAction = 'Reward';
                if S.GUI.Punishment
                    leftAction = 'Punishment'; tupAction = 'Punishment';
                else
                    leftAction = 'GetResponse'; tupAction = 'InterTrialInterval';
                end
        end
    end
    responseDetect = {};
    responseAction = {};
    switch response
        case 'Lick'
            responseDetect = {'BNC1High', leftAction, 'BNC2High', rightAction, 'Tup', tupAction};
            chooseState1 = chooseState2;
        case 'Rotary Encoder'
            responseDetect = {'RotaryEncoder1_1', leftAction, 'RotaryEncoder1_2', rightAction, 'Tup', tupAction};
            chooseState1 = 'InitRE';
            responseAction{end+1} = 'RotaryEncoder1'; responseAction{end+1} = ['Z;' 3];
    end
    if isPatternResponse
        responseAction{end+1} = 'PWM3'; responseAction{end+1} = S.GUI.Intensity_cue;
    end
    responseAction{end+1} = 'SoftCode'; responseAction{end+1} = 11;
    valveTimeLeft = GetValveTimes(S.GUI.RewardAmount, 1);
    valveTimeRight = GetValveTimes(S.GUI.RewardAmount, 2);
    if currentTrialType == 1, valveTime = valveTimeLeft; rewardAction = {'Valve1', 1, 'BNC1', 1};
    else, valveTime = valveTimeRight; rewardAction = {'Valve4', 1, 'BNC1', 1}; end

    if S.GUI.NoiseTime ~= 0
        punishAction = {'HiFi1', ['P', 0], 'BNC1', 1};
    else
        punishAction = {'BNC1', 1};
    end

    % Laser power for this trial (with Laser control ticked): drawn from the
    % design of the first pattern it shows: the Template's, or on a
    % Non-match trial with a pattern Sample only, the Sample's
    laserType = 'Template';
    laserDesign = [];
    if strcmp(S.GUIMeta.TemplateType.String{S.GUI.TemplateType}, 'Pattern')
        laserDesign = lhf.selectedDesign('Template');
    elseif currentTrialType == 2 && strcmp(S.GUIMeta.SampleType.String{S.GUI.SampleType}, 'Pattern')
        laserType = 'Sample';
        laserDesign = lhf.selectedDesign('Sample');
    end
    [irradiance, setpoint, laserAction] = lhf.laser.draw(laserDesign, laserType, S, luminose);

    % Each stimulus lasts as long as its kind says (lhf.stimDuration): a
    % pattern its design, an odour its sequence, light and sound their
    % panel. A Match trial replays the Template.
    templateKind = S.GUIMeta.TemplateType.String{S.GUI.TemplateType};
    templateStimTime = lhf.stimDuration(S.GUI, templateKind, 'Template');
    if currentTrialType == 1
        matchStimTime = templateStimTime;
    else
        matchStimTime = lhf.stimDuration(S.GUI, S.GUIMeta.SampleType.String{S.GUI.SampleType}, 'Sample');
    end

    if currentTrial == 1
        sma = NewStateMachine();
        sma = AddState(sma, 'Name', 'Barcode1', ...
            'Timer', normrnd(S.GUI.muBarcodeDur, S.GUI.sigmaBarcodeDur), ...
            'StateChangeConditions', {'Tup', 'Barcode2'}, ...
            'OutputActions', {'BNC1', 1});
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
            'StateChangeConditions', {'Tup', 'SetLaserPower'}, ...
            'OutputActions', {'BNC1', 0});
    else
        sma = NewStateMachine();
    end
    sma = AddState(sma, 'Name', 'SetLaserPower', ...
        'Timer', 0, ...
        'StateChangeConditions', {'Tup', 'TrialStart'}, ...
        'OutputActions', laserAction);
    sma = AddState(sma, 'Name', 'TrialStart', ...
        'Timer', ITI(currentTrial)/2, ...
        'StateChangeConditions', {'Tup', chooseState1}, ...
        'OutputActions', startAction);
    sma = AddState(sma, 'Name', 'InitRE', ...
        'Timer', 0.2, ...
        'StateChangeConditions', {'RotaryEncoder1_3', chooseState2, 'RotaryEncoder1_4', chooseState2}, ...
        'OutputActions', {'RotaryEncoder1', [';' 4]});
    sma = AddState(sma, 'Name', 'GetSniffTemplate', ...
        'Timer', 0, ...
        'StateChangeConditions', {'Flex1Trig1', 'DeliverStimTemplate'}, ...
        'OutputActions', {'PWM3', S.GUI.Intensity_cue});
    sma = AddState(sma, 'Name', 'DeliverStimTemplate', ...
        'Timer', templateStimTime, ...
        'StateChangeConditions', {'Tup', 'Delay'}, ...
        'OutputActions', stimTemplateAction);
    sma = AddState(sma, 'Name', 'Delay', ...
        'Timer', S.GUI.Delay, ...
        'StateChangeConditions', {'Tup', chooseStateMatch}, ...
        'OutputActions', delayAction);
    sma = AddState(sma, 'Name', 'GetSniffMatch', ...
        'Timer', 0, ...
        'StateChangeConditions', {'Flex1Trig1', 'DeliverStimMatch'}, ...
        'OutputActions', cueHoldAction);
    sma = AddState(sma, 'Name', 'DeliverStimMatch', ...
        'Timer', matchStimTime, ...
        'StateChangeConditions', {'Tup', 'GetResponse'}, ...
        'OutputActions', stimMatchAction);
    sma = AddState(sma, 'Name', 'GetResponse', ...
        'Timer', S.GUI.ResponseTime, ...
        'StateChangeConditions', responseDetect, ...
        'OutputActions', responseAction);
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', valveTime, ...
        'StateChangeConditions', {'Tup', 'InterTrialInterval'}, ...
        'OutputActions', rewardAction);
    sma = AddState(sma, 'Name', 'Punishment', ...
        'Timer', S.GUI.NoiseTime, ...
        'StateChangeConditions', {'Tup', 'TimeOut'}, ...
        'OutputActions', punishAction);
    sma = AddState(sma, 'Name', 'TimeOut', ...
        'Timer', S.GUI.ErrorDelay - S.GUI.NoiseTime, ...
        'StateChangeConditions', {'Tup', 'InterTrialInterval'}, ...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'InterTrialInterval', ...
        'Timer', ITI(currentTrial)/2, ...
        'StateChangeConditions', {'Tup', 'exit'}, ...
        'OutputActions', {});

    actions = struct();
    actions.TrialStart         = startAction;
    actions.DeliverStimTemplate = stimTemplateAction;
    actions.DeliverStimMatch   = stimMatchAction;
    actions.GetResponse        = responseAction;
    actions.Reward             = rewardAction;
    actions.Punishment         = punishAction;
    actions.RewardValveTime    = valveTime;
    actions.SetLaserPower = laserAction;
    actions.LaserIrradiance_mWmm2 = irradiance;  % NaN when no power was set
    actions.LaserSetpoint_mW      = setpoint;
end

function [action, code, needsSniff, rowIdx] = buildTemplateAction(S)
% buildTemplateAction returns the OutputActions cell, SoftCode (0 if
% none), whether a sniff-onset wait is required, and the selected row
% index (meaningful for Odour/Pattern; 1 otherwise) for delivering the
% Template stimulus per its configured modality. SoftCode 2 = Template
% Odour, SoftCode 9 = Template Pattern (see SoftCodeHandler_luminose_hf_MTS.m
% / dmd_hf_MTS.m / lhf.olf.resolve). rowIdx is reused by
% buildSampleAction's per-template checkbox lookup, and the action/code
% are replayed verbatim by PrepareStateMachine on Match trials.
    global BpodSystem
    Type = S.GUIMeta.TemplateType.String{S.GUI.TemplateType};
    action = {};
    code = 0;
    needsSniff = false;
    rowIdx = 1;
    switch Type
        case 'Odour'
            action = {'BNC2', 1};
            code = 2;
            rowIdx = drawWeightedRow(S.GUI.probs_Template);
            BpodSystem.PluginObjects.NextOdourRow.Template = rowIdx;
        case 'Pattern'
            action = {'PWM3', S.GUI.Intensity_cue}; % mask
            code = 9;
            needsSniff = true;
            if isfield(BpodSystem.PluginObjects, 'SelectedPatternRow') && ...
               isfield(BpodSystem.PluginObjects.SelectedPatternRow, 'Template')
                rowIdx = BpodSystem.PluginObjects.SelectedPatternRow.Template;
            end
        case 'Light'
            action = {'PWM1', S.GUI.Intensity_Template};
        case 'Sound'
            action = {'HiFi1', ['P', 2]};
    end
end

function [action, code, needsSniff] = buildSampleAction(S, templateRowIdx)
% buildSampleAction returns the OutputActions cell, SoftCode (0 if none),
% and whether a sniff-onset wait is required, for delivering the Sample
% stimulus on a Non-match trial. SoftCode 3 = Sample Odour, SoftCode 10 =
% Sample Pattern. For Odour, the delivered row is drawn uniformly from
% the Sample rows checked for templateRowIdx in 'templateMask_Sample'
% (falling back to all rows if none are checked for that column).
    global BpodSystem
    Type = S.GUIMeta.SampleType.String{S.GUI.SampleType};
    action = {};
    code = 0;
    needsSniff = false;
    switch Type
        case 'Odour'
            action = {'BNC2', 1};
            code = 3;
            nRows = size(S.GUI.valves_Sample, 1);
            mask = S.GUI.templateMask_Sample;
            col = min(max(templateRowIdx, 1), size(mask, 2));
            candidates = find(mask(1:nRows, col));
            if isempty(candidates)
                candidates = 1:nRows;
            end
            rowIdx = candidates(randi(numel(candidates)));
            BpodSystem.PluginObjects.NextOdourRow.Sample = rowIdx;
        case 'Pattern'
            action = {'PWM3', S.GUI.Intensity_cue}; % mask
            code = 10;
            needsSniff = true;
        case 'Light'
            action = {'PWM4', S.GUI.Intensity_Sample};
        case 'Sound'
            action = {'HiFi1', ['P', 3]};
    end
end

function rowIdx = drawWeightedRow(weights)
    weights = max(weights, 0);
    if sum(weights) > 0
        rowIdx = find(rand() <= cumsum(weights/sum(weights)), 1);
    else
        rowIdx = 1;
    end
end

function shouldStop = handle_pause_condition(H, R)
    global BpodSystem
    HandlePauseCondition;
    shouldStop = (BpodSystem.Status.BeingUsed == 0);
    if shouldStop
        H.stop;
        R.stopUSBStream;
    end
end

function cleanup()
    global BpodSystem S luminose sniffDetector %#ok<NUSED>
    dmd_hf_MTS('close');
    lhf.laser.close();  % emission off, port freed (nothing to do with Laser control off)
    clear dmd_hf_MTS;
    BpodSystem.Data.luminose = luminose;
    BpodSystem.Data.GUIMeta = S.GUIMeta;
    BpodSystem.ProtocolSettings = S;
    if ~isfield(BpodSystem.Data, 'StoppedReason')
        BpodSystem.Data.StoppedReason = lhf.stopRecord('unknown', NaN);  % setup error or Ctrl+C
    end
    SaveBpodSessionData;
    SaveBpodProtocolSettings;
    lhf.report.write(BpodSystem.Data, lhf.protocolInfo('MTS'), BpodSystem.Path.CurrentDataFile);
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

        maxRow = max(rowIndices);
        nFVec   = S.GUI.(sprintf('patternNFrames_%s',  t));
        expVec  = S.GUI.(sprintf('patternExposure_%s', t));
        probVec = S.GUI.(sprintf('patternProbs_%s',    t));
        while numel(nFVec)   < maxRow, nFVec(end+1)   = 1;   end
        while numel(expVec)  < maxRow, expVec(end+1)  = 1e6; end
        while numel(probVec) < maxRow, probVec(end+1) = 0;   end

        if ~isfield(BpodSystem.PluginObjects, 'PatternDesigns')
            BpodSystem.PluginObjects.PatternDesigns = struct();
        end
        if ~isfield(BpodSystem.PluginObjects.PatternDesigns, t)
            BpodSystem.PluginObjects.PatternDesigns.(t) = {};
        end

        for rowIdx = rowIndices
            rMetas = rowMetas(arrayfun(@(m) ~isempty(regexp(m.name, ...
                sprintf('designed_%s_r%d_', t, rowIdx), 'once')), rowMetas));
            if isempty(rMetas) && rowIdx == 1
                rMetas = legacyMetas;
            end
            if isempty(rMetas), continue; end
            [~, newest] = max([rMetas.datenum]);
            try
                m = load(fullfile(patternsFolder, rMetas(newest).name));
                if ~isfield(m, 'tickMs'), continue; end
                if isfield(m, 'nF')
                    nF = m.nF;
                else
                    totalDur = max([m.spots.onset_ms] + [m.spots.dur_ms]);
                    nF = ceil(totalDur / m.tickMs);
                end
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

function saveOnlinePlotsOnClose()
    % Each plot is saved once, as its window closes (RunProtocol('Stop')
    % closes them all), rather than rendered to disk after every trial.
    global BpodSystem
    [savePath, sessionName] = fileparts(BpodSystem.Path.CurrentDataFile);
    figNames = {'LivePlots'};
    for i = 1:numel(figNames)
        if isfield(BpodSystem.ProtocolFigures, figNames{i})
            fname = fullfile(savePath, [sessionName '_' figNames{i} '.png']);
            set(BpodSystem.ProtocolFigures.(figNames{i}), 'CloseRequestFcn', @(fig, ~) saveAndClose(fig, fname));
        end
    end
end

function saveAndClose(fig, fname)
    try
        saveas(fig, fname);
    catch
        warning('Could not save %s', fname);
    end
    delete(fig);
end

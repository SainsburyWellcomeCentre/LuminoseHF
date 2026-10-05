function luminose_hf_powercal
    %% clear & setup
    clc;
    warning('off', 'MATLAB:HandleGraphics:ObsoleteProperty:JavaFrame');

    global BpodSystem S luminose sniffDetector
    luminose = LuminoseConstants();
    % powercal keeps its own CS+ and CS- designs in the shared folder, saved
    % as designed_powercalCSplus_* and designed_powercal_* so goNogo's
    % CSplus/CSminus files never reach it (cue and opto designs stay shared):
    % lhf.patternFileType
    luminose.dmd.typeFileNames = struct('CSplus', 'powercalCSplus', 'CSminus', 'powercal');
    beep('off'); % native matlab error sounds OFF
    BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler_luminose_hf_powercal';

    olfWarmup = lhf.olf.startWorker(luminose.olfactometer);  % warms up while the GUI is open
    [dataDir, dataBasename, ~] = fileparts(BpodSystem.Path.CurrentDataFile);
    log_file = fullfile(dataDir, [regexprep(dataBasename, '_Session\d+$', '') '_log.txt']);
    diary(log_file);

    %% Configure trials
    % Defaults come from GUIparams; a saved settings file is merged into them
    % (renamed and retired settings: lhf.settingsHistory)
    saved = BpodSystem.ProtocolSettings;
    S = struct();
    GUIparams_luminose_hf_powercal();
    settingsNotes = {};
    if ~isstruct(saved) || isempty(fieldnames(saved))
        restorePatternParams({'cue', 'CSplus', 'CSminus', 'opto'}, luminose.dmd);
    else
        [S, settingsNotes] = lhf.mergeSettings(saved, S, 'powercal');
        cellfun(@(note) fprintf('Settings: %s\n', note), settingsNotes);
    end
    S = loadPowercalDesigns(S, luminose.dmd);
    % Exposures and frame counts follow the designs, not the settings file
    designs = struct();
    if isfield(BpodSystem.PluginObjects, 'PatternDesigns'), designs = BpodSystem.PluginObjects.PatternDesigns; end
    S.GUI = lhf.patternTiming(S.GUI, designs, luminose.dmd, {'cue', 'CSplus', 'CSminus', 'opto'});
    LuminoseParameterGUI_hf_powercal('init', S);
    disp('Waiting for START button...');
    setappdata(BpodSystem.ProtocolFigures.ParameterGUI, 'StartPressed', false);
    while ~getappdata(BpodSystem.ProtocolFigures.ParameterGUI, 'StartPressed')
        pause(0.1);
        if ~ishandle(BpodSystem.ProtocolFigures.ParameterGUI)
            return
        end
    end
    S.GUI = BpodSystem.GUIData.ParameterGUI.LatestGUIParams;
    S = LuminoseParameterGUI_hf_powercal('sync', S);
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
    info = lhf.protocolInfo('powercal');

    %% Laser (optional): with Laser control ticked, each trial showing a
    % pattern sets the power drawn from that pattern's design (lhf.laser.draw,
    % soft code 13 at SetLaserPower); unticked, the laser is not connected.
    lhf.laser.open(S, luminose);

    BpodSystem.Data.TrialResponse = [];
    BpodSystem.Data.TrialOutcome = [];
    BpodSystem.Data.SniffInhalationOnset_s  = [];
    BpodSystem.Data.SniffInhalationOffset_s = [];
    BpodSystem.Data.LaserIrradiance_mWmm2 = [];
    BpodSystem.Data.LaserSetpoint_mW = [];

    nextTrialType = lhf.nextTrialType(BpodSystem.Data, lhf.trialPolicy(S.GUI, info), []);
    currentTrialType = nextTrialType;

    cue = S.GUIMeta.CueType.String{S.GUI.CueType};
    CSplus = S.GUIMeta.CSplusType.String{S.GUI.CSplusType};
    CSminus = S.GUIMeta.CSminusType.String{S.GUI.CSminusType};

    if S.GUI.VariableITI
        ITI = S.GUI.InterTrialInterval * (1.01 .^ (0:S.GUI.maxTrials-1));
        ITI(ITI > S.GUI.MaxITI) = S.GUI.MaxITI;
        ITI = ITI(randperm(lhf.random(), length(ITI)))';
        ITI = round(ITI * 1000) / 1000;
    else
        ITI = S.GUI.InterTrialInterval * ones(1, S.GUI.maxTrials);
    end

    %% Begin plotting
    % All live plots share one window: one graphics canvas instead of five
    [BpodSystem.ProtocolFigures.LivePlots, plotAxes] = lhf.plot.createFigure('WithPower', true);
    lhf.plot.outcome(plotAxes.Outcome, 'init', info, currentTrialType);
    lhf.plot.accuracy(plotAxes.Accuracy, 'init', info);
    lhf.plot.reward(plotAxes.Reward, 'init');
    lhf.plot.responseTime(plotAxes.Response, 'init');
    lhf.plot.encoder(plotAxes.Encoder, 'init', 0);
    lhf.plot.power(plotAxes.Power, 'init', info);

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
    TimeSoundCSplus = 0:1/sf:S.GUI.SoundDuration_CSplus;
    CSplusSound = chirp(TimeSoundCSplus, S.GUI.LowFreq_CSplus, S.GUI.SoundDuration_CSplus, S.GUI.HighFreq_CSplus);
    H.load(3, CSplusSound);
    TimeSoundCSminus = 0:1/sf:S.GUI.SoundDuration_CSminus;
    CSminusSound = chirp(TimeSoundCSminus, S.GUI.LowFreq_CSminus, S.GUI.SoundDuration_CSminus, S.GUI.HighFreq_CSminus);
    H.load(4, CSminusSound);

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
    dmd_hf_powercal('prepare', dmdSoftCodes(sma));
    currentActions.Patterns = BpodSystem.PluginObjects.PreparedPatterns;  % what the DMD will show
    dmd_hf_powercal('advance');
    BpodSystem.PluginObjects.SelectedOdourRow = BpodSystem.PluginObjects.NextOdourRow;
    sessionStart = datestr(datetime('now'), 'yyyy-mm-dd HH:MM:SS');
    repoDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    [~, gitHash] = system(['git -C "' repoDir '" rev-parse HEAD']);
    BpodSystem.Data.GitHash = strtrim(gitHash);
    BpodSystem.Data.Setup = lhf.recordSetup(luminose, lhf.subjectName());  % code, config, calibrations, stage (lhf.recreate)
    trialManager.startTrial(sma);

    %% Main trial loop
    for currentTrial = 1:S.GUI.maxTrials
        try
            t1 = tic;
            S = LuminoseParameterGUI_hf_powercal('sync', S);

            currentTrialType = nextTrialType;

            if handle_pause_condition(H, R), BpodSystem.Data.StoppedReason = lhf.stopRecord('operator', currentTrial); break; end

            if currentTrial < S.GUI.maxTrials
                nextTrialType = lhf.nextTrialType(BpodSystem.Data, lhf.trialPolicy(S.GUI, info), currentTrialType);
                [sma, S, nextActions] = PrepareStateMachine(S, nextTrialType, currentTrial+1, ITI);
                dmd_hf_powercal('prepare', dmdSoftCodes(sma));
                nextActions.Patterns = BpodSystem.PluginObjects.PreparedPatterns;  % what the DMD will show
                disp(['Session: ', sessionStart, ' | Trial: ', num2str(currentTrial)]);
                SendStateMachine(sma, 'RunASAP');
            end

            RawEvents = trialManager.getTrialData;
            dmd_hf_powercal('advance');
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

                lhf.plot.power(plotAxes.Power, 'update', BpodSystem.Data);

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
    BpodSystem.PluginObjects.PreparingTrial = currentTrial;  % the DMD handler logs it
    for tCell = {'cue', 'CSplus', 'CSminus', 'opto'}
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
    BpodSystem.PluginObjects.NextOdourRow = lhf.olf.drawRows(S.GUI, {'cue', 'CSplus', 'CSminus'});
    cue = S.GUIMeta.CueType.String{S.GUI.CueType};
    CSplus = S.GUIMeta.CSplusType.String{S.GUI.CSplusType};
    CSminus = S.GUIMeta.CSminusType.String{S.GUI.CSminusType};
    response = S.GUIMeta.ResponseType.String{S.GUI.ResponseType};
    % A pattern stimulus waits for the sniff onset (GetSniff) with Sniff Trigger ticked
    patternStart = 'DeliverStim';
    if S.GUI.SniffTrigger, patternStart = 'GetSniff'; end

    startAction = {'BNC1', 1, 'HiFi1', '*', 'RotaryEncoder1', ['#' 0], 'AnalogThreshEnable', 1};
    cueAction = {'RotaryEncoder1', '*Z'};
    switch cue
        case 'Odour'
            cueAction{end+1} = 'BNC2'; cueAction{end+1} = 1;
            startAction{end+1} = 'SoftCode'; startAction{end+1} = 1;
        case 'Pattern'
            cueAction{end+1} = 'PWM3'; cueAction{end+1} = S.GUI.Intensity_cue; % mask
            if ~isempty(lhf.selectedDesign('cue')), cueAction(end+1:end+2) = {'SoftCode', 8}; end
        case 'Light'
            cueAction{end+1} = 'PWM3'; cueAction{end+1} = S.GUI.Intensity_cue;
        case 'Sound'
            cueAction{end+1} = 'HiFi1'; cueAction{end+1} = ['P', 1];
    end
    stimAction = {'BNC1', 1}; % sync
    responseAction = {};
    switch currentTrialType
        case 1 % CS+
            switch CSplus
                case 'Odour'
                    stimAction{end+1} = 'BNC2'; stimAction{end+1} = 1;
                    startAction{end+1} = 'SoftCode'; startAction{end+1} = 2;
                    chooseState2 = 'DeliverStim';
                case 'Pattern'
                    stimAction{end+1} = 'PWM3'; stimAction{end+1} = S.GUI.Intensity_cue; % mask
                    if ~isempty(lhf.selectedDesign('CSplus'))  % no soft codes for a row with no spots (the default)
                        stimAction(end+1:end+2) = {'SoftCode', 9};
                        responseAction(end+1:end+2) = {'SoftCode', 11};  % halt at the response
                    end
                    chooseState2 = patternStart;
                    responseAction{end+1} = 'PWM3'; responseAction{end+1} = S.GUI.Intensity_cue;
                case 'Light'
                    stimAction{end+1} = 'PWM1'; stimAction{end+1} = S.GUI.Intensity_CSplus;
                    chooseState2 = 'DeliverStim';
                case 'Sound'
                    stimAction{end+1} = 'HiFi1'; stimAction{end+1} = ['P', 2];
                    chooseState2 = 'DeliverStim';
            end
            goAction = 'Reward'; noGoAction = 'InterTrialInterval';
        case 2 % CS-
            switch CSminus
                case 'Odour'
                    stimAction{end+1} = 'BNC2'; stimAction{end+1} = 1;
                    startAction{end+1} = 'SoftCode'; startAction{end+1} = 3;
                    chooseState2 = 'DeliverStim';
                case 'Pattern'
                    stimAction{end+1} = 'PWM3'; stimAction{end+1} = S.GUI.Intensity_cue; % mask
                    if ~isempty(lhf.selectedDesign('CSminus'))  % no soft codes for a row with no spots
                        stimAction(end+1:end+2) = {'SoftCode', 10};
                        responseAction(end+1:end+2) = {'SoftCode', 11};  % halt at the response
                    end
                    chooseState2 = patternStart;
                    responseAction{end+1} = 'PWM3'; responseAction{end+1} = S.GUI.Intensity_cue;
                case 'Light'
                    stimAction{end+1} = 'PWM4'; stimAction{end+1} = S.GUI.Intensity_CSminus;
                    chooseState2 = 'DeliverStim';
                case 'Sound'
                    stimAction{end+1} = 'HiFi1'; stimAction{end+1} = ['P', 3];
                    chooseState2 = 'DeliverStim';
            end
            noGoAction = 'InterTrialInterval'; goAction = 'Punishment';
    end
    % Laser power for this trial, from the design of the pattern it shows
    % (none when the stimulus is not a pattern or its row has no design, or
    % with Laser control off). Set from this trial's own state machine
    % because the next trial is prepared while this one runs.
    stimTypes = {'CSplus', 'CSminus'};
    stimKinds = {CSplus, CSminus};
    stimDesign = [];
    if strcmp(stimKinds{currentTrialType}, 'Pattern')
        stimDesign = lhf.selectedDesign(stimTypes{currentTrialType});
    end
    [irradiance, setpoint, laserAction] = lhf.laser.draw(stimDesign, stimTypes{currentTrialType}, S, luminose);

    % Cue and stimulus last as long as their kind says (lhf.stimDuration):
    % a pattern its design, an odour its sequence, light and sound their panel
    cueTime = lhf.stimDuration(S.GUI, cue, 'cue');
    stimTime = lhf.stimDuration(S.GUI, stimKinds{currentTrialType}, stimTypes{currentTrialType});

    responseDetect = {};
    switch response
        case 'Lick'
            responseDetect = {'Port3In', goAction, 'Tup', noGoAction};
            chooseState1 = chooseState2;
        case 'Rotary Encoder'
            responseDetect = {'RotaryEncoder1_1', goAction, 'RotaryEncoder1_2', noGoAction};
            chooseState1 = 'InitRE';
            responseAction{end+1} = 'RotaryEncoder1'; responseAction{end+1} = ['Z;' 3];
    end
    valveTime = GetValveTimes(S.GUI.RewardAmount, 4);
    if S.GUI.NoiseTime ~= 0
        punishAction = {'HiFi1', ['P', 0], 'BNC1', 1};
    else
        punishAction = {'BNC1', 1};
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
        'StateChangeConditions', {'Tup', 'ShowCue'}, ...
        'OutputActions', startAction);
    sma = AddState(sma, 'Name', 'ShowCue', ...
        'Timer', cueTime, ...
        'StateChangeConditions', {'Tup', chooseState1}, ...
        'OutputActions', cueAction);
    sma = AddState(sma, 'Name', 'InitRE', ...
        'Timer', 0.2, ...
        'StateChangeConditions', {'RotaryEncoder1_3', chooseState2, 'RotaryEncoder1_4', chooseState2}, ...
        'OutputActions', {'RotaryEncoder1', [';' 4]});
    sma = AddState(sma, 'Name', 'GetSniff', ...
        'Timer', 0, ...
        'StateChangeConditions', {'Flex1Trig1', 'DeliverStim'}, ...
        'OutputActions', {'PWM3', S.GUI.Intensity_cue});
    sma = AddState(sma, 'Name', 'DeliverStim', ...
        'Timer', stimTime, ...
        'StateChangeConditions', {'Tup', 'GetResponse'}, ...
        'OutputActions', stimAction);
    sma = AddState(sma, 'Name', 'GetResponse', ...
        'Timer', S.GUI.ResponseTime, ...
        'StateChangeConditions', responseDetect, ...
        'OutputActions', responseAction);
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', valveTime, ...
        'StateChangeConditions', {'Tup', 'InterTrialInterval'}, ...
        'OutputActions', {'Valve4', 1, 'BNC1', 1});
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
    actions.TrialStart   = startAction;
    actions.ShowCue      = cueAction;
    actions.DeliverStim  = stimAction;
    actions.GetResponse  = responseAction;
    actions.Reward       = {'Valve4', 1, 'BNC1', 1};
    actions.Punishment   = punishAction;
    actions.RewardValveTime = valveTime;
    actions.SetLaserPower = laserAction;
    actions.LaserIrradiance_mWmm2 = irradiance;  % NaN when no pattern is shown
    actions.LaserSetpoint_mW      = setpoint;
    actions.PatternRows = fieldOrEmpty(BpodSystem.PluginObjects, 'SelectedPatternRow');  % row drawn per type
    actions.OdourRows   = fieldOrEmpty(BpodSystem.PluginObjects, 'NextOdourRow');        % odour rows drawn per type
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
    dmd_hf_powercal('close');
    clear dmd_hf_powercal;
    lhf.laser.close();  % emission off, port freed (nothing to do with Laser control off)
    lhf.olf.close();  % deliveries kept in Data.Olfactometer; the worker stays warm
    BpodSystem.Data.luminose = luminose;
    BpodSystem.Data.GUIMeta = S.GUIMeta;
    BpodSystem.ProtocolSettings = S;
    if ~isfield(BpodSystem.Data, 'StoppedReason')
        BpodSystem.Data.StoppedReason = lhf.stopRecord('unknown', NaN);  % setup error or Ctrl+C
    end
    SaveBpodSessionData;
    SaveBpodProtocolSettings;
    lhf.report.write(BpodSystem.Data, lhf.protocolInfo('powercal'), BpodSystem.Path.CurrentDataFile);
    diary off;
    if BpodSystem.Status.BeingUsed == 1
        RunProtocol('Stop');
    end
    % With BpodSystem listed in the base workspace, MATLAB's Workspace browser
    % works through every change the session made to it once the prompt
    % returns, and can run MATLAB out of memory (seen in LuminoseFM).
    evalin('base', 'clear BpodSystem');
end

function S = loadPowercalDesigns(S, dmdConfig)
% The CS+ and CS- designs for this session, from powercal's own files only:
% designs another protocol left in memory are replaced. A row without a
% saved design shows nothing, except row 1 with neither spots nor a blank
% saved: CS- defaults to a single spot at the DMD centre (centralSpotDesign)
% and CS+ to no spots for as long (blankDesign), so both stimuli last defaultStimMs and the response window
% opens at the same time after the sniff. Designing a row in the Pattern
% Designer saves it as powercal's and replaces the default.
    global BpodSystem
    if ~isfield(BpodSystem.PluginObjects, 'PatternDesigns')
        BpodSystem.PluginObjects.PatternDesigns = struct();
    end
    for t = {'CSplus', 'CSminus'}
        patternType = t{1};
        nRows = numel(S.GUI.(['patternProbs_' patternType]));
        designs = cell(1, nRows);
        for row = 1:nRows
            [design, blankMs] = lhf.patternDesign(struct(), dmdConfig, patternType, row);
            if isempty(design)
                design = noDesign();  % known to be empty: no file lookup per trial
                if blankMs > 0, design = blankDesign(blankMs); end  % a blank saved in the designer
            end
            designs{row} = design;
        end
        BpodSystem.PluginObjects.PatternDesigns.(patternType) = designs;
    end
    if isUnsaved(BpodSystem.PluginObjects.PatternDesigns.CSminus{1})
        [design, exposureUs] = centralSpotDesign(dmdConfig);
        BpodSystem.PluginObjects.PatternDesigns.CSminus{1} = design;
        S.GUI.patternNFrames_CSminus(1) = design.nF;
        S.GUI.patternExposure_CSminus(1) = exposureUs;
        fprintf('CS- row 1: no powercal design saved, using the central spot.\n');
    end
    if isUnsaved(BpodSystem.PluginObjects.PatternDesigns.CSplus{1})
        BpodSystem.PluginObjects.PatternDesigns.CSplus{1} = blankDesign(defaultStimMs());
        S.GUI.patternNFrames_CSplus(1) = 1;  % as the CS- spot: one 80 ms frame (the table shows it)
        S.GUI.patternExposure_CSplus(1) = defaultStimMs() * 1000;
        fprintf('CS+ row 1: no powercal design saved, showing no spots for %d ms.\n', defaultStimMs());
    end
end

function ms = defaultStimMs()
% How long the default CS- spot and the default blank CS+ last
    ms = 80;
end

function design = noDesign()
    spots = struct('x', {}, 'y', {}, 'onset_ms', {}, 'dur_ms', {}, 'isFixed', {});
    design = struct('spots', spots, 'tickMs', 1, 'r_px', 1, 'nF', 0);
end

function tf = isUnsaved(design)
% Neither spots nor a blank saved for the row
    tf = isempty(design.spots) && ~isfield(design, 'blankMs');
end

function design = blankDesign(ms)
% No spots, so nothing is projected (no soft code, no laser power), lasting
% ms (lhf.stimDuration reads blankMs); its tick is the same, so the Pattern
% Designer opens it at that length. The default CS+ is one of defaultStimMs.
    design = noDesign();
    design.tickMs = ms;
    design.blankMs = ms;
end

function [design, exposureUs] = centralSpotDesign(dmdConfig)
% The default CS- pattern: one spot at the DMD centre, shown for
% defaultStimMs (80 ms), 0.12 mm wide, converted as the Pattern Designer
% does, so it opens there unchanged (and its spot side can be changed there).
    DMD_W = 1024; DMD_H = 768;  % as PatternDesignerGUI
    spotSide = 0.12;
    r_px = max(1, round((spotSide / dmdConfig.projectedDMDlength) * DMD_W / 2));
    durMs = defaultStimMs();
    spot = struct('x', DMD_W / 2, 'y', DMD_H / 2, 'onset_ms', 0, 'dur_ms', durMs, 'isFixed', true);
    design = struct('spots', spot, 'tickMs', durMs, 'r_px', r_px, 'nF', 1);
    exposureUs = durMs * 1000;
end

function restorePatternParams(typeNames, dmdConfig)
    global S BpodSystem
    for i = 1:numel(typeNames)
        t = typeNames{i};
        patternsFolder = lhf.patternFolder(dmdConfig, t);
        f = lhf.patternFileType(dmdConfig, t);  % the name t's files carry
        allMetas = dir(fullfile(patternsFolder, sprintf('designed_%s_*_meta.mat', f)));
        if isempty(allMetas), continue; end

        % Separate row-indexed files from legacy files (no row index)
        isRowFile = arrayfun(@(m) ~isempty(regexp(m.name, ...
            sprintf('designed_%s_r\\d+_', f), 'once')), allMetas);
        rowMetas   = allMetas(isRowFile);
        legacyMetas = allMetas(~isRowFile);

        % Collect unique row indices from row-indexed files
        rowIndices = [];
        for j = 1:numel(rowMetas)
            tok = regexp(rowMetas(j).name, sprintf('designed_%s_r(\\d+)_', f), 'tokens', 'once');
            if ~isempty(tok), rowIndices(end+1) = str2double(tok{1}); end %#ok<AGROW>
        end
        rowIndices = unique(rowIndices);
        % Legacy files count as row 1 if no _r1_ file exists
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
                sprintf('designed_%s_r%d_', f, rowIdx), 'once')), rowMetas));
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

        % Equal probability across all restored rows
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

function value = fieldOrEmpty(s, name)
    value = struct();
    if isfield(s, name), value = s.(name); end
end

function GUIparams_luminose_hf_2AFC()
    global S
    
    %% ===== Trials =====
    S.GUITabs.Trials = {'ProtocolSettings', 'Sniff', 'TreatmentType', 'TestPulses', 'TrainingParams', 'Laser'};
    S.GUIPanels.TrainingParams = {'TrainingLevel', 'BiasCorrection', 'maxTrials', 'Leftprob'};
    S.GUIPanels.TestPulses = {'TestPulses', 'TestPulsesType'};
    S.GUIPanels.TreatmentType = {'Ephys', 'EEG', 'Drug'};
    S.GUIPanels.ProtocolSettings = {'Sleep', 'muBarcodeDur', 'sigmaBarcodeDur'};
    S.GUIPanels.Sniff = {'SniffOnsetThreshold', 'SniffOffsetThreshold', 'SniffTrigger', 'CalibrateSniff'};

    % == Training Params ==
    S.GUI.TrainingLevel = 1; % Default Training Level
    S.GUIMeta.TrainingLevel.Style = 'popupmenu';
    S.GUIMeta.TrainingLevel.String = {'Habituation', 'Training'};
    S.GUIMeta.TrainingLevel.Label = 'Training Level';
    S.GUI.BiasCorrection = true;
    S.GUIMeta.BiasCorrection.Style = 'checkbox';
    S.GUIMeta.BiasCorrection.Label = 'Bias Correction';
    S.GUI.maxTrials = 1000;
    S.GUIMeta.maxTrials.Label = 'Max Trials';
    S.GUI.Leftprob = 0.5;
    S.GUIMeta.Leftprob.Label = 'Left Probability';
    
    % == Test Pulses ==
    S.GUI.TestPulses = false;
    S.GUIMeta.TestPulses.Style = 'checkbox';
    S.GUIMeta.TestPulses.Label = 'Test Pulses';
    S.GUI.TestPulsesType = 2;
    S.GUIMeta.TestPulsesType.Style = 'popupmenu';
    S.GUIMeta.TestPulsesType.String = {'SinglePulse', 'PairedPulse'};
    S.GUIMeta.TestPulsesType.Label = 'Pulse Type';
    
    % == Treatment Type ==
    S.GUI.Ephys = false;
    S.GUIMeta.Ephys.Style = 'checkbox';
    S.GUIMeta.Ephys.Label = 'Ephys';
    S.GUI.EEG = false;
    S.GUIMeta.EEG.Style = 'checkbox';
    S.GUIMeta.EEG.Label = 'EEG';
    S.GUI.Drug = false;
    S.GUIMeta.Drug.Style = 'checkbox';
    S.GUIMeta.Drug.Label = 'Drug';

    % == Protocol Settings ==
    S.GUI.muBarcodeDur = 0.2;
    S.GUIMeta.muBarcodeDur.Label = 'Barcode mean';
    S.GUI.sigmaBarcodeDur = 0.05;
    S.GUIMeta.sigmaBarcodeDur.Label = 'Barcode std';
    S.GUI.Sleep = 1;
    S.GUIMeta.Sleep.Style = 'popupmenu';
    S.GUIMeta.Sleep.String = {'Pre-sleep', 'Post-sleep', 'During-sleep', 'None'};
    S.GUIMeta.Sleep.Label = 'Sleep Phase';

    % == Sniff ==
    S.GUI.SniffOnsetThreshold = 2.0;  % baseline ~2.5V; fires when sniff drops below this
    S.GUIMeta.SniffOnsetThreshold.Label = 'Sniff Onset Thresh (V)';
    S.GUI.SniffOffsetThreshold = 2.0;  % fires when signal returns above this
    S.GUIMeta.SniffOffsetThreshold.Label = 'Sniff Offset Thresh (V)';
    S.GUI.SniffTrigger = true;  % a pattern stimulus starts at the sniff onset; unticked, right after the cue
    S.GUIMeta.SniffTrigger.Style = 'checkbox';
    S.GUIMeta.SniffTrigger.Label = 'Sniff Trigger';
    S.GUI.CalibrateSniff = 0;
    S.GUIMeta.CalibrateSniff.Style = 'pushbutton';
    S.GUIMeta.CalibrateSniff.String = 'Calibrate Sniff (12s)';
    S.GUIMeta.CalibrateSniff.Callback = 'RunSniffCalibration';
    S.GUIMeta.CalibrateSniff.CallbackArg = '';

    %% ===== Task =====
    S.GUITabs.Task = {'ITI', 'Response', 'Stimulus', 'CueParams'};
    % Optional laser control: ticked, each trial showing a pattern sets the
    % power drawn from that pattern's design (set in the Pattern Designer);
    % unticked, the laser is not connected (lhf.laser.open)
    S.GUIPanels.Laser = {'LaserControl'};
    S.GUI.LaserControl = false;
    S.GUIMeta.LaserControl.Style = 'checkbox';
    S.GUIMeta.LaserControl.Label = 'Laser control';
    S.GUIPanels.CueParams = {'CueType'};
    S.GUIPanels.Stimulus = {'LeftType', 'RightType'};
    S.GUIPanels.Response = {'ResponseType', 'ResponseTime', 'RewardAmount', 'Punishment', ...
        'ErrorDelay', 'NoiseTime'};
    S.GUIPanels.ITI = {'VariableITI', 'InterTrialInterval', 'MaxITI'};
    % == CueParams ==
    % How long the cue and stimuli last: a pattern its design, an odour its
    % sequence (one olfactometer slot per odour), light and sound the
    % Duration in their own panel (lhf.stimDuration)
    S.GUI.CueType = 1;
    S.GUIMeta.CueType.Style = 'popupmenu';
    S.GUIMeta.CueType.String = {'Light', 'Sound', 'Odour', 'Pattern'};
    S.GUIMeta.CueType.Label = 'Cue Type';
    
    % == Stimulus ==
    S.GUI.LeftType = 3;
    S.GUIMeta.LeftType.Style = 'popupmenu';
    S.GUIMeta.LeftType.String = {'Light', 'Sound', 'Odour', 'Pattern'};
    S.GUIMeta.LeftType.Label = 'Left Type';
    S.GUI.RightType = 3;
    S.GUIMeta.RightType.Style = 'popupmenu';
    S.GUIMeta.RightType.String = {'Light', 'Sound', 'Odour', 'Pattern'};
    S.GUIMeta.RightType.Label = 'Right Type';
    
    % == Response ==
    S.GUI.ResponseType = 1;
    S.GUIMeta.ResponseType.Style = 'popupmenu';
    S.GUIMeta.ResponseType.String = {'Lick', 'Rotary Encoder'};
    S.GUIMeta.ResponseType.Label = 'Response Type';
    S.GUI.ResponseTime = 2;
    S.GUIMeta.ResponseTime.Label = 'Response Window (s)';
    S.GUI.RewardAmount = 2;
    S.GUIMeta.RewardAmount.Label = 'Reward Amount (ul)';
    S.GUI.Punishment = true;
    S.GUIMeta.Punishment.Style = 'checkbox';
    S.GUIMeta.Punishment.Label = 'Enable Punishment';
    S.GUI.ErrorDelay = 5;
    S.GUIMeta.ErrorDelay.Label = 'Error ITI Delay (s)';
    S.GUI.NoiseTime = 1; % must be less than error delay
    S.GUIMeta.NoiseTime.Label = 'White Noise Dur (s)';

    % == ITI ==
    S.GUI.VariableITI = true;
    S.GUIMeta.VariableITI.Style = 'checkbox';
    S.GUIMeta.VariableITI.Label = 'Variable ITI';
    S.GUI.InterTrialInterval = 5;
    S.GUIMeta.InterTrialInterval.Label = 'Mean ITI (s)';
    S.GUI.MaxITI = 6;
    S.GUIMeta.MaxITI.Label = 'Max ITI (s)';

    %% ===== Cue =====
    S.GUITabs.Cue = {'Light_cue', 'Sound_cue', 'Odour_cue', 'Pattern_cue'};
    S.GUIPanels.Light_cue = {'Intensity_cue', 'LightDuration_cue'};
    S.GUIPanels.Sound_cue = {'Freq_cue', 'SoundDuration_cue'};
    S.GUIPanels.Odour_cue = {'valves_cue'};
    S.GUIPanels.Pattern_cue = {'patternSel_cue'};
    % == Light ==
    S.GUI.Intensity_cue = 100;
    S.GUIMeta.Intensity_cue.Label = 'Intensity (0-255)';
    S.GUI.LightDuration_cue = 1;
    S.GUIMeta.LightDuration_cue.Label = 'Duration (s)';
    % == Sound ==
    S.GUI.Freq_cue = 5000;
    S.GUIMeta.Freq_cue.Label = 'Frequency (Hz)';
    S.GUI.SoundDuration_cue = 1;
    S.GUIMeta.SoundDuration_cue.Label = 'Duration (s)';
    % == Odour ==
    S.GUI.valves_cue = [7];
    S.GUIMeta.valves_cue.Style = 'odour_selector';
    S.GUIMeta.valves_cue.ProbParam = 'probs_cue';
    S.GUIMeta.valves_cue.DutyParam = 'dutyCycles_cue';
    S.GUIMeta.valves_cue.Label = 'Valves';
    S.GUI.dutyCycles_cue = [1];
    S.GUI.probs_cue = [1];
    % == Pattern ==
    S.GUI.patternSel_cue = 0;
    S.GUIMeta.patternSel_cue.Style = 'pattern_selector';
    S.GUIMeta.patternSel_cue.ProbParam = 'patternProbs_cue';
    S.GUIMeta.patternSel_cue.NFramesParam = 'patternNFrames_cue';
    S.GUIMeta.patternSel_cue.ExposureParam = 'patternExposure_cue';
    S.GUIMeta.patternSel_cue.TypeName = 'cue';
    S.GUIMeta.patternSel_cue.Label = '';
    S.GUI.patternProbs_cue = [1];
    S.GUIMeta.patternProbs_cue.Hidden = true;
    S.GUI.patternNFrames_cue = [1];
    S.GUIMeta.patternNFrames_cue.Hidden = true;
    S.GUI.patternExposure_cue = [1e6];
    S.GUIMeta.patternExposure_cue.Hidden = true;

    %% ===== Left =====
    S.GUITabs.Left = {'Light_Left', 'Sound_Left', 'Odour_Left', 'Pattern_Left'};
    S.GUIPanels.Light_Left = {'Intensity_Left', 'LightDuration_Left'};
    S.GUIPanels.Sound_Left = {'HighFreq_Left', 'LowFreq_Left', 'SoundDuration_Left'};
    S.GUIPanels.Odour_Left = {'valves_Left'};
    S.GUIPanels.Pattern_Left = {'patternSel_Left'};
    % == Light ==
    S.GUI.Intensity_Left = 100;
    S.GUIMeta.Intensity_Left.Label = 'Intensity (0-255)';
    S.GUI.LightDuration_Left = 1;
    S.GUIMeta.LightDuration_Left.Label = 'Duration (s)';
    % == Sound ==
    S.GUI.HighFreq_Left = 8;
    S.GUIMeta.HighFreq_Left.Label = 'High Freq (Hz)';
    S.GUI.LowFreq_Left = 4;
    S.GUIMeta.LowFreq_Left.Label = 'Low Freq (Hz)';
    S.GUI.SoundDuration_Left = 1;
    S.GUIMeta.SoundDuration_Left.Label = 'Duration (s)';
    % == Odour ==
    S.GUI.valves_Left = [12];
    S.GUIMeta.valves_Left.Style = 'odour_selector';
    S.GUIMeta.valves_Left.ProbParam = 'probs_Left';
    S.GUIMeta.valves_Left.DutyParam = 'dutyCycles_Left';
    S.GUIMeta.valves_Left.Label = 'Valves';
    S.GUI.dutyCycles_Left = [1];
    S.GUI.probs_Left = [1];
    % == Pattern ==
    S.GUI.patternSel_Left = 0;
    S.GUIMeta.patternSel_Left.Style = 'pattern_selector';
    S.GUIMeta.patternSel_Left.ProbParam = 'patternProbs_Left';
    S.GUIMeta.patternSel_Left.NFramesParam = 'patternNFrames_Left';
    S.GUIMeta.patternSel_Left.ExposureParam = 'patternExposure_Left';
    S.GUIMeta.patternSel_Left.TypeName = 'Left';
    S.GUIMeta.patternSel_Left.LaserOptions = true;  % laser power per design, in the Pattern Designer
    S.GUIMeta.patternSel_Left.LaserDefaults = struct('irradiances', [2 5 8 12 14.5], 'weights', [1 1 1 1 1]);
    S.GUIMeta.patternSel_Left.Label = '';
    S.GUI.patternProbs_Left = [1];
    S.GUIMeta.patternProbs_Left.Hidden = true;
    S.GUI.patternNFrames_Left = [1];
    S.GUIMeta.patternNFrames_Left.Hidden = true;
    S.GUI.patternExposure_Left = [200000];
    S.GUIMeta.patternExposure_Left.Hidden = true;

    %% ===== Right =====
    S.GUITabs.Right = {'Light_Right', 'Sound_Right', 'Odour_Right', 'Pattern_Right'};
    S.GUIPanels.Light_Right = {'Intensity_Right', 'LightDuration_Right'};
    S.GUIPanels.Sound_Right = {'HighFreq_Right', 'LowFreq_Right', 'SoundDuration_Right'};
    S.GUIPanels.Odour_Right = {'valves_Right'};
    S.GUIPanels.Pattern_Right = {'patternSel_Right'};
    % == Light ==
    S.GUI.Intensity_Right = 100;
    S.GUIMeta.Intensity_Right.Label = 'Intensity (0-255)';
    S.GUI.LightDuration_Right = 1;
    S.GUIMeta.LightDuration_Right.Label = 'Duration (s)';
    % == Sound ==
    S.GUI.HighFreq_Right = 16;
    S.GUIMeta.HighFreq_Right.Label = 'High Freq (Hz)';
    S.GUI.LowFreq_Right = 12;
    S.GUIMeta.LowFreq_Right.Label = 'Low Freq (Hz)';
    S.GUI.SoundDuration_Right = 1;
    S.GUIMeta.SoundDuration_Right.Label = 'Duration (s)';
    % == Odour ==
    S.GUI.valves_Right = [16];
    S.GUIMeta.valves_Right.Style = 'odour_selector';
    S.GUIMeta.valves_Right.ProbParam = 'probs_Right';
    S.GUIMeta.valves_Right.DutyParam = 'dutyCycles_Right';
    S.GUIMeta.valves_Right.Label = 'Valves';
    S.GUI.dutyCycles_Right = [1];
    S.GUI.probs_Right = [1];
    % == Pattern ==
    S.GUI.patternSel_Right = 0;
    S.GUIMeta.patternSel_Right.Style = 'pattern_selector';
    S.GUIMeta.patternSel_Right.ProbParam = 'patternProbs_Right';
    S.GUIMeta.patternSel_Right.NFramesParam = 'patternNFrames_Right';
    S.GUIMeta.patternSel_Right.ExposureParam = 'patternExposure_Right';
    S.GUIMeta.patternSel_Right.TypeName = 'Right';
    S.GUIMeta.patternSel_Right.LaserOptions = true;  % laser power per design, in the Pattern Designer
    S.GUIMeta.patternSel_Right.LaserDefaults = struct('irradiances', [2 5 8 12 14.5], 'weights', [1 1 1 1 1]);
    S.GUIMeta.patternSel_Right.Label = '';
    S.GUI.patternProbs_Right = [1];
    S.GUIMeta.patternProbs_Right.Hidden = true;
    S.GUI.patternNFrames_Right = [1];
    S.GUIMeta.patternNFrames_Right.Hidden = true;
    S.GUI.patternExposure_Right = [200000];
    S.GUIMeta.patternExposure_Right.Hidden = true;
    
    %% OptoStim
    S.GUITabs.OptoStim = {'MaskLED', 'SinglePulse', 'PairedPulse', 'Pattern_opto'};
    S.GUIPanels.SinglePulse = {'SPfrequency', 'SPamplitude'};
    S.GUIPanels.PairedPulse = {'PPfrequency', 'PPamplitude'};
    S.GUIPanels.MaskLED = {'Intensity_mask', 'Duration_mask'};
    S.GUIPanels.Pattern_opto = {'patternSel_opto'};
    S.GUI.SPfrequency = 1;
    S.GUIMeta.SPfrequency.Label = 'Freq (Hz)';
    S.GUI.SPamplitude = 1;
    S.GUIMeta.SPamplitude.Label = 'Amp (V)';
    S.GUI.PPfrequency = 1;
    S.GUIMeta.PPfrequency.Label = 'Freq (Hz)';
    S.GUI.PPamplitude = 1;
    S.GUIMeta.PPamplitude.Label = 'Amp (V)';
    S.GUI.Intensity_mask = 100;
    S.GUIMeta.Intensity_mask.Label = 'Intensity (0-255)';
    S.GUI.Duration_mask = 1;
    S.GUIMeta.Duration_mask.Label = 'Duration (s)';
    % == Pattern ==
    S.GUI.patternSel_opto = 0;
    S.GUIMeta.patternSel_opto.Style = 'pattern_selector';
    S.GUIMeta.patternSel_opto.ProbParam = 'patternProbs_opto';
    S.GUIMeta.patternSel_opto.NFramesParam = 'patternNFrames_opto';
    S.GUIMeta.patternSel_opto.ExposureParam = 'patternExposure_opto';
    S.GUIMeta.patternSel_opto.TypeName = 'opto';
    S.GUIMeta.patternSel_opto.Label = '';
    S.GUI.patternProbs_opto = [1];
    S.GUIMeta.patternProbs_opto.Hidden = true;
    S.GUI.patternNFrames_opto = [1];
    S.GUIMeta.patternNFrames_opto.Hidden = true;
    S.GUI.patternExposure_opto = [1e6];
    S.GUIMeta.patternExposure_opto.Hidden = true;

    %% Treatment
    S.GUITabs.Ephys = {'DrugSpecs', 'EEGSpecs', 'EphysSpecs'};
    
    S.GUIPanels.EphysSpecs = {'EphysType', 'EphysCoords'};
    S.GUI.EphysType = 1;
    S.GUIMeta.EphysType.Style = 'popupmenu';
    S.GUIMeta.EphysType.String = {'NP chronic', 'NP acute'};
    S.GUIMeta.EphysType.Label = 'Probe Type';
    S.GUI.EphysCoords = 1;
    S.GUIMeta.EphysCoords.Label = 'Coordinates';

    S.GUIPanels.EEGSpecs = {'EEGchannels', 'EMGchannels'};
    S.GUI.EEGchannels = 2;
    S.GUIMeta.EEGchannels.Label = 'EEG Channels';
    S.GUI.EMGchannels = 1;
    S.GUIMeta.EMGchannels.Label = 'EMG Channels';
    
    S.GUIPanels.DrugSpecs = {'DrugType', 'DrugDose'};
    S.GUI.DrugType = 1;
    S.GUIMeta.DrugType.Style = 'popupmenu';
    S.GUIMeta.DrugType.String = {'baclofen', 'APV', 'bicuculline', 'gabazine', 'muscimol', 'isofluorane'};
    S.GUIMeta.DrugType.Label = 'Drug Compound';
    S.GUI.DrugDose = 1;
    S.GUIMeta.DrugDose.Label = 'Dose (mg/kg)';

end
function GUIparams_luminose_hf_goNogo()
    global S
    
    %% ===== Trials =====
    S.GUITabs.Trials = {'ProtocolSettings', 'Sniff', 'TreatmentType', 'TestPulses', 'TrainingParams', 'Laser'};
    S.GUIPanels.TrainingParams = {'TrainingLevel', 'BiasCorrection', 'CSplus_prob', 'maxTrials'};
    S.GUIPanels.TestPulses = {'TestPulses', 'TestPulsesType'};
    S.GUIPanels.TreatmentType = {'Ephys', 'EEG', 'Drug'};
    S.GUIPanels.ProtocolSettings = {'Sleep', 'muBarcodeDur', 'sigmaBarcodeDur'};
    S.GUIPanels.Sniff = {'SniffOnsetThreshold', 'SniffOffsetThreshold', 'SniffTrigger', 'CalibrateSniff'};

    % == Training Params ==
    S.GUI.TrainingLevel = 2; % Default Training Level
    S.GUIMeta.TrainingLevel.Style = 'popupmenu';
    S.GUIMeta.TrainingLevel.String = {'Habituation', 'Training'};
    S.GUIMeta.TrainingLevel.Label = 'Training Level';
    S.GUI.BiasCorrection = true;
    S.GUIMeta.BiasCorrection.Style = 'checkbox';
    S.GUIMeta.BiasCorrection.Label = 'Bias Correction';
    S.GUI.CSplus_prob = 0.5;
    S.GUIMeta.CSplus_prob.Label = 'CS+ Probability';
    S.GUI.maxTrials = 1000;    
    S.GUIMeta.maxTrials.Label = 'Max Trials';
    
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
    S.GUI.SniffOnsetThreshold = 3;
    S.GUIMeta.SniffOnsetThreshold.Label = 'Sniff Onset Thresh (V)';
    S.GUI.SniffOffsetThreshold = 2;
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
    S.GUIPanels.Stimulus = {'CSplusType', 'CSminusType'};
    S.GUIPanels.Response = {'ResponseType', 'ResponseTime', 'RewardAmount', ...
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
    S.GUI.CSplusType = 3;
    S.GUIMeta.CSplusType.Style = 'popupmenu';
    S.GUIMeta.CSplusType.String = {'Light', 'Sound', 'Odour', 'Pattern'};
    S.GUIMeta.CSplusType.Label = 'CS+ Type';
    S.GUI.CSminusType = 3;
    S.GUIMeta.CSminusType.Style = 'popupmenu';
    S.GUIMeta.CSminusType.String = {'Light', 'Sound', 'Odour', 'Pattern'};
    S.GUIMeta.CSminusType.Label = 'CS- Type';
    
    % == Response ==
    S.GUI.ResponseType = 1;
    S.GUIMeta.ResponseType.Style = 'popupmenu';
    S.GUIMeta.ResponseType.String = {'Lick', 'Rotary Encoder'};
    S.GUIMeta.ResponseType.Label = 'Response Type';
    S.GUI.ResponseTime = 2;
    S.GUIMeta.ResponseTime.Label = 'Response Window (s)';
    S.GUI.RewardAmount = 2;
    S.GUIMeta.RewardAmount.Label = 'Reward Amount (ul)';
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

    %% ===== CS+ =====
    S.GUITabs.CSplus = {'Light_CSplus', 'Sound_CSplus', 'Odour_CSplus', 'Pattern_CSplus'};
    S.GUIPanels.Light_CSplus = {'Intensity_CSplus', 'LightDuration_CSplus'};
    S.GUIPanels.Sound_CSplus = {'HighFreq_CSplus', 'LowFreq_CSplus', 'SoundDuration_CSplus'};
    S.GUIPanels.Odour_CSplus = {'valves_CSplus'};
    S.GUIPanels.Pattern_CSplus = {'patternSel_CSplus'};
    % == Light ==
    S.GUI.Intensity_CSplus = 100;
    S.GUIMeta.Intensity_CSplus.Label = 'Intensity (0-255)';
    S.GUI.LightDuration_CSplus = 1;
    S.GUIMeta.LightDuration_CSplus.Label = 'Duration (s)';
    % == Sound ==
    S.GUI.HighFreq_CSplus = 8;
    S.GUIMeta.HighFreq_CSplus.Label = 'High Freq (Hz)';
    S.GUI.LowFreq_CSplus = 4;
    S.GUIMeta.LowFreq_CSplus.Label = 'Low Freq (Hz)';
    S.GUI.SoundDuration_CSplus = 1;
    S.GUIMeta.SoundDuration_CSplus.Label = 'Duration (s)';
    % == Odour ==
    S.GUI.valves_CSplus = [12];
    S.GUIMeta.valves_CSplus.Style = 'odour_selector';
    S.GUIMeta.valves_CSplus.ProbParam = 'probs_CSplus';
    S.GUIMeta.valves_CSplus.DutyParam = 'dutyCycles_CSplus';
    S.GUIMeta.valves_CSplus.Label = 'Valves';
    S.GUI.dutyCycles_CSplus = [1];
    S.GUI.probs_CSplus = [1];
    % == Pattern ==
    S.GUI.patternSel_CSplus = 0;
    S.GUIMeta.patternSel_CSplus.Style = 'pattern_selector';
    S.GUIMeta.patternSel_CSplus.ProbParam = 'patternProbs_CSplus';
    S.GUIMeta.patternSel_CSplus.NFramesParam = 'patternNFrames_CSplus';
    S.GUIMeta.patternSel_CSplus.ExposureParam = 'patternExposure_CSplus';
    S.GUIMeta.patternSel_CSplus.TypeName = 'CSplus';
    S.GUIMeta.patternSel_CSplus.LaserOptions = true;  % laser power per design, in the Pattern Designer
    S.GUIMeta.patternSel_CSplus.LaserDefaults = struct('irradiances', [2 5 8 12 14.5], 'weights', [1 1 1 1 1]);
    S.GUIMeta.patternSel_CSplus.Label = '';
    S.GUI.patternProbs_CSplus = [1];
    S.GUIMeta.patternProbs_CSplus.Hidden = true;
    S.GUI.patternNFrames_CSplus = [1];
    S.GUIMeta.patternNFrames_CSplus.Hidden = true;
    S.GUI.patternExposure_CSplus = [1e6];
    S.GUIMeta.patternExposure_CSplus.Hidden = true;

    %% ===== CS- =====
    S.GUITabs.CSminus = {'Light_CSminus', 'Sound_CSminus', 'Odour_CSminus', 'Pattern_CSminus'};
    S.GUIPanels.Light_CSminus = {'Intensity_CSminus', 'LightDuration_CSminus'};
    S.GUIPanels.Sound_CSminus = {'HighFreq_CSminus', 'LowFreq_CSminus', 'SoundDuration_CSminus'};
    S.GUIPanels.Odour_CSminus = {'valves_CSminus'};
    S.GUIPanels.Pattern_CSminus = {'patternSel_CSminus'};
    % == Light ==
    S.GUI.Intensity_CSminus = 100;
    S.GUIMeta.Intensity_CSminus.Label = 'Intensity (0-255)';
    S.GUI.LightDuration_CSminus = 1;
    S.GUIMeta.LightDuration_CSminus.Label = 'Duration (s)';
    % == Sound ==
    S.GUI.HighFreq_CSminus = 16;
    S.GUIMeta.HighFreq_CSminus.Label = 'High Freq (Hz)';
    S.GUI.LowFreq_CSminus = 12;
    S.GUIMeta.LowFreq_CSminus.Label = 'Low Freq (Hz)';
    S.GUI.SoundDuration_CSminus = 1;
    S.GUIMeta.SoundDuration_CSminus.Label = 'Duration (s)';
    % == Odour ==
    S.GUI.valves_CSminus = [16];
    S.GUIMeta.valves_CSminus.Style = 'odour_selector';
    S.GUIMeta.valves_CSminus.ProbParam = 'probs_CSminus';
    S.GUIMeta.valves_CSminus.DutyParam = 'dutyCycles_CSminus';
    S.GUIMeta.valves_CSminus.Label = 'Valves';
    S.GUI.dutyCycles_CSminus = [1];
    S.GUI.probs_CSminus = [1];
    % == Pattern ==
    S.GUI.patternSel_CSminus = 0;
    S.GUIMeta.patternSel_CSminus.Style = 'pattern_selector';
    S.GUIMeta.patternSel_CSminus.ProbParam = 'patternProbs_CSminus';
    S.GUIMeta.patternSel_CSminus.NFramesParam = 'patternNFrames_CSminus';
    S.GUIMeta.patternSel_CSminus.ExposureParam = 'patternExposure_CSminus';
    S.GUIMeta.patternSel_CSminus.TypeName = 'CSminus';
    S.GUIMeta.patternSel_CSminus.LaserOptions = true;  % laser power per design, in the Pattern Designer
    S.GUIMeta.patternSel_CSminus.LaserDefaults = struct('irradiances', [2 5 8 12 14.5], 'weights', [1 1 1 1 1]);
    S.GUIMeta.patternSel_CSminus.Label = '';
    S.GUI.patternProbs_CSminus = [1];
    S.GUIMeta.patternProbs_CSminus.Hidden = true;
    S.GUI.patternNFrames_CSminus = [1];
    S.GUIMeta.patternNFrames_CSminus.Hidden = true;
    S.GUI.patternExposure_CSminus = [1e6];
    S.GUIMeta.patternExposure_CSminus.Hidden = true;

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
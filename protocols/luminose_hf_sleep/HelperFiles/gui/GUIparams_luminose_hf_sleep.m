function GUIparams_luminose_hf_sleep()
    global S
    
    %% ===== Trials =====
    S.GUITabs.Trials = {'ProtocolSettings', 'TreatmentType', 'TestPulses', 'TrialParams', 'Sniff'};
    S.GUIPanels.TrialParams = {'maxTrials', 'Typeprob', 'ITImin', 'ITImax'};
    S.GUIPanels.TestPulses = {'TestPulses', 'TestPulsesType'};
    S.GUIPanels.TreatmentType = {'Ephys', 'EEG', 'Drug'};
    S.GUIPanels.ProtocolSettings = {'Sleep', 'muBarcodeDur', 'sigmaBarcodeDur'};
    S.GUIPanels.Sniff = {'SniffOnsetThreshold', 'SniffOffsetThreshold', 'CalibrateSniff'};

    % == Trial Params ==
    S.GUI.maxTrials = 10000;  
    S.GUIMeta.maxTrials.Label = 'Max Trials';
    S.GUI.Typeprob = 0.5;
    S.GUIMeta.Typeprob.Label = 'Type 1 Probability';
    S.GUI.ITImin = 2;
    S.GUIMeta.ITImin.Label = 'ITI Min (s)';
    S.GUI.ITImax = 5;
    S.GUIMeta.ITImax.Label = 'ITI Max (s)';
    
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
    S.GUI.EEG = true;
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
    S.GUI.Sleep = 3;
    S.GUIMeta.Sleep.Style = 'popupmenu';
    S.GUIMeta.Sleep.String = {'Pre-sleep', 'Post-sleep', 'During-sleep', 'None'};
    S.GUIMeta.Sleep.Label = 'Sleep Phase';

    %% OptoStim
    S.GUITabs.OptoStim = {'Pattern_opto', 'MaskLED', 'SinglePulse', 'PairedPulse'};

    % == Opto pattern (ITI delivery) ==
    S.GUIPanels.Pattern_opto = {'patternSel_opto'};
    S.GUI.patternSel_opto = 0;
    S.GUIMeta.patternSel_opto.Style        = 'pattern_selector';
    S.GUIMeta.patternSel_opto.ProbParam    = 'patternProbs_opto';
    S.GUIMeta.patternSel_opto.NFramesParam = 'patternNFrames_opto';
    S.GUIMeta.patternSel_opto.ExposureParam= 'patternExposure_opto';
    S.GUIMeta.patternSel_opto.TypeName     = 'opto';
    S.GUIMeta.patternSel_opto.Label        = '';
    S.GUI.patternProbs_opto    = [1]; S.GUIMeta.patternProbs_opto.Hidden    = true;
    S.GUI.patternNFrames_opto  = [1]; S.GUIMeta.patternNFrames_opto.Hidden  = true;
    S.GUI.patternExposure_opto = [1e6]; S.GUIMeta.patternExposure_opto.Hidden = true;

    S.GUIPanels.SinglePulse = {'SPfrequency', 'SPvariable', 'MaxSPfrequency'};
    S.GUIPanels.PairedPulse = {'PPfrequency', 'PPvariable', 'MaxPPfrequency'};
    S.GUIPanels.MaskLED = {'Intensity_mask', 'Duration_mask'};

    S.GUI.SPfrequency = 0.01;
    S.GUIMeta.SPfrequency.Label = 'Freq (Hz)';
    S.GUI.SPvariable = true;
    S.GUIMeta.SPvariable.Style = 'checkbox';
    S.GUIMeta.SPvariable.Label = 'Variable Freq';
    S.GUI.MaxSPfrequency = 0.02;
    S.GUIMeta.MaxSPfrequency.Label = 'Max Freq (Hz)';

    S.GUI.PPfrequency = 0.01;
    S.GUIMeta.PPfrequency.Label = 'Freq (Hz)';
    S.GUI.PPvariable = true;
    S.GUIMeta.PPvariable.Style = 'checkbox';
    S.GUIMeta.PPvariable.Label = 'Variable Freq';
    S.GUI.MaxPPfrequency = 0.02;
    S.GUIMeta.MaxPPfrequency.Label = 'Max Freq (Hz)';

    S.GUI.Intensity_mask = 100;
    S.GUIMeta.Intensity_mask.Label = 'Intensity (0-255)';
    S.GUI.Duration_mask = 0.01;
    S.GUIMeta.Duration_mask.Label = 'Duration (s)';
    
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

    % == Sniff ==
    S.GUI.SniffOnsetThreshold = 0.5;
    S.GUIMeta.SniffOnsetThreshold.Label = 'Sniff Onset Thresh (V)';
    S.GUI.SniffOffsetThreshold = 1.5;
    S.GUIMeta.SniffOffsetThreshold.Label = 'Sniff Offset Thresh (V)';
    S.GUI.CalibrateSniff = 0;
    S.GUIMeta.CalibrateSniff.Style = 'pushbutton';
    S.GUIMeta.CalibrateSniff.String = 'Calibrate Sniff (12s)';
    S.GUIMeta.CalibrateSniff.Callback = 'RunSniffCalibration';
    S.GUIMeta.CalibrateSniff.CallbackArg = '';

end
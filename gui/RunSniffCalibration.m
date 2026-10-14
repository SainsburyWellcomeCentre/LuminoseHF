function RunSniffCalibration(~)
% RunSniffCalibration  Pushbutton callback for the "Calibrate Sniff (12s)" button.
%
%   Runs a 12-second Bpod recording, auto-detects sniff peaks, and writes
%   the computed onset/offset thresholds back to the SniffOnsetThreshold and
%   SniffOffsetThreshold GUI fields so they take effect when START is pressed.
%
%   Called via GUIMeta.CalibrateSniff.Callback from any luminose protocol.

    global BpodSystem %#ok<GVMIS> Bpod's

    % Not during a session (its trial manager owns the state machine), and one at a time:
    % a second press would start a trial while the first still runs
    gui = [];
    try gui = BpodSystem.ProtocolFigures.ParameterGUI; catch, end
    if ~isempty(gui) && isgraphics(gui)
        if isappdata(gui, 'StartPressed') && getappdata(gui, 'StartPressed')
            warndlg('A session is running: calibrate the sniff sensor before START.', 'Sniff Calibration');
            return
        end
        if isappdata(gui, 'SniffCalibrating') && getappdata(gui, 'SniffCalibrating')
            return  % already running
        end
        setappdata(gui, 'SniffCalibrating', true);
        running = onCleanup(@() clearFlag(gui));  % however it ends
    end

    risingEdge = false;  % an inhalation drops the signal (SniffDetector)

    %% Run calibration
    try
        [onsetV, offsetV, ~] = calibrateSniffThresholds(risingEdge, 12);
    catch ME
        errordlg(sprintf('Calibration error: %s', ME.message), 'Sniff Calibration');
        return
    end

    if isnan(onsetV) || isnan(offsetV)
        return   % calibrateSniffThresholds already showed a warndlg
    end

    %% Write results back to GUI
    idxMap = BpodSystem.GUIData.ParameterGUI.ParamIndexByName;

    if isfield(idxMap, 'SniffOnsetThreshold')
        idx = idxMap.SniffOnsetThreshold;
        h   = BpodSystem.GUIHandles.ParameterGUI.Params(idx);
        set(h, 'String', num2str(onsetV, '%.2f'));
        BpodSystem.GUIData.ParameterGUI.LastParamValues{idx} = onsetV;
        BpodSystem.GUIData.ParameterGUI.LatestGUIParams.SniffOnsetThreshold = onsetV;
    end

    if isfield(idxMap, 'SniffOffsetThreshold')
        idx = idxMap.SniffOffsetThreshold;
        h   = BpodSystem.GUIHandles.ParameterGUI.Params(idx);
        set(h, 'String', num2str(offsetV, '%.2f'));
        BpodSystem.GUIData.ParameterGUI.LastParamValues{idx} = offsetV;
        BpodSystem.GUIData.ParameterGUI.LatestGUIParams.SniffOffsetThreshold = offsetV;
    end

    msgbox(sprintf('Calibration complete.\nOnset: %.2f V    Offset: %.2f V', onsetV, offsetV), ...
        'Sniff Calibration', 'help');

end


function clearFlag(gui)
% The calibration ended (or failed): it may run again.
    if isgraphics(gui)
        setappdata(gui, 'SniffCalibrating', false);
    end
end

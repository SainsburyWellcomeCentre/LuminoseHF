function [onsetV, offsetV, fig] = calibrateSniffThresholds(risingEdge, recordDur_s)
% calibrateSniffThresholds  Auto-detect sniff peaks and propose FlexIO thresholds.
%
%   [onsetV, offsetV, fig] = calibrateSniffThresholds(risingEdge, recordDur_s)
%
%   Runs a silent Bpod trial of recordDur_s seconds, reads the FlexIO binary
%   file directly, then uses SniffDetector.detectFromAnalog to find sniff
%   events and computes voltage thresholds from detected peak excursions.
%
%   Inputs
%     risingEdge   : logical — true if signal rises during inhalation
%     recordDur_s  : recording duration in seconds (default: 12)
%
%   Outputs
%     onsetV       : suggested onset threshold (V)
%     offsetV      : suggested offset threshold (V)
%     fig          : diagnostic figure handle
%
%   Threshold placement
%     Onset  is placed 40% of the way from baseline to the median peak excursion.
%     Offset is placed 25% of the way (fires earlier on signal return).
%     Hysteresis gap ≈ 15% of the median excursion.

    global BpodSystem %#ok<GVMIS> Bpod's

    if nargin < 2 || isempty(recordDur_s), recordDur_s = 12; end
    if nargin < 1 || isempty(risingEdge),  risingEdge  = false; end

    onsetV  = NaN;
    offsetV = NaN;
    fig     = [];

    sampleRate    = 500;
    ch            = 1;
    nSamplesNeeded = round(recordDur_s * sampleRate);

    %% Ensure FlexIO channel 1 is configured and analog viewer is running
    BpodSystem.FlexIOConfig.channelTypes(ch)   = 2;   % Analog Input
    BpodSystem.FlexIOConfig.threshold1(ch)     = 0;   % dummy — no triggers during calibration
    BpodSystem.FlexIOConfig.polarity1(ch)      = 0;
    BpodSystem.FlexIOConfig.threshold2(ch)     = 5;
    BpodSystem.FlexIOConfig.polarity2(ch)      = 1;
    BpodSystem.FlexIOConfig.thresholdMode(ch)  = 1;
    BpodSystem.FlexIOConfig.analogSamplingRate = sampleRate;

    % Start analog viewer if not already running — this creates the binary file
    % and populates BpodSystem.Data.Analog.
    analogReady = isfield(BpodSystem.Data, 'Analog') && ...
                  isfield(BpodSystem.Data.Analog, 'FileName') && ...
                  ~isempty(BpodSystem.Data.Analog.FileName);
    if ~analogReady
        BpodSystem.startAnalogViewer;
        pause(0.5);
    end

    if ~isfield(BpodSystem.Data, 'Analog') || ~isfield(BpodSystem.Data.Analog, 'FileName')
        warndlg('Analog viewer could not be started. Check FlexIO channel configuration.', ...
            'Sniff Calibration');
        return
    end

    %% Run a silent calibration trial
    sma = NewStateMachine();
    sma = AddState(sma, 'Name', 'Record', ...
        'Timer', recordDur_s, ...
        'StateChangeConditions', {'Tup', 'exit'}, ...
        'OutputActions', {'AnalogThreshEnable', 1});
    SendStateMachine(sma);
    % A trial manager left polling by a stopped session would read this trial's end
    % first, and RunStateMachine would wait forever
    lhf.bpod.stopStrayTrialTimers();
    RunStateMachine();

    %% Read channel 1 directly from the binary file
    % Format: each record = [trialNum, ch1, ch2, ..., chN] as uint16.
    % Record stride = nChannels + 1.  Channel 1 is at offset ch (= 1) within each record.
    analogFile = BpodSystem.Data.Analog.FileName;
    nCh        = BpodSystem.Data.Analog.nChannels;

    if ~exist(analogFile, 'file')
        warndlg('Analog data file not found. Run the protocol once to initialise the file.', ...
            'Sniff Calibration');
        return
    end

    fid     = fopen(analogFile, 'r');
    rawData = fread(fid, Inf, 'uint16');
    fclose(fid);

    stride = nCh + 1;
    if numel(rawData) < stride
        warndlg('Analog file is empty. Check FlexIO configuration.', 'Sniff Calibration');
        return
    end

    nRecords = floor(numel(rawData) / stride);
    rawData  = rawData(1 : nRecords * stride);

    % Channel ch is at column index ch+1 within each record (1-indexed),
    % because column 1 holds the trial number.
    ch1Bits = rawData(ch + 1 : stride : end);
    signal  = double(ch1Bits) / 4095 * 5;   % bits → volts (0–5 V range)

    % Keep only the calibration window (last N samples)
    if numel(signal) >= nSamplesNeeded
        signal = signal(end - nSamplesNeeded + 1 : end);
    end

    if numel(signal) < 50
        warndlg(['Could not extract enough analog samples. ' ...
            'Ensure the sniff sensor is connected to FlexIO channel 1.'], ...
            'Sniff Calibration');
        return
    end

    %% Detect sniff events
    % detectFromAnalog finds troughs (inhalation minima for falling-edge sensors).
    % For a rising-edge sensor, negate the signal so peaks become troughs.
    tmp           = SniffDetector(ch, sampleRate);
    tmp.risingEdge = false;

    sig = signal(:);
    if risingEdge
        sig_detect = -sig;
    else
        sig_detect = sig;
    end

    peakSamples = [];
    searchFrom  = 0;
    for iter = 1:200
        [onset_s, peak_s, offset_s] = tmp.detectFromAnalog(sig_detect, searchFrom);
        if isnan(onset_s), break; end
        peakSamples(end+1) = max(1, round(peak_s * sampleRate) + 1); %#ok<AGROW>
        if isnan(offset_s) || (offset_s + 0.05) * sampleRate >= numel(sig_detect)
            break
        end
        searchFrom = offset_s + 0.05;
    end

    nSniffs = numel(peakSamples);
    if nSniffs < 5
        warndlg(sprintf(['Only %d sniff(s) detected (need ≥5).\n' ...
            'Breathe through the sensor during calibration, or adjust\n' ...
            'SniffDetector prominence / minWidth parameters.'], nSniffs), ...
            'Sniff Calibration');
        return
    end

    %% Compute thresholds
    baseline_V = median(sig);

    if risingEdge
        peakVals = zeros(nSniffs, 1);
        for i = 1:nSniffs
            hw = round(0.1 * sampleRate);
            lo = max(1, peakSamples(i) - hw);
            hi = min(numel(sig), peakSamples(i) + hw);
            peakVals(i) = max(sig(lo:hi));
        end
        excursion = median(peakVals) - baseline_V;
        onsetV  = baseline_V + 0.40 * excursion;
        offsetV = baseline_V + 0.25 * excursion;
    else
        excursion = baseline_V - median(sig(peakSamples));
        onsetV  = baseline_V - 0.40 * excursion;
        offsetV = baseline_V - 0.25 * excursion;
    end

    onsetV  = max(0.2, min(4.8, onsetV));
    offsetV = max(0.2, min(4.8, offsetV));
    minGap  = 0.10;
    if abs(onsetV - offsetV) < minGap
        offsetV = onsetV + (risingEdge * -2 + 1) * minGap;  % -gap for rising, +gap for falling
        offsetV = max(0.2, min(4.8, offsetV));
    end

    %% Diagnostic figure
    t = (0 : numel(sig)-1) / sampleRate;

    fig = figure('Name', 'Sniff Calibration', 'NumberTitle', 'off', ...
        'Position', [100 100 900 500]);

    ax1 = subplot(2,1,1);
    plot(t, sig, 'Color', [0.2 0.4 0.7], 'LineWidth', 0.8);
    hold on;
    yline(onsetV,  'r--', sprintf('Onset %.2fV',  onsetV),  'LabelHorizontalAlignment', 'left');
    yline(offsetV, 'm--', sprintf('Offset %.2fV', offsetV), 'LabelHorizontalAlignment', 'left');
    plot(peakSamples/sampleRate, sig(peakSamples), 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    xlabel('Time (s)'); ylabel('Voltage (V)');
    title(sprintf('Raw signal — %d sniffs detected', nSniffs));
    grid on;

    ax2 = subplot(2,1,2);
    n   = numel(sig_detect);
    t_s = (0:n-1)' / sampleRate;
    knotSpacing = round(2.0 * sampleRate);
    interior    = (knotSpacing : knotSpacing : n - knotSpacing)' / sampleRate;
    try
        if numel(interior) >= 1
            sp           = spap2(augknt([t_s(1); interior; t_s(end)], 4), 4, t_s, sig_detect);
            baseline_fit = fnval(sp, t_s);
        else
            baseline_fit = linspace(sig_detect(1), sig_detect(end), n)';
        end
    catch
        baseline_fit = linspace(sig_detect(1), sig_detect(end), n)';
    end
    detrended = sig_detect - baseline_fit;
    [b, a]    = butter(4, 20 / (sampleRate/2), 'low');
    filtered  = filtfilt(b, a, detrended);
    if risingEdge, filtered = -filtered; end
    plot(t, filtered, 'Color', [0.2 0.6 0.3], 'LineWidth', 0.8);
    hold on;
    plot(peakSamples/sampleRate, filtered(peakSamples), 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    xlabel('Time (s)'); ylabel('Detrended (V)');
    title('Detrended + filtered signal with detected peaks');
    grid on;

    linkaxes([ax1 ax2], 'x');

function virtualSessions(runFolder, maxTrials)
% virtualSessions  powercal sessions back to back with a virtual subject, to catch crashes.
%
%   virtualSessions(runFolder, maxTrials)
%
%   The soak test (docs/testing.md), started by soak.sh in a MATLAB of its own. It
%   connects Bpod and runs luminose_hf_powercal for FakeSubject, one session after
%   another, until D:\luminoseData\soak\STOP exists (checked between sessions); then it
%   writes 'clean exit' and quits. A crash ends MATLAB without that line, which is what
%   soak.sh looks for.
%
%   The rig runs as in a session except the camera and laser: the stimuli are LUMI-0022's
%   (a light cue, CS+ and CS- patterns: powercal's newest designs, so the DMD projects
%   every trial; Sniff Trigger off, as no one sniffs), and Laser control is on with a simulated laser (obis's
%   SimulatedTransport, installed as lhf.device('laser')), so the power is set every trial
%   and the Laser panel opens on it. The settings are LUMI-0022's with those changes,
%   Training at CS+ probability 0.5 and maxTrials,
%   written to FakeSubject's VirtualSoak.mat each launch (a session saves its settings
%   back there as it ends, so a change to the file lasts one session only).
%
%   virtualUser is the operator: clicks, typing and panels during each session (see it),
%   and Stop at a random trial in about a third of the sessions.
%
%   START is pressed by a timer (the button's own callback). A second timer licks:
%   every 50 ms it releases BNC input 1 (the lick sensor) if held, or presses it with
%   probability 0.05, with the message Bpod's ManualOverride sends (a virtual event, as
%   the console's button sends) but not its drawnow (see lickTick). It is itself a timer acting on BpodSystem; see the caveat in
%   docs/testing.md.
%
%   Each session's analog data (_ANLG.dat) is written beside its data, as the Launch
%   Manager does: RunProtocol writes it in the current folder, so the driver moves there. Before
%   each session the session clock is reset, as the Launch Manager does; without that
%   the state machine streams no analog data after the first session ('X', sent by
%   RunProtocol('Stop'), stops it; '*' starts it again; found 2026-10-21).
%
%   runFolder/run_log.txt gets a line as each session starts and ends, written and
%   closed at once so it survives a crash.

    global BpodSystem %#ok<GVMIS> Bpod's
    repo = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(repo);
    stopFile = fullfile(fileparts(runFolder), 'STOP');
    logLine(runFolder, 'driver started: MATLAB %s, maxTrials %d', version, maxTrials);
    lick = [];
    try
        luminose = LuminoseConstants();
        writeSettings(char(luminose.f.luminoseData), maxTrials);
        Bpod('COM3');
        cfg = luminose.laser;
        lhf.device('laser', obis.Laser('Transport', obis.transport.SimulatedTransport(), ...
            'MaxPowermW', cfg.maxPower_mW));
        virtualUser('start', runFolder, 2);
        plan = RandStream('mt19937ar', 'Seed', 3);
        cd(fullfile(char(luminose.f.luminoseData), 'FakeSubject', 'luminose_hf_powercal', 'Session Data'));
        % RunProtocol writes each session's _ANLG.dat in the current folder: beside the
        % session's data, as the Launch Manager does
        lick = timer('Name', 'soak.lick', 'ExecutionMode', 'fixedSpacing', 'Period', 0.05, ...
            'BusyMode', 'drop', 'UserData', RandStream('mt19937ar', 'Seed', 1), ...
            'TimerFcn', @lickTick);
        session = 0;
        while ~isfile(stopFile)
            session = session + 1;
            press = timer('Name', 'soak.start', 'ExecutionMode', 'fixedSpacing', 'Period', 0.5, ...
                'TimerFcn', @(t, ~) pressStart(t, runFolder, session));
            stopAt = Inf;
            if rand(plan) < 1/3, stopAt = randi(plan, [20 maxTrials]); end
            virtualUser('session', stopAt);
            BpodSystem.resetSessionClock();  % as LaunchManager does: restarts the Flex analog
            % stream, which the 'X' RunProtocol('Stop') sends at a session's end turns off
            start(press);
            start(lick);
            RunProtocol('Start', 'luminose_hf_powercal', 'FakeSubject', 'VirtualSoak');
            stop(lick);
            stop(press);
            delete(press);
            logLine(runFolder, 'session %d ended: %s', session, describeEnd(BpodSystem));
            leakReport(runFolder, session);
        end
        delete(lick);
        virtualUser('stop');
        logLine(runFolder, 'clean exit');
        quit(0, 'force');
    catch ME
        if ~isempty(lick) && isvalid(lick), stop(lick); end
        logLine(runFolder, 'driver error: %s (%s line %d)', ME.message, ME.stack(1).name, ME.stack(1).line);
        quit(2, 'force');
    end
end

function writeSettings(dataFolder, maxTrials)
% FakeSubject's VirtualSoak.mat: LUMI-0022's settings and stimuli, the simulated laser
    source = fullfile(dataFolder, 'LUMI-0022', 'luminose_hf_powercal', 'Session Settings', 'DefaultSettings.mat');
    loaded = load(source);
    ProtocolSettings = loaded.ProtocolSettings;
    ProtocolSettings.GUI.CueType = 1;        % Light
    ProtocolSettings.GUI.CSplusType = 4;     % Pattern
    ProtocolSettings.GUI.CSminusType = 4;    % Pattern
    ProtocolSettings.GUI.LaserControl = true;   % the simulated laser
    ProtocolSettings.GUI.SniffTrigger = false;  % no animal: a pattern would wait for a sniff forever
    ProtocolSettings.GUI.TestPulses = false;
    ProtocolSettings.GUI.TrainingLevel = 2;  % Training: CS+ and CS- trials, as in the crashed sessions
    ProtocolSettings.GUI.CSplus_prob = 0.5;
    ProtocolSettings.GUI.maxTrials = maxTrials;
    ProtocolSettings.RandomSeed = [];
    folder = fullfile(dataFolder, 'FakeSubject', 'luminose_hf_powercal', 'Session Settings');
    if ~isfolder(folder), mkdir(folder); end
    save(fullfile(folder, 'VirtualSoak.mat'), 'ProtocolSettings');
end

function pressStart(t, runFolder, session)
% Presses START once the protocol is waiting for it (StartPressed set false)
    global BpodSystem %#ok<GVMIS> Bpod's
    try
        gui = BpodSystem.ProtocolFigures.ParameterGUI;
        if ~ishandle(gui) || ~isappdata(gui, 'StartPressed') || getappdata(gui, 'StartPressed')
            return
        end
        button = BpodSystem.GUIHandles.ParameterGUI.StartButton;
        callback = get(button, 'Callback');
        stop(t);
        logLine(runFolder, 'session %d started: %s', session, BpodSystem.Path.CurrentDataFile);
        callback(button, []);
    catch
    end
end

function lickTick(t, ~)
% Releases BNC input 1 if held, else presses it with probability 0.05
    global BpodSystem %#ok<GVMIS> Bpod's
    try
        if BpodSystem.Status.BeingUsed ~= 1, return; end
        ch = find(BpodSystem.HW.Inputs == 'B', 1);
        if BpodSystem.HardwareState.InputState(ch) == 1 || rand(t.UserData) < 0.05
            % ManualOverride('IB', 1)'s message without its GUI refresh: its drawnow,
            % called from this timer during another drawnow, spun MATLAB for 4 minutes
            BpodSystem.HardwareState.InputState(ch) = 1 - BpodSystem.HardwareState.InputState(ch);
            BpodSystem.SerialPort.write(['V' ch-1 BpodSystem.HardwareState.InputState(ch)], 'uint8');
        end
    catch
    end
end

function text = describeEnd(BpodSystem)
    text = '(no data)';
    try
        data = BpodSystem.Data;
        nTrials = 0;
        if isfield(data, 'nTrials'), nTrials = data.nTrials; end
        reason = 'none recorded';
        if isfield(data, 'StoppedReason')
            reason = data.StoppedReason.Reason;
            if ~isempty(data.StoppedReason.Message)
                reason = sprintf('%s (%s)', reason, data.StoppedReason.Message);
            end
        end
        text = sprintf('%d trials, %s, %s', nTrials, reason, BpodSystem.Path.CurrentDataFile);
        mem = memory;
        text = sprintf('%s, MATLAB uses %.1f GB', text, mem.MemUsedMATLAB / 1e9);
    catch
    end
end

function leakReport(runFolder, session)
% What is left after a session: timers (by name or callback), figures, graphics objects,
% root appdata, BpodSystem.Data's size, MATLAB's and Java's memory. To runFolder/leaks.txt.
    global BpodSystem %#ok<GVMIS> Bpod's
    fid = fopen(fullfile(runFolder, 'leaks.txt'), 'a');
    if fid < 0, return; end
    closer = onCleanup(@() fclose(fid));
    try
        fprintf(fid, '== after session %d, %s\n', session, char(datetime('now', 'Format', 'HH:mm:ss')));
        mem = memory;
        rt = java.lang.Runtime.getRuntime();
        fprintf(fid, 'MATLAB %.0f MB, Java heap used %.0f MB of %.0f MB\n', mem.MemUsedMATLAB / 1e6, ...
            double(rt.totalMemory() - rt.freeMemory()) / 1e6, double(rt.maxMemory()) / 1e6);
        timers = timerfindall;
        labels = cell(1, numel(timers));
        for k = 1:numel(timers)
            label = timers(k).Name;
            fcn = timers(k).TimerFcn;
            if isa(fcn, 'function_handle'), fcn = func2str(fcn); end
            if iscell(fcn), fcn = 'cell'; end
            if startsWith(label, 'timer-'), label = ['(' timers(k).Tag ') ' char(fcn)]; end
            labels{k} = sprintf('%s [%s]', label, timers(k).Running);
        end
        fprintf(fid, 'timers: %d\n', numel(timers));
        [names, ~, idx] = unique(labels);
        for k = 1:numel(names)
            fprintf(fid, '  %3d x %s\n', sum(idx == k), names{k});
        end
        figs = findall(groot, 'Type', 'figure');
        fprintf(fid, 'figures: %d (%s)\n', numel(figs), strjoin(unique(string({figs.Name})), ', '));
        fprintf(fid, 'graphics objects: %d\n', numel(findall(groot)));
        fprintf(fid, 'root appdata: %s\n', strjoin(fieldnames(getappdata(0)), ', '));
        data = BpodSystem.Data; %#ok<NASGU> sized below
        w = whos('data');
        fprintf(fid, 'BpodSystem.Data: %.1f MB; functions in memory: %d\n', w.bytes / 1e6, numel(inmem));
    catch err
        fprintf(fid, 'report failed: %s\n', err.message);
    end
end

function logLine(runFolder, varargin)
    fid = fopen(fullfile(runFolder, 'run_log.txt'), 'a');
    if fid < 0, return; end
    fprintf(fid, '%s  %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), sprintf(varargin{:}));
    fclose(fid);
end

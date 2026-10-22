function virtualUser(action, varargin)
% virtualUser  An operator for the soak test: clicks, typing and panels during sessions.
%
%   virtualUser('start', runFolder, seed)   starts it (once, after Bpod)
%   virtualUser('session', stopAtTrial)     a new session: Stop pressed at that trial
%                                           (Inf: runs to maxTrials)
%   virtualUser('stop')                     stops and deletes it
%
%   Every 10-40 s while a session runs (a 1 s timer that acts when due) it does one thing an operator does, the way the
%   operator does it: java.awt.Robot moves the real pointer and clicks or types, so the
%   click goes through MATLAB's event queue as a person's does (not called from this
%   timer). Its window is brought to the front first. What it does:
%     tab     selects a parameter GUI tab
%     edit    types a new CS+ probability (0.4-0.6), reward (2-3 uL) or ITI (4-6 s)
%     panel   clicks Laser, DMD or Calibrate under START (never Camera, nor the Pattern
%             Designer, which draws on the camera's panel, nor Stage: the stage must
%             not move, and a stray click on its panel could move it)
%     close   closes an open panel, as its window's X does
%     pause   clicks Bpod's Pause, and Resume on the next action
%     sniff   clicks Calibrate Sniff (refused during a session)
%     move    moves the Live Plots window
%   and clicks Bpod's Stop at the session's stopAtTrial. Each action is a line in
%   runFolder/actions.txt, written and closed at once so it survives a crash.
%
%   The pointer and keyboard are the rig's: nobody can use them while it runs.

    switch action
        case 'start'
            stopTimer();
            state = struct('runFolder', varargin{1}, 'rng', RandStream('mt19937ar', 'Seed', varargin{2}), ...
                'stopAtTrial', Inf, 'paused', false, 'robot', java.awt.Robot(), ...
                'nextAt', datetime('now') + seconds(15));
            t = timer('Name', 'soak.user', 'ExecutionMode', 'fixedSpacing', 'Period', 1, ...
                'BusyMode', 'drop', 'UserData', state, 'TimerFcn', @tick);
            start(t);
        case 'session'
            t = timerfindall('Name', 'soak.user');
            if isempty(t), return; end
            state = t.UserData;
            state.stopAtTrial = varargin{1};
            state.paused = false;
            t.UserData = state;
            note(state, 'session plan: Stop at trial %g', state.stopAtTrial);
        case 'stop'
            stopTimer();
    end
end

function stopTimer()
    t = timerfindall('Name', 'soak.user');
    if ~isempty(t)
        stop(t);
        delete(t);
    end
end

function tick(t, ~)
% Every second: acts when the next action is due and a session's GUI is up
    global BpodSystem %#ok<GVMIS> Bpod's
    state = t.UserData;
    if datetime('now') < state.nextAt, return; end
    try
        if ~isempty(BpodSystem) && BpodSystem.Status.BeingUsed == 1 ...
                && isfield(BpodSystem.GUIHandles, 'ParameterGUI') && isfield(BpodSystem.GUIHandles.ParameterGUI, 'Tabs')
            state = act(state);
        end
    catch err
        note(state, 'action failed: %s', err.message);
    end
    state.nextAt = datetime('now') + seconds(10 + 30 * rand(state.rng));
    t.UserData = state;
end

function state = act(state)
    global BpodSystem %#ok<GVMIS> Bpod's
    nTrials = 0;
    if isfield(BpodSystem.Data, 'nTrials'), nTrials = BpodSystem.Data.nTrials; end
    if state.paused
        click(state, BpodSystem.GUIHandles.RunButton);
        state.paused = false;
        note(state, 'trial %d: resume', nTrials);
        return
    end
    if nTrials >= state.stopAtTrial
        click(state, BpodSystem.GUIHandles.EndButton);
        state.stopAtTrial = Inf;
        note(state, 'trial %d: Stop', nTrials);
        return
    end
    actions = {'tab', 'edit', 'panel', 'close', 'pause', 'sniff', 'move'};
    weights = [3 3 3 2 1 1 1];
    what = actions{find(rand(state.rng) * sum(weights) < cumsum(weights), 1)};
    gui = BpodSystem.GUIHandles.ParameterGUI;
    switch what
        case 'tab'
            tabs = gui.Tabs.TabGroup.Children;
            tab = tabs(randi(state.rng, numel(tabs)));
            gui.Tabs.TabGroup.SelectedTab = tab;
            detail = tab.Title;
        case 'edit'
            names = {'CSplus_prob', 'RewardAmount', 'InterTrialInterval'};
            ranges = [0.4 0.6; 2 3; 4 6];
            k = randi(state.rng, numel(names));
            value = round(ranges(k, 1) + diff(ranges(k, :)) * rand(state.rng), 2);
            h = gui.Params(BpodSystem.GUIData.ParameterGUI.ParamIndexByName.(names{k}));
            gui.Tabs.TabGroup.SelectedTab = ancestor(h, 'uitab');
            drawnow;
            click(state, h);
            type(state, num2str(value));
            detail = sprintf('%s = %g', names{k}, value);
        case 'panel'
            buttons = gui.DeviceButtons;
            buttons = buttons(~ismember(get(buttons, 'String'), {'Camera', 'Stage'}));
            b = buttons(randi(state.rng, numel(buttons)));
            gui.Tabs.TabGroup.SelectedTab = ancestor(b, 'uitab');
            drawnow;
            click(state, b);
            detail = get(b, 'String');
        case 'close'
            [fig, detail] = openPanel(state);
            if isempty(fig)
                detail = 'none open';
            else
                close(fig);  % its CloseRequestFcn, as the X
            end
        case 'pause'
            click(state, BpodSystem.GUIHandles.RunButton);
            state.paused = true;
            detail = '';
        case 'sniff'
            h = gui.Params(BpodSystem.GUIData.ParameterGUI.ParamIndexByName.CalibrateSniff);
            gui.Tabs.TabGroup.SelectedTab = ancestor(h, 'uitab');
            drawnow;
            click(state, h);
            detail = '';
        case 'move'
            fig = findall(groot, 'Type', 'figure', 'Name', 'Live Plots');
            detail = 'no window';
            if ~isempty(fig)
                fig = fig(1);
                p = fig.Position;
                fig.Position = [p(1) + round(40 * (rand(state.rng) - 0.5)), p(2) + round(40 * (rand(state.rng) - 0.5)), p(3:4)];
                detail = mat2str(fig.Position);
            end
    end
    note(state, 'trial %d: %s %s', nTrials, what, detail);
end

function [fig, name] = openPanel(state)
% A random open device panel's window
    fig = [];
    name = '';
    if ~isappdata(0, 'lhfDevicePanels'), return; end
    panels = getappdata(0, 'lhfDevicePanels');
    names = fieldnames(panels);
    figs = {};
    for k = 1:numel(names)
        f = panelFigure(panels.(names{k}));
        if ~isempty(f)
            figs{end + 1} = f; %#ok<AGROW>
            names{numel(figs)} = names{k};
        end
    end
    if isempty(figs), return; end
    k = randi(state.rng, numel(figs));
    fig = figs{k};
    name = names{k};
end

function fig = panelFigure(app)
    fig = [];
    try
        if isa(app, 'matlab.ui.Figure')
            candidates = {app};
        else
            candidates = cellfun(@(p) app.(p), intersect(properties(app), {'UIFigure', 'Figure', 'Fig'}), ...
                'UniformOutput', false);
        end
        for k = 1:numel(candidates)
            if isa(candidates{k}, 'matlab.ui.Figure') && isvalid(candidates{k})
                fig = candidates{k};
                return
            end
        end
    catch
    end
end

function click(state, h)
% Brings h's window to the front and clicks h's centre with the real pointer
    fig = ancestor(h, 'figure');
    figure(fig);
    drawnow;
    p = getpixelposition(h, true);
    f = getpixelposition(fig);
    screen = get(groot, 'ScreenSize');
    javaSize = java.awt.Toolkit.getDefaultToolkit().getScreenSize();
    scale = double(javaSize.getHeight()) / screen(4);
    x = (f(1) + p(1) + p(3) / 2 - 1) * scale;
    y = (screen(4) - (f(2) + p(2) + p(4) / 2 - 1)) * scale;
    state.robot.mouseMove(round(x), round(y));
    pause(0.1);
    state.robot.mousePress(java.awt.event.InputEvent.BUTTON1_DOWN_MASK);
    pause(0.05);
    state.robot.mouseRelease(java.awt.event.InputEvent.BUTTON1_DOWN_MASK);
    pause(0.2);
end

function type(state, text)
% Selects the field's text and types text, then Enter
    r = state.robot;
    ctrl = java.awt.event.KeyEvent.VK_CONTROL;
    r.keyPress(ctrl); r.keyPress(java.awt.event.KeyEvent.VK_A);
    r.keyRelease(java.awt.event.KeyEvent.VK_A); r.keyRelease(ctrl);
    for c = text
        if c == '.'
            code = java.awt.event.KeyEvent.VK_PERIOD;
        else
            code = java.awt.event.KeyEvent.VK_0 + (c - '0');
        end
        r.keyPress(code);
        r.keyRelease(code);
        pause(0.03);
    end
    r.keyPress(java.awt.event.KeyEvent.VK_ENTER);
    r.keyRelease(java.awt.event.KeyEvent.VK_ENTER);
    pause(0.2);
end

function note(state, varargin)
    fid = fopen(fullfile(state.runFolder, 'actions.txt'), 'a');
    if fid < 0, return; end
    fprintf(fid, '%s  %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), sprintf(varargin{:}));
    fclose(fid);
end

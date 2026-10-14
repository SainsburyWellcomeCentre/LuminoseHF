classdef CalibrationApp < handle
% CalibrationApp  The rig's calibrations in one window: choose, set, run, check, save.
%
%   app = CalibrationApp()                  opened by the parameter GUI's Calibrate
%                                           button (lhf.devicePanel('calibration'))
%   app = CalibrationApp('Name', value, ...)
%
%   Left, the calibrations (lhf.cal.catalog): Camera - DMD, Stage - camera, Z focus,
%   Laser power. Right, the chosen one: what it does and what to set up first; its
%   settings, each editable (pre-filled with what it last ran with, else the
%   defaults from luminose_config.yaml; Defaults puts those back); Run and Stop
%   (between steps, leaving every device as it was: the DMD halted, the laser's
%   emission off, the stages back with their limits); progress, and each camera frame
%   on the Camera panel; the result plotted (lhf.cal.plot) with anything worth
%   checking. A run is not used until Save, which writes it where the rig reads it
%   (lhf.cal.save: the newest file is the one in use; the power calibration rewrites
%   dmd/power_calibration.csv, keeping the old one); Discard drops it. Saved results
%   lists every earlier run, the one in use first, and Show plots one.
%
%   The calibrations use the rig's one object per device (lhf.device), so the device
%   panels show what they do. Not while a session runs (it owns the DMD and the laser).
%
%   Options (tests and scripts)
%       'Visible'          false: an invisible window and no dialogs
%       'Luminose'         the config (default: the global, else LuminoseConstants())
%       'Folder'           where results go (default luminoseData/calibration)
%       'Devices'          struct of devices lhf.cal.run uses instead of lhf.device
%       'CameraPanel'      () -> the camera panel to show frames on, or [] (default
%                          lhf.devicePanel('camera'))
%       'Allowed'          () -> false while a session runs
%       'Confirm'          (question) -> true to go ahead (default: a dialog)
%       'SavePreferences'  false: the settings run with are not kept for next time
%
% See also lhf.cal.catalog, lhf.cal.run, lhf.cal.save, lhf.devicePanel

    properties (SetAccess = private)
        Figure
        Root
        Controls = struct()
        Catalog               % lhf.cal.catalog
        Selected = ''         % the calibration shown (its id)
        Values = struct()     % its settings as shown
        Pending = []          % a run not saved yet
        Shown = []            % the result plotted
        Running = false
        Status = ''
        LastError = ''
    end

    properties (Access = private)
        Luminose
        Folder
        Devices
        CameraPanelFcn
        Allowed
        Confirm
        Visible
        SavePreferences
        StopRequested = false
        CloseAfterRun = false
        History = struct('file', {}, 'stamp', {}, 'inUse', {})
    end

    methods
        function obj = CalibrationApp(varargin)
            p = inputParser;
            p.addParameter('Visible', true);
            p.addParameter('Luminose', []);
            p.addParameter('Folder', '');
            p.addParameter('Devices', struct());
            p.addParameter('CameraPanel', @() lhf.devicePanel('camera'));
            p.addParameter('Allowed', @() ~sessionRunning());
            p.addParameter('Confirm', []);
            p.addParameter('SavePreferences', true);
            p.parse(varargin{:});
            o = p.Results;
            obj.Luminose = o.Luminose;
            if isempty(obj.Luminose), obj.Luminose = rigConfig(); end
            obj.Folder = o.Folder;
            if isempty(obj.Folder)
                obj.Folder = fullfile(char(obj.Luminose.f.luminoseData), 'calibration');
            end
            obj.Devices = o.Devices;
            obj.CameraPanelFcn = o.CameraPanel;
            obj.Allowed = o.Allowed;
            obj.Visible = logical(o.Visible);
            obj.Confirm = o.Confirm;
            if isempty(obj.Confirm), obj.Confirm = @(q) obj.ask(q); end
            obj.SavePreferences = logical(o.SavePreferences);
            obj.Catalog = lhf.cal.catalog(obj.Luminose);
            obj.build();
            obj.select(obj.Catalog(1).id);
        end

        function delete(obj)
            obj.StopRequested = true;
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure);
            end
        end

        function select(obj, id)
            % Shows a calibration: its text, settings, saved results and the one in use.
            if obj.Running, return; end
            cal = obj.cal(id);
            obj.Selected = id;
            obj.Pending = [];
            c = obj.Controls;
            c.List.Value = id;
            c.Title.Text = cal.title;
            c.About.Text = cal.about;
            c.Before.Text = ['Before you start: ' cal.before];
            obj.Values = obj.remembered(cal);
            obj.showSettings();
            obj.refreshHistory();
            obj.Shown = [];
            delete(c.Result.Children);
            c.Messages.Value = {''};
            if ~isempty(obj.History)
                obj.showHistory(1);
            else
                c.Messages.Value = {'Nothing saved yet: set it up, Run, check the result, Save.'};
            end
            obj.setStatus('');
            obj.refresh();
        end

        function setValue(obj, key, value)
            % Changes one setting (checked against its kind; a bad one is refused).
            cal = obj.cal(obj.Selected);
            values = obj.Values;
            values.(key) = value;
            try
                obj.Values = lhf.cal.settings(cal, values);
            catch err
                obj.showError(err.message);
            end
            obj.showSettings();
        end

        function defaults(obj)
            obj.Values = lhf.cal.settings(obj.cal(obj.Selected));
            obj.showSettings();
        end

        function run(obj)
            % Runs the calibration shown with its settings; the result waits for Save.
            if obj.Running, return; end
            if ~obj.Allowed()
                obj.showError('A session is running: it owns the DMD and the laser. Calibrate after it ends.');
                return
            end
            id = obj.Selected;
            cal = obj.cal(id);
            obj.Pending = [];
            obj.StopRequested = false;
            obj.Running = true;
            obj.refresh();
            panel = obj.cameraPanel();
            if ~isempty(panel)
                try panel.setLive(false); catch, end
            end
            hooks = struct('progress', @(f, text) obj.progress(f, text), ...
                'frame', @(frame) showOn(panel, frame), 'shouldStop', @() obj.StopRequested);
            options = struct('hooks', hooks, 'save', false, 'devices', obj.Devices);
            obj.Controls.Messages.Value = {''};
            obj.setStatus(sprintf('Running %s...', cal.title));
            try
                result = lhf.cal.run(id, obj.Luminose, obj.Values, options);
                obj.Pending = result;
                obj.plotResult(result);
                obj.setStatus(sprintf('%s done: check it, then Save to use it (or Discard).', cal.title));
                if obj.SavePreferences
                    setpref('LuminoseHF', ['calibration_' id], obj.Values);
                end
            catch err
                if strcmp(err.identifier, 'lhf:cal:stopped')
                    obj.setStatus('Stopped: nothing saved; every device was left as it was.');
                else
                    obj.setStatus(['Failed: ' err.message]);
                    obj.showError(err.message);
                end
            end
            obj.Running = false;
            if obj.CloseAfterRun
                delete(obj);
                return
            end
            obj.refresh();
        end

        function stop(obj)
            % Stops a run at its next step.
            if obj.Running
                obj.StopRequested = true;
                obj.setStatus('Stopping at the next step...');
            end
        end

        function files = saveResult(obj)
            % Saves the run waiting (it becomes the one in use).
            files = {};
            if isempty(obj.Pending), return; end
            if strcmp(obj.Pending.id, 'power') && ~obj.Confirm(['Rewrite dmd/power_calibration.csv ' ...
                    'with this run? Every session converts irradiance with it. The old one is kept ' ...
                    'in the calibration folder.'])
                return
            end
            try
                files = lhf.cal.save(obj.Pending, obj.Luminose, obj.Folder);
            catch err
                obj.showError(err.message);
                return
            end
            obj.Pending = [];
            obj.refreshHistory();
            [~, name, ext] = fileparts(files{1});
            obj.setStatus(sprintf('Saved %s%s: in use from now on.', name, ext));
            obj.refresh();
        end

        function discard(obj)
            obj.Pending = [];
            obj.setStatus('Discarded: the one in use is unchanged.');
            delete(obj.Controls.Result.Children);
            if ~isempty(obj.History), obj.showHistory(1); end
            obj.refresh();
        end

        function showHistory(obj, k)
            % Plots the k-th saved result (1: the one in use).
            if k < 1 || k > numel(obj.History), return; end
            try
                result = lhf.cal.load(obj.History(k).file);
            catch err
                obj.showError(err.message);
                return
            end
            obj.Controls.HistoryList.Value = obj.History(k).file;
            obj.plotResult(result);
        end
    end

    methods (Access = private)
        function onClose(obj)
            % Closing while a run goes on stops it first (the devices are left as they were).
            if obj.Running
                obj.StopRequested = true;
                obj.CloseAfterRun = true;
            else
                delete(obj);
            end
        end

        function build(obj)
            visible = 'on';
            if ~obj.Visible, visible = 'off'; end
            obj.Figure = uifigure('Name', 'Calibration', 'Visible', visible, ...
                'Position', lhf.windowPosition('calibration', [1000 780]), 'CloseRequestFcn', @(~, ~) obj.onClose());
            obj.Root = uigridlayout(obj.Figure, [1 2], 'ColumnWidth', {200, '1x'}, 'Padding', 8);
            c = struct();
            left = uigridlayout(obj.Root, [3 1], 'RowHeight', {22, '1x', 60}, 'Padding', 0);
            uilabel(left, 'Text', 'Calibrations', 'FontWeight', 'bold');
            c.List = uilistbox(left, 'Items', {obj.Catalog.title}, 'ItemsData', {obj.Catalog.id}, ...
                'ValueChangedFcn', @(src, ~) obj.select(src.Value));
            c.FolderLabel = uilabel(left, 'Text', ['Results: ' obj.Folder], 'WordWrap', 'on', ...
                'FontSize', 10, 'FontColor', [0.4 0.4 0.4]);

            right = uigridlayout(obj.Root, [9 1], 'Padding', 0, 'RowSpacing', 6, ...
                'RowHeight', {26, 'fit', 'fit', 222, 30, 22, '1x', 50, 28});
            c.Title = uilabel(right, 'Text', '', 'FontSize', 16, 'FontWeight', 'bold');
            c.About = uilabel(right, 'Text', '', 'WordWrap', 'on');
            c.Before = uilabel(right, 'Text', '', 'WordWrap', 'on', 'FontColor', [0.6 0.35 0]);
            c.Settings = uitable(right, 'ColumnName', {'Setting', 'Value', 'Unit', 'About'}, ...
                'ColumnEditable', [false true false false], 'ColumnWidth', {130, 140, 70, 'auto'}, ...
                'RowName', {}, 'CellEditCallback', @(~, ev) obj.onEdit(ev));
            buttons = uigridlayout(right, [1 7], 'Padding', 0, ...
                'ColumnWidth', {80, 80, 80, 20, 80, 80, '1x'});
            c.Run = uibutton(buttons, 'Text', 'Run', 'FontWeight', 'bold', ...
                'BackgroundColor', [0.2 0.55 0.3], 'FontColor', [1 1 1], 'ButtonPushedFcn', @(~, ~) obj.run());
            c.Stop = uibutton(buttons, 'Text', 'Stop', 'BackgroundColor', [0.7 0.2 0.2], ...
                'FontColor', [1 1 1], 'ButtonPushedFcn', @(~, ~) obj.stop());
            c.Defaults = uibutton(buttons, 'Text', 'Defaults', 'ButtonPushedFcn', @(~, ~) obj.defaults(), ...
                'Tooltip', 'The settings from luminose_config.yaml and the built-in defaults');
            uilabel(buttons, 'Text', '');
            c.Save = uibutton(buttons, 'Text', 'Save', 'FontWeight', 'bold', ...
                'Tooltip', 'Use this run from now on (writes it to the calibration folder)', ...
                'ButtonPushedFcn', @(~, ~) obj.saveResult());
            c.Discard = uibutton(buttons, 'Text', 'Discard', 'ButtonPushedFcn', @(~, ~) obj.discard());
            c.Progress = uilabel(buttons, 'Text', '', 'FontColor', [0.3 0.3 0.3]);
            c.Status = uilabel(right, 'Text', '', 'FontWeight', 'bold');
            c.Result = uipanel(right, 'BorderType', 'none');
            c.Messages = uitextarea(right, 'Editable', 'off', 'Value', {''}, 'FontSize', 11);
            history = uigridlayout(right, [1 4], 'Padding', 0, 'ColumnWidth', {100, '1x', 70, 100});
            uilabel(history, 'Text', 'Saved results', 'FontWeight', 'bold');
            c.HistoryList = uidropdown(history, 'Items', {'(none)'}, 'ItemsData', {''});
            c.Show = uibutton(history, 'Text', 'Show', 'ButtonPushedFcn', ...
                @(~, ~) obj.showHistory(find(strcmp({obj.History.file}, c.HistoryList.Value), 1)));
            c.OpenFolder = uibutton(history, 'Text', 'Open folder', ...
                'ButtonPushedFcn', @(~, ~) openFolder(obj.Folder));
            obj.Controls = c;
        end

        function cal = cal(obj, id)
            cal = obj.Catalog(strcmp({obj.Catalog.id}, id));
        end

        function values = remembered(obj, cal)
            % The settings it last ran with (those still valid), else the defaults.
            values = lhf.cal.settings(cal);
            if ~obj.SavePreferences || ~ispref('LuminoseHF', ['calibration_' cal.id]), return; end
            last = getpref('LuminoseHF', ['calibration_' cal.id]);
            for name = fieldnames(last)'
                try
                    values = lhf.cal.settings(cal, setfield(values, name{1}, last.(name{1}))); %#ok<SFLD>
                catch
                end
            end
        end

        function showSettings(obj)
            cal = obj.cal(obj.Selected);
            n = numel(cal.settings);
            rows = cell(n, 4);
            for k = 1:n
                spec = cal.settings(k);
                rows(k, :) = {spec.label, asText(obj.Values.(spec.key), spec), spec.unit, spec.tip};
            end
            obj.Controls.Settings.Data = rows;
        end

        function onEdit(obj, ev)
            cal = obj.cal(obj.Selected);
            spec = cal.settings(ev.Indices(1));
            [value, ok] = fromText(ev.NewData, spec);
            if ~ok
                obj.showError(sprintf('%s: not understood ("%s").', spec.label, ev.NewData));
                obj.showSettings();
                return
            end
            obj.setValue(spec.key, value);
        end

        function refreshHistory(obj)
            obj.History = lhf.cal.history(obj.cal(obj.Selected), obj.Folder);
            c = obj.Controls;
            if isempty(obj.History)
                c.HistoryList.Items = {'(none saved yet)'};
                c.HistoryList.ItemsData = {''};
                return
            end
            items = arrayfun(@(h) [datestr(datenum(h.stamp, 'yyyymmdd_HHMMSS'), 'yyyy-mm-dd HH:MM:SS') ...
                inUseText(h.inUse)], obj.History, 'UniformOutput', false); %#ok<DATST,DATNM>
            c.HistoryList.Items = items;
            c.HistoryList.ItemsData = {obj.History.file};
        end

        function plotResult(obj, result)
            obj.Shown = result;
            try
                lhf.cal.plot(result, obj.Controls.Result);
            catch err
                obj.showError(['Could not plot it: ' err.message]);
            end
            lines = result.messages;
            if isempty(lines), lines = {'Nothing to flag.'}; end
            if isempty(obj.Pending) || ~isequal(result, obj.Pending)
                lines = [{sprintf('Saved %s.', result.time)}, lines];
            end
            obj.Controls.Messages.Value = lines;
        end

        function progress(obj, fraction, text)
            obj.Controls.Progress.Text = sprintf('%3.0f%%  %s', 100 * fraction, text);
            drawnow limitrate  % shows it, and lets Stop through
        end

        function refresh(obj)
            c = obj.Controls;
            c.Run.Enable = ~obj.Running;
            c.Stop.Enable = obj.Running;
            c.Defaults.Enable = ~obj.Running;
            c.List.Enable = ~obj.Running;
            c.Settings.Enable = onOff(~obj.Running);
            c.Save.Enable = ~obj.Running && ~isempty(obj.Pending);
            c.Discard.Enable = ~obj.Running && ~isempty(obj.Pending);
            c.Show.Enable = ~obj.Running && ~isempty(obj.History);
            if ~obj.Running, c.Progress.Text = ''; end
        end

        function panel = cameraPanel(obj)
            panel = [];
            if isempty(obj.CameraPanelFcn), return; end
            try
                panel = obj.CameraPanelFcn();
            catch
            end
        end

        function setStatus(obj, text)
            obj.Status = text;
            obj.Controls.Status.Text = text;
        end

        function showError(obj, message)
            obj.LastError = message;
            if obj.Visible && isvalid(obj.Figure)
                uialert(obj.Figure, message, 'Calibration');
            end
        end

        function go = ask(obj, question)
            go = ~obj.Visible || strcmp(uiconfirm(obj.Figure, question, 'Calibration', ...
                'Options', {'Go ahead', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2), 'Go ahead');
        end
    end
end


function showOn(panel, frame)
% A frame on the camera panel, if it is open.
    if ~isempty(panel) && isvalid(panel)
        try panel.showFrame(frame); catch, end
    end
end

function text = asText(value, spec)
    switch spec.kind
        case 'logical'
            text = 'no';
            if value, text = 'yes'; end
        case 'choice'
            text = value;
        case 'vector'
            text = strjoin(arrayfun(@(v) sprintf('%g', v), value, 'UniformOutput', false), ' ');
        otherwise
            text = sprintf('%g', value);
    end
end

function [value, ok] = fromText(text, spec)
    text = strtrim(char(text));
    switch spec.kind
        case 'logical'
            value = any(strcmpi(text, {'yes', 'y', 'true', '1', 'on'}));
            ok = value || any(strcmpi(text, {'no', 'n', 'false', '0', 'off'}));
        case 'choice'
            k = find(strcmpi(spec.choices, text), 1);
            ok = ~isempty(k);
            value = text;
            if ok, value = spec.choices{k}; end
        case 'vector'
            value = sscanf(regexprep(text, '[\[\],;]', ' '), '%f')';
            ok = ~isempty(value);
        otherwise
            value = str2double(text);
            ok = isfinite(value);
    end
end

function text = inUseText(inUse)
    text = '';
    if inUse, text = '  (in use)'; end
end

function s = onOff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end

function openFolder(folder)
    if ~isfolder(folder), mkdir(folder); end
    if ispc, winopen(folder); end
end

function running = sessionRunning()
% After START the protocol owns the DMD and the laser.
    global BpodSystem %#ok<GVMIS> Bpod's
    running = false;
    try
        running = logical(getappdata(BpodSystem.ProtocolFigures.ParameterGUI, 'StartPressed'));
    catch
    end
end

function config = rigConfig()
% The protocols' global LuminoseConstants, or the rig's config read now.
    global luminose %#ok<GVMIS> the protocols' global
    config = luminose;
    if isempty(config)
        config = LuminoseConstants();
    end
end

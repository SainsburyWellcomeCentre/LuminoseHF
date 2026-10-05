classdef DesignerCameraPanel < handle
% DesignerCameraPanel  The Pattern Designer's camera column: the live camera
%   as the DMD canvas, contrast, what the DMD projects, and the fiducial.
%
%   panel = DesignerCameraPanel(fig, origin, canvas, hooks, options)
%
%   fig, origin: the designer's figure and the panel's [x y] in pixels
%   (it is 420 x 760). canvas: struct axes, scale (DMD px per canvas px),
%   size ([rows cols] of the canvas), dmdSize ([rows cols]). hooks: struct
%       setBackground(img, clim)  show img (canvas-sized) under the spots
%                                 with display limits clim; [] restores
%                                 the designer's own background
%       patternImage()            the design as one logical DMD frame
%       redraw()                  redraw the canvas (calls drawOverlay)
%   options: struct, any of
%       calibrationFolder  where camera_dmd_*.mat and fiducials/ live
%       registration       an lhf.cam.fitRegistration, instead of loading one
%       makeCamera         () -> a connected hamacam.Camera (rigCamera)
%       makeDmd            () -> a connected DMDController.DMD
%       dmdAllowed         () -> false while a session runs (it owns the DMD;
%                          alignment waits too)
%       stageCalibration   an lhf.cam.fitStageCamera, instead of loading one
%       makeStages         () -> rigStages: struct x, y, z, close
%       stagesConfigured   whether zaber.axes names x, y and z, each with its safe_um
%       alignment          lhf.cam.align's settings (luminose.zaber.alignment)
%       confirm            (info) -> true to make the first alignment move
%                          (default: a dialog with the planned move)
%       confirmGoTo        (info) -> true to move X/Y to the reference's
%                          position (default: a dialog with the move)
%       exposureMs, averageFrames, animal
%
%   Align to reference (lhf.cam.align) registers the camera on the animal's
%   reference frame, moves X/Y, finds Z and refines X/Y, showing each frame;
%   pressed again it stops. The aligned frame is saved as this session's
%   entry. The stages connect on first use and are released with the rest.
%
%   The STAGE block shows X/Y/Z (Read, and after every move the column
%   makes) and Go to reference X/Y: X and Y move to where the animal's
%   reference was saved (its stageUm, else the newest session's), within
%   each axis's limits, after a confirmation; pressed again it stops. Z
%   stays, for Align to reference to find. It brings back tissue that is
%   further away than alignment's travel box.
%
%   Nothing connects until it is needed: the camera on Live or Capture,
%   the DMD when it is asked to project. Both are released when the figure
%   closes. The camera frame reaches the canvas through the camera-DMD
%   calibration (calibration/calibrate_camera_dmd.m, lhf.cam.canvasMap), so
%   a spot drawn on the tissue is projected on that tissue. Without a
%   calibration the panel says so and the camera stays off.
%
%   The designer calls drawOverlay(ax) after redrawing the canvas,
%   handleClick(x, y) first in its canvas click (true: the panel used it),
%   and patternChanged() when the design changes.

    properties (SetAccess = private)
        Camera = []           % hamacam.Camera, once connected
        Dmd = []              % DMDController.DMD, once connected
        Registration = []     % camera-DMD calibration, or []
        Frame = []            % the last camera frame, uint16
        CLim = [0 1]          % display limits, camera counts
        Fiducial = []         % the animal's fiducial (lhf.cam.loadFiducial), or []
        MarkXY = []           % the mark placed this session, camera px
        Stages = []           % rigStages, once connected
        StageCalibration = [] % lhf.cam.fitStageCamera, or []
        LastAlignment = []    % lhf.cam.align's last result
        LastStageUm = []      % [x y z] last read, or []
        Controls = struct()   % uicontrols, for scripting and tests
        LastError = ''
    end

    properties (Access = private)
        Figure
        Canvas
        Hooks
        Options
        Map = []              % lhf.cam.canvasMap for frames of MapSize
        MapSize = []          % the frame size Map was built for
        CanvasImg = []        % what the canvas shows, camera counts
        Timer = []
        Dragging = 0          % 1 low limit, 2 high limit
        Picking = false
        DmdMode = 'dark'      % 'dark' | 'allOn' | 'pattern'
        Closing = false
        Aligning = false
        Moving = false        % Go to reference X/Y is moving the stage
        StopRequested = false
    end

    properties (Constant, Access = private)
        BG = [0.13 0.13 0.15]
        LABEL = [0.75 0.75 0.75]
        TITLE = [0.8 0.8 0.8]
        EDIT = [0.22 0.22 0.25]
        BUTTON = [0.25 0.25 0.3]
        DMD_MODES = {'dark', 'allOn', 'pattern'}
    end

    methods
        function obj = DesignerCameraPanel(fig, origin, canvas, hooks, options)
            if nargin < 5, options = struct(); end
            obj.Figure = fig;
            obj.Canvas = canvas;
            obj.Hooks = hooks;
            obj.Options = withDefaults(options);
            obj.Registration = obj.Options.registration;
            if isempty(obj.Registration)
                try
                    obj.Registration = lhf.cam.loadRegistration(obj.Options.calibrationFolder);
                catch err
                    obj.LastError = err.message;
                end
            end
            obj.StageCalibration = obj.Options.stageCalibration;
            if isempty(obj.StageCalibration)
                try
                    obj.StageCalibration = lhf.cam.loadStageCalibration(obj.Options.calibrationFolder);
                catch err
                    obj.LastError = err.message;
                end
            end
            obj.build(origin);
            obj.loadAnimal();
            obj.Timer = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.1, ...
                'BusyMode', 'drop', 'Name', 'DesignerCameraPanel', ...
                'TimerFcn', @(~, ~) obj.liveTick());
            addlistener(fig, 'ObjectBeingDestroyed', @(~, ~) obj.close());
            obj.refresh();
        end

        function delete(obj)
            obj.close();
        end

        function close(obj)
            % Stops the live view and releases the camera and the DMD.
            if obj.Closing, return; end
            obj.Closing = true;
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer);
                delete(obj.Timer);
            end
            if ~isempty(obj.Camera)
                try obj.Camera.disconnect(); catch, end
            end
            if ~isempty(obj.Dmd)
                try obj.Dmd.halt(); catch, end
                try obj.Dmd.disconnect(); catch, end
            end
            if ~isempty(obj.Stages)
                try obj.Stages.close(); catch, end
            end
        end

        function setLive(obj, on)
            % Starts or stops the live view (a snapshot every 0.1 s).
            if on && obj.ensureCamera()
                if strcmp(obj.Timer.Running, 'off'), start(obj.Timer); end
            elseif strcmp(obj.Timer.Running, 'on')
                stop(obj.Timer);
            end
            obj.Controls.Live.Value = strcmp(obj.Timer.Running, 'on');
        end

        function capture(obj)
            % One averaged frame; stops the live view.
            obj.setLive(false);
            if obj.ensureCamera()
                obj.guard(@() obj.showFrame(obj.Camera.capture()));
            end
        end

        function showFrame(obj, frame)
            % Shows a camera frame on the canvas, through the calibration.
            obj.Frame = frame;
            obj.render();
        end

        function setLimits(obj, limits)
            % Display limits in camera counts; turns Auto off.
            limits = sort(double(limits));
            if limits(2) <= limits(1), limits(2) = limits(1) + 1; end
            obj.CLim = limits;
            obj.Controls.Auto.Value = false;
            obj.applyLimits();
        end

        function autoLimits(obj)
            % Limits from the 0.5th and 99.5th percentiles of the DMD field.
            v = obj.fieldPixels();
            if isempty(v), return; end
            limits = double(prctile(v, [0.5 99.5]));
            if limits(2) <= limits(1), limits(2) = limits(1) + 1; end
            obj.CLim = limits;
            obj.applyLimits();
        end

        function setDmdMode(obj, mode)
            % 'dark', 'allOn' or 'pattern' (the design, all spots at once).
            obj.DmdMode = mode;
            obj.Controls.DmdMode.Value = find(strcmp(obj.DMD_MODES, mode));
            obj.project();
        end

        function patternChanged(obj)
            % The design changed: reprojects it when the DMD shows it.
            if strcmp(obj.DmdMode, 'pattern'), obj.project(); end
        end

        function used = handleClick(obj, xDsp, yDsp)
            % A canvas click while placing the mark places it; true when used.
            used = obj.Picking;
            if ~used, return; end
            obj.Picking = false;
            obj.Controls.Place.Value = false;
            obj.MarkXY = lhf.cam.toCamera(obj.Registration, [xDsp yDsp] * obj.Canvas.scale);
            obj.refresh();
            obj.Hooks.redraw();
        end

        function setAnimal(obj, animal)
            obj.Controls.Animal.String = char(animal);
            obj.loadAnimal();
            obj.Hooks.redraw();
        end

        function saveFiducial(obj)
            % Captures an averaged frame and adds it, with the mark, to the
            % animal's fiducial file (the first ever saved is the reference).
            if isempty(obj.MarkXY)
                obj.showError('Place the mark first: Place mark, then click the canvas.');
                return
            end
            wasLive = obj.Controls.Live.Value;
            obj.setLive(false);
            if ~obj.ensureCamera() || ~obj.guard(@() obj.showFrame(obj.Camera.capture()))
                obj.setLive(wasLive);
                return
            end
            entry = struct('frame', obj.Frame, 'xy', obj.MarkXY, ...
                'exposureMs', obj.Camera.ExposureMs, 'roi', obj.Camera.Roi, ...
                'registrationFile', registrationFile(obj.Registration), 'stageUm', obj.stagePositions());
            file = obj.fiducialFile();
            if isempty(file), obj.setLive(wasLive); return; end
            if obj.guard(@() obj.storeFiducial(file, entry))
                obj.MarkXY = [];
            end
            obj.updateReadout();
            obj.refresh();
            obj.Hooks.redraw();
            obj.setLive(wasLive);
        end

        function alignToReference(obj)
            % Moves the stage until the camera matches the animal's reference;
            % while aligning, stops it instead.
            if obj.Aligning
                obj.StopRequested = true;
                return
            end
            if obj.Moving, return; end
            if ~obj.canAlign()
                obj.showError(obj.Controls.AlignInfo.String);
                return
            end
            obj.setLive(false);
            if ~obj.ensureCamera() || ~obj.ensureStages()
                return
            end
            options = obj.Options.alignment;
            options.crop = obj.dmdFieldBox();
            options.progress = @(info) obj.onAlignProgress(info);
            options.shouldStop = @() obj.StopRequested;
            options.confirm = @(info) obj.Options.confirm(info);
            obj.Aligning = true;
            obj.StopRequested = false;
            obj.Controls.Align.String = 'Stop';
            obj.Controls.Align.BackgroundColor = [0.55 0.2 0.2];
            reference = obj.Fiducial.reference.frame;
            result = [];
            try
                result = lhf.cam.align(@() obj.Camera.capture(), obj.Stages, reference, ...
                    obj.StageCalibration, options);
            catch err
                obj.showError(err.message);
            end
            obj.Aligning = false;
            obj.Controls.Align.String = 'Align to reference';
            obj.Controls.Align.BackgroundColor = [0.2 0.45 0.7];
            obj.updateReadout();
            if isempty(result), obj.refresh(); return; end
            obj.LastAlignment = result;
            obj.Controls.AlignInfo.String = result.message;
            if strcmp(result.status, 'aligned')
                entry = struct('frame', result.frame, 'xy', [], 'exposureMs', obj.Camera.ExposureMs, ...
                    'roi', obj.Camera.Roi, 'registrationFile', registrationFile(obj.Registration), ...
                    'stageUm', result.endUm, 'alignment', rmfield(result, 'frame'));
                file = obj.fiducialFile();
                if ~isempty(file)
                    obj.guard(@() obj.storeFiducial(file, entry));
                end
            end
            obj.refresh();
            obj.Controls.AlignInfo.String = result.message;  % after refresh, which writes the idle hint
            if result.rotationWarning || ~any(strcmp(result.status, {'aligned', 'cancelled'}))
                obj.showError(result.message);
            end
        end

        function readStage(obj)
            % Connects the stages if needed and shows where they are.
            if obj.ensureStages()
                obj.updateReadout();
            end
            obj.refresh();
        end

        function goToReference(obj)
            % Moves X and Y to the reference's saved position (Z stays, for
            % Align to reference); while moving, stops instead.
            if obj.Moving
                obj.StopRequested = true;
                return
            end
            [can, why] = obj.canGoToReference();
            if ~can
                obj.showError(why);
                return
            end
            [target, source] = obj.referenceXY();
            obj.setLive(false);
            if ~obj.ensureStages(), obj.refresh(); return; end
            obj.updateReadout();
            if isempty(obj.LastStageUm)
                obj.showError('Could not read the stage position.');
                return
            end
            info = struct('targetUm', target, 'moveUm', target - obj.LastStageUm(1:2), 'source', source);
            if ~obj.Options.confirmGoTo(info), return; end
            obj.Moving = true;
            obj.StopRequested = false;
            obj.Controls.GoRef.String = 'Stop';
            obj.Controls.GoRef.BackgroundColor = [0.55 0.2 0.2];
            obj.refresh();
            obj.guard(@() obj.moveXY(target));
            obj.Moving = false;
            obj.Controls.GoRef.String = 'Go to reference X/Y';
            obj.Controls.GoRef.BackgroundColor = obj.BUTTON;
            obj.updateReadout();
            obj.refresh();
        end

        function drawOverlay(obj, ax)
            % The reference mark (red crosshair) and this session's mark (yellow).
            if isempty(obj.Registration), return; end
            if obj.Controls.ShowRef.Value && ~isempty(obj.Fiducial)
                p = lhf.cam.toDmd(obj.Registration, obj.Fiducial.reference.xy) / obj.Canvas.scale;
                w = obj.Canvas.size(2);
                h = obj.Canvas.size(1);
                lines = [plot(ax, [0 w], [p(2) p(2)], '-', 'Color', [1 0.25 0.25], 'LineWidth', 1), ...
                         plot(ax, [p(1) p(1)], [0 h], '-', 'Color', [1 0.25 0.25], 'LineWidth', 1), ...
                         plot(ax, p(1), p(2), 'o', 'Color', [1 0.25 0.25], 'MarkerSize', 12, 'LineWidth', 1.5)];
                set(lines, 'HitTest', 'off', 'PickableParts', 'none');
            end
            if ~isempty(obj.MarkXY)
                p = lhf.cam.toDmd(obj.Registration, obj.MarkXY) / obj.Canvas.scale;
                h = plot(ax, p(1), p(2), '+', 'Color', [1 0.9 0.1], 'MarkerSize', 16, 'LineWidth', 2);
                set(h, 'HitTest', 'off', 'PickableParts', 'none');
            end
        end
    end

    methods (Access = private)
        function build(obj, origin)
            x = origin(1);
            y = origin(2);
            fig = obj.Figure;
            c = struct();

            obj.label('CAMERA', [x y+724 120 22], true);
            c.Live = uicontrol(fig, 'Style', 'togglebutton', 'String', 'Live', ...
                'Position', [x y+690 70 28], 'FontSize', 10, ...
                'BackgroundColor', [0.2 0.45 0.7], 'ForegroundColor', [1 1 1], ...
                'Callback', @(src, ~) obj.setLive(src.Value));
            c.Capture = obj.button('Capture', [x+76 y+690 70 28], @(~, ~) obj.capture());
            obj.label('Exp (ms)', [x+156 y+692 58 22]);
            c.Exposure = obj.edit(sprintf('%g', obj.Options.exposureMs), [x+216 y+692 50 24], ...
                @(src, ~) obj.onExposure(src));
            obj.label('Average', [x+276 y+692 55 22]);
            c.Average = obj.edit(sprintf('%d', obj.Options.averageFrames), [x+334 y+692 40 24], ...
                @(src, ~) obj.onAverage(src));

            c.DmdMode = uicontrol(fig, 'Style', 'popupmenu', ...
                'String', {'DMD: dark', 'DMD: all on', 'DMD: this pattern'}, ...
                'Position', [x y+656 180 26], 'FontSize', 10, ...
                'BackgroundColor', obj.EDIT, 'ForegroundColor', [1 1 1], ...
                'Callback', @(src, ~) obj.setDmdMode(obj.DMD_MODES{src.Value}));
            c.RefFrame = uicontrol(fig, 'Style', 'togglebutton', 'String', 'Show reference frame', ...
                'Position', [x+190 y+656 184 28], 'FontSize', 9, ...
                'BackgroundColor', obj.BUTTON, 'ForegroundColor', [1 1 1], ...
                'TooltipString', 'The canvas shows the animal''s reference frame instead of the camera', ...
                'Callback', @(~, ~) obj.render());

            c.Hist = axes('Parent', fig, 'Units', 'pixels', 'Position', [x+8 y+500 366 140], ...
                'Color', [0.16 0.16 0.18], 'XColor', [0.6 0.6 0.6], 'YColor', [0.6 0.6 0.6], ...
                'YScale', 'log', 'FontSize', 8, 'Box', 'on', 'NextPlot', 'add');
            c.HistLine = stairs(c.Hist, [0 1], [1 1], 'Color', [0.7 0.8 1], 'HitTest', 'off');
            c.LowLine = line(c.Hist, [0 0], [1 1], 'Color', [0.3 0.7 1], 'LineWidth', 3, ...
                'ButtonDownFcn', @(~, ~) obj.startDrag(1));
            c.HighLine = line(c.Hist, [1 1], [1 1], 'Color', [1 0.6 0.2], 'LineWidth', 3, ...
                'ButtonDownFcn', @(~, ~) obj.startDrag(2));
            c.Auto = uicontrol(fig, 'Style', 'checkbox', 'String', 'Auto', 'Value', true, ...
                'Position', [x y+464 60 22], 'FontSize', 10, ...
                'BackgroundColor', obj.BG, 'ForegroundColor', obj.LABEL, ...
                'Callback', @(src, ~) obj.onAuto(src.Value));
            obj.label('Low', [x+66 y+464 30 22]);
            c.Low = obj.edit('0', [x+98 y+464 70 24], @(~, ~) obj.onTypedLimits());
            obj.label('High', [x+178 y+464 34 22]);
            c.High = obj.edit('1', [x+214 y+464 70 24], @(~, ~) obj.onTypedLimits());
            c.Stats = obj.label('', [x y+436 384 22]);
            c.Stats.FontSize = 8;

            obj.label('FIDUCIAL', [x y+396 120 22], true);
            obj.label('Animal', [x y+366 50 22]);
            c.Animal = obj.edit(obj.Options.animal, [x+54 y+366 160 24], @(src, ~) obj.setAnimal(src.String));
            c.Animal.HorizontalAlignment = 'left';
            c.FiducialInfo = obj.label('', [x y+322 384 40]);
            c.FiducialInfo.FontSize = 9;
            c.Place = uicontrol(fig, 'Style', 'togglebutton', 'String', 'Place mark', ...
                'Position', [x y+284 110 28], 'FontSize', 10, ...
                'BackgroundColor', obj.BUTTON, 'ForegroundColor', [1 1 1], ...
                'Callback', @(src, ~) obj.onPlace(src.Value));
            c.SaveFiducial = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Save fiducial', ...
                'Position', [x+116 y+284 120 28], 'FontSize', 10, ...
                'BackgroundColor', [0.15 0.5 0.28], 'ForegroundColor', [1 1 1], ...
                'Callback', @(~, ~) obj.saveFiducial());
            c.ShowRef = uicontrol(fig, 'Style', 'checkbox', 'String', 'Show reference mark', 'Value', true, ...
                'Position', [x+244 y+286 150 22], 'FontSize', 9, ...
                'BackgroundColor', obj.BG, 'ForegroundColor', obj.LABEL, ...
                'Callback', @(~, ~) obj.Hooks.redraw());
            note = obj.label(['Place mark, click a landmark, Save fiducial: the first one saved is ' ...
                'the animal''s reference (red crosshair).'], [x y+250 384 30]);
            note.FontSize = 8;
            note.ForegroundColor = [0.5 0.5 0.5];
            c.Align = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Align to reference', ...
                'Position', [x y+212 150 30], 'FontSize', 10, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.2 0.45 0.7], 'ForegroundColor', [1 1 1], ...
                'TooltipString', 'Move the stage (X, Y, Z) until the camera matches the reference frame', ...
                'Callback', @(~, ~) obj.alignToReference());
            c.AlignInfo = obj.label('', [x+158 y+190 226 56]);
            c.AlignInfo.FontSize = 8;
            obj.label('STAGE', [x y+160 120 22], true);
            c.ReadStage = obj.button('Read', [x y+128 60 28], @(~, ~) obj.readStage());
            c.StageReadout = obj.label('Not connected: press Read', [x+66 y+128 318 24]);
            c.StageReadout.FontSize = 9;
            c.GoRef = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Go to reference X/Y', ...
                'Position', [x y+90 150 30], 'FontSize', 10, ...
                'BackgroundColor', obj.BUTTON, 'ForegroundColor', [1 1 1], ...
                'TooltipString', ['Move X and Y to where the reference was saved; Z stays ' ...
                '(Align to reference finds it)'], ...
                'Callback', @(~, ~) obj.goToReference());
            c.GoRefInfo = obj.label('', [x+158 y+76 226 44]);
            c.GoRefInfo.FontSize = 8;
            c.Calibration = obj.label('', [x y+10 384 60]);
            c.Calibration.FontSize = 8;
            obj.Controls = c;
        end

        function h = label(obj, text, position, isTitle)
            h = uicontrol(obj.Figure, 'Style', 'text', 'String', text, 'Position', position, ...
                'FontSize', 10, 'BackgroundColor', obj.BG, 'ForegroundColor', obj.LABEL, ...
                'HorizontalAlignment', 'left');
            if nargin > 3 && isTitle
                h.FontWeight = 'bold';
                h.ForegroundColor = obj.TITLE;
            end
        end

        function h = edit(obj, text, position, callback)
            h = uicontrol(obj.Figure, 'Style', 'edit', 'String', text, 'Position', position, ...
                'FontSize', 10, 'BackgroundColor', obj.EDIT, 'ForegroundColor', [1 1 1], ...
                'Callback', callback);
        end

        function h = button(obj, text, position, callback)
            h = uicontrol(obj.Figure, 'Style', 'pushbutton', 'String', text, 'Position', position, ...
                'FontSize', 10, 'BackgroundColor', obj.BUTTON, 'ForegroundColor', [1 1 1], ...
                'Callback', callback);
        end

        function refresh(obj)
            % Enables what can be used and writes the status lines.
            c = obj.Controls;
            calibrated = ~isempty(obj.Registration);
            set([c.Live, c.Capture, c.Place, c.SaveFiducial], 'Enable', onOff(calibrated));
            if calibrated
                cameraLine = sprintf('Camera-DMD calibration: %s (rms %.2f camera px).', ...
                    registrationName(obj.Registration), obj.Registration.rmsPx);
                c.Calibration.ForegroundColor = [0.55 0.75 0.95];
            else
                cameraLine = ['No camera-DMD calibration: run calibration/' ...
                    'calibrate_camera_dmd.m to see the camera on the canvas.'];
                c.Calibration.ForegroundColor = [1 0.6 0.2];
            end
            if isempty(obj.StageCalibration)
                stageLine = 'No stage-camera calibration (calibration/calibrate_stage_camera.m).';
            else
                stageLine = sprintf('Stage-camera calibration: %s (%.3f px/um).', ...
                    registrationName(obj.StageCalibration), obj.StageCalibration.pxPerUm);
            end
            c.Calibration.String = {cameraLine, stageLine};
            allowed = obj.Options.dmdAllowed();
            c.DmdMode.Enable = onOff(allowed);
            if allowed
                c.DmdMode.TooltipString = 'What the DMD projects while you look';
            else
                c.DmdMode.TooltipString = 'The running session owns the DMD';
            end
            fid = obj.Fiducial;
            if isempty(fid)
                c.FiducialInfo.String = 'No fiducial for this animal yet: the first one saved is its reference.';
            else
                c.FiducialInfo.String = sprintf('Reference %s; %d session(s) saved, last %s.', ...
                    fid.reference.time, numel(fid.sessions), fid.sessions(end).time);
            end
            if ~isempty(obj.MarkXY)
                c.FiducialInfo.String = [c.FiducialInfo.String sprintf(' Mark placed at (%.0f, %.0f) camera px.', ...
                    obj.MarkXY)];
            end
            c.RefFrame.Enable = onOff(calibrated && ~isempty(fid));
            if isempty(fid), c.RefFrame.Value = false; end
            [can, why] = obj.canAlign();
            c.Align.Enable = onOff((can && ~obj.Moving) || obj.Aligning);
            if ~obj.Aligning
                c.AlignInfo.String = why;
            end
            c.ReadStage.Enable = onOff(obj.Options.stagesConfigured && ~obj.Aligning && ~obj.Moving);
            [can, why] = obj.canGoToReference();
            c.GoRef.Enable = onOff(can || obj.Moving);
            c.GoRefInfo.String = why;
        end

        function [can, why] = canGoToReference(obj)
            % Whether Go to reference X/Y can run, and if not, why (if so, where to).
            can = false;
            target = obj.referenceXY();
            if ~obj.Options.stagesConfigured
                why = 'Needs zaber.axes (x, y, z, each with safe_um) in luminose_config.yaml.';
            elseif isempty(obj.Fiducial)
                why = 'Save this animal''s reference first.';
            elseif isempty(target)
                why = ['No stage position saved with this animal''s fiducials: press Read ' ...
                    'before Save fiducial.'];
            elseif ~obj.Options.dmdAllowed()
                why = 'Not while a session runs.';
            elseif obj.Aligning
                why = 'Aligning.';
            else
                can = true;
                why = sprintf('Reference X %.0f, Y %.0f um', target);
                if ~isempty(obj.LastStageUm)
                    why = sprintf('%s (dX %+.0f, dY %+.0f um)', why, target - obj.LastStageUm(1:2));
                end
            end
        end

        function [target, source] = referenceXY(obj)
            % The X/Y saved with the reference, else with the newest session that has one.
            target = [];
            source = '';
            fid = obj.Fiducial;
            if isempty(fid), return; end
            if isfield(fid.reference, 'stageUm') && numel(fid.reference.stageUm) >= 2
                target = fid.reference.stageUm(1:2);
                source = 'reference';
                return
            end
            for k = numel(fid.sessions):-1:1
                if isfield(fid.sessions(k), 'stageUm') && numel(fid.sessions(k).stageUm) >= 2
                    target = fid.sessions(k).stageUm(1:2);
                    source = sprintf('session of %s', fid.sessions(k).time);
                    return
                end
            end
        end

        function moveXY(obj, target)
            % Both targets checked before either axis moves, then both moved together.
            s = obj.Stages;
            xy = {s.x, s.y};
            for k = 1:2
                limits = xy{k}.LimitsUm;
                if target(k) < limits(1) || target(k) > limits(2)
                    error('DesignerCameraPanel:outsideLimits', ['%s %.0f um is outside its ' ...
                        'LimitsUm [%g %g] (its safe range): nothing moved.'], ...
                        char('X' + k - 1), target(k), limits(1), limits(2));
                end
            end
            s.x.moveAbsolute(target(1), 'Wait', false);
            s.y.moveAbsolute(target(2), 'Wait', false);
            while s.x.isMoving() || s.y.isMoving()
                if obj.StopRequested
                    s.x.stop();
                    s.y.stop();
                    break
                end
                pause(0.05);  % lets Stop through
            end
        end

        function updateReadout(obj)
            % Reads X/Y/Z when the stages are connected and shows them.
            um = obj.stagePositions();
            if isempty(um), return; end
            obj.LastStageUm = um;
            obj.Controls.StageReadout.String = sprintf('X %.1f   Y %.1f   Z %.1f um', um);
        end

        function [can, why] = canAlign(obj)
            % Whether Align to reference can run, and if not, why.
            can = false;
            if isempty(obj.Registration)
                why = 'Needs the camera-DMD calibration.';
            elseif isempty(obj.StageCalibration)
                why = 'Needs the stage-camera calibration: run calibration/calibrate_stage_camera.m.';
            elseif ~obj.Options.stagesConfigured
                why = 'Needs zaber.axes (x, y, z, each with safe_um) in luminose_config.yaml.';
            elseif isempty(obj.Fiducial)
                why = 'Save this animal''s reference first.';
            elseif ~obj.Options.dmdAllowed()
                why = 'Not while a session runs.';
            else
                can = true;
                why = 'Moves X/Y, finds Z, refines X/Y; asks before the first move.';
            end
        end

        function ok = ensureStages(obj)
            % Connects the X, Y and Z axes on first use.
            ok = ~isempty(obj.Stages) || obj.guard(@() obj.connectStages());
        end

        function connectStages(obj)
            obj.Stages = obj.Options.makeStages();
        end

        function um = stagePositions(obj)
            % [x y z] when the stages are connected, else []
            um = [];
            if isempty(obj.Stages), return; end
            try
                um = [obj.Stages.x.positionUm(), obj.Stages.y.positionUm(), obj.Stages.z.positionUm()];
            catch
            end
        end

        function box = dmdFieldBox(obj)
            % The DMD field's bounding box in camera px, [x y w h]: what alignment registers on
            h = obj.Canvas.dmdSize(1);
            w = obj.Canvas.dmdSize(2);
            corners = lhf.cam.toCamera(obj.Registration, [0 0; w 0; w h; 0 h]);
            lo = max(floor(min(corners)), 1);
            hi = ceil(max(corners));
            box = [lo, hi - lo];
        end

        function onAlignProgress(obj, info)
            % Each alignment frame on the canvas, and where it has got to.
            if isvalid(obj.Figure)
                obj.showFrame(info.frame);
                obj.Controls.AlignInfo.String = sprintf('%s %d: %.1f um off, rotation %.2f deg, peak %.2f', ...
                    info.step, info.iteration, info.residualUm, info.rotationDeg, info.peak);
                drawnow;  % shows it, and lets Stop through
            end
        end

        function render(obj)
            % Puts the frame (or the reference frame) on the canvas and the histogram.
            source = obj.Frame;
            if obj.Controls.RefFrame.Value && ~isempty(obj.Fiducial)
                source = obj.Fiducial.reference.frame;
            end
            if isempty(source), return; end
            if ~isequal(obj.MapSize, size(source))
                obj.Map = lhf.cam.canvasMap(obj.Registration, size(source), obj.Canvas.size, obj.Canvas.scale);
                obj.MapSize = size(source);
            end
            obj.CanvasImg = lhf.cam.toCanvas(source, obj.Map);
            v = obj.fieldPixels();
            if ~isempty(v)
                obj.Controls.Stats.String = sprintf('min %d   mean %.0f   max %d   saturated %.2f%%', ...
                    min(v), mean(v), max(v), 100 * mean(v >= 0.95 * 65535));
            end
            if obj.Controls.Auto.Value
                obj.autoLimits();
            else
                obj.applyLimits();
            end
        end

        function applyLimits(obj)
            % Shows the canvas image with CLim and redraws the histogram.
            c = obj.Controls;
            c.Low.String = sprintf('%.0f', obj.CLim(1));
            c.High.String = sprintf('%.0f', obj.CLim(2));
            v = obj.fieldPixels();
            if ~isempty(v)
                top = max(double(max(v)), obj.CLim(2)) * 1.05 + 1;
                edges = linspace(0, top, 129);
                counts = histcounts(double(v), edges);
                set(c.HistLine, 'XData', edges(1:end-1), 'YData', max(counts, 0.5));
                c.Hist.XLim = [0 top];
                c.Hist.YLim = [0.5 max(counts) * 2 + 1];
            end
            yl = c.Hist.YLim;
            set(c.LowLine, 'XData', obj.CLim([1 1]), 'YData', yl);
            set(c.HighLine, 'XData', obj.CLim([2 2]), 'YData', yl);
            if ~isempty(obj.CanvasImg)
                obj.Hooks.setBackground(obj.CanvasImg, obj.CLim);
            end
        end

        function v = fieldPixels(obj)
            % The canvas pixels the camera sees.
            v = [];
            if isempty(obj.CanvasImg) || isempty(obj.Map), return; end
            v = obj.CanvasImg(obj.Map > 0);
        end

        function startDrag(obj, which)
            obj.Dragging = which;
            obj.Figure.WindowButtonMotionFcn = @(~, ~) obj.drag();
            obj.Figure.WindowButtonUpFcn = @(~, ~) obj.stopDrag();
        end

        function drag(obj)
            if obj.Dragging == 0, return; end
            x = obj.Controls.Hist.CurrentPoint(1, 1);
            x = min(max(x, 0), obj.Controls.Hist.XLim(2));
            limits = obj.CLim;
            if obj.Dragging == 1
                limits(1) = min(x, limits(2) - 1);
            else
                limits(2) = max(x, limits(1) + 1);
            end
            obj.setLimits(limits);
        end

        function stopDrag(obj)
            obj.Dragging = 0;
            obj.Figure.WindowButtonMotionFcn = '';
            obj.Figure.WindowButtonUpFcn = '';
        end

        function onAuto(obj, on)
            if on, obj.autoLimits(); end
        end

        function onTypedLimits(obj)
            limits = [str2double(obj.Controls.Low.String), str2double(obj.Controls.High.String)];
            if any(isnan(limits))
                obj.applyLimits();  % puts the numbers back
            else
                obj.setLimits(limits);
            end
        end

        function onExposure(obj, src)
            value = str2double(src.String);
            if isnan(value) || value <= 0
                src.String = sprintf('%g', obj.Options.exposureMs);
                return
            end
            obj.Options.exposureMs = value;
            if ~isempty(obj.Camera)
                obj.guard(@() setProperty(obj.Camera, 'ExposureMs', value));
            end
        end

        function onAverage(obj, src)
            value = round(str2double(src.String));
            if isnan(value) || value < 1
                src.String = sprintf('%d', obj.Options.averageFrames);
                return
            end
            src.String = sprintf('%d', value);
            obj.Options.averageFrames = value;
            if ~isempty(obj.Camera)
                obj.guard(@() setProperty(obj.Camera, 'AverageFrames', value));
            end
        end

        function onPlace(obj, on)
            obj.Picking = logical(on);
        end

        function ok = ensureCamera(obj)
            % Connects the camera on first use, with the panel's exposure and averaging.
            ok = ~isempty(obj.Camera);
            if ok || isempty(obj.Registration), return; end
            ok = obj.guard(@() obj.connectCamera());
        end

        function connectCamera(obj)
            camera = obj.Options.makeCamera();
            camera.ExposureMs = obj.Options.exposureMs;
            camera.AverageFrames = obj.Options.averageFrames;
            obj.Camera = camera;
        end

        function project(obj)
            % Shows the DMD mode; connects the DMD on first use.
            if ~obj.Options.dmdAllowed()
                return
            end
            if strcmp(obj.DmdMode, 'dark') && isempty(obj.Dmd)
                return
            end
            obj.guard(@() obj.projectNow());
        end

        function projectNow(obj)
            if isempty(obj.Dmd)
                obj.Dmd = obj.Options.makeDmd();
            end
            switch obj.DmdMode
                case 'dark'
                    obj.Dmd.halt();
                case 'allOn'
                    obj.Dmd.displayFrame(true(obj.Canvas.dmdSize));
                case 'pattern'
                    obj.Dmd.displayFrame(obj.Hooks.patternImage());
            end
        end

        function liveTick(obj)
            % One live frame; a failed frame is dropped.
            try
                if ~isempty(obj.Camera) && isvalid(obj.Figure)
                    obj.showFrame(obj.Camera.snapshot());
                end
            catch
            end
        end

        function file = fiducialFile(obj)
            % The animal's file, or '' (shown as an error) when no animal is named.
            file = '';
            try
                file = lhf.cam.fiducialFile(obj.Options.calibrationFolder, obj.Controls.Animal.String);
            catch err
                obj.showError(err.message);
            end
        end

        function loadAnimal(obj)
            obj.Fiducial = [];
            obj.MarkXY = [];
            if isempty(strtrim(obj.Controls.Animal.String)), obj.refresh(); return; end
            file = obj.fiducialFile();
            if ~isempty(file)
                obj.guard(@() obj.readFiducial(file));
            end
            obj.refresh();
        end

        function readFiducial(obj, file)
            obj.Fiducial = lhf.cam.loadFiducial(file);
        end

        function storeFiducial(obj, file, entry)
            obj.Fiducial = lhf.cam.saveFiducial(file, entry);
        end

        function ok = guard(obj, action)
            % Runs an action; an error is shown, not thrown.
            ok = false;
            try
                action();
                ok = true;
            catch err
                obj.showError(err.message);
            end
        end

        function showError(obj, message)
            obj.LastError = message;
            if isvalid(obj.Figure) && strcmp(obj.Figure.Visible, 'on')
                warndlg(message, 'Camera');
            end
        end
    end
end


function options = withDefaults(options)
% The options not given, from the rig's config.
    global luminose
    if ~isfield(options, 'calibrationFolder')
        options.calibrationFolder = fullfile(char(luminose.f.luminoseData), 'calibration');
    end
    if ~isfield(options, 'registration'), options.registration = []; end
    if ~isfield(options, 'makeCamera'), options.makeCamera = @() rigCamera(luminose); end
    if ~isfield(options, 'makeDmd'), options.makeDmd = @connectedDmd; end
    if ~isfield(options, 'dmdAllowed'), options.dmdAllowed = @() ~sessionRunning(); end
    if ~isfield(options, 'exposureMs'), options.exposureMs = luminose.camera.exposureTime_ms; end
    if ~isfield(options, 'averageFrames'), options.averageFrames = luminose.camera.nAverageFrames; end
    if ~isfield(options, 'animal'), options.animal = lhf.subjectName(); end
    if ~isfield(options, 'stageCalibration'), options.stageCalibration = []; end
    if ~isfield(options, 'makeStages'), options.makeStages = @() rigStages(luminose); end
    if ~isfield(options, 'stagesConfigured')
        axes = luminose.zaber.axes;
        options.stagesConfigured = all(isfield(axes, {'x', 'y', 'z'})) ...
            && all(cellfun(@(n) isfield(axes.(n), 'safe_um'), {'x', 'y', 'z'}));
    end
    if ~isfield(options, 'alignment'), options.alignment = luminose.zaber.alignment; end
    if ~isfield(options, 'confirm'), options.confirm = @confirmFirstMove; end
    if ~isfield(options, 'confirmGoTo'), options.confirmGoTo = @confirmGoTo; end
end

function go = confirmFirstMove(info)
% Asks before the stage first moves.
    answer = questdlg(sprintf(['Align to the reference: move the stage X %+.0f um, Y %+.0f um, ' ...
        'then search Z +/- %g um and refine X/Y?'], info.moveUm, info.zSearchUm), ...
        'Align to reference', 'Move', 'Cancel', 'Cancel');
    go = strcmp(answer, 'Move');
end

function go = confirmGoTo(info)
% Asks before Go to reference X/Y moves the stage.
    answer = questdlg(sprintf(['Move the stage to the %s''s X/Y: X %+.0f um, Y %+.0f um? ' ...
        'Z stays where it is.'], info.source, info.moveUm), 'Go to reference X/Y', ...
        'Move', 'Cancel', 'Cancel');
    go = strcmp(answer, 'Move');
end

function dmd = connectedDmd()
    dmd = DMDController.DMD();
    dmd.connect(0);
end

function running = sessionRunning()
% After START the protocol's DMDPatternPlayer owns the DMD.
    global BpodSystem
    running = false;
    try
        running = logical(getappdata(BpodSystem.ProtocolFigures.ParameterGUI, 'StartPressed'));
    catch
    end
end

function name = registrationName(reg)
    name = registrationFile(reg);
    if isempty(name), name = 'given'; else, [~, name] = fileparts(name); end
end

function file = registrationFile(reg)
    file = '';
    if isfield(reg, 'file'), file = reg.file; end
end

function setProperty(object, name, value)
    object.(name) = value;
end

function s = onOff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end

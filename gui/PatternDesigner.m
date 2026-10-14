classdef PatternDesigner < handle
% PatternDesigner  The DMD spot designer: spots placed on the camera image,
%   where the DMD will light the tissue.
%
%   d = PatternDesigner(patternType, rowIdx, preloadFromType, options)
%
%   PatternDesignerGUI opens it (the parameter GUIs' pattern tables), with the
%   Laser and Stage panels (light to image the tissue by, and focus; Device panels
%   brings all three back). The canvas is the Hamamatsu camera's own panel (lhf.devicePanel('camera'),
%   live or a capture): the designer draws the DMD field, the spots and the
%   fiducial marks on its image (CameraApp.setOverlay) and takes the clicks on
%   it (setImageClickFcn). A camera pixel becomes a DMD pixel through the
%   camera-DMD calibration (Calibrate: Camera - DMD, lhf.cal.cameraDmd; in full-sensor
%   pixels: hamacam.Camera.frameToSensor/sensorToFrame keep it right at any
%   subarray or binning), so a spot drawn on the tissue is projected on that
%   tissue. Without a calibration spots cannot be placed: the window says so, the
%   camera panel opens only to look and focus, and a saved design can still be
%   retimed and saved.
%
%   On the camera image (while Draw and Measure are off on the camera panel):
%     Free mode   left click adds a spot (up to nSpots, none overlapping),
%                 right click removes the nearest
%     Grid mode   a click toggles the grid cell under it
%   Clicks outside the DMD field are ignored, with a note.
%
%   The window keeps the spot controls: Mode (Free / Grid), nSpots, Randomize, Clear all, an Overlay
%   layer (another type's design, amber), the spots table (DMD px, timing,
%   Fixed/Random), Delete spot #, Tick (ms), Spot side (mm), the timeline, the
%   laser power per pattern (when the protocol declares LaserOptions), Save
%   and Cancel. Saved designs are as before: DMD px in
%   BpodSystem.PluginObjects.PatternDesigns and designed_<type>_r<row>_*_meta.mat.
%
%   Show on DMD projects the design (lhf.spotImage, every spot at once) on the
%   rig's DMD (lhf.device) and again at every change, so the light can be seen
%   landing on the drawn spots; unticked or closed, the DMD halts. After START
%   the session's DMDPatternPlayer owns the DMD and it is refused.
%
%   Fiducial & alignment (unfolds to the right): the animal's fiducial (Place
%   mark, a click on the image, Save fiducial: the first one saved is the
%   reference, a red crosshair), Align to reference (lhf.cam.align: needs the
%   stage-camera calibration and the reference's subarray and binning), and
%   the stage readout with Go to reference X/Y.
%
%   Targets (glomeruli, say), in the same column: Mark targets, then a click on the
%   image adds one (G1, G2, ...; right click removes the nearest), named and ticked in
%   the table, and Save targets keeps them for the animal (lhf.cam.saveTargets). They
%   are stored in the animal's reference fiducial frame, so they come back in any
%   session: Locate registers the camera image on the reference (lhf.cam.register, no
%   stage move; Align to reference runs it too) and draws them where they are now
%   (cyan circles; dashed until located). A click near a located target puts the spot
%   on its centre, and Spots on targets puts one spot on each ticked target. The saved
%   design's meta file names the target each spot is on (spotTargets).
%   From code: setMarkTargets(tf), locateTargets(), spotsOnTargets(), saveTargets(),
%   deleteTargets(rows), setTargetUse(k, tf), renameTarget(k, name), targetsOnDmd().
%
%   options (tests and scripts), any of
%       luminose           the rig config (default: the global)
%       calibrationFolder  where camera_dmd_*.mat and fiducials/ live
%       registration       an lhf.cam.fitRegistration, instead of loading one
%       openCamera         () -> the camera's panel (hamacam.gui.CameraApp)
%       openPanel          (name) -> the 'stage' or 'laser' panel (lhf.devicePanel)
%       makeDmd            () -> a connected DMDController.DMD
%       dmdAllowed         () -> false while a session runs
%       stageCalibration   an lhf.cam.fitStageCamera, instead of loading one
%       makeStages         () -> struct x, y, z, close (rigStages)
%       stagesConfigured   whether zaber.axes names x, y and z, each with safe_um
%       alignment          lhf.cam.align's settings
%       confirm, confirmGoTo   (info) -> true to move (default: dialogs)
%       confirmBlank       (tickMs) -> true to save a design with no spots
%       confirmTargets     (question) -> true to go on (saving targets over another
%                          reference's, closing with unsaved targets: save them)
%       animal             the animal (default lhf.subjectName)
%       visible            false: an invisible window and no dialogs (tests)

    properties (SetAccess = private)
        PatternType
        RowIdx
        Spots                 % struct x, y (DMD px), onset_ms, dur_ms, isFixed
        OverlaySpots          % the Overlay layer's spots
        Mode = 'free'         % 'free' | 'grid'
        GridSelected = false(0, 0)
        RPx = 1               % spot half-width, DMD px
        SpotSide = 0          % spot side, mm
        Registration = []     % camera-DMD calibration (sensor px), or []
        CameraPanel = []      % hamacam.gui.CameraApp drawing the design
        StagePanel = []       % the stage's panel, opened with the designer (focus)
        LaserPanel = []       % the laser's panel, opened with the designer (light to image by)
        Dmd = []              % the DMD, once Show on DMD used it
        ShowOnDmd = false
        DmdAllOn = false      % every mirror on (DMD all on, for the fiducial)
        Fiducial = []         % the animal's fiducial, or []
        MarkXY = []           % the mark placed this session, sensor px
        Stages = []
        StageCalibration = []
        LastAlignment = []
        LastStageUm = []
        Targets = []          % struct name, xy (sensor px in the reference frame), created, use
        TargetTransform = []  % reference frame -> current frame (lhf.cam.mapPoints), or [] until located
        TargetsFile = []      % the targets file as loaded or saved (referenceTime, saves), or []
        TargetsDirty = false  % edits not saved yet
        MarkingTargets = false
        LastLocatePeak = []
        Saved = []            % the design Save wrote last
        Figure
        Controls = struct()
        LastError = ''
        LastMessage = ''
    end

    properties (Constant)
        DMD_W = 1024
        DMD_H = 768
        WIDTH = 480           % the spot column
        FIDUCIAL_WIDTH = 410  % the fiducial column, unfolded
    end

    properties (Constant, Access = private)
        BG = [0.13 0.13 0.15]
        LABEL = [0.75 0.75 0.75]
        TITLE = [0.8 0.8 0.8]
        EDIT = [0.22 0.22 0.25]
        BUTTON = [0.25 0.25 0.3]
        FIELD = [0.3 0.85 1]
        OVERLAY = [0.9 0.65 0.1]
        TARGET = [0.2 1 0.85]
        SPOT_COLORS = [0.2 0.6 1.0; 1.0 0.4 0.2; 0.3 0.85 0.3; 1.0 0.9 0.1; ...
            0.8 0.2 0.8; 0.1 0.9 0.9; 1.0 0.5 0.7; 0.6 0.4 1.0]
    end

    properties (Access = private)
        Options
        Luminose
        Height
        LaserOn = false
        LaserSelRow = []
        GridCellSize = 4
        GridCols = 1
        GridRows = 1
        GridOffX = 0
        GridOffY = 0
        Picking = false
        TargetSel = []        % table rows selected
        Aligning = false
        Moving = false
        StopRequested = false
        Closing = false
    end

    methods
        function obj = PatternDesigner(patternType, rowIdx, preloadFromType, options)
            if nargin < 2 || isempty(rowIdx), rowIdx = 1; end
            if nargin < 3, preloadFromType = ''; end
            if nargin < 4, options = struct(); end
            obj.PatternType = patternType;
            obj.RowIdx = rowIdx;
            obj.Options = withDefaults(options);
            obj.Luminose = obj.Options.luminose;
            obj.Spots = emptySpots();
            obj.OverlaySpots = emptySpots();
            obj.applySpotSide(obj.Luminose.dmd.spotSide);

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

            [laser, loadedTickMs] = obj.loadDesign(preloadFromType);
            obj.build(laser);
            if ~isempty(loadedTickMs)
                obj.Controls.TickMs.String = num2str(loadedTickMs);
            else
                obj.updateDefaultTick();
            end
            obj.updateModeButtons();
            obj.loadAnimal();
            obj.openPanels();
            obj.changed(false);
        end

        function delete(obj)
            obj.close();
        end

        function close(obj)
            % Takes the design off the camera panel and halts the DMD if it showed
            % it; the camera, DMD and stages stay connected (lhf.device).
            if obj.Closing, return; end
            if obj.TargetsDirty && obj.Options.visible && ~isempty(obj.Figure) ...
                    && isvalid(obj.Figure) && obj.Options.confirmTargets('Save the targets marked before closing?')
                obj.saveTargets();
            end
            obj.Closing = true;
            obj.StopRequested = true;
            obj.detachCamera();
            if (obj.ShowOnDmd || obj.DmdAllOn) && ~isempty(obj.Dmd)
                try obj.Dmd.halt(); catch, end
            end
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure);
            end
        end

        % ------------------------------------------------------------ the camera
        function openPanels(obj)
            % Opens (or brings forward) what designing needs: the laser's panel (light to
            % image the tissue by), the stage's (to focus) and the camera's, which the
            % design is drawn on. Opening a panel connects nothing.
            names = {'laser', 'stage'};
            props = {'LaserPanel', 'StagePanel'};
            for k = 1:2
                try
                    obj.(props{k}) = obj.Options.openPanel(names{k});
                catch err
                    obj.LastError = sprintf('The %s panel did not open: %s', names{k}, err.message);
                end
            end
            obj.attachCamera();
        end

        function attachCamera(obj)
            % Opens the camera's panel (or brings it forward) and, with a calibration,
            % draws the design on it.
            if ~obj.cameraAttached()
                if ~obj.guard(@() obj.openCameraPanel()), obj.refresh(); return; end
                obj.useAnimalFolder();
                if isempty(obj.Registration), obj.refresh(); return; end  % to look and focus only
                obj.CameraPanel.setOverlay(@(ax) obj.drawOnCamera(ax));
                obj.CameraPanel.setImageClickFcn(@(xy, kind) obj.onCameraClick(xy, kind));
            elseif ~isempty(obj.CameraPanel.Figure) && isvalid(obj.CameraPanel.Figure) ...
                    && obj.Options.visible
                figure(obj.CameraPanel.Figure);
            end
            obj.refresh();
        end

        function handles = drawOnCamera(obj, ax)
            % The DMD field, the spots and the fiducial marks on the camera image.
            handles = gobjects(0);
            if isempty(obj.Registration) || ~obj.cameraAttached(), return; end
            corners = [0.5 0.5; obj.DMD_W + 0.5 0.5; obj.DMD_W + 0.5 obj.DMD_H + 0.5; ...
                0.5 obj.DMD_H + 0.5; 0.5 0.5];
            field = obj.dmdToFrame(corners);
            handles(end + 1) = line(ax, field(:, 1), field(:, 2), 'LineStyle', '--', ...
                'Color', obj.FIELD, 'LineWidth', 1);
            if strcmp(obj.Mode, 'grid')
                handles = [handles, obj.drawGrid(ax)];
            else
                handles = [handles, obj.drawFreeSpots(ax)];
            end
            handles = [handles, obj.drawMarks(ax), obj.drawTargets(ax)];
        end

        function onCameraClick(obj, xyFrame, kind)
            % A press on the camera image: a mark while placing one, else a spot.
            if nargin < 3, kind = 'normal'; end
            if isempty(obj.Registration)
                obj.note('No camera-DMD calibration: spots cannot be placed on the camera.');
                return
            end
            camera = obj.CameraPanel.Camera;
            if obj.MarkingTargets
                obj.markTargetAt(xyFrame, kind);
                return
            end
            if ~obj.Picking
                xyFrame = obj.snapToTarget(xyFrame);  % a click near a target: its centre
            end
            sensor = camera.frameToSensor(xyFrame);
            if obj.Picking
                obj.Picking = false;
                obj.Controls.Place.Value = false;
                obj.MarkXY = sensor;
                obj.refresh();
                obj.redraw();
                return
            end
            dmd = lhf.cam.toDmd(obj.Registration, sensor);
            if any(dmd < 0.5) || dmd(1) > obj.DMD_W + 0.5 || dmd(2) > obj.DMD_H + 0.5
                obj.note('Outside the DMD field (dashed outline): the DMD cannot light it.');
                return
            end
            obj.clickDmd(round(dmd), kind);
        end

        function clickDmd(obj, dmd, kind)
            % A click at DMD pixel dmd ([x y]): add, remove or toggle as the mode says.
            x = min(max(dmd(1), 1), obj.DMD_W);
            y = min(max(dmd(2), 1), obj.DMD_H);
            if strcmp(obj.Mode, 'grid')
                col = floor((x - obj.GridOffX) / obj.GridCellSize) + 1;
                row = floor((y - obj.GridOffY) / obj.GridCellSize) + 1;
                if col < 1 || col > obj.GridCols || row < 1 || row > obj.GridRows
                    obj.note('Outside the grid.');
                    return
                end
                obj.GridSelected(row, col) = ~obj.GridSelected(row, col);
                obj.syncSpotsFromGrid();
            elseif strcmp(kind, 'normal')
                nMax = obj.nSpots();
                if numel(obj.Spots) >= nMax
                    obj.note(sprintf('%d spots already: raise nSpots to add more.', nMax));
                    return
                end
                if obj.anyOverlapWith(x, y, obj.Spots, 0)
                    obj.note('Too close to another spot: spots may not overlap.');
                    return
                end
                spot = struct('x', x, 'y', y, 'onset_ms', 0, 'dur_ms', 200, 'isFixed', true);
                obj.Spots(end + 1) = spot;
            else
                if isempty(obj.Spots), return; end
                d = hypot([obj.Spots.x] - x, [obj.Spots.y] - y);
                [nearest, k] = min(d);
                if nearest > max(1.5 * obj.RPx, 4)
                    obj.note('No spot there to remove.');
                    return
                end
                obj.Spots(k) = [];
            end
            obj.note('');
            obj.changed(true);
        end

        function xy = dmdToFrame(obj, dmdXY)
            % DMD px to the camera panel's frame px (its subarray and binning).
            xy = obj.CameraPanel.Camera.sensorToFrame(lhf.cam.toCamera(obj.Registration, dmdXY));
        end

        function corners = square(obj, x, y)
            % A spot's lit square in continuous DMD px (pixel k spans k +/- 0.5), closed.
            r = obj.RPx + 0.5;
            corners = [x - r, y - r; x + r, y - r; x + r, y + r; x - r, y + r; x - r, y - r];
        end

        function dmdXY = frameToDmd(obj, xyFrame)
            % The camera panel's frame px to DMD px.
            dmdXY = lhf.cam.toDmd(obj.Registration, obj.CameraPanel.Camera.frameToSensor(xyFrame));
        end

        % ------------------------------------------------------------ spot edits
        function setMode(obj, newMode)
            newMode = validatestring(newMode, {'free', 'grid'});
            if strcmp(newMode, obj.Mode), return; end
            if strcmp(newMode, 'grid')
                obj.GridSelected = obj.spotsToGrid(obj.Spots);
                obj.syncSpotsFromGrid();  % snap the spots to the cell centres
                obj.Controls.Table.ColumnEditable = [false false false true true true];
            else
                obj.Controls.Table.ColumnEditable = [false true true true true true];
            end
            obj.Mode = newMode;
            obj.updateModeButtons();
            obj.changed(true);
        end

        function randomize(obj)
            % nSpots at random: grid cells in Grid mode, else anywhere, none overlapping.
            n = obj.nSpots();
            if strcmp(obj.Mode, 'grid')
                nAll = obj.GridRows * obj.GridCols;
                n = min(n, nAll);
                obj.GridSelected = false(obj.GridRows, obj.GridCols);
                obj.GridSelected(randperm(nAll, n)) = true;
                obj.syncSpotsFromGrid();
            else
                margin = obj.RPx + 1;
                placed = emptySpots();
                for i = 1:n
                    for attempt = 1:1000
                        xt = randi([margin, obj.DMD_W - margin]);
                        yt = randi([margin, obj.DMD_H - margin]);
                        if ~obj.anyOverlapWith(xt, yt, placed, 0)
                            placed(end + 1) = struct('x', xt, 'y', yt, 'onset_ms', 0, ...
                                'dur_ms', 200, 'isFixed', true); %#ok<AGROW>
                            break
                        end
                    end
                end
                obj.Spots = placed;
            end
            obj.changed(true);
        end

        function clearAll(obj)
            obj.Spots = emptySpots();
            obj.GridSelected = false(obj.GridRows, obj.GridCols);
            obj.changed(false);
        end

        function deleteSpot(obj, idx)
            if isnan(idx) || idx < 1 || idx > numel(obj.Spots)
                obj.showError(sprintf('Enter a spot number between 1 and %d.', max(1, numel(obj.Spots))));
                return
            end
            obj.Spots(idx) = [];
            if strcmp(obj.Mode, 'grid')
                obj.GridSelected = obj.spotsToGrid(obj.Spots);
            end
            obj.changed(true);
        end

        function setSpotSide(obj, mm)
            % Spot side in mm at the sample; sets r_px and the grid.
            if isnan(mm) || mm <= 0
                obj.Controls.SpotSide.String = sprintf('%.3g', obj.SpotSide);
                return
            end
            obj.applySpotSide(mm);
            obj.Controls.SpotSide.String = sprintf('%.3g', mm);
            if strcmp(obj.Mode, 'grid')
                obj.GridSelected = obj.spotsToGrid(obj.Spots);  % onto the new grid's cells
                obj.syncSpotsFromGrid();
            end
            obj.changed(false);
        end

        function setOverlayType(obj, type)
            % Another type's design as a reference layer ('(none)' for none).
            k = find(strcmp(obj.Controls.Overlay.String, type), 1);
            if isempty(k), k = 1; end
            obj.Controls.Overlay.Value = k;
            obj.OverlaySpots = obj.loadOverlay();
            obj.redraw();
        end

        function setShowOnDmd(obj, on)
            % Projects the design on the DMD and at every change; off halts it.
            on = logical(on);
            if on && ~obj.Options.dmdAllowed()
                obj.Controls.ShowDmd.Value = false;
                obj.showError('The running session owns the DMD: Show on DMD waits until it ends.');
                return
            end
            obj.ShowOnDmd = on;
            obj.Controls.ShowDmd.Value = on;
            if on
                obj.DmdAllOn = false;  % one or the other
                obj.Controls.AllOn.Value = false;
                obj.project();
            elseif ~isempty(obj.Dmd)
                obj.guard(@() obj.Dmd.halt());
            end
        end

        function setDmdAllOn(obj, on)
            % Every DMD mirror on, to light the whole field (finding and marking the
            % fiducial); off halts the DMD. Show on DMD turns it off.
            on = logical(on);
            if on && ~obj.Options.dmdAllowed()
                obj.Controls.AllOn.Value = false;
                obj.showError('The running session owns the DMD: DMD all on waits until it ends.');
                return
            end
            obj.DmdAllOn = on;
            obj.Controls.AllOn.Value = on;
            if on
                obj.ShowOnDmd = false;
                obj.Controls.ShowDmd.Value = false;
                if obj.guard(@() obj.connectDmd())
                    obj.guard(@() obj.Dmd.displayFrame(true(obj.DMD_H, obj.DMD_W)));
                end
            elseif ~isempty(obj.Dmd)
                obj.guard(@() obj.Dmd.halt());
            end
        end

        function img = patternImage(obj)
            % The design as one DMD frame, every spot lit.
            img = lhf.spotImage(obj.Spots, obj.RPx, [obj.DMD_H obj.DMD_W]);
        end

        function design = savePattern(obj)
            % Saves the design (BpodSystem, the meta file, the pattern table, S.GUI)
            % and closes the window; [] when refused.
            global S BpodSystem %#ok<GVMIS> the protocol's (CLAUDE.md, Global variables)
            design = [];
            luminose = obj.Luminose;
            spots = obj.Spots;
            patternType = obj.PatternType;
            rowIdx = obj.RowIdx;
            tickMs = str2double(obj.Controls.TickMs.String);
            if isnan(tickMs) || tickMs <= 0
                obj.showError('Tick (ms) must be a positive number.');
                return
            end
            % No spots: a blank, which projects nothing (no DMD sequence, no laser)
            % while the stimulus lasts the tick (blankMs)
            isBlank = isempty(spots);
            if isBlank
                if ~obj.Options.confirmBlank(tickMs), return; end
                nF = 1;
                blankMs = tickMs;
            else
                if any([spots.dur_ms] <= 0)
                    obj.showError('All spots must have Duration > 0.');
                    return
                end
                nF = ceil(max([spots.onset_ms] + [spots.dur_ms]) / tickMs);
            end
            withLaser = obj.LaserOn && ~isBlank;  % a blank sets no laser power
            laserIrradiances_mWmm2 = [];
            laserWeights = [];
            if withLaser
                % Rows with no irradiance are ignored; the probabilities are saved as
                % the draw weights (lhf.laser.draw rescales them)
                rows = obj.Controls.LaserTable.Data;
                laserIrradiances_mWmm2 = cellfun(@cellNumber, rows(:, 1))';
                laserWeights = cellfun(@cellNumber, rows(:, 2))';
                keep = ~isnan(laserIrradiances_mWmm2);
                laserIrradiances_mWmm2 = laserIrradiances_mWmm2(keep);
                laserWeights = laserWeights(keep);
                laserWeights(isnan(laserWeights) | laserWeights < 0) = 0;
                if isempty(laserIrradiances_mWmm2) || any(laserIrradiances_mWmm2 <= 0)
                    obj.showError('Add at least one irradiance, every one above 0 mW/mm2.');
                    return
                end
                if sum(laserWeights) == 0
                    obj.showError('Give at least one irradiance a Prob above 0.');
                    return
                end
                laserWeights = round(laserWeights / sum(laserWeights), 4);
                try
                    irradianceToSetpoint_mW(laserIrradiances_mWmm2, luminose);  % within the calibration
                catch err
                    obj.showError(err.message);
                    return
                end
            end

            if ~isfield(BpodSystem, 'PluginObjects') || ~isstruct(BpodSystem.PluginObjects)
                BpodSystem.PluginObjects = struct();
            end
            if ~isfield(BpodSystem.PluginObjects, 'PatternDesigns')
                BpodSystem.PluginObjects.PatternDesigns = struct();
            end
            if ~isfield(BpodSystem.PluginObjects.PatternDesigns, patternType)
                BpodSystem.PluginObjects.PatternDesigns.(patternType) = {};
            end
            r_px = obj.RPx;
            design = struct('spots', spots, 'tickMs', tickMs, 'r_px', r_px, 'nF', nF);
            if withLaser
                design.laserIrradiances_mWmm2 = laserIrradiances_mWmm2;
                design.laserWeights = laserWeights;
            end
            if isBlank, design.blankMs = blankMs; end
            BpodSystem.PluginObjects.PatternDesigns.(patternType){rowIdx} = design;

            patternsFolder = lhf.patternFolder(luminose.dmd, patternType);
            if ~exist(patternsFolder, 'dir'), mkdir(patternsFolder); end
            timestamp = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<TNOW1,DATST>
            fileType = lhf.patternFileType(luminose.dmd, patternType);  % a protocol may rename the type
            prefix = sprintf('designed_%s_r%d_%s', fileType, rowIdx, timestamp);
            metaFile = fullfile(patternsFolder, sprintf('%s_meta.mat', prefix));
            spotTargets = obj.targetOfEachSpot(); %#ok<NASGU> saved below
            saved = {'spots', 'tickMs', 'r_px', 'nF', 'timestamp', 'prefix', 'spotTargets'};
            if withLaser, saved = [saved, {'laserIrradiances_mWmm2', 'laserWeights'}]; end
            if isBlank, saved{end + 1} = 'blankMs'; end
            save(metaFile, saved{:});

            try
                ptable = BpodSystem.GUIHandles.ParameterGUI.PatternSelectorTables.(patternType);
            catch
                ptable = [];
            end
            if ~isempty(ptable) && ishandle(ptable)
                tdata = get(ptable, 'Data');
                padRow = {0, 0, 1000, 'none'};
                while size(tdata, 1) < rowIdx, tdata(end + 1, :) = padRow(1:size(tdata, 2)); end %#ok<AGROW>
                tdata{rowIdx, 2} = numel(spots);
                tdata{rowIdx, 3} = tickMs;  % the table shows ms
                if size(tdata, 2) >= 4  % the laser column (none for a blank)
                    shown = design;
                    if isBlank, shown = []; end
                    tdata{rowIdx, 4} = lhf.laser.describe(shown, patternType, S);
                end
                set(ptable, 'Data', tdata);
            end

            if isstruct(S) && isfield(S, 'GUI')
                nFName = sprintf('patternNFrames_%s', patternType);
                expName = sprintf('patternExposure_%s', patternType);
                nFVec = [];
                expVec = [];
                if isfield(S.GUI, nFName), nFVec = S.GUI.(nFName); end
                if isfield(S.GUI, expName), expVec = S.GUI.(expName); end
                if numel(nFVec) < rowIdx, nFVec(rowIdx) = 0; end
                if numel(expVec) < rowIdx, expVec(rowIdx) = 0; end
                nFVec(rowIdx) = nF;
                expVec(rowIdx) = tickMs * 1000;
                S.GUI.(nFName) = nFVec;
                S.GUI.(expName) = expVec;
            end

            if isBlank
                message = sprintf('Row %d: blank, shows nothing for %g ms.', rowIdx, tickMs);
            else
                typeStr = 'all fixed';
                if any(~[spots.isFixed]), typeStr = 'includes random spots'; end
                message = sprintf('Row %d: %d frames, tick=%gms, %s.', rowIdx, nF, tickMs, typeStr);
            end
            obj.Saved = design;
            obj.LastMessage = message;
            if obj.Options.visible
                msgbox(message, 'Pattern saved', 'help');
            end
            obj.close();
        end

        % ------------------------------------------------------------ fiducial
        function showFiducial(obj, on)
            % Unfolds (widens the window) or folds the fiducial and alignment column.
            on = logical(on);
            obj.Controls.FiducialToggle.Value = on;
            arrow = char(9656);  % right-pointing triangle
            if on, arrow = char(9666); end
            obj.Controls.FiducialToggle.String = ['Fiducial & alignment ' arrow];
            position = obj.Figure.Position;
            right = position(1) + position(3);  % grows to the left: the camera is to its right
            position(3) = obj.WIDTH + on * obj.FIDUCIAL_WIDTH;
            position(1) = max(right - position(3), 0);
            obj.Figure.Position = position;
        end

        function setAnimal(obj, animal)
            obj.Controls.Animal.String = char(animal);
            obj.useAnimalFolder();
            obj.loadAnimal();
            obj.redraw();
        end

        function placeMark(obj, on)
            % While on, the next click on the camera image places the mark.
            obj.Picking = logical(on);
            obj.Controls.Place.Value = obj.Picking;
            if obj.Picking && obj.MarkingTargets
                obj.setMarkTargets(false);
            end
            if obj.Picking
                if ~obj.DmdAllOn && obj.Options.dmdAllowed()
                    obj.setDmdAllOn(true);  % the whole field lit, to see the landmark
                end
                obj.note('Click the landmark on the camera image.');
            end
        end

        function saveFiducial(obj)
            % Captures an averaged frame and adds it, with the mark, to the animal's
            % fiducial file (the first ever saved is the reference).
            if isempty(obj.MarkXY)
                obj.showError('Place the mark first: Place mark, then click the camera image.');
                return
            end
            if ~obj.cameraAttached() || ~obj.ensureCamera(), return; end
            app = obj.CameraPanel;
            wasLive = logical(app.Controls.Live.Value);
            app.setLive(false);
            frame = [];
            if obj.guard(@() captureInto())
                camera = app.Camera;
                entry = struct('frame', frame, 'xy', obj.MarkXY, ...
                    'exposureMs', camera.ExposureMs, 'roi', camera.Roi, 'binning', camera.Binning, ...
                    'registrationFile', registrationFile(obj.Registration), ...
                    'stageUm', obj.stagePositions(), ...
                    'stageCalibrationFile', registrationFile(obj.StageCalibration));
                file = obj.fiducialFile();
                if ~isempty(file) && obj.guard(@() obj.storeFiducial(file, entry))
                    obj.MarkXY = [];
                end
            end
            obj.updateReadout();
            obj.refresh();
            obj.redraw();
            app.setLive(wasLive);

            function captureInto()
                frame = app.Camera.capture();
                app.showFrame(frame);
            end
        end

        function alignToReference(obj)
            % Moves the stage until the camera matches the animal's reference;
            % while aligning, stops it instead.
            if obj.Aligning
                obj.StopRequested = true;
                return
            end
            if obj.Moving, return; end
            [can, why] = obj.canAlign();
            if ~can
                obj.showError(why);
                return
            end
            if ~obj.ensureCamera(), return; end
            [same, why] = obj.sameGeometry();
            if ~same
                obj.showError(why);
                obj.refresh();
                return
            end
            if ~obj.ensureStages(), return; end
            app = obj.CameraPanel;
            app.setLive(false);
            options = obj.Options.alignment;
            options.crop = obj.dmdFieldBox();
            options.progress = @(info) obj.onAlignProgress(info);
            options.shouldStop = @() obj.StopRequested;
            options.confirm = @(info) obj.Options.confirm(info);
            obj.Aligning = true;
            obj.StopRequested = false;
            obj.TargetTransform = [];  % the view is about to change
            obj.Controls.Align.String = 'Stop';
            obj.Controls.Align.BackgroundColor = [0.55 0.2 0.2];
            camera = app.Camera;
            result = [];
            try
                result = lhf.cam.align(@() camera.capture(), obj.Stages, ...
                    obj.Fiducial.reference.frame, obj.StageCalibration, options);
            catch err
                obj.showError(err.message);
            end
            obj.Aligning = false;
            if obj.Closing, return; end
            obj.Controls.Align.String = 'Align to reference';
            obj.Controls.Align.BackgroundColor = [0.2 0.45 0.7];
            obj.updateReadout();
            if isempty(result), obj.refresh(); return; end
            obj.LastAlignment = result;
            if strcmp(result.status, 'aligned')
                entry = struct('frame', result.frame, 'xy', [], 'exposureMs', camera.ExposureMs, ...
                    'roi', camera.Roi, 'binning', camera.Binning, ...
                    'registrationFile', registrationFile(obj.Registration), ...
                    'stageUm', result.endUm, ...
                    'stageCalibrationFile', registrationFile(obj.StageCalibration), ...
                    'alignment', rmfield(result, 'frame'));
                file = obj.fiducialFile();
                if ~isempty(file)
                    obj.guard(@() obj.storeFiducial(file, entry));
                end
            end
            if strcmp(result.status, 'aligned') && ~isempty(obj.Targets)
                obj.guard(@() obj.locateTargets());  % the targets where they are now
            end
            obj.refresh();
            obj.Controls.AlignInfo.String = result.message;  % after refresh's idle hint
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
            % Moves X and Y to the reference's saved position (Z stays, for Align
            % to reference); while moving, stops instead.
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
            obj.TargetTransform = [];  % the view moves: Locate again
            obj.Controls.GoRef.String = 'Stop';
            obj.Controls.GoRef.BackgroundColor = [0.55 0.2 0.2];
            obj.refresh();
            obj.guard(@() obj.moveXY(target));
            obj.Moving = false;
            if obj.Closing, return; end
            obj.Controls.GoRef.String = 'Go to reference X/Y';
            obj.Controls.GoRef.BackgroundColor = obj.BUTTON;
            obj.updateReadout();
            obj.refresh();
        end

        % ------------------------------------------------------------ targets
        function setMarkTargets(obj, on)
            % While on, clicks on the camera image add targets (right click removes the
            % nearest). Needs the reference fiducial and the targets located on it.
            on = logical(on);
            if on
                if isempty(obj.Registration) || ~obj.cameraAttached()
                    obj.showError('Needs the camera panel and the camera-DMD calibration.');
                    on = false;
                elseif isempty(obj.Fiducial)
                    obj.showError(['Save a fiducial first: targets are kept relative to the ' ...
                        'animal''s reference, so they come back in every session.']);
                    on = false;
                elseif isempty(obj.TargetTransform) && ~obj.guard(@() obj.locateTargets())
                    on = false;
                end
            end
            obj.MarkingTargets = on;
            obj.Controls.MarkTargets.Value = on;
            if on
                if obj.Picking, obj.placeMark(false); end
                obj.note('Click each target on the camera image (right click removes one).');
            else
                obj.note('');
            end
            obj.refresh();
        end

        function locateTargets(obj)
            % Captures a frame and registers it on the reference (no stage move): the
            % targets are then drawn where they are in this view. Errors when the
            % frames do not match well enough.
            if isempty(obj.Fiducial)
                error('lhf:designer:noReference', 'This animal has no reference fiducial yet.');
            end
            if ~obj.cameraAttached() || ~obj.ensureCamera()
                error('lhf:designer:noCamera', 'The camera is not connected.');
            end
            [same, why] = obj.sameGeometry();
            if ~same, error('lhf:designer:geometry', '%s', why); end
            app = obj.CameraPanel;
            wasLive = logical(app.Controls.Live.Value);
            app.setLive(false);
            restore = onCleanup(@() app.setLive(wasLive));
            frame = app.capture();
            box = obj.dmdFieldBox();
            minPeak = 0.1;
            try minPeak = obj.Options.alignment.minPeak; catch, end
            r = lhf.cam.register(obj.Fiducial.reference.frame, frame, 'Crop', box, ...
                'MinPeak', minPeak);
            obj.LastLocatePeak = r.peak;
            if ~r.ok
                obj.TargetTransform = [];
                error('lhf:designer:notLocated', ['The image does not match the reference well ' ...
                    'enough (peak %.2f): Align to reference first, or light and focus as the ' ...
                    'reference was.'], r.peak);
            end
            obj.TargetTransform = lhf.cam.mapPoints(r, box(3:4));
            clear restore
            obj.redraw();
            obj.refresh();
        end

        function spotsOnTargets(obj)
            % One spot on each ticked, located target (Free mode), within nSpots and
            % without overlaps; one note lists what was skipped.
            if isempty(obj.Targets), obj.note('No targets for this animal.'); return; end
            if isempty(obj.TargetTransform)
                obj.note('Locate the targets first (Locate, or Align to reference).');
                return
            end
            if strcmp(obj.Mode, 'grid')
                obj.note('Grid mode: click a target to toggle the cell under it.');
                return
            end
            dmd = obj.targetsOnDmd();
            skipped = {};
            for k = find([obj.Targets.use])
                name = obj.Targets(k).name;
                p = round(dmd(k, :));
                if any(p < 1) || p(1) > obj.DMD_W || p(2) > obj.DMD_H
                    skipped{end + 1} = sprintf('%s (outside the DMD field)', name); %#ok<AGROW>
                    continue
                end
                if any(hypot([obj.Spots.x] - p(1), [obj.Spots.y] - p(2)) < 0.5)
                    continue  % already on it
                end
                n = numel(obj.Spots);
                obj.clickDmd(p, 'normal');
                if numel(obj.Spots) == n
                    skipped{end + 1} = sprintf('%s (%s)', name, obj.LastMessage); %#ok<AGROW>
                end
            end
            if isempty(skipped)
                obj.note('');
            else
                obj.note(['Skipped: ' strjoin(skipped, '; ')]);
            end
        end

        function saveTargets(obj)
            % Keeps the targets for the animal (lhf.cam.saveTargets), with the image
            % they were marked on.
            file = obj.targetsFile();
            if isempty(file), return; end
            if isempty(obj.Fiducial)
                obj.showError('Save a fiducial first: targets are kept relative to it.');
                return
            end
            refTime = obj.Fiducial.reference.time;
            if ~isempty(obj.TargetsFile) && ~strcmp(obj.TargetsFile.referenceTime, refTime) ...
                    && ~obj.Options.confirmTargets(sprintf(['The saved targets were marked on ' ...
                    'the reference of %s, not this one (%s). Replace them?'], ...
                    obj.TargetsFile.referenceTime, refTime))
                return
            end
            frame = [];
            if obj.cameraAttached(), frame = obj.CameraPanel.Frame; end
            entry = struct('referenceTime', refTime, 'frame', frame, ...
                'transform', obj.TargetTransform);
            list = obj.Targets;
            if isempty(list), list = struct('name', {}, 'xy', {}, 'created', {}, 'use', {}); end
            if obj.guard(@() obj.storeTargets(file, list, entry))
                obj.TargetsDirty = false;
                obj.note(sprintf('%d target(s) saved for %s.', numel(obj.Targets), ...
                    obj.Controls.Animal.String));
            end
            obj.refresh();
        end

        function dmd = targetsOnDmd(obj)
            % Each target's DMD px now (n-by-2, continuous): located, else as in the
            % reference.
            dmd = zeros(0, 2);
            if isempty(obj.Targets) || isempty(obj.Registration), return; end
            dmd = obj.frameToDmd(obj.targetFrameXY());
        end

        function setTargetUse(obj, k, use)
            % Ticks (true) or unticks target k for Spots on targets.
            obj.Targets(k).use = logical(use);
            obj.targetsChanged();
        end

        function renameTarget(obj, k, name)
            % Names target k; refused (and the table put back) for an empty name or one
            % another target has.
            name = strtrim(char(name));
            others = {obj.Targets([1:k-1, k+1:end]).name};
            if isempty(name) || any(strcmp(others, name))
                obj.note('A target needs a name no other target has.');
                obj.syncTargetTable();
                return
            end
            obj.Targets(k).name = name;
            obj.targetsChanged();
        end

        function deleteTargets(obj, rows)
            % Removes the targets in rows (default: those selected in the table).
            if nargin < 2, rows = obj.TargetSel; end
            rows = rows(rows >= 1 & rows <= numel(obj.Targets));
            if isempty(rows)
                obj.note('Select targets in the table first.');
                return
            end
            obj.Targets(rows) = [];
            obj.TargetSel = [];
            obj.targetsChanged();
        end
    end

    methods (Access = private)
        % ------------------------------------------------------------ targets
        function storeTargets(obj, file, list, entry)
            obj.TargetsFile = lhf.cam.saveTargets(file, list, entry);
            obj.Targets = obj.TargetsFile.list;
        end

        function xy = targetFrameXY(obj)
            % Each target in the camera panel's frame px now (n-by-2): mapped when
            % located, else where it was in the reference.
            xy = zeros(0, 2);
            if isempty(obj.Targets) || ~obj.cameraAttached(), return; end
            camera = obj.CameraPanel.Camera;
            xy = camera.sensorToFrame(vertcat(obj.Targets.xy));
            if ~isempty(obj.TargetTransform)
                xy = lhf.cam.mapPoints(xy, obj.TargetTransform, 'toFrame');
            end
        end

        function r = snapRadius(obj)
            % How near a click must be to a target to land on it, frame px: the spot's
            % half-width on the camera, at least 10.
            r = 10;
            try
                a = obj.Registration.A(1:2, :);
                r = max(r, (obj.RPx + 0.5) * sqrt(abs(det(a))) / obj.CameraPanel.Camera.Binning);
            catch
            end
        end

        function xyFrame = snapToTarget(obj, xyFrame)
            % A click within snapRadius of a located target becomes the target's centre.
            if isempty(obj.Targets) || isempty(obj.TargetTransform), return; end
            xy = obj.targetFrameXY();
            [d, k] = min(hypot(xy(:, 1) - xyFrame(1), xy(:, 2) - xyFrame(2)));
            if d <= obj.snapRadius()
                xyFrame = xy(k, :);
            end
        end

        function markTargetAt(obj, xyFrame, kind)
            % Adds a target at a click (kept in the reference frame), or removes the
            % nearest on a right click.
            if isempty(obj.TargetTransform)
                obj.note('Locate the targets first.');
                return
            end
            if strcmp(kind, 'normal')
                ref = lhf.cam.mapPoints(xyFrame, obj.TargetTransform, 'toReference');
                xy = obj.CameraPanel.Camera.frameToSensor(ref);
                names = {};
                if ~isempty(obj.Targets), names = {obj.Targets.name}; end
                n = numel(names) + 1;
                while any(strcmp(names, sprintf('G%d', n))), n = n + 1; end
                target = struct('name', sprintf('G%d', n), 'xy', xy, ...
                    'created', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), 'use', true);
                if isempty(obj.Targets)
                    obj.Targets = target;
                else
                    obj.Targets(end + 1) = target;
                end
            else
                if isempty(obj.Targets), return; end
                xy = obj.targetFrameXY();
                [d, k] = min(hypot(xy(:, 1) - xyFrame(1), xy(:, 2) - xyFrame(2)));
                if d > obj.snapRadius()
                    obj.note('No target there to remove.');
                    return
                end
                obj.Targets(k) = [];
            end
            obj.targetsChanged();
        end

        function targetsChanged(obj)
            obj.TargetsDirty = true;
            obj.syncTargetTable();
            obj.redraw();
            obj.refresh();
        end

        function syncTargetTable(obj)
            t = obj.Targets;
            data = cell(numel(t), 4);
            for k = 1:numel(t)
                data(k, :) = {logical(t(k).use), t(k).name, round(t(k).xy(1)), round(t(k).xy(2))};
            end
            obj.Controls.TargetTable.Data = data;
        end

        function onTargetEdit(obj, ev)
            % Use ticked or a name typed (unique and not empty, or put back).
            k = ev.Indices(1);
            if k > numel(obj.Targets), return; end
            if ev.Indices(2) == 1
                obj.setTargetUse(k, ev.NewData);
            else
                obj.renameTarget(k, ev.NewData);
            end
        end

        function onTargetSelect(obj, ev)
            obj.TargetSel = [];
            if ~isempty(ev.Indices), obj.TargetSel = unique(ev.Indices(:, 1))'; end
        end

        function handles = drawTargets(obj, ax)
            % Each target as a circle with its name: cyan, faint when unticked, dashed
            % until located in this view.
            handles = gobjects(0);
            xy = obj.targetFrameXY();
            if isempty(xy), return; end
            r = obj.snapRadius();
            t = linspace(0, 2 * pi, 40);
            style = '-';
            if isempty(obj.TargetTransform), style = '--'; end
            for k = 1:size(xy, 1)
                colour = obj.TARGET;
                if ~obj.Targets(k).use, colour = 0.45 * obj.TARGET + 0.25; end
                handles(end + 1) = line(ax, xy(k, 1) + r * cos(t), xy(k, 2) + r * sin(t), ...
                    'Color', colour, 'LineStyle', style, 'LineWidth', 1.5, 'HitTest', 'off'); %#ok<AGROW>
                handles(end + 1) = text(ax, xy(k, 1), xy(k, 2) - r - 4, obj.Targets(k).name, ...
                    'Color', colour, 'FontSize', 9, 'FontWeight', 'bold', 'HitTest', 'off', ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom'); %#ok<AGROW>
            end
        end

        function names = targetOfEachSpot(obj)
            % For each spot, the located target it sits on (within its half-width), or ''.
            names = repmat({''}, 1, numel(obj.Spots));
            if isempty(obj.Targets) || isempty(obj.TargetTransform) || isempty(obj.Spots) ...
                    || isempty(obj.Registration)
                return
            end
            dmd = obj.targetsOnDmd();
            for i = 1:numel(obj.Spots)
                [d, k] = min(hypot(dmd(:, 1) - obj.Spots(i).x, dmd(:, 2) - obj.Spots(i).y));
                if d <= max(obj.RPx, 3)
                    names{i} = obj.Targets(k).name;
                end
            end
        end

        function refreshTargets(obj)
            % The targets' buttons and info line.
            c = obj.Controls;
            n = numel(obj.Targets);
            ready = ~isempty(obj.Registration) && ~isempty(obj.Fiducial) && obj.cameraAttached();
            c.MarkTargets.Enable = onOff(ready || obj.MarkingTargets);
            c.Locate.Enable = onOff(ready && ~obj.Aligning && ~obj.Moving);
            c.SpotsOnTargets.Enable = onOff(n > 0 && ~isempty(obj.TargetTransform));
            c.DeleteTargets.Enable = onOff(n > 0);
            c.SaveTargets.Enable = onOff(~isempty(obj.Fiducial) && (obj.TargetsDirty || n > 0));
            if isempty(obj.Fiducial)
                info = 'Save a fiducial first: targets are kept relative to the reference.';
            elseif n == 0
                info = 'No targets: Mark targets, then click glomeruli on the camera image.';
            elseif isempty(obj.TargetTransform)
                info = sprintf(['%d target(s), not located in this view (dashed): press Locate ' ...
                    'or Align to reference.'], n);
            else
                info = sprintf('%d target(s), located (peak %.2f).', n, obj.LastLocatePeak);
            end
            if ~isempty(obj.TargetsFile) && ~isempty(obj.Fiducial) ...
                    && ~strcmp(obj.TargetsFile.referenceTime, obj.Fiducial.reference.time)
                info = [info ' Marked on another reference (' obj.TargetsFile.referenceTime ').'];
            end
            if obj.TargetsDirty, info = [info ' Not saved.']; end
            c.TargetsInfo.String = info;
        end

        % ------------------------------------------------------------ building
        function build(obj, laser)
            % The spot column (WIDTH) and, to its right, the folded fiducial column.
            obj.LaserOn = ~isempty(laser);
            laserH = 0;
            if obj.LaserOn, laserH = 144; end
            H = 720 + laserH;
            obj.Height = H;
            visible = 'on';
            if ~obj.Options.visible, visible = 'off'; end
            obj.Figure = figure('Name', sprintf('Pattern Designer - %s  (row %d)', ...
                obj.PatternType, obj.RowIdx), 'NumberTitle', 'off', 'MenuBar', 'none', ...
                'ToolBar', 'none', 'Resize', 'off', 'Visible', visible, 'Color', obj.BG, ...
                'Position', lhf.windowPosition('designer', [obj.WIDTH H]), ...
                'CloseRequestFcn', @(~, ~) obj.close());
            addlistener(obj.Figure, 'ObjectBeingDestroyed', @(~, ~) obj.close());
            p = @(x, t, w, h) [x, H - t - h, w, h];  % from the top
            X = 12;
            IW = obj.WIDTH - 2 * X;
            c = struct();

            % Camera
            obj.label('CAMERA', p(X, 8, 120, 22), true);
            c.ShowDmd = uicontrol(obj.Figure, 'Style', 'checkbox', 'String', 'Show on DMD', ...
                'Position', p(X + 300, 8, 156, 22), 'FontSize', 10, 'FontWeight', 'bold', ...
                'BackgroundColor', obj.BG, 'ForegroundColor', [1 0.85 0.4], ...
                'TooltipString', 'Project the design (all spots at once) and again at every change', ...
                'Callback', @(src, ~) obj.setShowOnDmd(src.Value));
            c.Calibration = obj.label('', p(X, 32, IW, 30));
            c.Calibration.FontSize = 8;
            c.OpenCamera = obj.button('Device panels', p(X, 66, 112, 26), @(~, ~) obj.openPanels());
            c.OpenCamera.TooltipString = ['Open the camera (the design is drawn on it), stage (focus) ' ...
                'and laser (light) panels, or bring them forward'];
            c.Hint = obj.label('', p(X + 120, 64, IW - 120, 30));
            c.Hint.FontSize = 8;
            c.Hint.ForegroundColor = [0.6 0.6 0.6];
            c.FiducialToggle = uicontrol(obj.Figure, 'Style', 'togglebutton', ...
                'String', ['Fiducial & alignment ' char(9656)], ...
                'Position', p(X + 276, 100, 180, 24), 'FontSize', 9, ...
                'BackgroundColor', obj.BUTTON, 'ForegroundColor', [1 1 1], ...
                'Callback', @(src, ~) obj.showFiducial(src.Value));

            % Mode and fills
            obj.label('MODE', p(X, 100, 120, 22), true);
            c.ModeFree = obj.button('Free Placement', p(X, 126, 224, 28), @(~, ~) obj.setMode('free'));
            c.ModeGrid = obj.button('Grid Select', p(X + 232, 126, 224, 28), @(~, ~) obj.setMode('grid'));

            % Placement
            obj.label('PLACEMENT', p(X, 162, 120, 22), true);
            obj.label('nSpots', p(X, 190, 60, 22));
            c.NSpots = obj.edit('3', p(X + 62, 190, 45, 24), []);
            randomizeButton = obj.button('Randomize', p(X + 116, 188, 160, 28), @(~, ~) obj.randomize());
            randomizeButton.BackgroundColor = [0.2 0.45 0.7];
            clearButton = obj.button('Clear All', p(X + 284, 188, 172, 28), @(~, ~) obj.clearAll());
            clearButton.BackgroundColor = [0.5 0.2 0.2];
            allTypes = {'cue', 'CSplus', 'CSminus', 'opto'};
            obj.label('Overlay:', p(X, 224, 58, 22));
            c.Overlay = uicontrol(obj.Figure, 'Style', 'popupmenu', ...
                'String', [{'(none)'}, allTypes(~strcmp(allTypes, obj.PatternType))], ...
                'Position', p(X + 62, 222, 160, 26), 'FontSize', 10, ...
                'BackgroundColor', obj.EDIT, 'ForegroundColor', [1 1 1], ...
                'Callback', @(src, ~) obj.setOverlayType(src.String{src.Value}));
            ovNote = obj.label('reference layer (amber); overlap allowed', p(X + 230, 224, 226, 22));
            ovNote.FontSize = 8;
            ovNote.ForegroundColor = [0.45 0.45 0.45];
            obj.label('Tick (ms)', p(X, 256, 62, 22));
            c.TickMs = obj.edit('10', p(X + 62, 256, 45, 24), []);
            perFrame = obj.label('ms per frame', p(X + 112, 256, 90, 22));
            perFrame.FontSize = 9;
            perFrame.ForegroundColor = [0.5 0.5 0.5];
            obj.label('Spot side (mm)', p(X + 210, 256, 100, 22));
            c.SpotSide = obj.edit(sprintf('%.3g', obj.SpotSide), p(X + 312, 256, 55, 24), ...
                @(src, ~) obj.setSpotSide(str2double(src.String)));
            c.SpotInfo = obj.label('', p(X, 282, IW, 20));
            c.SpotInfo.FontSize = 9;

            % Spots
            obj.label('SPOTS', p(X, 304, 120, 22), true);
            c.Table = uitable(obj.Figure, 'Position', p(X, 328, IW, 160), ...
                'ColumnName', {'#', 'X (px)', 'Y (px)', 'Onset (ms)', 'Dur (ms)', 'Type'}, ...
                'ColumnWidth', {28, 66, 66, 80, 68, 90}, ...
                'ColumnEditable', [false true true true true true], ...
                'ColumnFormat', {'numeric', 'numeric', 'numeric', 'numeric', 'numeric', {'Fixed', 'Random'}}, ...
                'Data', {}, 'FontSize', 10, ...
                'BackgroundColor', [0.2 0.2 0.22; 0.17 0.17 0.19], 'ForegroundColor', [0.9 0.9 0.9], ...
                'CellEditCallback', @(~, ev) obj.onTableEdit(ev));
            obj.label('Delete spot #', p(X, 496, 92, 22));
            c.DeleteIdx = obj.edit('1', p(X + 96, 496, 40, 24), []);
            deleteButton = obj.button('Delete', p(X + 144, 494, 80, 28), ...
                @(~, ~) obj.deleteSpot(round(str2double(obj.Controls.DeleteIdx.String))));
            deleteButton.BackgroundColor = [0.45 0.22 0.22];

            % Timeline
            obj.label('TIMELINE', p(X, 530, 120, 22), true);
            c.Timeline = axes('Parent', obj.Figure, 'Units', 'pixels', 'Position', p(X, 554, IW, 80), ...
                'Color', [0.16 0.16 0.18], 'XColor', [0.6 0.6 0.6], 'YColor', 'none', ...
                'NextPlot', 'replacechildren', 'FontSize', 9);
            xlabel(c.Timeline, 'Time (ms)', 'Color', [0.6 0.6 0.6], 'FontSize', 9);

            % Laser power per pattern: one row per irradiance, each trial draws one
            t = 666;
            if obj.LaserOn
                obj.label('LASER POWER', p(X, t, 120, 22), true);
                range = obj.label(calibratedRangeText(obj.Luminose), p(X + 124, t, IW - 124, 22));
                range.FontSize = 9;
                range.ForegroundColor = [0.55 0.75 0.95];
                c.LaserTable = uitable(obj.Figure, 'Data', laserRows(laser.irradiances, laser.weights), ...
                    'ColumnName', {'Irradiance (mW/mm2)', 'Prob'}, 'ColumnWidth', {160, 90}, ...
                    'ColumnEditable', [true true], 'ColumnFormat', {'numeric', 'numeric'}, ...
                    'Position', p(X, t + 24, 300, 84), 'FontSize', 10, ...
                    'BackgroundColor', [0.2 0.2 0.22; 0.17 0.17 0.19], 'ForegroundColor', [0.9 0.9 0.9], ...
                    'CellEditCallback', @(~, ev) obj.onLaserEdit(ev), ...
                    'CellSelectionCallback', @(~, ev) obj.onLaserSelect(ev));
                obj.button('+ Add irradiance', p(X + 310, t + 24, 146, 28), @(~, ~) obj.onLaserAdd());
                obj.button('- Remove selected', p(X + 310, t + 58, 146, 28), @(~, ~) obj.onLaserRemove());
                laserNote = obj.label(['Each trial showing this pattern draws one irradiance with ' ...
                    'its Prob; the probabilities are rescaled to sum to 1.'], p(X, t + 112, IW, 28));
                laserNote.FontSize = 8;
                laserNote.ForegroundColor = [0.5 0.5 0.5];
                t = t + laserH;
            end

            % Save / Cancel
            saveButton = uicontrol(obj.Figure, 'Style', 'pushbutton', 'String', 'Save Pattern', ...
                'Position', p(X, t, 222, 44), 'FontSize', 13, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.15 0.55 0.25], 'ForegroundColor', [1 1 0.4], ...
                'Callback', @(~, ~) obj.savePattern());
            c.Save = saveButton;
            c.Cancel = uicontrol(obj.Figure, 'Style', 'pushbutton', 'String', 'Cancel', ...
                'Position', p(X + 234, t, 222, 44), 'FontSize', 13, ...
                'BackgroundColor', [0.35 0.35 0.38], 'ForegroundColor', [0.9 0.9 0.9], ...
                'Callback', @(~, ~) obj.close());

            obj.Controls = c;
            obj.buildFiducial(p, obj.WIDTH + 4);
        end

        function buildFiducial(obj, p, x)
            % The fiducial and alignment column, right of the spot column.
            c = obj.Controls;
            fig = obj.Figure;
            w = obj.FIDUCIAL_WIDTH - 20;
            obj.label('FIDUCIAL', p(x, 8, 120, 22), true);
            obj.label('Animal', p(x, 36, 50, 22));
            c.Animal = obj.edit(obj.Options.animal, p(x + 54, 36, 160, 24), ...
                @(src, ~) obj.setAnimal(src.String));
            c.Animal.HorizontalAlignment = 'left';
            c.AllOn = uicontrol(fig, 'Style', 'togglebutton', 'String', 'DMD all on', ...
                'Position', p(x + 230, 34, 150, 26), 'FontSize', 10, 'FontWeight', 'bold', ...
                'BackgroundColor', obj.BUTTON, 'ForegroundColor', [1 0.85 0.4], ...
                'TooltipString', 'Every mirror on, to light the whole field (Place mark turns it on)', ...
                'Callback', @(src, ~) obj.setDmdAllOn(src.Value));
            c.FiducialInfo = obj.label('', p(x, 64, w, 44));
            c.FiducialInfo.FontSize = 9;
            c.Place = uicontrol(fig, 'Style', 'togglebutton', 'String', 'Place mark', ...
                'Position', p(x, 112, 104, 28), 'FontSize', 10, ...
                'BackgroundColor', obj.BUTTON, 'ForegroundColor', [1 1 1], ...
                'Callback', @(src, ~) obj.placeMark(src.Value));
            c.SaveFiducial = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Save fiducial', ...
                'Position', p(x + 110, 112, 116, 28), 'FontSize', 10, ...
                'BackgroundColor', [0.15 0.5 0.28], 'ForegroundColor', [1 1 1], ...
                'Callback', @(~, ~) obj.saveFiducial());
            c.ShowRef = uicontrol(fig, 'Style', 'checkbox', 'String', 'Show reference mark', ...
                'Value', true, 'Position', p(x + 234, 114, 150, 22), 'FontSize', 9, ...
                'BackgroundColor', obj.BG, 'ForegroundColor', obj.LABEL, ...
                'Callback', @(~, ~) obj.redraw());
            note = obj.label(['DMD all on (Place mark turns it on), Place mark, click a landmark on ' ...
                'the camera image, Save fiducial: the first one saved is the animal''s reference ' ...
                '(red crosshair).'], p(x, 144, w, 30));
            note.FontSize = 8;
            note.ForegroundColor = [0.5 0.5 0.5];

            obj.label('ALIGNMENT', p(x, 182, 120, 22), true);
            c.Align = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Align to reference', ...
                'Position', p(x, 208, 150, 30), 'FontSize', 10, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.2 0.45 0.7], 'ForegroundColor', [1 1 1], ...
                'TooltipString', 'Move the stage (X, Y, Z) until the camera matches the reference frame', ...
                'Callback', @(~, ~) obj.alignToReference());
            c.AlignInfo = obj.label('', p(x + 158, 206, w - 158, 58));
            c.AlignInfo.FontSize = 8;

            obj.label('STAGE', p(x, 272, 120, 22), true);
            c.ReadStage = obj.button('Read', p(x, 298, 60, 28), @(~, ~) obj.readStage());
            c.StageReadout = obj.label('Not connected: press Read', p(x + 66, 300, w - 66, 24));
            c.StageReadout.FontSize = 9;
            c.GoRef = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Go to reference X/Y', ...
                'Position', p(x, 334, 150, 30), 'FontSize', 10, ...
                'BackgroundColor', obj.BUTTON, 'ForegroundColor', [1 1 1], ...
                'TooltipString', 'Move X and Y to where the reference was saved; Z stays', ...
                'Callback', @(~, ~) obj.goToReference());
            c.GoRefInfo = obj.label('', p(x + 158, 330, w - 158, 46));
            c.GoRefInfo.FontSize = 8;
            c.StageCalibration = obj.label('', p(x, 384, w, 30));
            c.StageCalibration.FontSize = 8;

            obj.label('TARGETS', p(x, 422, 120, 22), true);
            c.MarkTargets = uicontrol(fig, 'Style', 'togglebutton', 'String', 'Mark targets', ...
                'Position', p(x, 448, 112, 28), 'FontSize', 10, ...
                'BackgroundColor', obj.BUTTON, 'ForegroundColor', obj.TARGET, ...
                'TooltipString', 'Clicks on the camera image add targets (right click removes one)', ...
                'Callback', @(src, ~) obj.setMarkTargets(src.Value));
            c.Locate = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Locate', ...
                'Position', p(x + 118, 448, 80, 28), 'FontSize', 10, ...
                'BackgroundColor', obj.BUTTON, 'ForegroundColor', [1 1 1], ...
                'TooltipString', ['Capture, register on the reference (no stage move) and draw ' ...
                    'the targets where they are now'], ...
                'Callback', @(~, ~) obj.guard(@() obj.locateTargets()));
            c.SpotsOnTargets = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Spots on targets', ...
                'Position', p(x + 204, 448, w - 204, 28), 'FontSize', 10, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.15 0.45 0.45], 'ForegroundColor', [1 1 1], ...
                'TooltipString', 'One spot on each ticked target', ...
                'Callback', @(~, ~) obj.spotsOnTargets());
            c.TargetTable = uitable(fig, 'Position', p(x, 482, w, 150), ...
                'ColumnName', {'Use', 'Name', 'X', 'Y'}, ...
                'ColumnFormat', {'logical', 'char', 'numeric', 'numeric'}, ...
                'ColumnEditable', [true true false false], 'ColumnWidth', {40, 150, 70, 70}, ...
                'RowName', [], 'Data', cell(0, 4), ...
                'CellEditCallback', @(~, ev) obj.onTargetEdit(ev), ...
                'CellSelectionCallback', @(~, ev) obj.onTargetSelect(ev));
            c.DeleteTargets = obj.button('Delete', p(x, 638, 80, 26), @(~, ~) obj.deleteTargets());
            c.SaveTargets = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Save targets', ...
                'Position', p(x + 86, 638, 120, 26), 'FontSize', 10, ...
                'BackgroundColor', [0.15 0.5 0.28], 'ForegroundColor', [1 1 1], ...
                'Callback', @(~, ~) obj.saveTargets());
            c.TargetsInfo = obj.label('', p(x, 668, w, 46));
            c.TargetsInfo.FontSize = 8;
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
                'FontSize', 11, 'BackgroundColor', obj.EDIT, 'ForegroundColor', [1 1 1], ...
                'Callback', callback);
        end

        function h = button(obj, text, position, callback)
            h = uicontrol(obj.Figure, 'Style', 'pushbutton', 'String', text, 'Position', position, ...
                'FontSize', 10, 'BackgroundColor', obj.BUTTON, 'ForegroundColor', [1 1 1], ...
                'Callback', callback);
        end

        % ------------------------------------------------------------ the design
        function [laser, loadedTickMs] = loadDesign(obj, preloadFromType)
            % The row's design (another type's with preloadFromType) and its laser rows.
            global S BpodSystem %#ok<GVMIS> the protocol's (CLAUDE.md, Global variables)
            luminose = obj.Luminose;
            [laserOn, laser] = laserOptionsFor(S, obj.PatternType);
            loadType = obj.PatternType;
            loadRow = obj.RowIdx;
            if ~isempty(preloadFromType)
                loadType = preloadFromType;
                loadRow = 1;
            end
            design = [];
            try
                design = BpodSystem.PluginObjects.PatternDesigns.(loadType){loadRow};
            catch
            end
            if isstruct(design) && isfield(design, 'spots')
                spots = design.spots;
                loadedTickMs = design.tickMs;
                meta = design;
            else
                [spots, loadedTickMs, meta] = tryLoadMetaForRow(lhf.patternFolder(luminose.dmd, loadType), ...
                    lhf.patternFileType(luminose.dmd, loadType), loadRow);
            end
            if ~isempty(spots)
                obj.Spots = spots;
            end
            if laserOn && isfield(meta, 'laserIrradiances_mWmm2') && ~isempty(meta.laserIrradiances_mWmm2)
                laser.irradiances = meta.laserIrradiances_mWmm2;
                laser.weights = meta.laserWeights;
            end
            if ~laserOn, laser = []; end
            if ~isempty(spots) && isfield(meta, 'r_px')
                obj.applySpotSide(meta.r_px * 2 * luminose.dmd.projectedDMDlength / obj.DMD_W);  % its own size
            end
            obj.GridSelected = obj.spotsToGrid(obj.Spots);
        end

        function changed(obj, retick)
            % After any edit: the table, timeline, spot info, the camera and the DMD.
            if obj.Closing, return; end
            obj.syncTableFromSpots();
            obj.refreshTimeline();
            if retick, obj.updateDefaultTick(); end
            obj.updateSpotInfo();
            obj.redraw();
            obj.project();
        end

        function redraw(obj)
            % The design drawn again on the camera image.
            if obj.cameraAttached()
                obj.CameraPanel.redrawOverlay();
            end
        end

        function project(obj)
            % The design on the DMD, while Show on DMD is ticked.
            if ~obj.ShowOnDmd, return; end
            if ~obj.Options.dmdAllowed()
                obj.ShowOnDmd = false;
                obj.Controls.ShowDmd.Value = false;
                obj.note('The running session owns the DMD: Show on DMD turned off.');
                return
            end
            if obj.guard(@() obj.connectDmd())
                obj.guard(@() obj.Dmd.displayFrame(obj.patternImage()));
            end
        end

        function connectDmd(obj)
            obj.Dmd = obj.Options.makeDmd();  % the rig's shared DMD, connected (again)
        end

        function applySpotSide(obj, mm)
            obj.SpotSide = mm;
            r = max(round((mm / obj.Luminose.dmd.projectedDMDlength) * obj.DMD_W / 2), 1);
            obj.RPx = r;
            % 1 px between cells: no two cells' spots can overlap
            obj.GridCellSize = 2 * r + 2;
            obj.GridCols = floor(obj.DMD_W / obj.GridCellSize);
            obj.GridRows = floor(obj.DMD_H / obj.GridCellSize);
            obj.GridOffX = floor((obj.DMD_W - obj.GridCols * obj.GridCellSize) / 2);
            obj.GridOffY = floor((obj.DMD_H - obj.GridRows * obj.GridCellSize) / 2);
        end

        function n = nSpots(obj)
            n = round(str2double(obj.Controls.NSpots.String));
            if isnan(n) || n < 1, n = 3; end
        end

        function updateSpotInfo(obj)
            overlapping = false;
            for k = 1:numel(obj.Spots)
                if obj.anyOverlapWith(obj.Spots(k).x, obj.Spots(k).y, obj.Spots, k)
                    overlapping = true;
                    break
                end
            end
            info = obj.Controls.SpotInfo;
            if overlapping
                info.String = sprintf('half-width %d DMD px: spots overlap at this size', obj.RPx);
                info.ForegroundColor = [1 0.6 0.2];
            else
                info.String = sprintf('half-width %d DMD px; solid = Fixed, dashed = Random', obj.RPx);
                info.ForegroundColor = [0.5 0.5 0.5];
            end
        end

        function syncSpotsFromGrid(obj)
            % The spots at the selected cells' centres, keeping each one's timing.
            [rows, cols] = find(obj.GridSelected);
            old = obj.Spots;
            spots = emptySpots();
            r = obj.RPx;
            for i = 1:numel(rows)
                cx = obj.GridOffX + (cols(i) - 1) * obj.GridCellSize + r;
                cy = obj.GridOffY + (rows(i) - 1) * obj.GridCellSize + r;
                onset = 0;
                dur = 200;
                for j = 1:numel(old)
                    if max(abs(old(j).x - cx), abs(old(j).y - cy)) <= r
                        onset = old(j).onset_ms;
                        dur = old(j).dur_ms;
                        break
                    end
                end
                spots(i) = struct('x', cx, 'y', cy, 'onset_ms', onset, 'dur_ms', dur, 'isFixed', true);
            end
            obj.Spots = spots;
        end

        function gs = spotsToGrid(obj, spots)
            gs = false(obj.GridRows, obj.GridCols);
            for i = 1:numel(spots)
                col = floor((spots(i).x - obj.GridOffX) / obj.GridCellSize) + 1;
                row = floor((spots(i).y - obj.GridOffY) / obj.GridCellSize) + 1;
                if col >= 1 && col <= obj.GridCols && row >= 1 && row <= obj.GridRows
                    gs(row, col) = true;
                end
            end
        end

        function tf = anyOverlapWith(obj, x, y, spots, excludeIdx)
            % Chebyshev distance within 2 r_px of any spot but excludeIdx.
            tf = false;
            for k = 1:numel(spots)
                if k ~= excludeIdx && max(abs(x - spots(k).x), abs(y - spots(k).y)) <= 2 * obj.RPx
                    tf = true;
                    return
                end
            end
        end

        function ov = loadOverlay(obj)
            global BpodSystem %#ok<GVMIS> the protocol's (CLAUDE.md, Global variables)
            ov = emptySpots();
            sel = obj.Controls.Overlay.String{obj.Controls.Overlay.Value};
            if strcmp(sel, '(none)'), return; end
            try
                ov = BpodSystem.PluginObjects.PatternDesigns.(sel){1}.spots;
                return
            catch
            end
            luminose = obj.Luminose;
            ov = tryLoadMetaForRow(lhf.patternFolder(luminose.dmd, sel), lhf.patternFileType(luminose.dmd, sel), 1);
        end

        function syncTableFromSpots(obj)
            n = numel(obj.Spots);
            data = cell(n, 6);
            for i = 1:n
                s = obj.Spots(i);
                data(i, :) = {i, s.x, s.y, s.onset_ms, s.dur_ms, 'Fixed'};
                if ~s.isFixed, data{i, 6} = 'Random'; end
            end
            obj.Controls.Table.Data = data;
        end

        function updateDefaultTick(obj)
            if isempty(obj.Spots), return; end
            onsets = [obj.Spots.onset_ms];
            durs = [obj.Spots.dur_ms];
            if isscalar(unique(onsets)) && isscalar(unique(durs))
                obj.Controls.TickMs.String = num2str(durs(1));
            else
                obj.Controls.TickMs.String = '1';
            end
        end

        function updateModeButtons(obj)
            on = {'BackgroundColor', [0.22 0.50 0.82], 'ForegroundColor', [1 1 1]};
            off = {'BackgroundColor', [0.25 0.25 0.28], 'ForegroundColor', [0.65 0.65 0.65]};
            if strcmp(obj.Mode, 'free')
                set(obj.Controls.ModeFree, on{:});
                set(obj.Controls.ModeGrid, off{:});
            else
                set(obj.Controls.ModeFree, off{:});
                set(obj.Controls.ModeGrid, on{:});
            end
        end

        function onTableEdit(obj, ev)
            r = ev.Indices(1);
            val = ev.NewData;
            ok = isnumeric(val) && isscalar(val) && ~isnan(val);
            switch ev.Indices(2)
                case {2, 3}
                    if ok
                        name = 'x';
                        top = obj.DMD_W;
                        if ev.Indices(2) == 3, name = 'y'; top = obj.DMD_H; end
                        old = obj.Spots(r).(name);
                        obj.Spots(r).(name) = round(max(1, min(top, val)));
                        if obj.anyOverlapWith(obj.Spots(r).x, obj.Spots(r).y, obj.Spots, r)
                            obj.Spots(r).(name) = old;
                            obj.showError(sprintf('Spot %d would overlap another: reverted.', r));
                        end
                    end
                case 4
                    if ok, obj.Spots(r).onset_ms = max(0, val); end
                case 5
                    if ok, obj.Spots(r).dur_ms = max(1, val); end
                case 6
                    if strcmp(obj.Mode, 'free')
                        obj.Spots(r).isFixed = strcmp(val, 'Fixed');
                    end
            end
            if strcmp(obj.Mode, 'grid')
                obj.GridSelected = obj.spotsToGrid(obj.Spots);
            end
            obj.changed(true);
        end

        function onLaserEdit(obj, ev)
            if ev.Indices(1, 2) == 2  % a Prob: rescale all to sum to 1
                obj.Controls.LaserTable.Data = normalizeLaserProbs(obj.Controls.LaserTable.Data);
            end
        end

        function onLaserSelect(obj, ev)
            if ~isempty(ev.Indices), obj.LaserSelRow = ev.Indices(1, 1); end
        end

        function onLaserAdd(obj)
            rows = obj.Controls.LaserTable.Data;
            rows(end + 1, :) = {[], 0};
            rows(:, 2) = {round(1 / size(rows, 1), 4)};  % equal, as the pattern table's +
            obj.Controls.LaserTable.Data = rows;
        end

        function onLaserRemove(obj)
            rows = obj.Controls.LaserTable.Data;
            if size(rows, 1) <= 1, return; end  % keep one row
            k = obj.LaserSelRow;
            if isempty(k) || k > size(rows, 1), k = size(rows, 1); end  % none selected: the last
            rows(k, :) = [];
            obj.LaserSelRow = [];
            obj.Controls.LaserTable.Data = normalizeLaserProbs(rows);
        end

        function refreshTimeline(obj)
            ax = obj.Controls.Timeline;
            cla(ax);
            spots = obj.Spots;
            if isempty(spots), return; end
            n = numel(spots);
            totalDur = max([spots.onset_ms] + [spots.dur_ms]);
            hold(ax, 'on');
            for i = 1:n
                col = obj.spotColour(i);
                yi = n - i + 1;
                style = '-';
                if ~spots(i).isFixed, style = '--'; end
                rectangle(ax, 'Position', [spots(i).onset_ms, yi - 0.4, spots(i).dur_ms, 0.8], ...
                    'FaceColor', col, 'EdgeColor', col * 0.7, 'LineWidth', 0.8, 'LineStyle', style);
                text(ax, spots(i).onset_ms + spots(i).dur_ms / 2, yi, num2str(i), ...
                    'Color', [1 1 1], 'FontSize', 8, 'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
            end
            set(ax, 'XLim', [0 totalDur * 1.05 + 1], 'YLim', [0 n + 1]);
            hold(ax, 'off');
        end

        function col = spotColour(obj, i)
            col = obj.SPOT_COLORS(mod(i - 1, size(obj.SPOT_COLORS, 1)) + 1, :);
        end

        % ------------------------------------------------------------ drawing
        function handles = drawFreeSpots(obj, ax)
            % Each spot's square, as the DMD lights it, mapped onto the camera.
            handles = gobjects(0);
            for i = 1:numel(obj.OverlaySpots)
                s = obj.OverlaySpots(i);
                xy = obj.dmdToFrame(obj.square(s.x, s.y));
                handles(end + 1) = patch(ax, xy(:, 1), xy(:, 2), obj.OVERLAY, 'FaceAlpha', 0.18, ...
                    'EdgeColor', obj.OVERLAY, 'LineStyle', ':', 'LineWidth', 1.2); %#ok<AGROW>
                centre = mean(xy, 1);
                handles(end + 1) = text(ax, centre(1), centre(2), sprintf('O%d', i), ...
                    'Color', obj.OVERLAY, 'FontSize', 8, 'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle'); %#ok<AGROW>
            end
            for i = 1:numel(obj.Spots)
                s = obj.Spots(i);
                col = obj.spotColour(i);
                xy = obj.dmdToFrame(obj.square(s.x, s.y));
                if s.isFixed
                    handles(end + 1) = patch(ax, xy(:, 1), xy(:, 2), col, 'FaceAlpha', 0.35, ...
                        'EdgeColor', col, 'LineWidth', 2); %#ok<AGROW>
                else
                    handles(end + 1) = patch(ax, xy(:, 1), xy(:, 2), col, 'FaceAlpha', 0.15, ...
                        'EdgeColor', col, 'LineStyle', '--', 'LineWidth', 1.8); %#ok<AGROW>
                end
                centre = mean(xy, 1);
                handles(end + 1) = text(ax, centre(1), centre(2), num2str(i), 'Color', [1 1 1], ...
                    'FontSize', 9, 'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle'); %#ok<AGROW>
            end
        end

        function handles = drawGrid(obj, ax)
            % Every cell's square on the camera: selected blue, the overlay's amber.
            [cols, rows] = meshgrid(1:obj.GridCols, 1:obj.GridRows);
            cx = obj.GridOffX + (cols(:) - 1) * obj.GridCellSize + obj.RPx;
            cy = obj.GridOffY + (rows(:) - 1) * obj.GridCellSize + obj.RPx;
            own = obj.GridSelected(:);
            ov = obj.spotsToGrid(obj.OverlaySpots);
            ov = ov(:);
            handles = gobjects(0);
            groups = {~own & ~ov, ov & ~own, own};
            styles = {{[0.6 0.6 0.65], 'FaceAlpha', 0, 'EdgeColor', [0.6 0.6 0.65], 'EdgeAlpha', 0.35}, ...
                {obj.OVERLAY, 'FaceAlpha', 0.3, 'EdgeColor', obj.OVERLAY}, ...
                {[0.24 0.6 1], 'FaceAlpha', 0.45, 'EdgeColor', [0.24 0.6 1]}};
            for g = 1:3
                k = find(groups{g});
                if isempty(k), continue; end
                vertices = zeros(4 * numel(k), 2);
                for j = 1:numel(k)
                    corners = obj.square(cx(k(j)), cy(k(j)));
                    vertices(4 * j - 3:4 * j, :) = corners(1:4, :);
                end
                vertices = obj.dmdToFrame(vertices);
                faces = reshape(1:4 * numel(k), 4, [])';
                handles(end + 1) = patch(ax, 'Faces', faces, 'Vertices', vertices, ...
                    'FaceColor', styles{g}{1}, styles{g}{2:end}); %#ok<AGROW>
            end
        end

        function handles = drawMarks(obj, ax)
            % The reference mark (red crosshair) and this session's mark (yellow).
            handles = gobjects(0);
            camera = obj.CameraPanel.Camera;
            xl = ax.XLim;
            yl = ax.YLim;
            red = [1 0.25 0.25];
            if obj.Controls.ShowRef.Value && ~isempty(obj.Fiducial) && ~isempty(obj.Fiducial.reference.xy)
                p = camera.sensorToFrame(obj.Fiducial.reference.xy);
                handles = [line(ax, xl, [p(2) p(2)], 'Color', red, 'LineWidth', 1), ...
                    line(ax, [p(1) p(1)], yl, 'Color', red, 'LineWidth', 1), ...
                    line(ax, p(1), p(2), 'Marker', 'o', 'Color', red, 'MarkerSize', 12, 'LineWidth', 1.5)];
            end
            if ~isempty(obj.MarkXY)
                p = camera.sensorToFrame(obj.MarkXY);
                handles(end + 1) = line(ax, p(1), p(2), 'Marker', '+', 'Color', [1 0.9 0.1], ...
                    'MarkerSize', 16, 'LineWidth', 2);
            end
        end

        % ------------------------------------------------------------ camera panel
        function openCameraPanel(obj)
            obj.CameraPanel = obj.Options.openCamera();
        end

        function tf = cameraAttached(obj)
            app = obj.CameraPanel;
            tf = ~isempty(app) && isvalid(app) && ~isempty(app.Root) && isvalid(app.Root);
        end

        function detachCamera(obj)
            if obj.cameraAttached()
                try
                    obj.CameraPanel.setImageClickFcn([]);
                    obj.CameraPanel.setOverlay([]);
                catch
                end
            end
        end

        function ok = ensureCamera(obj)
            % The shared camera, connected (again, if its panel disconnected it).
            ok = obj.cameraAttached() || obj.guard(@() obj.openCameraPanel());
            if ~ok, return; end
            camera = obj.CameraPanel.Camera;
            ok = strcmp(camera.State, 'Ready') || obj.guard(@() camera.connect());
        end

        % ------------------------------------------------------------ fiducial
        function refresh(obj)
            % The status lines and what can be used.
            if obj.Closing || isempty(obj.Figure) || ~isvalid(obj.Figure), return; end
            c = obj.Controls;
            calibrated = ~isempty(obj.Registration);
            if calibrated
                c.Calibration.String = sprintf(['Camera-DMD calibration %s (rms %.2f camera px). ' ...
                    'Spots are drawn on the camera panel''s image.'], ...
                    registrationName(obj.Registration), obj.Registration.rmsPx);
                c.Calibration.ForegroundColor = [0.55 0.75 0.95];
                if isempty(c.Hint.String) || ~obj.cameraAttached()
                    c.Hint.String = obj.idleHint();
                end
            else
                c.Calibration.String = ['No camera-DMD calibration: spots cannot be placed. Run ' ...
                    'Camera - DMD in the Calibration window (Calibrate; calibrate_camera_dmd.m).'];
                c.Calibration.ForegroundColor = [1 0.6 0.2];
                c.Hint.String = 'A saved design can still be retimed and saved.';
            end
            set([c.Place, c.SaveFiducial], 'Enable', onOff(calibrated));
            allowed = obj.Options.dmdAllowed();
            c.ShowDmd.Enable = onOff(allowed || obj.ShowOnDmd);
            c.AllOn.Enable = onOff(allowed || obj.DmdAllOn);
            if allowed
                c.ShowDmd.TooltipString = 'Project the design (all spots at once) and again at every change';
            else
                c.ShowDmd.TooltipString = 'The running session owns the DMD';
            end
            fid = obj.Fiducial;
            if isempty(fid)
                info = 'No fiducial for this animal yet: the first one saved is its reference.';
            else
                info = sprintf('Reference %s; %d session(s) saved, last %s.', ...
                    fid.reference.time, numel(fid.sessions), fid.sessions(end).time);
            end
            if ~isempty(obj.MarkXY)
                info = [info sprintf(' Mark placed at (%.0f, %.0f) sensor px.', obj.MarkXY)];
            end
            c.FiducialInfo.String = info;
            [can, why] = obj.canAlign();
            c.Align.Enable = onOff((can && ~obj.Moving) || obj.Aligning);
            if ~obj.Aligning
                c.AlignInfo.String = why;
            end
            c.ReadStage.Enable = onOff(obj.Options.stagesConfigured && ~obj.Aligning && ~obj.Moving);
            [can, why] = obj.canGoToReference();
            c.GoRef.Enable = onOff(can || obj.Moving);
            c.GoRefInfo.String = why;
            obj.refreshTargets();
            if isempty(obj.StageCalibration)
                c.StageCalibration.String = 'No stage-camera calibration (Calibrate: Stage - camera).';
            else
                c.StageCalibration.String = sprintf('Stage-camera calibration %s (%.3f px/um).', ...
                    registrationName(obj.StageCalibration), obj.StageCalibration.pxPerUm);
            end
        end

        function text = idleHint(obj)
            if ~obj.cameraAttached()
                text = 'The camera panel is closed: press Device panels to draw on it.';
            elseif strcmp(obj.Mode, 'grid')
                text = ['Light with the laser, focus with the stage; Live or Capture on the camera ' ...
                    'panel, then click its image to toggle grid cells.'];
            else
                text = ['Light with the laser, focus with the stage; Live or Capture on the camera ' ...
                    'panel, then click its image: left adds a spot, right removes one.'];
            end
        end

        function note(obj, text)
            % A one-line note under the camera line ('' for the usual hint).
            if obj.Closing, return; end
            if isempty(text), text = obj.idleHint(); end
            obj.Controls.Hint.String = text;
            obj.LastMessage = text;
        end

        function [can, why] = canAlign(obj)
            can = false;
            if isempty(obj.Registration)
                why = 'Needs the camera-DMD calibration.';
            elseif isempty(obj.StageCalibration)
                why = 'Needs the stage-camera calibration: run Stage - camera in the Calibration window.';
            elseif ~obj.Options.stagesConfigured
                why = 'Needs zaber.axes (x, y, z, each with safe_um) in luminose_config.yaml.';
            elseif isempty(obj.Fiducial)
                why = 'Save this animal''s reference first.';
            elseif ~obj.Options.dmdAllowed()
                why = 'Not while a session runs.';
            else
                [can, why] = obj.sameGeometry();
                if can
                    why = 'Moves X/Y, finds Z, refines X/Y; asks before the first move.';
                end
            end
        end

        function [same, why] = sameGeometry(obj)
            % Whether the camera reads out as the reference was saved (subarray and
            % binning): alignment compares frames pixel for pixel. Unknown until the
            % camera is connected.
            same = true;
            why = '';
            if isempty(obj.Fiducial) || ~obj.cameraAttached(), return; end
            camera = obj.CameraPanel.Camera;
            if ~strcmp(camera.State, 'Ready'), return; end
            ref = obj.Fiducial.reference;
            refBinning = 1;
            if isfield(ref, 'binning') && ~isempty(ref.binning), refBinning = ref.binning; end
            refRoi = [];
            if isfield(ref, 'roi'), refRoi = double(ref.roi); end
            if isempty(refRoi), refRoi = [0 0 size(ref.frame, 2) size(ref.frame, 1)]; end
            if camera.Binning ~= refBinning || ~isequal(double(camera.Roi), refRoi)
                same = false;
                why = sprintf(['The reference was saved at subarray %s, binning %d; the camera ' ...
                    'is at %s, binning %d. Set the camera panel to the reference''s to align.'], ...
                    mat2str(refRoi), refBinning, mat2str(double(camera.Roi)), camera.Binning);
            end
        end

        function [can, why] = canGoToReference(obj)
            can = false;
            target = obj.referenceXY();
            if ~obj.Options.stagesConfigured
                why = 'Needs zaber.axes (x, y, z, each with safe_um) in luminose_config.yaml.';
            elseif isempty(obj.Fiducial)
                why = 'Save this animal''s reference first.';
            elseif isempty(target)
                why = 'No stage position saved with this animal''s fiducials: press Read before Save fiducial.';
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
                    error('PatternDesigner:outsideLimits', ['%s %.0f um is outside its ' ...
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
            um = obj.stagePositions();
            if isempty(um) || obj.Closing, return; end
            obj.LastStageUm = um;
            obj.Controls.StageReadout.String = sprintf('X %.1f   Y %.1f   Z %.1f um', um);
        end

        function ok = ensureStages(obj)
            % X, Y and Z, connected (again, if a panel disconnected them).
            ok = (~isempty(obj.Stages) && all(cellfun(@(n) strcmp(obj.Stages.(n).State, ...
                'Ready'), {'x', 'y', 'z'}))) || obj.guard(@() obj.connectStages());
        end

        function connectStages(obj)
            obj.Stages = obj.Options.makeStages();
        end

        function um = stagePositions(obj)
            um = [];
            if isempty(obj.Stages), return; end
            try
                um = [obj.Stages.x.positionUm(), obj.Stages.y.positionUm(), obj.Stages.z.positionUm()];
            catch
            end
        end

        function box = dmdFieldBox(obj)
            % The DMD field's bounding box in the camera's frame px, [x y w h], within
            % the frame: what alignment registers on.
            corners = obj.dmdToFrame([0.5 0.5; obj.DMD_W + 0.5 0.5; ...
                obj.DMD_W + 0.5 obj.DMD_H + 0.5; 0.5 obj.DMD_H + 0.5]);
            frameSize = double(obj.CameraPanel.Camera.Roi(3:4));  % [width height]
            lo = max(floor(min(corners)), 1);
            hi = min(ceil(max(corners)), frameSize);
            box = [lo, hi - lo];
        end

        function onAlignProgress(obj, info)
            % Each alignment frame on the camera panel, and where it has got to.
            if obj.Closing, return; end
            if obj.cameraAttached()
                obj.CameraPanel.showFrame(info.frame);
            end
            obj.Controls.AlignInfo.String = sprintf('%s %d: %.1f um off, rotation %.2f deg, peak %.2f', ...
                info.step, info.iteration, info.residualUm, info.rotationDeg, info.peak);
            drawnow;  % shows it, and lets Stop through
        end

        function file = fiducialFile(obj)
            file = '';
            try
                file = lhf.cam.fiducialFile(obj.Options.calibrationFolder, obj.Controls.Animal.String);
            catch err
                obj.showError(err.message);
            end
        end

        function useAnimalFolder(obj)
            % The camera saves this animal's images in <data>/<animal>/luminose_hf_widefield
            % (the data folder holds the calibration folder).
            if obj.cameraAttached() && isprop(obj.CameraPanel, 'SaveFolder')
                lhf.cam.useSubjectFolder(obj.Controls.Animal.String, obj.CameraPanel, ...
                    fileparts(char(obj.Options.calibrationFolder)));
            end
        end

        function loadAnimal(obj)
            obj.Fiducial = [];
            obj.MarkXY = [];
            obj.Targets = [];
            obj.TargetsFile = [];
            obj.TargetTransform = [];
            obj.TargetsDirty = false;
            if obj.MarkingTargets, obj.setMarkTargets(false); end
            if ~isempty(strtrim(obj.Controls.Animal.String))
                file = obj.fiducialFile();
                if ~isempty(file)
                    obj.guard(@() obj.readFiducial(file));
                end
                file = obj.targetsFile();
                if ~isempty(file)
                    obj.guard(@() obj.readTargets(file));
                end
            end
            obj.syncTargetTable();
            obj.refresh();
        end

        function readTargets(obj, file)
            obj.TargetsFile = lhf.cam.loadTargets(file);
            if ~isempty(obj.TargetsFile)
                obj.Targets = obj.TargetsFile.list;
            end
        end

        function file = targetsFile(obj)
            file = '';
            try
                file = lhf.cam.targetsFile(obj.Options.calibrationFolder, obj.Controls.Animal.String);
            catch err
                obj.showError(err.message);
            end
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
            if obj.Options.visible && ~obj.Closing
                warndlg(message, 'Pattern Designer');
            end
        end
    end
end


function options = withDefaults(options)
% The options not given, from the rig's config.
    global luminose %#ok<GVMIS> the protocols' global (CLAUDE.md, Global variables)
    if ~isfield(options, 'luminose'), options.luminose = luminose; end
    rig = options.luminose;
    if ~isfield(options, 'calibrationFolder')
        options.calibrationFolder = fullfile(char(rig.f.luminoseData), 'calibration');
    end
    if ~isfield(options, 'registration'), options.registration = []; end
    if ~isfield(options, 'openCamera'), options.openCamera = @() lhf.devicePanel('camera'); end
    if ~isfield(options, 'openPanel'), options.openPanel = @(name) lhf.devicePanel(name); end
    if ~isfield(options, 'makeDmd'), options.makeDmd = @() lhf.device('dmd', 'connect'); end
    if ~isfield(options, 'dmdAllowed'), options.dmdAllowed = @() ~sessionRunning(); end
    if ~isfield(options, 'stageCalibration'), options.stageCalibration = []; end
    if ~isfield(options, 'makeStages'), options.makeStages = @() rigStages(rig); end
    if ~isfield(options, 'stagesConfigured')
        options.stagesConfigured = false;
        try
            stageAxes = rig.zaber.axes;
            options.stagesConfigured = all(isfield(stageAxes, {'x', 'y', 'z'})) ...
                && all(cellfun(@(n) isfield(stageAxes.(n), 'safe_um'), {'x', 'y', 'z'}));
        catch
        end
    end
    if ~isfield(options, 'alignment')
        try
            options.alignment = rig.zaber.alignment;
        catch
            options.alignment = LuminoseConstants.alignmentDefaults();
        end
    end
    if ~isfield(options, 'confirm'), options.confirm = @confirmFirstMove; end
    if ~isfield(options, 'confirmGoTo'), options.confirmGoTo = @confirmGoTo; end
    if ~isfield(options, 'confirmBlank'), options.confirmBlank = @confirmBlank; end
    if ~isfield(options, 'confirmTargets'), options.confirmTargets = @confirmTargets; end
    if ~isfield(options, 'animal'), options.animal = lhf.subjectName(); end
    if ~isfield(options, 'visible'), options.visible = true; end
end

function go = confirmFirstMove(info)
    answer = questdlg(sprintf(['Align to the reference: move the stage X %+.0f um, Y %+.0f um, ' ...
        'then search Z +/- %g um and refine X/Y?'], info.moveUm, info.zSearchUm), ...
        'Align to reference', 'Move', 'Cancel', 'Cancel');
    go = strcmp(answer, 'Move');
end

function go = confirmGoTo(info)
    answer = questdlg(sprintf(['Move the stage to the %s''s X/Y: X %+.0f um, Y %+.0f um? ' ...
        'Z stays where it is.'], info.source, info.moveUm), 'Go to reference X/Y', ...
        'Move', 'Cancel', 'Cancel');
    go = strcmp(answer, 'Move');
end

function go = confirmTargets(question)
    go = strcmp(questdlg(question, 'Targets', 'Yes', 'No', 'Yes'), 'Yes');
end

function go = confirmBlank(tickMs)
    answer = questdlg(sprintf(['No spots placed. Save a blank pattern? It shows nothing ' ...
        '(no DMD sequence, no laser) and the stimulus lasts the Tick, %g ms.'], tickMs), ...
        'Blank pattern', 'Save blank', 'Cancel', 'Cancel');
    go = strcmp(answer, 'Save blank');
end

function running = sessionRunning()
% After START the protocol's DMDPatternPlayer owns the DMD.
    global BpodSystem %#ok<GVMIS> Bpod's
    running = false;
    try
        running = logical(getappdata(BpodSystem.ProtocolFigures.ParameterGUI, 'StartPressed'));
    catch
    end
end

function spots = emptySpots()
    spots = struct('x', {}, 'y', {}, 'onset_ms', {}, 'dur_ms', {}, 'isFixed', {});
end

function [spots, tickMs, meta] = tryLoadMetaForRow(patternsFolder, patternType, rowIdx)
% The newest saved design for the row; meta: its r_px and laser options, where saved.
    spots = emptySpots();
    tickMs = [];
    meta = struct();
    patternsFolder = char(patternsFolder);
    metas = dir(fullfile(patternsFolder, sprintf('designed_%s_r%d_*_meta.mat', patternType, rowIdx)));
    if isempty(metas) && rowIdx == 1
        allMetas = dir(fullfile(patternsFolder, sprintf('designed_%s_*_meta.mat', patternType)));
        metas = allMetas(arrayfun(@(m) isempty(regexp(m.name, ...
            sprintf('designed_%s_r\\d+_', patternType), 'once')), allMetas));
    end
    if isempty(metas), return; end
    [~, newest] = max([metas.datenum]);
    try
        m = load(fullfile(patternsFolder, metas(newest).name));
        for i = 1:numel(m.spots)
            if ~isfield(m.spots(i), 'isFixed'), m.spots(i).isFixed = true; end
        end
        spots = m.spots;
        if isfield(m, 'tickMs'), tickMs = m.tickMs; end
        if isfield(m, 'r_px'), meta.r_px = m.r_px; end
        if isfield(m, 'laserIrradiances_mWmm2')
            meta.laserIrradiances_mWmm2 = m.laserIrradiances_mWmm2;
            meta.laserWeights = m.laserWeights;
        end
    catch
    end
end

function [on, laser] = laserOptionsFor(S, patternType)
% Whether the protocol wants laser power per pattern for this type, and its defaults.
    on = false;
    laser = struct('irradiances', [], 'weights', []);
    selector = ['patternSel_' patternType];
    if ~(isstruct(S) && isfield(S, 'GUIMeta') && isfield(S.GUIMeta, selector)), return; end
    meta = S.GUIMeta.(selector);
    if ~(isfield(meta, 'LaserOptions') && meta.LaserOptions), return; end
    on = true;
    laser.irradiances = meta.LaserDefaults.irradiances;
    laser.weights = meta.LaserDefaults.weights;
end

function rows = laserRows(irradiances, weights)
% The laser table's rows: irradiance, probability
    if numel(weights) ~= numel(irradiances), weights = ones(size(irradiances)); end
    rows = [num2cell(irradiances(:)), num2cell(weights(:))];
    if isempty(rows), rows = {[], 1}; end
    rows = normalizeLaserProbs(rows);
end

function rows = normalizeLaserProbs(rows)
% Probabilities summing to 1 (all 0: equal), as the pattern table's Prob
    p = cellfun(@cellNumber, rows(:, 2));
    p(isnan(p) | p < 0) = 0;
    if sum(p) == 0, p = ones(size(p)); end
    p = p / sum(p);
    for k = 1:size(rows, 1), rows{k, 2} = round(p(k), 4); end
end

function v = cellNumber(c)
% A table cell as a number (NaN when empty)
    if isempty(c), v = NaN;
    elseif ischar(c) || isstring(c), v = str2double(c);
    else, v = double(c);
    end
end

function text = calibratedRangeText(luminose)
% The irradiances the power calibration covers, for the laser table
    try
        irr = irradianceCalibration(luminose);
        text = sprintf('Calibrated range: %.2f - %.2f mW/mm2', min(irr), max(irr));
    catch
        text = 'No power calibration found (dmd/power_calibration.csv)';
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

function s = onOff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end

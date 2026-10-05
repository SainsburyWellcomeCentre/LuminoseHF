function PatternDesignerGUI(patternType, rowIdx, preloadFromType)
% PatternDesignerGUI  Interactive DMD spot-pattern designer.
%
%   PatternDesignerGUI(patternType, rowIdx)
%   rowIdx defaults to 1 if omitted.
%
%   Two placement modes (toggle at top of control panel):
%     Free Placement — left-click canvas to place; right-click to remove nearest
%     Grid Select    — canvas shows non-overlapping grid; click any cell to toggle it
%
%   Overlap rule: Chebyshev distance > 2*r_px enforced in both modes and at
%   runtime.  In Grid mode overlap is impossible by construction.
%
%   Fill Left/Right Half: switches to Grid mode and selects every cell in
%     that half of the DMD field in one click (replaces current selection).
%   Fill Checkerboard A/B: switches to Grid mode and selects a sparse
%     lattice of cells (same grid cell size as Fill Left/Right Half) spaced
%     3 grid cells apart in both row and column, across the full DMD field.
%     A and B use lattices offset from each other so their spots sit in the
%     gaps between each other's spots (not adjacent) — pairing them (e.g.
%     Checkerboard A on the "Left" pattern, Checkerboard B on the "Right"
%     pattern) gives two interleaved, well-separated spot grids.
%   Overlay panel: load any other saved pattern type as a visual reference.
%   Delete Spot #N: remove a single spot by its number.
%   Clear All: remove all spots.
%   Save Pattern: write to BpodSystem and disk.

    if nargin < 2 || isempty(rowIdx), rowIdx = 1; end
    if nargin < 3, preloadFromType = ''; end

    if strcmp(patternType, 'opto') && isempty(preloadFromType)
        optoPatternDesignerUI(rowIdx);
        return;
    end

    global S luminose BpodSystem

    % ---------------------------------------------------------------
    % Constants
    % ---------------------------------------------------------------
    DMD_W = 1024;
    DMD_H = 768;
    SCALE = 2;
    CAN_W = DMD_W / SCALE;   % 512
    CAN_H = DMD_H / SCALE;   % 384

    % Spot size: set here (Spot side box) and saved with the design as r_px.
    % A design opens at its own size; a new one at the rig default
    % (luminose.dmd.spotSide). applySpotSide sets r_px and the grid from it.
    spotSide = luminose.dmd.spotSide;
    r_px = 1; r_disp = 1;
    gridCellSize = 4; gridCols = 1; gridRows = 1; gridOffX = 0; gridOffY = 0;
    applySpotSide(spotSide);

    SPOT_COLORS = [ ...
        0.2  0.6  1.0; ...
        1.0  0.4  0.2; ...
        0.3  0.85 0.3; ...
        1.0  0.9  0.1; ...
        0.8  0.2  0.8; ...
        0.1  0.9  0.9; ...
        1.0  0.5  0.7; ...
        0.6  0.4  1.0];

    % --- Background image ---
    dmdFolder = fileparts(char(luminose.dmd.patternsFolder));
    bgFile    = fullfile(dmdFolder, 'canvas_background.png');
    bgImage   = loadOrGenerateBG(bgFile, CAN_W, CAN_H);

    % ---------------------------------------------------------------
    % State
    % ---------------------------------------------------------------
    spots        = struct('x',{},'y',{},'onset_ms',{},'dur_ms',{},'isFixed',{});
    overlaySpots = struct('x',{},'y',{},'onset_ms',{},'dur_ms',{},'isFixed',{});
    gridSelected = false(gridRows, gridCols);
    mode         = 'free';   % 'free' | 'grid'
    loadedTickMs = [];
    % Laser power per pattern: shown only when the protocol declares
    % S.GUIMeta.patternSel_<type>.LaserOptions (powercal's CS+ and CS-)
    [laserOn, laser] = laserOptionsFor(S, patternType);

    % Load existing design — preloadFromType overrides to borrow another type's spots
    loadType = patternType;
    loadRow  = rowIdx;
    if ~isempty(preloadFromType)
        loadType = preloadFromType;
        loadRow  = 1;
    end
    if isfield(BpodSystem, 'PluginObjects') && ...
       isfield(BpodSystem.PluginObjects, 'PatternDesigns') && ...
       isfield(BpodSystem.PluginObjects.PatternDesigns, loadType) && ...
       numel(BpodSystem.PluginObjects.PatternDesigns.(loadType)) >= loadRow && ...
       ~isempty(BpodSystem.PluginObjects.PatternDesigns.(loadType){loadRow}) && ...
       isfield(BpodSystem.PluginObjects.PatternDesigns.(loadType){loadRow}, 'spots')
        d            = BpodSystem.PluginObjects.PatternDesigns.(loadType){loadRow};
        spots        = d.spots;
        loadedTickMs = d.tickMs;
        loadedMeta   = d;
    else
        [spots, loadedTickMs, loadedMeta] = tryLoadMetaForRow(lhf.patternFolder(luminose.dmd, loadType), lhf.patternFileType(luminose.dmd, loadType), loadRow);
    end
    if laserOn && isfield(loadedMeta, 'laserIrradiances_mWmm2') && ~isempty(loadedMeta.laserIrradiances_mWmm2)
        laser.irradiances = loadedMeta.laserIrradiances_mWmm2;
        laser.weights = loadedMeta.laserWeights;
    end
    if ~isempty(spots) && isfield(loadedMeta, 'r_px')
        applySpotSide(loadedMeta.r_px * 2 * luminose.dmd.projectedDMDlength / DMD_W);  % the design's own size
    end
    gridSelected = spotsToGrid(spots);

    % ---------------------------------------------------------------
    % Figure  (760 px tall to fit all controls)
    % ---------------------------------------------------------------
    fig = figure('Name', sprintf('Pattern Designer — %s  (row %d)', patternType, rowIdx), ...
        'NumberTitle', 'off', 'MenuBar', 'none', 'Resize', 'off', ...
        'Position', [80 80 1130 760], ...
        'Color', [0.13 0.13 0.15], ...
        'CloseRequestFcn', @onClose);

    % --- Canvas (left column) ---
    axCanvas = axes('Parent', fig, ...
        'Units', 'pixels', 'Position', [15 180 CAN_W CAN_H], ...
        'XColor', 'none', 'YColor', 'none', ...
        'XLim', [0 CAN_W], 'YLim', [0 CAN_H], 'YDir', 'reverse', ...
        'NextPlot', 'replacechildren', 'PickableParts', 'all', 'HitTest', 'on', ...
        'ButtonDownFcn', @onCanvasClick);

    % Tick (ms) and spot-size info above the canvas
    uicontrol(fig, 'Style', 'text', 'String', 'Tick (ms)', ...
        'Position', [15 588 70 22], 'FontSize', 10, ...
        'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.75 0.75 0.75], ...
        'HorizontalAlignment', 'left');
    hTickMs = uicontrol(fig, 'Style', 'edit', 'String', '10', ...
        'Position', [90 588 45 24], 'FontSize', 11, ...
        'BackgroundColor', [0.22 0.22 0.25], 'ForegroundColor', [1 1 1]);
    uicontrol(fig, 'Style', 'text', 'String', 'ms per frame', ...
        'Position', [142 588 120 22], 'FontSize', 9, ...
        'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.5 0.5 0.5], ...
        'HorizontalAlignment', 'left');
    uicontrol(fig, 'Style', 'text', 'String', 'Spot side (mm)', ...
        'Position', [15 562 100 22], 'FontSize', 10, ...
        'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.75 0.75 0.75], ...
        'HorizontalAlignment', 'left');
    hSpotSide = uicontrol(fig, 'Style', 'edit', 'String', sprintf('%.3g', spotSide), ...
        'Position', [118 562 55 24], 'FontSize', 11, ...
        'BackgroundColor', [0.22 0.22 0.25], 'ForegroundColor', [1 1 1], ...
        'Callback', @onSpotSide);
    hSpotInfo = uicontrol(fig, 'Style', 'text', 'String', '', ...
        'Position', [180 562 CAN_W-165 22], 'FontSize', 9, ...
        'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.5 0.5 0.5], ...
        'HorizontalAlignment', 'left');
    updateSpotInfo();

    % --- Laser power for this pattern (below the canvas) ---
    hLaserIrr = [];
    hLaserW = [];
    if laserOn
        uicontrol(fig, 'Style', 'text', 'String', 'LASER POWER (this pattern)', ...
            'Position', [15 146 CAN_W 22], 'FontSize', 10, 'FontWeight', 'bold', ...
            'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.8 0.8 0.8], ...
            'HorizontalAlignment', 'left');
        uicontrol(fig, 'Style', 'text', 'String', 'Irradiance (mW/mm2)', ...
            'Position', [15 114 150 22], 'FontSize', 10, ...
            'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.75 0.75 0.75], ...
            'HorizontalAlignment', 'left');
        hLaserIrr = uicontrol(fig, 'Style', 'edit', 'String', mat2str(laser.irradiances), ...
            'Position', [170 114 300 24], 'FontSize', 11, ...
            'BackgroundColor', [0.22 0.22 0.25], 'ForegroundColor', [1 1 1]);
        uicontrol(fig, 'Style', 'text', 'String', 'Draw weights', ...
            'Position', [15 82 150 22], 'FontSize', 10, ...
            'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.75 0.75 0.75], ...
            'HorizontalAlignment', 'left');
        hLaserW = uicontrol(fig, 'Style', 'edit', 'String', mat2str(laser.weights), ...
            'Position', [170 82 300 24], 'FontSize', 11, ...
            'BackgroundColor', [0.22 0.22 0.25], 'ForegroundColor', [1 1 1]);
        uicontrol(fig, 'Style', 'text', ...
            'String', 'Each trial showing this pattern draws one irradiance (weighted). Must be within the power calibration.', ...
            'Position', [15 40 CAN_W 34], 'FontSize', 8, ...
            'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.5 0.5 0.5], ...
            'HorizontalAlignment', 'left');
    end

    % ---------------------------------------------------------------
    % Control panel (right column)
    % ---------------------------------------------------------------
    PX = CAN_W + 25;   % 537
    PW = 465;

    % --- Mode toggle ---
    uicontrol(fig, 'Style', 'text', 'String', 'MODE', ...
        'Position', [PX 724 PW 22], 'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.8 0.8 0.8], ...
        'HorizontalAlignment', 'left');
    hModeFree = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Free Placement', ...
        'Position', [PX 692 224 28], 'FontSize', 10, ...
        'Callback', @(~,~) setMode('free'));
    hModeGrid = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Grid Select', ...
        'Position', [PX+232 692 225 28], 'FontSize', 10, ...
        'Callback', @(~,~) setMode('grid'));

    % --- Quick fill (Grid mode: select all cells in the left/right half, or
    %     every other cell in a full-field checkerboard) ---
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Left Half', ...
        'Position', [PX 650 112 28], 'FontSize', 9, ...
        'BackgroundColor', [0.25 0.25 0.3], 'ForegroundColor', [1 1 1], ...
        'Callback', @(~,~) onFillHalf('left'));
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Right Half', ...
        'Position', [PX+117 650 112 28], 'FontSize', 9, ...
        'BackgroundColor', [0.25 0.25 0.3], 'ForegroundColor', [1 1 1], ...
        'Callback', @(~,~) onFillHalf('right'));
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Checker A', ...
        'Position', [PX+234 650 112 28], 'FontSize', 9, ...
        'BackgroundColor', [0.25 0.25 0.3], 'ForegroundColor', [1 1 1], ...
        'Callback', @(~,~) onFillCheckerboard(0, 0));
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Checker B', ...
        'Position', [PX+351 650 114 28], 'FontSize', 9, ...
        'BackgroundColor', [0.25 0.25 0.3], 'ForegroundColor', [1 1 1], ...
        'Callback', @(~,~) onFillCheckerboard(1, 1));

    % --- Placement controls ---
    uicontrol(fig, 'Style', 'text', 'String', 'PLACEMENT', ...
        'Position', [PX 618 PW 22], 'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.8 0.8 0.8], ...
        'HorizontalAlignment', 'left');

    uicontrol(fig, 'Style', 'text', 'String', 'nSpots', ...
        'Position', [PX 588 70 22], 'FontSize', 10, ...
        'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.75 0.75 0.75], ...
        'HorizontalAlignment', 'left');
    hNSpots = uicontrol(fig, 'Style', 'edit', 'String', '3', ...
        'Position', [PX+75 588 45 24], 'FontSize', 11, ...
        'BackgroundColor', [0.22 0.22 0.25], 'ForegroundColor', [1 1 1]);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Randomize', ...
        'Position', [PX+130 586 155 28], 'FontSize', 10, ...
        'BackgroundColor', [0.2 0.45 0.7], 'ForegroundColor', [1 1 1], ...
        'Callback', @onRandomize);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Clear All', ...
        'Position', [PX+295 586 152 28], 'FontSize', 10, ...
        'BackgroundColor', [0.5 0.2 0.2], 'ForegroundColor', [1 1 1], ...
        'Callback', @onClearAll);

    % --- Overlay ---
    allTypes      = {'cue', 'CSplus', 'CSminus', 'opto'};
    overlayOptions = [{'(none)'}, allTypes(~strcmp(allTypes, patternType))];
    uicontrol(fig, 'Style', 'text', 'String', 'Overlay:', ...
        'Position', [PX 556 58 22], 'FontSize', 10, ...
        'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.75 0.75 0.75], ...
        'HorizontalAlignment', 'left');
    hOverlayPopup = uicontrol(fig, 'Style', 'popupmenu', 'String', overlayOptions, ...
        'Position', [PX+65 554 160 26], 'FontSize', 10, ...
        'BackgroundColor', [0.22 0.22 0.25], 'ForegroundColor', [1 1 1], ...
        'Callback', @onOverlayChange);
    uicontrol(fig, 'Style', 'text', 'String', '← reference layer (amber); overlap allowed', ...
        'Position', [PX+232 556 220 22], 'FontSize', 8, ...
        'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.45 0.45 0.45], ...
        'HorizontalAlignment', 'left');

    % --- Spots table ---
    uicontrol(fig, 'Style', 'text', 'String', 'SPOTS', ...
        'Position', [PX 524 PW 22], 'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.8 0.8 0.8], ...
        'HorizontalAlignment', 'left');

    hTable = uitable(fig, ...
        'Position', [PX 290 PW 228], ...
        'ColumnName', {'#', 'X (px)', 'Y (px)', 'Onset (ms)', 'Dur (ms)', 'Type'}, ...
        'ColumnWidth', {28, 68, 68, 82, 68, 90}, ...
        'ColumnEditable', [false true true true true true], ...
        'ColumnFormat', {'numeric','numeric','numeric','numeric','numeric',{'Fixed','Random'}}, ...
        'Data', {}, ...
        'FontSize', 11, ...
        'BackgroundColor', [0.2 0.2 0.22; 0.17 0.17 0.19], ...
        'ForegroundColor', [0.9 0.9 0.9], ...
        'CellEditCallback', @onTableEdit);

    % --- Delete one spot ---
    uicontrol(fig, 'Style', 'text', 'String', 'Delete spot #', ...
        'Position', [PX 258 92 22], 'FontSize', 10, ...
        'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.75 0.75 0.75], ...
        'HorizontalAlignment', 'left');
    hDeleteIdx = uicontrol(fig, 'Style', 'edit', 'String', '1', ...
        'Position', [PX+97 258 40 24], 'FontSize', 11, ...
        'BackgroundColor', [0.22 0.22 0.25], 'ForegroundColor', [1 1 1]);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Delete', ...
        'Position', [PX+145 256 80 28], 'FontSize', 10, ...
        'BackgroundColor', [0.45 0.22 0.22], 'ForegroundColor', [1 1 1], ...
        'Callback', @onDeleteOne);

    % --- Timeline ---
    uicontrol(fig, 'Style', 'text', 'String', 'TIMELINE', ...
        'Position', [PX 226 PW 22], 'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.13 0.13 0.15], 'ForegroundColor', [0.8 0.8 0.8], ...
        'HorizontalAlignment', 'left');

    axTimeline = axes('Parent', fig, ...
        'Units', 'pixels', 'Position', [PX 110 PW 110], ...
        'Color', [0.16 0.16 0.18], 'XColor', [0.6 0.6 0.6], 'YColor', 'none', ...
        'NextPlot', 'replacechildren', 'FontSize', 9);
    xlabel(axTimeline, 'Time (ms)', 'Color', [0.6 0.6 0.6], 'FontSize', 9);

    % --- Save / Cancel ---
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Save Pattern', ...
        'Position', [PX 15 215 50], 'FontSize', 14, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.15 0.55 0.25], 'ForegroundColor', [1 1 0.4], ...
        'Callback', @onSave);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Cancel', ...
        'Position', [PX+235 15 210 50], 'FontSize', 14, ...
        'BackgroundColor', [0.35 0.35 0.38], 'ForegroundColor', [0.9 0.9 0.9], ...
        'Callback', @(~,~) delete(fig));

    % --- Initial state ---
    if ~isempty(loadedTickMs)
        set(hTickMs, 'String', num2str(loadedTickMs));
    else
        updateDefaultTick();
    end
    updateModeButtons();
    refreshCanvas();
    refreshTimeline();
    syncTableFromSpots();

    % ===================================================================
    % Callbacks
    % ===================================================================

    function onCanvasClick(~, ~)
        pt   = axCanvas.CurrentPoint(1, 1:2);
        xDsp = pt(1);  yDsp = pt(2);
        xDMD = round(xDsp * SCALE);
        yDMD = round(yDsp * SCALE);

        if strcmp(mode, 'grid')
            col = floor((xDMD - gridOffX) / gridCellSize) + 1;
            row = floor((yDMD - gridOffY) / gridCellSize) + 1;
            if col < 1 || col > gridCols || row < 1 || row > gridRows, return; end
            gridSelected(row, col) = ~gridSelected(row, col);
            syncSpotsFromGrid();
        else
            if strcmp(get(fig, 'SelectionType'), 'normal')
                nMax = round(str2double(get(hNSpots, 'String')));
                if isnan(nMax) || nMax < 1, nMax = 3; end
                if numel(spots) >= nMax, return; end
                xDMD = max(1, min(DMD_W, xDMD));
                yDMD = max(1, min(DMD_H, yDMD));
                if anyOverlapWith(xDMD, yDMD, spots), return; end
                newSpot.x = xDMD;  newSpot.y = yDMD;
                newSpot.onset_ms = 0;  newSpot.dur_ms = 200;  newSpot.isFixed = true;
                spots(end+1) = newSpot;
            else
                removeNearestSpot(xDsp, yDsp);
            end
        end
        syncTableFromSpots();
        refreshCanvas();
        refreshTimeline();
        updateDefaultTick();
    end

    function onTableEdit(~, ev)
        r   = ev.Indices(1);
        c   = ev.Indices(2);
        val = ev.NewData;
        switch c
            case 2
                if isnumeric(val) && ~isnan(val)
                    newX = round(max(1, min(DMD_W, val)));
                    oldX = spots(r).x;
                    spots(r).x = newX;
                    if anyOverlapWithExcluding(newX, spots(r).y, spots, r)
                        spots(r).x = oldX;
                        warndlg(sprintf('Spot %d would overlap another — reverted.', r), 'Overlap');
                    end
                end
            case 3
                if isnumeric(val) && ~isnan(val)
                    newY = round(max(1, min(DMD_H, val)));
                    oldY = spots(r).y;
                    spots(r).y = newY;
                    if anyOverlapWithExcluding(spots(r).x, newY, spots, r)
                        spots(r).y = oldY;
                        warndlg(sprintf('Spot %d would overlap another — reverted.', r), 'Overlap');
                    end
                end
            case 4
                if isnumeric(val) && ~isnan(val)
                    spots(r).onset_ms = max(0, val);
                end
            case 5
                if isnumeric(val) && ~isnan(val)
                    spots(r).dur_ms = max(1, val);
                end
            case 6
                if strcmp(mode, 'free')
                    spots(r).isFixed = strcmp(val, 'Fixed');
                end
        end
        if strcmp(mode, 'grid')
            gridSelected = spotsToGrid(spots);
        end
        syncTableFromSpots();
        refreshCanvas();
        refreshTimeline();
        updateDefaultTick();
    end

    function onRandomize(~, ~)
        n = round(str2double(get(hNSpots, 'String')));
        if isnan(n) || n < 1, n = 3; end

        if strcmp(mode, 'grid')
            % Pick n random cells, replacing current selection
            [freeR, freeC] = find(true(gridRows, gridCols));   % all cells available
            nAll = numel(freeR);
            n    = min(n, nAll);
            perm = randperm(nAll, n);
            gridSelected = false(gridRows, gridCols);
            for i = 1:n
                gridSelected(freeR(perm(i)), freeC(perm(i))) = true;
            end
            syncSpotsFromGrid();
        else
            margin = r_px + 1;
            placed = struct('x',{},'y',{},'onset_ms',{},'dur_ms',{},'isFixed',{});
            for i = 1:n
                for attempt = 1:1000
                    xt = randi([margin, DMD_W - margin]);
                    yt = randi([margin, DMD_H - margin]);
                    if ~anyOverlapWith(xt, yt, placed)
                        s.x = xt;  s.y = yt;
                        s.onset_ms = 0;  s.dur_ms = 200;  s.isFixed = true;
                        placed(end+1) = s; %#ok<AGROW>
                        break;
                    end
                end
            end
            spots = placed;
        end
        syncTableFromSpots();
        refreshCanvas();
        refreshTimeline();
        updateDefaultTick();
    end

    function onClearAll(~, ~)
        spots        = struct('x',{},'y',{},'onset_ms',{},'dur_ms',{},'isFixed',{});
        gridSelected = false(gridRows, gridCols);
        set(hTable, 'Data', {});
        refreshCanvas();
        refreshTimeline();
    end

    function onFillHalf(side)
        % Select every grid cell in the left or right half of the DMD field,
        % replacing the current selection — a quick way to build a
        % full-height half-field block without clicking every cell.
        setMode('grid');
        half = floor(gridCols / 2);
        gridSelected = false(gridRows, gridCols);
        if strcmp(side, 'left')
            gridSelected(:, 1:half) = true;
        else
            gridSelected(:, half+1:gridCols) = true;
        end
        syncSpotsFromGrid();
        syncTableFromSpots();
        refreshCanvas();
        refreshTimeline();
        updateDefaultTick();
    end

    function onFillCheckerboard(rowOffset, colOffset)
        % Select a sparse lattice of grid cells spaced LATTICE_SPACING cells
        % apart in both row and column, replacing the current selection.
        % rowOffset/colOffset shift the lattice; Checker A (0,0) and
        % Checker B (1,1) are offset so their cells fall in each other's
        % gaps rather than sitting adjacent.
        LATTICE_SPACING = 3;
        setMode('grid');
        [colGrid, rowGrid] = meshgrid(1:gridCols, 1:gridRows);
        gridSelected = mod(rowGrid - 1, LATTICE_SPACING) == rowOffset & ...
                       mod(colGrid - 1, LATTICE_SPACING) == colOffset;
        syncSpotsFromGrid();
        syncTableFromSpots();
        refreshCanvas();
        refreshTimeline();
        updateDefaultTick();
    end

    function onDeleteOne(~, ~)
        idx = round(str2double(get(hDeleteIdx, 'String')));
        if isnan(idx) || idx < 1 || idx > numel(spots)
            warndlg(sprintf('Enter a number between 1 and %d.', max(1,numel(spots))), 'Invalid');
            return;
        end
        spots(idx) = [];
        if strcmp(mode, 'grid')
            gridSelected = spotsToGrid(spots);
        end
        syncTableFromSpots();
        refreshCanvas();
        refreshTimeline();
        updateDefaultTick();
    end

    function onSpotSide(~, ~)
        mm = str2double(get(hSpotSide, 'String'));
        if isnan(mm) || mm <= 0
            set(hSpotSide, 'String', sprintf('%.3g', spotSide));
            return
        end
        applySpotSide(mm);
        if strcmp(mode, 'grid')
            gridSelected = spotsToGrid(spots);  % spots snap to the new grid's cells
            syncSpotsFromGrid();
            syncTableFromSpots();
        end
        updateSpotInfo();
        refreshCanvas();
        refreshTimeline();
    end

    function onOverlayChange(~, ~)
        overlaySpots = loadOverlay();
        refreshCanvas();
    end

    function setMode(newMode)
        if strcmp(newMode, mode), return; end
        if strcmp(newMode, 'grid')
            gridSelected = spotsToGrid(spots);
            syncSpotsFromGrid();   % snap spot coords to grid centres
            % Disable X/Y editing in grid mode (positions are grid-determined)
            set(hTable, 'ColumnEditable', [false false false true true true]);
        else
            set(hTable, 'ColumnEditable', [false true true true true true]);
        end
        mode = newMode;
        updateModeButtons();
        syncTableFromSpots();
        refreshCanvas();
        refreshTimeline();
        updateDefaultTick();
    end

    function updateModeButtons()
        activeCol   = [0.22 0.50 0.82];
        inactiveCol = [0.25 0.25 0.28];
        activeFG    = [1 1 1];
        inactiveFG  = [0.65 0.65 0.65];
        if strcmp(mode, 'free')
            set(hModeFree, 'BackgroundColor', activeCol,   'ForegroundColor', activeFG);
            set(hModeGrid, 'BackgroundColor', inactiveCol, 'ForegroundColor', inactiveFG);
        else
            set(hModeFree, 'BackgroundColor', inactiveCol, 'ForegroundColor', inactiveFG);
            set(hModeGrid, 'BackgroundColor', activeCol,   'ForegroundColor', activeFG);
        end
    end

    function onSave(~, ~)
        if isempty(spots)
            msgbox('Place at least one spot before saving.', 'No spots', 'warn');
            return
        end
        if any([spots.dur_ms] <= 0)
            msgbox('All spots must have Duration > 0.', 'Invalid duration', 'warn');
            return
        end
        tickMs = str2double(get(hTickMs, 'String'));
        if isnan(tickMs) || tickMs <= 0
            msgbox('Tick (ms) must be a positive number.', 'Invalid tick', 'warn');
            return
        end
        totalDur = max([spots.onset_ms] + [spots.dur_ms]);
        nF       = ceil(totalDur / tickMs);

        laserIrradiances_mWmm2 = [];
        laserWeights = [];
        if laserOn
            laserIrradiances_mWmm2 = str2num(get(hLaserIrr, 'String')); %#ok<ST2NM> accepts [2 5 8]
            laserWeights = str2num(get(hLaserW, 'String')); %#ok<ST2NM>
            if isempty(laserWeights), laserWeights = ones(size(laserIrradiances_mWmm2)); end
            if isempty(laserIrradiances_mWmm2) || any(laserIrradiances_mWmm2 <= 0)
                msgbox('Irradiance must be one or more positive values, e.g. [2 5 8].', 'Invalid laser power', 'warn');
                return
            end
            if numel(laserWeights) ~= numel(laserIrradiances_mWmm2) || any(laserWeights < 0) || sum(laserWeights) == 0
                msgbox('Give one non-negative draw weight per irradiance (not all zero).', 'Invalid weights', 'warn');
                return
            end
            try
                irradianceToSetpoint_mW(laserIrradiances_mWmm2, luminose);  % every value within the calibration
            catch err
                msgbox(err.message, 'Laser power out of calibration', 'warn');
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
        design = struct('spots', spots, 'tickMs', tickMs, 'r_px', r_px, 'nF', nF);
        if laserOn
            design.laserIrradiances_mWmm2 = laserIrradiances_mWmm2;
            design.laserWeights = laserWeights;
        end
        BpodSystem.PluginObjects.PatternDesigns.(patternType){rowIdx} = design;

        patternsFolder = lhf.patternFolder(luminose.dmd, patternType);
        if ~exist(patternsFolder, 'dir'), mkdir(patternsFolder); end
        timestamp = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<TNOW1,DATST>
        fileType  = lhf.patternFileType(luminose.dmd, patternType);  % a protocol may save the type under its own name
        prefix    = sprintf('designed_%s_r%d_%s', fileType, rowIdx, timestamp);
        metaFile  = fullfile(patternsFolder, sprintf('%s_meta.mat', prefix));
        if laserOn
            save(metaFile, 'spots', 'tickMs', 'r_px', 'nF', 'timestamp', 'prefix', ...
                'laserIrradiances_mWmm2', 'laserWeights');
        else
            save(metaFile, 'spots', 'tickMs', 'r_px', 'nF', 'timestamp', 'prefix');
        end

        if isfield(BpodSystem.GUIHandles.ParameterGUI, 'PatternSelectorTables') && ...
           isfield(BpodSystem.GUIHandles.ParameterGUI.PatternSelectorTables, patternType)
            ptable = BpodSystem.GUIHandles.ParameterGUI.PatternSelectorTables.(patternType);
            if ishandle(ptable)
                tdata = get(ptable, 'Data');
                while size(tdata,1) < rowIdx, tdata(end+1,:) = {0, 0, 1e6}; end
                tdata{rowIdx, 2} = numel(spots);
                tdata{rowIdx, 3} = tickMs * 1000;
                set(ptable, 'Data', tdata);
            end
        end

        nFVec  = S.GUI.(sprintf('patternNFrames_%s',  patternType));
        expVec = S.GUI.(sprintf('patternExposure_%s', patternType));
        if numel(nFVec)  < rowIdx, nFVec(rowIdx)  = 0; end
        if numel(expVec) < rowIdx, expVec(rowIdx) = 0; end
        nFVec(rowIdx)  = nF;
        expVec(rowIdx) = tickMs * 1000;
        S.GUI.(sprintf('patternNFrames_%s',  patternType)) = nFVec;
        S.GUI.(sprintf('patternExposure_%s', patternType)) = expVec;

        hasRandom = any(~[spots.isFixed]);
        typeStr   = 'all fixed';
        if hasRandom, typeStr = 'includes random spots'; end
        msgbox(sprintf('Row %d: %d frames, tick=%gms, %s.', rowIdx, nF, tickMs, typeStr), ...
            'Pattern saved', 'help');
        delete(fig);
    end

    function onClose(~, ~)
        delete(fig);
    end

    % ===================================================================
    % Internal helpers
    % ===================================================================

    function applySpotSide(mm)
        spotSide = mm;
        r_px   = max(round((spotSide / luminose.dmd.projectedDMDlength) * DMD_W / 2), 1);
        r_disp = max(floor(r_px / SCALE), 1);
        % Grid parameters — 1px gap between cells guarantees strict non-overlap
        gridCellSize = 2 * r_px + 2;
        gridCols     = floor(DMD_W / gridCellSize);
        gridRows     = floor(DMD_H / gridCellSize);
        gridOffX     = floor((DMD_W - gridCols * gridCellSize) / 2);
        gridOffY     = floor((DMD_H - gridRows * gridCellSize) / 2);
    end

    function updateSpotInfo()
        overlapping = false;
        for k = 1:numel(spots)
            if anyOverlapWithExcluding(spots(k).x, spots(k).y, spots, k), overlapping = true; break; end
        end
        if overlapping
            set(hSpotInfo, 'String', sprintf('half-width %d px — spots overlap at this size', r_px), ...
                'ForegroundColor', [1 0.6 0.2]);
        else
            set(hSpotInfo, 'String', sprintf('half-width %d px — solid=Fixed, dashed=Random', r_px), ...
                'ForegroundColor', [0.5 0.5 0.5]);
        end
    end

    function syncSpotsFromGrid()
        [rows, cols] = find(gridSelected);
        n = numel(rows);
        oldSpots = spots;
        newSpots = struct('x',{},'y',{},'onset_ms',{},'dur_ms',{},'isFixed',{});
        for i = 1:n
            cx = gridOffX + (cols(i)-1)*gridCellSize + r_px;
            cy = gridOffY + (rows(i)-1)*gridCellSize + r_px;
            % Preserve timing if this cell was already in spots
            onset_ms = 0;  dur_ms = 200;
            for j = 1:numel(oldSpots)
                if max(abs(oldSpots(j).x - cx), abs(oldSpots(j).y - cy)) <= r_px
                    onset_ms = oldSpots(j).onset_ms;
                    dur_ms   = oldSpots(j).dur_ms;
                    break;
                end
            end
            newSpots(i).x        = cx;
            newSpots(i).y        = cy;
            newSpots(i).onset_ms = onset_ms;
            newSpots(i).dur_ms   = dur_ms;
            newSpots(i).isFixed  = true;
        end
        spots = newSpots;
    end

    function gs = spotsToGrid(spotArray)
        gs = false(gridRows, gridCols);
        for i = 1:numel(spotArray)
            col = floor((spotArray(i).x - gridOffX) / gridCellSize) + 1;
            row = floor((spotArray(i).y - gridOffY) / gridCellSize) + 1;
            if col >= 1 && col <= gridCols && row >= 1 && row <= gridRows
                gs(row, col) = true;
            end
        end
    end

    function tf = anyOverlapWith(x, y, spotArray)
        tf = false;
        for k = 1:numel(spotArray)
            if max(abs(x - spotArray(k).x), abs(y - spotArray(k).y)) <= 2*r_px
                tf = true; return;
            end
        end
    end

    function tf = anyOverlapWithExcluding(x, y, spotArray, excludeIdx)
        tf = false;
        for k = 1:numel(spotArray)
            if k == excludeIdx, continue; end
            if max(abs(x - spotArray(k).x), abs(y - spotArray(k).y)) <= 2*r_px
                tf = true; return;
            end
        end
    end

    function ov = loadOverlay()
        ov  = struct('x',{},'y',{},'onset_ms',{},'dur_ms',{},'isFixed',{});
        idx = get(hOverlayPopup, 'Value');
        sel = overlayOptions{idx};
        if strcmp(sel, '(none)'), return; end
        if isfield(BpodSystem, 'PluginObjects') && ...
           isfield(BpodSystem.PluginObjects, 'PatternDesigns') && ...
           isfield(BpodSystem.PluginObjects.PatternDesigns, sel) && ...
           ~isempty(BpodSystem.PluginObjects.PatternDesigns.(sel)) && ...
           ~isempty(BpodSystem.PluginObjects.PatternDesigns.(sel){1})
            ov = BpodSystem.PluginObjects.PatternDesigns.(sel){1}.spots;
            return;
        end
        ov = tryLoadMetaForRow(lhf.patternFolder(luminose.dmd, sel), lhf.patternFileType(luminose.dmd, sel), 1);
    end

    function removeNearestSpot(xDsp, yDsp)
        if isempty(spots), return; end
        dists = sqrt(([spots.x]/SCALE - xDsp).^2 + ([spots.y]/SCALE - yDsp).^2);
        [minD, idx] = min(dists);
        if minD <= r_disp * 1.5
            spots(idx) = [];
        end
    end

    function syncTableFromSpots()
        n    = numel(spots);
        data = cell(n, 6);
        for i = 1:n
            data{i,1} = i;
            data{i,2} = spots(i).x;
            data{i,3} = spots(i).y;
            data{i,4} = spots(i).onset_ms;
            data{i,5} = spots(i).dur_ms;
            if spots(i).isFixed
                data{i,6} = 'Fixed';
            else
                data{i,6} = 'Random';
            end
        end
        set(hTable, 'Data', data);
    end

    function updateDefaultTick()
        if isempty(spots), return; end
        onsets = [spots.onset_ms];
        durs   = [spots.dur_ms];
        if numel(unique(onsets)) == 1 && numel(unique(durs)) == 1
            set(hTickMs, 'String', num2str(durs(1)));
        else
            set(hTickMs, 'String', '1');
        end
    end

    function refreshCanvas()
        cla(axCanvas);
        hImg = imagesc(axCanvas, [0 CAN_W], [0 CAN_H], bgImage);
        set(hImg, 'HitTest', 'off', 'PickableParts', 'none');
        colormap(axCanvas, gray);
        set(axCanvas, 'YDir', 'reverse', 'XLim', [0 CAN_W], 'YLim', [0 CAN_H], ...
            'XColor', 'none', 'YColor', 'none');
        hold(axCanvas, 'on');

        if strcmp(mode, 'grid')
            drawGrid();
        else
            drawFreeSpots();
        end

        set(axCanvas, 'NextPlot', 'replacechildren', 'ButtonDownFcn', @onCanvasClick);
    end

    function drawGrid()
        ovGrid = spotsToGrid(overlaySpots);

        % Build a full-canvas RGBA image for the grid (one rect per cell)
        gridImg   = zeros(CAN_H, CAN_W, 3, 'uint8');
        gridAlpha = zeros(CAN_H, CAN_W, 'uint8');

        for row = 1:gridRows
            for col = 1:gridCols
                % Cell centre in display coordinates
                cxD = floor((gridOffX + (col-1)*gridCellSize + r_px) / SCALE);
                cyD = floor((gridOffY + (row-1)*gridCellSize + r_px) / SCALE);
                x1  = max(1, cxD - r_disp);   x2 = min(CAN_W, cxD + r_disp);
                y1  = max(1, cyD - r_disp);   y2 = min(CAN_H, cyD + r_disp);

                isOwn = gridSelected(row, col);
                isOv  = ovGrid(row, col);

                if isOwn && isOv
                    rgb = uint8([200 160  20]);  a = uint8(220);  % both — gold
                elseif isOwn
                    rgb = uint8([ 60 155 255]);  a = uint8(190);  % own — blue
                elseif isOv
                    rgb = uint8([230 165  25]);  a = uint8(110);  % overlay — amber
                else
                    rgb = uint8([ 65  65  70]);  a = uint8( 90);  % empty — dim
                end

                gridImg(y1:y2, x1:x2, 1) = rgb(1);
                gridImg(y1:y2, x1:x2, 2) = rgb(2);
                gridImg(y1:y2, x1:x2, 3) = rgb(3);
                gridAlpha(y1:y2, x1:x2)  = a;
            end
        end

        hi = image(axCanvas, [0 CAN_W], [0 CAN_H], gridImg, ...
            'AlphaData', double(gridAlpha)/255);
        set(hi, 'HitTest', 'off', 'PickableParts', 'none');
    end

    function drawFreeSpots()
        % Overlay spots first (behind own)
        for i = 1:numel(overlaySpots)
            cx  = overlaySpots(i).x / SCALE;
            cy  = overlaySpots(i).y / SCALE;
            col = [0.9 0.65 0.1];
            hr = rectangle(axCanvas, ...
                'Position', [cx-r_disp, cy-r_disp, 2*r_disp, 2*r_disp], ...
                'FaceColor', [col 0.18], 'EdgeColor', [col 0.55], ...
                'LineWidth', 1.2, 'LineStyle', ':');
            set(hr, 'HitTest', 'off', 'PickableParts', 'none');
            ht = text(axCanvas, cx, cy, sprintf('O%d', i), ...
                'Color', [col 0.75], 'FontSize', 8, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
            set(ht, 'HitTest', 'off', 'PickableParts', 'none');
        end

        % Own spots
        for i = 1:numel(spots)
            cx  = spots(i).x / SCALE;
            cy  = spots(i).y / SCALE;
            col = SPOT_COLORS(mod(i-1, size(SPOT_COLORS,1))+1, :);
            if spots(i).isFixed
                hr = rectangle(axCanvas, ...
                    'Position', [cx-r_disp, cy-r_disp, 2*r_disp, 2*r_disp], ...
                    'FaceColor', [col 0.45], 'EdgeColor', col, 'LineWidth', 2);
            else
                hr = rectangle(axCanvas, ...
                    'Position', [cx-r_disp, cy-r_disp, 2*r_disp, 2*r_disp], ...
                    'FaceColor', [col 0.20], 'EdgeColor', 'none');
                set(hr, 'HitTest', 'off', 'PickableParts', 'none');
                xs = [cx-r_disp cx+r_disp cx+r_disp cx-r_disp cx-r_disp];
                ys = [cy-r_disp cy-r_disp cy+r_disp cy+r_disp cy-r_disp];
                hl = plot(axCanvas, xs, ys, '--', 'Color', col, 'LineWidth', 1.8);
                set(hl, 'HitTest', 'off', 'PickableParts', 'none');
            end
            set(hr, 'HitTest', 'off', 'PickableParts', 'none');
            ht = text(axCanvas, cx, cy, num2str(i), 'Color', [1 1 1], 'FontSize', 9, ...
                'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
            set(ht, 'HitTest', 'off', 'PickableParts', 'none');
        end
    end

    function refreshTimeline()
        cla(axTimeline);
        if isempty(spots), return; end
        n        = numel(spots);
        totalDur = max([spots.onset_ms] + [spots.dur_ms]);
        hold(axTimeline, 'on');
        for i = 1:n
            col = SPOT_COLORS(mod(i-1, size(SPOT_COLORS,1))+1, :);
            yi  = n - i + 1;
            ls  = '-';
            if ~spots(i).isFixed, ls = '--'; end
            rectangle(axTimeline, ...
                'Position', [spots(i).onset_ms, yi-0.4, spots(i).dur_ms, 0.8], ...
                'FaceColor', col, 'EdgeColor', col*0.7, 'LineWidth', 0.8, 'LineStyle', ls);
            text(axTimeline, spots(i).onset_ms + spots(i).dur_ms/2, yi, num2str(i), ...
                'Color', [1 1 1], 'FontSize', 8, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
        end
        set(axTimeline, 'XLim', [0 totalDur*1.05+1], 'YLim', [0 n+1]);
        xlabel(axTimeline, 'Time (ms)', 'Color', [0.6 0.6 0.6], 'FontSize', 9);
        hold(axTimeline, 'off');
    end

end

% =======================================================================
% Opto row source chooser
% =======================================================================
function optoPatternDesignerUI(rowIdx)
% Choice dialog: design spots from scratch, or start from an existing
% trial-type pattern (pre-populates the canvas; user edits then saves).
    global S luminose BpodSystem %#ok<NUSED>

    sourceOpts = {'CSplus', 'CSminus', 'Left', 'Right', 'cue'};

    FG = [0.13 0.13 0.15];
    TG = [0.80 0.80 0.80];
    EB = [0.22 0.22 0.25];
    EG = [1.00 1.00 1.00];

    fig = figure('Name', sprintf('Opto Pattern  (row %d)', rowIdx), ...
        'NumberTitle','off','MenuBar','none','Resize','off', ...
        'Position',[250 300 400 200],'Color',FG);

    uicontrol(fig,'Style','text','String',sprintf('OPTO PATTERN — ROW %d', rowIdx), ...
        'Position',[15 165 370 24],'FontSize',12,'FontWeight','bold', ...
        'BackgroundColor',FG,'ForegroundColor',[0.4 0.8 1.0],'HorizontalAlignment','left');
    uicontrol(fig,'Style','text','String','How should this row''s spatial pattern be defined?', ...
        'Position',[15 143 370 18],'FontSize',9, ...
        'BackgroundColor',FG,'ForegroundColor',TG,'HorizontalAlignment','left');

    % Left: design from scratch
    uicontrol(fig,'Style','pushbutton','String','Design from scratch', ...
        'Position',[15 88 170 40],'FontSize',10,'FontWeight','bold', ...
        'BackgroundColor',[0.20 0.38 0.58],'ForegroundColor',EG, ...
        'Callback',@onDesignFromScratch);
    uicontrol(fig,'Style','text','String','Open spot canvas (empty)', ...
        'Position',[15 72 170 16],'FontSize',8, ...
        'BackgroundColor',FG,'ForegroundColor',[0.5 0.5 0.5],'HorizontalAlignment','center');

    % Right: start from trial type
    uicontrol(fig,'Style','text','String','Start from:', ...
        'Position',[210 120 75 20],'FontSize',10, ...
        'BackgroundColor',FG,'ForegroundColor',TG,'HorizontalAlignment','left');
    hRef = uicontrol(fig,'Style','popupmenu','String',sourceOpts, ...
        'Position',[210 98 165 26],'FontSize',10,'BackgroundColor',EB,'ForegroundColor',EG);
    uicontrol(fig,'Style','pushbutton','String','Open in designer →', ...
        'Position',[210 60 165 34],'FontSize',10,'FontWeight','bold', ...
        'BackgroundColor',[0.15 0.50 0.28],'ForegroundColor',[1 1 0.4], ...
        'Callback',@onOpenFromType);
    uicontrol(fig,'Style','text','String','Pre-load spots, then edit and save', ...
        'Position',[210 44 165 16],'FontSize',8, ...
        'BackgroundColor',FG,'ForegroundColor',[0.5 0.5 0.5],'HorizontalAlignment','center');

    uicontrol(fig,'Style','pushbutton','String','Cancel', ...
        'Position',[140 8 120 26],'FontSize',10, ...
        'BackgroundColor',[0.35 0.35 0.38],'ForegroundColor',[0.9 0.9 0.9], ...
        'Callback',@(~,~)delete(fig));

    function onDesignFromScratch(~,~)
        delete(fig);
        PatternDesignerGUI('opto', rowIdx, '');
    end

    function onOpenFromType(~,~)
        refType = sourceOpts{get(hRef,'Value')};
        delete(fig);
        PatternDesignerGUI('opto', rowIdx, refType);
    end

end

% =======================================================================
% Background image (file-backed procedural noise)
% =======================================================================
function img = loadOrGenerateBG(bgFile, W, H)
    if exist(bgFile, 'file')
        raw = imread(bgFile);
        if size(raw, 3) == 3, raw = rgb2gray(raw); end
        if size(raw,1) ~= H || size(raw,2) ~= W, raw = imresize(raw, [H W]); end
        img = raw;
        return
    end
    rng(0);
    img = uint8(randn(H, W) * 6 + 12);
    for k = 1:120
        cx = randi(W); cy = randi(H); r = randi([4 18]); val = randi([60 230]);
        x1=max(1,cx-r*3); x2=min(W,cx+r*3); y1=max(1,cy-r*3); y2=min(H,cy+r*3);
        [gx,gy] = meshgrid(x1:x2, y1:y2);
        blob = uint8(val * exp(-((gx-cx).^2+(gy-cy).^2)/(2*r^2)));
        img(y1:y2,x1:x2) = max(img(y1:y2,x1:x2), blob);
    end
    for k = 1:60
        x1=randi(W); y1=randi(H); ang=rand*2*pi; len=randi([20 120]);
        x2=round(x1+len*cos(ang)); y2=round(y1+len*sin(ang));
        nPts=max(abs(x2-x1),abs(y2-y1))+1;
        xs=round(linspace(x1,x2,nPts)); ys=round(linspace(y1,y2,nPts));
        keep=xs>=1&xs<=W&ys>=1&ys<=H;
        idx=sub2ind([H W],ys(keep),xs(keep));
        img(idx)=min(255,double(img(idx))+randi([15 45]));
    end
    imwrite(img, bgFile);
end

% =======================================================================
% Meta-file loaders
% =======================================================================
function [spots, tickMs, meta] = tryLoadMetaForRow(patternsFolder, patternType, rowIdx)
% meta: the design's r_px and laser options, where saved
    spots  = struct('x',{},'y',{},'onset_ms',{},'dur_ms',{},'isFixed',{});
    tickMs = [];
    meta   = struct();
    patternsFolder = char(patternsFolder);
    metas = dir(fullfile(patternsFolder, sprintf('designed_%s_r%d_*_meta.mat', patternType, rowIdx)));
    if isempty(metas) && rowIdx == 1
        all_m  = dir(fullfile(patternsFolder, sprintf('designed_%s_*_meta.mat', patternType)));
        legacy = all_m(arrayfun(@(m) isempty(regexp(m.name, ...
            sprintf('designed_%s_r\\d+_', patternType), 'once')), all_m));
        metas  = legacy;
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
% Whether the running protocol wants laser power set per pattern for this
% type, and its defaults for a new design.
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

function [spots, tickMs] = tryLoadMeta(patternsFolder, patternType, imgIdx) %#ok<DEFNU>
    spots  = struct('x',{},'y',{},'onset_ms',{},'dur_ms',{},'isFixed',{});
    tickMs = [];
    patternsFolder = char(patternsFolder);
    if imgIdx == 0
        metas = dir(fullfile(patternsFolder, sprintf('designed_%s_*_meta.mat', patternType)));
        if isempty(metas), return; end
        [~, newest] = max([metas.datenum]);
        metaFile = fullfile(patternsFolder, metas(newest).name);
    else
        files = dir(fullfile(patternsFolder, '*.bmp'));
        if imgIdx < 1 || imgIdx > numel(files), return; end
        tok = regexp(files(imgIdx).name, ...
            sprintf('^(designed_%s_\\d{8}_\\d{6})_f\\d+\\.bmp$', patternType), 'tokens');
        if isempty(tok), return; end
        metaFile = fullfile(patternsFolder, sprintf('%s_meta.mat', tok{1}{1}));
        if ~exist(metaFile, 'file'), return; end
    end
    try
        m = load(metaFile);
        for i = 1:numel(m.spots)
            if ~isfield(m.spots(i), 'isFixed'), m.spots(i).isFixed = true; end
        end
        spots = m.spots;
        if isfield(m, 'tickMs'), tickMs = m.tickMs; end
    catch
    end
end

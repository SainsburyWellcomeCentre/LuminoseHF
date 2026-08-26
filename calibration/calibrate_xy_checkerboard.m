% calibrate_xy_checkerboard  Derive the DMD-to-camera pixel ratio from a
%   captured image of the DMD checkerboard test pattern (test_dmd_custom.m,
%   "Test 3: Checkerboard pattern").
%
%   Detects every interior checkerboard corner and averages the spacing
%   between adjacent corners across the whole grid, instead of relying on
%   a single all-on bounding-box footprint (calibrate_xy_white.m) or an
%   assumed rotation angle. Averaging over many squares reduces sensitivity
%   to detection noise at any one edge/corner.
%
%   Input:
%     luminoseData/calibration/checkerboard.tif
%     — a single camera frame captured while the DMD displayed the
%       checkerboard from test_dmd_custom.m Test 3 (blockSize = 64 DMD px
%       per square; update BLOCK_SIZE_DMDPX below if that changes).
%
%   Output:
%     Camera-px-per-DMD-px ratio along each grid direction, plus the
%     checkerboard's rotation relative to the camera axes (for comparison
%     against the hardcoded 47 deg used elsewhere).
%
%   Requires Computer Vision Toolbox (detectCheckerboardPoints).

luminose = LuminoseConstants();

BLOCK_SIZE_DMDPX = 64;   % must match blockSize in test_dmd_custom.m Test 3

imgPath = fullfile(char(luminose.f.luminoseData), 'calibration', 'checkerboard.tif');
if ~exist(imgPath, 'file')
    fprintf('%s not found — displaying checkerboard on DMD and capturing from camera.\n', imgPath);

    cam = CameraModel(luminose.camera);
    dmd = DMDController.DMD();
    dmd.connect(0);
    info = dmd.getInfo();
    W = double(info.width);
    H = double(info.height);

    [xx, yy] = meshgrid(1:W, 1:H);
    checker = logical(mod(floor((xx-1)/BLOCK_SIZE_DMDPX) + floor((yy-1)/BLOCK_SIZE_DMDPX), 2));
    dmd.displayFrame(checker);
    pause(0.5);
    frame = cam.capture();

    dmd.halt();
    dmd.disconnect();
    cam.disconnect();

    outDir = fileparts(imgPath);
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    imwrite(frame, imgPath);
    fprintf('Saved captured checkerboard: %s\n', imgPath);
else
    frame = imread(imgPath);
end
if ndims(frame) == 3
    frame = rgb2gray(frame);
end

%% Detect checkerboard corners
[imagePoints, boardSize] = detectCheckerboardPoints(frame);
if isempty(imagePoints)
    error('calibrate_xy_checkerboard:noCorners', 'No checkerboard corners detected in %s', imgPath);
end

nGridRows = boardSize(1) - 1;   % interior corner grid size
nGridCols = boardSize(2) - 1;
nPts      = size(imagePoints, 1);
fprintf('Detected checkerboard: %d x %d squares -> %d x %d interior corners (%d total) in %s\n', ...
    boardSize(1), boardSize(2), nGridRows, nGridCols, nPts, imgPath);

if nPts ~= nGridRows * nGridCols
    error('calibrate_xy_checkerboard:badGrid', ...
        'Detected %d points but expected %d (%d x %d) — cannot reshape into a grid.', ...
        nPts, nGridRows*nGridCols, nGridRows, nGridCols);
end

% detectCheckerboardPoints returns points ordered so they reshape directly
% into an [nGridRows x nGridCols] grid (MATLAB's standard checkerboard
% convention, e.g. as used by the Camera Calibrator app).
gridX = reshape(imagePoints(:,1), nGridRows, nGridCols);
gridY = reshape(imagePoints(:,2), nGridRows, nGridCols);

%% Spacing between adjacent corners along each grid direction
% "Grid-row" direction: stepping down the board (dim 1)
dRowX = diff(gridX, 1, 1);   dRowY = diff(gridY, 1, 1);
rowSpacing_px = hypot(dRowX, dRowY);

% "Grid-column" direction: stepping across the board (dim 2)
dColX = diff(gridX, 1, 2);   dColY = diff(gridY, 1, 2);
colSpacing_px = hypot(dColX, dColY);

meanRowSpacing_px = mean(rowSpacing_px(:), 'omitnan');
meanColSpacing_px = mean(colSpacing_px(:), 'omitnan');
stdRowSpacing_px  = std(rowSpacing_px(:), 'omitnan');
stdColSpacing_px  = std(colSpacing_px(:), 'omitnan');
nSamples = numel(rowSpacing_px) + numel(colSpacing_px);

fprintf('\nCorner spacing (averaged over %d adjacent-corner pairs across the grid):\n', nSamples);
fprintf('  Grid-row direction:    %.3f +/- %.3f camera px per square  (n=%d)\n', ...
    meanRowSpacing_px, stdRowSpacing_px, numel(rowSpacing_px));
fprintf('  Grid-column direction: %.3f +/- %.3f camera px per square  (n=%d)\n', ...
    meanColSpacing_px, stdColSpacing_px, numel(colSpacing_px));

relStdRow = stdRowSpacing_px / meanRowSpacing_px;
relStdCol = stdColSpacing_px / meanColSpacing_px;
if relStdRow > 0.05 || relStdCol > 0.05
    warning('calibrate_xy_checkerboard:highSpread', ...
        'Spacing spread is >5%% (row %.1f%%, col %.1f%%) — check corner detection quality / grid reshape orientation.', ...
        relStdRow*100, relStdCol*100);
end

%% DMD-to-camera pixel ratio (camera px per DMD px)
% NOTE: "grid-row"/"grid-column" correspond to whichever image axis the
% checkerboard happens to be aligned to on camera, not necessarily the
% DMD's native X/Y — see gridAngle_deg below.
dmdToCameraRatio_gridRow = meanRowSpacing_px / BLOCK_SIZE_DMDPX;
dmdToCameraRatio_gridCol = meanColSpacing_px / BLOCK_SIZE_DMDPX;
anisotropyRatio          = dmdToCameraRatio_gridRow / dmdToCameraRatio_gridCol;

fprintf('\nDMD-to-camera pixel ratio (camera px per DMD px):\n');
fprintf('  Grid-row direction:    %.4f\n', dmdToCameraRatio_gridRow);
fprintf('  Grid-column direction: %.4f\n', dmdToCameraRatio_gridCol);
fprintf('  Row/col ratio: %.3fx  (should be ~1.0 if DMD pixels are square at the sample)\n', ...
    anisotropyRatio);

%% Derived rotation of the checkerboard grid relative to camera axes
meanRowVec    = [mean(dRowX(:), 'omitnan'), mean(dRowY(:), 'omitnan')];
gridAngle_deg = atan2d(meanRowVec(2), meanRowVec(1)) - 90;
fprintf('\nDerived checkerboard grid rotation relative to camera axes: %.2f deg\n', gridAngle_deg);
fprintf('(compare to the hardcoded 47 deg used in calibrate_xy_white.m / _plus.m / _lines.m)\n');

%% Plot
fig = figure('Name', 'Checkerboard DMD/camera ratio', 'NumberTitle', 'off', ...
    'Position', [100 100 1000 500]);

subplot(1,2,1);
imshow(frame, []);
hold on;
plot(imagePoints(:,1), imagePoints(:,2), 'r+', 'MarkerSize', 6, 'LineWidth', 1);
title(sprintf('Detected corners (%d x %d squares)', boardSize(1), boardSize(2)));
hold off;

subplot(1,2,2);
histogram(rowSpacing_px(:), 20, 'FaceColor', [0.85 0.3 0.3], 'FaceAlpha', 0.6);
hold on;
histogram(colSpacing_px(:), 20, 'FaceColor', [0.3 0.5 0.85], 'FaceAlpha', 0.6);
xlabel('Corner spacing (camera px)'); ylabel('Count');
legend({'Grid-row spacing', 'Grid-col spacing'}, 'Location', 'best');
title(sprintf('Spacing distribution (n=%d pairs)', nSamples));
grid on;
hold off;

%% Save
outDir = fullfile(char(luminose.f.luminoseData), 'calibration');
if ~exist(outDir, 'dir'), mkdir(outDir); end
stamp   = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<TNOW1,DATST>
matPath = fullfile(outDir, ['checkerboard_' stamp '.mat']);
pngPath = fullfile(outDir, ['checkerboard_' stamp '.png']);
svgPath = fullfile(outDir, ['checkerboard_' stamp '.svg']);

results.imgPath                  = imgPath;
results.blockSize_dmdpx           = BLOCK_SIZE_DMDPX;
results.boardSize                 = boardSize;
results.imagePoints                = imagePoints;
results.rowSpacing_px              = rowSpacing_px;
results.colSpacing_px              = colSpacing_px;
results.meanRowSpacing_px          = meanRowSpacing_px;
results.meanColSpacing_px          = meanColSpacing_px;
results.dmdToCameraRatio_gridRow   = dmdToCameraRatio_gridRow;
results.dmdToCameraRatio_gridCol   = dmdToCameraRatio_gridCol;
results.anisotropyRatio            = anisotropyRatio;
results.gridAngle_deg              = gridAngle_deg;
results.timestamp                  = stamp;
save(matPath, 'results');

exportgraphics(fig, pngPath, 'Resolution', 150);
print(fig, svgPath, '-dsvg');
fprintf('\nSaved:\n  MAT: %s\n  PNG: %s\n  SVG: %s\n', matPath, pngPath, svgPath);

fprintf('\nNext: once you have an independently measured um-per-camera-pixel value,\n');
fprintf('  um per DMD pixel (row dir) = (um/camera-px) * %.4f\n', dmdToCameraRatio_gridRow);
fprintf('  um per DMD pixel (col dir) = (um/camera-px) * %.4f\n', dmdToCameraRatio_gridCol);

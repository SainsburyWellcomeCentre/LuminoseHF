% calibrate_xy_lines  Display multiple horizontal + vertical 1-px lines on the DMD,
%   capture on camera, rotate to align with DMD axes, and plot mean intensity
%   projections along each axis to assess resolution.

luminose = LuminoseConstants();

cam = rigCamera(luminose);
dmd = DMDController.DMD();
dmd.connect(0);

info = dmd.getInfo();
dmdW = double(info.width);
dmdH = double(info.height);

off = [-3, 0, 6];
img = makeLinesPattern(dmdH, dmdW, off);
dmd.displayFrame(img);
pause(0.5);
frame = cam.capture();

frameD = double(frame);

rotAngle_deg = 47;
cam_px_um    = luminose.camera.effectivePixelSize_um;

%% Rotate camera image to align DMD axes with camera axes
rotFrame = imrotate(frameD, -rotAngle_deg, 'bilinear', 'crop');
rotH     = size(rotFrame, 1);
rotW     = size(rotFrame, 2);

%% Locate crop centre: reuse the beam centre detected by calibrate_xy_white.m
% (same -47deg rotation) instead of assuming the beam sits at the frame
% centre — it isn't necessarily centred in the camera FOV.
calDir = fullfile(char(luminose.f.luminoseData), 'calibration');
wFiles = dir(fullfile(calDir, 'white_*.mat'));
wData  = [];
if isempty(wFiles)
    warning('calibrate_xy_lines:noWhite', ...
        'No white calibration .mat found — falling back to frame-centre crop (may be off if the beam is not centred in the FOV).');
    centreRow = round(rotH/2);
    centreCol = round(rotW/2);
else
    [~, wIdx] = max([wFiles.datenum]);
    wData     = load(fullfile(calDir, wFiles(wIdx).name), 'results');
    centreRow = wData.results.pRow;
    centreCol = wData.results.pCol;
    fprintf('Crop centred on white calibration beam centre: %s  [%d, %d]\n', ...
        wFiles(wIdx).name, centreRow, centreCol);
end

%% Crop ±500 um around the beam centre
cropPad_px = round(500 / cam_px_um);
rCrop = max(1, round(centreRow) - cropPad_px) : min(rotH, round(centreRow) + cropPad_px);
cCrop = max(1, round(centreCol) - cropPad_px) : min(rotW, round(centreCol) + cropPad_px);
rotCrop = rotFrame(rCrop, cCrop);

%% Normalize crop by white beam profile
rotCropNorm = rotCrop;
if ~isempty(wData)
    wRot       = double(wData.results.rotFrame);
    wCrop      = wRot(rCrop, cCrop);
    thresh     = 0.05 * max(wCrop(:));
    beamMask   = wCrop > thresh;
    rotCropNorm = rotCrop ./ max(wCrop, thresh);
    rotCropNorm(~beamMask) = 0;
    fprintf('Normalized by white calibration: %s\n', wFiles(wIdx).name);
end

%% Mean projections from normalised crop
xProj = mean(rotCropNorm, 1);
yProj = mean(rotCropNorm, 2)';

%% Detect line positions
% Restrict detection to ±500 um around crop centre (trim edge margins)
detPad_px  = round(500 / cam_px_um);
cropW      = numel(cCrop);
cropH      = numel(rCrop);
xDetWin    = max(1, round(cropW/2) - detPad_px) : min(cropW, round(cropW/2) + detPad_px);
yDetWin    = max(1, round(cropH/2) - detPad_px) : min(cropH, round(cropH/2) + detPad_px);

[~, xRel] = findpeaks(xProj(xDetWin), 'MinPeakHeight', 0.005 * max(xProj(xDetWin)), ...
    'MinPeakProminence', 0.002 * max(xProj(xDetWin)), 'MinPeakDistance', 2, 'NPeaks', 3, 'SortStr', 'descend');
[~, yRel] = findpeaks(yProj(yDetWin), 'MinPeakHeight', 0.005 * max(yProj(yDetWin)), ...
    'MinPeakProminence', 0.002 * max(yProj(yDetWin)), 'MinPeakDistance', 2, 'NPeaks', 3, 'SortStr', 'descend');
xRel = sort(xRel);
yRel = sort(yRel);
xPeakLocs = xDetWin(1) + xRel - 1;
yPeakLocs = yDetWin(1) + yRel - 1;

fprintf('Vertical line positions (um):   %s  (%d detected)\n', num2str(xPeakLocs * cam_px_um), numel(xPeakLocs));
fprintf('Horizontal line positions (um): %s  (%d detected)\n', num2str(yPeakLocs * cam_px_um), numel(yPeakLocs));
if numel(xPeakLocs) > 1
    fprintf('Vertical spacings (um): %s\n', num2str(diff(xPeakLocs) * cam_px_um));
end
if numel(yPeakLocs) > 1
    fprintf('Horizontal spacings (um): %s\n', num2str(diff(yPeakLocs) * cam_px_um));
end

%% Plot
fig = figure('Name', 'Lines pattern calibration', 'NumberTitle', 'off');

% DMD pattern — zoomed centre crop
dmdCropPad = 6;
dRwin = max(1, round(dmdH/2)-dmdCropPad) : min(dmdH, round(dmdH/2)+dmdCropPad);
dCwin = max(1, round(dmdW/2)-dmdCropPad) : min(dmdW, round(dmdW/2)+dmdCropPad);

subplot(2, 2, 1);
imshow(img(dRwin, dCwin), 'InitialMagnification', 'fit');
title('DMD pattern (centre crop)');

% Zoomed normalised image — fixed ±50 um window around detected crossing
zoomPad_px = round(50 / cam_px_um);

% Centre zoom on the detected crossing (peak nearest to crop centre)
if ~isempty(xPeakLocs)
    [~, xi] = min(abs(xPeakLocs - round(cropW/2)));
    zCenC = xPeakLocs(xi);
else
    zCenC = round(cropW/2);
end
if ~isempty(yPeakLocs)
    [~, yi] = min(abs(yPeakLocs - round(cropH/2)));
    zCenR = yPeakLocs(yi);
else
    zCenR = round(cropH/2);
end

zCwin = max(1, zCenC - zoomPad_px) : min(cropW, zCenC + zoomPad_px);
zRwin = max(1, zCenR - zoomPad_px) : min(cropH, zCenR + zoomPad_px);
subplot(2, 2, 2);
imshow(rotCropNorm(zRwin, zCwin), []);
title('Camera normalised (zoom)');
hold on;
for c = xPeakLocs, xline(c - zCwin(1) + 1, 'r-', 'LineWidth', 0.8); end
for r = yPeakLocs, yline(r - zRwin(1) + 1, 'b-', 'LineWidth', 0.8); end
hold off;

profPad = 50;  % px

subplot(2, 2, 3);
plot((1:cropW) * cam_px_um, xProj);
xlabel('Position (um)'); ylabel('Mean intensity');
title(sprintf('X projection — %d vertical lines detected', numel(xPeakLocs)));
if ~isempty(xPeakLocs)
    xlim([(min(xPeakLocs)-profPad) * cam_px_um, (max(xPeakLocs)+profPad) * cam_px_um]);
end
hold on;
for c = xPeakLocs, xline(c * cam_px_um, 'r--'); end
hold off;
grid on;

subplot(2, 2, 4);
plot((1:cropH) * cam_px_um, yProj);
xlabel('Position (um)'); ylabel('Mean intensity');
title(sprintf('Y projection — %d horizontal lines detected', numel(yPeakLocs)));
if ~isempty(yPeakLocs)
    xlim([(min(yPeakLocs)-profPad) * cam_px_um, (max(yPeakLocs)+profPad) * cam_px_um]);
end
hold on;
for r = yPeakLocs, xline(r * cam_px_um, 'b--'); end
hold off;
grid on;

%% Save
outDir   = fullfile(char(luminose.f.luminoseData), 'calibration');
if ~exist(outDir, 'dir'), mkdir(outDir); end
stamp    = datestr(now, 'yyyymmdd_HHMMSS');
tiffPath = fullfile(outDir, ['lines_' stamp '.tif']);
matPath  = fullfile(outDir, ['lines_' stamp '.mat']);
pngPath  = fullfile(outDir, ['lines_' stamp '.png']);
svgPath  = fullfile(outDir, ['lines_' stamp '.svg']);

results.frame        = frame;
results.rotFrame     = rotFrame;
results.rotCrop      = rotCrop;
results.rotCropNorm  = rotCropNorm;
results.xProj        = xProj;
results.yProj        = yProj;
results.xPeakLocs    = xPeakLocs;
results.yPeakLocs    = yPeakLocs;
results.cam_px_um    = cam_px_um;
results.rCrop        = rCrop;
results.cCrop        = cCrop;
results.rotAngle_deg = rotAngle_deg;
results.timestamp    = stamp;
save(matPath, 'results');

imwrite(frame, tiffPath);
exportgraphics(fig, pngPath, 'Resolution', 150);
print(fig, svgPath, '-dsvg');
fprintf('Saved:\n  TIFF: %s\n  MAT:  %s\n  PNG:  %s\n  SVG:  %s\n', tiffPath, matPath, pngPath, svgPath);

fprintf('Press Enter to stop.\n');
pause;

dmd.halt();
dmd.disconnect();
cam.disconnect();

%% -------------------------------------------------------------------------
function out = maxpool2d(img, k)
if k <= 1, out = img; return; end
H2 = floor(size(img,1) / k);
W2 = floor(size(img,2) / k);
out = blockproc(img(1:H2*k, 1:W2*k), [k k], @(b) max(b.data(:)));
end

function img = makeLinesPattern(H, W, off)
img = zeros(H, W, 'uint8');
cRow = round(H/2);  cCol = round(W/2);
for off_i = off
    img(cRow + off, :) = 255;
    img(:, cCol + off) = 255;
end
end

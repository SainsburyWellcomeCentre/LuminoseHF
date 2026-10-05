% calibrate_xy_singlepixel  Display a single DMD pixel, capture on camera,
%   and plot X/Y intensity profiles with FWHM to assess PSF symmetry.

luminose = LuminoseConstants();

cam = rigCamera(luminose);
dmd = DMDController.DMD();
dmd.connect(0);

info = dmd.getInfo();
W = double(info.width);
H = double(info.height);

img = makeSinglePixel(H, W);
dmd.displayFrame(img);
pause(0.5);
frame = cam.capture();

frameD   = double(frame);
rotFrame = imrotate(frameD, -47, 'bilinear', 'crop');

[~, peakIdx] = max(rotFrame(:));
[pRow, pCol] = ind2sub(size(rotFrame), peakIdx);

xProfile = rotFrame(pRow, :);
yProfile = rotFrame(:, pCol);

cam_px_um = luminose.camera.effectivePixelSize_um;

xFWHM_um = calcFWHM(xProfile) * cam_px_um;
yFWHM_um = calcFWHM(yProfile) * cam_px_um;
fprintf('FWHM  X: %.1f um   Y: %.1f um\n', xFWHM_um, yFWHM_um);

% Zoom window: 5x the larger FWHM, minimum 20 px
pad = max(20, round(5 * max(xFWHM_um, yFWHM_um) / cam_px_um));

camH = size(rotFrame, 1);
camW = size(rotFrame, 2);
rWin = max(1, pRow-pad) : min(camH, pRow+pad);
cWin = max(1, pCol-pad) : min(camW, pCol+pad);

dmdH = size(img, 1);
dmdW = size(img, 2);
dRwin = max(1, round(dmdH/2)-pad) : min(dmdH, round(dmdH/2)+pad);
dCwin = max(1, round(dmdW/2)-pad) : min(dmdW, round(dmdW/2)+pad);

fig = figure('Name', 'Single pixel PSF', 'NumberTitle', 'off');

subplot(2, 2, 1);
imshow(img(dRwin, dCwin), 'InitialMagnification', 'fit');
title('DMD pattern (zoom)');

subplot(2, 2, 2);
imshow(rotFrame(rWin, cWin), []);
title(sprintf('Camera rotated 47° (zoom)  peak: [%d, %d]', pRow, pCol));
hold on;
plot(pCol - cWin(1) + 1, pRow - rWin(1) + 1, 'r+', 'MarkerSize', 10, 'LineWidth', 1.5);
hold off;

subplot(2, 2, 3);
plot((cWin - pCol) * cam_px_um, xProfile(cWin));
xlabel('Position (um)'); ylabel('Intensity');
title(sprintf('X profile — FWHM = %.1f um', xFWHM_um));
xline(0, 'r--');
yline(max(xProfile)/2, 'k--');
grid on;

subplot(2, 2, 4);
plot((rWin - pRow) * cam_px_um, yProfile(rWin));
xlabel('Position (um)'); ylabel('Intensity');
title(sprintf('Y profile — FWHM = %.1f um', yFWHM_um));
xline(0, 'r--');
yline(max(yProfile)/2, 'k--');
grid on;

%% Save
outDir = fullfile(char(luminose.f.luminoseData), 'calibration');
if ~exist(outDir, 'dir'), mkdir(outDir); end
stamp    = datestr(now, 'yyyymmdd_HHMMSS');
tiffPath = fullfile(outDir, ['singlepixel_' stamp '.tif']);
matPath  = fullfile(outDir, ['singlepixel_' stamp '.mat']);
pngPath  = fullfile(outDir, ['singlepixel_' stamp '.png']);
svgPath  = fullfile(outDir, ['singlepixel_' stamp '.svg']);

results.frame    = frame;
results.rotFrame = rotFrame;
results.xProfile = xProfile;
results.yProfile = yProfile;
results.xFWHM_um  = xFWHM_um;
results.yFWHM_um  = yFWHM_um;
results.cam_px_um = cam_px_um;
results.pRow     = pRow;
results.pCol     = pCol;
results.timestamp = stamp;
results.provenance = lhf.provenance(luminose);  % code, config and computer it was made with
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
function fwhm = calcFWHM(profile)
profile = double(profile(:)');
half = max(profile) / 2;
above = profile >= half;
rising  = find(diff([0 above]) ==  1, 1, 'first');
falling = find(diff([above 0]) == -1, 1, 'last');
if isempty(rising) || isempty(falling)
    fwhm = NaN;
else
    fwhm = falling - rising + 1;
end
end

function img = makeSinglePixel(H, W)
img = zeros(H, W, 'uint8');
img(round(H/2), round(W/2)) = 255;
end

% calibrate_xy_plus  Display a single horizontal + vertical 1-px line (plus)
%   on the DMD, capture on camera, rotate to align with DMD axes, and plot
%   mean intensity projections along each axis.

luminose = LuminoseConstants();

cam = rigCamera(luminose);
dmd = DMDController.DMD();
dmd.connect(0);

info = dmd.getInfo();
dmdW = double(info.width);
dmdH = double(info.height);

img = makePlusPattern(dmdH, dmdW);
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

%% Mean projections — each collapses one axis to reveal lines on the other
xProj = mean(rotFrame, 1);    % mean over rows   → shows vertical lines   (vs column)
yProj = mean(rotFrame, 2)';   % mean over cols   → shows horizontal lines (vs row)

%% Detect line positions
minProm = 0.05 * max(max(xProj), max(yProj));

[~, xPeakLocs] = findpeaks(xProj, 'MinPeakProminence', minProm, 'MinPeakDistance', 2);
[~, yPeakLocs] = findpeaks(yProj, 'MinPeakProminence', minProm, 'MinPeakDistance', 2);

fprintf('Vertical line position (um):   %s\n', num2str(xPeakLocs * cam_px_um));
fprintf('Horizontal line position (um): %s\n', num2str(yPeakLocs * cam_px_um));

%% Back-rotate detected line positions to original frame coordinates
cx = rotW / 2;
cy = rotH / 2;

fig = figure('Name', 'Plus pattern calibration', 'NumberTitle', 'off');

% Crop DMD pattern around the cross centre for display (single-px lines invisible at full scale)
dmdCropPad = 50;
dRwin = max(1, round(dmdH/2)-dmdCropPad) : min(dmdH, round(dmdH/2)+dmdCropPad);
dCwin = max(1, round(dmdW/2)-dmdCropPad) : min(dmdW, round(dmdW/2)+dmdCropPad);

subplot(2, 2, 1);
imshow(img(dRwin, dCwin), 'InitialMagnification', 'fit');
title('DMD pattern (centre crop)');

subplot(2, 2, 2);
imshow(frameD, []);
title('Camera (original)');
hold on;
for c = xPeakLocs
    [x1, y1] = backRot(c, 0,    cx, cy);
    [x2, y2] = backRot(c, rotH, cx, cy);
    plot([x1 x2], [y1 y2], 'r-', 'LineWidth', 0.8);
end
for r = yPeakLocs
    [x1, y1] = backRot(0,    r, cx, cy);
    [x2, y2] = backRot(rotW, r, cx, cy);
    plot([x1 x2], [y1 y2], 'b-', 'LineWidth', 0.8);
end
hold off;

subplot(2, 2, 3);
plot((1:rotW) * cam_px_um, xProj);
xlabel('Position (um)'); ylabel('Mean intensity');
title(sprintf('X projection — %d vertical lines detected', numel(xPeakLocs)));
hold on;
for c = xPeakLocs, xline(c * cam_px_um, 'r--'); end
hold off;
grid on;

subplot(2, 2, 4);
plot((1:rotH) * cam_px_um, yProj);
xlabel('Position (um)'); ylabel('Mean intensity');
title(sprintf('Y projection — %d horizontal lines detected', numel(yPeakLocs)));
hold on;
for r = yPeakLocs, xline(r * cam_px_um, 'b--'); end
hold off;
grid on;

%% Save
outDir   = fullfile(char(luminose.f.luminoseData), 'calibration');
if ~exist(outDir, 'dir'), mkdir(outDir); end
stamp    = datestr(now, 'yyyymmdd_HHMMSS');
tiffPath = fullfile(outDir, ['plus_' stamp '.tif']);
matPath  = fullfile(outDir, ['plus_' stamp '.mat']);
pngPath  = fullfile(outDir, ['plus_' stamp '.png']);
svgPath  = fullfile(outDir, ['plus_' stamp '.svg']);

results.frame        = frame;
results.rotFrame     = rotFrame;
results.xProj        = xProj;
results.yProj        = yProj;
results.xPeakLocs    = xPeakLocs;
results.yPeakLocs    = yPeakLocs;
results.cam_px_um    = cam_px_um;
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
function [xo, yo] = backRot(xr, yr, cx, cy)
% Inverse of imrotate(img, -47): transforms rotFrame coords back to original.
dx = xr - cx;  dy = yr - cy;
xo = cx + dx*cosd(47) + dy*sind(47);
yo = cy - dx*sind(47) + dy*cosd(47);
end

function out = maxpool2d(img, k)
% Downsample using block-wise max so 1-px lines are never dropped.
if k <= 1, out = img; return; end
H2 = floor(size(img,1) / k);
W2 = floor(size(img,2) / k);
out = blockproc(img(1:H2*k, 1:W2*k), [k k], @(b) max(b.data(:)));
end

function img = makePlusPattern(H, W)
% Single horizontal + vertical 1-px line centred on the DMD.
img = zeros(H, W, 'uint8');
img(round(H/2), :) = 255;
img(:, round(W/2)) = 255;
end

% calibrate_xy_white  Display all DMD mirrors on, capture on camera,
%   detect the DMD footprint, and plot X/Y intensity profiles with FWHM.
%   The DMD   is rotated ~45° relative to the camera; the footprint is found
%   via thresholding + minimum bounding rectangle on the convex hull.
%   Profiles use only pixels inside the detected DMD rectangle.

luminose = LuminoseConstants();

cam = rigCamera(luminose);
dmd = DMDController.DMD();
dmd.connect(0);

info = dmd.getInfo();
W = double(info.width);
H = double(info.height);

img = ones(H, W, 'uint8') * 255;
dmd.displayFrame(img);
pause(0.5);
frame = cam.capture();

frameD   = double(frame);
rotFrame = imrotate(frameD, -47, 'bilinear', 'crop');
camH     = size(rotFrame, 1);
camW     = size(rotFrame, 2);

%% Detect DMD footprint (axis-aligned after rotation)
smoothed = imgaussfilt(rotFrame, 5);
mask     = smoothed > 0.15 * max(smoothed(:));
mask     = imfill(bwareafilt(mask, 1), 'holes');
bb       = regionprops(mask, 'BoundingBox').BoundingBox;  % [x y w h]

% "All mirrors on" is a flat-top illumination, not a peaked beam, and the
% region can contain a real optical hotspot (dust/reflection/glint) that's
% genuinely one of the brightest points in the frame — any intensity-based
% measure (max or weighted centroid) gets pulled toward it. Use the
% geometric center of the detected footprint instead: bb is set by the
% mask's outer extent, which an interior hotspot doesn't move.
pRow = round(bb(2) + bb(4)/2);
pCol = round(bb(1) + bb(3)/2);
corners  = [bb(1)        bb(2);
            bb(1)+bb(3)  bb(2);
            bb(1)+bb(3)  bb(2)+bb(4);
            bb(1)        bb(2)+bb(4)];
dmdMask  = poly2mask(corners(:,1), corners(:,2), camH, camW);

% Camera pixel size derived from detected DMD footprint
% bb(3) = width after -47° rotation = 1024-mirror axis; verify it's the longer side
if bb(4) > bb(3)
    warning('calibrate_xy_white:axisSwap', ...
        'bb height (%.0f) > width (%.0f) — rotation may be wrong; using bb(3) anyway', bb(4), bb(3));
end
cam_px_um = luminose.dmd.projectedDMDlength / bb(3) * 1000;
fprintf('Effective pixel size at sample: %.3f um/px  (sensor: %.1f um, magnification: %.2fx)\n', ...
    cam_px_um, luminose.camera.pixelSize_um, luminose.camera.pixelSize_um / cam_px_um);
fprintf('Config effectivePixelSize_um = %.3f um  →  update if different\n', ...
    luminose.camera.effectivePixelSize_um);

%% Profiles restricted to DMD region
xCols    = find(dmdMask(pRow, :));
yRows    = find(dmdMask(:, pCol));
xProfile = rotFrame(pRow, xCols);
yProfile = rotFrame(yRows, pCol);

xFWHM_um = calcFWHM(xProfile) * cam_px_um;
yFWHM_um = calcFWHM(yProfile) * cam_px_um;
fprintf('FWHM  X: %.1f um   Y: %.1f um\n', xFWHM_um, yFWHM_um);

%% Plot
fig = figure('Name', 'White pattern PSF', 'NumberTitle', 'off');

subplot(2, 2, 1);
imshow(img, 'InitialMagnification', 'fit');
title('DMD pattern (all on)');

% Rotate corners (and center marker) back to original frame coordinates for display
cx = camW / 2;
cy = camH / 2;
dx = corners(:,1) - cx;
dy = corners(:,2) - cy;
cornersOrig = [cx + dx*cosd(47) + dy*sind(47), ...
               cy - dx*sind(47) + dy*cosd(47)];

dxP = pCol - cx;
dyP = pRow - cy;
pColOrig = cx + dxP*cosd(47) + dyP*sind(47);
pRowOrig = cy - dxP*sind(47) + dyP*cosd(47);

subplot(2, 2, 2);
imshow(frame, []);
title(sprintf('Camera  center: [%d, %d]', pRow, pCol));
hold on;
plot([cornersOrig(:,1); cornersOrig(1,1)], [cornersOrig(:,2); cornersOrig(1,2)], 'r-', 'LineWidth', 1.5);
plot(pColOrig, pRowOrig, 'r+', 'MarkerSize', 10, 'LineWidth', 1.5);
hold off;

subplot(2, 2, 3);
plot(xCols * cam_px_um, xProfile);
xlabel('Position (um)'); ylabel('Intensity');
title(sprintf('X profile — FWHM = %.1f um', xFWHM_um));
xline(pCol * cam_px_um, 'r--');
yline(max(xProfile)/2, 'k--');
grid on;

subplot(2, 2, 4);
plot(yRows * cam_px_um, yProfile);
xlabel('Position (um)'); ylabel('Intensity');
title(sprintf('Y profile — FWHM = %.1f um', yFWHM_um));
xline(pRow * cam_px_um, 'r--');
yline(max(yProfile)/2, 'k--');
grid on;

%% Save
outDir = fullfile(char(luminose.f.luminoseData), 'calibration');
if ~exist(outDir, 'dir'), mkdir(outDir); end
stamp    = datestr(now, 'yyyymmdd_HHMMSS');
tiffPath = fullfile(outDir, ['white_' stamp '.tif']);
matPath  = fullfile(outDir, ['white_' stamp '.mat']);
pngPath  = fullfile(outDir, ['white_' stamp '.png']);
svgPath  = fullfile(outDir, ['white_' stamp '.svg']);

results.frame    = frame;
results.rotFrame = rotFrame;
results.xProfile = xProfile;
results.yProfile = yProfile;
results.xCols    = xCols;
results.yRows    = yRows;
results.xFWHM_um  = xFWHM_um;
results.yFWHM_um  = yFWHM_um;
results.cam_px_um     = cam_px_um;
results.magnification = luminose.camera.pixelSize_um / cam_px_um;
results.pRow     = pRow;
results.pCol     = pCol;
results.corners  = corners;
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
half    = max(profile) / 2;
above   = profile >= half;
rising  = find(diff([0 above]) ==  1, 1, 'first');
falling = find(diff([above 0]) == -1, 1, 'last');
if isempty(rising) || isempty(falling)
    fwhm = NaN;
else
    fwhm = falling - rising + 1;
end
end

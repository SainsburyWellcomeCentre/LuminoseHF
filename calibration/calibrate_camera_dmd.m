% calibrate_camera_dmd  Map DMD pixels to camera pixels, for the Pattern
%   Designer's live camera canvas.
%
%   Projects one small spot at a time on a grid across the DMD field,
%   captures each with the camera, finds where it lands
%   (lhf.cam.spotCentroid, against a frame with the DMD dark) and fits an
%   affine map (lhf.cam.fitRegistration: scale, rotation, shear, offset and
%   any flip). One spot per frame, so no point can be matched to the wrong
%   one.
%
%   Before running: a flat fluorescent or reflective target at the sample
%   plane, in focus, and the laser on at a low power (the DMD gates it).
%   Adjust EXPOSURE_MS so a spot is bright but not saturated.
%
%   Output: luminoseData/calibration/camera_dmd_<stamp>.mat (variable
%   registration, read by lhf.cam.loadRegistration; the newest is used)
%   and a .png of the points and residuals. Rerun whenever the camera or
%   the DMD path moves.

luminose = LuminoseConstants();

GRID        = [6 5];   % spots across, down
MARGIN_PX   = 80;      % DMD px kept clear at each edge
SPOT_R_PX   = 6;       % spot half-width, DMD px
EXPOSURE_MS = luminose.camera.exposureTime_ms;

cam = rigCamera(luminose);
cam.ExposureMs = EXPOSURE_MS;
dmd = DMDController.DMD();
dmd.connect(0);
closer = onCleanup(@() releaseDevices(dmd, cam));

info = dmd.getInfo();
dmdSize = double([info.height info.width]);

[gx, gy] = meshgrid(round(linspace(MARGIN_PX, dmdSize(2) - MARGIN_PX, GRID(1))), ...
                    round(linspace(MARGIN_PX, dmdSize(1) - MARGIN_PX, GRID(2))));
dmdXY = [gx(:), gy(:)];
n = size(dmdXY, 1);

dmd.displayFrame(false(dmdSize));
pause(0.3);
background = cam.capture();

camXY = nan(n, 2);
fprintf('Projecting %d spots...\n', n);
for k = 1:n
    spot = struct('x', dmdXY(k, 1), 'y', dmdXY(k, 2));
    dmd.displayFrame(lhf.spotImage(spot, SPOT_R_PX, dmdSize));
    pause(0.3);
    frame = cam.capture();
    try
        camXY(k, :) = lhf.cam.spotCentroid(frame, background);
    catch err
        fprintf('  spot %d at DMD (%d, %d): %s\n', k, dmdXY(k, 1), dmdXY(k, 2), err.message);
    end
end
clear closer  % releases the DMD and the camera (a script's onCleanup only fires when cleared)

found = all(isfinite(camXY), 2);
fprintf('Found %d of %d spots.\n', nnz(found), n);
registration = lhf.cam.fitRegistration(dmdXY(found, :), camXY(found, :));

% Scale and rotation, to compare with dmd.projectedDMDlength and the 47 deg used elsewhere
a = registration.A(1:2, :);
scaleCamPerDmd = sqrt(abs(det(a)));
rotation_deg = atan2d(a(1, 2), a(1, 1));
fprintf('Camera px per DMD px: %.4f (config implies %.4f)\n', scaleCamPerDmd, ...
    luminose.dmd.projectedDMDlength * 1000 / dmdSize(2) / luminose.camera.effectivePixelSize_um);
fprintf('Rotation: %.2f deg, mirrored: %d\n', rotation_deg, det(a) < 0);
fprintf('Residual: rms %.2f, max %.2f camera px\n', registration.rmsPx, max(registration.residualPx));
if registration.rmsPx > 2
    warning('calibrate_camera_dmd:residual', ...
        'Residual above 2 camera px: check focus, the exposure and the spots flagged above.');
end

registration.timestamp = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<TNOW1,DATST>
registration.camSize = size(background);
registration.exposureMs = EXPOSURE_MS;
registration.dmdSize = dmdSize;
registration.spotRadiusPx = SPOT_R_PX;

outDir = fullfile(char(luminose.f.luminoseData), 'calibration');
if ~isfolder(outDir), mkdir(outDir); end
matPath = fullfile(outDir, ['camera_dmd_' registration.timestamp '.mat']);
save(matPath, 'registration', 'background');
fprintf('Saved %s\n', matPath);

fig = figure('Name', 'Camera-DMD calibration', 'NumberTitle', 'off', 'Position', [100 100 1000 480]);
subplot(1, 2, 1);
imshow(background, []);
hold on;
fitted = lhf.cam.toCamera(registration, dmdXY);
plot(fitted(:, 1), fitted(:, 2), 'g+', 'MarkerSize', 10);
plot(camXY(:, 1), camXY(:, 2), 'ro', 'MarkerSize', 8);
corners = lhf.cam.toCamera(registration, [0 0; dmdSize(2) 0; dmdSize(2) dmdSize(1); 0 dmdSize(1); 0 0]);
plot(corners(:, 1), corners(:, 2), 'y-');
hold off;
title('Spots found (red), fit (green), DMD field (yellow)');
subplot(1, 2, 2);
bar(registration.residualPx);
xlabel('Spot'); ylabel('Residual (camera px)');
title(sprintf('rms %.2f px', registration.rmsPx));
exportgraphics(fig, strrep(matPath, '.mat', '.png'));

function releaseDevices(dmd, cam)
    try dmd.halt(); catch, end
    try dmd.disconnect(); catch, end
    try cam.disconnect(); catch, end
end

% calibrate_z  Scan the Zaber Z-stage ±3 mm around the nominal focus
%   position (29.79 mm) and measure total frame intensity at each Z slice.
%   A single central DMD pixel is displayed. Intensity peaks at focus.
%   The stage returns to its starting position after the scan.

luminose = LuminoseConstants();

FOCUS_UM = 29790;   % nominal focus position (29.79 mm)
RANGE_UM = 5000;    % ±3 mm
zStep_um = luminose.zaber.zStep_um;

zPositions = (FOCUS_UM - RANGE_UM) : zStep_um : (FOCUS_UM + RANGE_UM);
nSteps     = numel(zPositions);
fprintf('Z scan: %.2f mm to %.2f mm in %d um steps (%d positions)\n', ...
    (FOCUS_UM - RANGE_UM)/1e3, (FOCUS_UM + RANGE_UM)/1e3, zStep_um, nSteps);

%% Connect hardware
cam   = rigCamera(luminose);
dmd   = DMDController.DMD();
dmd.connect(0);
zaber = rigStage(luminose);

startPos_um = zaber.positionUm();
% Refuse any move outside the scan and the way back to the start
zaber.LimitsUm = [min([zPositions startPos_um]) max([zPositions startPos_um])];
fprintf('Stage start position: %.3f mm\n', startPos_um / 1e3);

%% Display single central DMD pixel
info = dmd.getInfo();
W    = double(info.width);
H    = double(info.height);
img  = zeros(H, W, 'uint8');
img(round(H/2), round(W/2)) = 255;
dmd.displayFrame(img);
pause(0.5);

%% Scan
totalIntensity = nan(1, nSteps);

for i = 1:nSteps
    zaber.moveAbsolute(zPositions(i));
    frame              = cam.capture();
    totalIntensity(i)  = sum(double(frame(:)));

    if mod(i, 10) == 0 || i == 1 || i == nSteps
        fprintf('  [%3d/%d]  z = %.3f mm   intensity = %.0f\n', ...
            i, nSteps, zPositions(i)/1e3, totalIntensity(i));
    end
end

%% Return to start
fprintf('Returning to %.3f mm …\n', startPos_um / 1e3);
zaber.moveAbsolute(startPos_um);

%% Best focus
[~, focusIdx]        = max(totalIntensity);
bestFocus_mm         = zPositions(focusIdx) / 1e3;
offsetFromNominal_um = zPositions(focusIdx) - FOCUS_UM;
fprintf('Best focus: %.4f mm  (%.1f um from nominal %.4f mm)\n', ...
    bestFocus_mm, offsetFromNominal_um, FOCUS_UM/1e3);

%% Plot
zMm = zPositions / 1e3;

fig = figure('Name', 'Z intensity profile', 'NumberTitle', 'off', ...
    'Position', [100 100 800 500]);

plot(zMm, totalIntensity, 'b-o', 'MarkerSize', 3);
xlabel('Z position (mm)');
ylabel('Total frame intensity (AU)');
title('Z intensity profile — single DMD pixel');
xline(FOCUS_UM/1e3, 'k--', 'Nominal focus', 'LabelVerticalAlignment', 'bottom');
xline(bestFocus_mm, 'r--', sprintf('Best focus: %.4f mm', bestFocus_mm));
grid on;

%% Save
outDir = fullfile(char(luminose.f.luminoseData), 'calibration');
if ~exist(outDir, 'dir'), mkdir(outDir); end
stamp   = datestr(now, 'yyyymmdd_HHMMSS');
matPath = fullfile(outDir, ['zprofile_' stamp '.mat']);
pngPath = fullfile(outDir, ['zprofile_' stamp '.png']);
svgPath = fullfile(outDir, ['zprofile_' stamp '.svg']);

results.zPositions_um        = zPositions;
results.totalIntensity        = totalIntensity;
results.focusIdx              = focusIdx;
results.bestFocus_mm          = bestFocus_mm;
results.offsetFromNominal_um  = offsetFromNominal_um;
results.nominalFocus_um       = FOCUS_UM;
results.zStep_um              = zStep_um;
results.startPos_um           = startPos_um;
results.timestamp             = stamp;
results.stage                 = zaber.record();   % axis, limits, every move
results.camera                = cam.record();     % exposure, averaging, ROI
results.provenance = lhf.provenance(luminose);  % code, config and computer it was made with
save(matPath, 'results');

exportgraphics(fig, pngPath, 'Resolution', 150);
print(fig, svgPath, '-dsvg');
fprintf('Saved:\n  MAT: %s\n  PNG: %s\n  SVG: %s\n', matPath, pngPath, svgPath);

%% Disconnect
dmd.halt();
dmd.disconnect();
zaber.disconnect();
cam.disconnect();

%%
% calibrate_power  Record mean camera intensity within the illuminated DMD
%   footprint, for each laser power setting.
%
%   Sweeps through all rows in dmd/power_calibration.csv, captures a frame
%   at each power step, records the mean pixel value over the illuminated
%   region (detected once, from a reference frame at max power — a single
%   pixel's peak value is dominated by shot noise/hot pixels; averaging over
%   the whole illuminated footprint is far less noisy), and writes results
%   back into the intensity_at_camera column.
%
%   Warnings are printed if any frame is saturated (>95% of 65535).
%   A power-vs-intensity plot is shown on completion.

luminose = LuminoseConstants();
laser    = LaserModel(luminose.laser);
cam      = CameraModel(luminose.camera);

dmd = DMDController.DMD();
dmd.connect(0);
info = dmd.getInfo();
dmd.displayFrame(ones(double(info.height), double(info.width), 'uint8') * 255);
fprintf('DMD: all-white pattern displayed (%dx%d)\n', info.width, info.height);
pause(0.5);

calCsvPath = fullfile(char(luminose.f.luminose_hf), 'dmd', 'power_calibration.csv');
T = readtable(calCsvPath);
nSteps = height(T);

fprintf('Power calibration: %d steps\n', nSteps);
fprintf('CSV: %s\n\n', calCsvPath);

intensities  = zeros(nSteps, 1);
saturated    = false(nSteps, 1);
satThresh    = 0.95 * 65535;

laser.setEnabled(true);

% Detect the illuminated region once, from a reference frame at max power,
% so every step below is averaged over the same fixed spatial mask rather
% than read off a single (noisy) pixel.
laser.setPower(max(T.power_setting_mW));
pause(0.3);
refFrame  = double(cam.capture());
smoothed  = imgaussfilt(refFrame, 5);
illumMask = smoothed > 0.15 * max(smoothed(:));
illumMask = imfill(bwareafilt(illumMask, 1), 'holes');
fprintf('Illuminated region: %d px (%.1f%% of frame)\n\n', ...
    nnz(illumMask), 100 * nnz(illumMask) / numel(illumMask));

for i = 1:nSteps
    laser.setPower(T.power_setting_mW(i));
    pause(0.3);   % allow power to stabilise

    frame = double(cam.capture());
    peak  = max(frame(:));
    meanIntensity   = mean(frame(illumMask));
    intensities(i)  = meanIntensity;
    saturated(i)    = peak > satThresh;

    flag = '';
    if saturated(i), flag = '  *** SATURATED ***'; end
    fprintf('  [%2d/%d] %6.1f mW  mean = %7.1f  peak = %5d%s\n', ...
        i, nSteps, T.power_setting_mW(i), meanIntensity, peak, flag);
end

laser.setEnabled(false);
dmd.halt();
dmd.disconnect();
laser.disconnect();
cam.disconnect();

%% Write results
T.intensity_at_camera = intensities;
writetable(T, calCsvPath);
fprintf('\nUpdated: %s\n', calCsvPath);

if any(saturated)
    fprintf('WARNING: %d step(s) saturated — reduce exposure or laser power.\n', sum(saturated));
end

%% Plot
outDir  = fullfile(char(luminose.f.luminoseData), 'calibration');
if ~exist(outDir, 'dir'), mkdir(outDir); end
stamp   = datestr(now, 'yyyymmdd_HHMMSS');
pngPath = fullfile(outDir, ['power_' stamp '.png']);
svgPath = fullfile(outDir, ['power_' stamp '.svg']);

% Irradiance at the sample plane: the all-white calibration pattern fills the
% full DMD field, which projects to a projectedDMDlength(mm) x
% projectedDMDlength*info.height/info.width(mm) rectangle
areaAtSample_mm2  = luminose.dmd.projectedDMDlength^2 * (double(info.height) / double(info.width));
irradiance_mW_mm2 = T.power_at_sample_mW / areaAtSample_mm2;

% Detect where the laser actually turns on: baseline camera noise is
% estimated from the lowest-power steps. Require two consecutive steps
% above threshold so a single borderline point (e.g. right at the edge of
% the noise floor) doesn't get accepted as the true turn-on.
nBaseline   = min(10, nSteps);
baseline    = median(intensities(1:nBaseline));
baselineStd = std(intensities(1:nBaseline));
aboveThresh = intensities > baseline + 5 * baselineStd;
onsetIdx    = find(aboveThresh(1:end-1) & aboveThresh(2:end), 1);
if isempty(onsetIdx)
    onsetIdx = find(aboveThresh, 1);
end
if isempty(onsetIdx)
    warning('calibrate_power: no clear laser turn-on point detected in intensity data.');
    onsetIdx = 1;
end
fprintf('Laser turn-on detected at step %d (%.1f mW setting, %.2f mW at sample)\n', ...
    onsetIdx, T.power_setting_mW(onsetIdx), T.power_at_sample_mW(onsetIdx));

fig = figure('Name', 'Power Calibration', 'NumberTitle', 'off', 'Position', [200 200 900 400]);

subplot(1, 2, 1);
validSample = T.power_at_sample_mW > 0;
plot(T.power_setting_mW(validSample), irradiance_mW_mm2(validSample), 'w.-', 'MarkerSize', 10, 'LineWidth', 1);
xlabel('Laser power setting (mW)'); ylabel('Power at sample (mW/mm^2)');
title('Laser power vs power at sample');
grid on;

subplot(1, 2, 2);
onMask    = false(nSteps, 1);
onMask(onsetIdx:end) = true;
validMask = T.power_at_sample_mW > 0 & intensities > 0 & ~saturated & onMask;
plot(irradiance_mW_mm2(validMask), intensities(validMask), 'w.-', 'MarkerSize', 10, 'LineWidth', 1);
hold on;
if any(saturated & onMask)
    plot(irradiance_mW_mm2(saturated & onMask), intensities(saturated & onMask), 'r.', 'MarkerSize', 14);
end
xlabel('Power at sample (mW/mm^2)'); ylabel('Mean intensity (counts)');
title('Power at sample vs camera intensity (laser on)');
grid on;

matPath = fullfile(outDir, ['power_' stamp '.mat']);

results.power_setting_mW   = T.power_setting_mW;
results.power_at_sample_mW = T.power_at_sample_mW;
results.intensity_at_camera = intensities;
results.illumMask            = illumMask;
results.saturated           = saturated;
results.timestamp           = stamp;
save(matPath, 'results');

exportgraphics(fig, pngPath, 'Resolution', 150);
print(fig, svgPath, '-dsvg');
fprintf('Saved:\n  MAT: %s\n  PNG: %s\n  SVG: %s\n', matPath, pngPath, svgPath);

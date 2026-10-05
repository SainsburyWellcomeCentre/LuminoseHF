% align_sample_fiducial  Live camera view with a saved fiducial mark overlaid,
%   for manually orienting the sample under the DMD the same way every session.
%
%   First run:
%     Displays an all-on DMD pattern, captures one camera frame, and lets
%     you drag a crosshair onto your reference point. Click "Save Fiducial"
%     to lock it in — its position is saved to
%     luminoseData/calibration/fiducial.mat and reused on every later run.
%
%   Every run after that:
%     Displays an all-on DMD pattern and streams live camera frames with
%     the saved fiducial overlaid (fixed position), so you can manually
%     move/rotate the sample until it lines up with the mark. Click "Stop"
%     to end the live view.
%
%   To redraw the fiducial from scratch, delete
%   luminoseData/calibration/fiducial.mat before running.

luminose = LuminoseConstants();
cam      = rigCamera(luminose);
dmd      = DMDController.DMD();
dmd.connect(0);

info = dmd.getInfo();
W = double(info.width);
H = double(info.height);
dmd.displayFrame(ones(H, W, 'uint8') * 255);
fprintf('DMD: all-white pattern displayed (%dx%d)\n', W, H);
pause(0.3);

outDir  = fullfile(char(luminose.f.luminoseData), 'calibration');
if ~exist(outDir, 'dir'), mkdir(outDir); end
fidPath = fullfile(outDir, 'fiducial.mat');

%% First-time setup: draw the fiducial
if ~exist(fidPath, 'file')
    frame = cam.capture();

    fig1 = figure('Name', 'Place fiducial mark', 'NumberTitle', 'off');
    imshow(frame, []);
    title('Drag the crosshair onto your reference point, then click "Save Fiducial"');

    camSize = size(frame);
    hCross  = drawcrosshair(gca, 'Position', [camSize(2)/2, camSize(1)/2], ...
        'Color', [1 0.2 0.2], 'LineWidth', 1.5, 'Label', 'fiducial');

    uicontrol(fig1, 'Style', 'pushbutton', 'String', 'Save Fiducial', ...
        'Units', 'normalized', 'Position', [0.4 0.02 0.2 0.06], ...
        'FontSize', 11, 'BackgroundColor', [0.2 0.6 0.3], 'ForegroundColor', [1 1 1], ...
        'Callback', @(~,~) uiresume(fig1));

    uiwait(fig1);
    pos = hCross.Position;   % [x y] in camera-pixel coords

    results.x         = pos(1);
    results.y         = pos(2);
    results.timestamp = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<TNOW1,DATST>
    save(fidPath, 'results');
    close(fig1);
    fprintf('Fiducial saved: x=%.1f, y=%.1f -> %s\n', results.x, results.y, fidPath);
else
    m       = load(fidPath, 'results');
    results = m.results;
    fprintf('Loaded fiducial: x=%.1f, y=%.1f  (saved %s)\n', ...
        results.x, results.y, results.timestamp);
end

fidX = results.x;
fidY = results.y;

%% Live view with fiducial overlay
frame = cam.capture();
fig2  = figure('Name', 'Live alignment view', 'NumberTitle', 'off');
hImg  = imshow(frame, []);
hold on;
plot(get(gca,'XLim'), [fidY fidY], 'r-', 'LineWidth', 1.2);
plot([fidX fidX], get(gca,'YLim'), 'r-', 'LineWidth', 1.2);
plot(fidX, fidY, 'r+', 'MarkerSize', 14, 'LineWidth', 1.5);
hold off;
title('Manually orient the sample to align with the fiducial. Click Stop when done.');

setappdata(fig2, 'stopRequested', false);
uicontrol(fig2, 'Style', 'pushbutton', 'String', 'Stop', ...
    'Units', 'normalized', 'Position', [0.42 0.02 0.16 0.06], ...
    'FontSize', 11, 'BackgroundColor', [0.55 0.2 0.2], 'ForegroundColor', [1 1 1], ...
    'Callback', @(src,~) setappdata(ancestor(src,'figure'), 'stopRequested', true));

while ishandle(fig2) && ~getappdata(fig2, 'stopRequested')
    frame = cam.capture();
    set(hImg, 'CData', frame);
    drawnow limitrate;
end
if ishandle(fig2), close(fig2); end

%% Cleanup
dmd.halt();
dmd.disconnect();
cam.disconnect();
fprintf('Done.\n');

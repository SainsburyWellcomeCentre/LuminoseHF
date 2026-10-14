function [data, messages] = cameraDmd(d, s, hooks, luminose)
% lhf.cal.cameraDmd  Maps DMD pixels to full-sensor camera pixels, one spot at a time.
%
%   [data, messages] = lhf.cal.cameraDmd(devices, settings, hooks, luminose)
%
%   Run it through lhf.cal.run('cameraDmd', ...) or the Calibration window. Projects
%   a spot (half-width spotRadiusPx) at each point of a gridX x gridY grid inside
%   marginPx of the DMD's edges, captures each, finds where it lands
%   (lhf.cam.spotCentroid, against a frame with the DMD dark) and fits an affine map
%   (lhf.cam.fitRegistration). First it checks that light reaches the camera (every
%   mirror on: lhf:cal:noLight if almost nothing is lit); after the fit, points more
%   than outlierPx off the map are dropped one at a time (each noted), and it fails
%   (lhf:cal:noMap) if fewer than half the spots remain. One spot per frame, so no point can be matched to the
%   wrong one. Camera points are converted to full-sensor, unbinned pixels
%   (hamacam.Camera.frameToSensor), so the map holds at any subarray or binning.
%
%   data: registration (lhf.cam.fitRegistration plus space 'sensor', roi, binning,
%   camSize, exposureMs, dmdSize, spotRadiusPx, scaleCamPerDmd, rotationDeg,
%   mirrored), background (the frame with the DMD dark), dmdXY, camXY (frame px,
%   NaN where no spot was found), found. messages: spots not found, a poor fit.
%
% See also lhf.cal.run, lhf.cam.loadRegistration

    cam = d.camera;
    dmd = d.dmd;
    messages = {};
    dmdSize = dmdFrameSize(dmd);
    halter = onCleanup(@() haltQuietly(dmd));

    [gx, gy] = meshgrid(round(linspace(s.marginPx, dmdSize(2) - s.marginPx, s.gridX)), ...
        round(linspace(s.marginPx, dmdSize(1) - s.marginPx, s.gridY)));
    dmdXY = [gx(:), gy(:)];
    n = size(dmdXY, 1);

    step(hooks, 0, 'Background: the DMD dark');
    dmd.displayFrame(false(dmdSize));
    pause(s.settleS);
    background = cam.capture();
    hooks.frame(background);

    % Light first: with every mirror on, part of the frame must be clearly brighter,
    % or no spot can be seen (laser off, shutter closed, exposure far too short)
    step(hooks, 0, 'Light check: every DMD mirror on');
    dmd.displayFrame(true(dmdSize));
    pause(s.settleS);
    allOn = cam.capture();
    hooks.frame(allOn);
    lit = litFraction(allOn, background);
    if lit < 0.01
        error('lhf:cal:noLight', ['With every DMD mirror on, the camera sees almost no light ' ...
            '(%.2f%% of the frame lit): is the laser on (Laser panel), the light path open and ' ...
            'the exposure long enough?'], 100 * lit);
    end

    camXY = nan(n, 2);
    for k = 1:n
        step(hooks, k / (n + 1), sprintf('Spot %d of %d at DMD (%d, %d)', k, n, dmdXY(k, :)));
        spot = struct('x', dmdXY(k, 1), 'y', dmdXY(k, 2));
        dmd.displayFrame(lhf.spotImage(spot, s.spotRadiusPx, dmdSize));
        pause(s.settleS);
        frame = cam.capture();
        hooks.frame(frame);
        try
            camXY(k, :) = lhf.cam.spotCentroid(frame, background);
        catch err
            messages{end + 1} = sprintf('Spot %d at DMD (%d, %d) not found: %s', k, dmdXY(k, :), ...
                err.message); %#ok<AGROW>
        end
    end
    clear halter

    found = all(isfinite(camXY), 2);
    if nnz(found) < 6
        error('lhf:cal:tooFewSpots', ['Only %d of %d spots were found: check the target, focus, ' ...
            'the laser and the exposure (a bigger spot half-width helps).'], nnz(found), n);
    end
    sensorXY = cam.frameToSensor(camXY);
    % A point far off the map is something else (a hot pixel, dust, a reflection): drop
    % the worst one at a time, refitting, while it is beyond outlierPx
    reg = lhf.cam.fitRegistration(dmdXY(found, :), sensorXY(found, :));
    while nnz(found) > 6
        [worst, k] = max(reg.residualPx);
        if worst <= s.outlierPx, break; end
        idx = find(found);
        found(idx(k)) = false;
        messages{end + 1} = sprintf('Spot %d at DMD (%d, %d) dropped: %.1f camera px off the map.', ...
            idx(k), dmdXY(idx(k), :), worst); %#ok<AGROW>
        reg = lhf.cam.fitRegistration(dmdXY(found, :), sensorXY(found, :));
    end
    if nnz(found) < n / 2
        error('lhf:cal:noMap', ['Only %d of %d spots fit one map within %g camera px: the camera ' ...
            'is not seeing the projected spots. Check the light (Laser panel), focus and exposure, ' ...
            'and that the spots show on the Camera panel while it runs.'], nnz(found), n, s.outlierPx);
    end
    reg.space = 'sensor';  % full-sensor, unbinned camera pixels
    reg.roi = cam.Roi;     % the readout while calibrating
    reg.binning = cam.Binning;
    reg.camSize = size(background);
    reg.exposureMs = cam.ExposureMs;
    reg.dmdSize = dmdSize;
    reg.spotRadiusPx = s.spotRadiusPx;
    a = reg.A(1:2, :);
    reg.scaleCamPerDmd = sqrt(abs(det(a)));
    reg.rotationDeg = atan2d(a(1, 2), a(1, 1));
    reg.mirrored = det(a) < 0;
    if reg.rmsPx > s.maxRmsPx
        messages{end + 1} = sprintf(['Residual rms %.2f camera px is above %.2f: check focus, ' ...
            'the exposure and the spots not found or dropped.'], reg.rmsPx, s.maxRmsPx);
    end
    try
        expected = luminose.dmd.projectedDMDlength * 1000 / dmdSize(2) / luminose.camera.effectivePixelSize_um;
        if abs(reg.scaleCamPerDmd / expected - 1) > 0.1
            messages{end + 1} = sprintf(['Scale %.4f camera px per DMD px is more than 10%% from ' ...
                'the config''s %.4f (dmd.projectedDMDlength, camera.effectivePixelSize_um).'], ...
                reg.scaleCamPerDmd, expected);
        end
    catch
    end
    step(hooks, 1, sprintf('Fitted %d of %d spots: rms %.2f camera px', nnz(found), n, reg.rmsPx));
    data = struct('registration', reg, 'background', background, 'dmdXY', dmdXY, ...
        'camXY', camXY, 'found', found, 'litFraction', lit);
end


function f = litFraction(frame, background)
% The share of the frame clearly brighter than the background (smoothed, against
% the background's own noise).
    d = imgaussfilt(double(frame) - double(background), 2);
    b = double(background);
    noise = 1.4826 * median(abs(b(:) - median(b(:))));
    f = mean(d(:) > max(10 * noise, 20));
end

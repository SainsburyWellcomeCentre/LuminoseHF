function [data, messages] = zFocus(d, s, hooks, ~)
% lhf.cal.zFocus  Finds the Z where the DMD is in focus on the sample.
%
%   [data, messages] = lhf.cal.zFocus(devices, settings, hooks, luminose)
%
%   Run it through lhf.cal.run('zFocus', ...) or the Calibration window. Shows a
%   spot of half-width spotRadiusPx (0: one mirror) at the DMD centre, steps Z from
%   centreUm - rangeUm to centreUm + rangeUm by stepUm (only the planes within Z's
%   LimitsUm: a scan reaching past them is cut there, with a message), sums each
%   camera frame, and takes the brightest plane as the focus. Z's LimitsUm are
%   narrowed to the scan and the way back (and put back), so no move leaves it; Z
%   returns to where it started if returnToStart, however it ends.
%
%   data: results, as calibrate_z saved them: zPositions_um, totalIntensity,
%   focusIdx, bestFocus_mm, offsetFromNominal_um, nominalFocus_um, zStep_um,
%   startPos_um, stage (record), camera (record). messages: a scan cut to the
%   limits, a peak at an end.
%
% See also lhf.cal.run

    cam = d.camera;
    z = d.stage.z;
    dmd = d.dmd;
    messages = {};
    positions = (s.centreUm - s.rangeUm):s.stepUm:(s.centreUm + s.rangeUm);
    startUm = z.positionUm();
    limits = z.LimitsUm;
    % Only the planes Z may reach (its LimitsUm, within its safe range): the scan is cut
    % there rather than refused
    allowed = positions >= limits(1) & positions <= limits(2);
    if ~any(allowed)
        error('lhf:cal:outsideLimits', ['The scan %.3f - %.3f mm lies wholly outside Z''s ' ...
            'limits %.3f - %.3f mm: move the centre.'], positions(1) / 1e3, positions(end) / 1e3, ...
            limits(1) / 1e3, limits(2) / 1e3);  % error() takes scalars only
    end
    if ~all(allowed)
        messages{end + 1} = sprintf(['The scan was cut to Z''s limits: %.3f - %.3f mm ' ...
            '(asked %.3f - %.3f mm).'], positions(find(allowed, 1)) / 1e3, ...
            positions(find(allowed, 1, 'last')) / 1e3, positions([1 end]) / 1e3);
    end
    positions = positions(allowed);
    n = numel(positions);
    closer = onCleanup(@() finish(z, startUm, limits, s.returnToStart, dmd));
    z.LimitsUm = [min([positions startUm]) max([positions startUm])];

    dmdSize = dmdFrameSize(dmd);
    centre = round(dmdSize([2 1]) / 2);
    dmd.displayFrame(lhf.spotImage(struct('x', centre(1), 'y', centre(2)), s.spotRadiusPx, dmdSize));
    pause(0.3);

    total = nan(1, n);
    for k = 1:n
        step(hooks, (k - 1) / n, sprintf('Z %.3f mm (%d of %d)', positions(k) / 1e3, k, n));
        z.moveAbsolute(positions(k));
        frame = cam.capture();
        hooks.frame(frame);
        total(k) = sum(double(frame(:)));
    end
    [~, focusIdx] = max(total);
    if focusIdx == 1 || focusIdx == n
        messages{end + 1} = ['The brightest plane is at an end of the scan (or of Z''s limits): ' ...
            'widen the range, move the centre, or widen Z''s limits in the Stage panel.'];
    end
    results = struct('zPositions_um', positions, 'totalIntensity', total, 'focusIdx', focusIdx, ...
        'bestFocus_mm', positions(focusIdx) / 1e3, ...
        'offsetFromNominal_um', positions(focusIdx) - s.centreUm, 'nominalFocus_um', s.centreUm, ...
        'zStep_um', s.stepUm, 'startPos_um', startUm, 'stage', [], 'camera', cam.record());
    clear closer  % back to the start, limits put back, DMD halted
    results.stage = z.record();
    step(hooks, 1, sprintf('Best focus %.4f mm (%+.0f um from the centre)', results.bestFocus_mm, ...
        results.offsetFromNominal_um));
    data = struct('results', results);
end


function finish(z, startUm, limits, returnToStart, dmd)
    if returnToStart
        try z.moveAbsolute(startUm); catch, end
    end
    try z.LimitsUm = limits; catch, end
    haltQuietly(dmd);
end

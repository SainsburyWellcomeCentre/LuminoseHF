function result = align(grab, stages, reference, stageCal, options)
% lhf.cam.align  Move the stage until the camera sees what the reference frame saw.
%
%   result = lhf.cam.align(grab, stages, reference, stageCal, options)
%
%   grab: () -> a camera frame (averaged). stages: struct x, y, z (zaberstage.Stage,
%   or anything with positionUm, moveAbsolute, moveRelative). reference: the
%   animal's reference frame. stageCal: lhf.cam.fitStageCamera. options: the
%   alignment settings (LuminoseConstants.alignmentDefaults: maxTravelXY_um,
%   maxTravelZ_um, maxStep_um, tolerance_um, maxIterations, zSearch_um,
%   zStep_um, rotationWarn_deg, minPeak) and optionally
%       crop        [x y w h] camera px to register on (the DMD field)
%       progress    (info) -> called after every frame: step, iteration,
%                   residualUm, rotationDeg, positionUm, frame
%       shouldStop  () -> true to stop before the next move
%       confirm     (info) -> false to cancel before the first move; info has
%                   moveUm (the first X/Y move) and zSearchUm
%
%   Three steps, each frame registered on the whole image (lhf.cam.register):
%     1. X/Y to within 10 um: move by -inv(C) * shift, at most maxStep_um a move.
%     2. Z: step across +/- zSearch_um, approaching each plane from below, and
%        go to the plane whose image matches the reference best (a parabola
%        through the best three).
%     3. X/Y again, to tolerance_um, at a finer scale.
%   No move leaves the box of maxTravel around where the stage started, and a
%   frame registered with too little confidence stops it without moving.
%   Rotation is reported, not corrected: X/Y cannot undo it.
%
%   result: status ('aligned', 'notConverged', 'stopped', 'cancelled' or
%   'failed'), message, residualUm, rotationDeg, rotationWarning, peak,
%   startUm and endUm ([x y z]), zFoundUm, moves, frame (the last one).

    options = withDefaults(options);
    names = {'x', 'y', 'z'};
    startUm = positions();
    result = struct('status', 'failed', 'message', '', 'residualUm', NaN, 'rotationDeg', NaN, ...
        'rotationWarning', false, 'peak', NaN, 'startUm', startUm, 'endUm', startUm, ...
        'zFoundUm', NaN, 'moves', 0, 'frame', []);
    confirmed = false;

    try
        [ok, why] = xyPass('coarse', 10, 4);
        if ok
            [ok, why] = zSearch();
        end
        if ok
            [ok, why] = xyPass('fine', options.tolerance_um, 2);
        end
        if ok
            result.status = 'aligned';
        else
            result.status = why;
        end
    catch err
        result.status = 'failed';
        result.message = err.message;
    end
    result.endUm = positions();
    result.rotationWarning = abs(result.rotationDeg) > options.rotationWarn_deg;
    if isempty(result.message)
        result.message = describe(result);
    end
    if result.rotationWarning
        result.message = sprintf(['%s Rotated %.2f deg from the reference: the stage cannot correct ' ...
            'it; re-seat the animal.'], result.message, result.rotationDeg);
    end

    % ---------------------------------------------------------------
    function [ok, why] = xyPass(step, targetUm, downsample)
        ok = false;
        why = 'notConverged';
        for iteration = 1:options.maxIterations + 1
            r = measure(step, iteration, downsample);
            if ~r.ok
                why = 'failed';
                result.message = sprintf(['Registration not confident enough (peak %.3f < %.3f): ' ...
                    'is the sample in view, lit and near focus?'], r.peak, options.minPeak);
                return
            end
            moveUm = -(stageCal.Cinv * r.shiftPx(:))';
            if norm(moveUm) < targetUm
                ok = true;
                return
            end
            if iteration > options.maxIterations
                result.message = sprintf('%s X/Y: %.1f um left after %d moves.', step, norm(moveUm), options.maxIterations);
                return
            end
            if norm(moveUm) > options.maxStep_um
                moveUm = moveUm * options.maxStep_um / norm(moveUm);
            end
            if ~mayMove(struct('moveUm', moveUm, 'zSearchUm', options.zSearch_um))
                why = stopReason();
                return
            end
            moveBy(moveUm);
        end
    end

    function [ok, why] = zSearch()
        ok = false;
        why = 'failed';
        z0 = stages.z.positionUm();
        planes = z0 + (-options.zSearch_um:options.zStep_um:options.zSearch_um);
        similarity = nan(size(planes));
        moveZ(planes(1) - options.zStep_um);  % every plane approached from below
        for k = 1:numel(planes)
            if ~mayMove(struct('moveUm', [0 0], 'zSearchUm', options.zSearch_um))
                why = stopReason();
                return
            end
            moveZ(planes(k));
            r = measure('z', k, 4);
            if r.ok, similarity(k) = r.similarity; end
        end
        if all(isnan(similarity))
            result.message = 'No Z plane registered to the reference.';
            moveZ(z0 - options.zStep_um);
            moveZ(z0);
            return
        end
        [~, best] = max(similarity);
        zBest = planes(best);
        if best > 1 && best < numel(planes) && all(isfinite(similarity(best-1:best+1)))
            s = similarity(best-1:best+1);  % vertex of the parabola through the best three
            denominator = s(1) - 2 * s(2) + s(3);
            if denominator < 0
                zBest = zBest + options.zStep_um * 0.5 * (s(1) - s(3)) / denominator;
            end
        end
        moveZ(zBest - options.zStep_um);
        moveZ(zBest);
        result.zFoundUm = zBest;
        ok = true;
    end

    function r = measure(step, iteration, downsample)
        frame = grab();
        r = lhf.cam.register(reference, frame, 'Crop', options.crop, 'Downsample', downsample, ...
            'MinPeak', options.minPeak);
        result.frame = frame;
        result.peak = r.peak;
        if r.ok
            result.rotationDeg = r.rotationDeg;
            result.residualUm = norm(stageCal.Cinv * r.shiftPx(:));
        end
        options.progress(struct('step', step, 'iteration', iteration, 'residualUm', result.residualUm, ...
            'rotationDeg', result.rotationDeg, 'peak', r.peak, 'positionUm', positions(), 'frame', frame));
    end

    function go = mayMove(info)
        go = ~options.shouldStop();
        if go && ~confirmed
            go = options.confirm(info);
            confirmed = go;
            if ~go, result.status = 'cancelled'; end
        end
    end

    function why = stopReason()
        if strcmp(result.status, 'cancelled') || ~confirmed
            why = 'cancelled';
            result.message = 'Cancelled before any move.';
        else
            why = 'stopped';
            result.message = 'Stopped.';
        end
    end

    function moveBy(moveUm)
        target = positions() + [moveUm 0];
        requireInBox(target);
        stages.x.moveRelative(moveUm(1));
        stages.y.moveRelative(moveUm(2));
        result.moves = result.moves + 1;
    end

    function moveZ(z)
        target = positions();
        target(3) = z;
        requireInBox(target);
        stages.z.moveAbsolute(z);
        result.moves = result.moves + 1;
    end

    function requireInBox(target)
        offset = abs(target - startUm);
        if any(offset(1:2) > options.maxTravelXY_um) || offset(3) > options.maxTravelZ_um
            error('lhf:cam:outsideTravel', ['Refused: the move would take the stage %.0f um (X/Y) or ' ...
                '%.0f um (Z) from where alignment started, beyond maxTravel (%g, %g um).'], ...
                max(offset(1:2)), offset(3), options.maxTravelXY_um, options.maxTravelZ_um);
        end
    end

    function p = positions()
        p = zeros(1, 3);
        for n = 1:3
            p(n) = stages.(names{n}).positionUm();
        end
    end
end

function options = withDefaults(options)
    defaults = LuminoseConstants.alignmentDefaults();
    defaults.crop = [];
    defaults.progress = @(~) [];
    defaults.shouldStop = @() false;
    defaults.confirm = @(~) true;
    for name = fieldnames(defaults)'
        if ~isfield(options, name{1}), options.(name{1}) = defaults.(name{1}); end
    end
end

function text = describe(result)
    if strcmp(result.status, 'aligned')
        text = sprintf('Aligned: %.1f um from the reference, Z %.1f um, rotation %.2f deg.', ...
            result.residualUm, result.zFoundUm, result.rotationDeg);
    else
        text = result.status;
    end
end

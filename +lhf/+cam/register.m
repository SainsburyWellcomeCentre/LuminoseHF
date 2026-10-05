function r = register(reference, frame, varargin)
% lhf.cam.register  How a camera frame is shifted and rotated from a reference, from the whole image.
%
%   r = lhf.cam.register(reference, frame)
%   r = lhf.cam.register(reference, frame, 'Crop', [x y w h], 'Downsample', 4, 'MinPeak', 0.1)
%
%   Both frames are cropped (camera px; the DMD field, say), downsampled,
%   and flat-fielded: divided by a heavy blur of themselves, so the
%   illumination, which is fixed to the camera, does not pull the answer to no
%   shift. Phase correlation (imregcorr, rigid) gives the transform; its
%   angle, coarse below a degree or two, is refined by trying angles within
%   1 deg of it (translation found by phase correlation at each) and keeping
%   the best match.
%       shiftPx      [dx dy]: where the reference's centre is in frame, minus
%                    where it is in the reference (full-resolution camera px)
%       rotationDeg  frame's rotation from the reference
%       peak         imregcorr's peak correlation: how sure it is
%       ok           peak >= MinPeak
%       similarity   correlation of the two images once aligned, over their
%                    overlap (1 identical; falls with defocus): used to focus
%   lhf.cam.align moves the stage with it.

    p = inputParser;
    p.addParameter('Crop', [], @(v) isempty(v) || numel(v) == 4);
    p.addParameter('Downsample', 4, @(v) isscalar(v) && v >= 1);
    p.addParameter('MinPeak', 0.1, @isscalar);
    p.parse(varargin{:});
    f = p.Results.Downsample;

    [fixed, origin] = prepare(reference, p.Results.Crop, f);
    moving = prepare(frame, p.Results.Crop, f);

    centre = [size(fixed, 2), size(fixed, 1)] / 2 + 0.5;
    coarse = imregcorr(moving, fixed, 'rigid');
    angles = coarse.RotationAngle + (-1:0.25:1);
    fits = arrayfun(@(a) fitAtAngle(fixed, moving, centre, a), angles);
    scores = [fits.similarity];
    [~, best] = max(scores);
    fit = fits(best);
    if best > 1 && best < numel(angles) && all(isfinite(scores(best-1:best+1)))
        s = scores(best-1:best+1);  % vertex of the parabola through the best three
        denominator = s(1) - 2 * s(2) + s(3);
        if denominator < 0
            fit = fitAtAngle(fixed, moving, centre, angles(best) + 0.25 * 0.5 * (s(1) - s(3)) / denominator);
        end
    end
    inFrame = transformPointsInverse(fit.tform, centre);  % tform maps frame onto the reference

    r = struct();
    r.shiftPx = (inFrame - centre) * f;
    r.rotationDeg = -fit.tform.RotationAngle;
    r.peak = fit.peak;
    r.ok = isfinite(r.peak) && r.peak >= p.Results.MinPeak && all(isfinite(r.shiftPx));
    r.similarity = fit.similarity;
    r.origin = origin;
end

function fit = fitAtAngle(fixed, moving, centre, angle)
% The frame turned by angle about the centre, then shifted by phase correlation
    R = [cosd(angle) -sind(angle); sind(angle) cosd(angle)];
    turn = rigidtform2d(angle, (centre(:) - R * centre(:))');
    turned = imwarp(moving, turn, 'OutputView', imref2d(size(fixed)), 'FillValues', 0);
    [shift, peak] = imregcorr(turned, fixed, 'translation');
    tform = rigidtform2d(angle, turn.Translation + shift.Translation);
    fit = struct('tform', tform, 'peak', double(peak), ...
        'similarity', overlapCorrelation(fixed, moving, tform));
end

function [img, origin] = prepare(frame, crop, f)
% Cropped, downsampled, flat-fielded, zero mean, unit variance
    img = double(frame);
    origin = [0 0];
    if ~isempty(crop)
        crop = round(crop);
        cols = max(1, crop(1)):min(size(img, 2), crop(1) + crop(3) - 1);
        rows = max(1, crop(2)):min(size(img, 1), crop(2) + crop(4) - 1);
        img = img(rows, cols);
        origin = [cols(1) rows(1)] - 1;
    end
    if f > 1
        img = imresize(img, 1 / f, 'box');
    end
    illumination = imgaussfilt(img, max(size(img)) / 16);
    img = img ./ max(illumination, max(illumination(:)) * 1e-3) - 1;
    img = (img - mean(img(:))) / max(std(img(:)), eps);
end

function c = overlapCorrelation(fixed, moving, tform)
% Correlation of the frame warped onto the reference, where both have data
    view = imref2d(size(fixed));
    warped = imwarp(moving, tform, 'OutputView', view, 'FillValues', NaN);
    valid = isfinite(warped);
    c = NaN;
    if nnz(valid) < 0.1 * numel(valid), return; end
    a = fixed(valid);
    b = warped(valid);
    a = a - mean(a);
    b = b - mean(b);
    c = sum(a .* b) / sqrt(sum(a .^ 2) * sum(b .^ 2));
end

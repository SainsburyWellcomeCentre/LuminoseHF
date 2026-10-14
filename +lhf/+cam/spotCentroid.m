function xy = spotCentroid(frame, background, minAreaPx)
% lhf.cam.spotCentroid  Where one projected spot lands in a camera frame.
%
%   xy = lhf.cam.spotCentroid(frame, background)
%   xy = lhf.cam.spotCentroid(frame, background, minAreaPx)   (default 16)
%
%   [x y] in camera pixels: the centre of frame - background, smoothed (a Gaussian of
%   1.5 px, so a hot or noisy single pixel cannot pass for a spot), over the pixels
%   above half its maximum, each weighted by how far above, keeping only the
%   connected region holding the maximum (a dust speck elsewhere does not pull it).
%   Errors (lhf:cam:noSpot) when the spot is not clearly above the background: its
%   peak under 8 times the noise (the median absolute deviation, which a few bright
%   pixels do not inflate) or its region smaller than minAreaPx pixels.

    if nargin < 3, minAreaPx = 16; end  % a single hot pixel, blurred, covers about 10
    d = imgaussfilt(double(frame) - double(background), 1.5);
    peak = max(d, [], 'all');
    noise = 1.4826 * median(abs(d(:) - median(d(:))));
    if peak <= 0 || peak < 8 * max(noise, 1)
        error('lhf:cam:noSpot', 'No spot above the background (peak %.0f, noise %.1f counts).', peak, noise);
    end
    labels = bwlabel(d > peak / 2);
    [~, at] = max(d(:));
    region = labels == labels(at);
    if nnz(region) < minAreaPx
        error('lhf:cam:noSpot', ['Only %d bright pixel(s) at the peak, fewer than %d: a hot ' ...
            'pixel or speck, not a spot.'], nnz(region), minAreaPx);
    end
    w = (d - peak / 2) .* region;  % weights fall to 0 at the edge: pixels just in or out barely count
    [rows, cols] = ndgrid(1:size(d, 1), 1:size(d, 2));
    xy = [sum(w .* cols, 'all'), sum(w .* rows, 'all')] / sum(w, 'all');
end

function xy = spotCentroid(frame, background)
% lhf.cam.spotCentroid  Where one projected spot lands in a camera frame.
%
%   xy = lhf.cam.spotCentroid(frame, background)
%
%   [x y] in camera pixels: the centre of the pixels of frame - background
%   above half its maximum, each weighted by how far above, keeping only the connected
%   region holding the maximum (a dust speck elsewhere does not pull it).
%   Errors when the spot is not clearly above the background.

    d = double(frame) - double(background);
    peak = max(d, [], 'all');
    noise = std(d, 0, 'all');
    if peak <= 0 || peak < 10 * noise
        error('lhf:cam:noSpot', 'No spot above the background (peak %.0f, noise %.0f counts).', peak, noise);
    end
    labels = bwlabel(d > peak / 2);
    [~, at] = max(d(:));
    w = (d - peak / 2) .* (labels == labels(at));  % weights fall to 0 at the edge: pixels just in or out barely count
    [rows, cols] = ndgrid(1:size(d, 1), 1:size(d, 2));
    xy = [sum(w .* cols, 'all'), sum(w .* rows, 'all')] / sum(w, 'all');
end

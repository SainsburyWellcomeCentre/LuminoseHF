function img = spotImage(spots, r_px, dmdSize)
% lhf.spotImage  Every spot of a design lit at once, as one DMD frame.
%
%   img = lhf.spotImage(spots, r_px, [rows cols])
%
%   logical [rows cols]: each spot a square of half-width r_px around
%   (spots(k).x, spots(k).y), clipped at the edges, drawn as
%   DMDPatternPlayer draws them. Timing is ignored. The Pattern Designer
%   projects it to show the design on the sample.

    img = false(dmdSize);
    for k = 1:numel(spots)
        rows = max(1, spots(k).y - r_px):min(dmdSize(1), spots(k).y + r_px);
        cols = max(1, spots(k).x - r_px):min(dmdSize(2), spots(k).x + r_px);
        img(rows, cols) = true;
    end
end

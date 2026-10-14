function generateLeftRightPatterns(dur_ms)
%GENERATELEFTRIGHTPATTERNS  Save "left" and "right" half-field DMD patterns.
%
%   generateLeftRightPatterns()          % dur_ms defaults to 200
%   generateLeftRightPatterns(dur_ms)
%
%   "left"  = left half of the DMD field on, all else off
%   "right" = right half of the DMD field on, all else off
%
%   Saves left.bmp / right.bmp (the illumination mask) plus left_meta.mat /
%   right_meta.mat (side, dur_ms) to luminose.dmd.patternsFolder. As in the DMD
%   panel's designed-pattern view (DMDController.app), the bitmap only encodes which
%   mirrors are on; on-time (dur_ms) is applied separately when the pattern is loaded onto the device.

    if nargin < 1 || isempty(dur_ms)
        dur_ms = 200;
    end

    luminose       = LuminoseConstants();
    patternsFolder = char(luminose.dmd.patternsFolder);
    if ~exist(patternsFolder, 'dir')
        mkdir(patternsFolder);
    end

    H = 768;
    W = 1024;
    halfCol = floor(W / 2);

    sides           = {'left', 'right'};
    masks           = cell(1, 2);
    masks{1}        = false(H, W);
    masks{1}(:, 1:halfCol)     = true;
    masks{2}        = false(H, W);
    masks{2}(:, halfCol+1:W)  = true;

    for i = 1:numel(sides)
        side = sides{i};
        mask = masks{i};

        bmpFile = fullfile(patternsFolder, sprintf('%s.bmp', side));
        imwrite(uint8(mask) * 255, bmpFile);

        metaFile = fullfile(patternsFolder, sprintf('%s_meta.mat', side)); %#ok<NASGU>
        save(metaFile, 'side', 'dur_ms');

        fprintf('Saved %s (%d ms) -> %s\n', side, dur_ms, bmpFile);
    end
end

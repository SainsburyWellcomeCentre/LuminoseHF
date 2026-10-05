function [irradiances, weights] = options(design, patternType, S)
% lhf.laser.options  A design's laser irradiances (mW/mm2) and draw weights.
%
%   [irradiances, weights] = lhf.laser.options(design, patternType, S)
%
%   From the design (set in the Pattern Designer); for a design saved
%   without them, the type's defaults, S.GUIMeta.patternSel_<type>.LaserDefaults;
%   empty when neither exists. Weights that do not match the irradiances
%   (wrong count, negative, all zero) become equal weights.

    irradiances = [];
    weights = [];
    if isfield(design, 'laserIrradiances_mWmm2') && ~isempty(design.laserIrradiances_mWmm2)
        irradiances = design.laserIrradiances_mWmm2(:)';
        if isfield(design, 'laserWeights'), weights = design.laserWeights(:)'; end
    else
        selector = ['patternSel_' patternType];
        if isfield(S, 'GUIMeta') && isfield(S.GUIMeta, selector) && isfield(S.GUIMeta.(selector), 'LaserDefaults')
            irradiances = S.GUIMeta.(selector).LaserDefaults.irradiances(:)';
            weights = S.GUIMeta.(selector).LaserDefaults.weights(:)';
        end
    end
    if numel(weights) ~= numel(irradiances) || any(weights < 0) || sum(weights) == 0
        weights = ones(size(irradiances));
    end
end

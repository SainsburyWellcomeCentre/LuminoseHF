function text = describe(design, patternType, S)
% lhf.laser.describe  A design's laser power as one line for the pattern table.
%
%   text = lhf.laser.describe(design, patternType, S)
%
%   The irradiances (mW/mm2) a trial showing the design draws from, with each
%   one's probability: '2, 5, 8 (equal)' or '4 (0.75), 6 (0.25)'. From
%   lhf.laser.options, so a design saved without a list shows the type's
%   defaults. 'none' for no design or a blank (no power is set for them, as
%   lhf.laser.draw does) and for a type without laser options.

    text = 'none';
    if isempty(design), return; end
    [irradiances, weights] = lhf.laser.options(design, patternType, S);
    if isempty(irradiances), return; end
    if all(weights == weights(1))
        text = [strjoin(arrayfun(@(v) sprintf('%g', v), irradiances, 'UniformOutput', false), ', ') ' (equal)'];
        if numel(irradiances) == 1, text = sprintf('%g', irradiances); end
    else
        prob = weights / sum(weights);
        text = strjoin(arrayfun(@(v, q) sprintf('%g (%.2g)', v, q), irradiances, prob, ...
            'UniformOutput', false), ', ');
    end
end

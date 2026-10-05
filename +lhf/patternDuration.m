function seconds = patternDuration(design, exposureUs, row)
% lhf.patternDuration  How long a design plays on the DMD, in seconds.
%
%   seconds = lhf.patternDuration(design, S.GUI.patternExposure_<type>, row)
%
%   The sequence DMDPatternPlayer builds: one frame per tick up to the last
%   spot's offset, ceil(max(onset_ms + dur_ms) / tickMs) frames, each shown
%   for the row's exposure (us; the last entry when the vector is shorter,
%   as the DMD handler reads it). The protocols time DeliverStim with it, so
%   the response window opens as the pattern ends.

    exposure = exposureUs(min(row, numel(exposureUs)));
    nFrames = ceil(max([design.spots.onset_ms] + [design.spots.dur_ms]) / design.tickMs);
    seconds = nFrames * exposure / 1e6;
end

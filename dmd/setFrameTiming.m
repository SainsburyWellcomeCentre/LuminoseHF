function synchWidth = setFrameTiming(seq, t)
% setFrameTiming  Frame timing for an ALP sequence, with the longest synch pulse the DMD accepts.
%
%   synchWidth = setFrameTiming(seq, t)
%
%   seq  a DMDController sequence (binary mode already set)
%   t    illumination and picture time per frame (us)
%
%   The frame-synch pulse (DMD pin 8) gates the laser, so it should span the
%   frame, but AlpSeqTiming rejects (ALP_PARM_INVALID) a pulse as long as the
%   picture time. Widths just under t are tried in turn; the first accepted is
%   left set and returned. 0 (the ALP default, a short pulse) is the last
%   resort. DMDPatternPlayer probes the same way and caches the result.

    t = round(t);
    candidates = round([t-1, t-10, t-100, t-1000, 0.99*t, 0.9*t, 0.5*t]);
    for w = [unique(candidates(candidates > 0), 'stable'), 0]
        try
            seq.timing(t, t, 0, w, 0);
            synchWidth = w;
            return
        catch
        end
    end
    seq.timing(t, t, 0, 0, 0);  % rethrows the ALP's own error if even the default fails
    synchWidth = 0;
end

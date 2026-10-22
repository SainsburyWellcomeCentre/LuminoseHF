function release(varargin)
% lhf.bpod.release  Deletes a session's Bpod objects so their destructors run.
%
%   lhf.bpod.release(trialManager, R)   any handle objects; invalid or empty ones skipped
%
%   A BpodTrialManager and a RotaryEncoderModule each run a timer whose callback holds the
%   object itself, so MATLAB never frees them when the session's function ends: every
%   session left a stopped trial-manager timer and a running encoder capture timer (still
%   reading the encoder's port between sessions) behind, and MATLAB's memory grew by about
%   75 MB a session (leak report, 2026-10-21). Deleting them runs their own destructors,
%   which stop and delete those timers and stop the encoder's stream. The protocols call it
%   through an onCleanup made as both exist. Never throws.
%
% See also lhf.bpod.stopStrayTrialTimers

    for k = 1:numel(varargin)
        try
            obj = varargin{k};
            if ~isempty(obj) && isvalid(obj)
                delete(obj);
            end
        catch
            % a port already gone: nothing more to release
        end
    end
end

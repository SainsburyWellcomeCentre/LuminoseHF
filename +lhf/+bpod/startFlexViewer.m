function startFlexViewer()
% lhf.bpod.startFlexViewer  Opens Bpod's Flex I/O analog viewer with a fresh trace buffer.
%
%   lhf.bpod.startFlexViewer()
%
%   BpodSystem.startAnalogViewer reuses a viewer window that is still open (from the sniff
%   calibration or an earlier session) without rebuilding its trace buffer, so a buffer
%   broken earlier (lhf.bpod.repairFlexViewer) carried into the new session. An open
%   viewer is closed through Bpod first, then started anew, at the bottom left.
%
% An overflowed buffer is repaired between trials (lhf.bpod.repairFlexViewer), never from
% a timer: until 2026-10-21 a 0.25 s timer did it, writing into BpodSystem while the trial
% loop did, the pattern suspected in the MATLAB crashes. The trace can stay blank for the
% rest of a trial that overflowed it.
%
% See also lhf.bpod.repairFlexViewer, lhf.bpod.stopStrayTrialTimers

    global BpodSystem %#ok<GVMIS> Bpod's
    try
        if isfield(BpodSystem.GUIHandles, 'OscopeFig_Builtin') ...
                && ~isempty(BpodSystem.GUIHandles.OscopeFig_Builtin) ...
                && isvalid(BpodSystem.GUIHandles.OscopeFig_Builtin)
            BpodSystem.analogViewer('end', []);
        end
    catch
        % a half-closed viewer: start anyway
    end
    BpodSystem.startAnalogViewer();
    try
        position = get(BpodSystem.GUIHandles.OscopeFig_Builtin, 'Position');
        set(BpodSystem.GUIHandles.OscopeFig_Builtin, 'Position', [30 65 position(3:4)]);
    catch
        % a stand-in without a window (tests)
    end
end

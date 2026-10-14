function startFlexViewer()
% lhf.bpod.startFlexViewer  Opens Bpod's Flex I/O analog viewer with a fresh trace buffer.
%
%   lhf.bpod.startFlexViewer()
%
%   BpodSystem.startAnalogViewer reuses a viewer window that is still open (from the sniff
%   calibration or an earlier session) without rebuilding its trace buffer, so a buffer
%   broken earlier (lhf.bpod.repairFlexViewer) carried into the new session. An open
%   viewer is closed through Bpod first, then started anew.
%
% It also starts lhf.bpod.flexRepairTimer, which repairs an overflowed trace buffer every
% 0.25 s for the rest of the session.
%
% See also lhf.bpod.repairFlexViewer, lhf.bpod.flexRepairTimer, lhf.bpod.stopStrayTrialTimers

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
    BpodSystem.startAnalogViewer;
    lhf.bpod.flexRepairTimer('start');  % keeps repairing it during trials too
end

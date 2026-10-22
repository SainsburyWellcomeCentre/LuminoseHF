function open = showFlexViewer(show)
% lhf.bpod.showFlexViewer  Opens or closes Bpod's Flex I/O analog viewer, as the Analog viewer box says.
%
%   open = lhf.bpod.showFlexViewer(show)   open: whether the viewer is open after
%
%   The protocols call it at START and before each trial with S.GUI.AnalogViewer (Sniff
%   panel, unticked by default), so ticking or unticking it during a session opens or
%   closes the viewer at the next trial. A closed viewer is opened fresh
%   (lhf.bpod.startFlexViewer); an open one is left as it is. The analog data are recorded
%   (_ANLG.dat) whether it is open or not: the viewer only draws them. Closed, it saves the
%   front end ten redraws a second of four long traces, its largest load during a session
%   (2026-10-21: windows freezing while trials went on). Closing its window with the X
%   while the box is ticked opens it again at the next trial.
%
% See also lhf.bpod.startFlexViewer, lhf.bpod.repairFlexViewer

    global BpodSystem %#ok<GVMIS> Bpod's
    open = isOpen();
    if show && ~open
        lhf.bpod.startFlexViewer();
    elseif ~show && open
        BpodSystem.analogViewer('end', []);
    end
    open = isOpen();
end

function tf = isOpen()
    global BpodSystem %#ok<GVMIS> Bpod's
    tf = false;
    try
        h = BpodSystem.GUIHandles.OscopeFig_Builtin;
        tf = ~isempty(h) && isvalid(h);
    catch
    end
end

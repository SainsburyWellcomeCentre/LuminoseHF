function repaired = repairFlexViewer()
% lhf.bpod.repairFlexViewer  Puts the Flex I/O viewer's trace buffer back to one sweep.
%
%   repaired = lhf.bpod.repairFlexViewer()   true when it had to
%
%   Bpod's analog viewer (analogViewer 'update') writes a batch of samples larger than one
%   sweep past the end of its buffer, which happens whenever MATLAB was busy longer than a
%   sweep (2.4 s at 200 ms/div). From then on the trace's YData and XData differ in length
%   and every redraw warns "Error creating or updating Line ... XDataYData". The protocols
%   call this once per trial: a buffer of the wrong width is reset (NaN, sweep restarted),
%   so the trace starts over instead. Nothing happens when the viewer is closed.
%
% See also lhf.bpod.startFlexViewer

    global BpodSystem %#ok<GVMIS> Bpod's
    repaired = false;
    try
        handles = BpodSystem.GUIHandles;
        if ~isfield(handles, 'OSC') || ~isfield(handles, 'OSCData') || ...
                ~isfield(handles.OSC, 'nDisplaySamples') || ~isfield(handles.OSCData, 'Ydata')
            return
        end
        n = handles.OSC.nDisplaySamples;
        rows = size(handles.OSCData.Ydata, 1);
        if size(handles.OSCData.Ydata, 2) == n
            return
        end
        BpodSystem.GUIHandles.OSCData.Ydata = nan(rows, n);
        BpodSystem.GUIHandles.OSC.SweepPos = 1;
        repaired = true;
    catch
    end
end

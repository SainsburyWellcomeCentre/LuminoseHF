function flexRepairTimer(action)
% lhf.bpod.flexRepairTimer  Repairs the Flex I/O viewer's trace buffer every 0.25 s.
%
%   lhf.bpod.flexRepairTimer('start')   (re)starts it; lhf.bpod.startFlexViewer does
%   lhf.bpod.flexRepairTimer('stop')    stops and deletes it; the protocols' cleanup does
%
%   The viewer overflows as soon as Bpod reads a batch of samples longer than one sweep,
%   which happens in the first trial (the stream starts with it, while the next trial is
%   being prepared) and after any long busy stretch. Repairing only between trials left the
%   trace blank, and the console full of XDataYData warnings, for a whole trial; this timer
%   runs during trials too (Bpod's getTrialData waits in drawnow, which lets it run), so
%   the trace recovers within a quarter of a second. Never throws.
%
% See also lhf.bpod.repairFlexViewer, lhf.bpod.startFlexViewer

    name = 'lhf.bpod.flexRepair';
    try
        old = timerfindall('Name', name);
        if ~isempty(old)
            stop(old);
            delete(old);
        end
        if strcmp(action, 'start')
            t = timer('Name', name, 'ExecutionMode', 'fixedSpacing', 'Period', 0.25, ...
                'BusyMode', 'drop', 'TimerFcn', @(~, ~) lhf.bpod.repairFlexViewer());
            start(t);
        end
    catch
    end
end

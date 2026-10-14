function n = stopStrayTrialTimers()
% lhf.bpod.stopStrayTrialTimers  Stops BpodTrialManager timers left running by a stopped session.
%
%   n = lhf.bpod.stopStrayTrialTimers()   n: how many running ones were stopped
%
%   BpodTrialManager polls the state machine's serial port every 10 ms with a timer whose
%   callback holds the trial manager itself, so a session stopped mid-trial leaves the
%   object, and its timer, alive: its delete method, which would stop it, never runs.
%   That stray timer goes on reading the port and takes the bytes meant for the next
%   reader: the sniff calibration's RunStateMachine then never sees its trial end and
%   waits forever. Every protocol calls this as it starts and as it ends (cleanup), and
%   the sniff calibration before its trial. Only running timers are stopped, and none is
%   deleted: the trial manager's own delete stops its timer and would fail on a deleted
%   one; a stopped timer reads nothing. Never throws.
%
% See also BpodTrialManager, calibrateSniffThresholds, lhf.bpod.startFlexViewer

    n = 0;
    try
        timers = timerfindall;
    catch
        return
    end
    for k = 1:numel(timers)
        try
            fcn = timers(k).TimerFcn;
            if isa(fcn, 'function_handle') && contains(func2str(fcn), 'processLiveEvents') ...
                    && strcmp(timers(k).Running, 'on')
                stop(timers(k));
                n = n + 1;
            end
        catch
        end
    end
end

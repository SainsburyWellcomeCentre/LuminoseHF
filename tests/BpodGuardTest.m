classdef BpodGuardTest < matlab.unittest.TestCase
% LuminoseHF's guards around Bpod (lhf.bpod): a trial manager's polling timer left
% running by a stopped session is stopped, the Flex I/O viewer's overflowed trace buffer
% is put back to one sweep, and the sniff calibration refuses to run during a session or
% twice at once. No Bpod: a stand-in BpodSystem global and plain timers.

    properties
        savedBpod
    end

    methods (TestMethodSetup)
        function keepBpod(tc)
            global BpodSystem %#ok<GVMIS> the guards read it
            tc.savedBpod = BpodSystem;
            tc.addTeardown(@() BpodGuardTest.putBpod(tc.savedBpod));
        end
    end

    methods (Test)
        function aRunningTrialManagerTimerIsStopped(tc)
            obj = struct('processLiveEvents', @() []);  % stands in for a BpodTrialManager
            stray = timer('TimerFcn', @(h, e) obj.processLiveEvents(), 'StartDelay', 60);
            other = timer('TimerFcn', @(h, e) disp('other'), 'StartDelay', 60);
            tc.addTeardown(@() delete([stray other]));
            start(stray);
            start(other);
            tc.verifyGreaterThanOrEqual(lhf.bpod.stopStrayTrialTimers(), 1);
            tc.verifyEqual(stray.Running, 'off');
            tc.verifyTrue(isvalid(stray));        % stopped, not deleted
            tc.verifyEqual(other.Running, 'on');  % not a trial manager's
            stop(other);
        end

        function anOverflowedViewerBufferIsReset(tc)
            global BpodSystem %#ok<GVMIS> the stand-in
            BpodSystem = struct('GUIHandles', struct('OSC', struct('nDisplaySamples', 1200, 'SweepPos', 900), ...
                'OSCData', struct('Ydata', ones(4, 2000))));
            tc.verifyTrue(lhf.bpod.repairFlexViewer());
            tc.verifySize(BpodSystem.GUIHandles.OSCData.Ydata, [4 1200]);
            tc.verifyTrue(all(isnan(BpodSystem.GUIHandles.OSCData.Ydata(:))));
            tc.verifyEqual(BpodSystem.GUIHandles.OSC.SweepPos, 1);
            tc.verifyFalse(lhf.bpod.repairFlexViewer());  % right size: untouched
        end

        function theRepairTimerRunsOnceAndStops(tc)
            tc.addTeardown(@() lhf.bpod.flexRepairTimer('stop'));
            lhf.bpod.flexRepairTimer('start');
            lhf.bpod.flexRepairTimer('start');  % started again: still one
            t = timerfindall('Name', 'lhf.bpod.flexRepair');
            tc.verifyNumElements(t, 1);
            tc.verifyEqual(t.Running, 'on');
            lhf.bpod.flexRepairTimer('stop');
            tc.verifyEmpty(timerfindall('Name', 'lhf.bpod.flexRepair'));
        end

        function aClosedViewerIsLeftAlone(tc)
            global BpodSystem %#ok<GVMIS> the stand-in
            BpodSystem = struct('GUIHandles', struct());
            tc.verifyFalse(lhf.bpod.repairFlexViewer());
            BpodSystem = [];
            tc.verifyFalse(lhf.bpod.repairFlexViewer());
        end

        function sniffCalibrationWaitsForTheSessionToEnd(tc)
            global BpodSystem %#ok<GVMIS> the stand-in
            gui = figure('Visible', 'off');
            tc.addTeardown(@() delete(gui));
            tc.addTeardown(@() delete(findall(groot, 'Type', 'figure', 'Name', 'Sniff Calibration')));
            BpodSystem = struct('ProtocolFigures', struct('ParameterGUI', gui));
            setappdata(gui, 'StartPressed', true);
            RunSniffCalibration();  % would error reaching Bpod: it must return first
            tc.verifyFalse(isappdata(gui, 'SniffCalibrating') && getappdata(gui, 'SniffCalibrating'));
            setappdata(gui, 'StartPressed', false);
            setappdata(gui, 'SniffCalibrating', true);  % one already running
            RunSniffCalibration();
            tc.verifyTrue(getappdata(gui, 'SniffCalibrating'));  % its flag, still set
        end
    end

    methods (Static)
        function putBpod(saved)
            global BpodSystem %#ok<GVMIS> put back
            BpodSystem = saved;
        end
    end
end

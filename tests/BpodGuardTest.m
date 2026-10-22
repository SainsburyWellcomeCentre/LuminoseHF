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

        function aSessionsObjectsAreReleased(tc)
            held = timer('TimerFcn', @(h, e) [], 'StartDelay', 60);  % a handle object to release
            start(held);
            gone = timer;
            delete(gone);
            lhf.bpod.release(held, gone, []);  % a deleted and an empty one skipped
            tc.verifyFalse(isvalid(held));
        end

        function theEncoderTimerIsPausedForARead(tc)
            capture = timer('TimerFcn', @(h, e) [], 'Tag', 'RE_COMtest', 'StartDelay', 60);
            tc.addTeardown(@() delete(capture));
            start(capture);
            R = struct('Port', struct('PortName', 'COMtest'), ...
                'readUSBStream', @(code) struct('code', code, 'running', capture.Running));
            data = lhf.bpod.readEncoder(R, 0);
            tc.verifyEqual(data.code, 0);
            tc.verifyEqual(data.running, 'off');      % stopped while reading
            tc.verifyEqual(capture.Running, 'on');    % and started again
            R.readUSBStream = @(code) BpodGuardTest.failedRead();
            tc.verifyError(@() lhf.bpod.readEncoder(R, 0), 'test:read');
            tc.verifyEqual(capture.Running, 'on');    % started again after a failed read
            stop(capture);
        end

        function aTrialsAnalogSamplesAreReadAsTheyCome(tc)
            file = [tempname '_ANLG.dat'];
            tc.addTeardown(@() delete(file));
            BpodGuardTest.appendSamples(file, [1 1 1 2], [0 4095 2048 100]);
            [t, volts] = lhf.bpod.readTrialAnalog(file, 2, 1, 1000);
            tc.verifyEqual(t, [0; 0.001; 0.002]);
            tc.verifyEqual(volts(:, 1), [0; 5; 2048 / 4095 * 5], 'AbsTol', 1e-12);
            tc.verifyEqual(volts(:, 2), volts(:, 1));  % the second channel
            BpodGuardTest.appendSamples(file, [2 2 3], [7 8 9]);  % more of trial 2, trial 3 begun
            [t, volts] = lhf.bpod.readTrialAnalog(file, 2, 2, 1000);
            tc.verifyNumElements(t, 3);  % the one read before and the two added
            tc.verifyEqual(volts(:, 1) * 4095 / 5, [100; 7; 8], 'AbsTol', 1e-9);
            fid = fopen(file, 'a');  % half a sample: left for the next read
            fwrite(fid, uint16(3), 'uint16');
            fclose(fid);
            [t, ~] = lhf.bpod.readTrialAnalog(file, 2, 3, 1000);
            tc.verifyNumElements(t, 1);
            [t, volts] = lhf.bpod.readTrialAnalog(fullfile(tempdir, 'none_ANLG.dat'), 2, 1, 1000);
            tc.verifyEmpty(t);
            tc.verifySize(volts, [0 2]);
        end

        function aRelativeAnalogFileIsFoundBesideTheData(tc)
            folder = tempname;
            mkdir(folder);
            tc.addTeardown(@() rmdir(folder, 's'));
            BpodGuardTest.appendSamples(fullfile(folder, 'S_ANLG.dat'), [1 1], [10 20]);
            [t, ~] = lhf.bpod.readTrialAnalog('S_ANLG.dat', 2, 1, 1000);  % not in the current folder
            tc.verifyEmpty(t);
            [t, volts] = lhf.bpod.readTrialAnalog('S_ANLG.dat', 2, 1, 1000, folder);
            tc.verifyEqual(volts(:, 1) * 4095 / 5, [10; 20], 'AbsTol', 1e-9);
            tc.verifyNumElements(t, 2);
        end

        function settingsAreSavedAfterStopEmptiedThePath(tc)
            global BpodSystem %#ok<GVMIS> the stand-in
            file = [tempname '.mat'];
            tc.addTeardown(@() delete(file));
            BpodSystem = struct('Path', struct('Settings', file), 'ProtocolSettings', struct('GUI', struct('a', 1)));
            tc.verifyEqual(lhf.bpod.saveSettings('remember'), file);
            BpodSystem.Path.Settings = '';  % what Bpod's Stop does
            BpodSystem.ProtocolSettings.GUI.a = 2;
            tc.verifyEqual(lhf.bpod.saveSettings('save'), file);
            saved = load(file);
            tc.verifyEqual(saved.ProtocolSettings.GUI.a, 2);
        end

        function theViewerOpensAndClosesAsTheBoxSays(tc)
            global BpodSystem %#ok<GVMIS> the stand-in
            BpodSystem = struct('GUIHandles', struct('OscopeFig_Builtin', []), ...
                'startAnalogViewer', @BpodGuardTest.openViewer, 'analogViewer', @BpodGuardTest.closeViewer);
            tc.addTeardown(@() delete(findall(groot, 'Type', 'figure', 'Name', 'stand-in viewer')));
            tc.verifyFalse(lhf.bpod.showFlexViewer(false));   % closed and unticked: nothing
            tc.verifyTrue(lhf.bpod.showFlexViewer(true));     % ticked: opened
            viewer = BpodSystem.GUIHandles.OscopeFig_Builtin;
            tc.verifyTrue(lhf.bpod.showFlexViewer(true));     % already open: the same window
            tc.verifyEqual(BpodSystem.GUIHandles.OscopeFig_Builtin, viewer);
            tc.verifyFalse(lhf.bpod.showFlexViewer(false));   % unticked: closed
            tc.verifyFalse(isvalid(viewer));
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
        function appendSamples(file, trials, values)
            % Samples as Bpod writes them: uint16 [trial ch1 ch2], ch2 = ch1
            fid = fopen(file, 'a');
            fwrite(fid, [trials; values; values], 'uint16');
            fclose(fid);
        end

        function openViewer()
            global BpodSystem %#ok<GVMIS> the stand-in
            BpodSystem.GUIHandles.OscopeFig_Builtin = figure('Visible', 'off', 'Name', 'stand-in viewer');
        end

        function closeViewer(op, ~)
            global BpodSystem %#ok<GVMIS> the stand-in
            if strcmp(op, 'end')
                delete(BpodSystem.GUIHandles.OscopeFig_Builtin);
                BpodSystem.GUIHandles.OscopeFig_Builtin = [];
            end
        end

        function data = failedRead() %#ok<STOUT> a read that fails
            error('test:read', 'port gone');
        end

        function putBpod(saved)
            global BpodSystem %#ok<GVMIS> put back
            BpodSystem = saved;
        end
    end
end

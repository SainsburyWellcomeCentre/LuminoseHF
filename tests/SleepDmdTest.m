classdef SleepDmdTest < matlab.unittest.TestCase
% The sleep protocol's DMD path (dmd_hf_sleep, SoftCodeHandler_luminose_hf_sleep) on a
% simulated DMD put in the rig's registry (lhf.device): prepared before the trial on
% DMDPatternPlayer, shown by the soft code in this process, released at cleanup with the
% shared DMD left connected.

    properties
        Driver
        Saved
    end

    methods (TestMethodSetup)
        function setUp(tc)
            global BpodSystem S luminose %#ok<GVMIS>
            savedBpod = BpodSystem;
            savedS = S;
            savedLuminose = luminose;
            tc.Saved = getappdata(0, 'lhfDevices');
            root = fileparts(fileparts(mfilename('fullpath')));
            folder = fullfile(root, 'protocols', 'luminose_hf_sleep', 'HelperFiles', 'devices');
            addpath(folder, fullfile(root, 'dmd'));
            tc.addTeardown(@() rmpath(folder));   % teardowns run last first: this after restore
            tc.addTeardown(@() tc.restore(savedBpod, savedS, savedLuminose));
            tc.Driver = DMDController.SimulatedDriver('Width', 1024, 'Height', 768);
            lhf.device('dmd', DMDController.DMD(tc.Driver));
            design = struct('spots', struct('x', 100, 'y', 200, 'onset_ms', 0, 'dur_ms', 1, ...
                'isFixed', true), 'tickMs', 1, 'r_px', 3, 'nF', 1);
            BpodSystem = struct('PluginObjects', struct('PatternDesigns', struct('opto', ...
                {{design}}), 'SelectedPatternRow', struct('opto', 1), 'PreparingTrial', 1));
            S = struct('GUI', struct('patternExposure_opto', 1000));
            luminose = struct('dmd', struct());   % the session's config (designs are in memory)
        end
    end

    methods (Test)
        function aTestPulseIsPreparedThenShown(tc)
            global BpodSystem %#ok<GVMIS>
            dmd_hf_sleep('prepare', 12);
            tc.verifyTrue(BpodSystem.PluginObjects.PreparedPatterns.opto.shown);
            tc.verifyEmpty(tc.Driver.shownFrame());   % nothing shown until the soft code
            dmd_hf_sleep('advance');
            SoftCodeHandler_luminose_hf_sleep(12);   % in this process, not on a worker
            frame = tc.Driver.shownFrame();
            tc.verifyNotEmpty(frame);
            tc.verifyEqual(frame(200, 100), uint8(255));
        end

        function cleanupReleasesItsSequencesButLeavesTheDmd(tc)
            dmd_hf_sleep('prepare', 12);
            dmd_hf_sleep('advance');
            dmd_hf_sleep(12);
            dmd_hf_sleep('close');
            clear dmd_hf_sleep
            tc.verifyEmpty(tc.Driver.shownFrame());
            dmd = lhf.device('dmd');
            tc.verifyNotEmpty(dmd.device.deviceId);   % the shared DMD, still connected
            tc.verifyLessThanOrEqual(numel(tc.Driver.sequenceIds()), 1);   % the facade's own
        end

        function itUsesTheSharedDmd(tc)
            dmd_hf_sleep('prepare', 12);
            tc.verifyNotEmpty(lhf.device('dmd').device.deviceId);
            tc.verifyTrue(any(strcmp({tc.Driver.Calls.Function}, 'seqPut')));
        end
    end

    methods (Access = private)
        function restore(tc, savedBpod, savedS, savedLuminose)
            global BpodSystem S luminose %#ok<GVMIS>
            dmd_hf_sleep('close');
            clear dmd_hf_sleep
            BpodSystem = savedBpod;
            S = savedS;
            luminose = savedLuminose;
            if isempty(tc.Saved)
                if isappdata(0, 'lhfDevices'), rmappdata(0, 'lhfDevices'); end
            else
                setappdata(0, 'lhfDevices', tc.Saved);
            end
        end
    end
end

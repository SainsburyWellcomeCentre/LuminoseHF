classdef LaserTest < matlab.unittest.TestCase
% Per-pattern laser power (lhf.laser.options, lhf.laser.draw, lhf.laser.describe),
% the connected path on obis's simulated laser (lhf.laser.onSoftCode, lhf.laser.close)
% and the irradiance calibration (irradianceToSetpoint_mW). No laser, no Bpod.

    properties
        S
    end

    methods (TestMethodSetup)
        function makeSettings(tc)
            tc.S.GUI.LaserControl = true;
            tc.S.GUIMeta.patternSel_CSminus.LaserOptions = true;
            tc.S.GUIMeta.patternSel_CSminus.LaserDefaults = struct('irradiances', [2 5 8], 'weights', [1 1 1]);
        end
    end

    methods (Test)
        function aDesignsOwnListWins(tc)
            design.laserIrradiances_mWmm2 = [4 6];
            design.laserWeights = [3 1];
            [irr, w] = lhf.laser.options(design, 'CSminus', tc.S);
            tc.verifyEqual(irr, [4 6]);
            tc.verifyEqual(w, [3 1]);
        end

        function aDesignWithoutAListUsesTheTypesDefaults(tc)
            design = struct('spots', struct('x', 512, 'y', 384));
            [irr, w] = lhf.laser.options(design, 'CSminus', tc.S);
            tc.verifyEqual(irr, [2 5 8]);
            tc.verifyEqual(w, [1 1 1]);
        end

        function aTypeWithoutLaserOptionsHasNone(tc)
            [irr, w] = lhf.laser.options(struct(), 'cue', tc.S);
            tc.verifyEmpty(irr);
            tc.verifyEmpty(w);
        end

        function badWeightsBecomeEqual(tc)
            design.laserIrradiances_mWmm2 = [4 6 9];
            for weights = {[1 1], [0 0 0], [1 -1 1]}
                design.laserWeights = weights{1};
                [~, w] = lhf.laser.options(design, 'CSminus', tc.S);
                tc.verifyEqual(w, [1 1 1]);
            end
        end

        function withoutTheLaserNothingIsDrawnOrQueued(tc)
            % Laser control off, or no laser connected: no power, no soft code 13
            design.laserIrradiances_mWmm2 = [4 6];
            design.laserWeights = [1 1];
            tc.verifyFalse(lhf.laser.isOn());
            [irr, setpoint, action] = lhf.laser.draw(design, 'CSminus', tc.S, struct());
            tc.verifyTrue(isnan(irr) && isnan(setpoint));
            tc.verifyEmpty(action);
        end

        function theTableShowsEachIrradianceWithItsProbability(tc)
            design.laserIrradiances_mWmm2 = [4 6];
            design.laserWeights = [3 1];
            tc.verifyEqual(lhf.laser.describe(design, 'CSminus', tc.S), '4 (0.75), 6 (0.25)');
            tc.verifyEqual(lhf.laser.describe(struct('spots', 1), 'CSminus', tc.S), '2, 5, 8 (equal)');  % the defaults
            design.laserIrradiances_mWmm2 = 3.5; design.laserWeights = 1;
            tc.verifyEqual(lhf.laser.describe(design, 'CSminus', tc.S), '3.5');
            tc.verifyEqual(lhf.laser.describe([], 'CSminus', tc.S), 'none');           % no design or a blank
            tc.verifyEqual(lhf.laser.describe(struct('spots', 1), 'cue', tc.S), 'none'); % no laser options
        end

        function noDesignDrawsNothing(tc)
            [irr, ~, action] = lhf.laser.draw([], 'CSplus', tc.S, struct());
            tc.verifyTrue(isnan(irr));
            tc.verifyEmpty(action);
        end

        function aSoftCodeSetsTheQueuedPower(tc)
            [laser, transport] = tc.fakeSessionLaser();
            global BpodSystem %#ok<GVMIS>
            BpodSystem.PluginObjects.LaserQueue = [4 12.5; 6 20];
            lhf.laser.onSoftCode();
            tc.verifyEqual(transport.SetpointW, 0.0125, 'AbsTol', 1e-12);
            tc.verifyEqual(BpodSystem.PluginObjects.LaserQueue, [6 20]);
            tc.verifyEqual(laser.CommandedPowermW, 12.5);
            logText = fileread([BpodSystem.Path.CurrentDataFile '_laser_log.txt']);
            tc.verifySubstring(logText, 'trial=1 irradiance=4.00 mW/mm^2 setpoint=12.5 mW');
            BpodSystem.Data.nTrials = 6;   % six recorded: the code came from trial 7
            lhf.laser.onSoftCode();
            tc.verifySubstring(fileread([BpodSystem.Path.CurrentDataFile '_laser_log.txt']), 'trial=7 ');
        end

        function aPowerAboveTheLimitIsLoggedNotThrown(tc)
            [~, transport] = tc.fakeSessionLaser();
            global BpodSystem %#ok<GVMIS>
            BpodSystem.PluginObjects.LaserQueue = [99 200];
            lhf.laser.onSoftCode();   % a soft-code callback must never throw
            tc.verifyEqual(transport.SetpointW, 0);
            logText = fileread([BpodSystem.Path.CurrentDataFile '_laser_log.txt']);
            tc.verifySubstring(logText, 'ERROR: 200 mW refused');
        end

        function closeKeepsTheRecordAndTurnsEmissionOff(tc)
            [~, transport] = tc.fakeSessionLaser();
            global BpodSystem %#ok<GVMIS>
            tc.verifyTrue(lhf.laser.isOn());
            lhf.laser.close();
            tc.verifyFalse(transport.Enabled);
            tc.verifyFalse(transport.isOpen());
            tc.verifyFalse(isfield(BpodSystem.PluginObjects, 'Laser'));
            tc.verifyEqual(BpodSystem.Data.Laser.Package, 'obis');
            tc.verifyEqual(BpodSystem.Data.Laser.Mode, 'Digital');
            tc.verifyTrue(isfield(BpodSystem.Data.Laser.statusAtEnd, 'OutputmW'));   % read before closing
            tc.verifyTrue(isfield(BpodSystem.Data.Laser, 'statusAtStart'));
            lhf.laser.close();   % nothing open: does nothing
        end

        function closeWithoutRecordLeavesTheData(tc)
            tc.fakeSessionLaser();
            global BpodSystem %#ok<GVMIS>
            lhf.laser.close(false);
            tc.verifyFalse(isfield(BpodSystem.Data, 'Laser'));
        end

        function irradianceRoundTripsThroughTheCalibration(tc)
            luminose = tc.rigConstants();
            [irr, setpoint] = irradianceCalibration(luminose);
            tc.verifyEqual(irradianceToSetpoint_mW(irr(3), luminose), setpoint(3), 'AbsTol', 1e-9);
            mid = mean(irr([3 4]));
            tc.verifyEqual(irradianceToSetpoint_mW(mid, luminose), mean(setpoint([3 4])), ...
                'AbsTol', 1e-9);
            tc.verifyError(@() irradianceToSetpoint_mW(max(irr) * 1.01, luminose), ...
                'obis:Calibration:outOfRange');
        end

        function spotGainScalesTheIrradiance(tc)
            luminose = tc.rigConstants();
            luminose.laser.spotGain = 1;
            irrFull = irradianceCalibration(luminose);
            luminose.laser.spotGain = 2;
            irrSpot = irradianceCalibration(luminose);
            tc.verifyEqual(irrSpot, 2 * irrFull, 'RelTol', 1e-12);
        end
    end

    methods (Access = private)
        function [laser, transport] = fakeSessionLaser(tc)
            % A connected simulated obis.Laser where lhf.laser.open would put it, in Digital
            % mode with emission on, and a data file in a temporary folder.
            global BpodSystem %#ok<GVMIS>
            saved = BpodSystem;
            tc.addTeardown(@() restoreBpod(saved));
            folder = tempname;
            mkdir(folder);
            tc.addTeardown(@() rmdir(folder, 's'));
            transport = obis.transport.SimulatedTransport();
            laser = obis.Laser('Transport', transport, 'MaxPowermW', 165);
            laser.connect();
            laser.setMode('Digital');
            laser.setEnabled(true);
            tc.addTeardown(@() delete(laser));
            BpodSystem = struct('PluginObjects', struct('Laser', laser), 'Data', struct(), ...
                'Path', struct('CurrentDataFile', fullfile(folder, 'session')));
        end

        function luminose = rigConstants(~)
            % The fields the calibration reads, from this repository and its config file.
            config = LuminoseConstants.readConfig();
            luminose.f.luminose_hf = fileparts(fileparts(mfilename('fullpath')));
            luminose.dmd.projectedDMDlength = config.dmd.projectedDMDlength;
            luminose.laser.spotGain = config.laser.spotGain;
        end
    end
end


function restoreBpod(saved)
% Puts back the BpodSystem global a test replaced.
global BpodSystem %#ok<GVMIS>
BpodSystem = saved;
end

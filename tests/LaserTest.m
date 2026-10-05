classdef LaserTest < matlab.unittest.TestCase
% Per-pattern laser power (lhf.laser.options, lhf.laser.draw) without a
% laser or Bpod: the connected path needs the rig.

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

        function noDesignDrawsNothing(tc)
            [irr, ~, action] = lhf.laser.draw([], 'CSplus', tc.S, struct());
            tc.verifyTrue(isnan(irr));
            tc.verifyEmpty(action);
        end
    end
end

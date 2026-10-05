classdef StageAlignmentTest < matlab.unittest.TestCase
% Automatic alignment to an animal's reference: lhf.cam.register,
% lhf.cam.fitStageCamera, lhf.cam.align and calibration/rigStages, on a
% synthetic sample seen through a simulated camera that ZaberStage's simulated
% X, Y and Z axes move (a known stage-camera matrix, defocus with Z, a fixed
% illumination profile).

    properties
        world        % the synthetic sample, larger than the camera's view
        transport    % zaberstage.transport.SimulatedTransport, three axes
        stages       % rigStages: x, y, z, close
        C            % camera px per stage um
        rotation = 0 % the sample's rotation now, deg (the reference is at 0)
        start = [20000 20000 25000]  % where the reference was taken, um
    end

    properties (Constant)
        FRAME = 384
    end

    methods (TestMethodSetup)
        function makeWorld(tc)
            rng(7);
            tc.world = imgaussfilt(randn(1100), 6);
            tc.world = tc.world - min(tc.world(:)) + 0.2;
            t = 47;
            tc.C = 0.634 * [cosd(t) sind(t); -sind(t) cosd(t)] * [1 0; 0 -1];
            tc.transport = zaberstage.transport.SimulatedTransport('StartHomed', true, ...
                'Devices', struct('Address', 1, 'Name', 'X-MCC3', 'SerialNumber', 1, 'AxisCount', 3));
            luminose.zaber = struct('port', "SIM", 'axes', struct('x', struct('device', 1, 'axis', 1), ...
                'y', struct('device', 1, 'axis', 2), 'z', struct('device', 1, 'axis', 3)));
            tc.stages = rigStages(luminose, tc.transport);
            tc.moveTo(tc.start);
        end
    end

    methods (TestMethodTeardown)
        function closeStages(tc)
            tc.stages.close();
        end
    end

    methods (Test)
        function aShiftAndRotationAreMeasuredDespiteTheIllumination(tc)
            reference = tc.frame();
            tc.rotation = 0.8;
            moved = tc.shifted([12.4 -7.6]);  % image shifted by (12.4, -7.6) px
            r = lhf.cam.register(reference, moved, 'Downsample', 2);
            tc.verifyTrue(r.ok);
            tc.verifyEqual(r.shiftPx, [12.4 -7.6], 'AbsTol', 0.6);
            tc.verifyEqual(r.rotationDeg, 0.8, 'AbsTol', 0.15);
            same = lhf.cam.register(reference, reference);
            tc.verifyEqual(same.shiftPx, [0 0], 'AbsTol', 0.1);
            tc.verifyEqual(same.similarity, 1, 'AbsTol', 1e-3);
        end

        function aBlankFrameIsNotConfident(tc)
            rng(2);
            r = lhf.cam.register(tc.frame(), uint16(1000 + 20 * randn(tc.FRAME)));
            tc.verifyFalse(r.ok);
        end

        function theStageCameraMatrixIsRecovered(tc)
            moves = [100 0; -100 0; 0 100; 0 -100];
            shifts = (tc.C * moves')' + 0.05 * [1 -1; -1 1; 1 1; -1 -1];
            cal = lhf.cam.fitStageCamera(moves, shifts);
            tc.verifyEqual(cal.C, tc.C, 'AbsTol', 1e-3);
            tc.verifyEqual(cal.pxPerUm, 0.634, 'AbsTol', 1e-3);
            tc.verifyEqual(cal.Cinv * cal.C, eye(2), 'AbsTol', 1e-12);
            tc.verifyError(@() lhf.cam.fitStageCamera([1 0; 2 0], [1 1; 2 2]), 'lhf:cam:badMoves');
        end

        function measuredShiftsGiveTheMatrix(tc)
            % as calibrate_stage_camera does it: move, register, fit
            reference = tc.frame();
            moves = [100 0; -100 0; 0 100; 0 -100];
            shifts = zeros(4, 2);
            for k = 1:4
                tc.moveTo(tc.start + [moves(k, :) 0]);
                r = lhf.cam.register(reference, tc.frame(), 'Downsample', 2);
                shifts(k, :) = r.shiftPx;
            end
            cal = lhf.cam.fitStageCamera(moves, shifts);
            tc.verifyEqual(cal.C, tc.C, 'AbsTol', 0.01);
        end

        function alignmentReturnsToTheReference(tc)
            reference = tc.frame();
            tc.moveTo(tc.start + [150 -110 40]);
            tc.rotation = 0.3;
            steps = {};
            options = struct('progress', @(info) recordStep(info));
            result = lhf.cam.align(@() tc.frame(), tc.stages, reference, tc.calibration(), options);
            tc.verifyEqual(result.status, 'aligned', result.message);
            tc.verifyEqual(result.endUm(1:2), tc.start(1:2), 'AbsTol', 2.5);
            tc.verifyEqual(result.endUm(3), tc.start(3), 'AbsTol', 6);
            tc.verifyEqual(result.rotationDeg, 0.3, 'AbsTol', 0.15);
            tc.verifyFalse(result.rotationWarning);
            tc.verifyEqual(result.startUm, tc.start + [150 -110 40]);
            tc.verifyEqual(unique(steps, 'stable'), {'coarse', 'z', 'fine'});
            function recordStep(info)
                steps{end + 1} = info.step;
            end
        end

        function aLargeRotationIsReportedNotCorrected(tc)
            reference = tc.frame();
            tc.moveTo(tc.start + [30 20 0]);
            tc.rotation = 2;
            result = lhf.cam.align(@() tc.frame(), tc.stages, reference, tc.calibration(), struct());
            tc.verifyTrue(result.rotationWarning);
            tc.verifySubstring(result.message, 're-seat');
        end

        function aBlankViewStopsWithoutMoving(tc)
            reference = tc.frame();
            rng(3);
            blank = @() uint16(1000 + 20 * randn(tc.FRAME));
            before = numel(tc.transport.callsOf('moveRelative')) + numel(tc.transport.callsOf('moveAbsolute'));
            result = lhf.cam.align(blank, tc.stages, reference, tc.calibration(), struct());
            tc.verifyEqual(result.status, 'failed');
            tc.verifySubstring(result.message, 'not confident');
            tc.verifyEqual(result.moves, 0);
            after = numel(tc.transport.callsOf('moveRelative')) + numel(tc.transport.callsOf('moveAbsolute'));
            tc.verifyEqual(after, before);
        end

        function aMoveOutsideTheTravelBoxIsRefused(tc)
            reference = tc.frame();
            tc.moveTo(tc.start + [150 0 0]);
            options = struct('maxTravelXY_um', 50, 'maxStep_um', 500);
            result = lhf.cam.align(@() tc.frame(), tc.stages, reference, tc.calibration(), options);
            tc.verifyEqual(result.status, 'failed');
            tc.verifySubstring(result.message, 'Refused');
            tc.verifyEqual(result.endUm, tc.start + [150 0 0]);
        end

        function declinedConfirmationMovesNothing(tc)
            reference = tc.frame();
            tc.moveTo(tc.start + [60 0 0]);
            asked = struct('moveUm', []);
            options = struct('confirm', @(info) decline(info));
            result = lhf.cam.align(@() tc.frame(), tc.stages, reference, tc.calibration(), options);
            tc.verifyEqual(result.status, 'cancelled');
            tc.verifyEqual(result.moves, 0);
            tc.verifyEqual(norm(asked.moveUm), 60, 'AbsTol', 3);
            function go = decline(info)
                asked = info;
                go = false;
            end
        end

        function stopEndsItBetweenMoves(tc)
            reference = tc.frame();
            tc.moveTo(tc.start + [150 -110 40]);
            frames = 0;
            options = struct('progress', @(~) count(), 'shouldStop', @() stopNow());
            result = lhf.cam.align(@() tc.frame(), tc.stages, reference, tc.calibration(), options);
            tc.verifyEqual(result.status, 'stopped');
            tc.verifyEqual(frames, 3);
            function count()
                frames = frames + 1;
            end
            function tf = stopNow()
                tf = frames >= 3;  % read now, not when the handle was made
            end
        end

        function rigStagesNeedsAllThreeAxes(tc)
            luminose.zaber = struct('port', "SIM", 'axes', struct('z', struct('device', 1, 'axis', 1)));
            tc.verifyError(@() rigStages(luminose, zaberstage.transport.SimulatedTransport()), 'rigStages:noAxes');
        end

        function rigStagesShareOnePort(tc)
            tc.verifyTrue(tc.transport.isOpen());
            tc.verifyEqual([tc.stages.x.AxisNumber tc.stages.y.AxisNumber tc.stages.z.AxisNumber], [1 2 3]);
            tc.stages.x.disconnect();
            tc.verifyTrue(tc.transport.isOpen());  % y and z still use it
        end
    end

    methods
        function cal = calibration(tc)
            moves = [100 0; 0 100; -100 0];
            cal = lhf.cam.fitStageCamera(moves, (tc.C * moves')');
        end

        function moveTo(tc, um)
            tc.stages.x.moveAbsolute(um(1));
            tc.stages.y.moveAbsolute(um(2));
            tc.stages.z.moveAbsolute(um(3));
        end

        function img = frame(tc)
            % What the camera sees at the stage's position now
            p = [tc.stages.x.positionUm(), tc.stages.y.positionUm(), tc.stages.z.positionUm()];
            img = tc.render((tc.C * (p(1:2) - tc.start(1:2))')', abs(p(3) - tc.start(3)));
        end

        function img = shifted(tc, shiftPx)
            img = tc.render(shiftPx, 0);
        end

        function img = render(tc, shiftPx, defocusUm)
            % The sample shifted by shiftPx in the image, rotated by tc.rotation about
            % the frame centre, blurred by defocus, under a fixed illumination, with noise
            n = tc.FRAME;
            centre = (n + 1) / 2;
            [qx, qy] = meshgrid(1:n, 1:n);
            dx = qx - centre - shiftPx(1);
            dy = qy - centre - shiftPx(2);
            t = -tc.rotation;
            wx = cosd(t) * dx - sind(t) * dy + 550;
            wy = sind(t) * dx + cosd(t) * dy + 550;
            sample = interp2(tc.world, wx, wy, 'linear', 0.2);
            if defocusUm > 0
                sample = imgaussfilt(sample, defocusUm / 10);
            end
            illumination = exp(-((qx - centre - 40) .^ 2 + (qy - centre + 30) .^ 2) / (2 * 150 ^ 2));
            img = uint16(4000 * sample .* illumination + 100 + 10 * randn(n));
        end
    end
end

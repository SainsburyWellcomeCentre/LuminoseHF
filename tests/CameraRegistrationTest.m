classdef CameraRegistrationTest < matlab.unittest.TestCase
% The camera-DMD calibration and fiducials (lhf.cam.*), lhf.spotImage and
% lhf.subjectName: synthetic points and frames, files in a temporary folder.

    properties
        folder
    end

    methods (TestMethodSetup)
        function makeFolder(tc)
            tc.folder = tempname;
            mkdir(tc.folder);
        end
    end

    methods (TestMethodTeardown)
        function removeFolder(tc)
            rmdir(tc.folder, 's');
        end
    end

    methods (Test)
        function theFitRecoversAnAffineMapAndItsInverse(tc)
            A = rigLikeMap();
            [gx, gy] = meshgrid(80:200:944, 80:150:688);
            dmdXY = [gx(:), gy(:)];
            camXY = [dmdXY, ones(size(dmdXY, 1), 1)] * A;
            reg = lhf.cam.fitRegistration(dmdXY, camXY);
            tc.verifyEqual(reg.A, A, 'AbsTol', 1e-9);
            tc.verifyLessThan(reg.rmsPx, 1e-9);
            p = [512 384; 3 700];
            tc.verifyEqual(lhf.cam.toDmd(reg, lhf.cam.toCamera(reg, p)), p, 'AbsTol', 1e-9);
        end

        function noisyPointsGiveTheirResidual(tc)
            A = rigLikeMap();
            dmdXY = [100 100; 900 100; 900 700; 100 700; 500 400];
            camXY = [dmdXY, ones(5, 1)] * A;
            camXY(5, :) = camXY(5, :) + [3 4];  % one point 5 px off
            reg = lhf.cam.fitRegistration(dmdXY, camXY);
            tc.verifyGreaterThan(reg.residualPx(5), 1);
            tc.verifyEqual(reg.rmsPx, sqrt(mean(reg.residualPx .^ 2)), 'AbsTol', 1e-12);
        end

        function pointsOnALineAreRefused(tc)
            tc.verifyError(@() lhf.cam.fitRegistration([1 1; 2 2; 3 3], [1 1; 2 2; 3 3]), 'lhf:cam:badPoints');
            tc.verifyError(@() lhf.cam.fitRegistration([1 1; 2 2], [1 1; 2 2]), 'lhf:cam:badPoints');
        end

        function theCanvasShowsTheCameraPixelUnderEachDmdPoint(tc)
            reg = lhf.cam.fitRegistration([0 0; 1024 0; 0 768], [0 0; 1024 0; 0 768] * 1.3 + 40);
            camSize = [1100 1400];
            [cx, cy] = meshgrid(1:camSize(2), 1:camSize(1));
            frame = uint16(cx + 2000 * (cy > 600));  % column number, plus a mark below row 600
            map = lhf.cam.canvasMap(reg, camSize, [384 512], 2);
            img = lhf.cam.toCanvas(frame, map);
            tc.verifyClass(img, 'uint16');
            tc.verifySize(img, [384 512]);
            % canvas pixel (i, j) is DMD ((j - 0.5) * 2, (i - 0.5) * 2)
            i = 100; j = 300;
            cam = lhf.cam.toCamera(reg, [(j - 0.5) * 2, (i - 0.5) * 2]);
            tc.verifyEqual(double(img(i, j)), round(cam(1)) + 2000 * (round(cam(2)) > 600));
        end

        function canvasPixelsOutsideTheFrameAreZero(tc)
            reg = lhf.cam.fitRegistration([0 0; 1024 0; 0 768], [0 0; 1024 0; 0 768] + 500);
            map = lhf.cam.canvasMap(reg, [800 800], [384 512], 2);
            tc.verifyEqual(map(1, 1) > 0, true);  % DMD (1,1) -> camera (501,501)
            tc.verifyEqual(map(end, end), 0);     % camera (1523,1267): outside
            img = lhf.cam.toCanvas(ones(800, 800, 'uint16'), map);
            tc.verifyEqual(img(end, end), uint16(0));
        end

        function aSpotIsFoundAndDustElsewhereIgnored(tc)
            [x, y] = meshgrid(1:300, 1:200);
            background = 100 * ones(200, 300);
            frame = background + 3000 * exp(-((x - 120.4) .^ 2 + (y - 80.7) .^ 2) / (2 * 3 ^ 2));
            frame(10:11, 280:281) = frame(10:11, 280:281) + 2000;  % dust, not connected to the spot
            xy = lhf.cam.spotCentroid(uint16(frame), uint16(background));
            tc.verifyEqual(xy, [120.4 80.7], 'AbsTol', 0.05);
        end

        function noSpotIsAnError(tc)
            rng(1);
            background = uint16(100 + 5 * randn(100));
            tc.verifyError(@() lhf.cam.spotCentroid(background, background), 'lhf:cam:noSpot');
        end

        function theNewestCalibrationIsLoaded(tc)
            tc.verifyEmpty(lhf.cam.loadRegistration(tc.folder));
            registration = struct('rmsPx', 1); %#ok<NASGU>
            save(fullfile(tc.folder, 'camera_dmd_20261005_120000.mat'), 'registration');
            registration = struct('rmsPx', 2); %#ok<NASGU>
            save(fullfile(tc.folder, 'camera_dmd_20260101_120000.mat'), 'registration');
            reg = lhf.cam.loadRegistration(tc.folder);
            tc.verifyEqual(reg.rmsPx, 1);
            tc.verifyEqual(reg.file, fullfile(tc.folder, 'camera_dmd_20261005_120000.mat'));
        end

        function theFirstFiducialStaysTheReference(tc)
            file = lhf.cam.fiducialFile(tc.folder, 'LHF 01/a');
            tc.verifyEqual(file, fullfile(tc.folder, 'fiducials', 'LHF_01_a.mat'));
            tc.verifyEmpty(lhf.cam.loadFiducial(file));
            first = fiducialEntry(10, [100 200]);
            fid = lhf.cam.saveFiducial(file, first);
            tc.verifyEqual(fid.reference.xy, [100 200]);
            fid = lhf.cam.saveFiducial(file, fiducialEntry(20, [110 190]));
            tc.verifyNumElements(fid.sessions, 2);
            loaded = lhf.cam.loadFiducial(file);
            tc.verifyEqual(loaded.reference.frame, first.frame);
            tc.verifyEqual(loaded.sessions(2).xy, [110 190]);
            tc.verifyEqual(loaded.animal, 'LHF_01_a');
            tc.verifyNotEmpty(loaded.reference.time);
        end

        function aFiducialNeedsAnAnimal(tc)
            tc.verifyError(@() lhf.cam.fiducialFile(tc.folder, '  '), 'lhf:cam:noAnimal');
        end

        function aDesignBecomesOneDmdFrame(tc)
            spots = struct('x', {10, 1023}, 'y', {20, 2});
            img = lhf.spotImage(spots, 3, [768 1024]);
            tc.verifyClass(img, 'logical');
            tc.verifyEqual(nnz(img(17:23, 7:13)), 49);
            tc.verifyEqual(nnz(img), 49 + 5 * 5);  % the second clipped at the top and right edges
            tc.verifyEqual(nnz(lhf.spotImage(spots([]), 3, [768 1024])), 0);
        end

        function theSubjectComesFromBpod(tc)
            global BpodSystem
            saved = BpodSystem;
            restore = onCleanup(@() setBpod(saved));
            BpodSystem = struct('GUIData', struct('SubjectName', 'M12'));
            tc.verifyEqual(lhf.subjectName(), 'M12');
            BpodSystem = [];
            tc.verifyEqual(lhf.subjectName(), '');
        end
    end
end


function A = rigLikeMap()
% 1.365 camera px per DMD px, rotated 47 deg and mirrored, offset into a 2048 sensor
    t = 47;
    R = 1.365 * [cosd(t) sind(t); -sind(t) cosd(t)] * [1 0; 0 -1];
    A = [R; 300 1500];
end

function entry = fiducialEntry(value, xy)
    entry = struct('frame', value * ones(40, 50, 'uint16'), 'xy', xy, 'exposureMs', 2, ...
        'roi', [0 0 50 40], 'registrationFile', '');
end

function setBpod(value)
    global BpodSystem
    BpodSystem = value;
end

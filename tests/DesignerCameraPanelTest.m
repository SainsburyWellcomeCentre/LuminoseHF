classdef DesignerCameraPanelTest < matlab.unittest.TestCase
% The Pattern Designer's camera column (gui/DesignerCameraPanel) in an
% invisible figure, on HamamatsuCam's simulated camera and a FakeDmd.

    properties
        folder
        fig
        ax
        camera
        dmd
        background = []   % the last setBackground(img, clim)
        backgroundLimits = []
        redraws = 0
        allowDmd = true
        extraOptions = struct()  % options a test adds to makePanel's
    end

    methods (TestMethodSetup)
        function setUp(tc)
            tc.folder = tempname;
            mkdir(tc.folder);
            tc.fig = figure('Visible', 'off', 'Position', [0 0 1450 760]);
            tc.ax = axes('Parent', tc.fig, 'Units', 'pixels', 'Position', [15 180 512 384], 'NextPlot', 'add');
            tc.camera = hamacam.Camera('Transport', hamacam.transport.SimulatedTransport('Resolution', [1400 1100]));
            tc.dmd = FakeDmd();
        end
    end

    methods (TestMethodTeardown)
        function tearDown(tc)
            if isvalid(tc.fig), delete(tc.fig); end
            if isvalid(tc.camera), tc.camera.disconnect(); end
            rmdir(tc.folder, 's');
        end
    end

    methods (Test)
        function withoutACalibrationTheCameraStaysOff(tc)
            panel = tc.makePanel([]);
            tc.verifyEqual(panel.Controls.Live.Enable, 'off');
            tc.verifyEqual(panel.Controls.Capture.Enable, 'off');
            tc.verifySubstring(strjoin(cellstr(panel.Controls.Calibration.String)), 'calibrate_camera_dmd');
            panel.capture();
            tc.verifyEmpty(panel.Camera);
            tc.verifyEmpty(tc.background);
        end

        function aCaptureBecomesTheCanvas(tc)
            panel = tc.makePanel(tc.registration());
            tc.verifyEqual(panel.Controls.Live.Enable, 'on');
            panel.capture();
            tc.verifyEqual(panel.Camera.State, 'Ready');
            tc.verifyEqual(panel.Camera.ExposureMs, 3);
            tc.verifySize(tc.background, [384 512]);
            tc.verifyClass(tc.background, 'uint16');
            tc.verifyGreaterThan(diff(tc.backgroundLimits), 0);
            tc.verifyNotEmpty(panel.Controls.Stats.String);
        end

        function draggedLimitsTurnAutoOff(tc)
            panel = tc.makePanel(tc.registration());
            panel.capture();
            panel.setLimits([500 100]);
            tc.verifyEqual(tc.backgroundLimits, [100 500]);
            tc.verifyFalse(logical(panel.Controls.Auto.Value));
            tc.verifyEqual(panel.Controls.HighLine.XData, [500 500]);
            tc.verifyEqual(panel.Controls.Low.String, '100');
            panel.capture();  % a new frame keeps them
            tc.verifyEqual(tc.backgroundLimits, [100 500]);
        end

        function liveShowsFramesUntilStopped(tc)
            panel = tc.makePanel(tc.registration());
            panel.setLive(true);
            tc.verifyTrue(logical(panel.Controls.Live.Value));
            pause(0.5);
            panel.setLive(false);
            tc.verifyFalse(logical(panel.Controls.Live.Value));
            tc.verifyNotEmpty(panel.Frame);
        end

        function theDmdShowsWhatIsChosen(tc)
            panel = tc.makePanel(tc.registration());
            tc.verifyEmpty(panel.Dmd);  % not connected until asked
            panel.setDmdMode('allOn');
            tc.verifyEqual(tc.dmd.LastFrame, true(768, 1024));
            panel.setDmdMode('pattern');
            tc.verifyEqual(nnz(tc.dmd.LastFrame), 9);  % patternImage: one 3x3 spot
            panel.patternChanged();
            tc.verifyEqual(nnz(strcmp(tc.dmd.Calls, 'displayFrame')), 3);
            panel.setDmdMode('dark');
            tc.verifyEqual(tc.dmd.Calls{end}, 'halt');
        end

        function aRunningSessionKeepsTheDmd(tc)
            tc.allowDmd = false;
            panel = tc.makePanel(tc.registration());
            tc.verifyEqual(panel.Controls.DmdMode.Enable, 'off');
            panel.setDmdMode('allOn');
            tc.verifyEmpty(panel.Dmd);
            tc.verifyEmpty(tc.dmd.Calls);
        end

        function theFirstSavedFiducialIsTheReference(tc)
            panel = tc.makePanel(tc.registration());
            panel.setAnimal('M7');
            tc.verifySubstring(panel.Controls.FiducialInfo.String, 'No fiducial');
            tc.verifyFalse(panel.handleClick(100, 100));  % not placing: the designer keeps the click
            panel.Controls.Place.Value = true;
            panel.Controls.Place.Callback(panel.Controls.Place, []);
            tc.verifyTrue(panel.handleClick(100, 50));
            reg = tc.registration();
            tc.verifyEqual(panel.MarkXY, lhf.cam.toCamera(reg, [200 100]), 'AbsTol', 1e-9);
            panel.saveFiducial();
            tc.verifyEmpty(panel.LastError);
            fid = lhf.cam.loadFiducial(lhf.cam.fiducialFile(tc.folder, 'M7'));
            tc.verifyEqual(fid.reference.xy, lhf.cam.toCamera(reg, [200 100]), 'AbsTol', 1e-9);
            tc.verifySize(fid.reference.frame, [1100 1400]);
            tc.verifyEmpty(panel.MarkXY);

            panel.Controls.Place.Value = true;
            panel.Controls.Place.Callback(panel.Controls.Place, []);
            panel.handleClick(120, 60);
            panel.saveFiducial();
            fid = lhf.cam.loadFiducial(lhf.cam.fiducialFile(tc.folder, 'M7'));
            tc.verifyNumElements(fid.sessions, 2);
            tc.verifyEqual(fid.reference.xy, lhf.cam.toCamera(reg, [200 100]), 'AbsTol', 1e-9);
            tc.verifySubstring(panel.Controls.FiducialInfo.String, '2 session');
        end

        function savingWithoutAMarkIsRefused(tc)
            panel = tc.makePanel(tc.registration());
            panel.setAnimal('M7');
            panel.saveFiducial();
            tc.verifySubstring(panel.LastError, 'Place the mark');
            tc.verifyFalse(isfile(lhf.cam.fiducialFile(tc.folder, 'M7')));
        end

        function theReferenceMarkIsDrawnOnTheCanvas(tc)
            reg = tc.registration();
            lhf.cam.saveFiducial(lhf.cam.fiducialFile(tc.folder, 'M7'), struct('frame', ...
                zeros(1100, 1400, 'uint16'), 'xy', lhf.cam.toCamera(reg, [400 300]), 'exposureMs', 2, ...
                'roi', [0 0 1400 1100], 'registrationFile', ''));
            panel = tc.makePanel(reg);
            panel.setAnimal('M7');
            cla(tc.ax);
            panel.drawOverlay(tc.ax);
            marker = findobj(tc.ax, 'Type', 'line', 'Marker', 'o');
            tc.verifyEqual([marker.XData marker.YData], [200 150], 'AbsTol', 1e-9);
            panel.Controls.ShowRef.Value = false;
            cla(tc.ax);
            panel.drawOverlay(tc.ax);
            tc.verifyEmpty(findobj(tc.ax, 'Type', 'line'));
        end

        function alignmentNeedsItsCalibrationsAndAReference(tc)
            panel = tc.makePanel(tc.registration());
            tc.verifyEqual(panel.Controls.Align.Enable, 'off');
            tc.verifySubstring(panel.Controls.AlignInfo.String, 'stage-camera calibration');
            tc.extraOptions = struct('stageCalibration', lhf.cam.fitStageCamera([1 0; 0 1], [1 0; 0 1]), ...
                'stagesConfigured', true);
            panel = tc.makePanel(tc.registration());
            panel.setAnimal('M8');
            tc.verifySubstring(panel.Controls.AlignInfo.String, 'reference first');
            panel.alignToReference();
            tc.verifyEmpty(panel.Stages);  % refused before connecting anything
        end

        function alignToReferenceMovesTheStageAndSavesTheSession(tc)
            world = StageAlignmentTest;  % its synthetic sample, camera and stages
            world.makeWorld();
            tc.addTeardown(@() world.closeStages());
            file = lhf.cam.fiducialFile(tc.folder, 'M9');
            lhf.cam.saveFiducial(file, struct('frame', world.frame(), 'xy', [190 190]));
            world.moveTo(world.start + [60 -40 20]);

            tc.camera = hamacam.Camera('Transport', hamacam.transport.SimulatedTransport( ...
                'Resolution', [world.FRAME world.FRAME], 'FrameFcn', @(~, ~, ~) world.frame()));
            reg = lhf.cam.fitRegistration([0 0; 1024 0; 0 768], [0 0; 1024 0; 0 768] * 0.35 + 6);
            tc.extraOptions = struct('stageCalibration', world.calibration(), 'stagesConfigured', true, ...
                'makeStages', @() world.stages);
            panel = tc.makePanel(reg);
            panel.setAnimal('M9');
            tc.verifyEqual(panel.Controls.Align.Enable, 'on');
            panel.alignToReference();

            tc.verifyEqual(panel.LastAlignment.status, 'aligned', panel.LastAlignment.message);
            tc.verifyEqual(panel.LastAlignment.endUm, world.start, 'AbsTol', 6);
            tc.verifyEqual(panel.Controls.Align.String, 'Align to reference');
            tc.verifySubstring(panel.Controls.AlignInfo.String, 'Aligned');
            tc.verifyNotEmpty(tc.background);  % frames were shown on the canvas
            fid = lhf.cam.loadFiducial(file);
            tc.verifyNumElements(fid.sessions, 2);
            tc.verifyEqual(fid.sessions(2).stageUm, panel.LastAlignment.endUm);
            tc.verifyEqual(fid.sessions(2).alignment.status, 'aligned');
            tc.verifyEmpty(fid.reference.stageUm);  % saved before the field existed: filled empty
        end

        function closingTheFigureReleasesTheDevices(tc)
            panel = tc.makePanel(tc.registration());
            panel.capture();
            panel.setDmdMode('allOn');
            delete(tc.fig);
            tc.verifyEqual(tc.camera.State, 'Disconnected');
            tc.verifyEqual(tc.dmd.Calls(end-1:end), {'halt', 'disconnect'});
        end
    end

    methods
        function panel = makePanel(tc, reg)
            hooks = struct('setBackground', @(img, clim) tc.recordBackground(img, clim), ...
                'patternImage', @() lhf.spotImage(struct('x', 50, 'y', 60), 1, [768 1024]), ...
                'redraw', @() tc.countRedraw());
            options = struct('calibrationFolder', tc.folder, 'registration', reg, ...
                'makeCamera', @() tc.connectedCamera(), 'makeDmd', @() tc.dmd, ...
                'dmdAllowed', @() tc.allowDmd, 'exposureMs', 3, 'averageFrames', 2, 'animal', '', ...
                'stagesConfigured', false, 'alignment', LuminoseConstants.alignmentDefaults(), ...
                'confirm', @(~) true);
            for name = fieldnames(tc.extraOptions)'
                options.(name{1}) = tc.extraOptions.(name{1});
            end
            canvas = struct('axes', tc.ax, 'scale', 2, 'size', [384 512], 'dmdSize', [768 1024]);
            panel = DesignerCameraPanel(tc.fig, [1015 0], canvas, hooks, options);
        end

        function camera = connectedCamera(tc)
            tc.camera.connect();
            camera = tc.camera;
        end

        function recordBackground(tc, img, clim)
            tc.background = img;
            tc.backgroundLimits = clim;
        end

        function countRedraw(tc)
            tc.redraws = tc.redraws + 1;
        end
    end

    methods (Static)
        function reg = registration()
            % The 1024x768 DMD field inside the 1400x1100 simulated sensor, scaled 1.3
            reg = lhf.cam.fitRegistration([0 0; 1024 0; 0 768], [0 0; 1024 0; 0 768] * 1.3 + 20);
        end
    end
end

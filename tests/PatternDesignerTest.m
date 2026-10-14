classdef PatternDesignerTest < matlab.unittest.TestCase
% The Pattern Designer (gui/PatternDesigner) drawing on the camera's own panel
% (hamacam.gui.CameraApp on HamamatsuCam's simulated camera), with a known
% camera-DMD calibration and a FakeDmd: spots placed by clicks on the camera
% image land at the DMD pixels the calibration says, are drawn where they land,
% stay right after a subarray and binning change, and save as before; plus
% Show on DMD, and the fiducial, alignment and stage controls.

    properties
        folder
        camera
        app
        dmd
        designer
        allowDmd = true
        extraOptions = struct()   % options a test adds to makeDesigner's
        panelsOpened = {}         % the panels the designer asked for (openPanel)
        savedGlobals
        tissueShift = [0 0]       % how far the textured tissue has moved on the sensor, px
    end

    methods (TestMethodSetup)
        function setUp(tc)
            tc.folder = tempname;
            mkdir(tc.folder);
            tc.savedGlobals = PatternDesignerTest.swapGlobals(struct( ...
                'luminose', struct('dmd', struct('spotSide', 0.05, 'projectedDMDlength', 2.56, ...
                    'patternsFolder', string(fullfile(tc.folder, 'patterns'))), ...
                    'f', struct('luminoseData', string(tc.folder))), ...
                'S', struct('GUI', struct()), 'BpodSystem', struct()));
            tc.addTeardown(@() PatternDesignerTest.swapGlobals(tc.savedGlobals));
            tc.useCamera(hamacam.transport.SimulatedTransport('Resolution', [1400 1100]));
            tc.dmd = FakeDmd();
        end
    end

    methods (TestMethodTeardown)
        function tearDown(tc)
            if ~isempty(tc.designer) && isvalid(tc.designer), delete(tc.designer); end
            if ~isempty(tc.app) && isvalid(tc.app), tc.app.close(); end
            if ~isempty(tc.camera) && isvalid(tc.camera), tc.camera.disconnect(); end
            rmdir(tc.folder, 's');
        end
    end

    methods (Test)
        % ------------------------------------------------------------ placing spots
        function aClickPlacesASpotWhereTheDmdLightsIt(tc)
            d = tc.makeDesigner(tc.registration());
            tc.verifySameHandle(d.CameraPanel, tc.app);
            tc.click([200 100]);
            tc.verifyEqual([d.Spots.x d.Spots.y], [200 100]);
            tc.verifyEqual(d.Controls.Table.Data(1, 2:3), {200, 100});
        end

        function theSpotIsDrawnWhereItLands(tc)
            d = tc.makeDesigner(tc.registration());
            tc.click([200 100]);
            spot = tc.spotPatches();
            tc.verifyNumElements(spot, 1);
            % full sensor, binning 1: frame px are sensor px
            expected = lhf.cam.toCamera(tc.registration(), d.square(200, 100));
            tc.verifyEqual([spot.XData spot.YData], expected, 'AbsTol', 1e-9);
            field = findobj(tc.app.Controls.Image, 'Type', 'line', 'LineStyle', '--');
            tc.verifyNotEmpty(field);  % the DMD field's outline
        end

        function aSubarrayAndBinningKeepTheSpotsOnTheTissue(tc)
            d = tc.makeDesigner(tc.registration());
            tc.click([200 100]);
            tc.camera.Binning = 2;
            tc.camera.setRoi([100 40 400 300]);
            tc.app.capture();
            spot = tc.spotPatches();
            expected = tc.camera.sensorToFrame(lhf.cam.toCamera(tc.registration(), d.square(200, 100)));
            tc.verifyEqual([spot.XData spot.YData], expected, 'AbsTol', 1e-9);
            tc.verifySize(tc.app.Frame, [300 400]);
            tc.click([500 400]);  % through the binned subarray
            tc.verifyEqual([d.Spots(2).x d.Spots(2).y], [500 400]);
        end

        function aRightClickRemovesTheNearestSpot(tc)
            d = tc.makeDesigner(tc.registration());
            tc.click([200 100]);
            tc.click([600 400]);
            tc.click([603 398], 'alt');
            tc.verifyEqual([d.Spots.x d.Spots.y], [200 100]);
            tc.click([900 700], 'alt');  % nothing there
            tc.verifyNumElements(d.Spots, 1);
        end

        function overlappingAndExtraSpotsAreRefused(tc)
            d = tc.makeDesigner(tc.registration());
            tc.click([200 100]);
            tc.click([205 100]);  % within 2 r_px
            tc.verifyNumElements(d.Spots, 1);
            tc.verifySubstring(d.LastMessage, 'overlap');
            tc.click([400 100]);
            tc.click([600 100]);
            tc.click([800 100]);  % nSpots is 3
            tc.verifyNumElements(d.Spots, 3);
            tc.verifySubstring(d.LastMessage, 'nSpots');
        end

        function aClickOutsideTheDmdFieldIsIgnored(tc)
            d = tc.makeDesigner(tc.registration());
            tc.app.clickAt([5 5], 'normal');  % the field starts at camera px 20
            tc.verifyEmpty(d.Spots);
            tc.verifySubstring(d.LastMessage, 'Outside the DMD field');
        end

        function gridClicksToggleCells(tc)
            d = tc.makeDesigner(tc.registration());
            d.setMode('grid');
            tc.click([100 100]);
            tc.verifyNumElements(d.Spots, 1);
            tc.verifyEqual(nnz(d.GridSelected), 1);
            spot = d.Spots(1);
            tc.click([spot.x spot.y]);  % the same cell again
            tc.verifyEmpty(d.Spots);
            tc.click([500 400]);
            grid = findobj(tc.app.Controls.Image, 'Type', 'patch');
            tc.verifyNumElements(grid, 2);  % empty cells, selected cells
        end

        function withoutACalibrationPlacementIsRefused(tc)
            d = tc.makeDesigner([]);
            tc.verifyEmpty(d.Registration);
            tc.verifySameHandle(d.CameraPanel, tc.app);  % open, to look and focus
            tc.verifyEmpty(findobj(tc.app.Controls.Image, 'Type', 'line', 'LineStyle', '--'));  % nothing drawn
            tc.verifySubstring(d.Controls.Calibration.String, 'calibrate_camera_dmd');
            tc.app.clickAt([700 550], 'normal');  % not the designer's
            d.onCameraClick([700 550], 'normal');
            tc.verifyEmpty(d.Spots);
        end

        function theLaserAndStagePanelsOpenWithIt(tc)
            d = tc.makeDesigner(tc.registration());
            tc.verifyEqual(tc.panelsOpened, {'laser', 'stage'});
            tc.verifyEqual(d.LaserPanel, 'laser panel');
            tc.verifyEqual(d.StagePanel, 'stage panel');
            d.Controls.OpenCamera.Callback(d.Controls.OpenCamera, []);  % Device panels
            tc.verifyEqual(tc.panelsOpened, {'laser', 'stage', 'laser', 'stage'});
        end

        % ------------------------------------------------------------ saving
        function saveWritesTheDesignAsBefore(tc)
            global S BpodSystem luminose %#ok<GVMIS> what the designer writes
            S.GUI.patternNFrames_cue = 0;
            S.GUI.patternExposure_cue = 0;
            d = tc.makeDesigner(tc.registration());
            tc.click([200 100]);
            tc.click([600 400]);
            d.Controls.TickMs.String = '50';
            design = d.savePattern();
            tc.verifyEqual(fieldnames(design)', {'spots', 'tickMs', 'r_px', 'nF'});
            tc.verifyEqual([design.spots.x], [200 600]);
            tc.verifyEqual(design.r_px, 10);  % 0.05 mm of 2.56 mm across 1024 px, halved
            tc.verifyEqual(design.nF, 4);     % 200 ms at 50 ms
            tc.verifyEqual(BpodSystem.PluginObjects.PatternDesigns.cue{1}, design);
            tc.verifyEqual(S.GUI.patternNFrames_cue, 4);
            tc.verifyEqual(S.GUI.patternExposure_cue, 50000);
            loaded = lhf.patternDesign(struct(), luminose.dmd, 'cue', 1);
            tc.verifyEqual([loaded.spots.y], [100 400]);
            tc.verifyEqual(loaded.r_px, 10);
            tc.verifyFalse(isvalid(d.Figure));  % closed
        end

        function aSavedDesignOpensAgain(tc)
            d = tc.makeDesigner(tc.registration());
            tc.click([300 300]);
            d.savePattern();
            tc.designer = [];
            again = tc.makeDesigner(tc.registration());
            tc.verifyEqual([again.Spots.x again.Spots.y], [300 300]);
            tc.verifyNumElements(tc.spotPatches(), 1);
        end

        function closingTakesTheDesignOffTheCamera(tc)
            d = tc.makeDesigner(tc.registration());
            tc.click([200 100]);
            d.close();
            tc.verifyTrue(isvalid(tc.app));  % the camera panel stays open
            tc.verifyEmpty(tc.spotPatches());
            tc.app.clickAt([300 300], 'normal');  % no longer the designer's
            tc.verifyNumElements(d.Spots, 1);
        end

        % ------------------------------------------------------------ the DMD
        function showOnDmdProjectsEveryChangeAndHaltsOnClose(tc)
            d = tc.makeDesigner(tc.registration());
            tc.click([200 100]);
            tc.verifyEmpty(tc.dmd.Calls);  % nothing until asked
            d.setShowOnDmd(true);
            tc.verifyEqual(tc.dmd.LastFrame, lhf.spotImage(d.Spots, 10, [768 1024]));
            tc.verifyEqual(nnz(tc.dmd.LastFrame), 21^2);
            tc.click([600 400]);
            tc.verifyEqual(nnz(tc.dmd.LastFrame), 2 * 21^2);
            d.setShowOnDmd(false);
            tc.verifyEqual(tc.dmd.Calls{end}, 'halt');
            d.setShowOnDmd(true);
            d.close();
            tc.verifyEqual(tc.dmd.Calls{end}, 'halt');
            tc.verifyFalse(any(strcmp(tc.dmd.Calls, 'disconnect')));
        end

        function dmdAllOnLightsTheWholeFieldForTheFiducial(tc)
            d = tc.makeDesigner(tc.registration());
            d.setDmdAllOn(true);
            tc.verifyEqual(tc.dmd.LastFrame, true(768, 1024));
            tc.click([200 100]);  % a spot added: the field stays all on
            tc.verifyEqual(tc.dmd.LastFrame, true(768, 1024));
            d.setShowOnDmd(true);  % one or the other
            tc.verifyFalse(d.DmdAllOn);
            tc.verifyFalse(logical(d.Controls.AllOn.Value));
            tc.verifyEqual(nnz(tc.dmd.LastFrame), 21^2);
            d.setDmdAllOn(true);
            tc.verifyFalse(d.ShowOnDmd);
            d.setDmdAllOn(false);
            tc.verifyEqual(tc.dmd.Calls{end}, 'halt');
            d.placeMark(true);  % lights the field to find the landmark
            tc.verifyTrue(d.DmdAllOn);
            tc.verifyEqual(tc.dmd.LastFrame, true(768, 1024));
            d.close();
            tc.verifyEqual(tc.dmd.Calls{end}, 'halt');
        end

        function theGridFillButtonsAreGone(tc)
            d = tc.makeDesigner(tc.registration());
            labels = get(findobj(d.Figure, 'Style', 'pushbutton'), 'String');
            tc.verifyEmpty(intersect(labels, {'Left Half', 'Right Half', 'Checker A', 'Checker B'}));
        end

        function aRunningSessionKeepsTheDmd(tc)
            tc.allowDmd = false;
            d = tc.makeDesigner(tc.registration());
            tc.verifyEqual(d.Controls.ShowDmd.Enable, 'off');
            tc.verifyEqual(d.Controls.AllOn.Enable, 'off');
            d.setDmdAllOn(true);
            tc.verifyFalse(d.DmdAllOn);
            d.setShowOnDmd(true);
            tc.verifyFalse(d.ShowOnDmd);
            tc.verifyEmpty(tc.dmd.Calls);
            tc.verifySubstring(d.LastError, 'session');
        end

        % ------------------------------------------------------------ fiducial
        function theFirstSavedFiducialIsTheReference(tc)
            d = tc.makeDesigner(tc.registration());
            d.setAnimal('M7');
            widefield = fullfile(tc.folder, 'M7', 'luminose_hf_widefield');
            tc.verifyEqual(tc.app.SaveFolder, widefield);  % the camera saves into the animal's
            tc.verifyTrue(isfolder(widefield));
            tc.verifySubstring(d.Controls.FiducialInfo.String, 'No fiducial');
            d.placeMark(true);
            tc.click([200 100]);
            tc.verifyEmpty(d.Spots);  % the click placed the mark, not a spot
            reg = tc.registration();
            tc.verifyEqual(d.MarkXY, lhf.cam.toCamera(reg, [200 100]), 'AbsTol', 1e-9);
            d.saveFiducial();
            tc.verifyEmpty(d.LastError);
            fid = lhf.cam.loadFiducial(lhf.cam.fiducialFile(tc.calibration(), 'M7'));
            tc.verifyEqual(fid.reference.xy, lhf.cam.toCamera(reg, [200 100]), 'AbsTol', 1e-9);
            tc.verifySize(fid.reference.frame, [1100 1400]);
            tc.verifyEqual(fid.reference.binning, 1);
            tc.verifyEqual(double(fid.reference.roi), [0 0 1400 1100]);
            tc.verifyEmpty(d.MarkXY);

            d.placeMark(true);
            tc.click([220 110]);
            d.saveFiducial();
            fid = lhf.cam.loadFiducial(lhf.cam.fiducialFile(tc.calibration(), 'M7'));
            tc.verifyNumElements(fid.sessions, 2);
            tc.verifyEqual(fid.reference.xy, lhf.cam.toCamera(reg, [200 100]), 'AbsTol', 1e-9);
            tc.verifySubstring(d.Controls.FiducialInfo.String, '2 session');
        end

        % ------------------------------------------------------------ targets
        function targetsNeedTheReferenceFiducial(tc)
            d = tc.makeDesigner(tc.registration());
            d.setAnimal('M9');
            d.setMarkTargets(true);
            tc.verifyFalse(d.MarkingTargets);
            tc.verifySubstring(d.LastError, 'fiducial first');
        end

        function targetsAreMarkedSavedAndFoundAgainAfterAMove(tc)
            tc.useTissue();
            reg = tc.registration();
            d = tc.makeDesigner(reg);
            d.setAnimal('M7');
            d.placeMark(true);
            tc.click([200 100]);
            d.saveFiducial();                       % the reference: this view of the tissue
            d.setMarkTargets(true);                 % locates on the reference first
            tc.verifyTrue(d.MarkingTargets);
            tc.click([300 200]);
            tc.click([500 400]);
            tc.click([520 380]);
            tc.verifyEqual({d.Targets.name}, {'G1', 'G2', 'G3'});
            tc.verifyEmpty(d.Spots);                % marking adds targets, not spots
            tc.verifyEqual(d.Targets(1).xy, lhf.cam.toCamera(reg, [300 200]), 'AbsTol', 0.5);
            tc.click([521 381], 'alt');             % removes the nearest
            tc.verifyEqual({d.Targets.name}, {'G1', 'G2'});
            circles = findobj(tc.app.Controls.Image, 'Type', 'line', 'Color', [0.2 1 0.85]);
            tc.verifyNumElements(circles, 2);
            d.saveTargets();
            tc.verifyEmpty(d.LastError);
            saved = lhf.cam.loadTargets(lhf.cam.targetsFile(tc.calibration(), 'M7'));
            tc.verifyEqual({saved.list.name}, {'G1', 'G2'});
            tc.verifyEqual(saved.referenceTime, d.Fiducial.reference.time);
            delete(d);

            % Another session: the tissue sits 15 px right and 10 px up
            tc.tissueShift = [15 -10];
            d = tc.makeDesigner(reg);
            d.setAnimal('M7');
            tc.verifyEqual({d.Targets.name}, {'G1', 'G2'});
            tc.verifySubstring(d.Controls.TargetsInfo.String, 'not located');
            d.locateTargets();
            g1 = lhf.cam.toCamera(reg, [300 200]) + [15 -10];
            onDmd = d.targetsOnDmd();
            tc.verifyEqual(onDmd(1, :), lhf.cam.toDmd(reg, g1), 'AbsTol', 1);

            % A click near G1 lands the spot on it; Spots on targets adds G2's
            near = lhf.cam.toDmd(reg, g1) + [4 3];
            tc.click(near);
            tc.verifyEqual([d.Spots.x d.Spots.y], round(onDmd(1, :)));   % the located centre
            tc.verifyEqual([d.Spots.x d.Spots.y], lhf.cam.toDmd(reg, g1), 'AbsTol', 1);
            d.spotsOnTargets();
            tc.verifyNumElements(d.Spots, 2);
            g2 = lhf.cam.toDmd(reg, lhf.cam.toCamera(reg, [500 400]) + [15 -10]);
            tc.verifyEqual([d.Spots(2).x d.Spots(2).y], g2, 'AbsTol', 1);
            d.savePattern();
            files = dir(fullfile(tc.folder, 'patterns', '**', '*_meta.mat'));
            meta = load(fullfile(files(end).folder, files(end).name));
            tc.verifyEqual(meta.spotTargets, {'G1', 'G2'});
        end

        function onlyTickedTargetsGetSpots(tc)
            tc.useTissue();
            d = tc.makeDesigner(tc.registration());
            d.setAnimal('M8');
            d.placeMark(true);
            tc.click([200 100]);
            d.saveFiducial();
            d.setMarkTargets(true);
            tc.click([300 200]);
            tc.click([600 300]);
            d.setMarkTargets(false);
            d.setTargetUse(1, false);   % G1 unticked
            d.renameTarget(2, 'G1');    % taken: refused
            tc.verifyEqual(d.Targets(2).name, 'G2');
            d.renameTarget(2, 'dorsal');
            tc.verifyEqual(d.Controls.TargetTable.Data{2, 2}, 'dorsal');
            d.spotsOnTargets();
            tc.verifyNumElements(d.Spots, 1);
            tc.verifyEqual([d.Spots.x d.Spots.y], [600 300], 'AbsTol', 1);
            d.deleteTargets(1);
            tc.verifyEqual({d.Targets.name}, {'dorsal'});
            tc.verifySubstring(d.Controls.TargetsInfo.String, 'Not saved');
        end

        function aMarkIsKeptInSensorPixels(tc)
            d = tc.makeDesigner(tc.registration());
            tc.camera.Binning = 2;
            tc.app.capture();
            d.placeMark(true);
            tc.click([200 100]);
            tc.verifyEqual(d.MarkXY, lhf.cam.toCamera(tc.registration(), [200 100]), 'AbsTol', 1e-9);
        end

        function savingWithoutAMarkIsRefused(tc)
            d = tc.makeDesigner(tc.registration());
            d.setAnimal('M7');
            d.saveFiducial();
            tc.verifySubstring(d.LastError, 'Place the mark');
            tc.verifyFalse(isfile(lhf.cam.fiducialFile(tc.calibration(), 'M7')));
        end

        function theReferenceMarkIsDrawnOnTheCamera(tc)
            reg = tc.registration();
            lhf.cam.saveFiducial(lhf.cam.fiducialFile(tc.calibration(), 'M7'), struct('frame', ...
                zeros(1100, 1400, 'uint16'), 'xy', lhf.cam.toCamera(reg, [400 300]), 'exposureMs', 2, ...
                'roi', [0 0 1400 1100], 'registrationFile', ''));
            d = tc.makeDesigner(reg);
            d.setAnimal('M7');
            marker = findobj(tc.app.Controls.Image, 'Type', 'line', 'Marker', 'o');
            tc.verifyEqual([marker.XData marker.YData], lhf.cam.toCamera(reg, [400 300]), 'AbsTol', 1e-9);
            d.Controls.ShowRef.Value = false;
            d.Controls.ShowRef.Callback(d.Controls.ShowRef, []);
            tc.verifyEmpty(findobj(tc.app.Controls.Image, 'Type', 'line', 'Marker', 'o'));
        end

        function theFiducialColumnUnfolds(tc)
            d = tc.makeDesigner(tc.registration());
            tc.verifyEqual(d.Figure.Position(3), d.WIDTH);
            d.showFiducial(true);
            tc.verifyEqual(d.Figure.Position(3), d.WIDTH + d.FIDUCIAL_WIDTH);
            d.showFiducial(false);
            tc.verifyEqual(d.Figure.Position(3), d.WIDTH);
        end

        % ------------------------------------------------------------ alignment
        function alignmentNeedsItsCalibrationsAndAReference(tc)
            d = tc.makeDesigner(tc.registration());
            tc.verifyEqual(d.Controls.Align.Enable, 'off');
            tc.verifySubstring(d.Controls.AlignInfo.String, 'stage-camera calibration');
            delete(d);
            tc.extraOptions = struct('stageCalibration', lhf.cam.fitStageCamera([1 0; 0 1], [1 0; 0 1]), ...
                'stagesConfigured', true);
            d = tc.makeDesigner(tc.registration());
            d.setAnimal('M8');
            tc.verifySubstring(d.Controls.AlignInfo.String, 'reference first');
            d.alignToReference();
            tc.verifyEmpty(d.Stages);  % refused before connecting anything
        end

        function alignmentNeedsTheReferencesReadout(tc)
            lhf.cam.saveFiducial(lhf.cam.fiducialFile(tc.calibration(), 'M8'), struct('frame', ...
                zeros(1100, 1400, 'uint16'), 'xy', [700 550], 'roi', [0 0 1400 1100], 'binning', 1));
            tc.extraOptions = struct('stageCalibration', lhf.cam.fitStageCamera([1 0; 0 1], [1 0; 0 1]), ...
                'stagesConfigured', true);
            d = tc.makeDesigner(tc.registration());
            d.setAnimal('M8');
            tc.verifyEqual(d.Controls.Align.Enable, 'on');
            tc.camera.Binning = 2;
            d.setAnimal('M8');  % refreshes
            tc.verifyEqual(d.Controls.Align.Enable, 'off');
            tc.verifySubstring(d.Controls.AlignInfo.String, 'binning 1');
            d.alignToReference();
            tc.verifyEmpty(d.Stages);
        end

        function alignToReferenceMovesTheStageAndSavesTheSession(tc)
            world = StageAlignmentTest;  % its synthetic sample, camera and stages
            world.makeWorld();
            tc.addTeardown(@() world.closeStages());
            file = lhf.cam.fiducialFile(tc.calibration(), 'M9');
            lhf.cam.saveFiducial(file, struct('frame', world.frame(), 'xy', [190 190]));
            world.moveTo(world.start + [60 -40 20]);

            tc.app.close();
            tc.camera.disconnect();
            tc.useCamera(hamacam.transport.SimulatedTransport( ...
                'Resolution', [world.FRAME world.FRAME], 'FrameFcn', @(~, ~, ~) world.frame()));
            reg = lhf.cam.fitRegistration([0 0; 1024 0; 0 768], [0 0; 1024 0; 0 768] * 0.35 + 6);
            tc.extraOptions = struct('stageCalibration', world.calibration(), 'stagesConfigured', true, ...
                'makeStages', @() world.stages);
            d = tc.makeDesigner(reg);
            d.setAnimal('M9');
            tc.verifyEqual(d.Controls.Align.Enable, 'on');
            d.alignToReference();

            tc.verifyEqual(d.LastAlignment.status, 'aligned', d.LastAlignment.message);
            tc.verifyEqual(d.LastAlignment.endUm, world.start, 'AbsTol', 6);
            tc.verifyEqual(d.Controls.Align.String, 'Align to reference');
            tc.verifySubstring(d.Controls.AlignInfo.String, 'Aligned');
            fid = lhf.cam.loadFiducial(file);
            tc.verifyNumElements(fid.sessions, 2);
            tc.verifyEqual(fid.sessions(2).stageUm, d.LastAlignment.endUm);
            tc.verifyEqual(fid.sessions(2).alignment.status, 'aligned');
            tc.verifyEqual(fid.sessions(2).binning, 1);
        end

        % ------------------------------------------------------------ the stage
        function readStageShowsThePositions(tc)
            stages = tc.stagesAt([1000 2000 3000]);
            d = tc.makeDesigner(tc.registration());
            tc.verifySubstring(d.Controls.StageReadout.String, 'press Read');
            d.readStage();
            tc.verifySubstring(d.Controls.StageReadout.String, 'X 1000.0   Y 2000.0   Z 3000.0');
            tc.verifyEqual(d.LastStageUm, [1000 2000 3000]);
            tc.verifySameHandle(d.Stages.x, stages.x);
        end

        function goToReferenceMovesXYOnly(tc)
            stages = tc.stagesAt([1000 2000 3000]);
            tc.saveReferenceAt([10000 20000 30000]);
            d = tc.makeDesigner(tc.registration());
            d.setAnimal('M5');
            tc.verifyEqual(d.Controls.GoRef.Enable, 'on');
            tc.verifySubstring(d.Controls.GoRefInfo.String, 'Reference X 10000, Y 20000');
            d.goToReference();
            tc.verifyEmpty(d.LastError);
            tc.verifyEqual(tc.positions(stages), [10000 20000 3000]);  % Z stays
            tc.verifySubstring(d.Controls.StageReadout.String, 'X 10000.0');
            tc.verifySubstring(d.Controls.GoRefInfo.String, 'dX +0, dY +0');
            tc.verifyEqual(d.Controls.GoRef.String, 'Go to reference X/Y');
        end

        function goToReferenceIsOffWithoutASavedPosition(tc)
            tc.stagesAt([0 0 0]);
            tc.saveReferenceAt([]);
            d = tc.makeDesigner(tc.registration());
            d.setAnimal('M5');
            tc.verifyEqual(d.Controls.GoRef.Enable, 'off');
            tc.verifySubstring(d.Controls.GoRefInfo.String, 'press Read before Save fiducial');
        end

        function aTargetOutsideTheSafeRangeIsRefused(tc)
            stages = tc.stagesAt([1000 2000 3000], [0 5000]);
            tc.saveReferenceAt([10000 2500 30000]);
            d = tc.makeDesigner(tc.registration());
            d.setAnimal('M5');
            d.goToReference();
            tc.verifySubstring(d.LastError, 'outside');
            tc.verifyEqual(tc.positions(stages), [1000 2000 3000]);  % neither axis moved
        end

        function aDeclinedMoveMovesNothing(tc)
            stages = tc.stagesAt([1000 2000 3000]);
            tc.saveReferenceAt([10000 20000 30000]);
            tc.extraOptions.confirmGoTo = @(~) false;
            d = tc.makeDesigner(tc.registration());
            d.setAnimal('M5');
            d.goToReference();
            tc.verifyEqual(tc.positions(stages), [1000 2000 3000]);
        end
    end

    methods
        function d = makeDesigner(tc, reg)
            % A designer for cue row 1 on the test's camera panel, invisible.
            options = struct('calibrationFolder', tc.calibration(), 'registration', reg, ...
                'openCamera', @() tc.app, 'openPanel', @(name) tc.openPanel(name), 'makeDmd', @() tc.dmd, ...
                'dmdAllowed', @() tc.allowDmd, 'animal', '', 'stagesConfigured', false, ...
                'alignment', LuminoseConstants.alignmentDefaults(), ...
                'confirm', @(~) true, 'confirmGoTo', @(~) true, 'confirmBlank', @(~) true, ...
                'confirmTargets', @(~) true, ...
                'visible', false);
            for name = fieldnames(tc.extraOptions)'
                options.(name{1}) = tc.extraOptions.(name{1});
            end
            d = PatternDesigner('cue', 1, '', options);
            tc.designer = d;
        end

        function panel = openPanel(tc, name)
            tc.panelsOpened{end + 1} = name;
            panel = [name ' panel'];
        end

        function folder = calibration(tc)
            % The calibration folder, in the data folder tc.folder (which holds the
            % subjects' camera folders too).
            folder = fullfile(tc.folder, 'calibration');
        end

        function useCamera(tc, transport)
            % A connected simulated camera, its panel (invisible) showing a capture.
            tc.camera = hamacam.Camera('Transport', transport, 'ExposureMs', 3);
            tc.camera.connect();
            tc.app = hamacam.gui.CameraApp(tc.camera, 'Visible', false, ...
                'SavePreferences', false, 'SaveCaptures', false, 'ListDevices', @oneCamera);
            tc.app.capture();
        end

        function click(tc, dmdXY, kind)
            % A click on the camera image where the DMD lights dmdXY.
            if nargin < 3, kind = 'normal'; end
            sensor = lhf.cam.toCamera(tc.designer.Registration, dmdXY);
            tc.app.clickAt(tc.camera.sensorToFrame(sensor), kind);
        end

        function useTissue(tc)
            % The camera sees a fixed texture (moved by tissueShift), so frames register.
            rng(11);
            world = imgaussfilt(randn(1300, 1600), 5);
            world = uint16(3000 + 1500 * world / std(world(:)));
            transport = hamacam.transport.SimulatedTransport('Resolution', [1400 1100], ...
                'FrameFcn', @(~, roi, ~) tc.tissueView(world, roi));
            tc.app.close();
            tc.camera.disconnect();
            tc.useCamera(transport);
        end

        function frame = tissueView(tc, world, roi)
            % The full sensor's view of world, shifted by tissueShift (whole px).
            s = round(tc.tissueShift);
            rows = (1:roi(4)) + 100 - s(2);
            cols = (1:roi(3)) + 100 - s(1);
            frame = world(rows, cols);
        end

        function p = spotPatches(tc)
            % The spots' patches on the camera image (not the overlay layer's).
            p = findobj(tc.app.Controls.Image, 'Type', 'patch', 'LineStyle', '-');
        end

        function stages = stagesAt(tc, um, safeX)
            % Simulated X, Y, Z (rigStages) at um, given to the designer's options
            if nargin < 3, safeX = [0 50000]; end
            transport = zaberstage.transport.SimulatedTransport('StartHomed', true, ...
                'Devices', struct('Address', 1, 'Name', 'X-MCC3', 'SerialNumber', 1, 'AxisCount', 3));
            luminose.zaber = struct('port', "SIM", 'axes', struct( ...
                'x', struct('device', 1, 'axis', 1, 'safe_um', safeX), ...
                'y', struct('device', 1, 'axis', 2, 'safe_um', [0 50000]), ...
                'z', struct('device', 1, 'axis', 3, 'safe_um', [0 50000])));
            stages = rigStages(luminose, transport);
            tc.addTeardown(stages.close);
            names = {'x', 'y', 'z'};
            for k = 1:3, stages.(names{k}).moveAbsolute(um(k)); end
            tc.extraOptions.stagesConfigured = true;
            tc.extraOptions.makeStages = @() stages;
        end

        function saveReferenceAt(tc, stageUm)
            % Animal M5's reference fiducial, saved with this stage position
            lhf.cam.saveFiducial(lhf.cam.fiducialFile(tc.calibration(), 'M5'), struct('frame', ...
                zeros(1100, 1400, 'uint16'), 'xy', [700 550], 'stageUm', stageUm));
        end
    end

    methods (Static)
        function um = positions(stages)
            um = [stages.x.positionUm(), stages.y.positionUm(), stages.z.positionUm()];
        end

        function reg = registration()
            % The 1024x768 DMD field inside the 1400x1100 simulated sensor, scaled 1.3
            reg = lhf.cam.fitRegistration([0 0; 1024 0; 0 768], [0 0; 1024 0; 0 768] * 1.3 + 20);
        end

        function old = swapGlobals(new)
            % Sets the protocol globals the designer reads and writes; returns the old ones.
            global luminose S BpodSystem %#ok<GVMIS> the designer's
            old = struct('luminose', luminose, 'S', S, 'BpodSystem', BpodSystem);
            luminose = new.luminose;
            S = new.S;
            BpodSystem = new.BpodSystem;
        end
    end
end


function devices = oneCamera()
% A made-up camera list, so that no test asks the real adaptor.
devices = table(1, {'C11440-22CU'}, {'MONO16'}, 'VariableNames', {'DeviceID', 'DeviceName', 'Formats'});
end

classdef CalibrationTest < matlab.unittest.TestCase
% The rig's calibrations (lhf.cal) on simulated devices whose answers are known:
% hamacam's simulated camera drawing what a FakeDmd shows through a known map,
% ZaberStage's simulated axes, obis's simulated laser and a made-up power meter.
% Files go to a temporary folder (the power CSV too).

    properties
        folder
        luminose
        dmd
        camera
        trueReg       % the camera-DMD map the simulated camera draws through
        misplaced = false  % spots in the DMD's first column land 40 px off (dust, reflections)
        dark = false       % the camera sees no light at all
    end

    methods (TestMethodSetup)
        function setUp(tc)
            tc.folder = tempname;
            mkdir(fullfile(tc.folder, 'dmd'));
            tc.luminose = struct('f', struct('luminoseData', string(tc.folder), ...
                'luminose_hf', string(tc.folder), 'matlabFolder', string(tc.folder)), ...
                'camera', struct('exposureTime_ms', 3, 'nAverageFrames', 1, 'effectivePixelSize_um', 3.4), ...
                'dmd', struct('projectedDMDlength', 2.56), 'zaber', struct('zStep_um', 50, 'focus_um', 18500));
            writetable(table([0; 10; 20], [0; 3.4; 6.8], [100; 200; 300], 'VariableNames', ...
                {'power_setting_mW', 'power_at_sample_mW', 'intensity_at_camera'}), tc.csv());
            tc.dmd = FakeDmd();
            th = 47;
            tc.trueReg = lhf.cam.fitRegistration([0 0; 1024 0; 0 768], ...
                [0 0; 1024 0; 0 768] * (0.8 * [cosd(th) sind(th); -sind(th) cosd(th)]) + [600 100]);
        end
    end

    methods (TestMethodTeardown)
        function tearDown(tc)
            if ~isempty(tc.camera) && isvalid(tc.camera), tc.camera.disconnect(); end
            rmdir(tc.folder, 's');
        end
    end

    methods (Test)
        % ------------------------------------------------------------ settings
        function defaultsComeFromTheConfig(tc)
            cals = lhf.cal.catalog(tc.luminose);
            tc.verifyEqual({cals.id}, {'cameraDmd', 'stageCamera', 'zFocus', 'power'});
            s = lhf.cal.settings(cals(1));
            tc.verifyEqual([s.exposureMs s.averageFrames s.gridX s.gridY], [3 1 6 5]);
            tc.verifyEqual(lhf.cal.settings(cals(3)).stepUm, 50);
            tc.verifyEqual(lhf.cal.settings(cals(3)).centreUm, 18500);  % zaber.focus_um
            tc.verifyEqual(lhf.cal.settings(cals(4)).setpointsmW, [0 10 20]);  % the CSV's
        end

        function badSettingsAreRefused(tc)
            cals = lhf.cal.catalog(tc.luminose);
            tc.verifyError(@() lhf.cal.settings(cals(1), struct('gridX', 'six')), 'lhf:cal:badSetting');
            tc.verifyError(@() lhf.cal.settings(cals(1), struct('nope', 1)), 'lhf:cal:badSetting');
            tc.verifyError(@() lhf.cal.settings(cals(4), struct('meter', 'other')), 'lhf:cal:badSetting');
            s = lhf.cal.settings(cals(1), struct('gridX', 4));
            tc.verifyEqual(s.gridX, 4);
        end

        % ------------------------------------------------------------ camera - DMD
        function cameraDmdFindsTheMapAndSavesIt(tc)
            tc.spotCamera();
            before = tc.camera.ExposureMs;
            r = tc.runCal('cameraDmd', struct('gridX', 4, 'gridY', 3, 'settleS', 0, 'exposureMs', 5));
            reg = r.data.registration;
            tc.verifyEqual(reg.A, tc.trueReg.A, 'AbsTol', 0.02);
            tc.verifyLessThan(reg.rmsPx, 0.2);
            tc.verifyEqual(reg.space, 'sensor');
            tc.verifyEqual(tc.dmd.Calls{end}, 'halt');
            tc.verifyEqual(tc.camera.ExposureMs, before);  % put back
            loaded = lhf.cam.loadRegistration(fullfile(tc.folder, 'calibration'));
            tc.verifyEqual(loaded.A, reg.A);
            tc.verifyEqual(loaded.settings.gridX, 4);
            tc.verifyTrue(isfile(strrep(loaded.file, '.mat', '.png')));
        end

        function cameraDmdIsInSensorPixelsAtAnyBinning(tc)
            tc.spotCamera();
            tc.camera.Binning = 2;
            r = tc.runCal('cameraDmd', struct('gridX', 4, 'gridY', 3, 'settleS', 0));
            tc.verifyEqual(r.data.registration.A, tc.trueReg.A, 'AbsTol', 0.05);
            tc.verifyEqual(r.data.registration.binning, 2);
        end

        function spotsOffTheMapAreDropped(tc)
            tc.spotCamera();
            tc.misplaced = true;  % the first column's 5 spots land 40 px away
            r = tc.runCal('cameraDmd', struct('settleS', 0), struct(), false);
            tc.verifyEqual(r.data.registration.A, tc.trueReg.A, 'AbsTol', 0.02);
            tc.verifyEqual(nnz(~r.data.found), 5);
            tc.verifyEqual(nnz(contains(r.messages, 'dropped')), 5);
        end

        function noLightStopsItBeforeTheSpots(tc)
            tc.spotCamera();
            tc.dark = true;
            tc.verifyError(@() tc.runCal('cameraDmd', struct('settleS', 0)), 'lhf:cal:noLight');
            tc.verifyEqual(tc.dmd.Calls{end}, 'halt');
            tc.verifyEqual(nnz(strcmp(tc.dmd.Calls, 'displayFrame')), 2);  % dark, all on: no spots
        end

        function stopEndsItWithTheDmdHalted(tc)
            tc.spotCamera();
            before = tc.camera.ExposureMs;
            calls = 0;
            hooks = struct('progress', @(~, ~) count(), 'shouldStop', @() stopNow());
            tc.verifyError(@() lhf.cal.run('cameraDmd', tc.luminose, struct('settleS', 0), ...
                struct('hooks', hooks, 'devices', tc.devices(), 'folder', tc.calFolder())), 'lhf:cal:stopped');
            tc.verifyEqual(tc.dmd.Calls{end}, 'halt');
            tc.verifyEqual(tc.camera.ExposureMs, before);
            tc.verifyEmpty(lhf.cal.history(tc.cal('cameraDmd'), tc.calFolder()));  % nothing saved
            log = fileread(fullfile(tc.calFolder(), 'calibration_log.txt'));
            tc.verifySubstring(log, 'cameraDmd  stopped');
            function count()
                calls = calls + 1;
            end
            function tf = stopNow()
                tf = calls >= 3;
            end
        end

        % ------------------------------------------------------------ stage - camera
        function stageCameraRecoversTheMatrixAndReturns(tc)
            world = StageAlignmentTest;
            world.makeWorld();
            tc.addTeardown(@() world.closeStages());
            tc.camera = hamacam.Camera('Transport', hamacam.transport.SimulatedTransport( ...
                'Resolution', [world.FRAME world.FRAME], 'FrameFcn', @(~, ~, ~) world.frame()));
            tc.camera.connect();
            limits = world.stages.x.LimitsUm;
            r = tc.runCal('stageCamera', struct('settleS', 0), struct('stage', world.stages));
            tc.verifyEqual(r.data.stageCamera.C, world.C, 'AbsTol', 0.02);
            tc.verifyEqual([world.stages.x.positionUm(), world.stages.y.positionUm()], ...
                world.start(1:2), 'AbsTol', 1);
            tc.verifyEqual(world.stages.x.LimitsUm, limits);
            loaded = lhf.cam.loadStageCalibration(tc.calFolder());
            tc.verifyEqual(loaded.C, r.data.stageCamera.C);
        end

        % ------------------------------------------------------------ Z focus
        function zFocusFindsTheBrightestPlane(tc)
            stages = tc.simulatedStages();
            stages.z.moveAbsolute(24000);
            tc.camera = hamacam.Camera('Transport', hamacam.transport.SimulatedTransport( ...
                'Resolution', [64 64], 'FrameFcn', @(~, ~, ~) ...
                uint16(100 + 1000 * exp(-((stages.z.positionUm() - 25200) / 600) ^ 2) * ones(64))));
            tc.camera.connect();
            limits = stages.z.LimitsUm;
            r = tc.runCal('zFocus', struct('centreUm', 25000, 'rangeUm', 2000, 'stepUm', 200), ...
                struct('stage', stages));
            tc.verifyEqual(r.data.results.bestFocus_mm, 25.2, 'AbsTol', 1e-9);
            tc.verifyEqual(r.data.results.offsetFromNominal_um, 200, 'AbsTol', 1e-9);
            tc.verifyEqual(stages.z.positionUm(), 24000, 'AbsTol', 1);  % back to the start
            tc.verifyEqual(stages.z.LimitsUm, limits);
            tc.verifyEqual(tc.dmd.Calls{end}, 'halt');
            tc.verifyEqual(nnz(tc.dmd.LastFrame), 1);  % one mirror
        end

        function aScanPastTheLimitsIsCutThere(tc)
            stages = tc.simulatedStages();
            stages.z.moveAbsolute(24000);
            stages.z.LimitsUm = [20000 26000];
            tc.camera = hamacam.Camera('Transport', hamacam.transport.SimulatedTransport( ...
                'Resolution', [64 64], 'FrameFcn', @(~, ~, ~) ...
                uint16(100 + 1000 * exp(-((stages.z.positionUm() - 25200) / 600) ^ 2) * ones(64))));
            tc.camera.connect();
            r = tc.runCal('zFocus', struct('centreUm', 25000, 'rangeUm', 2000, 'stepUm', 200), ...
                struct('stage', stages));
            z = r.data.results.zPositions_um;
            tc.verifyEqual(z([1 end]), [23000 26000]);  % 27000 was past the limit
            tc.verifyEqual(r.data.results.bestFocus_mm, 25.2, 'AbsTol', 1e-9);
            tc.verifySubstring(strjoin(r.messages), 'cut to Z''s limits');
            tc.verifyEqual(stages.z.LimitsUm, [20000 26000]);  % put back
            tc.verifyEqual(stages.z.positionUm(), 24000, 'AbsTol', 1);
        end

        function aScanWhollyOutsideTheLimitsMovesNothing(tc)
            stages = tc.simulatedStages();
            stages.z.moveAbsolute(24000);
            tc.camera = hamacam.Camera('Transport', hamacam.transport.SimulatedTransport('Resolution', [64 64]));
            tc.camera.connect();
            tc.verifyError(@() tc.runCal('zFocus', struct('centreUm', 60000, 'rangeUm', 2000), ...
                struct('stage', stages)), 'lhf:cal:outsideLimits');
            tc.verifyEqual(stages.z.positionUm(), 24000, 'AbsTol', 1);
            log = fileread(fullfile(tc.calFolder(), 'calibration_log.txt'));
            tc.verifySubstring(log, 'zFocus  FAILED');
            tc.verifySubstring(log, 'wholly outside');  % the error, in full
        end

        % ------------------------------------------------------------ power
        function powerReadsTheMeterAndRewritesTheCsv(tc)
            laser = obis.Laser('Transport', obis.transport.SimulatedTransport(), 'MaxPowermW', 165);
            laser.connect();
            tc.addTeardown(@() laser.disconnect());
            tc.lightCamera(laser);
            meter = struct('read', @(n) deal(0.34 * laser.CommandedPowermW, 0.01), 'close', @() []);
            r = tc.runCal('power', struct('setpointsmW', [0 10 20 40], 'settleS', 0, 'meter', 'PM100D'), ...
                struct('laser', laser, 'meter', meter));
            t = readtable(tc.csv());
            tc.verifyEqual(t.power_setting_mW', [0 10 20 40]);
            tc.verifyEqual(t.power_at_sample_mW', 0.34 * [0 10 20 40], 'AbsTol', 1e-9);
            tc.verifyEqual(t.intensity_at_camera(end) > t.intensity_at_camera(2), true);
            tc.verifyFalse(laser.IsEnabled);  % emission off at the end
            tc.verifyEqual(tc.dmd.Calls{end}, 'halt');
            previous = dir(fullfile(tc.calFolder(), 'power_calibration_previous_*.csv'));
            tc.verifyNumElements(previous, 1);
            old = readtable(fullfile(previous.folder, previous.name));
            tc.verifyEqual(old.power_setting_mW', [0 10 20]);
            tc.verifyNumElements(r.files, 4);  % mat, previous csv, csv, png
        end

        function withoutAMeterTheCsvPowersAreKept(tc)
            laser = obis.Laser('Transport', obis.transport.SimulatedTransport(), 'MaxPowermW', 165);
            laser.connect();
            tc.addTeardown(@() laser.disconnect());
            tc.lightCamera(laser);
            r = tc.runCal('power', struct('setpointsmW', [0 10 15], 'settleS', 0, 'useCamera', false), ...
                struct('laser', laser), false);
            tc.verifyEqual(r.data.table.power_at_sample_mW', [0 3.4 NaN]);
            tc.verifySubstring(strjoin(r.messages), '15');
            tc.verifyEmpty(r.files);  % not saved
            tc.verifyEqual(readtable(tc.csv()).power_setting_mW', [0 10 20]);  % untouched
        end

        % ------------------------------------------------------------ history
        function historyListsNewestFirstAndLoads(tc)
            tc.spotCamera();
            first = tc.runCal('cameraDmd', struct('gridX', 3, 'gridY', 3, 'settleS', 0));
            pause(1.1);  % another stamp
            second = tc.runCal('cameraDmd', struct('gridX', 4, 'gridY', 3, 'settleS', 0));
            list = lhf.cal.history(tc.cal('cameraDmd'), tc.calFolder());
            tc.verifyEqual({list.file}, {second.files{1}, first.files{1}});
            tc.verifyEqual([list.inUse], [true false]);
            loaded = lhf.cal.load(list(2).file);
            tc.verifyEqual(loaded.id, 'cameraDmd');
            tc.verifyEqual(loaded.settings.gridX, 3);
            fig = figure('Visible', 'off');
            tc.addTeardown(@() delete(fig));
            lhf.cal.plot(loaded, fig);
            tc.verifyNumElements(findobj(fig, 'Type', 'axes'), 2);
        end

        % ------------------------------------------------------------ the window
        function theWindowShowsEachCalibrationsSettings(tc)
            app = tc.makeApp();
            tc.verifyEqual(app.Controls.List.Items, {'Camera - DMD', 'Stage - camera', 'Z focus', 'Laser power'});
            tc.verifyEqual(app.Selected, 'cameraDmd');
            tc.verifySize(app.Controls.Settings.Data, [9 4]);
            tc.verifyEqual(app.Controls.Settings.Data{1, 2}, '6');
            app.select('zFocus');
            tc.verifyEqual(app.Values.stepUm, 50);
            tc.verifySubstring(app.Controls.Before.Text, 'Before you start');
        end

        function editedSettingsAreChecked(tc)
            app = tc.makeApp();
            app.Controls.Settings.CellEditCallback([], struct('Indices', [1 2], 'NewData', '4'));
            tc.verifyEqual(app.Values.gridX, 4);
            app.Controls.Settings.CellEditCallback([], struct('Indices', [1 2], 'NewData', 'many'));
            tc.verifyEqual(app.Values.gridX, 4);
            tc.verifySubstring(app.LastError, 'not understood');
            app.select('power');
            app.Controls.Settings.CellEditCallback([], struct('Indices', [1 2], 'NewData', '[0, 5, 10]'));
            tc.verifyEqual(app.Values.setpointsmW, [0 5 10]);
            app.defaults();
            tc.verifyEqual(app.Values.setpointsmW, [0 10 20]);
        end

        function aRunIsUsedOnlyOnceSaved(tc)
            tc.spotCamera();
            app = tc.makeApp();
            app.setValue('gridX', 3);
            app.setValue('gridY', 3);
            app.setValue('settleS', 0);
            app.run();
            tc.verifyNotEmpty(app.Pending, app.Status);
            tc.verifySubstring(app.Status, 'Save');
            tc.verifyEmpty(lhf.cal.history(tc.cal('cameraDmd'), tc.calFolder()));
            tc.verifyNotEmpty(findobj(app.Controls.Result, 'Type', 'axes'));
            app.discard();
            tc.verifyEmpty(app.Pending);
            app.run();
            files = app.saveResult();
            tc.verifyNotEmpty(files);
            list = lhf.cal.history(tc.cal('cameraDmd'), tc.calFolder());
            tc.verifyNumElements(list, 1);
            tc.verifyEqual(app.Controls.HistoryList.Value, list(1).file);
            tc.verifyEqual(lhf.cam.loadRegistration(tc.calFolder()).settings.gridX, 3);
        end

        function stopInTheWindowSavesNothing(tc)
            tc.spotCamera();
            app = tc.makeApp();
            app.setValue('settleS', 0);
            tc.dmd.OnDisplay = @() app.stop();  % pressed while the first frame shows
            app.run();
            tc.verifyEmpty(app.Pending);
            tc.verifySubstring(app.Status, 'Stopped');
            tc.verifyEqual(tc.dmd.Calls{end}, 'halt');
        end

        function noRunWhileASessionRuns(tc)
            tc.spotCamera();
            app = tc.makeApp(@() false);
            app.run();
            tc.verifySubstring(app.LastError, 'session');
            tc.verifyEmpty(tc.dmd.Calls);
        end

        function savingPowerAsksFirst(tc)
            laser = obis.Laser('Transport', obis.transport.SimulatedTransport(), 'MaxPowermW', 165);
            laser.connect();
            tc.addTeardown(@() laser.disconnect());
            tc.lightCamera(laser);
            app = tc.makeApp(@() true, struct('laser', laser), @(~) false);
            app.select('power');
            app.setValue('setpointsmW', [0 10]);
            app.setValue('settleS', 0);
            app.run();
            tc.verifyNotEmpty(app.Pending, app.Status);
            tc.verifyEmpty(app.saveResult());  % declined
            tc.verifyEqual(readtable(tc.csv()).power_setting_mW', [0 10 20]);
        end
    end

    methods
        function app = makeApp(tc, allowed, devices, confirm)
            if nargin < 2, allowed = @() true; end
            if nargin < 3, devices = struct(); end
            if nargin < 4, confirm = @(~) true; end
            d = tc.devices();
            for name = fieldnames(devices)'
                d.(name{1}) = devices.(name{1});
            end
            app = CalibrationApp('Visible', false, 'Luminose', tc.luminose, 'Folder', tc.calFolder(), ...
                'Devices', d, 'CameraPanel', [], 'Allowed', allowed, 'Confirm', confirm, ...
                'SavePreferences', false);
            tc.addTeardown(@() delete(app));
        end

        function r = runCal(tc, id, values, devices, save)
            if nargin < 4, devices = struct(); end
            if nargin < 5, save = true; end
            d = tc.devices();
            for name = fieldnames(devices)'
                d.(name{1}) = devices.(name{1});
            end
            r = lhf.cal.run(id, tc.luminose, values, struct('devices', d, 'folder', tc.calFolder(), ...
                'save', save, 'hooks', struct('progress', @(~, ~) [])));
        end

        function d = devices(tc)
            d = struct('camera', tc.camera, 'dmd', tc.dmd);
        end

        function folder = calFolder(tc)
            folder = fullfile(tc.folder, 'calibration');
        end

        function file = csv(tc)
            file = fullfile(tc.folder, 'dmd', 'power_calibration.csv');
        end

        function cal = cal(tc, id)
            cals = lhf.cal.catalog(tc.luminose);
            cal = cals(strcmp({cals.id}, id));
        end

        function spotCamera(tc)
            % A 1400 x 1100 camera that sees the FakeDmd's lit mirrors through trueReg
            tc.camera = hamacam.Camera('Transport', hamacam.transport.SimulatedTransport( ...
                'Resolution', [1400 1100], 'FrameFcn', @(~, roi, ~) tc.spotFrame(roi)));
            tc.camera.connect();
        end

        function frame = spotFrame(tc, roi)
            [qx, qy] = meshgrid(1:roi(3), 1:roi(4));
            img = 100 + 5 * randn(roi(4), roi(3));
            lit = tc.dmd.LastFrame;
            if tc.dark || isempty(lit) || ~islogical(lit) || ~any(lit(:))
                % nothing lit
            elseif nnz(lit) >= 1000
                img = img + 2000;  % every mirror on: the field lit
            else
                [y, x] = find(lit);
                p = tc.camera.sensorToFrame(lhf.cam.toCamera(tc.trueReg, [mean(x) mean(y)]));
                if tc.misplaced && mean(x) < 100
                    p = p + 40;
                end
                img = img + 3000 * exp(-((qx - p(1)) .^ 2 + (qy - p(2)) .^ 2) / (2 * 3 ^ 2));
            end
            frame = uint16(img);
        end

        function lightCamera(tc, laser)
            % A camera whose lit field brightens with the laser's setpoint while emitting
            tc.camera = hamacam.Camera('Transport', hamacam.transport.SimulatedTransport( ...
                'Resolution', [128 128], 'FrameFcn', @(~, ~, ~) litFrame(laser)));
            tc.camera.connect();
        end

        function stages = simulatedStages(tc)
            transport = zaberstage.transport.SimulatedTransport('StartHomed', true, ...
                'Devices', struct('Address', 1, 'Name', 'X-MCC3', 'SerialNumber', 1, 'AxisCount', 3));
            rig.zaber = struct('port', "SIM", 'axes', struct( ...
                'x', struct('device', 1, 'axis', 1, 'safe_um', [0 50000]), ...
                'y', struct('device', 1, 'axis', 2, 'safe_um', [0 50000]), ...
                'z', struct('device', 1, 'axis', 3, 'safe_um', [0 50000])));
            stages = rigStages(rig, transport);
            tc.addTeardown(stages.close);
        end
    end
end


function frame = litFrame(laser)
    [qx, qy] = meshgrid(1:128, 1:128);
    field = double(abs(qx - 64) < 30 & abs(qy - 64) < 25);
    level = 0;
    if laser.IsEnabled, level = 50 * laser.CommandedPowermW; end
    frame = uint16(100 + level * field + 5 * randn(128));
end

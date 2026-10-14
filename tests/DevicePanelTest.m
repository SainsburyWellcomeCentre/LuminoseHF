classdef DevicePanelTest < matlab.unittest.TestCase
% lhf.device and lhf.devicePanel: the rig's one object per device, and the device
% packages' panels that control it (the parameter GUI's device buttons,
% gui/DeviceButtons). Every device here is simulated; nothing real is opened.

    properties
        Saved   % appdata on the root before the test
    end

    methods (TestMethodSetup)
        function keepAppdata(tc)
            names = {'lhfDevicePanels', 'lhfDevices', 'lhfSessionRunning'};
            tc.Saved = struct();
            for k = 1:numel(names)
                if isappdata(0, names{k})
                    tc.Saved.(names{k}) = getappdata(0, names{k});
                    rmappdata(0, names{k});
                end
            end
            tc.addTeardown(@() tc.restoreAppdata(names));
        end
    end

    methods (Test)
        function cameraImagesGoInTheSubjectsWidefieldFolder(tc)
            data = tempname;
            mkdir(data);
            tc.addTeardown(@() rmdir(data, 's'));
            tc.verifyEqual(lhf.cam.subjectFolder(data, 'LUMI-0022'), ...
                fullfile(data, 'LUMI-0022', 'luminose_hf_widefield'));
            tc.verifyEqual(lhf.cam.subjectFolder(data, ''), '');
            camera = hamacam.Camera('Transport', hamacam.transport.SimulatedTransport());
            tc.addTeardown(@() delete(camera));
            app = hamacam.gui.CameraApp(camera, 'Visible', false, 'SavePreferences', false, ...
                'SaveCaptures', false, 'ListDevices', @() table(1, {'C11440-22CU'}, {'MONO16'}, ...
                'VariableNames', {'DeviceID', 'DeviceName', 'Formats'}));  % never the real adaptor
            tc.addTeardown(@() app.close());
            before = app.SaveFolder;
            tc.verifyEqual(lhf.cam.useSubjectFolder('', app, data), '');  % no subject: unchanged
            tc.verifyEqual(app.SaveFolder, before);
            folder = lhf.cam.useSubjectFolder('LUMI-0022', app, data);
            tc.verifyTrue(isfolder(folder));
            tc.verifyEqual(app.SaveFolder, folder);
        end

        % ---------------------------------------------------------------- lhf.device
        function aDeviceIsOneObject(tc)
            laser = simulatedLaser();
            lhf.device('laser', laser);
            tc.verifySameHandle(lhf.device('laser'), laser);
            tc.verifySameHandle(lhf.device('laser'), lhf.device('laser'));
        end

        function connectConnectsOnlyIfNeeded(tc)
            laser = simulatedLaser();
            lhf.device('laser', laser);
            tc.verifyEqual(laser.State, 'Disconnected');
            same = lhf.device('laser', 'connect');
            tc.verifySameHandle(same, laser);
            tc.verifyEqual(laser.State, 'Ready');
            calls = numel(laser.log().Command);
            lhf.device('laser', 'connect');   % already connected: nothing sent
            tc.verifyEqual(numel(laser.log().Command), calls);
        end

        function theStagesConnectOnOnePort(tc)
            stages = simulatedStages();
            lhf.device('stage', stages);
            lhf.device('stage', 'connect');
            tc.verifyEqual({stages.x.State, stages.y.State, stages.z.State}, ...
                {'Ready', 'Ready', 'Ready'});
        end

        function aDeletedDeviceIsMadeAgainNotReturned(tc)
            laser = simulatedLaser();
            lhf.device('laser', laser);
            lhf.device('laser', []);   % forgotten
            devices = getappdata(0, 'lhfDevices');
            tc.verifyFalse(isfield(devices, 'laser'));
        end

        % ---------------------------------------------------------------- lhf.devicePanel
        function aPanelControlsTheSharedDevice(tc)
            laser = simulatedLaser();
            lhf.device('laser', laser);
            app = lhf.devicePanel('laser');
            tc.addTeardown(@() app.close());
            tc.verifySameHandle(app.Laser, laser);
            app.Controls.Connect.ButtonPushedFcn(app.Controls.Connect, []);
            tc.verifyEqual(lhf.device('laser').State, 'Ready');   % what the session sees
            app.close();
            tc.verifyEqual(laser.State, 'Ready');   % closing the panel leaves it connected
        end

        function aSessionMakesTheLaserPanelViewOnly(tc)
            lhf.device('laser', simulatedLaser());
            app = lhf.devicePanel('laser');
            tc.addTeardown(@() app.close());
            lhf.lockDevicePanels(true);   % START
            tc.verifyEqual(app.LockReason, 'session running');
            tc.verifyEqual(app.Controls.Start.Enable, matlab.lang.OnOffSwitchState('off'));
            tc.verifyEqual(app.Controls.Stop.Enable, matlab.lang.OnOffSwitchState('on'));
            lhf.lockDevicePanels(false);  % the session ended
            tc.verifyEmpty(app.LockReason);
        end

        function aPanelOpenedDuringASessionOpensViewOnly(tc)
            lhf.device('laser', simulatedLaser());
            lhf.lockDevicePanels(true);
            app = lhf.devicePanel('laser');
            tc.addTeardown(@() app.close());
            tc.verifyEqual(app.LockReason, 'session running');
            stage = lhf.devicePanel('stage', struct('stage', @() struct('LockReason', '', ...
                'Figure', [], 'Root', [])));
            tc.verifyEmpty(stage.LockReason);  % the stage panel stays usable
        end

        function aPanelOpensOnceAndComesBack(tc)
            lhf.device('laser', simulatedLaser());
            first = lhf.devicePanel('laser');
            tc.addTeardown(@() first.close());
            tc.verifySameHandle(lhf.devicePanel('laser'), first);   % to the front, not twice
            first.close();
            third = lhf.devicePanel('laser');
            tc.addTeardown(@() third.close());
            tc.verifyNotSameHandle(third, first);   % closed: a new one, on the same laser
            tc.verifySameHandle(third.Laser, first.Laser);
        end

        function theStagePanelShowsTheSharedAxes(tc)
            stages = simulatedStages();
            lhf.device('stage', stages);
            lhf.device('stage', 'connect');
            app = lhf.devicePanel('stage');
            tc.addTeardown(@() app.close());
            tc.verifySameHandle(app.Stages(3), stages.z);
            tc.verifyEqual(app.Names, {'X', 'Y', 'Z'});
            app.close();
            tc.verifyEqual(stages.z.State, 'Ready');
        end

        function aSessionAndThePanelShareTheLaser(tc)
            % lhf.laser.open takes the rig's laser: the panel shows the session's
            global BpodSystem %#ok<GVMIS>
            saved = BpodSystem;
            tc.addTeardown(@() restoreBpod(saved));
            BpodSystem = struct('PluginObjects', struct(), 'Data', struct());
            laser = simulatedLaser();
            lhf.device('laser', laser);
            app = lhf.devicePanel('laser');
            tc.addTeardown(@() app.close());
            S.GUI.LaserControl = 1;
            lhf.laser.open(S, struct('laser', struct('port', "SIM")));
            tc.verifySameHandle(BpodSystem.PluginObjects.Laser, app.Laser);
            tc.verifyEqual(char(app.Laser.Mode), 'Digital');
            lhf.laser.close(false);
            tc.verifyFalse(laser.IsEnabled);
            tc.verifyEqual(laser.State, 'Ready');
        end

        function windowsOpenInTheRigsLayout(tc)
            global BpodSystem %#ok<GVMIS> lhf.windowPosition reads the parameter GUI there
            saved = BpodSystem;
            tc.addTeardown(@() restoreBpod(saved));
            BpodSystem = struct();
            screen = [1 1 2560 1440];
            top = 1440 - 32;  % below the title bar
            params = lhf.windowPosition('parameters', [450 1300], screen);
            tc.verifyEqual(params, [2560 - 1 - 450, top - 1300, 450 1300]);  % right edge, top
            camera = lhf.windowPosition('camera', [640 900], screen);
            tc.verifyEqual(camera(1) + 640, params(1) - 2);  % left of the parameters
            tc.verifyEqual(camera(2) + 900, top);              % top
            stage = lhf.windowPosition('stage', [640 275], screen);
            tc.verifyEqual(stage(1), camera(1));               % below the camera
            tc.verifyLessThan(stage(2) + 275, camera(2));
            laser = lhf.windowPosition('laser', [640 300], screen);
            tc.verifyEqual(laser(1) + 640, stage(1) - 2);     % left of the stage
            tc.verifyEqual(laser(2) + 300, stage(2) + 275);    % tops aligned
            for name = {'dmd', 'calibration', 'designer'}
                p = lhf.windowPosition(name{1}, [480 700], screen);
                tc.verifyEqual(p(1) + 480, camera(1) - 2);    % left of the camera
                tc.verifyEqual(p(2) + 700, top);
            end
        end

        function aWindowFollowsAMovedNeighbour(tc)
            fig = figure('Visible', 'off', 'Position', [300 400 640 900]);
            tc.addTeardown(@() delete(fig));
            setappdata(0, 'lhfDevicePanels', struct('camera', struct('Figure', fig)));
            stage = lhf.windowPosition('stage', [640 275], [1 1 2560 1440]);
            tc.verifyEqual(stage(1), 300);
            tc.verifyEqual(stage(2), 400 - 32 - 2 - 275);
            low = lhf.windowPosition('stage', [640 275], [1 1 1920 1080]);
            tc.verifyGreaterThanOrEqual(low(2), 1 + 48);       % kept above the taskbar
        end

        function anUnknownDeviceIsAnError(tc)
            tc.verifyError(@() lhf.devicePanel('olfactometer'), ...
                'MATLAB:unrecognizedStringChoice');
            tc.verifyError(@() lhf.device('olfactometer'), 'MATLAB:unrecognizedStringChoice');
        end

        function theButtonRowHasTheDevicesAndCalibrate(tc)
            host = figure('Visible', 'off');
            tc.addTeardown(@() delete(host));
            buttons = DeviceButtons(host, [15 10 455 32]);
            tc.verifyEqual({buttons.String}, {'Camera', 'Stage', 'Laser', 'DMD', 'Calibrate'});
            positions = vertcat(buttons.Position);
            tc.verifyEqual(positions(end, 1) + positions(end, 3), 15 + 455, 'AbsTol', 1e-9);
            tc.verifyTrue(all(diff(positions(:, 1)) > 0));
        end
    end

    methods (Access = private)
        function restoreAppdata(tc, names)
            panels = getappdata(0, 'lhfDevicePanels');
            if isstruct(panels)
                for name = fieldnames(panels)'
                    try panels.(name{1}).close(); catch, end
                end
            end
            for k = 1:numel(names)
                if isappdata(0, names{k})
                    rmappdata(0, names{k});
                end
                if isfield(tc.Saved, names{k})
                    setappdata(0, names{k}, tc.Saved.(names{k}));
                end
            end
        end
    end
end


function laser = simulatedLaser()
laser = obis.Laser('Transport', obis.transport.SimulatedTransport(), 'MaxPowermW', 165);
end


function stages = simulatedStages()
transport = zaberstage.transport.SimulatedTransport('Devices', struct('Address', 1, ...
    'Name', 'X-MCC3', 'SerialNumber', 1, 'AxisCount', 3));
names = {'x', 'y', 'z'};
stages = struct();
for k = 1:3
    stages.(names{k}) = zaberstage.Stage('Transport', transport, 'SharedTransport', true, ...
        'AxisNumber', k);
end
axesOnly = stages;
stages.close = @() closeAll(axesOnly, transport);
end


function closeAll(stages, transport)
for n = {'x', 'y', 'z'}
    stages.(n{1}).disconnect();
end
transport.close();
end


function restoreBpod(saved)
global BpodSystem %#ok<GVMIS>
BpodSystem = saved;
end

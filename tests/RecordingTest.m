classdef RecordingTest < matlab.unittest.TestCase
% What a session and its preparation record so they can be recreated:
% lhf.provenance, lhf.calibrationSnapshot, lhf.stagePosition, lhf.recordSetup,
% lhf.recreate and the report's Reproduce section. Git runs on a temporary
% repository; the stages are ZaberStage's simulated ones.

    properties
        folder     % temporary: a git repository, a calibration folder, outputs
        repo
        calibration
        luminose   % the fields these functions read, as a struct
    end

    methods (TestMethodSetup)
        function setUp(tc)
            tc.folder = tempname;
            mkdir(tc.folder);
            tc.addTeardown(@() rmdir(tc.folder, 's'));
            tc.repo = fullfile(tc.folder, 'Repo');
            mkdir(tc.repo);
            git(tc.repo, 'init -q');
            writeFile(fullfile(tc.repo, 'tracked.m'), 'x = 1;');
            git(tc.repo, 'add tracked.m');
            git(tc.repo, '-c user.email=t@t -c user.name=t commit -q -m first');

            root = fullfile(tc.folder, 'LuminoseHF');
            mkdir(fullfile(root, 'dmd'));
            writeFile(fullfile(root, 'dmd', 'power_calibration.csv'), ...
                sprintf('power_setting_mW,power_at_sample_mW\n0,0\n10,3.4\n'));
            writeFile(fullfile(root, 'odour_bottles.tsv'), sprintf('valve\tbottle\n3\tA\n'));
            writeFile(fullfile(root, 'odour_chemicals.tsv'), sprintf('name\tppm\nA\t20\n'));
            writeFile(fullfile(root, 'luminose_config.yaml'), sprintf('paths:\n  dataFolder: "D:"\n'));
            tc.calibration = fullfile(tc.folder, 'calibration');
            mkdir(tc.calibration);
            tc.luminose = struct('configFile', fullfile(root, 'luminose_config.yaml'), ...
                'f', struct('luminose_hf', root, 'luminoseData', tc.folder, 'matlabFolder', tc.folder), ...
                'laser', struct('spotGain', 2.348), 'dmd', struct('patternsFolder', ''), ...
                'olfactometer', struct('odourBottlesFile', fullfile(root, 'odour_bottles.tsv'), ...
                'odourChemicalsFile', fullfile(root, 'odour_chemicals.tsv')));
        end
    end

    methods (Test)
        function aRepositoryIsRecordedWithItsUncommittedChanges(tc)
            p = lhf.provenance(tc.luminose, {tc.repo});
            tc.verifyMatches(p.code.commit, '^[0-9a-f]{40}$');
            tc.verifyFalse(p.code.dirty);
            tc.verifyEmpty(strtrim(p.code.diff));
            writeFile(fullfile(tc.repo, 'tracked.m'), 'x = 2;');
            writeFile(fullfile(tc.repo, 'new.m'), 'y = 3;');
            p = lhf.provenance(tc.luminose, {tc.repo});
            tc.verifyTrue(p.code.dirty);
            tc.verifySubstring(p.code.diff, '+x = 2;');
            tc.verifyEqual(p.code.untracked, {'new.m'});
            tc.verifyEqual(p.code.untrackedFiles.text, 'y = 3;');
            tc.verifySubstring(p.config.text, 'dataFolder');
            tc.verifyEqual(p.config.values.laser.spotGain, 2.348);
            tc.verifyNotEmpty(p.matlab);
        end

        function aFolderThatIsNotARepositoryIsNoted(tc)
            p = lhf.provenance(tc.luminose, {tc.calibration, fullfile(tc.folder, 'missing')});
            tc.verifyEmpty(p.code(1).commit);
            tc.verifySubstring(p.code(1).note, 'not a git repository');
            tc.verifyEqual(p.code(2).note, 'folder not found');
        end

        function theNewestCalibrationsAreCopied(tc)
            tc.saveCalibrations();
            c = lhf.calibrationSnapshot(tc.luminose, tc.calibration);
            tc.verifyEmpty(c.notes);
            tc.verifySubstring(c.power.text, '10,3.4');
            tc.verifyEqual(c.power.table.power_at_sample_mW', [0 3.4]);
            tc.verifySubstring(c.power.newestRun, 'power_20260902_000000.mat');
            tc.verifySubstring(c.cameraDmd.file, 'camera_dmd_20260902_000000.mat');
            tc.verifyEqual(c.cameraDmd.registration.rmsPx, 2);
            tc.verifyFalse(isfield(c.cameraDmd.registration, 'background'));
            tc.verifyEqual(c.stageCamera.calibration.pxPerUm, 0.634);
            tc.verifyEqual(c.zProfile.bestFocus_mm, 29.8);
            tc.verifyEqual(c.spotGain, 2.348);
            tc.verifySubstring(c.odourTables.bottlesText, 'bottle');
        end

        function missingCalibrationsAreNotedNotThrown(tc)
            lum = tc.luminose;
            lum.f.luminose_hf = fullfile(tc.folder, 'nowhere');
            c = lhf.calibrationSnapshot(lum, fullfile(tc.folder, 'empty'));
            tc.verifyNotEmpty(c.notes);
            tc.verifyEmpty(c.cameraDmd.file);
            tc.verifyEmpty(c.power.newestRun);
        end

        function theStagePositionIsReadThenReleased(tc)
            [stages, transport] = tc.simulatedStages([1000 2000 3000]);
            [um, note] = lhf.stagePosition(tc.luminose, @() stages);
            tc.verifyEqual(um, [1000 2000 3000]);
            tc.verifyEmpty(note);
            tc.verifyFalse(transport.isOpen());   % released
            [um, note] = lhf.stagePosition(tc.luminose, @() failing('no port'));
            tc.verifyEmpty(um);
            tc.verifySubstring(note, 'no port');
        end

        function theDesignersStagesAreUsedWhenItHasThem(tc)
            published = tc.simulatedStages([10 20 30]);
            setappdata(0, 'lhfStages', published);
            tc.addTeardown(@() rmappdata(0, 'lhfStages'));
            um = lhf.stagePosition(tc.luminose, @() failing('must not open the port'));
            tc.verifyEqual(um, [10 20 30]);
        end

        function theSetupRecordsEverything(tc)
            tc.saveCalibrations();
            lhf.cam.saveFiducial(lhf.cam.fiducialFile(tc.calibration, 'M1'), ...
                struct('frame', zeros(4, 'uint16'), 'xy', [1 2], 'stageUm', [5 6 7]));
            stages = tc.simulatedStages([1 2 3]);
            setup = lhf.recordSetup(tc.luminose, 'M1', struct('calibrationFolder', tc.calibration, ...
                'makeStages', @() stages, 'repos', {{tc.repo}}));
            tc.verifyEqual(setup.subject, 'M1');
            tc.verifyMatches(setup.provenance.code.commit, '^[0-9a-f]{40}$');
            tc.verifyEqual(setup.calibration.stageCamera.calibration.pxPerUm, 0.634);
            tc.verifyEqual(setup.stageUm, [1 2 3]);
            tc.verifyEqual(setup.fiducial.entry.stageUm, [5 6 7]);
            tc.verifyFalse(isfield(setup.fiducial.entry, 'frame'));
            tc.verifyMatches(setup.fiducial.entry.code.commit, '^[0-9a-f]{40}$');  % saveFiducial records the code
        end

        function aDataFileOutsideTheDataFolderIsFlagged(tc)
            options = struct('calibrationFolder', tc.calibration, 'makeStages', @() failing('none'), ...
                'repos', {{}}, 'dataFile', fullfile(tc.folder, 'M1', 'session.mat'));
            setup = lhf.recordSetup(tc.luminose, 'M1', options);
            tc.verifyEmpty(setup.dataFolderNote);   % tc.folder is the data folder
            options.dataFile = 'E:\elsewhere\M1\session.mat';
            setup = tc.verifyWarning(@() lhf.recordSetup(tc.luminose, 'M1', options), ...
                'lhf:recordSetup:dataFolder');
            tc.verifySubstring(setup.dataFolderNote, 'outside the data folder');
        end

        function configPathsHaveSingleBackslashes(tc)
            % YAML "\\" in double quotes is one \: paths compare equal to Bpod's
            file = fullfile(tc.folder, 'paths.yaml');
            writeFile(file, sprintf('paths:\n  dataFolder: "D:\\\\luminoseData\\\\rawdata"   # note\n  other: ''a\\\\b''\n'));
            config = LuminoseConstants.readConfig(file);
            tc.verifyEqual(char(config.paths.dataFolder), 'D:\luminoseData\rawdata');
            tc.verifyEqual(char(config.paths.other), 'a\\b');   % single quotes: as written
        end

        function aSessionIsWrittenOutToRunAgain(tc)
            tc.saveCalibrations();
            writeFile(fullfile(tc.repo, 'tracked.m'), 'x = 2;');
            writeFile(fullfile(tc.repo, 'new.m'), 'y = 3;');
            C = lhf.Outcome.Correct;
            data = fakeSession([1 2 1], [C C C]);
            data.RandomSeed = 1234;
            data.GUIMeta = struct('RewardAmount', struct('Label', 'Reward'));
            data.Setup = lhf.recordSetup(tc.luminose, 'M1', struct('calibrationFolder', tc.calibration, ...
                'makeStages', @() failing('no stages'), 'repos', {{tc.repo}}));
            spot = struct('x', 512, 'y', 384, 'onset_ms', 0, 'dur_ms', 80, 'isFixed', true);
            shown = struct('spots', spot, 'r_px', 5, 'tickMs', 80, 'nF', 1, 'exposureUs', 80000, ...
                'subFrames', 1, 'frameUs', 80000, 'synchUs', 79999, 'reused', false, 'row', 1, ...
                'shown', true, 'laserIrradiances_mWmm2', [2 4], 'laserWeights', [1 1]);
            blank = struct('row', 1, 'shown', false, 'blankMs', 80);
            for n = 1:3
                data.RawEvents.Trial{n}.Actions = struct('Patterns', struct('CSplus', blank, 'CSminus', shown));
            end

            out = fullfile(tc.folder, 'recreated');
            files = lhf.recreate(data, out);
            m = load(fullfile(out, 'settings.mat'));
            tc.verifyEqual(m.ProtocolSettings.RandomSeed, 1234);
            tc.verifyEqual(m.ProtocolSettings.GUI.RewardAmount, 3);
            tc.verifyEqual(m.ProtocolSettings.GUIMeta.RewardAmount.Label, 'Reward');
            minus = dir(fullfile(out, 'Patterns', 'designed_CSminus_r1_*_meta.mat'));
            tc.verifyNumElements(minus, 1);   % one file per type and row, not per trial
            d = load(fullfile(minus.folder, minus.name));
            tc.verifyEqual(d.spots, spot);
            tc.verifyEqual(d.laserIrradiances_mWmm2, [2 4]);
            plus = dir(fullfile(out, 'Patterns', 'designed_CSplus_r1_*_meta.mat'));
            d = load(fullfile(plus.folder, plus.name));
            tc.verifyEqual(d.blankMs, 80);
            tc.verifyEmpty(d.spots);
            tc.verifySubstring(fileread(fullfile(out, 'code', 'Repo.patch')), '+x = 2;');
            tc.verifyEqual(fileread(fullfile(out, 'code', 'Repo', 'new.m')), 'y = 3;');
            tc.verifySubstring(fileread(fullfile(out, 'power_calibration.csv')), '10,3.4');
            tc.verifySubstring(fileread(fullfile(out, 'luminose_config.yaml')), 'dataFolder');
            readme = fileread(fullfile(out, 'README.txt'));
            tc.verifySubstring(readme, data.Setup.provenance.code.commit);
            tc.verifySubstring(readme, 'UNCOMMITTED CHANGES');
            tc.verifySubstring(readme, 'not read (no stages)');
            tc.verifySubstring(readme, 'Random seed: 1234');
            tc.verifyTrue(all(cellfun(@isfile, files)));
        end

        function aSessionWithoutASetupIsRefused(tc)
            data = fakeSession(1, lhf.Outcome.Correct);
            tc.verifyError(@() lhf.recreate(data, fullfile(tc.folder, 'out')), 'lhf:recreate:noSetup');
        end

        function theReportSaysHowToReproduce(tc)
            C = lhf.Outcome.Correct;
            data = fakeSession([1 2], [C C]);
            data.Setup = lhf.recordSetup(tc.luminose, 'M1', struct('calibrationFolder', tc.calibration, ...
                'makeStages', @() failing('no stages'), 'repos', {{tc.repo}}));
            spot = struct('x', 1, 'y', 1, 'onset_ms', 0, 'dur_ms', 80, 'isFixed', true);
            for n = 1:2
                data.RawEvents.Trial{n}.Actions = struct('Patterns', struct('CSminus', ...
                    struct('spots', spot, 'row', 1, 'shown', true)));
            end
            files = lhf.report.write(data, lhf.protocolInfo('goNogo'), fullfile(tc.folder, 'session.mat'), ...
                struct('subject', 'M1'));
            text = fileread(files.log);
            tc.verifySubstring(text, '## Reproduce');
            tc.verifySubstring(text, '| Repo | ');
            tc.verifySubstring(text, 'CSminus r1: 2');
            tc.verifySubstring(text, 'lhf.recreate');
        end
    end

    methods
        function saveCalibrations(tc)
            % Two of each calibration file; the newer must be the one copied
            for stamp = {'20260801_000000', '20260902_000000'}
                registration = struct('rmsPx', 1 + strcmp(stamp{1}, '20260902_000000')); %#ok<NASGU>
                background = zeros(4); %#ok<NASGU>
                save(fullfile(tc.calibration, ['camera_dmd_' stamp{1} '.mat']), 'registration', 'background');
                stageCamera = struct('pxPerUm', 0.634); %#ok<NASGU>
                save(fullfile(tc.calibration, ['stage_camera_' stamp{1} '.mat']), 'stageCamera');
                results = struct('bestFocus_mm', 29.8); %#ok<NASGU>
                save(fullfile(tc.calibration, ['zprofile_' stamp{1} '.mat']), 'results');
                save(fullfile(tc.calibration, ['power_' stamp{1} '.mat']), 'results');
            end
        end

        function [stages, transport] = simulatedStages(tc, um)
            % X, Y and Z on one simulated port (rigStages), at um
            transport = zaberstage.transport.SimulatedTransport('StartHomed', true, ...
                'Devices', struct('Address', 1, 'Name', 'X-MCC3', 'SerialNumber', 1, 'AxisCount', 3));
            safe = [0 50000];
            luminose.zaber = struct('port', "SIM", 'axes', struct('x', struct('device', 1, 'axis', 1, ...
                'safe_um', safe), 'y', struct('device', 1, 'axis', 2, 'safe_um', safe), ...
                'z', struct('device', 1, 'axis', 3, 'safe_um', safe)));
            stages = rigStages(luminose, transport);
            tc.addTeardown(@() stages.close());
            names = {'x', 'y', 'z'};
            for k = 1:3, stages.(names{k}).moveAbsolute(um(k)); end
        end
    end
end


function git(folder, args)
    [status, out] = system(sprintf('git -C "%s" %s', folder, args));
    assert(status == 0, 'git %s: %s', args, out);
end

function writeFile(file, text)
    fid = fopen(file, 'w');
    fprintf(fid, '%s', text);
    fclose(fid);
end

function stages = failing(message)
% A makeStages that cannot connect
    stages = [];
    error('RecordingTest:noStages', '%s', message);
end

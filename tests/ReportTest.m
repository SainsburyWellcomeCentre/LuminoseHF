classdef ReportTest < matlab.unittest.TestCase
% The end-of-session report (lhf.report.*) and the stop record (lhf.stopRecord).

    properties
        folder
        dataFile
    end

    methods (TestMethodSetup)
        function makeFolder(tc)
            tc.folder = tempname;
            mkdir(tc.folder);
            tc.dataFile = fullfile(tc.folder, 'M1_luminose_hf_goNogo_20260929_120000.mat');
        end
    end

    methods (TestMethodTeardown)
        function removeFolder(tc)
            rmdir(tc.folder, 's');
        end
    end

    methods (Test)
        function summaryCountsEachTypeAndOutcome(tc)
            C = lhf.Outcome.Correct; I = lhf.Outcome.Incorrect;
            data = fakeSession([1 1 2 2 2], [C I C C I], 'RewardAmount', 2);
            s = lhf.report.summary(data, lhf.protocolInfo('goNogo'));
            tc.verifyEqual(s.nTrials, 5);
            tc.verifyEqual([s.byType.n], [2 3]);
            tc.verifyEqual([s.byType.correct], [1 2]);
            tc.verifyEqual([s.byType.incorrect], [1 1]);
            tc.verifyEqual(s.percentCorrect, 60, 'AbsTol', 1e-12);
            tc.verifyEqual(s.rewardTotal, 2);  % one rewarded CS+ trial
            tc.verifyEqual(s.medianResponseTime, 0.4, 'AbsTol', 1e-12);
        end

        function summaryListsSettingsChangedDuringTheSession(tc)
            data = fakeSession([1 2 1], [1 1 1]);
            data.TrialSettings(3).GUI.CSplus_prob = 0.7;
            data.TrialSettings(3).GUI.delivered_odours = struct('cue', 3);  % not an operator change
            data.TrialSettings(2).GUI.delivered_odours = struct('cue', 4);
            s = lhf.report.summary(data, lhf.protocolInfo('goNogo'));
            tc.verifyNumElements(s.settingChanges, 1);
            tc.verifyEqual(s.settingChanges.name, 'CSplus_prob');
            tc.verifyEqual(s.settingChanges.trial, 3);
            tc.verifyEqual([s.settingChanges.from s.settingChanges.to], [0.5 0.7]);
        end

        function writeMakesTheLogAndTheImage(tc)
            C = lhf.Outcome.Correct; I = lhf.Outcome.Incorrect;
            data = fakeSession([1 2 1 2], [C C I C]);
            data.RandomSeed = 1234;
            data.StoppedReason = lhf.stopRecord('completed', 4);
            data.SettingsNotes = {'Setting RepeatOnError no longer exists: dropped.'};
            files = lhf.report.write(data, lhf.protocolInfo('goNogo'), tc.dataFile, struct('subject', 'M1'));

            tc.verifyTrue(isfile(files.log));
            tc.verifyTrue(isfile(files.image));
            text = fileread(files.log);
            tc.verifySubstring(text, '| Subject | M1 |');
            tc.verifySubstring(text, '| Random seed | 1234 |');
            tc.verifySubstring(text, 'completed at trial 4');
            tc.verifySubstring(text, '| CS+ (Go) | 2 | 1 | 1 | 0 | 50.0 |');
            tc.verifySubstring(text, 'RepeatOnError');
        end

        function writeNeverThrows(tc)
            % A session that ended before any trial, into a folder that does not exist
            data = struct();
            data.StoppedReason = lhf.stopRecord('unknown', NaN);
            badFile = fullfile(tc.folder, 'missing', 'x.mat');
            files = tc.verifyWarning(@() lhf.report.write(data, lhf.protocolInfo('2AFC'), badFile, ...
                struct('subject', 'M1')), 'lhf:report:log');
            tc.verifyEmpty(files.log);
            tc.verifyEmpty(files.image);
        end

        function stopRecordKeepsTheError(tc)
            try
                error('test:boom', 'Boom at trial %d', 12);
            catch ME
                r = lhf.stopRecord('error', 12, ME);
            end
            tc.verifyEqual(r.Reason, 'error');
            tc.verifyEqual(r.Trial, 12);
            tc.verifyEqual(r.Identifier, 'test:boom');
            tc.verifySubstring(r.Message, 'Boom');
            tc.verifyNotEmpty(r.Stack);
            r = lhf.stopRecord('operator', 3);
            tc.verifyEmpty(r.Message);
        end
    end
end

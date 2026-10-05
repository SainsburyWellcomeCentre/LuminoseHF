classdef ScoreTrialTest < matlab.unittest.TestCase
% Scoring (lhf.scoreTrial) and the outcome codes (lhf.Outcome).

    methods (Test)
        function outcomeCodesAreTheStoredNumbers(tc)
            % Part of the data format: never renumber
            tc.verifyEqual(lhf.Outcome.Incorrect, 0);
            tc.verifyEqual(lhf.Outcome.Correct, 1);
            tc.verifyEqual(lhf.Outcome.NoResponse, 3);
            tc.verifyEqual(lhf.Outcome.label(3), 'No response');
        end

        % --- go/no-go
        function goTrialRewardedIsCorrectAndLicked(tc)
            [o, r] = lhf.scoreTrial(fakeTrial('Reward', [3 3.1]), 1, 'goNogo');
            tc.verifyEqual([o r], [lhf.Outcome.Correct 1]);
        end

        function goTrialWithoutRewardIsAMiss(tc)
            [o, r] = lhf.scoreTrial(fakeTrial('Reward', [NaN NaN]), 1, 'goNogo');
            tc.verifyEqual([o r], [lhf.Outcome.Incorrect 0]);
        end

        function noGoTrialWithheldIsCorrect(tc)
            [o, r] = lhf.scoreTrial(fakeTrial('Punishment', [NaN NaN], 'InterTrialInterval', [5 6]), 2, 'goNogo');
            tc.verifyEqual([o r], [lhf.Outcome.Correct 0]);
        end

        function noGoTrialPunishedIsIncorrectAndLicked(tc)
            [o, r] = lhf.scoreTrial(fakeTrial('Punishment', [3 3.5]), 2, 'goNogo');
            tc.verifyEqual([o r], [lhf.Outcome.Incorrect 1]);
        end

        % --- choice (2AFC, MTS)
        function choiceRewardedIsCorrect(tc)
            t = fakeTrial('GetResponse', [2 2.5], 'Reward', [2.5 2.6], 'BNC1High', 2.5);
            [o, r] = lhf.scoreTrial(t, 1, 'choice');
            tc.verifyEqual([o r], [lhf.Outcome.Correct 1]);
        end

        function choiceWrongSidePunishedIsIncorrect(tc)
            t = fakeTrial('GetResponse', [2 2.5], 'Punishment', [2.5 3], 'BNC2High', 2.5);
            [o, r] = lhf.scoreTrial(t, 1, 'choice');
            tc.verifyEqual([o r], [lhf.Outcome.Incorrect 2]);
        end

        function choiceTimeoutIsNoResponse(tc)
            t = fakeTrial('GetResponse', [2 4], 'Punishment', [4 4.5]);
            [o, r] = lhf.scoreTrial(t, 1, 'choice');
            tc.verifyEqual(o, lhf.Outcome.NoResponse);
            tc.verifyTrue(isnan(r));
        end

        function lickDuringCueIsNotAResponse(tc)
            % Licked during the cue, then timed out in GetResponse
            t = fakeTrial('ShowCue', [1 2], 'GetResponse', [2 4], 'Punishment', [4 4.5], 'BNC1High', 1.5);
            [o, r] = lhf.scoreTrial(t, 1, 'choice');
            tc.verifyEqual(o, lhf.Outcome.NoResponse);
            tc.verifyTrue(isnan(r));
        end

        function firstLickInTheWindowIsTheResponse(tc)
            t = fakeTrial('GetResponse', [2 3; 3.2 4], 'Reward', [4 4.1], ...
                'BNC2High', 2.8, 'BNC1High', [1.0 4.0]);
            [~, r] = lhf.scoreTrial(t, 1, 'choice');
            tc.verifyEqual(r, 2);
        end

        function withoutPunishmentTheLickIsScored(tc)
            % Punishment off: a wrong lick returns to GetResponse, then time runs out
            t = fakeTrial('GetResponse', [2 2.5; 2.5 4], 'Punishment', [NaN NaN], 'BNC2High', 2.5);
            tc.verifyEqual(lhf.scoreTrial(t, 1, 'choice'), lhf.Outcome.Incorrect);
            tc.verifyEqual(lhf.scoreTrial(t, 2, 'choice'), lhf.Outcome.Correct);
        end

        function unknownTaskErrors(tc)
            tc.verifyError(@() lhf.scoreTrial(fakeTrial(), 1, 'maze'), 'lhf:scoreTrial:task');
        end
    end
end

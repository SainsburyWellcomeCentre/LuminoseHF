classdef TrialSelectionTest < matlab.unittest.TestCase
% Trial selection: lhf.nextTrialType, lhf.responseBias, lhf.trialPolicy,
% lhf.random and lhf.protocolInfo.

    methods (TestMethodSetup)
        function seed(~)
            lhf.random('init', 1234);
        end
    end

    methods (Test)
        function probabilityOneAlwaysGivesTypeOne(tc)
            policy = struct('task', 'choice', 'pFirst', 1, 'biasCorrection', false);
            types = arrayfun(@(~) lhf.nextTrialType(struct(), policy, 1), 1:50);
            tc.verifyEqual(unique(types), 1);
        end

        function probabilityZeroAlwaysGivesTypeTwo(tc)
            policy = struct('task', 'goNogo', 'pFirst', 0, 'biasCorrection', false);
            types = arrayfun(@(~) lhf.nextTrialType(struct(), policy, 2), 1:50);
            tc.verifyEqual(unique(types), 2);
        end

        function alternationFollowsTheRunningTrial(tc)
            policy = struct('task', 'choice', 'pFirst', 0.5, 'alternate', true);
            tc.verifyEqual(lhf.nextTrialType(struct(), policy, []), 1);
            tc.verifyEqual(lhf.nextTrialType(struct(), policy, 1), 2);
            tc.verifyEqual(lhf.nextTrialType(struct(), policy, 2), 1);
        end

        function anErrorDoesNotForceARepeat(tc)
            % Repeat-on-error was removed: after an error the draw is still pFirst
            data.TrialTypes = 2;
            data.TrialOutcome = lhf.Outcome.Incorrect;
            data.TrialResponse = NaN;
            policy = struct('task', 'choice', 'pFirst', 1, 'biasCorrection', false, 'RepeatOnError', true);
            tc.verifyEqual(lhf.nextTrialType(data, policy, 2), 1);
        end

        function sameSeedSameTrials(tc)
            policy = struct('task', 'choice', 'pFirst', 0.5, 'biasCorrection', false);
            lhf.random('init', 99);
            first = arrayfun(@(~) lhf.nextTrialType(struct(), policy, 1), 1:40);
            lhf.random('init', 99);
            second = arrayfun(@(~) lhf.nextTrialType(struct(), policy, 1), 1:40);
            tc.verifyEqual(first, second);
            tc.verifyEqual(lhf.random('seed'), 99);
        end

        function initWithoutASeedDrawsOne(tc)
            seed = lhf.random('init');
            tc.verifyTrue(isscalar(seed) && seed >= 0 && seed == round(seed));
            tc.verifyEqual(lhf.random('seed'), seed);
        end

        function goNogoBiasIsAgainstTheExpectedLickRate(tc)
            % Licked on every trial with pFirst 0.5: bias -0.5 (show fewer CS+)
            tc.verifyEqual(lhf.responseBias(ones(1, 20), 0.5, 'goNogo'), -0.5, 'AbsTol', 1e-12);
            % Licking at the expected rate is no bias
            tc.verifyEqual(lhf.responseBias([ones(1, 7) zeros(1, 3)], 0.7, 'goNogo'), 0, 'AbsTol', 1e-12);
        end

        function choiceBiasIgnoresNoResponsesAndOldTrials(tc)
            responses = [2 2 2 2 2, NaN NaN, 1 1 2 2];
            % Window of 4: [1 1 2 2] -> balanced
            tc.verifyEqual(lhf.responseBias(responses, 0.5, 'choice', 4), 0, 'AbsTol', 1e-12);
            % All right choices: bias +1, show more left
            tc.verifyEqual(lhf.responseBias([2 2 2], 0.5, 'choice'), 1, 'AbsTol', 1e-12);
            tc.verifyEqual(lhf.responseBias([NaN NaN], 0.5, 'choice'), 0);
        end

        function biasCorrectionIsBounded(tc)
            data.TrialResponse = 2 * ones(1, 20);  % always chose side 2
            policy = struct('task', 'choice', 'pFirst', 0.8, 'biasCorrection', true);
            lhf.random('init', 5);
            types = arrayfun(@(~) lhf.nextTrialType(data, policy, 1), 1:400);
            % Corrected pFirst is capped at 0.9, so type 2 still appears
            tc.verifyGreaterThan(sum(types == 2), 0);
            tc.verifyGreaterThan(mean(types == 1), 0.8);
        end

        function policyReadsTheProtocolsProbabilityField(tc)
            info = lhf.protocolInfo('MTS');
            GUI = struct('MatchProb', 0.3, 'BiasCorrection', 1, 'TrainingLevel', 1);
            policy = lhf.trialPolicy(GUI, info);
            tc.verifyEqual(policy.pFirst, 0.3);
            tc.verifyTrue(policy.biasCorrection);
            tc.verifyTrue(policy.alternate);   % MTS habituation alternates
            policy = lhf.trialPolicy(struct('CSplus_prob', 0.5, 'TrainingLevel', 1), lhf.protocolInfo('goNogo'));
            tc.verifyFalse(policy.alternate);  % go/no-go does not
            tc.verifyFalse(policy.biasCorrection);
        end

        function powercalHabituationIsAllCSplus(tc)
            info = lhf.protocolInfo('powercal');
            GUI = struct('CSplus_prob', 0.3, 'BiasCorrection', true, 'TrainingLevel', 1);
            policy = lhf.trialPolicy(GUI, info);
            tc.verifyEqual(policy.pFirst, 1);
            tc.verifyFalse(policy.biasCorrection);
            data.TrialResponse = ones(1, 20);  % a bias that would otherwise lower pFirst
            types = arrayfun(@(~) lhf.nextTrialType(data, policy, 1), 1:100);
            tc.verifyEqual(unique(types), 1);
            % Training uses the set probability again; goNogo habituation is unchanged
            GUI.TrainingLevel = 2;
            tc.verifyEqual(lhf.trialPolicy(GUI, info).pFirst, 0.3);
            GUI.TrainingLevel = 1;
            tc.verifyEqual(lhf.trialPolicy(GUI, lhf.protocolInfo('goNogo')).pFirst, 0.3);
        end

        function everyProtocolIsDescribed(tc)
            for p = {'goNogo', 'powercal', '2AFC', 'MTS'}
                info = lhf.protocolInfo(p{1});
                tc.verifyTrue(ismember(info.task, {'goNogo', 'choice'}), p{1});
                tc.verifyNumElements(info.typeNames, 2);
                tc.verifyNumElements(info.odourTypes, 3);
            end
            tc.verifyError(@() lhf.protocolInfo('maze'), 'lhf:protocolInfo:protocol');
        end
    end
end

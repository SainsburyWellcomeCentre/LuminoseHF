classdef LivePlotsTest < matlab.unittest.TestCase
% The live plots (lhf.plot.*) in an invisible window, fed made-up sessions.

    properties
        fig
        ax
        info
    end

    methods (TestMethodSetup)
        function openWindow(tc)
            [tc.fig, tc.ax] = lhf.plot.createFigure('Visible', 'off');
            tc.info = lhf.protocolInfo('goNogo');
        end
    end

    methods (TestMethodTeardown)
        function closeWindow(tc)
            delete(tc.fig);
        end
    end

    methods (Test)
        function windowHasFiveAxes(tc)
            for name = {'Outcome', 'Accuracy', 'Reward', 'Response', 'Encoder'}
                tc.verifyClass(tc.ax.(name{1}), 'matlab.graphics.axis.Axes');
            end
        end

        function outcomeMarksEachTrialInItsCategory(tc)
            C = lhf.Outcome.Correct; I = lhf.Outcome.Incorrect;
            data = fakeSession([1 2 1], [C I C]);
            lhf.plot.outcome(tc.ax.Outcome, 'init', tc.info, 1);
            for n = 1:3
                data.nTrials = n;
                lhf.plot.outcome(tc.ax.Outcome, 'update', data, 2);
            end
            st = tc.ax.Outcome.UserData;
            tc.verifyEqual(st.x.correct, [1 3]);
            tc.verifyEqual(st.y.correct, [1 1]);
            tc.verifyEqual(st.x.error, 2);
            tc.verifyEqual(get(st.current, 'XData'), 4);   % next trial
            tc.verifyEqual(get(st.current, 'YData'), 0);   % type 2 row
            tc.verifyEqual(tc.ax.Outcome.YTickLabel(:)', {'No go', 'Go'});
        end

        function noResponseHasItsOwnMark(tc)
            data = fakeSession(1, lhf.Outcome.NoResponse);
            lhf.plot.outcome(tc.ax.Outcome, 'init', lhf.protocolInfo('2AFC'), 1);
            lhf.plot.outcome(tc.ax.Outcome, 'update', data, 1);
            tc.verifyEqual(tc.ax.Outcome.UserData.x.noresp, 1);
        end

        function dprimeIsZeroAtChanceAndGrowsWithHits(tc)
            tc.verifyEqual(lhf.dprime(5, 10, 5, 10), 0, 'AbsTol', 1e-12);
            % log-linear rates: 10.5/11 hits, 0.5/11 false alarms
            expected = -sqrt(2) * erfcinv(2 * 10.5 / 11) + sqrt(2) * erfcinv(2 * 0.5 / 11);
            tc.verifyEqual(lhf.dprime(10, 10, 0, 10), expected, 'AbsTol', 1e-12);
            tc.verifyTrue(isfinite(lhf.dprime(10, 10, 0, 10)));
            tc.verifyLessThan(lhf.dprime(2, 10, 8, 10), 0);
        end

        function dprimeReadsHitsAndFalseAlarms(tc)
            C = lhf.Outcome.Correct; I = lhf.Outcome.Incorrect;
            [window, axs] = lhf.plot.createFigure('Visible', 'off', 'WithDprime', true);
            tc.addTeardown(@() delete(window));
            lhf.plot.dprime(axs.Dprime, 'init');
            data = fakeSession([1 1 1 1], [C C I C]);   % Go only: no d' yet
            lhf.plot.dprime(axs.Dprime, 'update', data);
            tc.verifyTrue(all(isnan(axs.Dprime.UserData.moving)));
            tc.verifySubstring(axs.Dprime.Title.String, 'needs Go and No-Go');
            data = fakeSession([1 1 1 1 2 2 2], [C C I C C I C]);   % 3/4 hits, 1/3 FA
            lhf.plot.dprime(axs.Dprime, 'update', data);
            tc.verifyEqual(axs.Dprime.UserData.moving(end), lhf.dprime(3, 4, 1, 3), 'AbsTol', 1e-12);
            tc.verifySubstring(axs.Dprime.Title.String, 'hits 3/4, false alarms 1/3');
        end

        function theWindowCanHoldDprimeAndPower(tc)
            [window, axs] = lhf.plot.createFigure('Visible', 'off', 'WithDprime', true, ...
                'WithPower', true);
            tc.addTeardown(@() delete(window));
            tc.verifyClass(axs.Dprime, 'matlab.graphics.axis.Axes');
            tc.verifyClass(axs.Power, 'matlab.graphics.axis.Axes');
        end

        function analogShowsEachChannelOfTheLastTrial(tc)
            [window, axs] = lhf.plot.createFigure('Visible', 'off', 'WithAnalog', true);
            tc.addTeardown(@() delete(window));
            names = {'Sniff', 'Photodetector', 'Flowmeter', 'NI-DAQ'};
            lhf.plot.analog(axs.Analog, 'init', names);
            st = axs.Analog.UserData;
            tc.verifyEqual({st.traces.DisplayName}, names);
            t = (0:4999)' / 1000;  % 5 s at 1 kHz: thinned to 2000 points
            volts = [sin(t) + 2, t / 5, ones(size(t)), zeros(size(t))];
            lhf.plot.analog(axs.Analog, 'update', t, volts);
            tc.verifyLessThanOrEqual(numel(st.traces(1).XData), 2000);
            tc.verifyEqual(st.traces(3).YData(:), ones(numel(st.traces(3).YData), 1));
            tc.verifyEqual(axs.Analog.XLim, [0 t(end)]);
            lhf.plot.analog(axs.Analog, 'update', zeros(0, 1), zeros(0, 4));  % no samples: kept
            tc.verifyEqual(axs.Analog.XLim, [0 t(end)]);
        end

        function accuracyReadsTheStoredOutcomes(tc)
            C = lhf.Outcome.Correct; I = lhf.Outcome.Incorrect;
            data = fakeSession([1 1 2 2], [C I C C]);
            lhf.plot.accuracy(tc.ax.Accuracy, 'init', tc.info);
            lhf.plot.accuracy(tc.ax.Accuracy, 'update', data);
            st = tc.ax.Accuracy.UserData;
            tc.verifyEqual(st.moving(end, :), [0.5 1 0.75], 'AbsTol', 1e-12);
            tc.verifySubstring(st.title.String, '75.0% (3/4)');
        end

        function accuracyAveragesEachTypesOwnLastTrials(tc)
            % 20 CS+ trials (half correct), then 20 CS- trials: the CS+ line still
            % covers its own last 20, Overall the last 20 trials
            C = lhf.Outcome.Correct; I = lhf.Outcome.Incorrect;
            data = fakeSession([ones(1, 20), 2 * ones(1, 20)], [repmat(I, 1, 10), repmat(C, 1, 30)]);
            lhf.plot.accuracy(tc.ax.Accuracy, 'init', tc.info);
            lhf.plot.accuracy(tc.ax.Accuracy, 'update', data);
            tc.verifyEqual(tc.ax.Accuracy.UserData.moving(end, :), [0.5 1 1], 'AbsTol', 1e-12);
        end

        function accuracyOnlyScoresNewTrials(tc)
            C = lhf.Outcome.Correct;
            data = fakeSession([1 2], [C C]);
            lhf.plot.accuracy(tc.ax.Accuracy, 'init', tc.info);
            lhf.plot.accuracy(tc.ax.Accuracy, 'update', data);
            % An already-scored trial is not re-read
            data.TrialOutcome(1) = lhf.Outcome.Incorrect;
            data = appendTrial(data, 1, C);
            lhf.plot.accuracy(tc.ax.Accuracy, 'update', data);
            tc.verifyEqual(tc.ax.Accuracy.UserData.correct(:, 3)', [1 1 1]);
        end

        function rewardAddsUpTheRewardedTrials(tc)
            C = lhf.Outcome.Correct; I = lhf.Outcome.Incorrect;
            data = fakeSession([1 1 2 1], [C I C C], 'RewardAmount', 2.5);
            lhf.plot.reward(tc.ax.Reward, 'init');
            lhf.plot.reward(tc.ax.Reward, 'update', data);
            st = tc.ax.Reward.UserData;
            tc.verifyEqual(st.history, [2.5 2.5 2.5 5]);
            tc.verifySubstring(st.title.String, '5.00');
        end

        function responseTimeHasARunningMedian(tc)
            data = fakeSession([1 1 1], [1 1 1], 'ResponseTime', 0.4);
            data.RawEvents.Trial{3}.States.GetResponse = [2 3];
            lhf.plot.responseTime(tc.ax.Response, 'init');
            lhf.plot.responseTime(tc.ax.Response, 'update', data);
            st = tc.ax.Response.UserData;
            tc.verifyEqual(st.times, [0.4 0.4 1], 'AbsTol', 1e-12);
            tc.verifyEqual(st.medians, [0.4 0.4 0.4], 'AbsTol', 1e-12);
        end

        function encoderDrawsTheLastTrial(tc)
            lhf.plot.encoder(tc.ax.Encoder, 'init', 10);
            enc = struct('Times', [0 1 2], 'Positions', [0 5 -5]);
            lhf.plot.encoder(tc.ax.Encoder, 'update', 10, enc, 2);
            st = tc.ax.Encoder.UserData;
            tc.verifyEqual(get(st.trace, 'YData'), [0 5 -5]);
            tc.verifyEqual(tc.ax.Encoder.YLim, [-20 20]);
            tc.verifyNumElements(st.thresholds, 2);
            tc.verifyEqual(tc.ax.Encoder.Title.String, 'Rotary Encoder (last trial)');
        end

        function powerPanelOnlyWhenAsked(tc)
            tc.verifyFalse(isfield(tc.ax, 'Power'));
            [fig, ax] = lhf.plot.createFigure('Visible', 'off', 'WithPower', true);
            closer = onCleanup(@() delete(fig));
            tc.verifyClass(ax.Power, 'matlab.graphics.axis.Axes');
        end

        function powerGroupsTrialsByIrradiance(tc)
            C = lhf.Outcome.Correct; I = lhf.Outcome.Incorrect;
            data = fakeSession([1 2 1 1 2], [C C I C I]);
            data.LaserIrradiance_mWmm2 = [14.5 2 14.5 NaN 14.5];
            [fig, ax] = lhf.plot.createFigure('Visible', 'off', 'WithPower', true);
            closer = onCleanup(@() delete(fig));
            lhf.plot.power(ax.Power, 'init', tc.info);
            lhf.plot.power(ax.Power, 'update', data);
            st = ax.Power.UserData;
            tc.verifyEqual(st.powers', [14.5 2]);
            tc.verifyEqual(st.n, [2 1 3; 0 1 1]);           % the NaN trial is left out
            tc.verifyEqual(st.correct, [1 0 1; 0 1 1]);
            tc.verifyEqual(get(st.lines(3), 'XData'), [2 14.5]);
            tc.verifyEqual(get(st.lines(3), 'YData'), [100 100/3], 'AbsTol', 1e-12);
            % Only new trials are read
            data.TrialOutcome(1) = I;
            data = appendTrial(data, 1, C);
            data.LaserIrradiance_mWmm2(6) = 2;
            lhf.plot.power(ax.Power, 'update', data);
            tc.verifyEqual(ax.Power.UserData.n(2, :), [1 1 2]);
            tc.verifyEqual(ax.Power.UserData.correct(1, :), [1 0 1]);
        end
    end
end

function data = appendTrial(data, type, outcome)
    n = data.nTrials + 1;
    more = fakeSession(type, outcome);
    data.nTrials = n;
    data.TrialTypes(n) = type;
    data.TrialOutcome(n) = outcome;
    data.RawEvents.Trial{n} = more.RawEvents.Trial{1};
    data.TrialSettings(n) = more.TrialSettings(1);
end

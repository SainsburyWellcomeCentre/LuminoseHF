function accuracy(ax, action, varargin)
% lhf.plot.accuracy  Moving accuracy per trial type and overall.
%
%   lhf.plot.accuracy(ax, 'init', info)
%   lhf.plot.accuracy(ax, 'update', data)
%
%   info  lhf.protocolInfo(protocol): typeNames name the two lines
%   data  BpodSystem.Data; reads TrialTypes and TrialOutcome (lhf.scoreTrial)
%
%   A trial counts as correct when its outcome is lhf.Outcome.Correct;
%   incorrect and no-response trials count against. Each line averages the
%   last WINDOW trials of its type. Only trials added since the last update
%   are scored; the rest are kept in ax.UserData.

    WINDOW = 20;

    switch action
        case 'init'
            info = varargin{1};
            cla(ax);
            hold(ax, 'on');
            st.lines(1) = plot(ax, NaN, NaN, '-o', 'Color', [0.18 0.55 0.80], 'LineWidth', 2, ...
                'MarkerSize', 4, 'MarkerFaceColor', [0.18 0.55 0.80], ...
                'DisplayName', sprintf('%s — win=%d', info.typeNames{1}, WINDOW));
            st.lines(2) = plot(ax, NaN, NaN, '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2, ...
                'MarkerSize', 4, 'MarkerFaceColor', [0.85 0.33 0.10], ...
                'DisplayName', sprintf('%s — win=%d', info.typeNames{2}, WINDOW));
            st.lines(3) = plot(ax, NaN, NaN, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.5, ...
                'DisplayName', 'Overall');
            yline(ax, 50, ':', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.2, 'HandleVisibility', 'off');
            hold(ax, 'off');

            ax.XLabel.String = 'Trial';
            ax.YLabel.String = 'Accuracy (%)';
            ax.YLim = [0 100];
            ax.FontSize = 11;
            ax.Box = 'on';
            ax.LineWidth = 1.2;
            grid(ax, 'on');
            ax.GridAlpha = 0.25;
            legend(ax, 'Location', 'southwest', 'FontSize', 9);
            st.title = title(ax, 'Moving Accuracy', 'FontSize', 12, 'FontWeight', 'bold', ...
                'Color', [0.2 0.2 0.2]);

            % correct(:, k): trial correct (1/0) if of type k, NaN otherwise; column 3 all trials
            st.correct = zeros(0, 3);
            st.moving  = zeros(0, 3);
            ax.UserData = st;

        case 'update'
            data = varargin{1};
            st = ax.UserData;
            nTrials = numel(data.TrialOutcome);
            for i = size(st.correct, 1)+1:nTrials
                isCorrect = double(data.TrialOutcome(i) == lhf.Outcome.Correct);
                row = [NaN NaN isCorrect];
                row(data.TrialTypes(i)) = isCorrect;
                st.correct(i, :) = row;
                for k = 1:3
                    st.moving(i, k) = windowMean(st.correct(:, k), i, WINDOW);
                end
            end
            ax.UserData = st;
            if nTrials == 0, return; end

            trials = 1:nTrials;
            for k = 1:3
                set(st.lines(k), 'XData', trials, 'YData', st.moving(:, k)' * 100);
            end
            ax.XLim = [max(1, nTrials - 200), max(WINDOW + 1, nTrials + 1)];

            totalCorrect = sum(st.correct(:, 3));
            overall = totalCorrect / nTrials * 100;
            if overall >= 75
                colour = [0.13 0.55 0.13];
            elseif overall >= 50
                colour = [0.80 0.50 0.10];
            else
                colour = [0.75 0.15 0.15];
            end
            set(st.title, 'String', sprintf('Mov. Acc. (win=%d) — Total: %.1f%% (%d/%d)', ...
                WINDOW, overall, totalCorrect, nTrials), 'Color', colour);
    end
end

function m = windowMean(values, i, window)
% Mean of the window ending at trial i, ignoring NaN (trials of the other type)
    v = values(max(1, i - window + 1):i);
    v = v(~isnan(v));
    if isempty(v)
        m = NaN;
    else
        m = mean(v);
    end
end

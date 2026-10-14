function dprime(ax, action, varargin)
% lhf.plot.dprime  Moving d' (sensitivity) of a go/no-go session.
%
%   lhf.plot.dprime(ax, 'init')
%   lhf.plot.dprime(ax, 'update', data)
%
%   data  BpodSystem.Data; reads TrialTypes (1 Go, 2 No-Go, lhf.protocolInfo) and
%         TrialOutcome (lhf.scoreTrial)
%
%   d' (lhf.dprime) from hits, Go trials scored Correct, and false alarms, No-Go trials
%   scored Incorrect (licked). The line uses each type's last WINDOW trials, as lhf.plot.accuracy does; it
%   starts once both types have a trial. The title gives the whole session's d', hit and
%   false-alarm rates. 0 is chance; the dotted line at 1 is a usual learning criterion.
%   Only trials added since the last update are scored; the rest are kept in ax.UserData.
%
% See also lhf.dprime, lhf.plot.accuracy, lhf.plot.createFigure, lhf.scoreTrial

    WINDOW = 20;

    switch action
        case 'init'
            cla(ax);
            hold(ax, 'on');
            st.line = plot(ax, NaN, NaN, '-o', 'Color', [0.45 0.20 0.60], 'LineWidth', 2, ...
                'MarkerSize', 4, 'MarkerFaceColor', [0.45 0.20 0.60], ...
                'DisplayName', sprintf('d'' (last %d of each type)', WINDOW));
            yline(ax, 0, '-', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
            yline(ax, 1, ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2, 'HandleVisibility', 'off');
            hold(ax, 'off');
            ax.XLabel.String = 'Trial';
            ax.YLabel.String = 'd''';
            ax.YLim = [-1 4];
            ax.FontSize = 11;
            ax.Box = 'on';
            ax.LineWidth = 1.2;
            grid(ax, 'on');
            ax.GridAlpha = 0.25;
            st.title = title(ax, 'd''', 'FontSize', 12, 'FontWeight', 'bold', ...
                'Color', [0.2 0.2 0.2]);
            % go(i): 1 hit, 0 miss, NaN not a Go trial; noGo(i): 1 false alarm, 0 correct
            % rejection, NaN not a No-Go trial
            st.go = zeros(0, 1);
            st.noGo = zeros(0, 1);
            st.moving = zeros(0, 1);
            ax.UserData = st;

        case 'update'
            data = varargin{1};
            st = ax.UserData;
            nTrials = numel(data.TrialOutcome);
            for i = numel(st.go)+1:nTrials
                outcome = data.TrialOutcome(i);
                st.go(i, 1) = NaN;
                st.noGo(i, 1) = NaN;
                if data.TrialTypes(i) == 1
                    st.go(i) = double(outcome == lhf.Outcome.Correct);
                elseif data.TrialTypes(i) == 2
                    st.noGo(i) = double(outcome == lhf.Outcome.Incorrect);
                end
                g = lastOf(st.go(1:i), WINDOW);
                f = lastOf(st.noGo(1:i), WINDOW);
                st.moving(i, 1) = NaN;
                if ~isempty(g) && ~isempty(f)
                    st.moving(i) = lhf.dprime(sum(g), numel(g), sum(f), numel(f));
                end
            end
            ax.UserData = st;
            if nTrials == 0, return; end

            set(st.line, 'XData', 1:nTrials, 'YData', st.moving');
            ax.XLim = [max(1, nTrials - 200), max(WINDOW + 1, nTrials + 1)];
            top = max([4; st.moving(isfinite(st.moving)) + 0.5]);
            bottom = min([-1; st.moving(isfinite(st.moving)) - 0.5]);
            ax.YLim = [bottom top];

            g = st.go(~isnan(st.go));
            f = st.noGo(~isnan(st.noGo));
            if isempty(g) || isempty(f)
                set(st.title, 'String', 'd'' (needs Go and No-Go trials)', ...
                    'Color', [0.2 0.2 0.2]);
                return
            end
            d = lhf.dprime(sum(g), numel(g), sum(f), numel(f));
            if d >= 1.5
                colour = [0.13 0.55 0.13];
            elseif d >= 1
                colour = [0.80 0.50 0.10];
            else
                colour = [0.75 0.15 0.15];
            end
            set(st.title, 'String', sprintf(['d'' (win=%d) — Total: %.2f  (hits %d/%d, ' ...
                'false alarms %d/%d)'], WINDOW, d, sum(g), numel(g), sum(f), numel(f)), ...
                'Color', colour);
    end
end


function v = lastOf(values, window)
% The last window values that are not NaN.
    v = values(~isnan(values));
    v = v(max(1, end - window + 1):end);
end

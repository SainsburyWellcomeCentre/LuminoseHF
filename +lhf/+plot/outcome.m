function outcome(ax, action, varargin)
% lhf.plot.outcome  Trial-by-trial outcomes, and the next trial's type.
%
%   lhf.plot.outcome(ax, 'init', info, nextType)
%   lhf.plot.outcome(ax, 'update', data, nextType)
%
%   info      lhf.protocolInfo(protocol): tickNames label the two rows
%   data      BpodSystem.Data; reads TrialTypes and TrialOutcome (lhf.scoreTrial)
%   nextType  the type of the trial prepared next (drawn as the blue dot)
%
%   Filled green correct, filled red incorrect, open grey no response. Only
%   the newest trial is added on each update; the axes keep the rest in
%   ax.UserData. The caller redraws (drawnow) once all plots are updated.

    switch action
        case 'init'
            [info, nextType] = varargin{:};
            cla(ax);
            hold(ax, 'on');
            st.correct = plot(ax, NaN, NaN, 'go', 'MarkerFaceColor', 'g');
            st.error   = plot(ax, NaN, NaN, 'ro', 'MarkerFaceColor', 'r');
            st.noresp  = plot(ax, NaN, NaN, 'o', 'Color', [0.7 0.7 0.7], 'MarkerFaceColor', 'none');
            st.current = plot(ax, NaN, NaN, 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 8);
            hold(ax, 'off');
            set(ax, 'YLim', [-0.5 1.5], 'YTick', [0 1], ...
                'YTickLabel', fliplr(info.tickNames), 'XLim', [0 10], 'TickDir', 'out');
            xlabel(ax, 'Trial #');
            st.x = struct('correct', [], 'error', [], 'noresp', []);
            st.y = st.x;
            ax.UserData = st;
            moveCurrent(ax, 1, nextType);

        case 'update'
            [data, nextType] = varargin{:};
            st = ax.UserData;
            i = data.nTrials;
            row = double(data.TrialTypes(i) == 1);
            switch data.TrialOutcome(i)
                case lhf.Outcome.Correct,    key = 'correct';
                case lhf.Outcome.Incorrect,  key = 'error';
                case lhf.Outcome.NoResponse, key = 'noresp';
                otherwise,                   key = '';
            end
            if ~isempty(key)
                st.x.(key)(end+1) = i;
                st.y.(key)(end+1) = row;
                safeSet(st.(key), st.x.(key), st.y.(key));
            end
            ax.UserData = st;
            set(ax, 'XLim', [max(i - 100, 0) max(i + 1, 100)]);
            moveCurrent(ax, i + 1, nextType);
    end
end

function moveCurrent(ax, trial, nextType)
    if isempty(nextType)
        set(ax.UserData.current, 'XData', NaN, 'YData', NaN);
    else
        set(ax.UserData.current, 'XData', trial, 'YData', double(nextType == 1));
    end
end

function safeSet(h, x, y)
% A line made with plot(NaN, NaN) has length 1; setting XData to [] first
% leaves a length mismatch that warns at the next drawnow. NaN keeps it at 1.
    if isempty(x)
        x = NaN; y = NaN;
    end
    set(h, 'XData', x, 'YData', y);
end

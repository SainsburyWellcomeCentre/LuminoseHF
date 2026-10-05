function liveTrackingPlot_hf_sleep(ax, action, data, nextTrialType)
persistent h

switch action
    case 'init'
        axes(ax); cla; hold on

        % Completed trials
        h.previous  = plot(NaN, NaN, 'ko', 'MarkerFaceColor', 'none');

        % Current trial as blue dot
        h.current = plot(NaN, NaN, 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 8);

        set(ax, 'YLim', [-0.5 1.5], ...
                'YTick', [0 1], ...
                'YTickLabel', {'2', '1'}, ...
                'XLim', [0 10], ...
                'TickDir', 'out')
        xlabel('Trial #')

        % Draw blue dot for trial 1 immediately
        if nargin >= 4 && ~isempty(nextTrialType)
            set(h.current, 'XData', 1, 'YData', nextTrialType == 1)
        end
        drawnow

    case 'update'
        nDone = data.nTrials;
        xPrev = []; yPrev = [];

        % Plot all completed trials
        for i = 1:nDone
            side    = data.TrialTypes(i) == 1;
            xPrev(end+1) = i; yPrev(end+1) = side;
        end

        set(h.previous,  'XData', xPrev, 'YData', yPrev)

        % Move blue dot to the next trial
        nextTrial = nDone + 1;

        if nargin >= 4 && ~isempty(nextTrialType)
            nextSide = nextTrialType == 1;  % 1->Left(1), 2->Right(0)
        else
            nextSide = NaN;
        end

        % Extend x-axis if needed
        xlim(ax, [0 max(10, nextTrial + 5)])

        set(h.current, 'XData', nextTrial, 'YData', nextSide)
        drawnow
end
end


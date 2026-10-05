function encoder(ax, action, choiceThreshold, varargin)
% lhf.plot.encoder  The last trial's rotary encoder position.
%
%   lhf.plot.encoder(ax, 'init', choiceThreshold)
%   lhf.plot.encoder(ax, 'update', choiceThreshold, encoderData, trialDuration)
%
%   encoderData  Data.EncoderData{n} (fields Times, Positions)
%   With a choiceThreshold other than 0, dotted lines mark ±threshold and
%   the axes are fitted to the trial.

    switch action
        case 'init'
            cla(ax);
            st.trace = plot(ax, 0, 0, 'k-', 'LineWidth', 2);
            st.thresholds = gobjects(0);
            if choiceThreshold ~= 0
                st.thresholds(1) = line(ax, [0 1000], -[1 1] * choiceThreshold, 'Color', 'k', 'LineStyle', ':');
                st.thresholds(2) = line(ax, [0 1000],  [1 1] * choiceThreshold, 'Color', 'k', 'LineStyle', ':');
            end
            set(ax, 'Box', 'off', 'TickDir', 'out');
            ylabel(ax, 'Position (deg)', 'FontSize', 12);
            xlabel(ax, 'Time (s)', 'FontSize', 12);
            title(ax, 'Rotary Encoder (last trial)');
            ax.UserData = st;

        case 'update'
            [encoderData, trialDuration] = varargin{:};
            st = ax.UserData;
            set(st.trace, 'XData', encoderData.Times, 'YData', encoderData.Positions);
            if choiceThreshold ~= 0
                set(ax, 'YLim', [-2 2] * choiceThreshold, 'XLim', [0 trialDuration]);
            end
    end
end

function analog(ax, action, varargin)
% lhf.plot.analog  The last trial's Flex I/O analog channels (sniff, photodetector, ...).
%
%   lhf.plot.analog(ax, 'init', names)        names: one label per analog channel
%   lhf.plot.analog(ax, 'update', t, volts)   from lhf.bpod.readTrialAnalog
%
%   One line per channel, in volts, over the trial; drawn once per trial, so it replaces
%   Bpod's Flex I/O viewer (ten redraws a second) for watching the signals during a
%   session. More than 2000 samples per channel are thinned to 2000 for drawing. A trial
%   with no samples leaves the last one shown.

    switch action
        case 'init'
            names = varargin{1};
            cla(ax);
            colours = lines(numel(names));
            st.traces = gobjects(1, numel(names));
            for k = 1:numel(names)
                st.traces(k) = line(ax, NaN, NaN, 'Color', colours(k, :), 'LineWidth', 1, ...
                    'DisplayName', names{k});
            end
            set(ax, 'Box', 'off', 'TickDir', 'out', 'YLim', [0 5]);
            ylabel(ax, 'Volts', 'FontSize', 12);
            xlabel(ax, 'Time (s)', 'FontSize', 12);
            title(ax, 'Analog inputs (last trial)');
            legend(ax, 'Location', 'eastoutside', 'Box', 'off', 'AutoUpdate', 'off');
            ax.UserData = st;

        case 'update'
            [t, volts] = varargin{:};
            if isempty(t), return; end
            st = ax.UserData;
            step = max(1, ceil(numel(t) / 2000));
            keep = 1:step:numel(t);
            for k = 1:min(numel(st.traces), size(volts, 2))
                set(st.traces(k), 'XData', t(keep), 'YData', volts(keep, k));
            end
            if t(end) > 0
                ax.XLim = [0 t(end)];
            end
    end
end

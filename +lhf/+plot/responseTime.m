function responseTime(ax, action, varargin)
% lhf.plot.responseTime  Response time per trial and its running median.
%
%   lhf.plot.responseTime(ax, 'init')
%   lhf.plot.responseTime(ax, 'update', data)
%
%   Response time as lhf.responseTime defines it. Only trials added since the
%   last update are measured; the rest are kept in ax.UserData.

    switch action
        case 'init'
            cla(ax);
            hold(ax, 'on');
            st.line   = plot(ax, [NaN NaN], [NaN NaN], 'LineWidth', 2);
            st.median = plot(ax, [NaN NaN], [NaN NaN], 'k', 'LineWidth', 2);
            hold(ax, 'off');
            xlabel(ax, 'Trial #');
            ylabel(ax, 'Response Time (s)');
            st.title = title(ax, 'Response Time');
            grid(ax, 'on');
            ax.Box = 'on';
            ax.FontSize = 11;
            st.times = [];
            st.medians = [];
            ax.UserData = st;

        case 'update'
            data = varargin{1};
            st = ax.UserData;
            nTrials = numel(data.RawEvents.Trial);
            for i = numel(st.times)+1:nTrials
                st.times(i) = lhf.responseTime(data.RawEvents.Trial{i});
                st.medians(i) = median(st.times, 'omitnan');
            end
            ax.UserData = st;
            if nTrials == 0, return; end
            trials = 1:nTrials;
            set(st.line,   'XData', trials, 'YData', st.times);
            set(st.median, 'XData', trials, 'YData', st.medians);
            if ~isnan(st.medians(end))
                set(st.title, 'String', sprintf('Response Time (median = %.3f s)', st.medians(end)));
            end
    end
end

function power(ax, action, varargin)
% lhf.plot.power  Percent correct against laser irradiance (mW/mm2), per trial type and overall.
%
%   lhf.plot.power(ax, 'init', info)
%   lhf.plot.power(ax, 'update', data)
%
%   info  lhf.protocolInfo(protocol): typeNames name the two lines
%   data  BpodSystem.Data; reads TrialTypes, TrialOutcome (lhf.scoreTrial)
%         and LaserIrradiance_mWmm2
%
%   Each point is every trial so far at that irradiance. Trials with no power
%   set (NaN irradiance) are left out. Only trials added since the last
%   update are read; the counts per irradiance are kept in ax.UserData.

    switch action
        case 'init'
            info = varargin{1};
            cla(ax);
            hold(ax, 'on');
            st.lines(1) = plot(ax, NaN, NaN, '-o', 'Color', [0.18 0.55 0.80], 'LineWidth', 2, ...
                'MarkerSize', 6, 'MarkerFaceColor', [0.18 0.55 0.80], 'DisplayName', info.typeNames{1});
            st.lines(2) = plot(ax, NaN, NaN, '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2, ...
                'MarkerSize', 6, 'MarkerFaceColor', [0.85 0.33 0.10], 'DisplayName', info.typeNames{2});
            st.lines(3) = plot(ax, NaN, NaN, '--d', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.5, ...
                'MarkerSize', 5, 'DisplayName', 'Overall');
            yline(ax, 50, ':', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.2, 'HandleVisibility', 'off');
            hold(ax, 'off');

            ax.XLabel.String = 'Irradiance (mW/mm^2)';
            ax.YLabel.String = 'Correct (%)';
            ax.YLim = [0 100];
            ax.FontSize = 11;
            ax.Box = 'on';
            ax.LineWidth = 1.2;
            grid(ax, 'on');
            ax.GridAlpha = 0.25;
            legend(ax, 'Location', 'southeast', 'FontSize', 9);
            title(ax, 'Performance vs Power', 'FontSize', 12, 'FontWeight', 'bold', ...
                'Color', [0.2 0.2 0.2]);

            % Row p is irradiance powers(p); columns: type 1, type 2, all trials
            st.powers  = zeros(0, 1);
            st.n       = zeros(0, 3);
            st.correct = zeros(0, 3);
            st.nRead   = 0;
            ax.UserData = st;

        case 'update'
            data = varargin{1};
            st = ax.UserData;
            if ~isfield(data, 'LaserIrradiance_mWmm2'), return; end
            nTrials = min(numel(data.TrialOutcome), numel(data.LaserIrradiance_mWmm2));
            for i = st.nRead+1:nTrials
                irradiance = data.LaserIrradiance_mWmm2(i);
                if isnan(irradiance), continue; end
                p = find(st.powers == irradiance, 1);
                if isempty(p)
                    p = numel(st.powers) + 1;
                    st.powers(p, 1) = irradiance;
                    st.n(p, :) = 0;
                    st.correct(p, :) = 0;
                end
                cols = [data.TrialTypes(i) 3];
                st.n(p, cols) = st.n(p, cols) + 1;
                st.correct(p, cols) = st.correct(p, cols) + double(data.TrialOutcome(i) == lhf.Outcome.Correct);
            end
            st.nRead = max(st.nRead, nTrials);
            ax.UserData = st;
            if isempty(st.powers), return; end

            [x, order] = sort(st.powers);
            pct = st.correct(order, :) ./ st.n(order, :) * 100;   % NaN where a type has no trials
            for k = 1:3
                set(st.lines(k), 'XData', x', 'YData', pct(:, k)');
            end
            pad = max(0.5, 0.05 * (x(end) - x(1)));
            ax.XLim = [x(1) - pad, x(end) + pad];
    end
end

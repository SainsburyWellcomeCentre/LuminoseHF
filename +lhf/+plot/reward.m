function reward(ax, action, varargin)
% lhf.plot.reward  Cumulative reward volume (µL) across trials.
%
%   lhf.plot.reward(ax, 'init')
%   lhf.plot.reward(ax, 'update', data)
%
%   A trial adds TrialSettings(n).GUI.RewardAmount when it visited the
%   Reward state. Only trials added since the last update are summed; the
%   running total is kept in ax.UserData.

    switch action
        case 'init'
            cla(ax);
            st.line = plot(ax, 0, 0, 'LineWidth', 2);
            xlabel(ax, 'Trial #');
            ylabel(ax, 'Cumulative Reward (µL)');
            st.title = title(ax, 'Total Reward Delivered: 0 µL');
            grid(ax, 'on');
            ax.Box = 'on';
            ax.FontSize = 11;
            st.history = [];
            ax.UserData = st;

        case 'update'
            data = varargin{1};
            st = ax.UserData;
            nTrials = numel(data.RawEvents.Trial);
            total = 0;
            if ~isempty(st.history), total = st.history(end); end
            for i = numel(st.history)+1:nTrials
                total = total + rewardOf(data, i);
                st.history(i) = total;
            end
            ax.UserData = st;
            if nTrials == 0, return; end
            set(st.line, 'XData', 1:nTrials, 'YData', st.history);
            set(st.title, 'String', sprintf('Total Reward Delivered: %.2f µL', total));
    end
end

function amount = rewardOf(data, i)
    amount = 0;
    states = data.RawEvents.Trial{i}.States;
    if isfield(states, 'Reward') && ~isnan(states.Reward(1))
        amount = data.TrialSettings(i).GUI.RewardAmount;
        if isempty(amount) || isnan(amount)
            amount = 0;
        end
    end
end

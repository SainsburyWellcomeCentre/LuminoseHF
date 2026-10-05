function data = fakeSession(types, outcomes, varargin)
% fakeSession  A BpodSystem.Data-like struct for tests.
%
%   data = fakeSession(types, outcomes)
%   data = fakeSession(types, outcomes, 'RewardAmount', 3, 'ResponseTime', 0.4)
%
%   Trial n has type types(n) and outcome outcomes(n) (lhf.Outcome codes).
%   Correct trials of type 1 visit Reward; every trial spends ResponseTime
%   in GetResponse; TrialSettings(n).GUI.RewardAmount is RewardAmount.

    p = inputParser;
    p.addParameter('RewardAmount', 3);
    p.addParameter('ResponseTime', 0.4);
    p.parse(varargin{:});

    n = numel(types);
    data.nTrials = n;
    data.TrialTypes = types;
    data.TrialOutcome = outcomes;
    data.TrialResponse = NaN(1, n);
    data.RawEvents.Trial = cell(1, n);
    for i = 1:n
        args = {'GetResponse', [2, 2 + p.Results.ResponseTime]};
        if outcomes(i) == lhf.Outcome.Correct && types(i) == 1
            args = [args, {'Reward', [3 3.1]}]; %#ok<AGROW>
        else
            args = [args, {'Reward', [NaN NaN]}]; %#ok<AGROW>
        end
        data.RawEvents.Trial{i} = fakeTrial(args{:});
        data.TrialSettings(i).GUI = struct('RewardAmount', p.Results.RewardAmount, 'CSplus_prob', 0.5);
    end
end

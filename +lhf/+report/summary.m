function s = summary(data, info)
% lhf.report.summary  A behaviour session's numbers, from its data alone.
%
%   s = lhf.report.summary(data, info)
%
%   data  BpodSystem.Data (TrialTypes, TrialOutcome, TrialResponse, RawEvents,
%         TrialSettings)
%   info  lhf.protocolInfo(protocol)
%
%   s.nTrials                 trials recorded
%   s.byType(k)               for type k: name, n, correct, incorrect,
%                             noResponse, percentCorrect
%   s.correct, percentCorrect all types
%   s.rewardTotal             µL delivered (TrialSettings(n).GUI.RewardAmount)
%   s.medianResponseTime      s, over trials that left GetResponse (NaN if none)
%   s.settingChanges          struct array: name, trial, from, to, one per
%                             change of an S.GUI value during the session

    s.nTrials = 0;
    if isfield(data, 'TrialOutcome')
        s.nTrials = numel(data.TrialOutcome);
    end
    n = s.nTrials;
    types = zeros(1, n);
    outcomes = zeros(1, n);
    if n > 0
        types = data.TrialTypes(1:n);
        outcomes = data.TrialOutcome(1:n);
    end

    for k = 1:2
        ofType = types == k;
        t.name = info.typeNames{k};
        t.n = sum(ofType);
        t.correct = sum(ofType & outcomes == lhf.Outcome.Correct);
        t.incorrect = sum(ofType & outcomes == lhf.Outcome.Incorrect);
        t.noResponse = sum(ofType & outcomes == lhf.Outcome.NoResponse);
        t.percentCorrect = percent(t.correct, t.n);
        s.byType(k) = t;
    end
    s.correct = sum(outcomes == lhf.Outcome.Correct);
    s.percentCorrect = percent(s.correct, n);

    s.rewardTotal = 0;
    rts = NaN(1, n);
    for i = 1:n
        trial = data.RawEvents.Trial{i};
        if isfield(trial.States, 'Reward') && ~isnan(trial.States.Reward(1))
            amount = data.TrialSettings(i).GUI.RewardAmount;
            if ~isempty(amount) && ~isnan(amount)
                s.rewardTotal = s.rewardTotal + amount;
            end
        end
        rts(i) = lhf.responseTime(trial);
    end
    s.medianResponseTime = median(rts, 'omitnan');

    s.settingChanges = struct('name', {}, 'trial', {}, 'from', {}, 'to', {});
    if n > 1 && isfield(data, 'TrialSettings')
        for i = 2:n
            before = data.TrialSettings(i - 1).GUI;
            after = data.TrialSettings(i).GUI;
            for name = fieldnames(after)'
                f = name{1};
                if startsWith(f, 'delivered_'), continue; end  % set per trial, not by the operator
                if isfield(before, f) && ~isequaln(before.(f), after.(f))
                    s.settingChanges(end+1) = struct('name', f, 'trial', i, ...
                        'from', {before.(f)}, 'to', {after.(f)});
                end
            end
        end
    end
end

function p = percent(k, n)
    if n == 0
        p = NaN;
    else
        p = 100 * k / n;
    end
end

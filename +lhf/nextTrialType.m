function nextType = nextTrialType(data, policy, runningType)
% lhf.nextTrialType  The type (1 or 2) of the trial about to be prepared.
%
%   nextType = lhf.nextTrialType(data, policy, runningType)
%
%   data         BpodSystem.Data: TrialResponse holds the trials recorded so far
%   policy       struct:
%                  task            'goNogo' or 'choice' (for lhf.responseBias)
%                  pFirst          probability of type 1
%                  biasCorrection  shift pFirst against the response bias
%                  alternate       strictly alternate 1, 2, 1, ... (habituation)
%                  window, gain    bias window (default 20) and gain (default 0.5)
%   runningType  the type of the trial running now ([] before the first trial)
%
%   The next trial is prepared while the current one runs, so the recorded
%   data end one trial before runningType. That is why alternation reads
%   runningType, and why there is no repeat-on-error: an error on the
%   running trial is not known until after its successor is on the machine.
%   Draws come from lhf.random().

    if nargin < 3, runningType = []; end

    if isfield(policy, 'alternate') && policy.alternate
        if isempty(runningType) || runningType == 2
            nextType = 1;
        else
            nextType = 2;
        end
        return
    end

    pFirst = policy.pFirst;
    if isfield(policy, 'biasCorrection') && policy.biasCorrection && isfield(data, 'TrialResponse')
        window = fieldOr(policy, 'window', 20);
        gain   = fieldOr(policy, 'gain', 0.5);
        bias = lhf.responseBias(data.TrialResponse, policy.pFirst, policy.task, window);
        pFirst = min(0.9, max(0.1, pFirst + gain * bias));
    end

    if rand(lhf.random()) < pFirst
        nextType = 1;
    else
        nextType = 2;
    end
end

function value = fieldOr(s, name, default)
    if isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    else
        value = default;
    end
end

function [outcome, response] = scoreTrial(trial, trialType, task)
% lhf.scoreTrial  Outcome and response of one trial, from its states and events.
%
%   [outcome, response] = lhf.scoreTrial(trial, trialType, task)
%
%   The one definition of how a trial is scored: the protocols store its
%   result in Data.TrialOutcome / Data.TrialResponse, and the plots, bias
%   correction and session report read those fields rather than re-scoring.
%
%   trial      Data.RawEvents.Trial{n} (fields States and Events)
%   trialType  1 or 2 (CS+/CS-, Left/Right, Match/Non-match)
%   task       'goNogo'  CS+ is correct when rewarded, CS- when not punished.
%                        response: 1 licked, 0 did not lick.
%              'choice'  2AFC, MTS: lick sensors on BNC1 (type 1)
%                        and BNC2 (type 2). response: the first lick while in
%                        GetResponse, 1 or 2, NaN for none. Rewarded is
%                        correct; no response is NoResponse; punished is
%                        incorrect; with no punishment state (punishment off,
%                        habituation) the response itself is scored.
%
%   outcome    an lhf.Outcome code

    states = trial.States;
    hasReward     = hasVisited(states, 'Reward');
    hasPunishment = hasVisited(states, 'Punishment');

    switch task
        case 'goNogo'
            if trialType == 1
                correct = hasReward;
            else
                correct = ~hasPunishment;
            end
            if correct
                outcome = lhf.Outcome.Correct;
            else
                outcome = lhf.Outcome.Incorrect;
            end
            % CS+ correct and CS- incorrect are the trials with a lick
            response = double((trialType == 1) == correct);

        case 'choice'
            response = firstLick(trial.Events, states);
            if hasReward
                outcome = lhf.Outcome.Correct;
            elseif isnan(response)
                outcome = lhf.Outcome.NoResponse;
            elseif hasPunishment
                outcome = lhf.Outcome.Incorrect;
            elseif response == trialType
                % No punishment state (habituation): score the lick itself
                outcome = lhf.Outcome.Correct;
            else
                outcome = lhf.Outcome.Incorrect;
            end

        otherwise
            error('lhf:scoreTrial:task', 'Unknown task ''%s''; use ''goNogo'' or ''choice''.', task);
    end
end

function visited = hasVisited(states, name)
    visited = isfield(states, name) && ~isnan(states.(name)(1));
end

function response = firstLick(events, states)
    % Only licks while GetResponse ran count (a lick during the cue is not a
    % choice); the lick that ends the state is stamped with its exit time.
    left  = licksIn(events, 'BNC1High', states);
    right = licksIn(events, 'BNC2High', states);
    if isempty(left) && isempty(right)
        response = NaN;
    elseif isempty(right) || (~isempty(left) && left(1) < right(1))
        response = 1;
    else
        response = 2;
    end
end

function t = licksIn(events, name, states)
    t = [];
    if ~isfield(events, name), return; end
    t = events.(name);
    if isfield(states, 'GetResponse')
        windows = states.GetResponse;
        windows = windows(~isnan(windows(:, 1)), :);
        inWindow = false(size(t));
        for k = 1:size(windows, 1)
            inWindow = inWindow | (t >= windows(k, 1) & t <= windows(k, 2));
        end
        t = t(inWindow);
    end
end

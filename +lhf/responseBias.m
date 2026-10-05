function bias = responseBias(responses, pFirst, task, window)
% lhf.responseBias  Response bias over the last trials, against the split pFirst predicts.
%
%   bias = lhf.responseBias(responses, pFirst, task, window)
%
%   responses  Data.TrialResponse (see lhf.scoreTrial); NaN (no response) is ignored
%   pFirst     the set probability of trial type 1 (CS+, Left, Match)
%   task       'goNogo' or 'choice'
%   window     number of recent trials (default 20)
%
%   bias > 0 means too few type-1 responses (goNogo: licks too little;
%   choice: favours side 2), so type 1 should be shown more; bias < 0 the
%   reverse. Measured against pFirst, not 50/50, so a deliberately skewed
%   pFirst is not read as bias. 0 when there are no responses yet.

    if nargin < 4, window = 20; end

    recent = responses(max(1, numel(responses) - window + 1):end);
    recent = recent(~isnan(recent));
    if isempty(recent)
        bias = 0;
        return
    end

    switch task
        case 'goNogo'
            pLick = mean(recent == 1);
            bias = pFirst - pLick;
        case 'choice'
            pOne = mean(recent == 1);
            pTwo = mean(recent == 2);
            bias = (pTwo - pOne) - (1 - 2 * pFirst);
        otherwise
            error('lhf:responseBias:task', 'Unknown task ''%s''.', task);
    end
end

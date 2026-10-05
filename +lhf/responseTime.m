function rt = responseTime(trial)
% lhf.responseTime  Seconds from entering GetResponse to leaving it, NaN if it never ran.
%
%   rt = lhf.responseTime(Data.RawEvents.Trial{n})
%
%   RT = GetResponse(1, 2) - GetResponse(1, 1): the first time the trial was
%   in GetResponse. It ends at the response, or at the state's timer when
%   there was none.

    rt = NaN;
    if isfield(trial.States, 'GetResponse')
        t = trial.States.GetResponse;
        if numel(t) >= 2 && ~isnan(t(1)) && ~isnan(t(1, 2))
            rt = t(1, 2) - t(1, 1);
        end
    end
end

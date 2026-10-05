function record = stopRecord(kind, trial, ME)
% lhf.stopRecord  Why a session ended, for Data.StoppedReason.
%
%   record = lhf.stopRecord('completed', trial)      ran all maxTrials
%   record = lhf.stopRecord('operator', trial)       Bpod's stop or pause-stop
%   record = lhf.stopRecord('error', trial, ME)      the trial loop failed
%   record = lhf.stopRecord('unknown', trial)        cleanup found no reason
%                                                    (setup error, Ctrl+C)
%
%   record.Reason      the kind above
%   record.Trial       the trial running when it ended
%   record.Time        when, as text
%   record.Message     the error message ('' otherwise)
%   record.Identifier  the error identifier ('' otherwise)
%   record.Stack       'function line n' per frame of the error (cell)

    record.Reason = kind;
    record.Trial = trial;
    record.Time = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    record.Message = '';
    record.Identifier = '';
    record.Stack = {};
    if nargin >= 3 && ~isempty(ME)
        record.Message = ME.message;
        record.Identifier = ME.identifier;
        record.Stack = arrayfun(@(f) sprintf('%s line %d', f.name, f.line), ME.stack, ...
            'UniformOutput', false);
    end
end

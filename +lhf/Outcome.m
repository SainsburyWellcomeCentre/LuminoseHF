classdef Outcome
% lhf.Outcome  The trial outcome codes stored in Data.TrialOutcome.
%
%   The numbers are part of the data format: never renumber or reuse one.
%   2 has never been used.
%
%   lhf.Outcome.Correct      1  rewarded, or a correctly withheld response
%   lhf.Outcome.Incorrect    0  wrong response, or a miss on a Go trial
%   lhf.Outcome.NoResponse   3  no response in a choice task
%
%   lhf.Outcome.label(code) returns the name for one code.

    properties (Constant)
        Incorrect  = 0
        Correct    = 1
        NoResponse = 3
    end

    methods (Static)
        function name = label(code)
            switch code
                case lhf.Outcome.Correct,    name = 'Correct';
                case lhf.Outcome.Incorrect,  name = 'Incorrect';
                case lhf.Outcome.NoResponse, name = 'No response';
                otherwise,                   name = 'Unscored';
            end
        end
    end
end

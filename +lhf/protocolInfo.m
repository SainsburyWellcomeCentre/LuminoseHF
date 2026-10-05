function info = protocolInfo(protocol)
% lhf.protocolInfo  What the shared code needs to know about one protocol.
%
%   info = lhf.protocolInfo(protocol)
%
%   info.name        the protocol ('goNogo', 'powercal', '2AFC', 'MTS')
%   info.task        'goNogo' or 'choice' (lhf.scoreTrial, lhf.responseBias)
%   info.typeNames   trial types 1 and 2 as legends and the report name them
%   info.tickNames   trial types 1 and 2 on the outcome plot's axis
%   info.odourTypes  S.GUI suffix of odour soft codes 1, 2, 3 (valves_<suffix>)
%   info.pFirstField S.GUI field with the probability of type 1
%   info.alternateInHabituation  habituation (TrainingLevel 1) alternates types
%   info.firstOnlyInHabituation  habituation (TrainingLevel 1) runs only type 1 (CS+)

    info.name = protocol;
    info.alternateInHabituation = false;
    info.firstOnlyInHabituation = false;
    switch protocol
        case {'goNogo', 'powercal'}
            info.task = 'goNogo';
            info.typeNames = {'CS+ (Go)', 'CS- (No-Go)'};
            info.tickNames = {'Go', 'No go'};
            info.odourTypes = {'cue', 'CSplus', 'CSminus'};
            info.pFirstField = 'CSplus_prob';
            info.firstOnlyInHabituation = strcmp(protocol, 'powercal');
        case '2AFC'
            info.task = 'choice';
            info.typeNames = {'Left', 'Right'};
            info.tickNames = {'Left', 'Right'};
            info.odourTypes = {'cue', 'Left', 'Right'};
            info.pFirstField = 'Leftprob';
            info.alternateInHabituation = true;
        case 'MTS'
            info.task = 'choice';
            info.typeNames = {'Match', 'Non-match'};
            info.tickNames = {'Match', 'Non-match'};
            info.odourTypes = {'cue', 'Template', 'Sample'};
            info.pFirstField = 'MatchProb';
            info.alternateInHabituation = true;
        otherwise
            error('lhf:protocolInfo:protocol', 'Unknown protocol ''%s''.', protocol);
    end
end

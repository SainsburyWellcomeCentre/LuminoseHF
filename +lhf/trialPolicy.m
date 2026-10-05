function policy = trialPolicy(GUI, info)
% lhf.trialPolicy  The lhf.nextTrialType policy from a protocol's current settings.
%
%   policy = lhf.trialPolicy(S.GUI, lhf.protocolInfo(protocol))
%
%   Read each trial, so changes in the runtime GUI apply to the next trial
%   prepared.

    policy.task = info.task;
    policy.pFirst = GUI.(info.pFirstField);
    policy.biasCorrection = isfield(GUI, 'BiasCorrection') && logical(GUI.BiasCorrection);
    habituation = isfield(GUI, 'TrainingLevel') && GUI.TrainingLevel == 1;
    policy.alternate = info.alternateInHabituation && habituation;
    if info.firstOnlyInHabituation && habituation
        % Every trial is CS+: no probability or bias correction applies
        policy.pFirst = 1;
        policy.biasCorrection = false;
    end
end

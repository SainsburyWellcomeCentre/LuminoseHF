function seconds = sequenceDuration(valves, olfConfig)
% lhf.olf.sequenceDuration  How long one row's valve sequence plays, in seconds.
%
%   seconds = lhf.olf.sequenceDuration(S.GUI.valves_<type>(row, :), luminose.olfactometer)
%
%   One slot per odour (the row's valves > 0; the GUI pads rows with 0) of
%   preSequenceTime + pulseTime + postSequenceTime, as
%   OlfactometerModel.generate_valve_pattern lays them out.

    slot = olfConfig.preSequenceTime + olfConfig.pulseTime + olfConfig.postSequenceTime;
    seconds = nnz(valves > 0) * slot;
end

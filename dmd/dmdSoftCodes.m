function codes = dmdSoftCodes(sma)
% dmdSoftCodes  DMD pattern soft codes (8, 9, 10, 12; 11 only halts) a state
% machine can send, from its states' outputs and its global timers' on-messages.
    global BpodSystem
    softCol = find(strcmp(BpodSystem.StateMachineInfo.OutputChannelNames, 'SoftCode'), 1);
    codes = sma.OutputMatrix(:, softCol);
    timers = sma.GlobalTimers;
    onSoft = logical(timers.IsSet) & timers.OutputChannel == softCol;
    codes = [codes(:); reshape(timers.OnMessage(onSoft), [], 1)];
    codes = unique(codes(ismember(codes, [8 9 10 12])))';
end

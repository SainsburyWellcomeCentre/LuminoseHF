function n = runningTrial()
% lhf.runningTrial  The number of the trial running now, for soft-code logs.
%
%   n = lhf.runningTrial()
%
%   The trial after the last one recorded (BpodSystem.Data.nTrials + 1). Soft
%   codes are handled while MATLAB waits for a trial's data, after the previous
%   trial has been recorded, so this is the trial that sent the code.

    global BpodSystem
    n = 1;
    try
        if isfield(BpodSystem.Data, 'nTrials') && ~isempty(BpodSystem.Data.nTrials)
            n = BpodSystem.Data.nTrials + 1;
        end
    catch
    end
end

%% Softcode Handler
function SoftCodeHandler_luminose_hf_powercal(code)
    global S luminose
    if code <= 7
        % Resolved here, where S is valid; the worker only drives the valves
        S = lhf.olf.deliver(code, S, lhf.protocolInfo('powercal'), luminose.olfactometer);
    elseif code == 13
        lhf.laser.onSoftCode();  % synchronous — the laser's serial port lives in this process
    else
        dmd_hf_powercal(code);  % synchronous — libisloaded fails on thread workers
    end
end

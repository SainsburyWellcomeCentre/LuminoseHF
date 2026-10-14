%% Softcode Handler
function SoftCodeHandler_luminose_hf_sleep(code)
    if code == 0, return; end
    dmd_hf_sleep(code);  % synchronous: the sequence was prepared before the trial; libisloaded fails on thread workers
end

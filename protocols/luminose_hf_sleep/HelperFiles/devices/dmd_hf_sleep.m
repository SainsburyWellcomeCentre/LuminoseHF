function dmd_hf_sleep(code)
% dmd_hf_sleep  DMD soft-code handler for the sleep protocol.
%
%   Soft-code mapping:
%     9  - CS+ pattern (imgIdx_CSplus, exposure_CSplus, nFrames_CSplus)
%    10  - CS- pattern (imgIdx_CSminus,exposure_CSminus,nFrames_CSminus)
%
%   Each code builds (or reuses a cached) frame stack and displays it
%   immediately in MASTER mode — no external hardware trigger involved.
%   Random spots get new positions each trial; all-fixed cached.

    persistent dmd plusSeq plusKey minusSeq minusKey optoSeq optoKey
    global S luminose BpodSystem
    C = DMDController.Constants;

    if isempty(dmd)
        dmd = DMDController.DMD();
        dmd.connect();
        fprintf('DMD connected (sleep).\n');
    end

    % Code 12: opto ITI pattern, MASTER mode (fires immediately)
    if code == 12
        rowIdx = 1;
        if isfield(BpodSystem.PluginObjects, 'SelectedPatternRow') && ...
           isfield(BpodSystem.PluginObjects.SelectedPatternRow, 'opto')
            rowIdx = BpodSystem.PluginObjects.SelectedPatternRow.opto;
        end
        key12 = rowIdx;
        if ~isequaln(optoKey, key12) || isempty(optoSeq)
            design = loadDesign(BpodSystem, 'opto', rowIdx, luminose.dmd.patternsFolder);
            if isempty(design)
                fprintf('dmd_hf_sleep: no opto pattern found for row %d\n', rowIdx); return;
            end
            H = double(dmd.device.height); W = double(dmd.device.width);
            spots = design.spots; r_px = design.r_px; tickMs = design.tickMs;
            margin = r_px + 1;
            fixed = [spots.isFixed]; px = double([spots(fixed).x]); py = double([spots(fixed).y]);
            for i = 1:numel(spots)
                if ~spots(i).isFixed
                    for attempt = 1:500
                        xt = randi([margin, W-margin]); yt = randi([margin, H-margin]);
                        if isempty(px) || all(max(abs(px-xt), abs(py-yt)) > 2*r_px)
                            spots(i).x = xt; spots(i).y = yt;
                            px(end+1) = xt; py(end+1) = yt; %#ok<AGROW>
                            break;
                        end
                    end
                end
            end
            frameStack = buildPatternFrameStack(spots, r_px, tickMs, H, W);
            if ~isempty(optoSeq), delete(optoSeq); end
            optoSeq = allocFrameStack(dmd, frameStack, illuTime);
            optoKey = key12;
        end
        dmd.halt();
        optoSeq.setRepeat(1);
        dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_MASTER);
        dmd.device.projStart(optoSeq);
        fprintf('dmd_hf_sleep: opto flash row %d\n', rowIdx);
        return;
    end

    switch code
        case 9,   typeName = 'CSplus';
        case 10,  typeName = 'CSminus';
        otherwise
            fprintf('dmd_hf_sleep: unknown code %d\n', code); return;
    end

    rowIdx = 1;
    if isfield(BpodSystem.PluginObjects, 'SelectedPatternRow') && ...
       isfield(BpodSystem.PluginObjects.SelectedPatternRow, typeName)
        rowIdx = BpodSystem.PluginObjects.SelectedPatternRow.(typeName);
    end

    dmd.halt();

    design = loadDesign(BpodSystem, typeName, rowIdx, luminose.dmd.patternsFolder);
    if isempty(design)
        fprintf('dmd_hf_sleep: no design for %s row %d\n', typeName, rowIdx); return;
    end
    spots = design.spots; r_px = design.r_px; tickMs = design.tickMs;
    nF       = design.nF;
    illuTime = round(tickMs * 1000);  % ms → µs
    hasRandom = any(~[spots.isFixed]);

    [cachedSeq, cachedKey] = getCache(code, plusKey, plusSeq, minusKey, minusSeq);
    if ~hasRandom
        key = [rowIdx, nF, illuTime];
    else
        key = [];
    end

    if hasRandom || ~isequaln(cachedKey, key) || isempty(cachedSeq)
        H = double(dmd.device.height); W = double(dmd.device.width);
        margin = r_px + 1;
        fixed = [spots.isFixed]; px = double([spots(fixed).x]); py = double([spots(fixed).y]);
        for i = 1:numel(spots)
            if ~spots(i).isFixed
                for attempt = 1:500
                    xt = randi([margin, W-margin]); yt = randi([margin, H-margin]);
                    if isempty(px) || all(max(abs(px-xt), abs(py-yt)) > 2*r_px)
                        spots(i).x = xt; spots(i).y = yt;
                        px(end+1) = xt; py(end+1) = yt; %#ok<AGROW>
                        break;
                    end
                end
            end
        end
        frameStack = buildPatternFrameStack(spots, r_px, tickMs, H, W);
        if ~isempty(cachedSeq), delete(cachedSeq); end
        cachedSeq = allocFrameStack(dmd, frameStack, illuTime);
        % Always store the handle back (even for random-position patterns,
        % where key stays empty so it's rebuilt every call) so the next
        % call can find and delete it instead of leaking the DMD sequence.
        [plusSeq, plusKey, minusSeq, minusKey] = ...
            setCache(code, cachedSeq, key, plusSeq, plusKey, minusSeq, minusKey);
    end
    dmd.halt();
    cachedSeq.setRepeat(1);
    dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_MASTER);
    dmd.device.projStart(cachedSeq);
    fprintf('dmd_hf_sleep: displaying %s row %d in MASTER mode (immediate)\n', typeName, rowIdx);
end

function seq = allocFrameStack(dmd, frameStack, illuTime_us)
    nF  = size(frameStack, 3);
    seq = dmd.device.allocSequence(1, nF);
    for k = 1:nF, seq.put(k-1, 1, frameStack(:,:,k)); end
    seq.setBinaryMode(true);
    setFrameTiming(seq, illuTime_us); seq.setRepeat(1);
end

function design = loadDesign(BpodSystem, typeName, rowIdx, patternsFolder)
    % Try the requested type first, then fall back to any available pattern.
    fallback = {'CSplus', 'CSminus', 'opto', 'Left', 'Right', 'cue'};
    candidates = [{typeName}, fallback(~strcmp(fallback, typeName))];
    for ci = 1:numel(candidates)
        t = candidates{ci};
        rIdx = 1; if ci == 1, rIdx = rowIdx; end
        design = tryLoadDesign(BpodSystem, t, rIdx, patternsFolder);
        if ~isempty(design)
            if ci > 1
                fprintf('dmd_hf_sleep: no %s pattern, using %s\n', typeName, t);
            end
            return;
        end
    end
    design = [];
end

function design = tryLoadDesign(BpodSystem, typeName, rowIdx, patternsFolder)
    design = [];
    try
        pd = BpodSystem.PluginObjects.PatternDesigns;
        if isfield(pd, typeName) && numel(pd.(typeName)) >= rowIdx && ...
           ~isempty(pd.(typeName){rowIdx}) && isfield(pd.(typeName){rowIdx}, 'spots')
            design = pd.(typeName){rowIdx}; return;
        end
    catch
    end
    patternsFolder = char(patternsFolder);
    metas = dir(fullfile(patternsFolder, sprintf('designed_%s_r%d_*_meta.mat', typeName, rowIdx)));
    if isempty(metas) && rowIdx == 1
        all_m = dir(fullfile(patternsFolder, sprintf('designed_%s_*_meta.mat', typeName)));
        isRow = arrayfun(@(m) ~isempty(regexp(m.name, sprintf('designed_%s_r\\d+_', typeName), 'once')), all_m);
        metas = all_m(~isRow);
    end
    if isempty(metas), return; end
    [~, newest] = max([metas.datenum]);
    try
        m = load(fullfile(patternsFolder, metas(newest).name), 'spots', 'tickMs', 'r_px', 'nF');
        if ~isfield(m, 'spots') || ~isfield(m, 'tickMs'), return; end
        for i = 1:numel(m.spots)
            if ~isfield(m.spots(i), 'isFixed'), m.spots(i).isFixed = true; end
        end
        nF = 1; if isfield(m, 'nF'), nF = m.nF; end
        design = struct('spots', m.spots, 'tickMs', m.tickMs, 'r_px', m.r_px, 'nF', nF);
    catch, end
end

function [seq, key] = getCache(code, plusKey, plusSeq, minusKey, minusSeq)
    switch code
        case 9,  seq = plusSeq;  key = plusKey;
        case 10, seq = minusSeq; key = minusKey;
        otherwise, seq = []; key = [];
    end
end

function [plusSeq,plusKey,minusSeq,minusKey] = ...
        setCache(code,seq,key,plusSeq,plusKey,minusSeq,minusKey)
    switch code
        case 9,  plusSeq  = seq; plusKey  = key;
        case 10, minusSeq = seq; minusKey = key;
    end
end

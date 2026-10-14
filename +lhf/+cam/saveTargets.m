function targets = saveTargets(file, list, entry)
% lhf.cam.saveTargets  Saves an animal's targets: points marked on its camera image.
%
%   targets = lhf.cam.saveTargets(lhf.cam.targetsFile(folder, animal), list, entry)
%
%   list: struct array, one per target (a glomerulus, say): name, xy ([x y] in
%   full-sensor camera px in the animal's reference fiducial frame, lhf.cam.mapPoints),
%   created (time text; added when missing), use (true: ticked for Spots on targets).
%   entry: struct with referenceTime (the fiducial reference the points are relative to,
%   lhf.cam.saveFiducial's reference.time), frame (the image they were marked on) and
%   transform (reference to that frame, lhf.cam.mapPoints); time and code
%   (lhf.provenance, without the diff) are added. The file's variable targets holds
%   animal, referenceTime, list (replaced by this one) and saves (every entry, oldest
%   first). Returns it.
%
% See also lhf.cam.loadTargets, lhf.cam.targetsFile, lhf.cam.mapPoints

    now = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    list = withListFields(list, now);
    names = {'referenceTime', 'frame', 'transform', 'time', 'code'};
    entry.time = now;
    p = lhf.provenance([], {fileparts(fileparts(fileparts(mfilename('fullpath'))))});
    entry.code = rmfield(p.code, 'diff');
    for k = 1:numel(names)
        if ~isfield(entry, names{k}), entry.(names{k}) = []; end
    end
    entry = orderfields(rmfield(entry, setdiff(fieldnames(entry), names)), names);

    targets = lhf.cam.loadTargets(file);
    [~, animal] = fileparts(file);
    if isempty(targets)
        folder = fileparts(file);
        if ~isfolder(folder), mkdir(folder); end
        targets = struct('animal', animal, 'referenceTime', entry.referenceTime, ...
            'list', list, 'saves', entry);
    else
        targets.referenceTime = entry.referenceTime;
        targets.list = list;
        targets.saves = [targets.saves(:)', entry];
    end
    save(file, 'targets', '-v7.3');  % frames are large
end


function list = withListFields(list, now)
% name, xy, created, use on every target, in that order.
    if isempty(list)
        list = struct('name', {}, 'xy', {}, 'created', {}, 'use', {});
        return
    end
    names = {'name', 'xy', 'created', 'use'};
    for k = 1:numel(list)
        if ~isfield(list, 'created') || isempty(list(k).created), list(k).created = now; end
        if ~isfield(list, 'use') || isempty(list(k).use), list(k).use = true; end
    end
    list = orderfields(rmfield(list, setdiff(fieldnames(list), names)), names);
end

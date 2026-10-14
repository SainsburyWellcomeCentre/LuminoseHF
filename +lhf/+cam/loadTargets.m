function targets = loadTargets(file)
% lhf.cam.loadTargets  An animal's targets (lhf.cam.saveTargets), or [] if none.
%
%   targets = lhf.cam.loadTargets(lhf.cam.targetsFile(folder, animal))
%
% See also lhf.cam.saveTargets, lhf.cam.targetsFile

    targets = [];
    if ~isfile(file), return; end
    m = load(file, 'targets');
    targets = m.targets;
end

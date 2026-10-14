function file = targetsFile(calibrationFolder, animal)
% lhf.cam.targetsFile  Where an animal's targets (glomeruli marked on the camera) are kept.
%
%   file = lhf.cam.targetsFile(fullfile(luminose.f.luminoseData, 'calibration'), animal)
%
%   <calibrationFolder>/targets/<animal>.mat, with any character a file name cannot hold
%   replaced by _, as lhf.cam.fiducialFile does. See lhf.cam.saveTargets.
%
% See also lhf.cam.saveTargets, lhf.cam.loadTargets, lhf.cam.fiducialFile

    animal = strtrim(char(animal));
    if isempty(animal)
        error('lhf:cam:noAnimal', 'Name the animal the targets belong to.');
    end
    file = fullfile(char(calibrationFolder), 'targets', [regexprep(animal, '[^\w\-]', '_') '.mat']);
end

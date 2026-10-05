function file = fiducialFile(calibrationFolder, animal)
% lhf.cam.fiducialFile  Where an animal's fiducial is kept.
%
%   file = lhf.cam.fiducialFile(fullfile(luminose.f.luminoseData, 'calibration'), animal)
%
%   <calibrationFolder>/fiducials/<animal>.mat, with any character a file
%   name cannot hold replaced by _. See lhf.cam.saveFiducial.

    animal = strtrim(char(animal));
    if isempty(animal)
        error('lhf:cam:noAnimal', 'Name the animal the fiducial belongs to.');
    end
    file = fullfile(char(calibrationFolder), 'fiducials', [regexprep(animal, '[^\w\-]', '_') '.mat']);
end

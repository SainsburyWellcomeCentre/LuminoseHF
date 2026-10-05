function fid = loadFiducial(file)
% lhf.cam.loadFiducial  An animal's fiducial (lhf.cam.saveFiducial), or [] if none.
%
%   fid = lhf.cam.loadFiducial(lhf.cam.fiducialFile(folder, animal))

    fid = [];
    if ~isfile(file), return; end
    m = load(file, 'fiducial');
    fid = m.fiducial;
end

function fid = saveFiducial(file, entry)
% lhf.cam.saveFiducial  Add one session's fiducial frame to an animal's file.
%
%   fid = lhf.cam.saveFiducial(lhf.cam.fiducialFile(folder, animal), entry)
%
%   entry: struct with any of frame (the camera frame, uint16, full sensor),
%   xy ([x y] of the mark in camera pixels, [] after an automatic alignment),
%   exposureMs, roi, registrationFile, stageUm ([x y z] when the stages were
%   connected) and alignment (lhf.cam.align's result, without its frame);
%   missing fields are saved empty, and the time is added. The file holds
%   fiducial: animal, reference (the first entry ever saved, never replaced;
%   later sessions are aligned to it) and sessions (every entry, the
%   reference first). Returns the updated struct.

    entry.time = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    entry = withAllFields(entry);
    fid = lhf.cam.loadFiducial(file);
    if isempty(fid)
        [~, animal] = fileparts(file);
        fid = struct('animal', animal, 'reference', entry, 'sessions', entry);
        folder = fileparts(file);
        if ~isfolder(folder), mkdir(folder); end
    else
        fid.reference = withAllFields(fid.reference);  % a file saved before a field existed
        sessions = arrayfun(@withAllFields, fid.sessions);
        fid.sessions = [sessions(:)', entry];
    end
    fiducial = fid; %#ok<NASGU>
    save(file, 'fiducial', '-v7.3');  % frames are large
end

function entry = withAllFields(entry)
% Every entry has the same fields, in the same order (any other field is dropped)
    names = {'frame', 'xy', 'exposureMs', 'roi', 'registrationFile', 'stageUm', 'alignment', 'time'};
    for k = 1:numel(names)
        if ~isfield(entry, names{k}), entry.(names{k}) = []; end
    end
    entry = rmfield(entry, setdiff(fieldnames(entry), names));
    entry = orderfields(entry, names);
end

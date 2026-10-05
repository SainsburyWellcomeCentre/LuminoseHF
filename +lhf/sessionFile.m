function file = sessionFile(suffix)
% lhf.sessionFile  A file beside the session's data file: <data file>_<suffix>.
%
%   file = lhf.sessionFile('dmd_log.txt')
%
%   For the session's own logs, so they stay with its data. Before Bpod has a
%   data file, the file is in tempdir.

    global BpodSystem
    try
        [folder, name] = fileparts(BpodSystem.Path.CurrentDataFile);
    catch
        folder = '';
    end
    if isempty(folder)
        folder = tempdir;
        name = 'luminose';
    end
    file = fullfile(folder, [name '_' suffix]);
end

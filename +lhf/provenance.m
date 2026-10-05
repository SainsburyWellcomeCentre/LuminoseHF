function p = provenance(luminose, repos)
% lhf.provenance  What ran: computer, MATLAB, every repository's code, the config.
%
%   p = lhf.provenance(luminose)
%   p = lhf.provenance(luminose, repos)   repos: folders to record (default below)
%
%   Saved with every session (Data.Setup.provenance, lhf.recordSetup) and every
%   calibration (results.provenance), so a run can be rebuilt later: check out
%   each repository's commit and apply its diff (lhf.recreate writes them out).
%
%   p.time, computer, user, matlab (version), toolboxes (struct array Name,
%   Version)
%   p.code      struct array, one per repository: name, path, commit, branch,
%               dirty (uncommitted changes or untracked files), status
%               (git status --porcelain), diff (git diff HEAD: the uncommitted
%               changes to tracked files), untracked (cell of paths),
%               untrackedFiles (struct array path, text: the untracked source
%               and text files under 200 kB, which git diff leaves out), note
%               (why something could not be read, else '')
%   p.config    file, text (luminose_config.yaml as it was), values (every
%               LuminoseConstants property as a plain struct, which loads even
%               if the class changes)
%
%   Default repositories: LuminoseHF, each device package's repository
%   (LuminoseConstants.devicePackages), Bpod_Gen2 and DMDController in
%   luminose.f.matlabFolder. Never throws: what cannot be read is noted.

    here = fileparts(fileparts(mfilename('fullpath')));  % the LuminoseHF repository
    if nargin < 2
        repos = {here};
        try
            matlabFolder = char(luminose.f.matlabFolder);
            names = [{LuminoseConstants.devicePackages().repo}, {'Bpod_Gen2', 'DMDController'}];
            repos = [repos, cellfun(@(n) fullfile(matlabFolder, n), names, 'UniformOutput', false)];
        catch
        end
    end

    p.time = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
    p.computer = getenv('COMPUTERNAME');
    p.user = getenv('USERNAME');
    p.matlab = version();
    p.toolboxes = struct('Name', {}, 'Version', {});
    try
        v = ver();
        p.toolboxes = struct('Name', {v.Name}, 'Version', {v.Version});
    catch
    end

    p.code = struct('name', {}, 'path', {}, 'commit', {}, 'branch', {}, 'dirty', {}, ...
        'status', {}, 'diff', {}, 'untracked', {}, 'untrackedFiles', {}, 'note', {});
    for k = 1:numel(repos)
        p.code(k) = repoState(repos{k});
    end

    p.config = struct('file', '', 'text', '', 'values', struct());
    try
        p.config.file = char(luminose.configFile);
        p.config.text = fileread(p.config.file);
    catch
    end
    try
        if isstruct(luminose)
            p.config.values = luminose;
        else
            for name = properties(luminose)'
                p.config.values.(name{1}) = luminose.(name{1});
            end
        end
    catch
    end
end

function r = repoState(folder)
% One repository's commit, branch and uncommitted changes.
    [~, name] = fileparts(folder);
    r = struct('name', name, 'path', folder, 'commit', '', 'branch', '', 'dirty', false, ...
        'status', '', 'diff', '', 'untracked', {{}}, ...
        'untrackedFiles', struct('path', {}, 'text', {}), 'note', '');
    if ~isfolder(folder)
        r.note = 'folder not found';
        return
    end
    [ok, out] = git(folder, 'rev-parse HEAD');
    if ~ok
        r.note = ['not a git repository or git not found: ' strtrim(out)];
        return
    end
    r.commit = strtrim(out);
    [~, out] = git(folder, 'rev-parse --abbrev-ref HEAD');
    r.branch = strtrim(out);
    [~, r.status] = git(folder, 'status --porcelain');
    [~, r.diff] = git(folder, 'diff HEAD');
    [~, out] = git(folder, 'ls-files --others --exclude-standard');
    r.untracked = splitlines(strtrim(out))';
    r.untracked = r.untracked(~cellfun(@isempty, r.untracked));
    textTypes = {'.m', '.yaml', '.yml', '.md', '.txt', '.csv', '.tsv', '.json'};
    for k = 1:numel(r.untracked)
        file = fullfile(folder, r.untracked{k});
        [~, ~, ext] = fileparts(file);
        info = dir(file);
        if any(strcmpi(ext, textTypes)) && isscalar(info) && info.bytes < 200e3
            try
                r.untrackedFiles(end + 1) = struct('path', r.untracked{k}, 'text', fileread(file));
            catch
            end
        end
    end
    r.dirty = ~isempty(strtrim(r.status));
end

function [ok, out] = git(folder, args)
    [status, out] = system(sprintf('git -C "%s" %s', folder, args));
    ok = status == 0;
end

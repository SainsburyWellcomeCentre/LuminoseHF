function setup = recordSetup(luminose, subject, options)
% lhf.recordSetup  Everything a session's preparation left in force, for Data.Setup.
%
%   BpodSystem.Data.Setup = lhf.recordSetup(luminose, subject)
%   setup = lhf.recordSetup(luminose, subject, options)
%
%   Called once at START by every protocol, so the session can be recreated
%   later (lhf.recreate):
%     setup.provenance   lhf.provenance: computer, MATLAB, each repository's
%                        commit and uncommitted changes, the config
%     setup.calibration  lhf.calibrationSnapshot: the calibrations in force
%     setup.stageUm      Zaber [x y z] at START (lhf.stagePosition), or []
%     setup.stageNote    why stageUm is empty, else ''
%     setup.fiducial     the subject's newest fiducial entry (without its frame)
%                        and its file (lhf.cam.saveFiducial), or [] for none
%     setup.subject
%     setup.dataFile     where Bpod is saving this session
%     setup.dataFolderNote  '' when dataFile is inside paths.dataFolder
%                        (luminose.f.luminoseData), else a warning: Bpod's data
%                        folder (its Settings menu) must match the config
%
%   options (tests): calibrationFolder, makeStages, repos. Never throws.

    if nargin < 3, options = struct(); end
    calibrationFolder = '';
    try
        calibrationFolder = fullfile(char(luminose.f.luminoseData), 'calibration');
    catch
    end
    if isfield(options, 'calibrationFolder'), calibrationFolder = options.calibrationFolder; end

    setup.subject = char(subject);
    [setup.dataFile, setup.dataFolderNote] = checkDataFile(luminose, options);
    if ~isempty(setup.dataFolderNote)
        warning('lhf:recordSetup:dataFolder', '%s', setup.dataFolderNote);
    end
    if isfield(options, 'repos')
        setup.provenance = lhf.provenance(luminose, options.repos);
    else
        setup.provenance = lhf.provenance(luminose);
    end
    setup.calibration = lhf.calibrationSnapshot(luminose, calibrationFolder);
    if isfield(options, 'makeStages')
        [setup.stageUm, setup.stageNote] = lhf.stagePosition(luminose, options.makeStages);
    else
        [setup.stageUm, setup.stageNote] = lhf.stagePosition(luminose);
    end
    setup.fiducial = [];
    try
        file = lhf.cam.fiducialFile(calibrationFolder, subject);
        fid = lhf.cam.loadFiducial(file);
        if ~isempty(fid)
            entry = fid.sessions(end);
            if isfield(entry, 'frame'), entry = rmfield(entry, 'frame'); end
            setup.fiducial = struct('file', file, 'entry', entry, 'referenceTime', fid.reference.time);
        end
    catch
    end
end

function [file, note] = checkDataFile(luminose, options)
% Whether Bpod's data file is inside the config's data folder
    global BpodSystem
    file = '';
    note = '';
    try
        if isfield(options, 'dataFile')
            file = char(options.dataFile);
        else
            file = char(BpodSystem.Path.CurrentDataFile);
        end
        folder = char(luminose.f.luminoseData);
    catch
        return
    end
    if isempty(file) || isempty(folder), return; end
    inside = startsWith(normalised(file), [strip(normalised(folder), 'right', '\') '\']);
    if ~inside
        note = sprintf(['This session is being saved to %s, outside the data folder %s ' ...
            '(paths.dataFolder in luminose_config.yaml). Set Bpod''s data folder to it ' ...
            '(Bpod console: Settings, folders).'], file, folder);
    end
end

function p = normalised(p)
% Lower case, one \ between parts (a config path may carry \\ or /)
    p = lower(regexprep(char(p), '[\\/]+', '\\'));
end

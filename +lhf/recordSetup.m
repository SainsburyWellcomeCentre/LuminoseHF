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

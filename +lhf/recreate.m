function files = recreate(dataFile, outFolder)
% lhf.recreate  Everything needed to run a saved session again, written to a folder.
%
%   files = lhf.recreate(dataFile, outFolder)
%
%   dataFile   a session's Bpod data file (SessionData), or the SessionData
%              struct itself
%   outFolder  created if needed
%
%   Writes, from what the session recorded (Data.Setup, lhf.recordSetup;
%   RawEvents.Trial{n}.Actions.Patterns):
%     settings.mat           ProtocolSettings: S.GUI as trial 1 ran, S.GUIMeta,
%                            and S.RandomSeed = the session's seed, so the
%                            same draws repeat (lhf.mergeSettings loads it)
%     Patterns/              every design shown, as designed_<file type>_r<row>_
%                            <yyyymmdd_HHMMSS>_meta.mat (copy into dmd/Patterns)
%     luminose_config.yaml   the config as it was
%     power_calibration.csv, odour_bottles.tsv, odour_chemicals.tsv
%     camera_dmd.mat, stage_camera.mat   the calibrations in force
%     code/<repo>.patch      each repository's uncommitted changes (git apply),
%     code/<repo>/...        and its untracked source files
%     README.txt             commits to check out, the stage position at
%                            START, the fiducial to align to, and how to use
%                            the files
%   files: cell of the files written. Errors if the session has no Setup
%   (recorded from 2026-10-05).

    sessionName = '(given as a struct)';
    if ischar(dataFile) || isstring(dataFile)
        m = load(char(dataFile), 'SessionData');
        data = m.SessionData;
        [~, sessionName] = fileparts(char(dataFile));
    else
        data = dataFile;
    end
    if ~isfield(data, 'Setup')
        error('lhf:recreate:noSetup', ['This session has no Data.Setup (recorded from ' ...
            '2026-10-05): its code and calibrations were not saved with it.']);
    end
    setup = data.Setup;
    if ~isfolder(outFolder), mkdir(outFolder); end
    files = {};

    % Settings: as trial 1 ran, with the session's seed
    ProtocolSettings = struct('GUI', data.TrialSettings(1).GUI);
    if isfield(data, 'GUIMeta'), ProtocolSettings.GUIMeta = data.GUIMeta; end
    ProtocolSettings.RandomSeed = data.RandomSeed;
    files{end+1} = fullfile(outFolder, 'settings.mat');
    save(files{end}, 'ProtocolSettings');

    % Designs shown, one file per type and row
    dmdConfig = struct();
    try
        dmdConfig = setup.provenance.config.values.dmd;
    catch
    end
    written = {};
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    patternFolder = fullfile(outFolder, 'Patterns');
    for n = 1:numel(data.RawEvents.Trial)
        trial = data.RawEvents.Trial{n};
        if ~isfield(trial, 'Actions') || ~isfield(trial.Actions, 'Patterns'), continue; end
        patterns = trial.Actions.Patterns;
        for type = fieldnames(patterns)'
            p = patterns.(type{1});
            key = sprintf('%s_r%d', type{1}, p.row);
            if any(strcmp(written, key)), continue; end
            written{end+1} = key; %#ok<AGROW>
            if ~isfolder(patternFolder), mkdir(patternFolder); end
            fileType = type{1};
            try
                fileType = lhf.patternFileType(dmdConfig, type{1});
            catch
            end
            design = struct();
            if isfield(p, 'shown') && p.shown
                design.spots = p.spots;  % random spots: those of the first trial; each trial's in its Actions
                design.tickMs = p.tickMs;
                design.r_px = p.r_px;
                design.nF = p.nF;
                for f = {'laserIrradiances_mWmm2', 'laserWeights'}
                    if isfield(p, f{1}), design.(f{1}) = p.(f{1}); end
                end
            else
                design.spots = struct('x', {}, 'y', {}, 'onset_ms', {}, 'dur_ms', {}, 'isFixed', {});
                if isfield(p, 'blankMs') && p.blankMs > 0
                    design.blankMs = p.blankMs;
                    design.tickMs = p.blankMs;
                    design.r_px = 0;
                    design.nF = 1;
                else
                    continue  % a row with no design: nothing to write
                end
            end
            files{end+1} = fullfile(patternFolder, sprintf('designed_%s_r%d_%s_meta.mat', ...
                fileType, p.row, stamp)); %#ok<AGROW>
            save(files{end}, '-struct', 'design');
        end
    end

    % Config and calibration tables, as they were
    files = writeText(files, outFolder, 'luminose_config.yaml', setup.provenance.config.text);
    cal = setup.calibration;
    files = writeText(files, outFolder, 'power_calibration.csv', cal.power.text);
    files = writeText(files, outFolder, 'odour_bottles.tsv', cal.odourTables.bottlesText);
    files = writeText(files, outFolder, 'odour_chemicals.tsv', cal.odourTables.chemicalsText);
    if ~isempty(cal.cameraDmd.registration)
        registration = cal.cameraDmd.registration; %#ok<NASGU>
        files{end+1} = fullfile(outFolder, 'camera_dmd.mat');
        save(files{end}, 'registration');
    end
    if ~isempty(cal.stageCamera.calibration)
        stageCamera = cal.stageCamera.calibration; %#ok<NASGU>
        files{end+1} = fullfile(outFolder, 'stage_camera.mat');
        save(files{end}, 'stageCamera');
    end

    % Code: uncommitted changes and untracked files per repository
    lines = {sprintf('Session: %s (%s %s)', sessionName, textOf(data, 'SessionDate'), ...
        textOf(data, 'SessionStartTime_UTC')), ''};
    lines{end+1} = 'Code (check out each commit, then apply its patch and copy its untracked files):';
    for r = setup.provenance.code
        if isempty(r.commit)
            lines{end+1} = sprintf('  %-20s not recorded (%s)', r.name, r.note); %#ok<AGROW>
            continue
        end
        state = 'clean';
        if r.dirty, state = 'UNCOMMITTED CHANGES'; end
        lines{end+1} = sprintf('  %-20s %s (%s) %s', r.name, r.commit, r.branch, state); %#ok<AGROW>
        if ~isempty(strtrim(r.diff))
            files = writeText(files, fullfile(outFolder, 'code'), [r.name '.patch'], r.diff);
            lines{end+1} = sprintf('      git -C <%s> apply code/%s.patch', r.name, r.name); %#ok<AGROW>
        end
        for u = r.untrackedFiles
            files = writeText(files, fullfile(outFolder, 'code', r.name), u.path, u.text);
        end
        if ~isempty(r.untracked)
            lines{end+1} = sprintf('      untracked: %s', strjoin(r.untracked, ', ')); %#ok<AGROW>
        end
    end
    lines{end+1} = '';
    lines{end+1} = sprintf('MATLAB %s on %s; recorded %s.', setup.provenance.matlab, ...
        setup.provenance.computer, setup.provenance.time);
    if isempty(setup.stageUm)
        lines{end+1} = sprintf('Stage at START: not read (%s).', setup.stageNote);
    else
        lines{end+1} = sprintf('Stage at START: X %.1f, Y %.1f, Z %.1f um.', setup.stageUm);
    end
    if ~isempty(setup.fiducial)
        lines{end+1} = sprintf('Fiducial: %s, newest entry %s (reference %s).', setup.fiducial.file, ...
            setup.fiducial.entry.time, setup.fiducial.referenceTime);
    end
    lines{end+1} = sprintf('Random seed: %d (in settings.mat: the draws repeat once).', data.RandomSeed);
    lines{end+1} = '';
    lines{end+1} = ['To run it again: check out the code above; copy luminose_config.yaml and ' ...
        'power_calibration.csv (to dmd/), the odour tables (to olfactometer/) and Patterns/ ' ...
        '(to dmd/Patterns) into place; load settings.mat as the protocol''s settings in Bpod.'];
    lines{end+1} = ['Each trial''s exact patterns (random spots placed) are in ' ...
        'RawEvents.Trial{n}.Actions.Patterns, its odour rows in Actions.OdourRows.'];
    files = writeText(files, outFolder, 'README.txt', strjoin(lines, newline));
end

function files = writeText(files, folder, name, text)
    if isempty(text), return; end
    file = fullfile(folder, name);
    if ~isfolder(fileparts(file)), mkdir(fileparts(file)); end
    fid = fopen(file, 'w', 'n', 'UTF-8');
    if fid < 0, error('lhf:recreate:write', 'Cannot write %s.', file); end
    fprintf(fid, '%s', text);
    fclose(fid);
    files{end+1} = file;
end

function t = textOf(data, field)
    t = '';
    if isfield(data, 'Info') && isfield(data.Info, field), t = char(data.Info.(field)); end
end

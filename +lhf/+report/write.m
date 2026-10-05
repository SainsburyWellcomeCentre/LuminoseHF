function files = write(data, info, dataFile, meta)
% lhf.report.write  The end-of-session report: a Markdown log and a summary image.
%
%   files = lhf.report.write(data, info, dataFile, meta)
%
%   data      BpodSystem.Data at the end of the session
%   info      lhf.protocolInfo(protocol)
%   dataFile  BpodSystem.Path.CurrentDataFile; the report is written beside it:
%             <name>_report.md and <name>_summary.png
%   meta      optional struct: subject (default: Bpod's current subject)
%   The settings notes (lhf.mergeSettings) come from data.SettingsNotes.
%
%   files     struct with fields log and image ('' for one not written)
%
%   Called from a protocol's cleanup. It never throws: a failure is a
%   warning, so the report cannot stop the data being saved.

    if nargin < 4, meta = struct(); end
    if ~isfield(meta, 'subject')
        meta.subject = lhf.subjectName();
    end
    if isfield(data, 'SettingsNotes')
        meta.settingsNotes = data.SettingsNotes;
    end
    files = struct('log', '', 'image', '');
    [folder, name] = fileparts(dataFile);

    try
        s = lhf.report.summary(data, info);
        files.log = fullfile(folder, [name '_report.md']);
        writeLog(files.log, s, data, info, name, meta);
    catch ME
        files.log = '';
        warning('lhf:report:log', 'Session log not written: %s', ME.message);
    end

    try
        if isfield(data, 'TrialOutcome') && ~isempty(data.TrialOutcome)
            files.image = fullfile(folder, [name '_summary.png']);
            lhf.report.summaryImage(data, info, files.image);
        end
    catch ME
        files.image = '';
        warning('lhf:report:image', 'Summary image not written: %s', ME.message);
    end
end

function writeLog(file, s, data, info, name, meta)
    lines = {};
    add = @(varargin) sprintf(varargin{:});

    lines{end+1} = add('# Session report: %s', name);
    lines{end+1} = '';
    lines{end+1} = '| | |';
    lines{end+1} = '|---|---|';
    lines{end+1} = add('| Protocol | luminose_hf_%s |', info.name);
    lines{end+1} = add('| Subject | %s |', textOr(meta, 'subject', 'unknown'));
    if isfield(data, 'Info') && isfield(data.Info, 'SessionDate')
        lines{end+1} = add('| Date | %s %s |', data.Info.SessionDate, textOr(data.Info, 'SessionStartTime_UTC', ''));
    end
    lines{end+1} = add('| Trials | %d |', s.nTrials);
    if isfield(data, 'StoppedReason')
        r = data.StoppedReason;
        lines{end+1} = add('| Ended | %s at trial %d (%s) |', r.Reason, r.Trial, r.Time);
        if ~isempty(r.Message)
            lines{end+1} = add('| Error | %s |', escape(r.Message));
        end
    end
    if isfield(data, 'RandomSeed')
        lines{end+1} = add('| Random seed | %d |', data.RandomSeed);
    end
    if isfield(data, 'GitHash')
        lines{end+1} = add('| Code version | %s |', data.GitHash);
    end
    lines{end+1} = '';

    lines{end+1} = '## Performance';
    lines{end+1} = '';
    lines{end+1} = '| Trial type | Trials | Correct | Incorrect | No response | % correct |';
    lines{end+1} = '|---|---:|---:|---:|---:|---:|';
    for k = 1:2
        t = s.byType(k);
        lines{end+1} = add('| %s | %d | %d | %d | %d | %s |', t.name, t.n, t.correct, ...
            t.incorrect, t.noResponse, pct(t.percentCorrect)); %#ok<AGROW>
    end
    lines{end+1} = add('| All | %d | %d | | | %s |', s.nTrials, s.correct, pct(s.percentCorrect));
    lines{end+1} = '';
    lines{end+1} = add('Water delivered: %.1f µL. Median response time: %s.', s.rewardTotal, ...
        secondsText(s.medianResponseTime));
    lines{end+1} = '';

    lines{end+1} = '## Settings changed during the session';
    lines{end+1} = '';
    if isempty(s.settingChanges)
        lines{end+1} = 'None.';
    else
        shown = min(numel(s.settingChanges), 50);
        for c = s.settingChanges(1:shown)
            lines{end+1} = add('- Trial %d: %s %s → %s', c.trial, c.name, ...
                valueText(c.from), valueText(c.to)); %#ok<AGROW>
        end
        if shown < numel(s.settingChanges)
            lines{end+1} = add('- … and %d more', numel(s.settingChanges) - shown);
        end
    end

    if isfield(meta, 'settingsNotes') && ~isempty(meta.settingsNotes)
        lines{end+1} = '';
        lines{end+1} = '## Settings file notes';
        lines{end+1} = '';
        for k = 1:numel(meta.settingsNotes)
            lines{end+1} = ['- ' meta.settingsNotes{k}]; %#ok<AGROW>
        end
    end

    if isfield(data, 'Setup')
        lines = [lines, reproduceLines(data)];
    end

    fid = fopen(file, 'w', 'n', 'UTF-8');
    if fid < 0
        error('lhf:report:open', 'Cannot open %s for writing.', file);
    end
    closer = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', lines{:});
end

function lines = reproduceLines(data)
% What the session ran with (Data.Setup, lhf.recordSetup) and how to run it again
    setup = data.Setup;
    lines = {'', '## Reproduce', '', ...
        'Everything below is in the data file; `lhf.recreate(dataFile, folder)` writes it out as files.', ''};
    lines{end+1} = '| Repository | Commit | State |';
    lines{end+1} = '|---|---|---|';
    for r = setup.provenance.code
        state = 'clean';
        if isempty(r.commit)
            state = r.note;
        elseif r.dirty
            state = '**uncommitted changes (saved)**';
        end
        lines{end+1} = sprintf('| %s | %s | %s |', r.name, r.commit(1:min(end, 10)), state); %#ok<AGROW>
    end
    lines{end+1} = '';
    if isempty(setup.stageUm)
        lines{end+1} = sprintf('- Stage at START: not read (%s)', escape(setup.stageNote));
    else
        lines{end+1} = sprintf('- Stage at START: X %.1f, Y %.1f, Z %.1f µm', setup.stageUm);
    end
    if ~isempty(setup.fiducial)
        lines{end+1} = sprintf('- Fiducial: newest entry %s (reference %s)', setup.fiducial.entry.time, ...
            setup.fiducial.referenceTime);
    end
    cal = setup.calibration;
    names = {cal.power.newestRun, cal.cameraDmd.file, cal.stageCamera.file, cal.zProfile.file};
    names = names(~cellfun(@isempty, names));
    [~, names] = cellfun(@fileparts, names, 'UniformOutput', false);
    if ~isempty(names)
        lines{end+1} = ['- Calibrations in force: ' strjoin(names, ', ')];
    end
    used = patternsUsed(data);
    if ~isempty(used)
        lines{end+1} = ['- Patterns shown (type row: trials): ' used];
    end
end

function text = patternsUsed(data)
% "CSplus r1: 40, CSminus r1: 38" from each trial's Actions.Patterns
    keys = {};
    for n = 1:numel(data.RawEvents.Trial)
        trial = data.RawEvents.Trial{n};
        if ~isfield(trial, 'Actions') || ~isfield(trial.Actions, 'Patterns'), continue; end
        for type = fieldnames(trial.Actions.Patterns)'
            p = trial.Actions.Patterns.(type{1});
            if isfield(p, 'shown') && p.shown
                keys{end+1} = sprintf('%s r%d', type{1}, p.row); %#ok<AGROW>
            end
        end
    end
    text = '';
    if isempty(keys), return; end
    [u, ~, k] = unique(keys);
    counts = accumarray(k(:), 1);
    text = strjoin(cellfun(@(a, b) sprintf('%s: %d', a, b), u, num2cell(counts'), 'UniformOutput', false), ', ');
end

function t = textOr(s, field, default)
    t = default;
    if isstruct(s) && isfield(s, field) && ~isempty(s.(field))
        t = char(string(s.(field)));
    end
end

function t = pct(p)
    if isnan(p)
        t = '–';
    else
        t = sprintf('%.1f', p);
    end
end

function t = secondsText(x)
    if isnan(x)
        t = 'none';
    else
        t = sprintf('%.3f s', x);
    end
end

function t = valueText(v)
    if (isnumeric(v) || islogical(v)) && numel(v) <= 8
        t = mat2str(v, 4);
    elseif ischar(v) || isstring(v)
        t = ['"' char(v) '"'];
    else
        t = sprintf('(%s %s)', strjoin(string(size(v)), 'x'), class(v));
    end
end

function t = escape(t)
    t = strrep(strrep(t, '|', '\|'), newline, ' ');
end

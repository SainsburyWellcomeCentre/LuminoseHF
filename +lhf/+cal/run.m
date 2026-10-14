function result = run(id, luminose, values, options)
% lhf.cal.run  Runs one calibration on the rig's shared devices.
%
%   result = lhf.cal.run(id, luminose)            defaults (lhf.cal.catalog), saved
%   result = lhf.cal.run(id, luminose, values)    values: struct of settings to change
%   result = lhf.cal.run(id, luminose, values, options)
%
%   id: 'cameraDmd', 'stageCamera', 'zFocus' or 'power'. The devices are the rig's
%   one object each (lhf.device(name, 'connect'): the Camera, Stage, Laser and DMD
%   panels show what happens). The camera's exposure and averaging are set from the
%   settings and put back afterwards, as are the stage limits a scan narrows; the DMD
%   is halted and the laser's emission turned off however the run ends.
%
%   options, any of
%       hooks    struct of progress(fraction, text), frame(frame) (each camera frame;
%                the Calibration window shows them on the camera panel) and
%                shouldStop() (true stops the run between steps: error lhf:cal:stopped)
%       save     false: return the result without saving (default true; the window
%                saves only when Save is pressed)
%       folder   where to save (default luminoseData/calibration)
%       devices  struct overriding any of camera, dmd, stage, laser, meter (tests)
%
%   Every run, finished, stopped or failed, adds an entry (time, settings, outcome,
%   messages, and a failure's full error report) to calibration_log.txt in the folder.
%
%   result: id, title, settings, time, data (what the calibration measured: see
%   lhf.cal.cameraDmd, stageCamera, zFocus, power), messages (warnings worth
%   reading), and files (what lhf.cal.save wrote, when saved).
%
% See also lhf.cal.catalog, lhf.cal.save, lhf.cal.plot, gui/CalibrationApp

    if nargin < 3 || isempty(values), values = struct(); end
    if nargin < 4, options = struct(); end
    cals = lhf.cal.catalog(luminose);
    cal = cals(strcmp({cals.id}, id));
    if isempty(cal)
        error('lhf:cal:unknown', 'No calibration %s: one of %s.', id, strjoin({cals.id}, ', '));
    end
    s = lhf.cal.settings(cal, values);
    hooks = withHooks(field(options, 'hooks', struct()));
    given = field(options, 'devices', struct());

    folder = field(options, 'folder', '');
    restore = {}; %#ok<NASGU> holds onCleanup objects until cleared
    try
        [d, restore] = acquire(id, cal, s, given); %#ok<ASGLU> restore: onCleanup objects, kept until cleared
        [data, messages] = feval(['lhf.cal.' id], d, s, hooks, luminose);
    catch err
        clear restore  % the camera's exposure back, the meter closed
        writeLog(luminose, folder, id, s, err);
        rethrow(err);
    end
    clear restore  % the camera's exposure back, the meter closed
    writeLog(luminose, folder, id, s, [], messages);
    result = struct('id', id, 'title', cal.title, 'settings', s, ...
        'time', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')), 'data', data, ...
        'messages', {messages}, 'files', {{}});
    if field(options, 'save', true)
        result.files = lhf.cal.save(result, luminose, folder);
    end
end


function [d, restore] = acquire(id, cal, s, given)
% The devices, connected; the camera set from the settings; what puts things back.
    d = struct();
    restore = {};
    for name = cal.devices
        if isfield(given, name{1})
            d.(name{1}) = given.(name{1});
        else
            d.(name{1}) = lhf.device(name{1}, 'connect');
        end
    end
    if isfield(d, 'camera')
        camera = d.camera;
        before = {camera.ExposureMs, camera.AverageFrames};
        restore{end + 1} = onCleanup(@() putBack(camera, before));
        camera.ExposureMs = s.exposureMs;
        camera.AverageFrames = s.averageFrames;
    end
    if strcmp(id, 'power')
        if isfield(given, 'meter')
            d.meter = given.meter;
        elseif strcmp(s.meter, 'PM100D')
            d.meter = lhf.cal.powerMeter(s.meterWavelengthNm);
            meter = d.meter;
            restore{end + 1} = onCleanup(@() meter.close());
        else
            d.meter = [];
        end
    end
end


function v = field(s, name, default)
    v = default;
    if isfield(s, name), v = s.(name); end
end

function hooks = withHooks(hooks)
    if ~isfield(hooks, 'progress'), hooks.progress = @(f, text) fprintf('  [%3.0f%%] %s\n', 100 * f, text); end
    if ~isfield(hooks, 'frame'), hooks.frame = @(~) []; end
    if ~isfield(hooks, 'shouldStop'), hooks.shouldStop = @() false; end
end

function putBack(camera, before)
    try
        camera.ExposureMs = before{1};
        camera.AverageFrames = before{2};
    catch
    end
end


function writeLog(luminose, folder, id, s, err, messages)
% One entry in calibration_log.txt; never throws (the run's result matters more).
    try
        if isempty(folder)
            folder = fullfile(char(luminose.f.luminoseData), 'calibration');
        end
        if ~isfolder(folder), mkdir(folder); end
        fid = fopen(fullfile(folder, 'calibration_log.txt'), 'a');
        closer = onCleanup(@() fclose(fid));
        if isempty(err)
            outcome = 'finished';
        elseif strcmp(err.identifier, 'lhf:cal:stopped')
            outcome = 'stopped';
        else
            outcome = 'FAILED';
        end
        fprintf(fid, '%s  %s  %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), id, outcome);
        fprintf(fid, '  settings: %s\n', jsonencode(s));
        if nargin > 5
            for k = 1:numel(messages)
                fprintf(fid, '  note: %s\n', messages{k});
            end
        end
        if ~isempty(err)
            report = getReport(err, 'extended', 'hyperlinks', 'off');
            fprintf(fid, '  %s\n', strrep(report, newline, [newline '  ']));
        end
        fprintf(fid, '\n');
        clear closer
    catch
    end
end

function result = load(file)
% lhf.cal.load  A saved calibration as a result lhf.cal.plot can draw.
%
%   result = lhf.cal.load(file)
%
%   file: a camera_dmd_*, stage_camera_*, zprofile_* or power_*.mat from
%   lhf.cal.save or the old calibration scripts. result: id, title, settings (those
%   it ran with, or an empty struct for an old file), time (its stamp), data (as
%   lhf.cal.run returns it, as far as the file holds it), messages ({}), files.
%
% See also lhf.cal.history, lhf.cal.plot

    [~, name] = fileparts(file);
    stamp = regexp(name, '\d{8}_\d{6}$', 'match', 'once');
    m = builtin('load', file);
    switch true
        case startsWith(name, 'camera_dmd_')
            id = 'cameraDmd';
            title = 'Camera - DMD';
            data = struct('registration', m.registration, 'background', []);
            if isfield(m, 'background'), data.background = m.background; end
            [data.registration, settings] = takeSettings(data.registration);
        case startsWith(name, 'stage_camera_')
            id = 'stageCamera';
            title = 'Stage - camera';
            data = struct('stageCamera', m.stageCamera);
            [data.stageCamera, settings] = takeSettings(data.stageCamera);
        case startsWith(name, 'zprofile_')
            id = 'zFocus';
            title = 'Z focus';
            data = struct('results', m.results);
            [data.results, settings] = takeSettings(data.results);
        case startsWith(name, 'power_')
            id = 'power';
            title = 'Laser power';
            data = struct('results', m.results);
            [data.results, settings] = takeSettings(data.results);
            if ~isfield(data.results, 'meterSd_mW')
                data.results.meterSd_mW = nan(size(data.results.power_setting_mW));
            end
        otherwise
            error('lhf:cal:unknownFile', '%s is not a calibration file.', name);
    end
    result = struct('id', id, 'title', title, 'settings', settings, 'time', stamp, ...
        'data', data, 'messages', {{}}, 'files', {{file}});
end


function [s, settings] = takeSettings(s)
    settings = struct();
    if isfield(s, 'settings'), settings = s.settings; end
end

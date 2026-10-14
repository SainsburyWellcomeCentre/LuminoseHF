function files = save(result, luminose, folder)
% lhf.cal.save  Writes a calibration's result where the rig reads it from.
%
%   files = lhf.cal.save(result, luminose)           into luminoseData/calibration
%   files = lhf.cal.save(result, luminose, folder)
%
%   result from lhf.cal.run. The files are those the old calibration scripts wrote,
%   so everything that reads them is unchanged (the newest of each is used), each
%   with the settings it ran with and lhf.provenance, plus a .png of lhf.cal.plot:
%       cameraDmd    camera_dmd_<stamp>.mat: registration, background, provenance
%       stageCamera  stage_camera_<stamp>.mat: stageCamera, provenance
%       zFocus       zprofile_<stamp>.mat: results
%       power        power_<stamp>.mat: results; and dmd/power_calibration.csv
%                    rewritten from the table, the one it replaces first copied to
%                    power_calibration_previous_<stamp>.csv in the folder
%   files: cell of the files written.
%
% See also lhf.cal.run, lhf.cal.load

    if nargin < 3 || isempty(folder)
        folder = fullfile(char(luminose.f.luminoseData), 'calibration');
    end
    if ~isfolder(folder), mkdir(folder); end
    stamp = result.time;
    provenance = lhf.provenance(luminose);  % code, config and computer it was made with
    data = result.data;
    files = {};
    switch result.id
        case 'cameraDmd'
            registration = data.registration;
            registration.timestamp = stamp;
            registration.settings = result.settings;
            background = data.background; %#ok<NASGU> saved by name
            files{end + 1} = fullfile(folder, ['camera_dmd_' stamp '.mat']);
            builtin('save', files{end}, 'registration', 'background', 'provenance');
        case 'stageCamera'
            stageCamera = data.stageCamera;
            stageCamera.timestamp = stamp;
            stageCamera.settings = result.settings;
            files{end + 1} = fullfile(folder, ['stage_camera_' stamp '.mat']);
            builtin('save', files{end}, 'stageCamera', 'provenance');
        case 'zFocus'
            results = data.results;
            results.timestamp = stamp;
            results.settings = result.settings;
            results.provenance = provenance;
            files{end + 1} = fullfile(folder, ['zprofile_' stamp '.mat']);
            builtin('save', files{end}, 'results');
        case 'power'
            results = data.results;
            results.timestamp = stamp;
            results.settings = result.settings;
            results.provenance = provenance;
            files{end + 1} = fullfile(folder, ['power_' stamp '.mat']);
            builtin('save', files{end}, 'results');
            if isfile(data.csvFile)
                files{end + 1} = fullfile(folder, ['power_calibration_previous_' stamp '.csv']);
                copyfile(data.csvFile, files{end});
            end
            writetable(data.table, data.csvFile);
            files{end + 1} = data.csvFile;
        otherwise
            error('lhf:cal:unknown', 'No calibration %s.', result.id);
    end
    png = strrep(files{1}, '.mat', '.png');
    fig = figure('Visible', 'off', 'Position', [100 100 1000 440], 'Color', 'w');
    closer = onCleanup(@() delete(fig));
    try
        lhf.cal.plot(result, fig);
        exportgraphics(fig, png, 'Resolution', 120);
        files{end + 1} = png;
    catch
        % the picture is a convenience: the data are saved
    end
    clear closer
end

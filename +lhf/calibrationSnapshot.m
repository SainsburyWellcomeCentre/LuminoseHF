function c = calibrationSnapshot(luminose, calibrationFolder)
% lhf.calibrationSnapshot  The calibrations in force, copied so a session keeps them.
%
%   c = lhf.calibrationSnapshot(luminose)
%   c = lhf.calibrationSnapshot(luminose, calibrationFolder)   (default
%       <dataFolder>/calibration)
%
%   Saved with every session (Data.Setup.calibration, lhf.recordSetup): later
%   calibrations overwrite dmd/power_calibration.csv and add newer files, so
%   the session keeps its own copy of what it used.
%
%   c.power        file (dmd/power_calibration.csv), text (as it was), table,
%                  newestRun (the newest power_*.mat in calibrationFolder)
%   c.spotGain     luminose.laser.spotGain (spot / full-field irradiance)
%   c.cameraDmd    file and registration (the newest camera_dmd_*.mat, without
%                  its background frame; lhf.cam.loadRegistration)
%   c.stageCamera  file and calibration (the newest stage_camera_*.mat)
%   c.zProfile     file and bestFocus_mm (the newest zprofile_*.mat)
%   c.odourTables  bottlesFile, bottlesText, chemicalsFile, chemicalsText (the
%                  tables a duty of 0 is read from)
%   c.notes        cell of what could not be read
%
%   Never throws.

    if nargin < 2
        calibrationFolder = '';
        try
            calibrationFolder = fullfile(char(luminose.f.luminoseData), 'calibration');
        catch
        end
    end
    c.notes = {};

    c.power = struct('file', '', 'text', '', 'table', [], 'newestRun', '');
    try
        c.power.file = fullfile(char(luminose.f.luminose_hf), 'dmd', 'power_calibration.csv');
        c.power.text = fileread(c.power.file);
        c.power.table = readtable(c.power.file);
    catch err
        c.notes{end+1} = ['power calibration: ' err.message];
    end
    c.power.newestRun = newest(calibrationFolder, 'power_*.mat');

    c.spotGain = [];
    try
        c.spotGain = luminose.laser.spotGain;
    catch
    end

    c.cameraDmd = struct('file', '', 'registration', []);
    try
        reg = lhf.cam.loadRegistration(calibrationFolder);
        if ~isempty(reg)
            c.cameraDmd.file = reg.file;
            c.cameraDmd.registration = reg;
        end
    catch err
        c.notes{end+1} = ['camera-DMD calibration: ' err.message];
    end

    c.stageCamera = struct('file', '', 'calibration', []);
    try
        cal = lhf.cam.loadStageCalibration(calibrationFolder);
        if ~isempty(cal)
            c.stageCamera.file = cal.file;
            c.stageCamera.calibration = cal;
        end
    catch err
        c.notes{end+1} = ['stage-camera calibration: ' err.message];
    end

    c.zProfile = struct('file', newest(calibrationFolder, 'zprofile_*.mat'), 'bestFocus_mm', []);
    if ~isempty(c.zProfile.file)
        try
            m = load(c.zProfile.file, 'results');
            c.zProfile.bestFocus_mm = m.results.bestFocus_mm;
        catch err
            c.notes{end+1} = ['z profile: ' err.message];
        end
    end

    c.odourTables = struct('bottlesFile', '', 'bottlesText', '', 'chemicalsFile', '', 'chemicalsText', '');
    try
        c.odourTables.bottlesFile = char(luminose.olfactometer.odourBottlesFile);
        c.odourTables.chemicalsFile = char(luminose.olfactometer.odourChemicalsFile);
        c.odourTables.bottlesText = fileread(c.odourTables.bottlesFile);
        c.odourTables.chemicalsText = fileread(c.odourTables.chemicalsFile);
    catch err
        c.notes{end+1} = ['odour tables: ' err.message];
    end
end

function file = newest(folder, pattern)
% The file whose name sorts last (the names carry yyyymmdd_HHMMSS), or ''
    file = '';
    if isempty(folder), return; end
    files = dir(fullfile(folder, pattern));
    if isempty(files), return; end
    names = sort({files.name});
    file = fullfile(folder, names{end});
end

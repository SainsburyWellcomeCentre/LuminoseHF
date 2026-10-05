classdef LuminoseConstants < handle
    % LuminoseConstants  Centralized paths and device configuration for Luminose
    %
    %   obj = LuminoseConstants()
    %   obj = LuminoseConstants(configFile)
    %
    %   Constructor loads configuration from a YAML file. If configFile is not
    %   provided, uses 'luminose_config.yaml' beside this file (the repo root),
    %   so the repo works from wherever it is cloned.
    %   All configuration parameters must be specified in the YAML file.
    %
    %   Use `help LuminoseConstants` or `doc LuminoseConstants` to view this
    %   documentation in MATLAB.

    properties
        % f  Struct containing resolved filesystem paths (string fields)
        f struct
        bpod struct
        olfactometer struct
        dmd struct
        laser struct
        camera struct
        zaber struct
        configFile string
        % packageVersions  version() of each device package (addDevicePackages)
        packageVersions struct
    end

    methods (Static)
        function file = defaultConfigFile()
            % defaultConfigFile  luminose_config.yaml in the folder holding this class
            file = string(fullfile(fileparts(mfilename('fullpath')), 'luminose_config.yaml'));
        end

        function config = readConfig(file)
            % readConfig  The YAML file as a struct, with no checks and no path changes
            if nargin < 1
                file = LuminoseConstants.defaultConfigFile();
            end
            config = LuminoseConstants.loadYAML(file);
        end

        function packages = devicePackages()
            % devicePackages  The device repos LuminoseHF uses: package, repo folder, URL
            packages = struct( ...
                'package', {'obis', 'zaberstage', 'hamacam', 'olfactometer'}, ...
                'repo',    {'OBISLaser', 'ZaberStage', 'HamamatsuCam', 'NIDAQOlfactometer'}, ...
                'url',     {'https://github.com/SainsburyWellcomeCentre/OBISLaser', ...
                            'https://github.com/SainsburyWellcomeCentre/ZaberStage', ...
                            'https://github.com/SainsburyWellcomeCentre/HamamatsuCam', ...
                            'https://github.com/SainsburyWellcomeCentre/NIDAQOlfactometer'});
        end

        function versions = addDevicePackages(matlabFolder)
            % addDevicePackages  Put each device repo's root (only) on the path
            %
            %   versions = LuminoseConstants.addDevicePackages(matlabFolder)
            %
            %   Each repo in devicePackages() must be in matlabFolder. Its root is
            %   added and any of its subfolders genpath put on the path are removed:
            %   a repo's tests/ and examples/ hold names (LaserTest, run_tests) that
            %   would shadow this repo's. Returns each package's version().
            versions = struct();
            entries = strsplit(path, pathsep);
            for p = LuminoseConstants.devicePackages()
                root = fullfile(char(matlabFolder), p.repo);
                if ~isfolder(fullfile(root, ['+' p.package]))
                    error('LuminoseConstants:MissingPackage', ...
                        'Package %s not found in %s: clone %s there.', p.package, root, p.url);
                end
                inside = entries(startsWith(entries, [root filesep], 'IgnoreCase', true));
                if ~isempty(inside)
                    rmpath(inside{:});
                end
                addpath(root);
                versions.(p.package) = feval([p.package '.version']);
            end
        end
    end

    methods
        function obj = LuminoseConstants(configFile)
            % LuminoseConstants  Construct the constants object.
            %
            %   obj = LuminoseConstants()
            %       Load from 'luminose_config.yaml' in the repo root
            %
            %   obj = LuminoseConstants(configFile)
            %       Load from specified YAML config file

            if nargin < 1
                configFile = LuminoseConstants.defaultConfigFile();
            else
                configFile = string(configFile);
            end
            
            % Check if config file exists
            if ~isfile(configFile)
                error('LuminoseConstants:ConfigNotFound', ...
                    'Config file not found: %s\nPlease create a config file or specify the correct path.', configFile);
            end
            
            obj.configFile = configFile;
            
            % Load configuration from YAML
            config = obj.loadYAML(configFile);
            
            % Validate required fields
            obj.validateConfig(config);
            
            % Load paths
            obj.loadPaths(config);
            
            % Load device configurations from YAML
            obj.loadBpodConfig(config);
            obj.loadOlfactometerConfig(config);
            obj.loadDMDConfig(config);
            obj.loadLaserConfig(config);
            obj.loadCameraConfig(config);
            obj.loadZaberConfig(config);

            % Add key folders to path
            addpath(genpath(char(obj.f.luminose_hf)), genpath(char(obj.f.luminoseData)), genpath(char(obj.f.matlabFolder)));
            obj.packageVersions = LuminoseConstants.addDevicePackages(obj.f.matlabFolder);
            savepath();
        end
        
        function saveConfig(obj, filename)
            % saveConfig  Save current configuration to YAML file
            %
            %   obj.saveConfig(filename)
            %       Save configuration to specified file
            
            if nargin < 2
                filename = obj.configFile;
            end
            
            config = struct();
            config.paths.parentFolder = char(obj.f.parentFolder);
            config.paths.matlabFolder = char(obj.f.matlabFolder);
            config.paths.dataFolder = char(obj.f.luminoseData);
            config.bpod = obj.bpod;
            config.olfactometer = obj.olfactometer;
            config.dmd = obj.dmd;
            
            obj.saveYAML(filename, config);
            fprintf('Configuration saved to: %s\n', filename);
        end
    end

    methods (Static, Access = private)
        function config = loadYAML(filename)
            % loadYAML  Load YAML configuration file
            %
            %   Requires: YAML toolbox or ReadYaml function
            %   Falls back to basic parsing if not available
            
            try
                % Try using yaml toolbox if available
                config = yaml.loadFile(filename, "ConvertToArray", true);
            catch
                try
                    % Try ReadYaml if available
                    config = ReadYaml(filename);
                catch
                    % Fallback: use basic YAML parsing
                    config = LuminoseConstants.parseYAMLBasic(filename);
                end
            end
        end
        
    end

    methods (Access = private)
        function saveYAML(obj, filename, data)
            % saveYAML  Save data to YAML file
            
            try
                % Try using yaml toolbox if available
                yaml.dumpFile(filename, data, "block");
            catch
                try
                    % Try WriteYaml if available
                    WriteYaml(filename, data);
                catch
                    % Fallback: basic YAML writing
                    warning('LuminoseConstants:NoYAMLWriter', ...
                        'No YAML writer found. Install yaml toolbox for best results.');
                    obj.writeYAMLBasic(filename, data);
                end
            end
        end
        
    end

    methods (Static, Access = private)
        function config = parseYAMLBasic(filename)
            % parseYAMLBasic  Basic YAML parser (fallback)
            %
            %   Nested "key:" blocks at any depth (by indentation), scalars (true, false,
            %   numbers, quoted or bare text), [a, b] lists (a row vector when all numbers,
            %   else a cell) and {key: value} maps. For complex configs, install the YAML
            %   toolbox: https://github.com/ewiger/yamlmatlab

            fid = fopen(filename, 'r');
            if fid == -1
                error('Cannot open file: %s', filename);
            end
            closeFile = onCleanup(@() fclose(fid));

            config = struct();
            stack = struct('indent', -1, 'path', {{}});  % open blocks, outermost first
            while ~feof(fid)
                originalLine = fgetl(fid);
                if ~ischar(originalLine), break; end
                line = strtrim(originalLine);
                % Skip comments, empty lines and anything that is not "key: value"
                colonIdx = strfind(line, ':');
                if isempty(line) || startsWith(line, '#') || isempty(colonIdx)
                    continue;
                end
                indent = find(originalLine ~= ' ', 1) - 1;
                key = strtrim(line(1:colonIdx(1)-1));
                value = strtrim(line(colonIdx(1)+1:end));
                % Strip inline comments
                hashIdx = strfind(value, '#');
                if ~isempty(hashIdx), value = strtrim(value(1:hashIdx(1)-1)); end

                while stack(end).indent >= indent
                    stack(end) = [];
                end
                path = [stack(end).path, {key}];
                if isempty(value)
                    config = setfield(config, path{:}, struct());
                    stack(end + 1) = struct('indent', indent, 'path', {path}); %#ok<AGROW>
                else
                    config = setfield(config, path{:}, LuminoseConstants.parseYAMLValue(value));
                end
            end
        end

        function value = parseYAMLValue(text)
            % parseYAMLValue  One YAML value: a scalar, [a, b] list or {key: value} map
            text = strtrim(text);
            if startsWith(text, '[') && endsWith(text, ']')
                items = cellfun(@LuminoseConstants.parseYAMLValue, ...
                    LuminoseConstants.splitYAMLItems(text(2:end-1)), 'UniformOutput', false);
                if all(cellfun(@(v) isnumeric(v) && isscalar(v), items))
                    value = [items{:}];
                    if isempty(value), value = zeros(1, 0); end
                else
                    value = items;
                end
            elseif startsWith(text, '{') && endsWith(text, '}')
                value = struct();
                for item = LuminoseConstants.splitYAMLItems(text(2:end-1))
                    colonIdx = strfind(item{1}, ':');
                    if isempty(colonIdx), continue; end
                    value.(strtrim(item{1}(1:colonIdx(1)-1))) = ...
                        LuminoseConstants.parseYAMLValue(item{1}(colonIdx(1)+1:end));
                end
            elseif strcmp(text, 'true')
                value = true;
            elseif strcmp(text, 'false')
                value = false;
            elseif ~isnan(str2double(text))
                value = str2double(text);
            elseif numel(text) >= 2 && startsWith(text, '"') && endsWith(text, '"')
                value = strrep(text(2:end-1), '\\', '\');  % YAML: "\\" in double quotes is one \
            elseif numel(text) >= 2 && startsWith(text, '''') && endsWith(text, '''')
                value = text(2:end-1);  % Remove quotes
            else
                value = text;
            end
        end

        function items = splitYAMLItems(text)
            % splitYAMLItems  Split at commas outside brackets, braces and quotes
            items = {};
            depth = 0;
            quote = '';
            from = 1;
            for k = 1:numel(text)
                c = text(k);
                if ~isempty(quote)
                    if c == quote, quote = ''; end
                elseif c == '"' || c == ''''
                    quote = c;
                elseif c == '[' || c == '{'
                    depth = depth + 1;
                elseif c == ']' || c == '}'
                    depth = depth - 1;
                elseif c == ',' && depth == 0
                    items{end + 1} = strtrim(text(from:k-1)); %#ok<AGROW>
                    from = k + 1;
                end
            end
            last = strtrim(text(from:end));
            if ~isempty(last) || ~isempty(items)
                items{end + 1} = last;
            end
        end
        
    end

    methods (Access = private)
        function writeYAMLBasic(obj, filename, data)
            % writeYAMLBasic  Basic YAML writer (fallback)
            
            fid = fopen(filename, 'w');
            if fid == -1
                error('Cannot open file for writing: %s', filename);
            end
            
            fprintf(fid, '# Luminose Configuration\n');
            fprintf(fid, '# Generated: %s\n\n', datestr(now));
            
            fields = fieldnames(data);
            for i = 1:length(fields)
                obj.writeYAMLStruct(fid, fields{i}, data.(fields{i}), 0);
            end
            
            fclose(fid);
        end
        
        function writeYAMLStruct(obj, fid, name, value, indent)
            % writeYAMLStruct  Recursively write struct to YAML
            
            spaces = repmat(' ', 1, indent);
            
            if isstruct(value)
                fprintf(fid, '%s%s:\n', spaces, name);
                subfields = fieldnames(value);
                for i = 1:length(subfields)
                    obj.writeYAMLStruct(fid, subfields{i}, value.(subfields{i}), indent + 2);
                end
            else
                if islogical(value)
                    fprintf(fid, '%s%s: %s\n', spaces, name, lower(string(value)));
                elseif isnumeric(value)
                    fprintf(fid, '%s%s: %g\n', spaces, name, value);
                else
                    fprintf(fid, '%s%s: "%s"\n', spaces, name, char(value));
                end
            end
        end
        
        function validateConfig(obj, config)
            % validateConfig  Ensure all required fields are present
            
            required = {'paths', 'bpod', 'olfactometer', 'dmd', 'laser', 'camera', 'zaber'};
            for i = 1:length(required)
                if ~isfield(config, required{i})
                    error('LuminoseConstants:MissingSection', ...
                        'Config file missing required section: %s', required{i});
                end
            end
            
            % Validate paths
            if ~all(isfield(config.paths, {'parentFolder', 'matlabFolder', 'dataFolder'}))
                error('LuminoseConstants:MissingPaths', ...
                    'Config file must specify parentFolder, matlabFolder and dataFolder in paths section');
            end
        end
        
        function loadPaths(obj, config)
            % loadPaths  Load path configuration
            
            f = struct();
            f.parentFolder = string(config.paths.parentFolder);
            f.luminose_hf = string(fileparts(mfilename('fullpath')));  % this repository, wherever it is
            f.luminoseData = string(config.paths.dataFolder);
            f.matlabFolder = string(config.paths.matlabFolder);
            obj.f = f;
        end
        
        function loadBpodConfig(obj, config)
            % loadBpodConfig  Load Bpod configuration from YAML
            
            cfg = config.bpod;
            obj.bpod = struct( ...
                'protocols', string(cfg.protocols), ...
                'protocolFile', string(cfg.protocolFile), ...
                'dataPath', string(cfg.dataPath) ...
            );
        end
        
        function loadOlfactometerConfig(obj, config)
            % loadOlfactometerConfig  Load olfactometer configuration from YAML
            
            cfg = config.olfactometer;
            
            obj.olfactometer = struct( ...
                'sampleRate', cfg.sampleRate, ...
                'pulseTime', cfg.pulseTime, ...
                'backValveDelay', cfg.backValveDelay, ...
                'preSequenceTime', cfg.preSequenceTime, ...
                'postSequenceTime', cfg.postSequenceTime, ...
                'distanceFile', string(cfg.distanceFile), ...
                'mapFile', string(cfg.mapFile), ...
                'odourChemicalsFile', string(cfg.odourChemicalsFile), ...
                'odourBottlesFile', string(cfg.odourBottlesFile), ...
                'inputTrigger', cfg.inputTrigger, ...
                'DigitalTriggerTimeout', cfg.DigitalTriggerTimeout ...
            );
            
            % Load nested device structs
            obj.olfactometer.backValves = obj.loadDeviceConfig(cfg.backValves);
            obj.olfactometer.frontValves = obj.loadDeviceConfig(cfg.frontValves);
            obj.olfactometer.syncTTL = obj.loadDeviceConfig(cfg.syncTTL);
        end
        
        function device = loadDeviceConfig(obj, dev)
            % loadDeviceConfig  Helper to load device configuration
            
            device = struct( ...
                'deviceID', string(dev.deviceID), ...
                'channelID', string(dev.channelID), ...
                'measurementType', string(dev.measurementType) ...
            );
            
            if isfield(dev, 'channelCount')
                device.channelCount = dev.channelCount;
            end
        end
        
        function loadDMDConfig(obj, config)
            % loadDMDConfig  Load DMD configuration from YAML
            
            cfg = config.dmd;
            
            obj.dmd = struct( ...
                'testImagePath', string(cfg.testImagePath), ...
                'projectedDMDlength', cfg.projectedDMDlength, ...
                'spotSide', cfg.spotSide, ...
                'patternsFolder', string(cfg.patternsFolder) ...
            );
        end
        
        function loadLaserConfig(obj, config)
            cfg = config.laser;
            obj.laser = struct( ...
                'port',        string(cfg.port), ...
                'baudRate',    cfg.baudRate, ...
                'maxPower_mW', cfg.maxPower_mW, ...
                'spotGain',    1 ...
            );
            if isfield(cfg, 'spotGain')  % measured spot vs full-field irradiance
                obj.laser.spotGain = cfg.spotGain;
            end
        end

        function loadCameraConfig(obj, config)
            cfg = config.camera;
            obj.camera = struct( ...
                'adaptorName',         string(cfg.adaptorName), ...
                'adaptorDllPath',      string(cfg.adaptorDllPath), ...
                'deviceID',            cfg.deviceID, ...
                'exposureTime_ms',     cfg.exposureTime_ms, ...
                'nAverageFrames',      cfg.nAverageFrames, ...
                'pixelSize_um',        cfg.pixelSize_um, ...
                'effectivePixelSize_um', cfg.effectivePixelSize_um ...
            );
        end

        function loadZaberConfig(obj, config)
            cfg = config.zaber;
            obj.zaber = struct( ...
                'port',      string(cfg.port), ...
                'zRange_um', cfg.zRange_um, ...
                'zStep_um',  cfg.zStep_um ...
            );
            % Optional: the X, Y and Z axes (rigStage, rigStages), each counted the other way
            % if reversed (zaberstage.Stage 'Reversed') and kept within safe_um
            % (SafeLimitsUm; rigAxisOptions refuses an axis without it), and alignment's limits
            obj.zaber.axes = struct();
            if isfield(cfg, 'axes') && isstruct(cfg.axes)
                for name = {'x', 'y', 'z'}
                    if isfield(cfg.axes, name{1})
                        a = cfg.axes.(name{1});
                        obj.zaber.axes.(name{1}) = struct('device', double(a.device), 'axis', double(a.axis), ...
                            'reversed', isfield(a, 'reversed') && logical(a.reversed));
                        if isfield(a, 'safe_um')
                            safe = a.safe_um;
                            if ~isnumeric(safe), safe = str2double(string(safe)); end  % -Inf, Inf read as text
                            obj.zaber.axes.(name{1}).safe_um = double(safe(:)');
                        end
                    end
                end
            end
            obj.zaber.alignment = LuminoseConstants.alignmentDefaults();
            if isfield(cfg, 'alignment') && isstruct(cfg.alignment)
                for name = fieldnames(cfg.alignment)'
                    if ~isfield(obj.zaber.alignment, name{1})
                        error('LuminoseConstants:badConfig', 'Unknown zaber.alignment setting "%s".', name{1});
                    end
                    obj.zaber.alignment.(name{1}) = double(cfg.alignment.(name{1}));
                end
            end
        end
    end

    methods (Static)
        function a = alignmentDefaults()
            % alignmentDefaults  Automatic alignment's limits when the config sets none (lhf.cam.align)
            a = struct('maxTravelXY_um', 1000, 'maxTravelZ_um', 200, 'maxStep_um', 500, ...
                'tolerance_um', 2, 'maxIterations', 6, 'zSearch_um', 100, 'zStep_um', 10, ...
                'rotationWarn_deg', 1, 'minPeak', 0.1);
        end
    end
end
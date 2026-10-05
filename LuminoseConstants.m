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
        bonsai struct
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
            % devicePackages  The device repos luminose_hf uses: package, repo folder, URL
            packages = struct( ...
                'package', {'obis', 'zaberstage', 'hamacam', 'olfactometer'}, ...
                'repo',    {'OBISLaser', 'ZaberStage', 'HamamatsuCam', 'Olfactometer'}, ...
                'url',     {'https://github.com/SainsburyWellcomeCentre/OBISLaser', ...
                            'https://github.com/SainsburyWellcomeCentre/ZaberStage', ...
                            'https://github.com/SainsburyWellcomeCentre/HamamatsuCam', ...
                            'https://github.com/SainsburyWellcomeCentre/Olfactometer'});
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
            obj.loadBonsaiConfig(config);
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
            config.bonsai = obj.bonsai;
            
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
            %   This is a simple parser for basic YAML. For complex configs,
            %   install the YAML toolbox: https://github.com/ewiger/yamlmatlab
            
            fid = fopen(filename, 'r');
            if fid == -1
                error('Cannot open file: %s', filename);
            end
            
            config = struct();
            currentSection = '';
            currentSubsection = '';
            
            while ~feof(fid)
                line = fgetl(fid);
                originalLine = line;
                line = strtrim(line);
                
                % Skip comments and empty lines
                if isempty(line) || startsWith(line, '#')
                    continue;
                end
                
                % Count leading spaces for indentation level
                leadingSpaces = 0;
                for i = 1:length(originalLine)
                    if originalLine(i) == ' '
                        leadingSpaces = leadingSpaces + 1;
                    else
                        break;
                    end
                end
                
                % Check if this is a key (ends with colon)
                colonIdx = strfind(line, ':');
                if ~isempty(colonIdx)
                    key = strtrim(line(1:colonIdx(1)-1));
                    value = strtrim(line(colonIdx(1)+1:end));
                    % Strip inline comments
                    hashIdx = strfind(value, '#');
                    if ~isempty(hashIdx), value = strtrim(value(1:hashIdx(1)-1)); end
                    
                    % Level 0: Top-level section (no indentation)
                    if leadingSpaces == 0 && endsWith(line, ':')
                        currentSection = key;
                        currentSubsection = '';
                        config.(currentSection) = struct();
                        continue;
                    end
                    
                    % Level 1: Subsection (2 spaces)
                    if leadingSpaces == 2 && isempty(value)
                        currentSubsection = key;
                        if ~isempty(currentSection)
                            config.(currentSection).(currentSubsection) = struct();
                        end
                        continue;
                    end
                    
                    % Key-value pairs with actual values
                    if ~isempty(value)
                        % Convert value types
                        if strcmp(value, 'true')
                            value = true;
                        elseif strcmp(value, 'false')
                            value = false;
                        elseif ~isempty(str2double(value)) && ~isnan(str2double(value))
                            value = str2double(value);
                        else
                            % Remove quotes if present
                            if (startsWith(value, '"') && endsWith(value, '"')) || ...
                               (startsWith(value, '''') && endsWith(value, ''''))
                                value = value(2:end-1);
                            end
                        end
                        
                        % Assign to appropriate level based on indentation
                        if leadingSpaces >= 4 && ~isempty(currentSubsection)
                            % Level 2: nested under subsection (4+ spaces)
                            config.(currentSection).(currentSubsection).(key) = value;
                        elseif leadingSpaces >= 2 && ~isempty(currentSection)
                            % Level 1: under section (2+ spaces)
                            config.(currentSection).(key) = value;
                        end
                    end
                end
            end
            
            fclose(fid);
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
            
            required = {'paths', 'bpod', 'olfactometer', 'dmd', 'bonsai', 'laser', 'camera', 'zaber'};
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
        
        function loadBonsaiConfig(obj, config)
            % loadBonsaiConfig  Load Bonsai configuration from YAML

            cfg = config.bonsai;

            obj.bonsai = struct( ...
                'launch_bonsai', cfg.launch_bonsai, ...
                'exePath', string(cfg.exePath), ...
                'workflowPath', string(cfg.workflowPath) ...
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
                'axisIndex', cfg.axisIndex, ...
                'zRange_um', cfg.zRange_um, ...
                'zStep_um',  cfg.zStep_um ...
            );
        end
    end
end
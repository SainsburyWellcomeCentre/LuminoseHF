classdef RepositoryTest < matlab.unittest.TestCase
% Checks on the code itself: it parses, uses the shared package rather
% than the removed per-protocol copies, and finds its config from anywhere.

    properties (Constant)
        % Per-protocol helpers replaced by +lhf; nothing may call them again
        removed = {'getNextTrialType_hf_', 'computeBias_hf_', 'getTrialOutcome_hf_', ...
            'getTrialSide_hf_', 'updateTrialData_hf_', 'liveOutcomePlot_hf_', ...
            'liveAccuracyPlot_hf_', 'liveRewardPlot_hf_', 'liveResponseTimePlot_hf_', ...
            'createLivePlotFigure', 'resolveOdourDelivery_hf_', 'laser_hf_powercal'}
    end

    methods (Test)
        function codeParses(tc)
            % A parse error stops a file running at all (style is not checked here)
            for f = RepositoryTest.codeFiles()'
                tree = mtree(f{1}, '-file');
                failed = strcmp(tree.root.kind, 'ERR');
                why = '';
                if failed
                    messages = checkcode(f{1});
                    why = strjoin({messages.message}, '; ');
                end
                tc.verifyFalse(failed, sprintf('%s does not parse: %s', f{1}, why));
            end
        end

        function removedHelpersAreNotCalled(tc)
            for f = RepositoryTest.codeFiles()'
                if endsWith(f{1}, 'RepositoryTest.m'), continue; end
                text = fileread(f{1});
                for name = tc.removed
                    % liveEncoderPlot_hf_sleep is still the sleep protocol's own
                    tc.verifyEmpty(regexp(text, ['\<' name{1} '(?!sleep)\w*\('], 'once'), ...
                        sprintf('%s calls %s', f{1}, name{1}));
                end
            end
        end

        function removedDeviceModelsAreNotUsed(tc)
            % Device drivers moved to their own repositories (docs/architecture.md, D16)
            r = RepositoryTest.root();
            listing = dir(fullfile(r, '**', '*.m'));
            listing = listing(~contains({listing.folder}, 'bpod_examples'));
            for k = 1:numel(listing)
                file = fullfile(listing(k).folder, listing(k).name);
                if endsWith(file, 'RepositoryTest.m'), continue; end
                found = regexp(fileread(file), '\<(LaserModel|CameraModel|ZaberModel|OlfactometerModel)\(|lhf\.olf\.worker', ...
                    'match', 'once');
                tc.verifyEmpty(found, sprintf('%s uses %s', file, found));
            end
        end

        function devicePackagesAreFound(tc)
            config = LuminoseConstants.readConfig();
            versions = LuminoseConstants.addDevicePackages(config.paths.matlabFolder);
            tc.verifyEqual(sort(fieldnames(versions))', ...
                sort({LuminoseConstants.devicePackages().package}));
        end

        function repeatOnErrorIsGone(tc)
            for f = RepositoryTest.codeFiles()'
                if contains(f{1}, [filesep 'tests' filesep]) || contains(f{1}, 'settingsHistory'), continue; end
                tc.verifyFalse(contains(fileread(f{1}), 'RepeatOnError'), f{1});
            end
        end

        function configIsFoundBesideTheClass(tc)
            file = LuminoseConstants.defaultConfigFile();
            tc.verifyEqual(char(file), fullfile(RepositoryTest.root(), 'luminose_config.yaml'));
        end
    end

    methods (Static)
        function r = root()
            r = fileparts(fileparts(which('RepositoryTest')));
        end

        function files = codeFiles()
            r = RepositoryTest.root();
            listing = [dir(fullfile(r, '+lhf', '**', '*.m')); ...
                       dir(fullfile(r, 'protocols', 'luminose_hf_*', '**', '*.m')); ...
                       dir(fullfile(r, 'tests', '*.m')); ...
                       dir(fullfile(r, 'LuminoseConstants.m'))];
            files = fullfile({listing.folder}, {listing.name})';
        end
    end
end

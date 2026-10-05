classdef PatternDesignTest < matlab.unittest.TestCase
% Where pattern designs live and when a row has one: lhf.patternFolder,
% lhf.patternFileType, lhf.patternDesign (files in a temporary folder, no DMD),
% and how long a cue or stimulus lasts: lhf.patternDuration, lhf.stimDuration.

    properties
        shared
        dmd
    end

    methods (TestMethodSetup)
        function makeFolders(tc)
            tc.shared = tempname;
            mkdir(tc.shared);
            tc.dmd = struct('patternsFolder', string(tc.shared));
        end
    end

    methods (TestMethodTeardown)
        function removeFolders(tc)
            rmdir(tc.shared, 's');
        end
    end

    methods (Test)
        function typesShareOneFolderAndNameFilesByType(tc)
            tc.verifyEqual(lhf.patternFolder(tc.dmd, 'CSplus'), tc.shared);
            tc.verifyEqual(lhf.patternFileType(tc.dmd, 'CSminus'), 'CSminus');
            tc.dmd.typeFileNames = struct('CSminus', 'powercal');
            tc.verifyEqual(lhf.patternFileType(tc.dmd, 'CSminus'), 'powercal');
            tc.verifyEqual(lhf.patternFileType(tc.dmd, 'cue'), 'cue');
            tc.verifyEqual(lhf.patternFolder(tc.dmd, 'CSminus'), tc.shared);
        end

        function aRowWithoutAFileHasNoDesign(tc)
            tc.verifyEmpty(lhf.patternDesign(struct(), tc.dmd, 'CSplus', 1));
        end

        function theNewestFileForTheRowIsLoaded(tc)
            saveDesign(tc.shared, 'CSminus', 'r1_20260101_000000', 100);
            pause(1.1);  % distinct file dates
            saveDesign(tc.shared, 'CSminus', 'r1_20260102_000000', 200);
            saveDesign(tc.shared, 'CSminus', 'r2_20260103_000000', 300);
            d = lhf.patternDesign(struct(), tc.dmd, 'CSminus', 1);
            tc.verifyEqual(d.spots.x, 200);
            d = lhf.patternDesign(struct(), tc.dmd, 'CSminus', 2);
            tc.verifyEqual(d.spots.x, 300);
        end

        function aTypeWithItsOwnFileNameIgnoresTheOthers(tc)
            % goNogo's CS- design in the shared folder is not powercal's
            saveDesign(tc.shared, 'CSminus', 'r1_20260101_000000', 100);
            tc.dmd.typeFileNames = struct('CSminus', 'powercal');
            tc.verifyEmpty(lhf.patternDesign(struct(), tc.dmd, 'CSminus', 1));
            saveDesign(tc.shared, 'powercal', 'r1_20260930_000000', 400);
            d = lhf.patternDesign(struct(), tc.dmd, 'CSminus', 1);
            tc.verifyEqual(d.spots.x, 400);
        end

        function aDesignInMemoryWins(tc)
            saveDesign(tc.shared, 'cue', 'r1_20260101_000000', 100);
            memory.cue = {struct('spots', spot(700), 'tickMs', 10, 'r_px', 5, 'nF', 1)};
            d = lhf.patternDesign(memory, tc.dmd, 'cue', 1);
            tc.verifyEqual(d.spots.x, 700);
        end

        function aDesignWithNoSpotsIsNothing(tc)
            % powercal marks rows it knows are empty this way (no file lookup per trial)
            saveDesign(tc.shared, 'CSplus', 'r1_20260101_000000', 100);
            empty = struct('x', {}, 'y', {}, 'onset_ms', {}, 'dur_ms', {}, 'isFixed', {});
            memory.CSplus = {struct('spots', empty, 'tickMs', 1, 'r_px', 1, 'nF', 0)};
            tc.verifyEmpty(lhf.patternDesign(memory, tc.dmd, 'CSplus', 1));
        end

        function anOldFileWithoutARowIsRowOne(tc)
            saveDesign(tc.shared, 'opto', '20250101_000000', 50);
            d = lhf.patternDesign(struct(), tc.dmd, 'opto', 1);
            tc.verifyEqual(d.spots.x, 50);
            tc.verifyTrue(d.spots.isFixed);  % added when missing
            tc.verifyEmpty(lhf.patternDesign(struct(), tc.dmd, 'opto', 2));
        end

        function aDesignPlaysItsFramesAtTheRowsExposure(tc)
            % spots end at 80 and 250 ms on a 20 ms tick: 13 frames
            d = struct('spots', [spot(100), spot(200)], 'tickMs', 20);
            d.spots(2).onset_ms = 50; d.spots(2).dur_ms = 200;
            tc.verifyEqual(lhf.patternDuration(d, [20000 10000], 1), 0.26, 'AbsTol', 1e-12);
            tc.verifyEqual(lhf.patternDuration(d, [20000 10000], 2), 0.13, 'AbsTol', 1e-12);
            tc.verifyEqual(lhf.patternDuration(d, 20000, 3), 0.26, 'AbsTol', 1e-12);  % last exposure for later rows
        end

        function eachKindLastsAsLongAsWhatItShows(tc)
            global BpodSystem luminose %#ok<GVMIS>
            saved = {BpodSystem, luminose};
            tc.addTeardown(@restoreGlobals, saved);
            BpodSystem = struct('PluginObjects', struct());
            BpodSystem.PluginObjects.PatternDesigns.CSplus = {[], struct('spots', spot(100), 'tickMs', 10, 'r_px', 5, 'nF', 1)};
            luminose = struct('dmd', tc.dmd, 'olfactometer', ...
                struct('preSequenceTime', 0.001, 'pulseTime', 1, 'postSequenceTime', 0.001));
            g.LightDuration_cue = 0.3;
            g.SoundDuration_CSminus = 0.7;
            g.valves_CSminus = [3 4 5; 6 0 0];
            g.patternExposure_CSplus = [10000 5000];
            g.patternProbs_CSplus = [0.5 0.5];

            tc.verifyEqual(lhf.stimDuration(g, 'Light', 'cue'), 0.3);
            tc.verifyEqual(lhf.stimDuration(g, 'Sound', 'CSminus'), 0.7);

            % the drawn odour row: one slot per odour, padding zeros are none
            BpodSystem.PluginObjects.NextOdourRow.CSminus = 2;
            tc.verifyEqual(lhf.stimDuration(g, 'Odour', 'CSminus'), 1.002, 'AbsTol', 1e-12);
            tc.verifyEqual(lhf.stimDuration(g, 'Odour', 'CSminus', 'longest'), 3.006, 'AbsTol', 1e-12);

            % the drawn pattern row: 8 frames x 5 ms; a row with no design lasts 0
            BpodSystem.PluginObjects.SelectedPatternRow.CSplus = 2;
            tc.verifyEqual(lhf.stimDuration(g, 'Pattern', 'CSplus'), 0.04, 'AbsTol', 1e-12);
            BpodSystem.PluginObjects.SelectedPatternRow.CSplus = 1;
            tc.verifyEqual(lhf.stimDuration(g, 'Pattern', 'CSplus'), 0);
            tc.verifyEqual(lhf.stimDuration(g, 'Pattern', 'CSplus', 'longest'), 0.04, 'AbsTol', 1e-12);

            % a blank design (powercal's default CS+) shows nothing for blankMs
            empty = struct('x', {}, 'y', {}, 'onset_ms', {}, 'dur_ms', {}, 'isFixed', {});
            BpodSystem.PluginObjects.PatternDesigns.CSplus{1} = ...
                struct('spots', empty, 'tickMs', 1, 'r_px', 1, 'nF', 0, 'blankMs', 80);
            tc.verifyEmpty(lhf.selectedDesign('CSplus'));  % nothing to project
            tc.verifyEqual(lhf.stimDuration(g, 'Pattern', 'CSplus'), 0.08, 'AbsTol', 1e-12);
            tc.verifyEqual(lhf.stimDuration(g, 'Pattern', 'CSplus', 'longest'), 0.08, 'AbsTol', 1e-12);

            tc.verifyError(@() lhf.stimDuration(g, 'Smell', 'cue'), 'lhf:stimDuration:kind');
        end
    end
end

function restoreGlobals(saved)
    global BpodSystem luminose %#ok<GVMIS>
    [BpodSystem, luminose] = saved{:};
end

function s = spot(x)
    s = struct('x', x, 'y', 384, 'onset_ms', 0, 'dur_ms', 80, 'isFixed', true);
end

function saveDesign(folder, patternType, stamp, x)
    spots = rmfield(spot(x), 'isFixed');  %#ok<NASGU> the designer's older files lack it
    tickMs = 80; r_px = 23; nF = 1; %#ok<NASGU>
    save(fullfile(folder, sprintf('designed_%s_%s_meta.mat', patternType, stamp)), ...
        'spots', 'tickMs', 'r_px', 'nF');
end

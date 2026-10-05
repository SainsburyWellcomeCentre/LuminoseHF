classdef MergeSettingsTest < matlab.unittest.TestCase
% Loading a saved settings file: lhf.mergeSettings, lhf.settingsHistory.

    properties
        defaults
    end

    methods (TestMethodSetup)
        function makeDefaults(tc)
            d.GUI.CSplus_prob = 0.5;
            d.GUI.BiasCorrection = true;
            d.GUI.CueType = 1;
            d.GUIMeta.CueType.Style = 'popupmenu';
            d.GUIMeta.CueType.String = {'Odour', 'Pattern', 'Light'};
            d.GUIMeta.CSplus_prob.Label = 'CS+ Probability';
            d.GUIPanels.TrainingParams = {'BiasCorrection', 'CSplus_prob'};
            d.GUITabs.Trials = {'TrainingParams'};
            tc.defaults = d;
        end
    end

    methods (Test)
        function noSavedFileGivesTheDefaults(tc)
            [S, notes] = lhf.mergeSettings(struct(), tc.defaults, 'goNogo');
            tc.verifyEqual(S, tc.defaults);
            tc.verifyEmpty(notes);
        end

        function savedValuesAreKept(tc)
            saved.GUI = struct('CSplus_prob', 0.7, 'BiasCorrection', 0, 'CueType', 3);
            [S, notes] = lhf.mergeSettings(saved, tc.defaults, 'goNogo');
            tc.verifyEqual(S.GUI.CSplus_prob, 0.7);
            tc.verifyEqual(S.GUI.BiasCorrection, 0);  % logical and double are one kind
            tc.verifyEqual(S.GUI.CueType, 3);
            tc.verifyEmpty(notes);
        end

        function declarationsComeFromTheDefaults(tc)
            saved.GUI = struct('CSplus_prob', 0.7);
            saved.GUIMeta.CSplus_prob.Label = 'Old label';
            saved.GUIPanels.TrainingParams = {'CSplus_prob', 'RepeatOnError'};
            S = lhf.mergeSettings(saved, tc.defaults, 'goNogo');
            tc.verifyEqual(S.GUIMeta, tc.defaults.GUIMeta);
            tc.verifyEqual(S.GUIPanels, tc.defaults.GUIPanels);
        end

        function retiredSettingIsDroppedWithANote(tc)
            saved.GUI = struct('CSplus_prob', 0.6, 'RepeatOnError', true);
            [S, notes] = lhf.mergeSettings(saved, tc.defaults, 'goNogo');
            tc.verifyFalse(isfield(S.GUI, 'RepeatOnError'));
            tc.verifyNumElements(notes, 1);
            tc.verifySubstring(notes{1}, 'RepeatOnError');
        end

        function undeclaredValuesAreKept(tc)
            % Pattern tables and delivered odours are added outside GUIparams
            saved.GUI = struct('patternProbs_cue', [0.5 0.5], 'delivered_odours', struct('cue', 3));
            saved.RandomSeed = 42;
            [S, notes] = lhf.mergeSettings(saved, tc.defaults, 'goNogo');
            tc.verifyEqual(S.GUI.patternProbs_cue, [0.5 0.5]);
            tc.verifyEqual(S.GUI.delivered_odours.cue, 3);
            tc.verifyEqual(S.RandomSeed, 42);
            tc.verifyEmpty(notes);
        end

        function wrongKindKeepsTheDefault(tc)
            saved.GUI = struct('CSplus_prob', 'half');
            [S, notes] = lhf.mergeSettings(saved, tc.defaults, 'goNogo');
            tc.verifyEqual(S.GUI.CSplus_prob, 0.5);
            tc.verifySubstring(notes{1}, 'CSplus_prob');
        end

        function menuChoiceOutOfRangeKeepsTheDefault(tc)
            saved.GUI = struct('CueType', 7);
            [S, notes] = lhf.mergeSettings(saved, tc.defaults, 'goNogo');
            tc.verifyEqual(S.GUI.CueType, 1);
            tc.verifySubstring(notes{1}, 'out of range');
        end

        function renamedSettingCarriesItsValue(tc)
            history.renamed = {'CSplusProbability', 'CSplus_prob'};
            history.retired = {};
            saved.GUI = struct('CSplusProbability', 0.8);
            [S, notes] = lhf.mergeSettings(saved, tc.defaults, 'goNogo', history);
            tc.verifyEqual(S.GUI.CSplus_prob, 0.8);
            tc.verifyFalse(isfield(S.GUI, 'CSplusProbability'));
            tc.verifySubstring(notes{1}, 'CSplusProbability is now CSplus_prob');
        end

        function powercalDropsItsOldLaserLists(tc)
            % Laser power is per design now (2026-09-30)
            saved.GUI = struct('LaserIrradiances_mWmm2', [1 3], 'LaserIrradiances_CSminus', [2 5], ...
                'CentralSpotSide_um', 120);
            [S, notes] = lhf.mergeSettings(saved, tc.defaults, 'powercal');
            tc.verifyFalse(any(isfield(S.GUI, {'LaserIrradiances_mWmm2', 'LaserIrradiances_CSminus', 'CentralSpotSide_um'})));
            tc.verifyNumElements(notes, 3);
        end

        function historyExistsForEveryProtocol(tc)
            for p = {'goNogo', 'powercal', '2AFC', 'MTS', 'sleep'}
                h = lhf.settingsHistory(p{1});
                tc.verifySize(h.renamed, [size(h.renamed, 1) 2]);
                % A retired name must not also be renamed
                tc.verifyEmpty(intersect(h.retired, h.renamed(:)'));
            end
        end
    end
end

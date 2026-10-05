classdef OdourDeliveryTest < matlab.unittest.TestCase
% Which valves an odour soft code delivers: lhf.olf.resolve, lhf.olf.drawRows,
% how long a row plays: lhf.olf.sequenceDuration, and the delivery itself on the
% olfactometer package's simulated valves, in process: lhf.olf.deliver, lhf.olf.close
% (no hardware, no pool).

    properties
        GUI
        types = {'cue', 'CSplus', 'CSminus'}
    end

    methods (TestMethodSetup)
        function makeTables(tc)
            g.valves_cue = [3 4];            g.dutyCycles_cue = [0 0];          g.probs_cue = 1;
            g.valves_CSplus = [5 6; 7 8];    g.dutyCycles_CSplus = [10 10; 20 20]; g.probs_CSplus = [0 1];
            g.valves_CSminus = [11 12; 13 14]; g.dutyCycles_CSminus = [1 1; 2 2]; g.probs_CSminus = [0.5 0.5];
            tc.GUI = g;
            lhf.random('init', 7);
        end
    end

    methods (Test)
        function singleRowIsDelivered(tc)
            [v, d, type] = lhf.olf.resolve(1, tc.GUI, tc.types, struct());
            tc.verifyEqual(v, [3 4]);
            tc.verifyEqual(d, [0 0]);
            tc.verifyEqual(type, 'cue');
        end

        function rowsAreDrawnByProbability(tc)
            for k = 1:20
                v = lhf.olf.resolve(2, tc.GUI, tc.types, struct());
                tc.verifyEqual(v, [7 8]);  % row 1 has probability 0
            end
        end

        function aFixedRowWins(tc)
            % the protocols draw the rows as they prepare the trial (lhf.olf.drawRows)
            [v, d] = lhf.olf.resolve(2, tc.GUI, tc.types, struct('CSplus', 1));
            tc.verifyEqual(v, [5 6]);
            tc.verifyEqual(d, [10 10]);
        end

        function drawsRepeatWithTheSeed(tc)
            lhf.random('init', 3);
            first = arrayfun(@(~) lhf.olf.resolve(3, tc.GUI, tc.types, struct()), 1:30, 'UniformOutput', false);
            lhf.random('init', 3);
            second = arrayfun(@(~) lhf.olf.resolve(3, tc.GUI, tc.types, struct()), 1:30, 'UniformOutput', false);
            tc.verifyEqual(first, second);
        end

        function paddingZerosAreNotDelivered(tc)
            % the GUI pads shorter sequences with 0 to the table's width
            tc.GUI.valves_cue = [3 0 0];  tc.GUI.dutyCycles_cue = [0.5 0 0];
            [v, d] = lhf.olf.resolve(1, tc.GUI, tc.types, struct());
            tc.verifyEqual(v, 3);
            tc.verifyEqual(d, 0.5);
        end

        function rowsAreDrawnPerTypeAsTheTrialIsPrepared(tc)
            rows = lhf.olf.drawRows(tc.GUI, {'cue', 'CSplus', 'Template'});
            tc.verifyEqual(rows.cue, 1);
            tc.verifyEqual(rows.CSplus, 2);          % row 1 has probability 0
            tc.verifyFalse(isfield(rows, 'Template')); % no table
            [v, ~] = lhf.olf.resolve(2, tc.GUI, tc.types, rows);
            tc.verifyEqual(v, [7 8]);
        end

        function aRowPlaysOneSlotPerOdour(tc)
            olf = struct('preSequenceTime', 0.001, 'pulseTime', 1, 'postSequenceTime', 0.001);
            tc.verifyEqual(lhf.olf.sequenceDuration([3 4 5], olf), 3.006, 'AbsTol', 1e-12);
            tc.verifyEqual(lhf.olf.sequenceDuration([11 0 0], olf), 1.002, 'AbsTol', 1e-12);
            tc.verifyEqual(lhf.olf.sequenceDuration([0 0], olf), 0);
        end

        function unknownCodeDeliversNothing(tc)
            [v, ~, type] = lhf.olf.resolve(5, tc.GUI, tc.types, struct());
            tc.verifyEmpty(v);
            tc.verifyEmpty(type);
        end

        function aSoftCodeDeliversAndRecordsTheDutyUsed(tc)
            delivery = tc.fakeSessionDelivery();
            global BpodSystem %#ok<GVMIS>
            S.GUI = tc.GUI;
            S.GUI.valves_cue = [3 4];
            S.GUI.dutyCycles_cue = [0 0.5];   % 0: the bottle's own duty
            S = lhf.olf.deliver(1, S, lhf.protocolInfo('goNogo'), []);
            tc.verifyEqual(S.GUI.delivered_odours.cue, [3 4]);
            bottle = delivery.Bottles.dutyCycles(3);
            tc.verifyEqual(S.GUI.delivered_dutyCycles.cue, [bottle 0.5]);
            tc.verifyNumElements(delivery.Deliveries, 1);
            tc.verifyFalse(isfile([BpodSystem.Path.CurrentDataFile '_olfactometer_errors.txt']));
            d = BpodSystem.Data.OdourDeliveries;   % with the trial it belongs to
            tc.verifyEqual([d.Trial, d.Valves], [1 3 4]);
            tc.verifyEqual(d.Duty, [bottle 0.5]);
            tc.verifyTrue(d.Ok);
            BpodSystem.Data.nTrials = 4;
            lhf.olf.deliver(1, S, lhf.protocolInfo('goNogo'), []);
            tc.verifyEqual(BpodSystem.Data.OdourDeliveries(2).Trial, 5);
        end

        function aBadRowIsLoggedNotThrown(tc)
            tc.fakeSessionDelivery();
            global BpodSystem %#ok<GVMIS>
            S.GUI = tc.GUI;
            S.GUI.valves_cue = 9;            % clean air: refused
            S.GUI.dutyCycles_cue = 1;
            S = lhf.olf.deliver(1, S, lhf.protocolInfo('goNogo'), []);
            tc.verifyFalse(isfield(S.GUI, 'delivered_odours'));
            text = fileread([BpodSystem.Path.CurrentDataFile '_olfactometer_errors.txt']);
            tc.verifySubstring(text, 'notOdourValve');
            tc.verifyFalse(BpodSystem.Data.OdourDeliveries.Ok);   % refused ones are recorded too
            tc.verifySubstring(BpodSystem.Data.OdourDeliveries.Message, 'odour valve');
        end

        function closeKeepsTheDeliveries(tc)
            tc.fakeSessionDelivery();
            global BpodSystem %#ok<GVMIS>
            S.GUI = tc.GUI;
            S.GUI.valves_cue = 3;
            S.GUI.dutyCycles_cue = 1;
            lhf.olf.deliver(1, S, lhf.protocolInfo('goNogo'), []);
            lhf.olf.close();
            tc.verifyNumElements(BpodSystem.Data.Olfactometer.Deliveries, 1);
            tc.verifyFalse(isfield(BpodSystem.PluginObjects, 'Olfactometer'));
            lhf.olf.close();   % nothing open: does nothing
        end
    end

    methods (Access = private)
        function delivery = fakeSessionDelivery(tc)
            % An in-process, simulated delivery with the rig's config and bottle tables,
            % where lhf.olf.startWorker would put it, and a data file in a temporary folder.
            global BpodSystem %#ok<GVMIS>
            saved = BpodSystem;
            tc.addTeardown(@() restoreBpod(saved));
            folder = tempname;
            mkdir(folder);
            tc.addTeardown(@() rmdir(folder, 's'));
            root = fileparts(fileparts(mfilename('fullpath')));
            config = LuminoseConstants.readConfig();
            olf = config.olfactometer;
            olf.odourBottlesFile = fullfile(root, 'olfactometer', 'odour_bottles.tsv');
            olf.odourChemicalsFile = fullfile(root, 'olfactometer', 'odour_chemicals.tsv');
            bottles = olfactometer.Bottles.fromTsv(olf.odourBottlesFile, olf.odourChemicalsFile);
            delivery = olfactometer.AsyncDelivery(olf, 'Bottles', bottles, 'InProcess', true, ...
                'Simulated', true);
            delivery.start();
            tc.addTeardown(@() olfactometer.internal.serve('release'));
            BpodSystem = struct('PluginObjects', struct('Olfactometer', delivery), ...
                'Data', struct(), 'Path', struct('CurrentDataFile', fullfile(folder, 'session')));
        end
    end
end


function restoreBpod(saved)
% Puts back the BpodSystem global a test replaced.
global BpodSystem %#ok<GVMIS>
BpodSystem = saved;
end

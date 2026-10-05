function liveBarPlot_hf_powercal(ax, op, data)
    % barPlot - Creates and updates a bar plot showing accuracy for CS+ and CS- trials
    %
    % Syntax:
    %   barPlot(ax, 'init', trialTypes, [])  - Initialize the plot
    %   barPlot(ax, 'update', trialTypes, data) - Update with new trial data
    %
    % Inputs:
    %   ax - axes handle for plotting
    %   op - operation: 'init' or 'update'
    %   trialTypes - vector of trial types (1 = CS+, 2 = CS-)
    %   data - BpodSystem.Data structure containing trial outcomes
    
    global BpodSystem
    
    op = lower(op);
    
    switch op
        case 'init'
            % Initialize the bar plot
            cla(ax);
            hold(ax, 'on');
            
            % Create initial bars with zero height
            BpodSystem.GUIHandles.AccuracyPlot.Bars = bar(ax, [1 2], [0 0], 0.6);
            BpodSystem.GUIHandles.AccuracyPlot.Bars.FaceColor = 'flat';
            BpodSystem.GUIHandles.AccuracyPlot.Bars.CData(1,:) = [0.2 0.5 0.8];  % CS+ color (blue)
            BpodSystem.GUIHandles.AccuracyPlot.Bars.CData(2,:) = [0.8 0.4 0.2];  % CS- color (orange)
            
            % Formatting
            ax.XTick = [1 2];
            ax.XTickLabel = {'CS+', 'CS-'};
            ax.YLim = [0 100];
            ax.YLabel.String = 'Accuracy (%)';
            ax.FontSize = 11;
            ax.FontName = 'Segoe UI';
            ax.Box = 'on';
            ax.LineWidth = 1.5;
            grid(ax, 'on');
            ax.GridAlpha = 0.3;
            
            % Create text labels for percentages
            BpodSystem.GUIHandles.AccuracyPlot.Text1 = text(ax, 1, 5, '', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 11, ...
                'FontWeight', 'bold', ...
                'Color', [0.2 0.2 0.2]);
            BpodSystem.GUIHandles.AccuracyPlot.Text2 = text(ax, 2, 5, '', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 11, ...
                'FontWeight', 'bold', ...
                'Color', [0.2 0.2 0.2]);
            
            % Create title
            BpodSystem.GUIHandles.AccuracyPlot.Title = title(ax, 'Overall Accuracy: 0% (0/0 trials)', ...
                'FontSize', 12, ...
                'FontWeight', 'bold', ...
                'Color', [0.2 0.2 0.2]);
            
            hold(ax, 'off');
            
        case 'update'
            if isempty(data) || ~isfield(data, 'TrialTypes')
                return;
            end

            % Recover if AccuracyPlot was initialized by the legacy line plot.
            if ~isfield(BpodSystem.GUIHandles, 'AccuracyPlot') || ...
               ~isfield(BpodSystem.GUIHandles.AccuracyPlot, 'Bars') || ...
               ~ishandle(BpodSystem.GUIHandles.AccuracyPlot.Bars)
                liveBarPlot_hf_powercal(ax, 'init', []);
            end
            
            % Get completed trials
            nTrials = length(data.TrialTypes);
            if nTrials == 0
                return;
            end
            
            % Initialize counters
            nCSplus = 0;
            nCSminus = 0;
            correctCSplus = 0;
            correctCSminus = 0;
            
            % Count trials and correct responses
            for i = 1:nTrials
                trialType = data.TrialTypes(i);
                
                % Check if trial had a reward (correct) or punishment (incorrect)
                hasReward = ~isnan(data.RawEvents.Trial{i}.States.Reward(1));
                hasPunishment = ~isnan(data.RawEvents.Trial{i}.States.Punishment(1));
                
                if trialType == 1  % CS+ trial (should GO - lick)
                    nCSplus = nCSplus + 1;
                    if hasReward
                        correctCSplus = correctCSplus + 1;
                    end
                elseif trialType == 2  % CS- trial (should NO-GO - withhold)
                    nCSminus = nCSminus + 1;
                    % Correct if reached ITI without punishment
                    hasITI = ~isnan(data.RawEvents.Trial{i}.States.InterTrialInterval(1));
                    if hasITI && ~hasPunishment
                        correctCSminus = correctCSminus + 1;
                    end
                end
            end
            
            % Calculate accuracies
            if nCSplus > 0
                accuracyCSplus = (correctCSplus / nCSplus) * 100;
            else
                accuracyCSplus = 0;
            end
            
            if nCSminus > 0
                accuracyCSminus = (correctCSminus / nCSminus) * 100;
            else
                accuracyCSminus = 0;
            end
            
            % Overall accuracy
            totalTrials = nCSplus + nCSminus;
            totalCorrect = correctCSplus + correctCSminus;
            if totalTrials > 0
                overallAccuracy = (totalCorrect / totalTrials) * 100;
            else
                overallAccuracy = 0;
            end
            
            % Update bar heights
            set(BpodSystem.GUIHandles.AccuracyPlot.Bars, 'YData', [accuracyCSplus, accuracyCSminus]);
            
            % Update text labels
            if accuracyCSplus > 0
                set(BpodSystem.GUIHandles.AccuracyPlot.Text1, 'Position', [1, accuracyCSplus + 3, 0]);
                set(BpodSystem.GUIHandles.AccuracyPlot.Text1, 'String', sprintf('%.1f%%', accuracyCSplus));
            else
                set(BpodSystem.GUIHandles.AccuracyPlot.Text1, 'String', '');
            end
            
            if accuracyCSminus > 0
                set(BpodSystem.GUIHandles.AccuracyPlot.Text2, 'Position', [2, accuracyCSminus + 3, 0]);
                set(BpodSystem.GUIHandles.AccuracyPlot.Text2, 'String', sprintf('%.1f%%', accuracyCSminus));
            else
                set(BpodSystem.GUIHandles.AccuracyPlot.Text2, 'String', '');
            end
            
            % Update title with overall accuracy
            titleStr = sprintf('Overall Accuracy: %.1f%% (%d/%d trials)', ...
                overallAccuracy, totalCorrect, totalTrials);
            set(BpodSystem.GUIHandles.AccuracyPlot.Title, 'String', titleStr);
            
            % Update title color based on performance
            if overallAccuracy >= 75
                titleColor = [0.2 0.6 0.2];  % Green for good performance
            elseif overallAccuracy >= 50
                titleColor = [0.8 0.6 0.2];  % Orange for medium performance
            else
                titleColor = [0.8 0.2 0.2];  % Red for low performance
            end
            set(BpodSystem.GUIHandles.AccuracyPlot.Title, 'Color', titleColor);
            
        otherwise
            error('Invalid operation. Use ''init'' or ''update''');
    end
end

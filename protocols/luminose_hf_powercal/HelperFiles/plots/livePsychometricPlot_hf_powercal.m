function livePsychometricPlot_hf_powercal(ax, op, data, difficultyLevels)
    % psychometricPlot - Creates and updates psychometric curve
    %
    % Syntax:
    %   psychometricPlot(ax, 'init', [], difficultyLevels)
    %   psychometricPlot(ax, 'update', data, difficultyLevels)
    %
    % Inputs:
    %   ax - axes handle
    %   op - 'init' or 'update'
    %   data - BpodSystem.Data structure
    %   difficultyLevels - Array of difficulty values used in experiment
    %                      (e.g., [0.1, 0.3, 0.5, 0.7, 0.9] for odor concentrations)
    
    global BpodSystem
    op = lower(op);
    
    switch op
        case 'init'
            cla(ax);
            hold(ax, 'on');
            
            % Initialize plot elements
            BpodSystem.GUIHandles.PsychometricPlot.DataPoints = plot(ax, NaN, NaN, 'o', ...
                'MarkerSize', 10, ...
                'MarkerFaceColor', [0.2 0.5 0.8], ...
                'MarkerEdgeColor', [0.1 0.3 0.6], ...
                'LineWidth', 1.5);
            
            BpodSystem.GUIHandles.PsychometricPlot.FitCurve = plot(ax, NaN, NaN, '-', ...
                'Color', [0.8 0.2 0.2], ...
                'LineWidth', 2.5);
            
            BpodSystem.GUIHandles.PsychometricPlot.ErrorBars = errorbar(ax, NaN, NaN, NaN, ...
                'o', 'Color', [0.2 0.5 0.8], ...
                'LineWidth', 1.5, ...
                'CapSize', 8);
            
            % Formatting
            ax.XLabel.String = 'Difficulty Level';
            ax.YLabel.String = 'P(Go Response)';
            ax.YLim = [0 1];
            ax.FontSize = 11;
            ax.FontName = 'Segoe UI';
            ax.Box = 'on';
            ax.LineWidth = 1.5;
            grid(ax, 'on');
            ax.GridAlpha = 0.3;
            
            % Add reference lines
            plot(ax, ax.XLim, [0.5 0.5], '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
            
            title(ax, 'Psychometric Curve', 'FontSize', 12, 'FontWeight', 'bold');
            legend(ax, {'Data', 'Logistic Fit'}, 'Location', 'northwest');
            
            hold(ax, 'off');
            
        case 'update'
            if isempty(data) || ~isfield(data, 'TrialTypes') || ~isfield(data, 'DifficultyLevel')
                return;
            end
            
            nTrials = length(data.TrialTypes);
            if nTrials == 0
                return;
            end
            
            % Calculate performance at each difficulty level
            uniqueDifficulties = unique(difficultyLevels);
            nDifficulties = length(uniqueDifficulties);
            
            pGoResponse = zeros(1, nDifficulties);
            nTrialsPerDiff = zeros(1, nDifficulties);
            errorBars = zeros(1, nDifficulties);
            
            for i = 1:nDifficulties
                diff = uniqueDifficulties(i);
                
                % Find trials at this difficulty
                trialsAtDiff = find(data.DifficultyLevel == diff);
                nTrialsPerDiff(i) = length(trialsAtDiff);
                
                if nTrialsPerDiff(i) > 0
                    % Count "Go" responses (licks)
                    nGoResponses = 0;
                    for t = trialsAtDiff
                        hasLick = ~isnan(data.RawEvents.Trial{t}.States.Reward(1)) || ...
                                  (data.TrialTypes(t) == 2 && ~isnan(data.RawEvents.Trial{t}.States.Punishment(1)));
                        if hasLick
                            nGoResponses = nGoResponses + 1;
                        end
                    end
                    
                    pGoResponse(i) = nGoResponses / nTrialsPerDiff(i);
                    
                    % Calculate binomial confidence interval (Wilson score interval)
                    errorBars(i) = 1.96 * sqrt(pGoResponse(i) * (1 - pGoResponse(i)) / nTrialsPerDiff(i));
                else
                    pGoResponse(i) = NaN;
                    errorBars(i) = NaN;
                end
            end
            
            % Update data points with error bars
            validIdx = ~isnan(pGoResponse);
            set(BpodSystem.GUIHandles.PsychometricPlot.ErrorBars, ...
                'XData', uniqueDifficulties(validIdx), ...
                'YData', pGoResponse(validIdx), ...
                'YNegativeDelta', errorBars(validIdx), ...
                'YPositiveDelta', errorBars(validIdx));
            
            % Fit logistic function if enough data points
            if sum(validIdx) >= 3
                try
                    % Logistic function: y = 1 / (1 + exp(-k*(x - x0)))
                    % where k is slope and x0 is threshold (50% point)
                    logisticFun = @(b, x) 1 ./ (1 + exp(-b(1) * (x - b(2))));
                    
                    % Initial guess: [slope, threshold]
                    beta0 = [1, mean(uniqueDifficulties)];
                    
                    % Fit the curve
                    beta = nlinfit(uniqueDifficulties(validIdx), pGoResponse(validIdx), logisticFun, beta0);
                    
                    % Generate smooth curve for plotting
                    xFit = linspace(min(uniqueDifficulties), max(uniqueDifficulties), 100);
                    yFit = logisticFun(beta, xFit);
                    
                    set(BpodSystem.GUIHandles.PsychometricPlot.FitCurve, ...
                        'XData', xFit, ...
                        'YData', yFit);
                    
                    % Update title with threshold info
                    titleStr = sprintf('Psychometric Curve (Threshold: %.2f)', beta(2));
                    title(ax, titleStr, 'FontSize', 12, 'FontWeight', 'bold');
                catch
                    % If fit fails, just show data points
                    set(BpodSystem.GUIHandles.PsychometricPlot.FitCurve, ...
                        'XData', NaN, 'YData', NaN);
                end
            end
            
            % Update axis limits based on data
            if any(validIdx)
                ax.XLim = [min(uniqueDifficulties) - 0.05, max(uniqueDifficulties) + 0.05];
            end
            
        otherwise
            error('Invalid operation. Use ''init'' or ''update''');
    end
end
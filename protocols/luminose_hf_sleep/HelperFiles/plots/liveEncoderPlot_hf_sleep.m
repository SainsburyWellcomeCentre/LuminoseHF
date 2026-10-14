function liveEncoderPlot_hf_sleep(axes, op, choiceThreshold, varargin)
global BpodSystem
switch op
    case 'init'
        BpodSystem.GUIHandles.EncoderPlot = plot(axes, 0,0, '-', 'Color', [0 0.45 0.74], 'LineWidth', 2);  % blue
        if choiceThreshold ~= 0
            BpodSystem.GUIHandles.EncoderPlotThreshold1Line = line([0,1000],[-choiceThreshold -choiceThreshold], 'Color', 'k', 'LineStyle', ':');
            BpodSystem.GUIHandles.EncoderPlotThreshold2Line = line([0,1000],[choiceThreshold choiceThreshold], 'Color', 'k', 'LineStyle', ':');
        end
        set(axes, 'box', 'off', 'tickdir', 'out');
        ylabel('Position (deg)', 'FontSize', 12); 
        xlabel('Time (s)', 'FontSize', 12);
    case 'update'
        encoderData = varargin{1};
        trialDuration = varargin{2};
        set(BpodSystem.GUIHandles.EncoderPlot, 'XData', encoderData.Times,'YData', encoderData.Positions);
        if choiceThreshold ~= 0
            set(axes, 'ylim', [-choiceThreshold*2 choiceThreshold*2], 'xlim', [0 trialDuration]);
            set(BpodSystem.GUIHandles.EncoderPlotThreshold1Line,'ydata',[-choiceThreshold, -choiceThreshold]);
            set(BpodSystem.GUIHandles.EncoderPlotThreshold2Line,'ydata',[choiceThreshold, choiceThreshold]);
        end
end
function DrawTrialStructure(Params, Meta)
    % DrawTrialStructure  Visualizes the behavioral trial timeline in the GUI
    global BpodSystem
    ax = BpodSystem.GUIHandles.ParameterGUI.TrialStructureAxes;
    cla(ax);
    hold(ax,'on');

    % The longest row of each (lhf.stimDuration): a pattern its design, an
    % odour its sequence, light and sound their panel's Duration
    cueType = Meta.CueType.String{Params.CueType};
    cueTime = lhf.stimDuration(Params, cueType, 'cue', 'longest');
    leftType = Meta.LeftType.String{Params.LeftType}; rightType = Meta.RightType.String{Params.RightType};
    stimTime = max(lhf.stimDuration(Params, leftType, 'Left', 'longest'), lhf.stimDuration(Params, rightType, 'Right', 'longest'));
    stimType = strcat(leftType, '/', rightType);
    responseTime = Params.ResponseTime;
    errorDelay = Params.ErrorDelay;
    iti = Params.InterTrialInterval;
    itiVariable = Params.VariableITI;
    if itiVariable
        itiType = 'Variable';
    else
        itiType = 'Fixed';
    end

    blocks = {'Cue','Stim','Response','Reward/Error','ITI'};
    blockNames = {cueType, stimType, 'Lick spout', strcat('Water/','Noise'), itiType};
    colors = [0.4 0.7 0.4;
              0.2 0.5 0.8;
              0.8 0.8 0.2;
              0.8 0.4 0.2;
              0.6 0.6 0.6];
    ypos = 0.4;
    height = 0.4;

    t = 0;
    blockTimes = [cueTime, stimTime, responseTime, errorDelay, iti];
    
    for i = 1:length(blocks)
        rectangle(ax,'Position',[t ypos blockTimes(i) height], ...
            'FaceColor', colors(i,:), 'EdgeColor','k');
        text(t + blockTimes(i) - blockTimes(i)*0.5, ypos+height*1.4, blocks{i}, ...
            'HorizontalAlignment','center','VerticalAlignment','middle','Parent',ax);
        text(t + blockTimes(i) - blockTimes(i)*0.5, ypos+height/2, string(blockTimes(i))+'s', ...
            'HorizontalAlignment','center','VerticalAlignment','middle','Parent',ax);
        text(t + blockTimes(i) - blockTimes(i)*0.5, ypos-height*0.6, blockNames{i}, ...
            'HorizontalAlignment','center','VerticalAlignment','middle', ...
            'Rotation', 25,'Parent',ax);
        t = t + blockTimes(i);
    end

    ax.XLim = [0 t];
    ax.YLim = [0 1];
    ax.XTick = [];
    ax.YTick = [];
    hold(ax,'on');
    axis(ax,'off');
end

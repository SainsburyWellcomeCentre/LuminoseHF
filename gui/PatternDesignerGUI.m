function designer = PatternDesignerGUI(patternType, rowIdx, preloadFromType)
% PatternDesignerGUI  Opens the DMD spot designer for one pattern table row.
%
%   PatternDesignerGUI(patternType, rowIdx)
%   PatternDesignerGUI(patternType, rowIdx, preloadFromType)   starts from
%       another type's design (the opto chooser's "Open in designer")
%   designer = PatternDesignerGUI(...)   the gui/PatternDesigner it opened
%
%   rowIdx defaults to 1. The designer (gui/PatternDesigner.m) draws the
%   spots on the Hamamatsu camera panel's image, through the camera-DMD
%   calibration, so they are placed where the DMD lights the tissue; its
%   window keeps the spot controls (mode, table, timing, spot size,
%   laser power, Save), Show on DMD, and the animal's fiducial and alignment.
%   For an opto row with nothing to start from it first asks whether to
%   design from scratch or start from a trial type's pattern.

    designer = [];
    if nargin < 2 || isempty(rowIdx), rowIdx = 1; end
    if nargin < 3, preloadFromType = ''; end

    if strcmp(patternType, 'opto') && isempty(preloadFromType)
        optoPatternDesignerUI(rowIdx);
        return;
    end
    designer = PatternDesigner(patternType, rowIdx, preloadFromType);
end

% =======================================================================
% Opto row source chooser
% =======================================================================
function optoPatternDesignerUI(rowIdx)
% Choice dialog: design spots from scratch, or start from an existing
% trial-type pattern (pre-populates the canvas; user edits then saves).

    sourceOpts = {'CSplus', 'CSminus', 'Left', 'Right', 'cue'};

    FG = [0.13 0.13 0.15];
    TG = [0.80 0.80 0.80];
    EB = [0.22 0.22 0.25];
    EG = [1.00 1.00 1.00];

    fig = figure('Name', sprintf('Opto Pattern  (row %d)', rowIdx), ...
        'NumberTitle','off','MenuBar','none','Resize','off', ...
        'Position',[250 300 400 200],'Color',FG);

    uicontrol(fig,'Style','text','String',sprintf('OPTO PATTERN — ROW %d', rowIdx), ...
        'Position',[15 165 370 24],'FontSize',12,'FontWeight','bold', ...
        'BackgroundColor',FG,'ForegroundColor',[0.4 0.8 1.0],'HorizontalAlignment','left');
    uicontrol(fig,'Style','text','String','How should this row''s spatial pattern be defined?', ...
        'Position',[15 143 370 18],'FontSize',9, ...
        'BackgroundColor',FG,'ForegroundColor',TG,'HorizontalAlignment','left');

    % Left: design from scratch
    uicontrol(fig,'Style','pushbutton','String','Design from scratch', ...
        'Position',[15 88 170 40],'FontSize',10,'FontWeight','bold', ...
        'BackgroundColor',[0.20 0.38 0.58],'ForegroundColor',EG, ...
        'Callback',@onDesignFromScratch);
    uicontrol(fig,'Style','text','String','Open spot canvas (empty)', ...
        'Position',[15 72 170 16],'FontSize',8, ...
        'BackgroundColor',FG,'ForegroundColor',[0.5 0.5 0.5],'HorizontalAlignment','center');

    % Right: start from trial type
    uicontrol(fig,'Style','text','String','Start from:', ...
        'Position',[210 120 75 20],'FontSize',10, ...
        'BackgroundColor',FG,'ForegroundColor',TG,'HorizontalAlignment','left');
    hRef = uicontrol(fig,'Style','popupmenu','String',sourceOpts, ...
        'Position',[210 98 165 26],'FontSize',10,'BackgroundColor',EB,'ForegroundColor',EG);
    uicontrol(fig,'Style','pushbutton','String','Open in designer →', ...
        'Position',[210 60 165 34],'FontSize',10,'FontWeight','bold', ...
        'BackgroundColor',[0.15 0.50 0.28],'ForegroundColor',[1 1 0.4], ...
        'Callback',@onOpenFromType);
    uicontrol(fig,'Style','text','String','Pre-load spots, then edit and save', ...
        'Position',[210 44 165 16],'FontSize',8, ...
        'BackgroundColor',FG,'ForegroundColor',[0.5 0.5 0.5],'HorizontalAlignment','center');

    uicontrol(fig,'Style','pushbutton','String','Cancel', ...
        'Position',[140 8 120 26],'FontSize',10, ...
        'BackgroundColor',[0.35 0.35 0.38],'ForegroundColor',[0.9 0.9 0.9], ...
        'Callback',@(~,~)delete(fig));

    function onDesignFromScratch(~,~)
        delete(fig);
        PatternDesigner('opto', rowIdx, '');  % not PatternDesignerGUI: it would ask again
    end

    function onOpenFromType(~,~)
        refType = sourceOpts{get(hRef,'Value')};
        delete(fig);
        PatternDesignerGUI('opto', rowIdx, refType);
    end

end

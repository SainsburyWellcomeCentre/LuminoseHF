function varargout = LuminoseParameterGUI_hf_sleep(varargin)
% BpodParameterGUI('init', ParamStruct) - initializes a GUI with edit boxes for every field in subfield ParamStruct.GUI
% BpodParameterGUI('sync', ParamStruct) - updates the GUI with fields of
%       ParamStruct.GUI, if they have not been changed by the user. 
%       Returns a param struct. Fields in the GUI sub-struct are read from the UI.

    global BpodSystem
    Op = varargin{1};
    Params = varargin{2};
    Op = lower(Op);
    
    % Define color scheme
    COLORS.background = [0.07 0.07 0.09];
    COLORS.panelBg = [0.11 0.11 0.14];
    COLORS.tabBg = [0.08 0.08 0.10];
    COLORS.accentTrial = [0.75 0.55 0.95];
    COLORS.textDark = [0.88 0.88 0.88];
    COLORS.inputBg = [0.16 0.16 0.20];

    % Parameters to lock after START is pressed
    LOCKED_PARAMS = { ...
        'maxTrials', ...
        'muBarcodeDur', ...
        'sigmaBarcodeDur', ...
        'Ephys', 'EphysType', 'EphysCoords', ...
        'EEG', 'EEGchannels', 'EMGchannels', ...
        'Drug', 'DrugType', 'DrugDose' ...
    };
    
    switch Op
        case 'init'
            ParamNames = fieldnames(Params.GUI);
            nParams = length(ParamNames);
            BpodSystem.GUIData.ParameterGUI.ParamNames = cell(1,nParams);
            BpodSystem.GUIData.ParameterGUI.nParams = nParams;
            BpodSystem.GUIHandles.ParameterGUI.Labels = zeros(1,nParams);
            BpodSystem.GUIHandles.ParameterGUI.Params = zeros(1,nParams);
            BpodSystem.GUIData.ParameterGUI.LastParamValues = cell(1,nParams);
            BpodSystem.GUIData.ParameterGUI.PanelParams = struct;
            BpodSystem.GUIData.ParameterGUI.ParamIndexByName = struct;
            BpodSystem.GUIData.ParameterGUI.PanelStyles = struct;
            BpodSystem.GUIData.ParameterGUI.LockedParams = LOCKED_PARAMS;
            BpodSystem.GUIData.ParameterGUI.ProtocolSuffix = 'sleep';
    
            if isfield(Params, 'GUIMeta')
                Meta = Params.GUIMeta;
            else
                Meta = struct;
            end
            BpodSystem.GUIData.ParameterGUI.LatestGUIParams = Params.GUI;
            BpodSystem.GUIData.ParameterGUI.LatestMeta = Meta;
            
            % Handle hidden parameters
            hiddenParams = {};
            if ~isempty(fieldnames(Meta))
                metaNames = fieldnames(Meta);
                for iMeta = 1:numel(metaNames)
                    if isstruct(Meta.(metaNames{iMeta})) && isfield(Meta.(metaNames{iMeta}), 'Hidden') && Meta.(metaNames{iMeta}).Hidden
                        hiddenParams{end+1} = metaNames{iMeta}; %#ok<AGROW>
                    end
                end
            end

            if isfield(Params, 'GUIPanels')
                Panels = Params.GUIPanels;
                PanelNames = fieldnames(Panels);
                nPanels = length(PanelNames);
                paramNames = fieldnames(Params.GUI);
                nParameters = length(paramNames);
                paramsInPanels = {}; 
                for i = 1:nPanels
                    paramsInPanels = [paramsInPanels Panels.(PanelNames{i})];
                end
                paramsInDefaultPanel = {};
                for i = 1:nParameters
                    if ismember(paramNames{i}, hiddenParams)
                        continue
                    end
                    if ~strcmp(paramNames{i}, paramsInPanels)
                        paramsInDefaultPanel = [paramsInDefaultPanel paramNames{i}];
                    end
                end
                if ~isempty(paramsInDefaultPanel)
                    Panels.Parameters = cell(1,length(paramsInDefaultPanel));
                    for i = 1:length(paramsInDefaultPanel)
                        Panels.Parameters{i} = paramsInDefaultPanel{i};
                    end
                    PanelNames{nPanels+1} = 'Parameters';
                end
                nPanels = length(PanelNames);
            else
                Panels = struct;
                Panels.Parameters = ParamNames;
                PanelNames = {'Parameters'};
                nPanels = 1;
            end
            
            if isfield(Params, 'GUITabs')
                Tabs = Params.GUITabs;            
            else
                Tabs = struct;
                Tabs.Parameters = PanelNames;
            end
            TabNames = fieldnames(Tabs);
            nTabs = length(TabNames);
            
            Params = Params.GUI;
            PanelNames = PanelNames(end:-1:1);
            GUIHeight = 1300;
            MaxVPos = 0;
            MaxHPos = 0;
            BpodSystem.ProtocolFigures.ParameterGUI = figure('Position', [50 50 450 GUIHeight],'name','Luminose','numbertitle','off', 'MenuBar', 'none', 'Resize', 'on', 'Color', COLORS.background);
            BpodSystem.GUIHandles.ParameterGUI.Tabs.TabGroup = uitabgroup(BpodSystem.ProtocolFigures.ParameterGUI);
            ParamNum = 1;
            for t = 1:nTabs
                VPos = 15;
                HPos = 15;
                ThisTabPanelNames = Tabs.(TabNames{t});
                nPanels = length(ThisTabPanelNames);
                if contains(lower(TabNames{t}),'trial')
                    tabColor = COLORS.accentTrial;
                elseif contains(lower(TabNames{t}),'opto')
                    tabColor = [0.95 0.78 0.28];
                elseif contains(lower(TabNames{t}),'ephys')
                    tabColor = [0.92 0.50 0.62];
                else
                    tabColor = [0.88 0.90 1.00];
                end
    
                BpodSystem.GUIHandles.ParameterGUI.Tabs.(TabNames{t}) = uitab('title',TabNames{t},'BackgroundColor',COLORS.tabBg);
                htab = BpodSystem.GUIHandles.ParameterGUI.Tabs.(TabNames{t});
    
                for p = 1:nPanels
                    ThisPanelParamNames = Panels.(ThisTabPanelNames{p});
                    ThisPanelParamNames = ThisPanelParamNames(~ismember(ThisPanelParamNames, hiddenParams));
                    if isempty(ThisPanelParamNames)
                        continue
                    end
                    BpodSystem.GUIData.ParameterGUI.PanelParams.(ThisTabPanelNames{p}) = ThisPanelParamNames;
                    ThisPanelParamNames = ThisPanelParamNames(end:-1:1);
                    nParams = length(ThisPanelParamNames);
                    paramHeight = 35;      
                    panelPadding = 45;  % room for the panel title above the top row
                    ThisPanelHeight = nParams * paramHeight + panelPadding;
                    BpodSystem.GUIHandles.ParameterGUI.Panels.(ThisTabPanelNames{p}) = uipanel(htab,...
                        'title',sprintf('  %s  ',ThisTabPanelNames{p}),'FontSize',12,'FontWeight','Bold',...
                        'ForegroundColor',tabColor,'BackgroundColor',COLORS.panelBg,'Units','Pixels',...
                        'Position',[HPos VPos 455 ThisPanelHeight],'BorderType','line','HighlightColor',tabColor,...
                        'BorderWidth',2,'BorderColor',tabColor);
                    BpodSystem.GUIData.ParameterGUI.PanelStyles.(ThisTabPanelNames{p}) = struct( ...
                        'ForegroundColor', tabColor, ...
                        'BackgroundColor', COLORS.panelBg, ...
                        'HighlightColor', tabColor, ...
                        'BorderColor', tabColor);
    
                    InPanelPos = 15;
                    for i = 1:nParams
                        ThisParamName = ThisPanelParamNames{i};
                        ThisParam = Params.(ThisParamName);
                        BpodSystem.GUIData.ParameterGUI.ParamNames{ParamNum} = ThisParamName;
                        BpodSystem.GUIData.ParameterGUI.ParamIndexByName.(ThisParamName) = ParamNum;
                        if ischar(ThisParam)
                            BpodSystem.GUIData.ParameterGUI.LastParamValues{ParamNum} = NaN;
                        else
                            BpodSystem.GUIData.ParameterGUI.LastParamValues{ParamNum} = ThisParam;
                        end
                        
                        % Determine style and string
                        ThisParamStyle = 'edit';
                        ThisParamString = '';
                        if isfield(Meta, ThisParamName) && isstruct(Meta.(ThisParamName))
                            if isfield(Meta.(ThisParamName), 'Style')
                                ThisParamStyle = Meta.(ThisParamName).Style;
                            end
                            if isfield(Meta.(ThisParamName), 'String')
                                ThisParamString = Meta.(ThisParamName).String;
                            end
                        end

                        % Label logic
                        if isfield(Meta, ThisParamName) && isfield(Meta.(ThisParamName), 'Label')
                            labelStr = Meta.(ThisParamName).Label;
                        else
                            underscorePos = strfind(ThisParamName,'_');
                            if isempty(underscorePos)
                                labelStr = ThisParamName;
                            else
                                labelStr = ThisParamName(1:underscorePos(1)-1);
                            end
                            labelStr = strrep(labelStr,'_',' ');
                        end
    
                        BpodSystem.GUIHandles.ParameterGUI.Labels(ParamNum) = uicontrol(htab,...
                            'Style','text','String',labelStr,'Position',[HPos+15 VPos+InPanelPos 215 28],...
                            'FontWeight','normal','FontSize',11,'BackgroundColor',COLORS.panelBg,...
                            'ForegroundColor',COLORS.textDark,'FontName','Segoe UI','HorizontalAlignment','Left');
    
                        callbackFunc = @(~,~) HandleRealTimeSync('sleep');

                        switch lower(ThisParamStyle)
                            case 'edit'
                                BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 1;
                                BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = uicontrol(htab,'Style', 'edit', 'String', mat2str(ThisParam), 'Position', [HPos+220 VPos+InPanelPos+2 200 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor',COLORS.inputBg,'ForegroundColor',COLORS.textDark, 'FontName', 'Arial','HorizontalAlignment','Center', 'Callback', callbackFunc);
                            case 'checkbox'
                                BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 3;
                                BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = uicontrol(htab,'Style', 'checkbox', 'Value', ThisParam, 'String', '   (check to activate)', 'Position', [HPos+220 VPos+InPanelPos+4 200 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor',COLORS.inputBg,'ForegroundColor',COLORS.textDark, 'FontName', 'Arial','HorizontalAlignment','Center', 'Callback', callbackFunc);
                            case 'popupmenu'
                                BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 4;
                                BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = uicontrol(htab,'Style', 'popupmenu', 'String', ThisParamString, 'Value', ThisParam, 'Position', [HPos+220 VPos+InPanelPos+2 200 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor',COLORS.inputBg,'ForegroundColor',COLORS.textDark, 'FontName', 'Arial','HorizontalAlignment','Center', 'Callback', callbackFunc);
                            case 'pushbutton'
                                BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 6;
                                if isfield(Meta, ThisParamName) && isfield(Meta.(ThisParamName), 'Callback')
                                    cbFn  = Meta.(ThisParamName).Callback;
                                    cbArg = '';
                                    if isfield(Meta.(ThisParamName), 'CallbackArg')
                                        cbArg = Meta.(ThisParamName).CallbackArg;
                                    end
                                    thisCallback = @(~,~) feval(cbFn, cbArg);
                                else
                                    thisCallback = callbackFunc;
                                end
                                BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = uicontrol(htab,'Style', 'pushbutton', 'String', ThisParamString,...
                                    'Value', ThisParam, 'Position', [HPos+220 VPos+InPanelPos+2 200 25], 'FontWeight', 'normal', 'FontSize', 12,...
                                    'BackgroundColor',COLORS.inputBg,'ForegroundColor',COLORS.textDark, 'FontName', 'Arial','HorizontalAlignment','Center', 'Callback', thisCallback);
                            case 'pattern_selector'
                                BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 10;
                                typeName  = Meta.(ThisParamName).TypeName;
                                probParam = Meta.(ThisParamName).ProbParam;
                                nFParam   = Meta.(ThisParamName).NFramesParam;
                                expParam  = Meta.(ThisParamName).ExposureParam;
                                vProbs    = Params.(probParam);
                                vNFrames  = Params.(nFParam);
                                vExposure = Params.(expParam);
                                nOpts = numel(vProbs);
                                tableData = cell(nOpts, 3);
                                for iOpt = 1:nOpts
                                    tableData{iOpt,1} = vProbs(iOpt);
                                    tableData{iOpt,2} = getDesignSpotCount(BpodSystem, typeName, iOpt);
                                    tableData{iOpt,3} = vExposure(iOpt) / 1000;  % shown in ms, stored in us
                                end
                                selectorHeight = 195;
                                selectorPanel = uipanel(htab, 'Units', 'pixels', ...
                                    'Position', [HPos+10 VPos+InPanelPos 435 selectorHeight], ...
                                    'BackgroundColor', COLORS.panelBg, 'BorderType', 'none');
                                hRowEdit = uicontrol(selectorPanel, 'Style', 'edit', 'String', '1', ...
                                    'Position', [253 16 35 26], 'FontSize', 11, 'BackgroundColor', COLORS.inputBg, 'ForegroundColor', COLORS.textDark);
                                ptable = uitable(selectorPanel, 'Data', tableData, ...
                                    'ColumnName', {'Prob', 'Spots', 'Exposure (ms)'}, ...
                                    'ColumnWidth', {55, 65, 105}, 'ColumnEditable', [true false false], ...
                                    'ColumnFormat', {'numeric','numeric','numeric'}, ...
                                    'Position', [5 60 385 120], 'FontSize', 10, ...
                                    'CellEditCallback', @(src,ev) PatternTableCellEdited(src, ev, 'sleep'), ...
                                    'CellSelectionCallback', @(src,ev) PatternTableSelectionChanged(src, ev, hRowEdit));
                                uicontrol(selectorPanel, 'Style', 'text', 'String', 'Row:', ...
                                    'Position', [215 18 35 22], 'FontSize', 10, ...
                                    'BackgroundColor', COLORS.panelBg, 'HorizontalAlignment', 'right');
                                uicontrol(selectorPanel, 'Style', 'pushbutton', 'String', 'Design Selected Row...', ...
                                    'Position', [5 15 205 35], 'FontSize', 10, 'FontWeight', 'bold', ...
                                    'BackgroundColor', [0.15 0.55 0.25], 'ForegroundColor', [1 1 0.4], ...
                                    'Callback', @(~,~) DesignSelectedPatternRow(ptable, typeName, hRowEdit));
                                uicontrol(selectorPanel, 'Style', 'pushbutton', 'String', '+', ...
                                    'Position', [395 115 32 32], 'FontSize', 14, 'FontWeight', 'bold', ...
                                    'Callback', @(~,~) PatternAddRow(ptable, 'sleep'));
                                uicontrol(selectorPanel, 'Style', 'pushbutton', 'String', '-', ...
                                    'Position', [395 75 32 32], 'FontSize', 14, 'FontWeight', 'bold', ...
                                    'Callback', @(~,~) PatternRemoveRow(ptable, 'sleep'));
                                selectorData = struct('ParamName', ThisParamName, 'ProbParam', probParam, ...
                                    'NFramesParam', nFParam, 'ExposureParam', expParam, ...
                                    'TypeName', typeName, 'ActiveRow', 1);
                                BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = ptable;
                                set(ptable, 'UserData', selectorData);
                                if ~isfield(BpodSystem.GUIHandles.ParameterGUI, 'PatternSelectorTables')
                                    BpodSystem.GUIHandles.ParameterGUI.PatternSelectorTables = struct();
                                end
                                BpodSystem.GUIHandles.ParameterGUI.PatternSelectorTables.(typeName) = ptable;
                                ThisPanelHeight = ThisPanelHeight + selectorHeight - 25;
                                BpodSystem.GUIHandles.ParameterGUI.Panels.(ThisTabPanelNames{p}).Position(4) = ThisPanelHeight;
                                InPanelPos = InPanelPos + selectorHeight - 35;
                                BpodSystem.GUIData.ParameterGUI.LastParamValues{ParamNum} = tableData;
                            otherwise
                                error('Invalid parameter style specified.');
                        end
                        InPanelPos = InPanelPos + paramHeight;
                        ParamNum = ParamNum + 1;
                    end
                    Wrap = 0;
                    if p < nPanels
                        NextPanelParams = Panels.(ThisTabPanelNames{p+1});
                        NextPanelSize = (length(NextPanelParams)*45) + 5;
                        if VPos + ThisPanelHeight + 45 + NextPanelSize > GUIHeight, Wrap = 1; end
                    end
                    VPos = VPos + ThisPanelHeight + 15;
                    if Wrap
                        HPos = HPos + 450;
                        if VPos > MaxVPos, MaxVPos = VPos; end
                        VPos = 15;
                    else
                        if VPos > MaxVPos, MaxVPos = VPos; end
                    end
                    if HPos > MaxHPos, MaxHPos = HPos; end
                end        

                if contains(lower(TabNames{t}),'trial')
                    BpodSystem.GUIHandles.ParameterGUI.StartButton = uicontrol(htab, ...
                        'Style', 'pushbutton', 'String', 'START', ...
                        'Position', [15 VPos 455 50], 'FontSize', 16, 'FontWeight', 'Bold', ...
                        'BackgroundColor', [0.2 0.7 0.3], 'ForegroundColor', 'white', ...
                        'FontName', 'Segoe UI', 'Callback', @(~,~) HandleSleepStartButton(LOCKED_PARAMS));
                    VPos = VPos + 60;
                end
                if contains(lower(TabNames{t}),'trial')
                    panelName = 'logo'; ThisPanelHeight = 125;
                    BpodSystem.GUIHandles.ParameterGUI.Panels.(panelName) = uipanel(htab,...
                        'title','','FontSize',12,'FontWeight','Bold','ForegroundColor',COLORS.accentTrial,...
                        'BackgroundColor',[0 0 0],'Units','Pixels','Position',[HPos VPos 455 ThisPanelHeight],...
                        'BorderType','line','HighlightColor',COLORS.accentTrial,'BorderWidth',2);
                    BpodSystem.GUIHandles.ParameterGUI.ImageAxes = axes('Parent',BpodSystem.GUIHandles.ParameterGUI.Panels.(panelName),...
                        'Units','normalized','Position',[0.05 0.05 0.9 0.9],'Color',[0 0 0],'XColor','none','YColor','none');
                    DisplayPNGImage();
                    VPos = VPos + ThisPanelHeight + 15;
                end
                if strcmpi(TabNames{t}, 'OptoStim')
                    panelName = 'OptoStimPreview'; panelHeight = 135;
                    BpodSystem.GUIHandles.ParameterGUI.Panels.(panelName) = uipanel(htab, 'title', '  OptoStim Preview  ', ...
                        'FontSize', 12, 'FontWeight', 'Bold', 'ForegroundColor', tabColor, 'BackgroundColor', COLORS.panelBg, ...
                        'Units', 'Pixels', 'Position', [15 VPos 455 panelHeight], 'BorderType', 'line', 'HighlightColor', tabColor, 'BorderWidth', 2);
                    BpodSystem.GUIHandles.ParameterGUI.OptoStimAxes = axes('Parent', BpodSystem.GUIHandles.ParameterGUI.Panels.(panelName), ...
                        'Units', 'normalized', 'Position', [0.08 0.18 0.9 0.6], 'Box', 'on', 'Color', COLORS.panelBg);
                    hold(BpodSystem.GUIHandles.ParameterGUI.OptoStimAxes, 'on');
                    DrawOptoStim(Params);
                    VPos = VPos + panelHeight + 15;
                end
                if VPos > MaxVPos, MaxVPos = VPos; end
                set(BpodSystem.ProtocolFigures.ParameterGUI,'Position',[1760 100 MaxHPos+500 min(MaxVPos+120,GUIHeight)]);
            end
            nCreatedParams = ParamNum - 1;
            BpodSystem.GUIData.ParameterGUI.nParams = nCreatedParams;
            BpodSystem.GUIData.ParameterGUI.ParamNames = BpodSystem.GUIData.ParameterGUI.ParamNames(1:nCreatedParams);
            BpodSystem.GUIHandles.ParameterGUI.Labels = BpodSystem.GUIHandles.ParameterGUI.Labels(1:nCreatedParams);
            BpodSystem.GUIHandles.ParameterGUI.Params = BpodSystem.GUIHandles.ParameterGUI.Params(1:nCreatedParams);
            BpodSystem.GUIData.ParameterGUI.LastParamValues = BpodSystem.GUIData.ParameterGUI.LastParamValues(1:nCreatedParams);
            BpodSystem.GUIData.ParameterGUI.Styles = BpodSystem.GUIData.ParameterGUI.Styles(1:nCreatedParams);
            UpdateRelevantPanels(Params, Meta);
        case 'sync'
            ParamNames = BpodSystem.GUIData.ParameterGUI.ParamNames;
            nParams = BpodSystem.GUIData.ParameterGUI.nParams;
            for p = 1:nParams
                ThisParamName = ParamNames{p};
                ThisParamStyle = BpodSystem.GUIData.ParameterGUI.Styles(p);
                ThisParamHandle = BpodSystem.GUIHandles.ParameterGUI.Params(p);
                ThisParamLastValue = BpodSystem.GUIData.ParameterGUI.LastParamValues{p};
                ThisParamCurrentValue = Params.GUI.(ThisParamName);
                switch ThisParamStyle
                    case 1 
                        GUIParam = str2num(get(ThisParamHandle, 'String'));
                        if ~isequal(single(GUIParam), single(ThisParamLastValue)), Params.GUI.(ThisParamName) = GUIParam;
                        elseif ~isequal(single(ThisParamCurrentValue), single(ThisParamLastValue)), set(ThisParamHandle, 'String', num2str(ThisParamCurrentValue)); end
                    case 3 
                        GUIParam = get(ThisParamHandle, 'Value');
                        if ~isequal(GUIParam, ThisParamLastValue), Params.GUI.(ThisParamName) = GUIParam;
                        elseif ~isequal(ThisParamCurrentValue, ThisParamLastValue), set(ThisParamHandle, 'Value', ThisParamCurrentValue); end
                    case 4
                        GUIParam = get(ThisParamHandle, 'Value');
                        if ~isequal(GUIParam, ThisParamLastValue), Params.GUI.(ThisParamName) = GUIParam;
                        elseif ~isequal(ThisParamCurrentValue, ThisParamLastValue), set(ThisParamHandle, 'Value', ThisParamCurrentValue); end
                    case 6
                        GUIParam = ThisParamCurrentValue;
                    case 10
                        % The opto pattern table: probabilities and exposures (as goNogo's)
                        tableData = get(ThisParamHandle, 'Data');
                        sd = get(ThisParamHandle, 'UserData');
                        nRows = size(tableData, 1);
                        probsVec = zeros(nRows,1); exposureVec = ones(nRows,1)*1e6;
                        for iR = 1:nRows
                            pVal = tableData{iR,1}; if isempty(pVal)||isnan(pVal), pVal=0; end
                            probsVec(iR) = pVal;
                            exposureVec(iR) = tableData{iR,3} * 1000;  % ms in the table, us in S.GUI
                        end
                        Params.GUI.(sd.ProbParam)     = probsVec;
                        Params.GUI.(sd.ExposureParam) = exposureVec;
                        % nFrames is managed by PatternDesignerGUI, not read from table
                end
                BpodSystem.GUIData.ParameterGUI.LastParamValues{p} = Params.GUI.(ThisParamName);
            end
            syncMeta = struct;
            if isfield(Params, 'GUIMeta')
                syncMeta = Params.GUIMeta;
            elseif isfield(BpodSystem.GUIData, 'ParameterGUI') && ...
                   isfield(BpodSystem.GUIData.ParameterGUI, 'LatestMeta')
                syncMeta = BpodSystem.GUIData.ParameterGUI.LatestMeta;
            end
            BpodSystem.GUIData.ParameterGUI.LatestGUIParams = Params.GUI;
            BpodSystem.GUIData.ParameterGUI.LatestMeta = syncMeta;
            if ~isempty(fieldnames(syncMeta)), UpdateRelevantPanels(Params.GUI, syncMeta); end
    end
    if verLessThan('MATLAB', '8.4'), drawnow; end
    varargout{1} = Params;
end

function HandleRealTimeSync(suffix)
    global BpodSystem
    % Only sync in real-time if START hasn't been pressed
    startPressed = isappdata(BpodSystem.ProtocolFigures.ParameterGUI, 'StartPressed') && ...
        getappdata(BpodSystem.ProtocolFigures.ParameterGUI, 'StartPressed');
    
    if ~startPressed
        syncFunc = str2func(sprintf('LuminoseParameterGUI_hf_%s', suffix));
        syncFunc('sync', struct('GUI', BpodSystem.GUIData.ParameterGUI.LatestGUIParams, 'GUIMeta', BpodSystem.GUIData.ParameterGUI.LatestMeta));
    end
end

function UpdateRelevantPanels(Params, Meta)
    global BpodSystem
    panelStates = struct( ...
        'MaskLED', false, 'SinglePulse', false, 'PairedPulse', false, ...
        'DrugSpecs', logical(Params.Drug), 'EEGSpecs', logical(Params.EEG), 'EphysSpecs', logical(Params.Ephys));

    if logical(Params.TestPulses)
        panelStates.MaskLED = true;
        if isfield(Meta, 'TestPulsesType')
            pulseType = Meta.TestPulsesType.String{Params.TestPulsesType};
            panelStates.(pulseType) = true;
        end
    end

    panelNames = fieldnames(panelStates);
    for iPanel = 1:numel(panelNames)
        SetPanelEnabled(panelNames{iPanel}, panelStates.(panelNames{iPanel}));
    end
end

function HandleSleepStartButton(lockedParams)
    global BpodSystem
    StartButtonPressed(lockedParams);
    if isfield(BpodSystem.GUIData, 'ParameterGUI') && ...
            isfield(BpodSystem.GUIData.ParameterGUI, 'LatestGUIParams') && ...
            isfield(BpodSystem.GUIData.ParameterGUI, 'LatestMeta')
        UpdateRelevantPanels(BpodSystem.GUIData.ParameterGUI.LatestGUIParams, ...
            BpodSystem.GUIData.ParameterGUI.LatestMeta);
    end
end

function SetPanelEnabled(panelName, isEnabled)
    global BpodSystem
    if ~isfield(BpodSystem.GUIHandles.ParameterGUI.Panels, panelName), return; end
    panelHandle = BpodSystem.GUIHandles.ParameterGUI.Panels.(panelName);
    if ~ishandle(panelHandle), return; end
    startPressed = isappdata(BpodSystem.ProtocolFigures.ParameterGUI, 'StartPressed') && ...
        getappdata(BpodSystem.ProtocolFigures.ParameterGUI, 'StartPressed');

    style = BpodSystem.GUIData.ParameterGUI.PanelStyles.(panelName);
    if isEnabled
        fgColor = style.ForegroundColor; bgColor = style.BackgroundColor;
        borderColor = style.BorderColor;
        textColor = [0.88 0.88 0.88]; inputBg = [0.22 0.22 0.27];
    else
        fgColor = [0.45 0.45 0.48]; bgColor = [0.13 0.13 0.16];
        borderColor = [0.30 0.30 0.35];
        textColor = [0.52 0.52 0.54]; inputBg = [0.13 0.13 0.16];
    end

    set(panelHandle, 'ForegroundColor', fgColor, 'BackgroundColor', bgColor, ...
        'HighlightColor', borderColor, 'BorderColor', borderColor);

    if isfield(BpodSystem.GUIData.ParameterGUI.PanelParams, panelName)
        paramNames = BpodSystem.GUIData.ParameterGUI.PanelParams.(panelName);
        for iParam = 1:numel(paramNames)
            paramName = paramNames{iParam};
            if ~isfield(BpodSystem.GUIData.ParameterGUI.ParamIndexByName, paramName), continue; end
            paramIdx = BpodSystem.GUIData.ParameterGUI.ParamIndexByName.(paramName);
            if ishandle(BpodSystem.GUIHandles.ParameterGUI.Labels(paramIdx))
                set(BpodSystem.GUIHandles.ParameterGUI.Labels(paramIdx), 'ForegroundColor', textColor);
            end
            if ishandle(BpodSystem.GUIHandles.ParameterGUI.Params(paramIdx))
                allowEnable = ~(startPressed && isEnabled && ...
                    any(strcmp(paramName, BpodSystem.GUIData.ParameterGUI.LockedParams)));
                SetControlEnabled(BpodSystem.GUIHandles.ParameterGUI.Params(paramIdx), isEnabled, inputBg, textColor, allowEnable);
            end
        end
    end
    childHandles = findall(panelHandle);
    childHandles(childHandles == panelHandle) = [];
    for iChild = 1:numel(childHandles)
        allowEnable = ~(startPressed && isEnabled);
        SetControlEnabled(childHandles(iChild), isEnabled, inputBg, textColor, allowEnable);
    end
end

function SetControlEnabled(h, isEnabled, bgColor, textColor, allowEnable)
    if ~ishandle(h), return; end
    if isprop(h, 'Enable')
        if isEnabled && allowEnable, set(h, 'Enable', 'on'); elseif ~isEnabled, set(h, 'Enable', 'off'); end
    end
    if isprop(h, 'BackgroundColor'), try set(h, 'BackgroundColor', bgColor); catch; end; end
    if isprop(h, 'ForegroundColor'), try set(h, 'ForegroundColor', textColor); catch; end; end
end

function DisplayPNGImage()
    global BpodSystem
    ax = BpodSystem.GUIHandles.ParameterGUI.ImageAxes;
    imagePath = fullfile(BpodSystem.Path.ProtocolFolder, '..', 'logo.png');
    if exist(imagePath, 'file')
        img = imread(imagePath); imshow(img, 'Parent', ax); axis(ax, 'off');
    else
        cla(ax); text(0.5, 0.5, 'Image not found', 'Parent', ax, 'HorizontalAlignment', 'center');
        axis(ax, 'off');
    end
end

function n = getDesignSpotCount(BpodSystem, typeName, rowIdx)
    n = 0;
    try
        d = BpodSystem.PluginObjects.PatternDesigns.(typeName){rowIdx};
        if ~isempty(d), n = numel(d.spots); end
    catch
    end
end

function PatternTableSelectionChanged(src, ev, hRowEdit)
    if isempty(ev.Indices), return; end
    rowIdx = ev.Indices(1,1);
    sd = get(src, 'UserData'); sd.ActiveRow = rowIdx; set(src, 'UserData', sd);
    if ishandle(hRowEdit), set(hRowEdit, 'String', num2str(rowIdx)); end
end

function DesignSelectedPatternRow(ptable, typeName, hRowEdit)
    rowIdx = round(str2double(get(hRowEdit, 'String')));
    if isnan(rowIdx) || rowIdx < 1, rowIdx = 1; end
    nRows = size(get(ptable, 'Data'), 1);
    rowIdx = min(rowIdx, nRows);
    PatternDesignerGUI(typeName, rowIdx);
end

function PatternAddRow(ptable, suffix)
    data = get(ptable, 'Data');
    nRows = size(data,1) + 1;
    data(end+1,:) = {0, 1, 1000};
    for i = 1:nRows, data{i,1} = round(1/nRows, 4); end
    set(ptable, 'Data', data);
    sd = get(ptable, 'UserData'); sd.ActiveRow = nRows; set(ptable, 'UserData', sd);
    HandleRealTimeSync(suffix);
end

function PatternRemoveRow(ptable, suffix)
    data = get(ptable, 'Data');
    if size(data,1) > 1
        data(end,:) = [];
        set(ptable, 'Data', data);
        normalizePatternProbs(ptable);
        sd = get(ptable, 'UserData');
        sd.ActiveRow = min(sd.ActiveRow, size(data,1));
        set(ptable, 'UserData', sd);
        HandleRealTimeSync(suffix);
    end
end

function PatternTableCellEdited(src, ev, suffix)
    if ~isempty(ev.Indices) && ev.Indices(1,2) == 1
        normalizePatternProbs(src);
    end
    HandleRealTimeSync(suffix);
end

function normalizePatternProbs(ptable)
    data = get(ptable, 'Data');
    nRows = size(data,1); if nRows == 0, return; end
    probs = zeros(nRows,1);
    for i = 1:nRows
        p = data{i,1}; if isempty(p)||(isnumeric(p)&&isnan(p)), p=0; end
        probs(i) = p;
    end
    total = sum(probs);
    if total == 0, probs = ones(nRows,1)/nRows; else, probs = probs/total; end
    for i = 1:nRows, data{i,1} = round(probs(i),4); end
    set(ptable, 'Data', data);
end

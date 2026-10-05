function varargout = LuminoseParameterGUI_hf_MTS(varargin)
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
    COLORS.accentCS_plus = [0.3 0.6 0.9];
    COLORS.accentCS_minus = [0.9 0.5 0.2];
    COLORS.accentCue = [0.4 0.8 0.4];
    COLORS.accentTrial = [0.75 0.55 0.95];
    COLORS.textDark = [0.88 0.88 0.88];
    COLORS.inputBg = [0.16 0.16 0.20];

    % Parameters to lock after START is pressed
    LOCKED_PARAMS = { ...
        'TrainingLevel', ...
        'maxTrials', ...
        'muBarcodeDur', ...
        'sigmaBarcodeDur', ...
        'SoundSamplingRate', ...
        'ResponseType', ...
        'VariableITI', 'InterTrialInterval', 'MaxITI', ...
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
            BpodSystem.GUIData.ParameterGUI.ProtocolSuffix = 'MTS';

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
                if contains(lower(TabNames{t}),'template')
                    tabColor = COLORS.accentCS_plus;
                elseif contains(lower(TabNames{t}),'sample')
                    tabColor = COLORS.accentCS_minus;
                elseif contains(lower(TabNames{t}),'cue')
                    tabColor = COLORS.accentCue;
                elseif contains(lower(TabNames{t}),'trial')
                    tabColor = COLORS.accentTrial;
                elseif contains(lower(TabNames{t}),'task')
                    tabColor = [0.35 0.85 0.82];
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

                        callbackFunc = @(~,~) HandleRealTimeSync('MTS');

                        switch lower(ThisParamStyle)
                            case 'edit'
                                BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 1;
                                BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = uicontrol(htab,'Style', 'edit', 'String', mat2str(ThisParam), 'Position', [HPos+220 VPos+InPanelPos+2 200 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor',COLORS.inputBg,'ForegroundColor',COLORS.textDark, 'FontName', 'Arial','HorizontalAlignment','Center', 'Callback', callbackFunc);
                            case 'edittext'
                                BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 8;
                                BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = uicontrol(htab,'Style', 'edit', 'String', ThisParam, 'Position', [HPos+220 VPos+InPanelPos+2 200 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor',COLORS.inputBg,'ForegroundColor',COLORS.textDark, 'FontName', 'Arial','HorizontalAlignment','Center', 'Callback', callbackFunc);
                            case 'text'
                                BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 2;
                                BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = uicontrol(htab,'Style', 'text', 'String', num2str(ThisParam), 'Position', [HPos+220 VPos+InPanelPos+2 200 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor',COLORS.inputBg,'ForegroundColor',COLORS.textDark, 'FontName', 'Arial','HorizontalAlignment','Center');
                            case 'checkbox'
                                BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 3;
                                BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = uicontrol(htab,'Style', 'checkbox', 'Value', ThisParam, 'String', '   (check to activate)', 'Position', [HPos+220 VPos+InPanelPos+4 200 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor',COLORS.inputBg,'ForegroundColor',COLORS.textDark, 'FontName', 'Arial','HorizontalAlignment','Center', 'Callback', callbackFunc);
                            case 'popupmenu'
                                BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 4;
                                BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = uicontrol(htab,'Style', 'popupmenu', 'String', ThisParamString, 'Value', ThisParam, 'Position', [HPos+220 VPos+InPanelPos+2 200 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor',COLORS.inputBg,'ForegroundColor',COLORS.textDark, 'FontName', 'Arial','HorizontalAlignment','Center', 'Callback', callbackFunc);
                            case 'togglebutton'
                                BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 5;
                                BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = uicontrol(htab,'Style', 'togglebutton', 'String', ThisParamString, 'Value', ThisParam, 'Position', [HPos+220 VPos+InPanelPos+2 200 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor',COLORS.inputBg,'ForegroundColor',COLORS.textDark, 'FontName', 'Arial','HorizontalAlignment','Center', 'Callback', callbackFunc);
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
                            case 'table'
                                BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 7;
                                columnNames = fieldnames(Params.(ThisParamName));
                                if isfield(Meta.(ThisParamName),'ColumnLabel')
                                    columnLabel = Meta.(ThisParamName).ColumnLabel;
                                else
                                    columnLabel = columnNames;
                                end
                                tableData = [];
                                for iTableCol = 1:numel(columnNames)
                                    tableData = [tableData, Params.(ThisParamName).(columnNames{iTableCol})];
                                end
                                htable = uitable(htab,'data',tableData,'columnname',columnLabel,...
                                    'ColumnEditable',true(1,numel(columnLabel)), 'FontSize', 12, 'CellEditCallback', callbackFunc);
                                htable.Position([3 4]) = htable.Extent([3 4]);
                                htable.Position([1 2]) = [HPos+220 VPos+InPanelPos+2];
                                BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = htable;
                                ThisPanelHeight = ThisPanelHeight + (htable.Position(4)-25);
                                BpodSystem.GUIHandles.ParameterGUI.Panels.(ThisTabPanelNames{p}).Position(4) = ThisPanelHeight;
                                BpodSystem.GUIData.ParameterGUI.LastParamValues{ParamNum} = htable.Data;
                            case 'odour_selector'
                                BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 9;
                                matrixValves = ThisParam;
                                probParam = Meta.(ThisParamName).ProbParam;
                                dutyParam = Meta.(ThisParamName).DutyParam;
                                vectorProbs = Params.(probParam);
                                matrixDuty = Params.(dutyParam);

                                selectorHeight = 260;
                                selectorPanel = uipanel(htab, 'Units', 'pixels', ...
                                    'Position', [HPos+10 VPos+InPanelPos 435 selectorHeight], ...
                                    'BackgroundColor', COLORS.panelBg, 'BorderType', 'none');

                                mapping = getOdourMapping();
                                bottleButtons = zeros(1, 16);
                                if ~isempty(matrixValves)
                                    initialVRow = matrixValves(1, :);
                                else
                                    initialVRow = [];
                                end

                                for iBottle = 1:16
                                    row = ceil(iBottle/8);
                                    col = mod(iBottle-1, 8) + 1;
                                    btnPos = [10 + (col-1)*53, selectorHeight - 55 - (row-1)*55, 45, 50];
                                    chemical = mapping(iBottle).Name;
                                    notes = mapping(iBottle).Notes;
                                    tooltip = sprintf('Valve %d: %s\nChems: %s\nNotes: %s', iBottle, chemical, mapping(iBottle).Chemicals, notes);
                                    isAir = ismember(iBottle, [1, 2, 9, 10, 14]);

                                    isSelected = ismember(iBottle, initialVRow);
                                    btnColor = [0.28 0.28 0.33];
                                    if isSelected, btnColor = tabColor; end
                                    if isAir && ~isSelected, btnColor = [0.20 0.22 0.30]; end

                                    img = generateBottleImage(btnPos(3)-10, btnPos(4)-10, btnColor, COLORS.panelBg);
                                    bottleButtons(iBottle) = uicontrol(selectorPanel, 'Style', 'pushbutton', ...
                                        'String', '', 'Position', btnPos, ...
                                        'CData', img, 'BackgroundColor', COLORS.panelBg, 'TooltipString', tooltip, ...
                                        'UserData', struct('Valve', iBottle, 'TabColor', tabColor, 'IsAir', isAir), ...
                                        'Callback', @(src, ~) OdourBottleClicked(src, ParamNum));
                                end

                                nOptions = size(matrixValves, 1);
                                tableData = cell(nOptions, 3);
                                for iOpt = 1:nOptions
                                    vRow = matrixValves(iOpt, :);
                                    vRow = vRow(vRow > 0);
                                    dRow = matrixDuty(iOpt, :);
                                    dRow = dRow(1:length(vRow));
                                    tableData{iOpt, 1} = vectorProbs(iOpt);
                                    tableData{iOpt, 2} = num2str(vRow);
                                    tableData{iOpt, 3} = num2str(dRow);
                                end

                                otable = uitable(selectorPanel, 'Data', tableData, ...
                                    'ColumnName', {'Prob', 'Valves', 'DutyCycles'}, ...
                                    'ColumnWidth', {50, 160, 160}, 'ColumnEditable', [true, true, true], ...
                                    'ColumnFormat', {'numeric', 'char', 'char'}, ...
                                    'Position', [5 10 385 125], 'FontSize', 10, ...
                                    'CellEditCallback', @(src, ev) OdourTableCellEdited(src, ev, 'MTS'));

                                set(otable, 'CellSelectionCallback', @(src, ev) OdourTableSelectionChanged(src, ev, bottleButtons));

                                uicontrol(selectorPanel, 'Style', 'pushbutton', 'String', '+', ...
                                    'Position', [395 90 32 32], 'FontSize', 14, 'FontWeight', 'bold', ...
                                    'Callback', @(~, ~) OdourAddRow(otable, 'MTS'));
                                uicontrol(selectorPanel, 'Style', 'pushbutton', 'String', '-', ...
                                    'Position', [395 50 32 32], 'FontSize', 14, 'FontWeight', 'bold', ...
                                    'Callback', @(~, ~) OdourRemoveRow(otable, 'MTS'));

                                selectorData = struct('Buttons', bottleButtons, 'Table', otable, ...
                                    'ParamName', ThisParamName, 'ProbParam', probParam, 'DutyParam', dutyParam, ...
                                    'Mapping', mapping, 'ActiveRow', 1);
                                BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = otable;
                                set(otable, 'UserData', selectorData);

                                ThisPanelHeight = ThisPanelHeight + selectorHeight - 25;
                                BpodSystem.GUIHandles.ParameterGUI.Panels.(ThisTabPanelNames{p}).Position(4) = ThisPanelHeight;
                                InPanelPos = InPanelPos + selectorHeight - 35;
                                BpodSystem.GUIData.ParameterGUI.LastParamValues{ParamNum} = tableData;
                            case 'odour_selector_conditional'
                                % Same valve-picker as 'odour_selector', but each
                                % row's probability column is replaced by one
                                % checkbox per template row (fixed at
                                % MAX_TEMPLATE_COLS columns; columns beyond the
                                % current number of Template rows are simply
                                % unused). Checked = this sample row is a valid
                                % Non-match follow-up for that template row.
                                BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 11;
                                matrixValves = ThisParam;
                                dutyParam = Meta.(ThisParamName).DutyParam;
                                maskParam = Meta.(ThisParamName).MaskParam;
                                matrixDuty = Params.(dutyParam);
                                maskMatrix = Params.(maskParam);
                                MAX_TEMPLATE_COLS = size(maskMatrix, 2);

                                selectorHeight = 260;
                                selectorPanel = uipanel(htab, 'Units', 'pixels', ...
                                    'Position', [HPos+10 VPos+InPanelPos 435 selectorHeight], ...
                                    'BackgroundColor', COLORS.panelBg, 'BorderType', 'none');

                                mapping = getOdourMapping();
                                bottleButtons = zeros(1, 16);
                                if ~isempty(matrixValves)
                                    initialVRow = matrixValves(1, :);
                                else
                                    initialVRow = [];
                                end

                                for iBottle = 1:16
                                    row = ceil(iBottle/8);
                                    col = mod(iBottle-1, 8) + 1;
                                    btnPos = [10 + (col-1)*53, selectorHeight - 55 - (row-1)*55, 45, 50];
                                    chemical = mapping(iBottle).Name;
                                    notes = mapping(iBottle).Notes;
                                    tooltip = sprintf('Valve %d: %s\nChems: %s\nNotes: %s', iBottle, chemical, mapping(iBottle).Chemicals, notes);
                                    isAir = ismember(iBottle, [1, 2, 9, 10, 14]);

                                    isSelected = ismember(iBottle, initialVRow);
                                    btnColor = [0.28 0.28 0.33];
                                    if isSelected, btnColor = tabColor; end
                                    if isAir && ~isSelected, btnColor = [0.20 0.22 0.30]; end

                                    img = generateBottleImage(btnPos(3)-10, btnPos(4)-10, btnColor, COLORS.panelBg);
                                    bottleButtons(iBottle) = uicontrol(selectorPanel, 'Style', 'pushbutton', ...
                                        'String', '', 'Position', btnPos, ...
                                        'CData', img, 'BackgroundColor', COLORS.panelBg, 'TooltipString', tooltip, ...
                                        'UserData', struct('Valve', iBottle, 'TabColor', tabColor, 'IsAir', isAir), ...
                                        'Callback', @(src, ~) OdourMaskBottleClicked(src, ParamNum));
                                end

                                nOptions = size(matrixValves, 1);
                                tableData = cell(nOptions, 2 + MAX_TEMPLATE_COLS);
                                for iOpt = 1:nOptions
                                    vRow = matrixValves(iOpt, :);
                                    vRow = vRow(vRow > 0);
                                    dRow = matrixDuty(iOpt, :);
                                    dRow = dRow(1:length(vRow));
                                    tableData{iOpt, 1} = num2str(vRow);
                                    tableData{iOpt, 2} = num2str(dRow);
                                    for iCol = 1:MAX_TEMPLATE_COLS
                                        tableData{iOpt, 2+iCol} = logical(maskMatrix(iOpt, iCol));
                                    end
                                end

                                columnNames = [{'Valves', 'DutyCycles'}, arrayfun(@(c) sprintf('T%d', c), 1:MAX_TEMPLATE_COLS, 'UniformOutput', false)];
                                columnWidths = [{120, 90}, repmat({28}, 1, MAX_TEMPLATE_COLS)];
                                columnFormat = [{'char', 'char'}, repmat({'logical'}, 1, MAX_TEMPLATE_COLS)];

                                otable = uitable(selectorPanel, 'Data', tableData, ...
                                    'ColumnName', columnNames, ...
                                    'ColumnWidth', columnWidths, 'ColumnEditable', true(1, 2+MAX_TEMPLATE_COLS), ...
                                    'ColumnFormat', columnFormat, ...
                                    'Position', [5 10 385 125], 'FontSize', 10, ...
                                    'CellEditCallback', @(src, ev) OdourMaskTableCellEdited(src, ev, 'MTS'));

                                set(otable, 'CellSelectionCallback', @(src, ev) OdourMaskTableSelectionChanged(src, ev, bottleButtons));

                                uicontrol(selectorPanel, 'Style', 'pushbutton', 'String', '+', ...
                                    'Position', [395 90 32 32], 'FontSize', 14, 'FontWeight', 'bold', ...
                                    'Callback', @(~, ~) OdourMaskAddRow(otable, 'MTS'));
                                uicontrol(selectorPanel, 'Style', 'pushbutton', 'String', '-', ...
                                    'Position', [395 50 32 32], 'FontSize', 14, 'FontWeight', 'bold', ...
                                    'Callback', @(~, ~) OdourMaskRemoveRow(otable, 'MTS'));

                                selectorData = struct('Buttons', bottleButtons, 'Table', otable, ...
                                    'ParamName', ThisParamName, 'DutyParam', dutyParam, 'MaskParam', maskParam, ...
                                    'Mapping', mapping, 'ActiveRow', 1, 'MaxTemplateCols', MAX_TEMPLATE_COLS);
                                BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = otable;
                                set(otable, 'UserData', selectorData);

                                ThisPanelHeight = ThisPanelHeight + selectorHeight - 25;
                                BpodSystem.GUIHandles.ParameterGUI.Panels.(ThisTabPanelNames{p}).Position(4) = ThisPanelHeight;
                                InPanelPos = InPanelPos + selectorHeight - 35;
                                BpodSystem.GUIData.ParameterGUI.LastParamValues{ParamNum} = tableData;
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
                                    tableData{iOpt,3} = vExposure(iOpt);
                                end
                                selectorHeight = 195;
                                selectorPanel = uipanel(htab, 'Units', 'pixels', ...
                                    'Position', [HPos+10 VPos+InPanelPos 435 selectorHeight], ...
                                    'BackgroundColor', COLORS.panelBg, 'BorderType', 'none');
                                hRowEdit = uicontrol(selectorPanel, 'Style', 'edit', 'String', '1', ...
                                    'Position', [253 16 35 26], 'FontSize', 11, 'BackgroundColor', COLORS.inputBg, 'ForegroundColor', COLORS.textDark);
                                ptable = uitable(selectorPanel, 'Data', tableData, ...
                                    'ColumnName', {'Prob', 'Spots', 'Exposure (us)'}, ...
                                    'ColumnWidth', {55, 65, 105}, 'ColumnEditable', [true false true], ...
                                    'ColumnFormat', {'numeric','numeric','numeric'}, ...
                                    'Position', [5 60 385 120], 'FontSize', 10, ...
                                    'CellEditCallback', @(src,ev) PatternTableCellEdited(src, ev, 'MTS'), ...
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
                                    'Callback', @(~,~) PatternAddRow(ptable, 'MTS'));
                                uicontrol(selectorPanel, 'Style', 'pushbutton', 'String', '-', ...
                                    'Position', [395 75 32 32], 'FontSize', 14, 'FontWeight', 'bold', ...
                                    'Callback', @(~,~) PatternRemoveRow(ptable, 'MTS'));
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
                        if VPos + ThisPanelHeight + 45 + NextPanelSize > GUIHeight
                            Wrap = 1;
                        end
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
                        'FontName', 'Segoe UI', 'Callback', @(~,~) HandleMTSStartButton(LOCKED_PARAMS));
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
                if contains(lower(TabNames{t}),'task')
                    panelName = 'TrialStructure'; ThisPanelHeight = 105;
                    BpodSystem.GUIHandles.ParameterGUI.Panels.(panelName) = uipanel(htab,...
                        'title',sprintf('  %s  ',panelName),'FontSize',12,'FontWeight','Bold','ForegroundColor',tabColor,...
                        'BackgroundColor',COLORS.panelBg,'Units','Pixels','Position',[HPos VPos 455 ThisPanelHeight],...
                        'BorderType','line','HighlightColor',tabColor,'BorderWidth',2,'BorderColor',tabColor);
                    BpodSystem.GUIHandles.ParameterGUI.TrialStructureAxes = axes('Parent',BpodSystem.GUIHandles.ParameterGUI.Panels.(panelName),...
                        'Units','normalized','Position',[0.08 0.12 0.9 0.62],'Box','on','Color',COLORS.panelBg);
                    DrawTrialStructure(Params, Meta);
                    VPos = VPos + ThisPanelHeight + 15;
                end
                if any(contains(lower(TabNames{t}), {'cue','template','sample'}))
                    panelName = sprintf('%s_StimulusIndicators', TabNames{t}); ThisPanelHeight = 80;
                    BpodSystem.GUIHandles.ParameterGUI.Panels.(panelName) = uipanel(htab,...
                        'title',' Stimulus Type ','FontSize',11,'FontWeight','Bold','ForegroundColor',tabColor,...
                        'BackgroundColor',COLORS.panelBg,'Units','Pixels','Position',[15 VPos 455 ThisPanelHeight],...
                        'BorderType','line','HighlightColor',tabColor,'BorderWidth',2);
                    boxWidth = 80; spacing = 20; x0 = 25;
                    for iBox = 1:4
                        x = x0 + (iBox-1)*(boxWidth+spacing);
                        bgColor = [0.25 0.25 0.30];
                        switch lower(TabNames{t})
                            case 'cue', selIdx = Params.CueType; stimLabels = Meta.CueType.String;
                            case 'template', selIdx = Params.TemplateType; stimLabels = Meta.TemplateType.String;
                            case 'sample', selIdx = Params.SampleType; stimLabels = Meta.SampleType.String;
                            otherwise, selIdx = 0; stimLabels = {};
                        end
                        if iBox == selIdx, bgColor = tabColor; end
                        BpodSystem.GUIHandles.ParameterGUI.StimIndicators.(TabNames{t})(iBox) = uipanel(BpodSystem.GUIHandles.ParameterGUI.Panels.(panelName), ...
                            'Units','pixels','Position',[x 15 boxWidth 30], 'BackgroundColor', bgColor, 'BorderType','line','BorderWidth',1);
                        uicontrol('Parent',BpodSystem.GUIHandles.ParameterGUI.StimIndicators.(TabNames{t})(iBox), 'Style','text','String',stimLabels{iBox}, ...
                            'Units','normalized','Position',[0 0 1 1], 'BackgroundColor',bgColor,'ForegroundColor',COLORS.textDark, ...
                            'FontWeight','Bold','FontSize',10,'HorizontalAlignment','center');
                    end
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
                    case 2
                        GUIParam = ThisParamCurrentValue; Text = GUIParam; if ~ischar(Text), Text = num2str(Text); end
                        set(ThisParamHandle, 'String', Text);
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
                        tableData = get(ThisParamHandle, 'Data');
                        sd = get(ThisParamHandle, 'UserData');
                        nRows = size(tableData, 1);
                        probsVec = zeros(nRows,1); exposureVec = ones(nRows,1)*1e6;
                        for iR = 1:nRows
                            pVal = tableData{iR,1}; if isempty(pVal)||isnan(pVal), pVal=0; end
                            probsVec(iR) = pVal;
                            exposureVec(iR) = tableData{iR,3};
                        end
                        GUIParam = 0;
                        Params.GUI.(sd.ProbParam)     = probsVec;
                        Params.GUI.(sd.ExposureParam) = exposureVec;
                        % nFrames is managed by PatternDesignerGUI, not read from table
                    case 9
                        tableData = get(ThisParamHandle, 'Data');
                        selectorData = get(ThisParamHandle, 'UserData');
                        nRows = size(tableData, 1);
                        valvesMatrix = []; probsVector = zeros(nRows, 1); dutyMatrix = [];
                        for iR = 1:nRows
                            probsVector(iR) = tableData{iR, 1};
                            vRow = str2num(tableData{iR, 2}); dRow = str2num(tableData{iR, 3});
                            if isempty(vRow), vRow = 0; end
                            if isempty(dRow), dRow = 1; end
                            valvesMatrix = PadAndAppend(valvesMatrix, vRow);
                            dutyMatrix = PadAndAppend(dutyMatrix, dRow);
                        end
                        Params.GUI.(ThisParamName) = valvesMatrix;
                        Params.GUI.(selectorData.ProbParam) = probsVector;
                        Params.GUI.(selectorData.DutyParam) = dutyMatrix;
                    case 11
                        tableData = get(ThisParamHandle, 'Data');
                        selectorData = get(ThisParamHandle, 'UserData');
                        nRows = size(tableData, 1);
                        nMaskCols = selectorData.MaxTemplateCols;
                        valvesMatrix = []; dutyMatrix = []; maskMatrix = false(nRows, nMaskCols);
                        for iR = 1:nRows
                            vRow = str2num(tableData{iR, 1}); dRow = str2num(tableData{iR, 2});
                            if isempty(vRow), vRow = 0; end
                            if isempty(dRow), dRow = 1; end
                            valvesMatrix = PadAndAppend(valvesMatrix, vRow);
                            dutyMatrix = PadAndAppend(dutyMatrix, dRow);
                            for iCol = 1:nMaskCols
                                maskMatrix(iR, iCol) = logical(tableData{iR, 2+iCol});
                            end
                        end
                        Params.GUI.(ThisParamName) = valvesMatrix;
                        Params.GUI.(selectorData.DutyParam) = dutyMatrix;
                        Params.GUI.(selectorData.MaskParam) = maskMatrix;
                end
                if ~isequal(ThisParamStyle, 5), BpodSystem.GUIData.ParameterGUI.LastParamValues{p} = Params.GUI.(ThisParamName); end
            end
            BpodSystem.GUIData.ParameterGUI.LatestGUIParams = Params.GUI;
            BpodSystem.GUIData.ParameterGUI.LatestMeta = Params.GUIMeta;
            UpdateRelevantPanels(Params.GUI, Params.GUIMeta);
            if isfield(BpodSystem.GUIHandles.ParameterGUI, 'TrialStructureAxes'), DrawTrialStructure(Params.GUI, Params.GUIMeta); end
            if isfield(BpodSystem.GUIHandles.ParameterGUI, 'OptoStimAxes'), DrawOptoStim(Params.GUI); end
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

function m = PadAndAppend(m, row)
    if isempty(m), m = row; return; end
    nColsM = size(m, 2); nColsR = length(row);
    if nColsM < nColsR, m = [m, zeros(size(m,1), nColsR-nColsM)];
    elseif nColsR < nColsM, row = [row, zeros(1, nColsM-nColsR)]; end
    m = [m; row];
end

function OdourTableSelectionChanged(src, ev, bottleButtons)
    if isempty(ev.Indices), return; end
    rowIdx = ev.Indices(1, 1);
    data = get(src, 'UserData'); data.ActiveRow = rowIdx; set(src, 'UserData', data);
    tableData = get(src, 'Data'); vRow = str2num(tableData{rowIdx, 2});
    for iB = 1:16
        btn = bottleButtons(iB); btnData = get(btn, 'UserData');
        isSelected = ismember(iB, vRow);
        btnColor = [0.28 0.28 0.33]; if isSelected, btnColor = btnData.TabColor; end
        if btnData.IsAir && ~isSelected, btnColor = [0.20 0.22 0.30]; end
        pos = get(btn, 'Position'); img = generateBottleImage(pos(3)-10, pos(4)-10, btnColor, [0.18 0.18 0.22]);
        set(btn, 'CData', img);
    end
end

function OdourAddRow(htable, suffix)
    data = get(htable, 'Data');
    nRows = size(data, 1) + 1;
    data = [data; {0, '', ''}];
    for i = 1:nRows
        data{i, 1} = round(1/nRows, 4);
    end
    set(htable, 'Data', data);
    selectorData = get(htable, 'UserData');
    selectorData.ActiveRow = nRows;
    set(htable, 'UserData', selectorData);
    HandleRealTimeSync(suffix);
end

function OdourRemoveRow(htable, suffix)
    data = get(htable, 'Data');
    if size(data, 1) > 1
        data(end, :) = [];
        set(htable, 'Data', data);
        normalizeOdourProbs(htable);
        selectorData = get(htable, 'UserData');
        selectorData.ActiveRow = min(selectorData.ActiveRow, size(data, 1));
        set(htable, 'UserData', selectorData);
        HandleRealTimeSync(suffix);
    end
end

function OdourTableCellEdited(src, ev, suffix)
    if ~isempty(ev.Indices) && ev.Indices(1, 2) == 1
        normalizeOdourProbs(src);
    end
    HandleRealTimeSync(suffix);
end

function normalizeOdourProbs(htable)
    data = get(htable, 'Data');
    nRows = size(data, 1);
    if nRows == 0, return; end
    probs = zeros(nRows, 1);
    for i = 1:nRows
        p = data{i, 1};
        if isempty(p) || (isnumeric(p) && isnan(p)), p = 0; end
        probs(i) = p;
    end
    total = sum(probs);
    if total == 0
        probs = ones(nRows, 1) / nRows;
    else
        probs = probs / total;
    end
    for i = 1:nRows
        data{i, 1} = round(probs(i), 4);
    end
    set(htable, 'Data', data);
end

function OdourMaskBottleClicked(src, paramNum)
% Bottle-grid callback for the Sample tab's conditional odour table, where
% column 1 = Valves and column 2 = DutyCycles (no Prob column).
    global BpodSystem
    data = get(src, 'UserData');
    v = data.Valve;
    if ismember(v, [1, 2, 9, 10])
        return;
    end
    tabColor = data.TabColor;
    panelBg = [1 1 1];

    htable = BpodSystem.GUIHandles.ParameterGUI.Params(paramNum);
    selectorData = get(htable, 'UserData');
    currentData = get(htable, 'Data');

    activeRow = selectorData.ActiveRow;
    if activeRow > size(currentData, 1)
        activeRow = size(currentData, 1);
        selectorData.ActiveRow = activeRow;
    end

    vRow = str2num(currentData{activeRow, 1}); %#ok<ST2NM>
    dRow = str2num(currentData{activeRow, 2}); %#ok<ST2NM>

    if ~isempty(vRow) && vRow(end) == v
        vRow(end) = [];
        if length(dRow) > length(vRow), dRow(end) = []; end
    else
        vRow = [vRow, v];
        if length(dRow) < length(vRow), dRow = [dRow, 1]; end
    end

    currentData{activeRow, 1} = num2str(vRow);
    currentData{activeRow, 2} = num2str(dRow);
    set(htable, 'Data', currentData);

    for iBtn = 1:16
        hBtn = selectorData.Buttons(iBtn);
        hData = get(hBtn, 'UserData');
        isSelected = ismember(hData.Valve, vRow);
        btnColor = [0.9 0.9 0.9]; if isSelected, btnColor = tabColor; end
        if hData.IsAir && ~isSelected, btnColor = [0.95 0.95 1.0]; end
        pos = get(hBtn, 'Position');
        img = generateBottleImage(pos(3)-10, pos(4)-10, btnColor, panelBg);
        set(hBtn, 'CData', img, 'BackgroundColor', panelBg);
    end

    set(htable, 'UserData', selectorData);
    HandleRealTimeSync('MTS');
end

function OdourMaskTableSelectionChanged(src, ev, bottleButtons)
    if isempty(ev.Indices), return; end
    rowIdx = ev.Indices(1, 1);
    data = get(src, 'UserData'); data.ActiveRow = rowIdx; set(src, 'UserData', data);
    tableData = get(src, 'Data'); vRow = str2num(tableData{rowIdx, 1}); %#ok<ST2NM>
    for iB = 1:16
        btn = bottleButtons(iB); btnData = get(btn, 'UserData');
        isSelected = ismember(iB, vRow);
        btnColor = [0.28 0.28 0.33]; if isSelected, btnColor = btnData.TabColor; end
        if btnData.IsAir && ~isSelected, btnColor = [0.20 0.22 0.30]; end
        pos = get(btn, 'Position'); img = generateBottleImage(pos(3)-10, pos(4)-10, btnColor, [0.18 0.18 0.22]);
        set(btn, 'CData', img);
    end
end

function OdourMaskAddRow(htable, suffix)
    data = get(htable, 'Data');
    sd = get(htable, 'UserData');
    nRows = size(data, 1) + 1;
    newRow = [{'', ''}, repmat({false}, 1, sd.MaxTemplateCols)];
    data = [data; newRow];
    set(htable, 'Data', data);
    sd.ActiveRow = nRows;
    set(htable, 'UserData', sd);
    HandleRealTimeSync(suffix);
end

function OdourMaskRemoveRow(htable, suffix)
    data = get(htable, 'Data');
    if size(data, 1) > 1
        data(end, :) = [];
        set(htable, 'Data', data);
        sd = get(htable, 'UserData');
        sd.ActiveRow = min(sd.ActiveRow, size(data, 1));
        set(htable, 'UserData', sd);
        HandleRealTimeSync(suffix);
    end
end

function OdourMaskTableCellEdited(src, ev, suffix) %#ok<INUSL>
    HandleRealTimeSync(suffix);
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
    data(end+1,:) = {0, 1, 1e6};
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

function UpdateRelevantPanels(Params, Meta)
    global BpodSystem

    COLORS.accentCS_plus = [0.2 0.5 0.8];
    COLORS.accentCS_minus = [0.8 0.4 0.2];
    COLORS.accentCue = [0.4 0.7 0.4];

    panelStates = struct( ...
        'Light_cue', false, 'Sound_cue', false, 'Odour_cue', false, 'Pattern_cue', false, ...
        'Light_Template', false, 'Sound_Template', false, 'Odour_Template', false, 'Pattern_Template', false, ...
        'Light_Sample', false, 'Sound_Sample', false, 'Odour_Sample', false, 'Pattern_Sample', false, ...
        'MaskLED', false, 'SinglePulse', false, 'PairedPulse', false, 'Pattern_opto', false, ...
        'DrugSpecs', logical(Params.Drug), 'EEGSpecs', logical(Params.EEG), 'EphysSpecs', logical(Params.Ephys));

    if isfield(Meta, 'CueType')
        cueType = Meta.CueType.String{Params.CueType};
        panelStates.(sprintf('%s_cue', cueType)) = true;
    end
    if isfield(Meta, 'TemplateType')
        templateType = Meta.TemplateType.String{Params.TemplateType};
        panelStates.(sprintf('%s_Template', templateType)) = true;
    end
    if isfield(Meta, 'SampleType')
        sampleType = Meta.SampleType.String{Params.SampleType};
        panelStates.(sprintf('%s_Sample', sampleType)) = true;
    end

    if logical(Params.TestPulses)
        panelStates.MaskLED = true;
        panelStates.Pattern_opto = true;
        if isfield(Meta, 'TestPulsesType')
            pulseType = Meta.TestPulsesType.String{Params.TestPulsesType};
            panelStates.(pulseType) = true;
        end
    end

    panelNames = fieldnames(panelStates);
    for iPanel = 1:numel(panelNames)
        SetPanelEnabled(panelNames{iPanel}, panelStates.(panelNames{iPanel}));
    end

    tabs = {'Cue', 'Template', 'Sample'};
    for iTab = 1:numel(tabs)
        tabName = tabs{iTab};
        if isfield(BpodSystem.GUIHandles.ParameterGUI, 'StimIndicators') && ...
           isfield(BpodSystem.GUIHandles.ParameterGUI.StimIndicators, tabName)

            switch lower(tabName)
                case 'cue', selIdx = Params.CueType; tabColor = COLORS.accentCue;
                case 'template', selIdx = Params.TemplateType; tabColor = COLORS.accentCS_plus;
                case 'sample', selIdx = Params.SampleType; tabColor = COLORS.accentCS_minus;
            end

            indicators = BpodSystem.GUIHandles.ParameterGUI.StimIndicators.(tabName);
            for iInd = 1:numel(indicators)
                hInd = indicators(iInd);
                if iInd == selIdx, bgColor = tabColor; else bgColor = [0.25 0.25 0.30]; end
                set(hInd, 'BackgroundColor', bgColor);
                set(findall(hInd, 'Type', 'uicontrol'), 'BackgroundColor', bgColor);
            end
        end
    end
end

function HandleMTSStartButton(lockedParams)
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

function DrawTrialStructure(Params, Meta)
    global BpodSystem
    ax = BpodSystem.GUIHandles.ParameterGUI.TrialStructureAxes;
    % Redrawn only when a setting changed: a pattern's duration may load its
    % design file (lhf.stimDuration), and sync runs every trial
    key = {rmfield(Params, intersect(fieldnames(Params), {'delivered_odours', 'delivered_dutyCycles'})), Meta};
    if isequal(ax.UserData, key), return; end
    cla(ax); hold(ax,'on');
    ax.UserData = key;

    % The cue starts with the Template. Each stimulus's longest row
    % (lhf.stimDuration): a pattern its design, an odour its sequence,
    % light and sound their panel's Duration
    cueType = Meta.CueType.String{Params.CueType};
    templateType = Meta.TemplateType.String{Params.TemplateType}; sampleType = Meta.SampleType.String{Params.SampleType};
    templateTime = lhf.stimDuration(Params, templateType, 'Template', 'longest');
    matchTime = max(templateTime, lhf.stimDuration(Params, sampleType, 'Sample', 'longest'));
    delay = Params.Delay;
    responseTime = Params.ResponseTime; errorDelay = Params.ErrorDelay; iti = Params.InterTrialInterval;
    itiType = 'Fixed'; if Params.VariableITI, itiType = 'Variable'; end

    blocks = {'Template','Delay','Match','Response','Reward/Error','ITI'};
    blockNames = {[templateType ' + ' cueType ' cue'], 'A=B?', [templateType '/' sampleType], 'Lick spout', 'Water/Noise', itiType};
    colors = [0.2 0.5 0.8; 0.6 0.5 0.7; 0.8 0.3 0.6; 0.8 0.8 0.2; 0.8 0.4 0.2; 0.6 0.6 0.6];
    ypos = 0.4; height = 0.4; t = 0;
    blockTimes = [templateTime, delay, matchTime, responseTime, errorDelay, iti];
    for i = 1:length(blocks)
        rectangle(ax,'Position',[t ypos blockTimes(i) height], 'FaceColor', colors(i,:), 'EdgeColor','k');
        text(t + blockTimes(i)/2, ypos+height*1.4, blocks{i}, 'HorizontalAlignment','center','Parent',ax);
        text(t + blockTimes(i)/2, ypos+height/2, string(round(blockTimes(i), 3))+'s', 'HorizontalAlignment','center','Parent',ax);
        text(t + blockTimes(i)/2, ypos-height*0.6, blockNames{i}, 'HorizontalAlignment','center', 'Rotation', 25,'Parent',ax);
        t = t + blockTimes(i);
    end
    ax.XLim = [0 t]; ax.YLim = [0 1]; axis(ax,'off');
    BpodSystem.GUIData.ParameterGUI.TrialDuration = t;  % the OptoStim preview's trial
end

function DrawOptoStim(Params)
    global BpodSystem
    ax = BpodSystem.GUIHandles.ParameterGUI.OptoStimAxes;
    cla(ax); hold(ax,'on');
    widthScale = 0.5; ypos = 0.3; height = 0.4;
    totalTrial = 10;
    if isfield(BpodSystem.GUIData.ParameterGUI, 'TrialDuration'), totalTrial = BpodSystem.GUIData.ParameterGUI.TrialDuration; end
    scaledTotal = totalTrial * widthScale;
    rectangle(ax, 'Position', [0 ypos scaledTotal height], 'FaceColor', [0.85 0.85 0.85], 'EdgeColor', [0 0 0]);
    if Params.TestPulsesType == 1, freq = Params.SPfrequency; amplitude = Params.SPamplitude; symbol = '*';
    else freq = Params.PPfrequency; amplitude = Params.PPamplitude; symbol = '**'; end
    if freq > 0
        dt = 1 / freq; tEvents = 0:dt:totalTrial; color = [0 0 max(min(amplitude,1),0)];
        for tEv = tEvents, tScaled = tEv * widthScale;
            text(ax, tScaled, ypos + height + 0.05, symbol, 'Color', color, 'FontSize', 12, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
        end
    end
    ax.XLim = [0 scaledTotal]; ax.YLim = [0 1]; axis(ax, 'off');
end

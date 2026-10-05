function [S, notes] = mergeSettings(saved, defaults, protocol, history)
% lhf.mergeSettings  A saved settings struct brought up to the protocol's current declaration.
%
%   [S, notes] = lhf.mergeSettings(saved, defaults, protocol)
%
%   saved     BpodSystem.ProtocolSettings from the settings file (may be empty)
%   defaults  S as GUIparams_luminose_hf_<protocol> builds it from nothing
%   protocol  'goNogo', 'powercal', '2AFC', 'MTS' or 'sleep'
%   history   optional: renamed/retired settings in place of
%             lhf.settingsHistory(protocol) (tests)
%
%   The declarations (GUIMeta, GUIPanels, GUITabs) always come from the
%   defaults. Each saved S.GUI value is kept, with these exceptions, each
%   reported in notes (a cell of lines for the console):
%     renamed   moved to its new name (lhf.settingsHistory)
%     retired   dropped (lhf.settingsHistory)
%     invalid   the default kept: a menu choice out of range, or a value of
%               another kind (number, text, cell, struct) than the default
%   Saved S.GUI fields the defaults do not declare (pattern tables,
%   delivered odours) are kept as they are, as are saved fields outside
%   S.GUI and the declarations.

    S = defaults;
    notes = {};
    if ~isstruct(saved) || isempty(fieldnames(saved))
        return
    end

    if nargin < 4
        history = lhf.settingsHistory(protocol);
    end

    for name = fieldnames(saved)'
        if ~ismember(name{1}, {'GUI', 'GUIMeta', 'GUIPanels', 'GUITabs'})
            S.(name{1}) = saved.(name{1});
        end
    end
    if ~isfield(saved, 'GUI')
        return
    end

    savedGUI = saved.GUI;
    for k = 1:size(history.renamed, 1)
        [oldName, newName] = history.renamed{k, :};
        if isfield(savedGUI, oldName)
            if ~isfield(savedGUI, newName)
                savedGUI.(newName) = savedGUI.(oldName);
            end
            savedGUI = rmfield(savedGUI, oldName);
            notes{end+1} = sprintf('Setting %s is now %s: value carried over.', oldName, newName); %#ok<AGROW>
        end
    end

    for name = fieldnames(savedGUI)'
        field = name{1};
        value = savedGUI.(field);
        if ismember(field, history.retired)
            notes{end+1} = sprintf('Setting %s no longer exists: dropped.', field); %#ok<AGROW>
        elseif ~isfield(defaults.GUI, field)
            S.GUI.(field) = value;
        elseif ~sameKind(value, defaults.GUI.(field))
            notes{end+1} = sprintf('Setting %s has a %s where a %s is expected: default kept.', ...
                field, class(value), class(defaults.GUI.(field))); %#ok<AGROW>
        elseif ~validMenuChoice(value, field, defaults)
            notes{end+1} = sprintf('Setting %s: menu choice %s is out of range: default kept.', ...
                field, mat2str(value)); %#ok<AGROW>
        else
            S.GUI.(field) = value;
        end
    end
end

function same = sameKind(a, b)
    same = strcmp(kind(a), kind(b));
end

function k = kind(v)
    if isnumeric(v) || islogical(v)
        k = 'number';
    elseif ischar(v) || isstring(v)
        k = 'text';
    elseif iscell(v)
        k = 'cell';
    elseif isstruct(v)
        k = 'struct';
    else
        k = class(v);
    end
end

function ok = validMenuChoice(value, field, defaults)
    ok = true;
    if ~isfield(defaults, 'GUIMeta') || ~isfield(defaults.GUIMeta, field), return; end
    meta = defaults.GUIMeta.(field);
    if isfield(meta, 'Style') && strcmp(meta.Style, 'popupmenu') && isfield(meta, 'String')
        ok = isscalar(value) && value == round(value) && value >= 1 && value <= numel(meta.String);
    end
end

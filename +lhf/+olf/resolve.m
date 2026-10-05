function [valves, dutyCycles, type] = resolve(code, GUI, odourTypes, fixedRows)
% lhf.olf.resolve  The valves and duty cycles an odour soft code delivers.
%
%   [valves, dutyCycles, type] = lhf.olf.resolve(code, S.GUI, odourTypes, fixedRows)
%
%   code        odour soft code 1, 2 or 3
%   odourTypes  S.GUI suffix of each code (lhf.protocolInfo: odourTypes)
%   fixedRows   struct of row indices already chosen for a type (MTS picks the
%               Template and Sample rows as it prepares the trial), or struct()
%
%   Each type has a table: S.GUI.valves_<type>, dutyCycles_<type>,
%   probs_<type>. The row is fixedRows.<type> when given (the protocols draw
%   it as they prepare the trial, lhf.olf.drawRows), otherwise drawn with
%   probs_<type> from lhf.random(). The row's padding zeros are dropped. An
%   unknown code returns empty.

    valves = [];
    dutyCycles = [];
    type = '';
    if code < 1 || code > numel(odourTypes)
        disp(['Unknown odour SoftCode received: ' num2str(code)]);
        return
    end

    type = odourTypes{code};
    table = GUI.(['valves_' type]);
    duty  = GUI.(['dutyCycles_' type]);

    if isfield(fixedRows, type)
        row = fixedRows.(type);
    else
        drawn = lhf.olf.drawRows(GUI, {type});
        row = drawn.(type);
    end
    % Rows are padded with 0 to the longest sequence; 0 is no odour
    keep = table(row, :) > 0;
    valves = table(row, keep);
    dutyCycles = duty(row, keep);
end

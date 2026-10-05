function [um, note] = stagePosition(luminose, makeStages)
% lhf.stagePosition  The Zaber X/Y/Z now (um, as MATLAB counts them), or [] and why.
%
%   [um, note] = lhf.stagePosition(luminose)
%   [um, note] = lhf.stagePosition(luminose, makeStages)   makeStages: () -> rigStages
%
%   Uses the stages the Pattern Designer's camera column has connected, when
%   it has (it publishes them as setappdata(0, 'lhfStages', stages)): a port
%   can be opened only once. Otherwise opens calibration/rigStages, reads and
%   closes. Nothing moves. Never throws: um is [] and note says why.

    um = [];
    note = '';
    if isappdata(0, 'lhfStages')
        try
            um = readXYZ(getappdata(0, 'lhfStages'));
            return
        catch err
            note = ['the Pattern Designer''s stages: ' err.message '; '];
        end
    end
    if nargin < 2, makeStages = @() rigStages(luminose); end
    try
        stages = makeStages();
        closer = onCleanup(@() stages.close()); %#ok<NASGU> released however this ends
        um = readXYZ(stages);
        note = '';
    catch err
        note = [note err.message];
    end
end

function um = readXYZ(stages)
    um = [stages.x.positionUm(), stages.y.positionUm(), stages.z.positionUm()];
end

function [um, note] = stagePosition(~, makeStages)
% lhf.stagePosition  The Zaber X/Y/Z now (um, as MATLAB counts them), or [] and why.
%
%   [um, note] = lhf.stagePosition(luminose)
%   [um, note] = lhf.stagePosition(luminose, makeStages)   makeStages: () -> stages (tests)
%
%   Reads the rig's one X, Y and Z (lhf.device('stage'), the Stage panel's and the
%   Pattern Designer's too). Connected, they are read as they are; otherwise they are
%   connected, read and disconnected again, leaving them as they were. Nothing moves.
%   Never throws: um is [] and note says why.

    um = [];
    note = '';
    try
        if nargin < 2
            stages = lhf.device('stage');
        else
            stages = makeStages();
        end
        wasConnected = all(cellfun(@(n) strcmp(stages.(n).State, 'Ready'), {'x', 'y', 'z'}));
        if ~wasConnected
            for n = {'x', 'y', 'z'}
                if ~strcmp(stages.(n{1}).State, 'Ready')
                    stages.(n{1}).connect();
                end
            end
            closer = onCleanup(@() stages.close());  % as they were, however this ends
        end
        um = [stages.x.positionUm(), stages.y.positionUm(), stages.z.positionUm()];
    catch err
        note = err.message;
    end
end

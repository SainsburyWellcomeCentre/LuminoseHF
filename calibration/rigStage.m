function stage = rigStage(luminose)
% rigStage  The rig's Zaber Z stage, connected (nothing moves).
%
%   stage = rigStage(luminose)
%
%   A zaberstage.Stage (ZaberStage repo) on luminose.zaber.port, axis
%   luminose.zaber.axisIndex. Its limits start as the axis's own travel: narrow
%   stage.LimitsUm to the range a script needs. Release it with stage.disconnect().
    stage = zaberstage.Stage('Port', char(luminose.zaber.port), ...
        'AxisNumber', luminose.zaber.axisIndex);
    stage.connect();
end

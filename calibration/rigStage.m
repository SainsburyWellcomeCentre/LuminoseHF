function stage = rigStage(luminose)
% rigStage  The rig's Zaber Z stage, connected (nothing moves).
%
%   stage = rigStage(luminose)
%
%   A zaberstage.Stage (ZaberStage repo) on luminose.zaber.port, on the device and axis
%   of zaber.axes.z, kept within its safe_um (SafeLimitsUm, which a script cannot widen).
%   Its limits start as that safe range: narrow stage.LimitsUm to the range a script
%   needs. Release it with stage.disconnect().
    options = rigAxisOptions(luminose.zaber.axes, 'z');
    stage = zaberstage.Stage('Port', char(luminose.zaber.port), options{:});
    stage.connect();
end

function options = rigAxisOptions(axes, name)
% rigAxisOptions  The zaberstage.Stage options for one of the rig's axes, from zaber.axes.
%
%   options = rigAxisOptions(luminose.zaber.axes, 'x')
%
%   Name-value pairs DeviceAddress, AxisNumber, Reversed and SafeLimitsUm (its safe_um),
%   for rigStage and rigStages. Errors if the axis is missing or has no safe_um: no axis
%   moves without its safe range.
    if ~isfield(axes, name)
        error('rigAxisOptions:noAxis', ['zaber.axes in luminose_config.yaml has no %s axis ' ...
            '(device and axis): read them on the rig with zaberstage.listDevices or zaberstage.app.'], name);
    end
    a = axes.(name);
    if ~isfield(a, 'safe_um') || numel(a.safe_um) ~= 2
        error('rigAxisOptions:noSafeLimits', ['zaber.axes.%s in luminose_config.yaml has no ' ...
            'safe_um: [min max], the range (um, as MATLAB counts the axis) it may move in ' ...
            'without hitting anything (-Inf or Inf for an end of the travel).'], name);
    end
    options = {'DeviceAddress', a.device, 'AxisNumber', a.axis, ...
        'Reversed', isfield(a, 'reversed') && a.reversed, 'SafeLimitsUm', double(a.safe_um(:)')};
end

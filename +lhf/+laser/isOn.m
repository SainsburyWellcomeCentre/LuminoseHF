function on = isOn()
% lhf.laser.isOn  Whether this session controls the laser (lhf.laser.open connected it).
    global BpodSystem
    try
        on = isfield(BpodSystem.PluginObjects, 'Laser') && isa(BpodSystem.PluginObjects.Laser, 'LaserModel');
    catch
        on = false;  % no Bpod
    end
end

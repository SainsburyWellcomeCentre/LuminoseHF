function [irradiance, setpoint, action] = draw(design, patternType, S, luminose)
% lhf.laser.draw  The laser power for a trial showing a pattern, queued for soft code 13.
%
%   [irradiance, setpoint, action] = lhf.laser.draw(design, patternType, S, luminose)
%
%   design       the trial's pattern design (lhf.selectedDesign), or [] for none
%   patternType  its type ('CSplus', 'Left', 'Template', ...)
%
%   One irradiance is drawn, weighted, from the design's own list
%   (laserIrradiances_mWmm2, laserWeights: set in the Pattern Designer). A
%   design saved without a list uses the type's defaults
%   (S.GUIMeta.patternSel_<type>.LaserDefaults). The irradiance and its
%   setpoint are pushed onto BpodSystem.PluginObjects.LaserQueue, and action
%   is {'SoftCode', 13} for the trial's SetLaserPower state; lhf.laser.onSoftCode
%   pops them and sets the power.
%
%   Returns NaN, NaN, {} (no power set) when the laser is not under control
%   (lhf.laser.isOn) or there is no design to show.

    global BpodSystem

    irradiance = NaN;
    setpoint = NaN;
    action = {};
    if isempty(design) || ~lhf.laser.isOn()
        return
    end

    [irradiances, weights] = lhf.laser.options(design, patternType, S);
    if isempty(irradiances)
        return
    end
    k = find(rand() <= cumsum(weights / sum(weights)), 1);
    irradiance = irradiances(k);
    setpoint = lhf.laser.setpoint(irradiance, luminose);
    BpodSystem.PluginObjects.LaserQueue(end+1, :) = [irradiance setpoint];
    action = {'SoftCode', 13};
end

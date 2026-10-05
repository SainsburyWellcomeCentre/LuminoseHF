function onSoftCode()
% lhf.laser.onSoftCode  Soft code 13: set the laser to the next queued power.
%
%   Pops the next [irradiance setpoint] row of BpodSystem.PluginObjects.LaserQueue
%   (pushed by lhf.laser.draw as the trial was prepared) and sets the OBIS
%   setpoint. Emission stays gated by DMD pin 8. Errors are written to
%   <data file>_laser_log.txt with every power set, never thrown: a soft-code
%   callback must not stop the session.

    global BpodSystem

    try
        if ~lhf.laser.isOn()
            laserLog('ERROR: soft code 13 with no laser under control: power unchanged');
            return
        end
        if isempty(BpodSystem.PluginObjects.LaserQueue)
            laserLog('ERROR: soft code 13 with an empty laser queue: power unchanged');
            return
        end
        next = BpodSystem.PluginObjects.LaserQueue(1, :);
        BpodSystem.PluginObjects.LaserQueue(1, :) = [];
        BpodSystem.PluginObjects.Laser.setPower(next(2));
        laserLog(sprintf('irradiance=%.2f mW/mm^2 setpoint=%.1f mW', next(1), next(2)));
    catch err
        laserLog(sprintf('ERROR: %s at %s line %d', err.message, err.stack(1).name, err.stack(1).line));
    end
end

function laserLog(message)
    global BpodSystem
    [folder, name] = fileparts(BpodSystem.Path.CurrentDataFile);
    fid = fopen(fullfile(folder, [name '_laser_log.txt']), 'a');
    if fid < 0, return; end
    fprintf(fid, '[%s] %s\n', char(datetime('now', 'Format', 'HH:mm:ss.SSS')), message);
    fclose(fid);
end

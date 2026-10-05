function on = open(S, luminose)
% lhf.laser.open  Connect the laser for a session, if Laser control is ticked.
%
%   on = lhf.laser.open(S, luminose)
%
%   With S.GUI.LaserControl off (or absent) nothing is connected and the
%   session runs without the laser: no power is set, no soft code 13 is
%   sent, and the laser can be unplugged. The DMD's pin 8 still gates
%   emission, at whatever power the laser was left at.
%
%   With it on, the OBIS laser (obis.Laser) is connected in Digital mode with
%   emission enabled (gated by DMD pin 8, power set per trial by lhf.laser.draw
%   and soft code 13), refusing any power above luminose.laser.maxPower_mW. A
%   laser that does not connect stops the session here, before any trial,
%   with a message saying to untick Laser control to run without it.
%
%   Sets BpodSystem.PluginObjects.Laser (the obis.Laser, or absent) and an
%   empty LaserQueue, and reads the laser's status (output, temperature,
%   codes: obis.Laser.status) for the record lhf.laser.close keeps. Close
%   with lhf.laser.close.

    global BpodSystem

    lhf.laser.close(false);  % a laser left open by an aborted session
    BpodSystem.PluginObjects.LaserQueue = zeros(0, 2);
    lhf.laser.setpoint('reset');

    on = isfield(S.GUI, 'LaserControl') && logical(S.GUI.LaserControl);
    if ~on
        disp('Laser control off: the laser is not connected and its power is not set.');
        return
    end
    try
        laser = obis.Laser('Port', char(luminose.laser.port), ...
            'BaudRate', luminose.laser.baudRate, 'MaxPowermW', luminose.laser.maxPower_mW);
        laser.connect();
        laser.setMode('Digital');
        laser.setEnabled(true);
        BpodSystem.PluginObjects.Laser = laser;
        BpodSystem.PluginObjects.LaserStatusAtStart = readStatus(laser);
    catch err
        error('lhf:laser:connect', ['Laser control is on but the laser did not connect (%s): %s\n' ...
            'Untick Laser control on the Task tab to run without the laser.'], ...
            char(luminose.laser.port), err.message);
    end
    fprintf('Laser connected on %s: power set per trial from each pattern''s design.\n', char(luminose.laser.port));
end

function s = readStatus(laser)
% The laser's status now, or the reason it could not be read
    try
        s = laser.status();
    catch err
        s = struct('error', err.message);
    end
end

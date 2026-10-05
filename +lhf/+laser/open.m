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
%   With it on, the OBIS laser is opened in digital mode (emission gated by
%   DMD pin 8, power set per trial by lhf.laser.draw and soft code 13). A
%   laser that does not connect stops the session here, before any trial,
%   with a message saying to untick Laser control to run without it.
%
%   Sets BpodSystem.PluginObjects.Laser (the LaserModel, or absent) and an
%   empty LaserQueue. Close with lhf.laser.close.

    global BpodSystem

    lhf.laser.close();  % a laser left open by an aborted session
    BpodSystem.PluginObjects.LaserQueue = zeros(0, 2);
    lhf.laser.setpoint('reset');

    on = isfield(S.GUI, 'LaserControl') && logical(S.GUI.LaserControl);
    if ~on
        disp('Laser control off: the laser is not connected and its power is not set.');
        return
    end
    try
        BpodSystem.PluginObjects.Laser = LaserModel(luminose.laser, 'digital');
    catch err
        error('lhf:laser:connect', ['Laser control is on but the laser did not connect (%s): %s\n' ...
            'Untick Laser control on the Task tab to run without the laser.'], ...
            char(luminose.laser.port), err.message);
    end
    fprintf('Laser connected on %s: power set per trial from each pattern''s design.\n', char(luminose.laser.port));
end

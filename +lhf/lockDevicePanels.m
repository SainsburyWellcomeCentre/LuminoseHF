function lockDevicePanels(running)
% lhf.lockDevicePanels  Makes the Laser and DMD panels view only while a session runs.
%
%   lhf.lockDevicePanels(true)    at START (StartButtonPressed)
%   lhf.lockDevicePanels(false)   when the session ends (each protocol's cleanup)
%
%   During a session its own code drives the rig's laser (power per trial, emission) and
%   DMD (the prepared sequences), the same objects the panels control (lhf.device), so a
%   press on a panel would change what the session is doing. The open Laser and DMD
%   panels are locked (their lock/unlock: the state says "view only: session running";
%   the laser's Stop, emission off, stays usable), and lhf.devicePanel locks one opened
%   during the session. The camera and stage panels stay usable. The state is kept in
%   appdata 'lhfSessionRunning'. Never throws.
%
% See also lhf.devicePanel, lhf.device, StartButtonPressed

    setappdata(0, 'lhfSessionRunning', logical(running));
    panels = struct();
    if isappdata(0, 'lhfDevicePanels')
        panels = getappdata(0, 'lhfDevicePanels');
    end
    for name = {'laser', 'dmd'}
        if ~isfield(panels, name{1}), continue; end
        try
            if running
                panels.(name{1}).lock('session running');
            else
                panels.(name{1}).unlock();
            end
        catch
            % a closed panel, or one without lock
        end
    end
end

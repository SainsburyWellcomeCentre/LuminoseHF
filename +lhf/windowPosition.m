function position = windowPosition(name, sizeWH, screen)
% lhf.windowPosition  Where a LuminoseHF window opens: the rig's default layout.
%
%   position = lhf.windowPosition(name, [width height])
%   position = lhf.windowPosition(name, [width height], screen)   screen [x y w h] (tests)
%
%   name: 'parameters', 'camera', 'stage', 'laser', 'dmd', 'calibration' or
%   'designer'. Returns [x y width height] for the window's Position. Right to left
%   along the top of the screen:
%
%       [ dmd / calibration / designer ][ camera ][ parameters ]  <- top edge
%                     [ laser ][ stage ]
%
%   The parameter GUI at the right edge, the camera left of it, the DMD, Calibration
%   and Pattern Designer windows left of the camera (sharing that place), all aligned
%   to the top; the stage below the camera, and the laser left of the stage, aligned
%   to its top. Each is placed from where its neighbours actually are when they are
%   open (the parameter GUI, BpodSystem.ProtocolFigures.ParameterGUI; the panels,
%   lhf.devicePanel's), else from their default sizes, so a window moved by hand
%   moves those opened after it. A window that does not fit goes as low as the
%   taskbar allows and is not shortened.
%
% See also lhf.devicePanel, gui/PatternDesigner, gui/CalibrationApp

    if nargin < 3, screen = get(groot, 'ScreenSize'); end
    name = validatestring(name, {'parameters', 'camera', 'stage', 'laser', 'dmd', ...
        'calibration', 'designer'});
    TITLE = 32;     % a window's title bar, above its Position
    GAP = 2;        % between windows: their 1-px borders lie outside Position
    TASKBAR = 48;
    top = screen(2) + screen(4) - 1 - TITLE;      % the highest a window's Position reaches
    rightEdge = screen(1) + screen(3) - 1 - 1;  % the window's own border
    w = sizeWH(1);
    h = sizeWH(2);

    switch name  % each asks only for the neighbours it sits against
        case 'parameters'
            x = rightEdge - w;
            y = top - h;
        case 'camera'
            params = placed('parameters', [450 1300]);
            x = params(1) - GAP - w;
            y = top - h;
        case {'dmd', 'calibration', 'designer'}
            camera = placed('camera', [640 900]);
            x = camera(1) - GAP - w;
            y = top - h;
        case 'stage'
            camera = placed('camera', [640 900]);
            x = camera(1);
            y = camera(2) - TITLE - GAP - h;
        case 'laser'
            stage = placed('stage', [640 275]);
            x = stage(1) - GAP - w;
            y = stage(2) + stage(4) - h;   % tops aligned
    end
    x = max(x, screen(1));
    y = max(y, min(screen(2) + TASKBAR, top - h));
    position = [x y w h];

    function p = placed(other, defaultSize)
        % Where another window is, if open, else where it would open.
        fig = openFigure(other);
        if ~isempty(fig)
            p = fig.Position;
        else
            p = lhf.windowPosition(other, defaultSize, screen);
        end
    end
end


function fig = openFigure(name)
% The figure of an open window, or [].
    global BpodSystem %#ok<GVMIS> Bpod's
    fig = [];
    try
        switch name
            case 'parameters'
                candidate = BpodSystem.ProtocolFigures.ParameterGUI;
            otherwise
                panels = getappdata(0, 'lhfDevicePanels');
                candidate = panels.(name).Figure;
        end
        if ~isempty(candidate) && isvalid(candidate) && ~isempty(candidate.Position)
            fig = candidate;
        end
    catch
    end
end

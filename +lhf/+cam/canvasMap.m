function map = canvasMap(reg, camSize, canvasSize, scale)
% lhf.cam.canvasMap  Which camera pixel each Pattern Designer canvas pixel shows.
%
%   map = lhf.cam.canvasMap(reg, camSize, canvasSize, scale)
%
%   reg: lhf.cam.fitRegistration. camSize: the frame's [rows cols].
%   canvasSize: the canvas's [rows cols]; canvas pixel (i, j) is DMD pixel
%   ((j - 0.5) * scale, (i - 0.5) * scale), as the designer places spots at
%   canvas point * scale. map(i, j) is the linear index of the nearest camera
%   pixel, 0 where the camera does not see that part of the DMD field. Built
%   once per calibration and frame size; lhf.cam.toCanvas applies it to
%   every frame.

    [col, row] = meshgrid(1:canvasSize(2), 1:canvasSize(1));
    cam = lhf.cam.toCamera(reg, [(col(:) - 0.5) * scale, (row(:) - 0.5) * scale]);
    x = round(cam(:, 1));
    y = round(cam(:, 2));
    inside = x >= 1 & x <= camSize(2) & y >= 1 & y <= camSize(1);
    map = zeros(canvasSize);
    map(inside) = sub2ind(camSize, y(inside), x(inside));
end

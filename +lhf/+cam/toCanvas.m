function img = toCanvas(frame, map)
% lhf.cam.toCanvas  A camera frame as the Pattern Designer canvas shows it.
%
%   img = lhf.cam.toCanvas(frame, map)
%
%   map from lhf.cam.canvasMap. Same class as frame; 0 where the camera does
%   not see the DMD field. Cheap enough for every live frame.

    img = zeros(size(map), 'like', frame);
    seen = map > 0;
    img(seen) = frame(map(seen));
end

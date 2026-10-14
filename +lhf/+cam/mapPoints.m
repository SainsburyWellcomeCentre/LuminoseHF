function xy = mapPoints(xy, transform, direction)
% lhf.cam.mapPoints  Points between an animal's reference frame and the current frame.
%
%   xyFrame = lhf.cam.mapPoints(xyRef, transform, 'toFrame')
%   xyRef   = lhf.cam.mapPoints(xyFrame, transform, 'toReference')
%   transform = lhf.cam.mapPoints(r, cropSize)        from lhf.cam.register's result
%   transform = lhf.cam.mapPoints('identity')
%
%   xy: n-by-2 [x y] camera px (frame px or full-sensor px alike, as long as both frames
%   read out the same: the shift is in the frame's px). transform: shiftPx, rotationDeg
%   and centre (the registered crop's centre, frame px): a point p of the reference
%   lies at centre + R(rotationDeg) * (p - centre) + shiftPx in the frame. Built from
%   r = lhf.cam.register(reference, frame, 'Crop', crop) and the crop's [width height]
%   ([] for the whole frame: give the frame's size).
%
% See also lhf.cam.register, lhf.cam.saveTargets

    if ischar(xy) && strcmp(xy, 'identity')
        xy = struct('shiftPx', [0 0], 'rotationDeg', 0, 'centre', [0 0]);
        return
    end
    if isstruct(xy)  % (r, cropSize): the transform
        r = xy;
        cropSize = double(transform(:)');
        xy = struct('shiftPx', double(r.shiftPx(:)'), 'rotationDeg', double(r.rotationDeg), ...
            'centre', double(r.origin(:)') + cropSize / 2 + 0.5);
        return
    end
    c = transform.centre;
    a = transform.rotationDeg;
    R = [cosd(a) -sind(a); sind(a) cosd(a)];
    switch direction
        case 'toFrame'
            xy = (xy - c) * R' + c + transform.shiftPx;
        case 'toReference'
            xy = (xy - c - transform.shiftPx) * R + c;
        otherwise
            error('lhf:cam:badDirection', 'direction is ''toFrame'' or ''toReference''.');
    end
end

function camXY = toCamera(reg, dmdXY)
% lhf.cam.toCamera  DMD pixels to camera pixels.
%
%   camXY = lhf.cam.toCamera(reg, dmdXY)
%
%   reg from lhf.cam.fitRegistration; dmdXY n-by-2 [x y].

    camXY = [double(dmdXY), ones(size(dmdXY, 1), 1)] * reg.A;
end

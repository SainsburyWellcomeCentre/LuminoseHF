function dmdXY = toDmd(reg, camXY)
% lhf.cam.toDmd  Camera pixels to DMD pixels.
%
%   dmdXY = lhf.cam.toDmd(reg, camXY)
%
%   reg from lhf.cam.fitRegistration; camXY n-by-2 [x y].

    dmdXY = [double(camXY), ones(size(camXY, 1), 1)] * reg.Ainv;
end

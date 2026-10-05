function reg = fitRegistration(dmdXY, camXY)
% lhf.cam.fitRegistration  The affine map between DMD pixels and camera pixels.
%
%   reg = lhf.cam.fitRegistration(dmdXY, camXY)
%
%   dmdXY, camXY: n-by-2 [x y] of the same n >= 3 points (not on one line),
%   in DMD pixels and in camera pixels. Fits camXY = [dmdXY 1] * A by least
%   squares. reg.A (3x2) maps DMD to camera, reg.Ainv (3x2) camera to DMD,
%   reg.residualPx the camera-pixel distance of each point from the fit,
%   reg.rmsPx their root mean square, plus the points. Used through
%   lhf.cam.toCamera and lhf.cam.toDmd; calibration/calibrate_camera_dmd.m
%   measures the points.

    if size(dmdXY, 2) ~= 2 || ~isequal(size(dmdXY), size(camXY)) || size(dmdXY, 1) < 3
        error('lhf:cam:badPoints', 'Give the same n >= 3 points as n-by-2 [x y] in DMD and camera pixels.');
    end
    X = [double(dmdXY), ones(size(dmdXY, 1), 1)];
    if rank(X) < 3
        error('lhf:cam:badPoints', 'The points lie on one line: an affine map cannot be fitted.');
    end
    A = X \ double(camXY);
    M = [A, [0; 0; 1]];  % [x y 1] * M = [x' y' 1]
    Minv = inv(M);
    residual = X * A - double(camXY);

    reg = struct();
    reg.A = A;
    reg.Ainv = Minv(:, 1:2);
    reg.residualPx = hypot(residual(:, 1), residual(:, 2));
    reg.rmsPx = sqrt(mean(reg.residualPx .^ 2));
    reg.dmdXY = double(dmdXY);
    reg.camXY = double(camXY);
end

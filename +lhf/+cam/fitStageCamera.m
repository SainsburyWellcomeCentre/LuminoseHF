function cal = fitStageCamera(movesUm, shiftsPx)
% lhf.cam.fitStageCamera  How a stage move shifts the camera image.
%
%   cal = lhf.cam.fitStageCamera(movesUm, shiftsPx)
%
%   movesUm: n-by-2 [x y] stage moves (um); shiftsPx: n-by-2 [dx dy] image
%   shifts they caused (camera px, lhf.cam.register), n >= 2 moves not along
%   one line. Fits shiftsPx' = C * movesUm' by least squares: C (2x2, camera
%   px per um) holds the stage-camera rotation, each axis's direction and the
%   scale. cal.C, cal.Cinv (um per camera px), cal.pxPerUm (sqrt |det C|),
%   cal.rotationDeg (of the stage X axis on the camera), cal.residualPx,
%   cal.rmsPx and the points. calibration/calibrate_stage_camera.m measures them.

    if size(movesUm, 2) ~= 2 || ~isequal(size(movesUm), size(shiftsPx)) || rank(double(movesUm)) < 2
        error('lhf:cam:badMoves', 'Give n-by-2 stage moves (not along one line) and the n-by-2 shifts they caused.');
    end
    M = double(movesUm);
    P = double(shiftsPx);
    C = (M \ P)';  % P = M * C'
    residual = M * C' - P;

    cal = struct();
    cal.C = C;
    cal.Cinv = inv(C);
    cal.pxPerUm = sqrt(abs(det(C)));
    cal.rotationDeg = atan2d(C(2, 1), C(1, 1));
    cal.residualPx = hypot(residual(:, 1), residual(:, 2));
    cal.rmsPx = sqrt(mean(cal.residualPx .^ 2));
    cal.movesUm = M;
    cal.shiftsPx = P;
end

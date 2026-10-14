function plot(result, parent)
% lhf.cal.plot  Draws a calibration's result.
%
%   lhf.cal.plot(result, parent)
%
%   result from lhf.cal.run or lhf.cal.load; parent a figure or panel (cleared).
%       cameraDmd    the dark frame with the spots found (red), the fit (green) and
%                    the DMD field (yellow); each spot's residual
%       stageCamera  each move's measured image shift and the fit's
%       zFocus       frame intensity against Z, with the best focus
%       power        power at the sample against setpoint; camera counts against
%                    power at the sample (saturated in red)
%
% See also lhf.cal.run, lhf.cal.save

    delete(parent.Children);
    layout = tiledlayout(parent, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    data = result.data;
    switch result.id
        case 'cameraDmd'
            reg = data.registration;
            ax = nexttile(layout);
            if isfield(data, 'background') && ~isempty(data.background)
                imagesc(ax, data.background);
                colormap(ax, gray);
            end
            axis(ax, 'image');
            set(ax, 'YDir', 'reverse', 'SortMethod', 'childorder');  % markers on one spot both show
            hold(ax, 'on');
            toFrame = @(xy) sensorToFrame(reg, xy);
            plot(ax, NaN, NaN);  % keeps the image when the lines below are empty
            measured = toFrame(reg.camXY);
            fitted = toFrame(lhf.cam.toCamera(reg, reg.dmdXY));
            w = reg.dmdSize(2);
            h = reg.dmdSize(1);
            field = toFrame(lhf.cam.toCamera(reg, [0.5 0.5; w + 0.5 0.5; w + 0.5 h + 0.5; 0.5 h + 0.5; 0.5 0.5]));
            plot(ax, field(:, 1), field(:, 2), 'y-');
            plot(ax, measured(:, 1), measured(:, 2), 'ro', 'MarkerSize', 9, 'LineWidth', 1.2);
            plot(ax, fitted(:, 1), fitted(:, 2), 'g+', 'MarkerSize', 7, 'LineWidth', 1.2);
            hold(ax, 'off');
            title(ax, sprintf('%d spots: found (red), fit (green), DMD field (yellow)', size(reg.dmdXY, 1)));
            ax = nexttile(layout);
            bar(ax, reg.residualPx);
            xlabel(ax, 'Spot');
            ylabel(ax, 'Residual (camera px)');
            title(ax, sprintf('rms %.2f px; %.4f camera px per DMD px, %.1f deg', reg.rmsPx, ...
                sqrt(abs(det(reg.A(1:2, :)))), atan2d(reg.A(1, 2), reg.A(1, 1))));
        case 'stageCamera'
            cal = data.stageCamera;
            ax = nexttile(layout);
            fitted = (cal.C * cal.movesUm')';
            plot(ax, cal.shiftsPx(:, 1), cal.shiftsPx(:, 2), 'ro', fitted(:, 1), fitted(:, 2), 'g+', ...
                'MarkerSize', 10);
            hold(ax, 'on');
            for k = 1:size(cal.movesUm, 1)
                text(ax, cal.shiftsPx(k, 1), cal.shiftsPx(k, 2), sprintf('  X %+g, Y %+g um', cal.movesUm(k, :)));
            end
            hold(ax, 'off');
            axis(ax, 'equal');
            grid(ax, 'on');
            xlabel(ax, 'Image shift x (camera px)');
            ylabel(ax, 'Image shift y (camera px)');
            title(ax, 'Measured (red) and fitted (green) shifts');
            ax = nexttile(layout);
            bar(ax, cal.residualPx);
            xlabel(ax, 'Move');
            ylabel(ax, 'Residual (camera px)');
            title(ax, sprintf('%.4f px/um, X at %.1f deg, rms %.2f px', cal.pxPerUm, cal.rotationDeg, cal.rmsPx));
        case 'zFocus'
            r = data.results;
            ax = nexttile(layout, [1 2]);
            plot(ax, r.zPositions_um / 1e3, r.totalIntensity, 'b-o', 'MarkerSize', 3);
            xline(ax, r.nominalFocus_um / 1e3, 'k--', 'Centre');
            xline(ax, r.bestFocus_mm, 'r--', sprintf('Best %.4f mm', r.bestFocus_mm));
            grid(ax, 'on');
            xlabel(ax, 'Z (mm)');
            ylabel(ax, 'Total frame intensity');
            title(ax, sprintf('Best focus %.4f mm (%+.0f um from the centre)', r.bestFocus_mm, ...
                r.offsetFromNominal_um));
        case 'power'
            r = data.results;
            ax = nexttile(layout);
            if isfield(r, 'meterSd_mW') && any(isfinite(r.meterSd_mW))
                errorbar(ax, r.power_setting_mW, r.power_at_sample_mW, r.meterSd_mW, 'b.-', 'MarkerSize', 12);
            else
                plot(ax, r.power_setting_mW, r.power_at_sample_mW, 'b.-', 'MarkerSize', 12);
            end
            grid(ax, 'on');
            xlabel(ax, 'Laser setpoint (mW)');
            ylabel(ax, 'Power at the sample (mW)');
            title(ax, 'Setpoint against power at the sample');
            ax = nexttile(layout);
            ok = ~r.saturated;
            plot(ax, r.power_at_sample_mW(ok), r.intensity_at_camera(ok), 'k.-', 'MarkerSize', 12);
            hold(ax, 'on');
            plot(ax, r.power_at_sample_mW(~ok), r.intensity_at_camera(~ok), 'r.', 'MarkerSize', 16);
            hold(ax, 'off');
            grid(ax, 'on');
            xlabel(ax, 'Power at the sample (mW)');
            ylabel(ax, 'Mean camera counts, lit field');
            title(ax, 'Camera intensity (saturated in red)');
    end
end


function xy = sensorToFrame(reg, xy)
% Full-sensor px to the frame read out while calibrating (hamacam's convention).
    n = 1;
    offset = [0 0];
    if isfield(reg, 'binning') && ~isempty(reg.binning), n = double(reg.binning); end
    if isfield(reg, 'roi') && ~isempty(reg.roi), offset = double(reg.roi(1:2)); end
    xy = (double(xy) - 0.5) / n - offset + 0.5;
end

function [data, messages] = power(d, s, hooks, luminose)
% lhf.cal.power  Laser setpoint against power at the sample (and camera intensity).
%
%   [data, messages] = lhf.cal.power(devices, settings, hooks, luminose)
%
%   Run it through lhf.cal.run('power', ...) or the Calibration window. With every
%   DMD mirror on and the laser in CW power mode, steps through setpointsmW; at each,
%   after settleS, reads the power meter (devices.meter.read(n): mean mW of n
%   readings, the PM100D at the sample plane) and, if useCamera, the mean camera
%   counts over the lit field (found once, at the highest setpoint). Without a meter
%   the power at the sample comes from dmd/power_calibration.csv for the same
%   setpoints. Emission starts off and is turned off however it ends; the DMD halts.
%
%   data: table (power_setting_mW, power_at_sample_mW, intensity_at_camera: what
%   lhf.cal.save writes to dmd/power_calibration.csv), results (as calibrate_power
%   saved them: power_setting_mW, power_at_sample_mW, intensity_at_camera, illumMask,
%   saturated, meterSd_mW, calibrationFile, laser and camera records), csvFile.
%   messages: setpoints the CSV has no power for, saturated frames.
%
% See also lhf.cal.run, irradianceCalibration, lhf.cal.powerMeter

    laser = d.laser;
    dmd = d.dmd;
    cam = d.camera;
    meter = d.meter;
    messages = {};
    csvFile = fullfile(char(luminose.f.luminose_hf), 'dmd', 'power_calibration.csv');
    setpoints = s.setpointsmW(:);
    n = numel(setpoints);

    atSample = nan(n, 1);
    if isempty(meter)
        try
            old = readtable(csvFile);
            [known, row] = ismembertol(setpoints, old.power_setting_mW, 1e-9, 'DataScale', 1);
            atSample(known) = old.power_at_sample_mW(row(known));
            if any(~known)
                messages{end + 1} = sprintf(['The CSV has no power at the sample for %s mW: ' ...
                    'measure them with the meter.'], mat2str(setpoints(~known)'));
            end
        catch err
            messages{end + 1} = sprintf('No power at the sample: %s', err.message);
        end
    end

    closer = onCleanup(@() finish(laser, dmd));
    laser.setEnabled(false);
    laser.setMode('CWP');
    dmdSize = dmdFrameSize(dmd);
    dmd.displayFrame(true(dmdSize));
    pause(0.5);
    laser.setEnabled(true);

    mask = [];
    maxCount = 65535;
    try maxCount = cam.MaxCount; catch, end
    if s.useCamera
        step(hooks, 0, sprintf('Finding the lit field at %g mW', max(setpoints)));
        laser.setPower(max(setpoints));
        pause(s.settleS);
        reference = double(cam.capture());
        hooks.frame(uint16(reference));
        smoothed = imgaussfilt(reference, 5);
        mask = smoothed > 0.15 * max(smoothed(:));
        mask = imfill(bwareafilt(mask, 1), 'holes');
    end

    intensity = nan(n, 1);
    saturated = false(n, 1);
    meterSd = nan(n, 1);
    for k = 1:n
        step(hooks, k / (n + 1), sprintf('%g mW (%d of %d)', setpoints(k), k, n));
        laser.setPower(setpoints(k));
        pause(s.settleS);
        if ~isempty(meter)
            [atSample(k), meterSd(k)] = meter.read(s.meterSamples);
        end
        if s.useCamera
            frame = cam.capture();
            hooks.frame(frame);
            intensity(k) = mean(double(frame(mask)));
            saturated(k) = max(frame(:)) >= 0.95 * maxCount;
        end
    end
    clear closer  % emission off, DMD halted
    if any(saturated)
        messages{end + 1} = sprintf(['%d setpoint(s) saturated the camera (%s mW): lower the ' ...
            'exposure.'], nnz(saturated), mat2str(setpoints(saturated)'));
    end

    tbl = table(setpoints, atSample, intensity, 'VariableNames', ...
        {'power_setting_mW', 'power_at_sample_mW', 'intensity_at_camera'});
    results = struct('power_setting_mW', setpoints, 'power_at_sample_mW', atSample, ...
        'intensity_at_camera', intensity, 'illumMask', mask, 'saturated', saturated, ...
        'meterSd_mW', meterSd, 'calibrationFile', csvFile, 'laser', laser.record(), ...
        'camera', cam.record());
    step(hooks, 1, sprintf('%d setpoints, %g - %g mW at the sample', n, min(atSample), max(atSample)));
    data = struct('table', tbl, 'results', results, 'csvFile', csvFile);
end


function finish(laser, dmd)
    try laser.setEnabled(false); catch, end
    try laser.stopAll(); catch, end
    haltQuietly(dmd);
end

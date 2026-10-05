function camera = rigCamera(luminose)
% rigCamera  The rig's Hamamatsu camera, connected, with the config's exposure and averaging.
%
%   camera = rigCamera(luminose)
%
%   A hamacam.Camera (HamamatsuCam repo) built from luminose.camera in
%   luminose_config.yaml: device, adaptor DLL, exposureTime_ms, nAverageFrames.
%   Release it with camera.disconnect().
    cfg = luminose.camera;
    camera = hamacam.Camera('DeviceID', cfg.deviceID, 'DllPath', char(cfg.adaptorDllPath), ...
        'ExposureMs', cfg.exposureTime_ms, 'AverageFrames', cfg.nAverageFrames);
    camera.connect();
end

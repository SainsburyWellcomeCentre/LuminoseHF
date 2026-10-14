function folder = useSubjectFolder(subject, app, dataFolder)
% lhf.cam.useSubjectFolder  Points the Camera panel's Save to folder at a subject's folder.
%
%   folder = lhf.cam.useSubjectFolder()                    the Bpod subject, the open panel
%   folder = lhf.cam.useSubjectFolder(subject)
%   folder = lhf.cam.useSubjectFolder(subject, app, dataFolder)
%
%   Makes lhf.cam.subjectFolder(dataFolder, subject) (<data>/<subject>/luminose_hf_widefield)
%   if needed and sets it as the panel's Save to folder, so Save frame and Save each
%   capture write there. app: a hamacam.gui.CameraApp (default: the Camera panel, if open);
%   dataFolder: default the config's paths.dataFolder. With no subject or no panel it
%   changes nothing and returns ''. Never throws: a folder that cannot be made leaves the
%   panel's folder as it was. Called when the Camera panel opens or comes to the front
%   (lhf.devicePanel), at START, and when the Pattern Designer's animal is set.
%
% See also lhf.cam.subjectFolder, lhf.devicePanel, lhf.subjectName

    folder = '';
    try
        if nargin < 1, subject = lhf.subjectName(); end
        if nargin < 2 || isempty(app), app = openPanel(); end
        if isempty(app) || isempty(strtrim(char(subject)))
            return
        end
        if nargin < 3 || isempty(dataFolder), dataFolder = configData(); end
        target = lhf.cam.subjectFolder(dataFolder, subject);
        if ~isfolder(target)
            mkdir(target);
        end
        if ~strcmp(app.SaveFolder, target)
            app.setSaveFolder(target);
        end
        folder = target;
    catch
    end
end


function app = openPanel()
% The Camera panel lhf.devicePanel opened, if it is still open.
    app = [];
    if isappdata(0, 'lhfDevicePanels')
        panels = getappdata(0, 'lhfDevicePanels');
        if isfield(panels, 'camera') && isvalid(panels.camera)
            app = panels.camera;
        end
    end
end


function folder = configData()
% paths.dataFolder, from the protocols' luminose global or the rig's config.
    global luminose %#ok<GVMIS> the protocols' global
    config = luminose;
    if isempty(config)
        config = LuminoseConstants();
    end
    folder = char(config.f.luminoseData);
end

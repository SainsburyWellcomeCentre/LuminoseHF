function folder = subjectFolder(dataFolder, subject)
% lhf.cam.subjectFolder  Where the camera's images of a subject are saved.
%
%   folder = lhf.cam.subjectFolder(luminose.f.luminoseData, subject)
%
%   <dataFolder>/<subject>/luminose_hf_widefield, beside the subject's Bpod protocol
%   folders (any character a folder name cannot hold becomes _); '' for no subject. It is
%   not created here: lhf.cam.useSubjectFolder makes it when the Camera panel saves there.
%
% See also lhf.cam.useSubjectFolder, lhf.subjectName

    subject = strtrim(char(subject));
    folder = '';
    if isempty(subject)
        return
    end
    folder = fullfile(char(dataFolder), regexprep(subject, '[^\w\-]', '_'), 'luminose_hf_widefield');
end

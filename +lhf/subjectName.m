function name = subjectName()
% lhf.subjectName  The Bpod subject (animal) selected, or '' outside Bpod.
%
%   name = lhf.subjectName()
%
%   The launch manager always sets GUIData.SubjectName; Status.CurrentSubjectName
%   only when the subject list's selection changes.

    global BpodSystem
    name = '';
    try
        if isfield(BpodSystem.GUIData, 'SubjectName')
            name = char(BpodSystem.GUIData.SubjectName);
        end
        if isempty(name)
            name = char(BpodSystem.Status.CurrentSubjectName);
        end
    catch
    end
end

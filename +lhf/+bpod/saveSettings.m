function file = saveSettings(action)
% lhf.bpod.saveSettings  Saves the protocol's settings to the subject's settings file, also after Stop.
%
%   file = lhf.bpod.saveSettings('remember')   at START: notes BpodSystem.Path.Settings
%   file = lhf.bpod.saveSettings('save')       in cleanup: saves BpodSystem.ProtocolSettings
%
%   Bpod's SaveBpodProtocolSettings saves to BpodSystem.Path.Settings, which Bpod's Stop
%   button (RunProtocol('Stop')) empties before the protocol's cleanup runs; the settings
%   then went to matlab.mat in the current folder, the protocol's own (RunProtocol runs it
%   with run()), and the subject's file kept the previous session's (until 2026-10-21).
%   'save' uses Path.Settings when set and the remembered file otherwise; with neither it
%   saves nothing. file: the file used ('' for none).
%
% See also SaveBpodProtocolSettings, lhf.mergeSettings

    global BpodSystem %#ok<GVMIS> Bpod's
    persistent remembered
    if isempty(remembered), remembered = ''; end
    file = '';
    if isfield(BpodSystem.Path, 'Settings'), file = char(BpodSystem.Path.Settings); end
    switch action
        case 'remember'
            remembered = file;
        case 'save'
            if isempty(file), file = remembered; end
            if isempty(file), return; end
            ProtocolSettings = BpodSystem.ProtocolSettings; %#ok<NASGU> saved under Bpod's name
            save(file, 'ProtocolSettings');
    end
end

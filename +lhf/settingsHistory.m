function history = settingsHistory(protocol)
% lhf.settingsHistory  Renamed and retired settings, for loading older settings files.
%
%   history = lhf.settingsHistory(protocol)
%
%   history.renamed  n-by-2 cell {oldName, newName} of S.GUI fields
%   history.retired  names of S.GUI fields that no longer exist
%
%   lhf.mergeSettings reads this so a saved value follows its setting when
%   it is renamed, and a removed setting is dropped with a note rather than
%   silently carried on. To rename a setting: rename it in GUIparams_*, add
%   {old, new} here (for every protocol that has it) and note it in
%   docs/data-format.md. Never reuse a retired name for something else.

    history.renamed = cell(0, 2);
    history.retired = {};

    switch protocol
        case {'goNogo', 'powercal', '2AFC', 'MTS'}
            % 2026-09-29: removed; the next trial is prepared before the
            % running one's outcome is known (lhf.nextTrialType)
            history.retired{end+1} = 'RepeatOnError';
            % 2026-10-02: a cue or stimulus lasts as long as its pattern
            % design or odour sequence, or the Duration in its Light or Sound
            % panel (LightDuration_<type>, SoundDuration_<type>)
            history.retired = [history.retired, {'CueTime', 'StimTime'}];
            % 2026-10-02: the sniff is always detected on a falling signal
            % (the rising-edge hand test is gone); Sniff Trigger is new
            history.retired{end+1} = 'SniffRising';
            if strcmp(protocol, 'powercal')
                % 2026-09-30: the CS- central spot is a default design
                % (editable in the Pattern Designer), not hard-coded
                history.retired = [history.retired, {'CentralSpotSide_um', 'CentralSpotDur_ms'}];
                % 2026-09-30: laser power is set per pattern design, in the
                % Pattern Designer, not by one list per session or trial type
                history.retired = [history.retired, {'LaserIrradiances_mWmm2', 'LaserIrradianceProbs', ...
                    'LaserIrradiances_CSplus', 'LaserIrradianceProbs_CSplus', ...
                    'LaserIrradiances_CSminus', 'LaserIrradianceProbs_CSminus'}];
                % 2026-10-01: the fixed training power is the design's own
                % list too (save a design with one irradiance for a fixed power)
                history.retired{end+1} = 'TrainingIrradiance_mWmm2';
                % 2026-10-02: the spot size is set in the Pattern Designer
                % and saved with each design
                history.retired{end+1} = 'dmdSpotSide';
            end
        case 'sleep'
            % 2026-10-02: the sniff is always detected on a falling signal
            history.retired{end+1} = 'SniffRising';
        otherwise
            error('lhf:settingsHistory:protocol', 'Unknown protocol ''%s''.', protocol);
    end
end

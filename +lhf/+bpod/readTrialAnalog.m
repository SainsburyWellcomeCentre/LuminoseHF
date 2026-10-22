function [t, volts] = readTrialAnalog(file, nChannels, trial, rate, folder)
% lhf.bpod.readTrialAnalog  One trial's Flex I/O analog samples, read from the session's _ANLG.dat.
%
%   [t, volts] = lhf.bpod.readTrialAnalog(file, nChannels, trial, rate)
%   [t, volts] = lhf.bpod.readTrialAnalog(file, nChannels, trial, rate, folder)
%
%   file       the session's analog data file, its name or Bpod's open file id
%              (BpodSystem.AnalogDataFile; Bpod writes the samples as they come)
%   nChannels  Flex channels configured as analog inputs
%   trial      the trial wanted (the trial number Bpod writes with each sample)
%   rate       samples per second (BpodSystem.HW.FlexIO_SamplingRate)
%   folder     where to look for a relative name not found from the current folder: the
%              session's data folder. RunProtocol opens the file by a relative name, then
%              runs the protocol with run(), which moves to the protocol's folder; the
%              Launch Manager gives the full path, beside the session's data.
%   t          seconds from the trial's first sample (column)
%   volts      one column per channel, 0-5 V
%
%   Each sample in the file is uint16 [trial ch1 ... chN], 12-bit values. Only the bytes
%   added since the last call are read (the offset and the samples of trials not yet
%   asked for are kept per file), so a call per trial costs the same all session.
%   A trial with no samples yet, or no file (analog recording off), gives empty t and
%   volts. Never throws.
%
% See also lhf.plot.analog

    persistent state
    t = zeros(0, 1);
    volts = zeros(0, nChannels);
    try
        if isnumeric(file)
            file = fopen(file);  % the name of Bpod's open file
        end
        file = char(file);
        if ~isempty(file) && ~isfile(file) && nargin > 4
            file = fullfile(folder, file);  % a relative name, not where the current folder is
        end
        if isempty(file) || ~isfile(file), return; end
        if isempty(state) || ~strcmp(state.file, file) || state.nChannels ~= nChannels
            state = struct('file', file, 'nChannels', nChannels, 'offset', 0, ...
                'rows', zeros(0, nChannels + 1, 'uint16'));
        end
        rowBytes = 2 * (nChannels + 1);
        fid = fopen(file, 'r');
        if fid < 0, return; end
        closer = onCleanup(@() fclose(fid));
        fseek(fid, 0, 'eof');
        nRows = floor((ftell(fid) - state.offset) / rowBytes);
        if nRows > 0
            fseek(fid, state.offset, 'bof');
            raw = fread(fid, nRows * (nChannels + 1), '*uint16');
            state.offset = state.offset + nRows * rowBytes;
            state.rows = [state.rows; reshape(raw, nChannels + 1, nRows)'];
        end
        state.rows = state.rows(state.rows(:, 1) >= trial, :);  % earlier trials are done with
        mine = state.rows(state.rows(:, 1) == trial, 2:end);
        volts = double(mine) / 4095 * 5;
        t = (0:size(volts, 1) - 1)' / rate;
    catch
        t = zeros(0, 1);
        volts = zeros(0, nChannels);
    end
end

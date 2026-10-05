function trial = fakeTrial(varargin)
% fakeTrial  A Data.RawEvents.Trial{n} struct for tests.
%
%   trial = fakeTrial('Reward', [3 3.1], 'GetResponse', [2 3], 'BNC1High', 2.5)
%
%   Names ending in 'High'/'Low' or 'In'/'Out' are events (times); the rest
%   are states ([start end] rows). States not given are absent, as Bpod
%   leaves out states a trial's state machine did not define.

    trial.States = struct();
    trial.Events = struct();
    for k = 1:2:numel(varargin)
        name = varargin{k};
        value = varargin{k + 1};
        if endsWith(name, {'High', 'Low', 'In', 'Out'})
            trial.Events.(name) = value;
        else
            trial.States.(name) = value;
        end
    end
end

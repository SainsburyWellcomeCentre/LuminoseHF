function data = readEncoder(R, varargin)
% lhf.bpod.readEncoder  R.readUSBStream with the encoder's own capture timer paused.
%
%   data = lhf.bpod.readEncoder(R, eventCode)   as R.readUSBStream(eventCode)
%
%   RotaryEncoderModule.startUSBStream starts a timer (tag 'RE_<port>') that reads the
%   encoder's serial port every few ms. The trial loop's own read of the same port could
%   be interrupted by it ("Another read operation is attempting to interrupt the current
%   read operation", seen 2026-10-10 and 10-14). The timer is stopped for the read and
%   started again after, also when the read fails; nothing is lost, as readUSBStream
%   takes all the port holds.
%
% See also RotaryEncoderModule, lhf.bpod.stopStrayTrialTimers

    timers = timerfindall('Tag', ['RE_' R.Port.PortName]);
    if isempty(timers)
        paused = timers;
    else
        paused = timers(strcmp({timers.Running}, 'on'));
    end
    if ~isempty(paused)
        stop(paused);
    end
    restart = onCleanup(@() startAgain(paused)); %#ok<NASGU> also when the read fails
    data = R.readUSBStream(varargin{:});
end

function startAgain(timers)
    for k = 1:numel(timers)
        if isvalid(timers(k)) && strcmp(timers(k).Running, 'off')
            start(timers(k));
        end
    end
end

classdef DMDPatternPlayer < handle
% DMDPatternPlayer  Uploads DMD sequences ahead of the trial that shows them.
%
%   Frame rendering and upload happen in the prepare window (while the
%   previous trial runs), never inside a soft-code callback:
%     prepareSpots / prepareFrames  build the NEXT trial's sequence per type;
%                                   prepareSpots returns what it prepared
%                                   (spots as projected, timing) for the record
%     advance()                     at the trial boundary, next -> current
%     show(typeName)                soft code: projects the current sequence
%
%   A sequence whose key matches one already on the device is reused; key []
%   (random spot positions) is rebuilt for every trial. Keyed sequences unused
%   for UnusedTrialsKept trials are freed.
%
%   AlpSeqTiming rejects (ALP_PARM_INVALID) a synch pulse as long as the
%   picture time, and may reject long frames, so the timing is probed on the
%   device: a spot frame longer than MaxFrameUs is uploaded as identical
%   sub-frames, and each frame's synch pulse (DMD pin 8, gates the laser) is
%   the longest the ALP accepts for that picture time.

    properties (SetAccess = private)
        Width
        Height
        MaxFrameUs      % longest picture time the ALP accepts (us)
    end

    properties (Constant)
        UnusedTrialsKept = 20
    end

    properties (Access = private)
        dmd
        entries = struct('type', {}, 'key', {}, 'seq', {}, 'lastTrial', {}, 'info', {})
        current = struct()
        next = struct()
        trial = 1
        synchWidths     % picture time (us) -> longest accepted synch pulse (us)
    end

    methods
        function obj = DMDPatternPlayer()
            obj.dmd = DMDController.DMD();
            obj.dmd.connect();
            obj.Width = double(obj.dmd.device.width);
            obj.Height = double(obj.dmd.device.height);
            obj.MaxFrameUs = maxPictureTime(obj.dmd.device);
            obj.synchWidths = containers.Map('KeyType', 'double', 'ValueType', 'double');
        end

        function delete(obj)
            if isempty(obj.dmd), return; end
            obj.dmd.halt();
            for k = 1:numel(obj.entries)
                delete(obj.entries(k).seq);  % sequences before the device
            end
            obj.entries = obj.entries([]);
            delete(obj.dmd);
            obj.dmd = [];
        end

        function info = prepareSpots(obj, typeName, design, illuTime_us)
            % info: what the DMD will show, as recorded per trial (Actions.Patterns):
            % spots (random ones placed), r_px, tickMs, nF, exposureUs, subFrames,
            % frameUs, synchUs, reused (an identical sequence already on the device)
            spots = design.spots;
            if isfield(spots, 'isFixed') && any(~[spots.isFixed])
                key = [];
                spots = placeRandomSpots(spots, design.r_px, obj.Height, obj.Width);
            else
                key = {spots, design.r_px, design.tickMs, illuTime_us};
                [found, info] = obj.reuse(typeName, key);
                if found
                    info.reused = true;
                    return
                end
            end
            nSub = max(1, ceil(illuTime_us / obj.MaxFrameUs));
            t = round(illuTime_us / nSub);
            seq = obj.spotSequence(spots, design.r_px, design.tickMs, nSub);
            % Frame-synch pulse (DMD pin 8, gates the laser) spans as much of
            % each frame as the ALP allows; its default is a fraction of it.
            synch = obj.synchWidth(t);
            seq.timing(t, t, 0, synch, 0);
            seq.setRepeat(1);
            info = struct('spots', spots, 'r_px', design.r_px, 'tickMs', design.tickMs, ...
                'nF', ceil(max([spots.onset_ms] + [spots.dur_ms]) / design.tickMs), ...
                'exposureUs', illuTime_us, 'subFrames', nSub, 'frameUs', t, 'synchUs', synch, ...
                'reused', false);
            obj.add(typeName, key, seq, info);
        end

        function prepareFrames(obj, typeName, key, buildFrames, timing)
            % buildFrames(H, W) returns a logical H x W x nF stack; timing is
            % the 5 arguments of Sequence.timing.
            if obj.reuse(typeName, key), return; end
            frames = buildFrames(obj.Height, obj.Width);
            nF = size(frames, 3);
            seq = obj.dmd.device.allocSequence(1, nF);
            for k = 1:nF, seq.put(k-1, 1, frames(:,:,k)); end
            seq.setBinaryMode(true);
            seq.timing(timing(1), timing(2), timing(3), timing(4), timing(5));
            seq.setRepeat(1);
            obj.add(typeName, key, seq, struct());
        end

        function advance(obj)
            obj.current = obj.next;
            obj.next = struct();
            obj.trial = obj.trial + 1;
            shown = struct2cell(obj.current);
            drop = false(1, numel(obj.entries));
            for k = 1:numel(obj.entries)
                e = obj.entries(k);
                inUse = any(cellfun(@(s) s == e.seq, shown));
                drop(k) = ~inUse && (isempty(e.key) || obj.trial - e.lastTrial > obj.UnusedTrialsKept);
            end
            if any(drop)
                obj.dmd.halt();
                for k = find(drop), delete(obj.entries(k).seq); end
                obj.entries(drop) = [];
            end
        end

        function shown = show(obj, typeName)
            shown = isfield(obj.current, typeName);
            if ~shown, return; end
            C = DMDController.Constants;
            seq = obj.current.(typeName);
            obj.dmd.halt();
            seq.setRepeat(1);
            obj.dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_MASTER);
            obj.dmd.device.projStart(seq);
        end

        function halt(obj)
            obj.dmd.halt();
        end
    end

    methods (Access = private)
        function w = synchWidth(obj, t)
            if isKey(obj.synchWidths, t), w = obj.synchWidths(t); return; end
            w = 0;  % ALP default
            probe = obj.dmd.device.allocSequence(1, 1);
            cleanup = onCleanup(@() delete(probe));
            probe.setBinaryMode(true);
            candidates = round([t, t-1, t-10, t-100, t-1000, 0.99*t, 0.9*t, 0.5*t]);
            for c = unique(candidates(candidates > 0), 'stable')
                if acceptsTiming(probe, t, c), w = c; break; end
            end
            obj.synchWidths(t) = w;
            fprintf('DMD: %d us frames, synch pulse %d us.\n', t, w);
        end

        function [found, info] = reuse(obj, typeName, key)
            found = false;
            info = struct();
            for k = 1:numel(obj.entries)
                e = obj.entries(k);
                if strcmp(e.type, typeName) && ~isempty(e.key) && isequaln(e.key, key)
                    obj.entries(k).lastTrial = obj.trial + 1;
                    obj.next.(typeName) = e.seq;
                    found = true;
                    info = e.info;
                    return
                end
            end
        end

        function add(obj, typeName, key, seq, info)
            obj.entries(end+1) = struct('type', typeName, 'key', {key}, 'seq', seq, ...
                                        'lastTrial', obj.trial + 1, 'info', info);
            obj.next.(typeName) = seq;
        end

        function seq = spotSequence(obj, spots, r_px, tickMs, nSub)
            % Renders and uploads one frame at a time, so MATLAB never holds
            % the whole H x W x nF stack. Each tick is put nSub times.
            H = obj.Height; W = obj.Width;
            onsets = [spots.onset_ms];
            offsets = onsets + [spots.dur_ms];
            nF = ceil(max(offsets) / tickMs);
            seq = obj.dmd.device.allocSequence(1, nF * nSub);
            frame = zeros(H, W, 'uint8');
            for k = 0:nF-1
                t = k * tickMs;
                frame(:) = 0;
                for iS = find(onsets <= t & offsets > t)
                    cx = round(spots(iS).x); cy = round(spots(iS).y);
                    frame(max(1, cy-r_px):min(H, cy+r_px), max(1, cx-r_px):min(W, cx+r_px)) = 255;
                end
                for j = 0:nSub-1, seq.put(k*nSub + j, 1, frame); end
            end
            seq.setBinaryMode(true);
        end
    end
end

function maxUs = maxPictureTime(device)
    % Longest picture time AlpSeqTiming accepts (default synch pulse), tried
    % on a 1-frame binary probe; 200 ms is known to work.
    C = DMDController.Constants;
    reported = NaN;
    maxUs = 200000;
    try
        probe = device.allocSequence(1, 1);
        cleanup = onCleanup(@() delete(probe));
        probe.setBinaryMode(true);
        try, reported = double(probe.inquire(C.ALP_MAX_PICTURE_TIME)); catch, end
        candidates = [1e6 5e5 4e5 3e5 250000 200000];
        if reported > 0, candidates = unique([min(reported, 1e7) candidates]); end
        for t = sort(candidates, 'descend')
            if acceptsTiming(probe, t, 0), maxUs = t; break; end
        end
    catch ME
        warning('DMDPatternPlayer: frame-time probe failed (%s); using %d us', ME.message, maxUs);
    end
    fprintf('DMD: ALP_MAX_PICTURE_TIME reports %g us; frames up to %d us.\n', reported, maxUs);
end

function ok = acceptsTiming(seq, t, synchWidth)
    try
        seq.timing(t, t, 0, synchWidth, 0);
        ok = true;
    catch
        ok = false;
    end
end

function spots = placeRandomSpots(spots, r_px, H, W)
    margin = r_px + 1;
    fixed = [spots.isFixed];
    px = double([spots(fixed).x]);
    py = double([spots(fixed).y]);
    for i = find(~fixed)
        for attempt = 1:500
            xt = randi([margin, W - margin]);
            yt = randi([margin, H - margin]);
            if isempty(px) || all(max(abs(px-xt), abs(py-yt)) > 2*r_px)
                spots(i).x = xt; spots(i).y = yt;
                px(end+1) = xt; py(end+1) = yt; %#ok<AGROW>
                break;
            end
        end
    end
end

% test_dmd.m  Standalone DMD test — runs without Bpod.
%
% Replicates the designed-pattern path that runs during goNogo / 2AFC
% experiments. Always plays in MASTER mode (no BNC trigger required).
%
% USAGE
%   1. Edit the CONFIGURATION section below.
%   2. Run the script from the MATLAB command window.
%   3. The DMD plays the pattern and the script blocks until complete.
%
% REQUIREMENTS
%   LuminoseConstants  — loads luminose_config.yaml for patternsFolder / dmd params
%   DMDController      — must be on the MATLAB path (set via luminose_config.yaml)
%   At least one designed pattern saved from PatternDesignerGUI

%% -------------------------------------------------------------------------
%  CONFIGURATION — edit these before running
%% -------------------------------------------------------------------------
PATTERN_TYPE    = 'Left';   % pattern name: 'Left','Right','CSplus','CSminus','cue'
N_REPEATS       = 3;        % how many times to replay the sequence
ILLUMINATION_US = [];       % µs per frame; leave [] to derive from pattern tickMs
SHOW_PREVIEW    = true;     % display frame-stack preview figure before playing

%% -------------------------------------------------------------------------
%  Path setup
%% -------------------------------------------------------------------------
scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);             % dmd/ utilities (buildPatternFrameStack, etc.)
addpath(fileparts(scriptDir));  % repo root (LuminoseConstants)

%% -------------------------------------------------------------------------
%  Load config
%% -------------------------------------------------------------------------
fprintf('Loading configuration...\n');
luminose       = LuminoseConstants();
patternsFolder = char(luminose.dmd.patternsFolder);
fprintf('Patterns folder: %s\n\n', patternsFolder);

%% -------------------------------------------------------------------------
%  Find newest meta file for the requested pattern type
%% -------------------------------------------------------------------------
% Row-1 files first, then legacy (no row index)
metas = dir(fullfile(patternsFolder, sprintf('designed_%s_r1_*_meta.mat', PATTERN_TYPE)));
if isempty(metas)
    all_metas  = dir(fullfile(patternsFolder, sprintf('designed_%s_*_meta.mat', PATTERN_TYPE)));
    has_row    = arrayfun(@(m) ~isempty(regexp(m.name, ...
        sprintf('designed_%s_r\\d+_', PATTERN_TYPE), 'once')), all_metas);
    metas      = all_metas(~has_row);
end

if isempty(metas)
    avail = dir(fullfile(patternsFolder, 'designed_*_meta.mat'));
    toks  = regexp({avail.name}, 'designed_([A-Za-z]+)', 'tokens', 'once');
    types = unique([toks{:}]);
    fprintf('Available pattern types: %s\n', strjoin(types, ', '));
    error('test_dmd: no meta file found for pattern type "%s" in\n  %s', ...
        PATTERN_TYPE, patternsFolder);
end

[~, newest] = max([metas.datenum]);
metaFile    = fullfile(patternsFolder, metas(newest).name);
fprintf('Loading: %s\n', metas(newest).name);

m      = load(metaFile);
spots  = m.spots;
tickMs = m.tickMs;
r_px   = m.r_px;
for i = 1:numel(spots)
    if ~isfield(spots(i), 'isFixed'), spots(i).isFixed = true; end
end

if isempty(ILLUMINATION_US)
    ILLUMINATION_US = tickMs * 1000;   % convert ms → µs to match pattern design
end

fprintf('Pattern "%s": %d spot(s), tickMs=%.1f ms, r_px=%d px, illuTime=%d µs\n', ...
    PATTERN_TYPE, numel(spots), tickMs, r_px, round(ILLUMINATION_US));
for i = 1:numel(spots)
    tag = 'fixed';
    if ~spots(i).isFixed, tag = 'RANDOM'; end
    fprintf('  Spot %d: x=%-4d y=%-4d onset=%.0f ms  dur=%.0f ms  [%s]\n', ...
        i, spots(i).x, spots(i).y, spots(i).onset_ms, spots(i).dur_ms, tag);
end
fprintf('\n');

%% -------------------------------------------------------------------------
%  Randomise non-fixed spots (mirrors experiment behaviour each trial)
%% -------------------------------------------------------------------------
margin   = r_px + 1;
nRandom  = 0;
for i = 1:numel(spots)
    if ~spots(i).isFixed
        spots(i).x = randi([margin, 2560 - margin]);
        spots(i).y = randi([margin, 1600 - margin]);
        nRandom    = nRandom + 1;
    end
end
if nRandom > 0
    fprintf('Randomised %d non-fixed spot(s) to new positions.\n\n', nRandom);
end

%% -------------------------------------------------------------------------
%  Build frame stack
%% -------------------------------------------------------------------------
fprintf('Building frame stack...\n');
frameStack = buildPatternFrameStack(spots, r_px, tickMs);
nFrames    = size(frameStack, 3);
totalMs    = nFrames * tickMs;
fprintf('  %d frame(s) × %.1f ms = %.0f ms (%.2f s) per play\n\n', ...
    nFrames, tickMs, totalMs, totalMs / 1000);

%% -------------------------------------------------------------------------
%  Optional: preview frame stack
%% -------------------------------------------------------------------------
if SHOW_PREVIEW && nFrames > 0
    nCols  = min(nFrames, 8);
    nRows  = ceil(nFrames / nCols);
    figure('Name', sprintf('test_dmd preview: %s', PATTERN_TYPE), ...
           'NumberTitle', 'off');
    for f = 1:nFrames
        subplot(nRows, nCols, f);
        imshow(frameStack(:,:,f));
        title(sprintf('f%d (%.0fms)', f, (f-1)*tickMs), 'FontSize', 7);
    end
    sgtitle(sprintf('%s — %d frame(s), r\\_px=%d', PATTERN_TYPE, nFrames, r_px));
    drawnow;
end

%% -------------------------------------------------------------------------
%  Connect to DMD
%% -------------------------------------------------------------------------
fprintf('Connecting to DMD...\n');
dmd = DMDController.DMD();
try
    dmd.connect();
catch ME
    error('test_dmd: DMD connection failed — %s\nIs the ALP driver installed and the device powered?', ME.message);
end

info = dmd.getInfo();
fprintf('Device: %d × %d mirrors  |  S/N %d  |  Free SDRAM: %d frames\n\n', ...
    info.width, info.height, info.serialNumber, info.availMemory);

%% -------------------------------------------------------------------------
%  Allocate sequence and upload frames
%% -------------------------------------------------------------------------
fprintf('Uploading %d frame(s) to DMD SDRAM...\n', nFrames);
seq = dmd.device.allocSequence(1, nFrames);
for k = 1:nFrames
    seq.put(k-1, 1, frameStack(:,:,k));
end
seq.setBinaryMode(true);
t = round(ILLUMINATION_US);
w = setFrameTiming(seq, t);  % synch pulse (pin 8, gates the laser) as long as the ALP allows
fprintf('Upload complete. Illumination: %d µs/frame, synch pulse %d µs\n\n', t, w);

%% -------------------------------------------------------------------------
%  Arm and play.
%
%  Single-frame pattern (nFrames == 1):
%    SLAVE mode — one BNC rising edge per repeat arms and fires the frame.
%    Matches dmd_hf_* handler behaviour for single-BMP patterns.
%
%  Multi-frame designed pattern (nFrames > 1):
%    MASTER mode — sequence plays immediately, no trigger needed.
%    Matches dmd_hf_* handler behaviour for designed (buildPatternFrameStack)
%    patterns, which always run in MASTER mode.
%% -------------------------------------------------------------------------
C = DMDController.Constants;
dmd.halt();
seq.setRepeat(N_REPEATS);
totalDur_s = (nFrames * tickMs * N_REPEATS) / 1000;

if nFrames == 1
    dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_SLAVE);
    dmd.device.control(C.ALP_TRIGGER_EDGE, C.ALP_EDGE_RISING);
    dmd.device.projStart(seq);
    fprintf('ARMED — send BNC trigger now. (~%.2f s will play once triggered)\n', totalDur_s);
else
    dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_MASTER);
    dmd.device.projStart(seq);
    fprintf('Playing %d frame(s) x %d repeat(s) (~%.2f s)...\n', nFrames, N_REPEATS, totalDur_s);
end

% Poll until done rather than blocking with AlpProjWait (which ignores Ctrl+C).
C2 = DMDController.Constants;
deadline = tic;
while true
    ps = double(dmd.device.projInquire(C2.ALP_PROJ_STATE));
    if ps == double(C2.ALP_PROJ_IDLE)
        break;
    end
    if toc(deadline) > totalDur_s + 15
        fprintf('WARNING: sequence did not complete within expected time. Halting.\n');
        dmd.halt();
        break;
    end
    pause(0.05);
end

fprintf('Sequence complete.\n\n');

%% -------------------------------------------------------------------------
%  Cleanup
%% -------------------------------------------------------------------------
dmd.halt();
delete(seq);
dmd.disconnect();
fprintf('DMD disconnected. Test complete.\n');

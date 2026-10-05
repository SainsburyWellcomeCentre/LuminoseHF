% test_dmd2.m  Display all spots from a designed pattern as a static image.
%
% Unlike test_dmd.m, this ignores timing and shows every spot simultaneously,
% holding the pattern on until you run the CLEANUP section.
%
% USAGE
%   1. Set META_FILE below (or leave empty to auto-pick newest for PATTERN_TYPE).
%   2. Run the script from the MATLAB command window.
%   3. Run the CLEANUP section (last block) when you want to turn it off.
%
% REQUIREMENTS
%   DMDController  — must be on the MATLAB path (set via luminose_config.yaml)

%% -------------------------------------------------------------------------
%  CONFIGURATION — edit these before running
%% -------------------------------------------------------------------------
META_FILE       = 'designed_powercal_r1_20261001_152909_meta.mat';
                  % Full path to a _meta.mat file, OR leave '' to auto-pick:
PATTERN_TYPE    = 'CSminus';   % used only when META_FILE is empty
ILLUMINATION_US = 500;        % µs on-time per frame; increase for brighter

%% -------------------------------------------------------------------------
%  Path setup
%% -------------------------------------------------------------------------
scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
addpath(fileparts(scriptDir));

%% -------------------------------------------------------------------------
%  Resolve meta file
%% -------------------------------------------------------------------------
if isempty(META_FILE)
    luminose       = LuminoseConstants();
    patternsFolder = char(luminose.dmd.patternsFolder);

    metas = dir(fullfile(patternsFolder, sprintf('designed_%s_r1_*_meta.mat', PATTERN_TYPE)));
    if isempty(metas)
        all_metas = dir(fullfile(patternsFolder, sprintf('designed_%s_*_meta.mat', PATTERN_TYPE)));
        has_row   = arrayfun(@(m) ~isempty(regexp(m.name, ...
            sprintf('designed_%s_r\\d+_', PATTERN_TYPE), 'once')), all_metas);
        metas     = all_metas(~has_row);
    end
    if isempty(metas)
        error('test_dmd2: no meta file found for pattern type "%s"', PATTERN_TYPE);
    end
    [~, newest] = max([metas.datenum]);
    META_FILE   = fullfile(patternsFolder, metas(newest).name);
end

fprintf('Loading: %s\n', META_FILE);

%% -------------------------------------------------------------------------
%  Load spots and build single static frame
%% -------------------------------------------------------------------------
m    = load(META_FILE);
spots = m.spots;
r_px  = m.r_px;

fprintf('Pattern: %d spot(s), r_px=%d px\n', numel(spots), r_px);
for i = 1:numel(spots)
    fprintf('  Spot %d: x=%-4d  y=%-4d\n', i, spots(i).x, spots(i).y);
end

%% -------------------------------------------------------------------------
%  Connect and get device dimensions
%% -------------------------------------------------------------------------
fprintf('\nConnecting to DMD...\n');
dmd = DMDController.DMD();
try
    dmd.connect();
catch ME
    error('test_dmd2: DMD connection failed — %s', ME.message);
end

info = dmd.getInfo();
H = double(info.height);
W = double(info.width);
fprintf('Device: %d x %d  |  S/N %d\n\n', W, H, info.serialNumber);

%% -------------------------------------------------------------------------
%  Render all spots onto one frame
%% -------------------------------------------------------------------------
img = false(H, W);
for i = 1:numel(spots)
    cx = round(spots(i).x);
    cy = round(spots(i).y);
    r1 = max(1, cy - r_px);  r2 = min(H, cy + r_px);
    c1 = max(1, cx - r_px);  c2 = min(W, cx + r_px);
    img(r1:r2, c1:c2) = true;
end

figure('Name', 'test_dmd2 preview', 'NumberTitle', 'off');
imshow(img);
title(sprintf('%d spot(s)  r\\_px=%d', numel(spots), r_px));
drawnow;

%% -------------------------------------------------------------------------
%  Upload and display — loops until you run the CLEANUP block
%% -------------------------------------------------------------------------
seq = dmd.device.allocSequence(1, 1);
seq.put(0, 1, img);
seq.setBinaryMode(true);
w = setFrameTiming(seq, ILLUMINATION_US);  % synch pulse (pin 8, gates the laser) as long as the ALP allows
fprintf('Frame %d us, synch pulse %d us.\n', round(ILLUMINATION_US), w);
seq.setRepeat(0);   % 0 = loop forever

C = DMDController.Constants;
dmd.halt();
dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_MASTER);
dmd.device.projStart(seq);
fprintf('Pattern on. Run CLEANUP block to stop.\n');

%% -------------------------------------------------------------------------
%  CLEANUP — run this section when you want to turn the DMD off
%% -------------------------------------------------------------------------
% dmd.halt();
% delete(seq);
% dmd.disconnect();
% fprintf('DMD off.\n');

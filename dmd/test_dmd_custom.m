%BASIC_DISPLAY  Connect to DLP V-7002, display a test pattern, then disconnect.
%
% Prerequisites:
%   1. Run setup.m once to compile the thunk DLL.
%   2. Add DMDController to MATLAB path:
%        addpath('C:\Users\harrislab\Documents\MATLAB\DMDController')
%   3. V-7002 device must be connected via USB and powered on.
%
% Run from MATLAB Command Window or as a script.

fprintf('=== DMDController Basic Display Test ===\n\n');

%% Add path (if not already added)
dmdRoot = fileparts('C:\Users\harrislab\MATLAB\DMDController');
if ~contains(path, dmdRoot)
    addpath(dmdRoot);
end

%% Connect
fprintf('Connecting to DMD...\n');
dmd = DMDController.DMD();
dmd.connect(0);  % device 0

%% Print device info
info = dmd.getInfo();
fprintf('  Device serial number : %d\n', info.serialNumber);
fprintf('  Firmware version     : %d\n', info.version);
fprintf('  DMD resolution       : %d x %d\n', info.width, info.height);
fprintf('  Available SDRAM      : %d binary frames\n', info.availMemory);

%% Check temperatures
temps = dmd.getTemperatures();
fprintf('  DDC FPGA temperature : %.1f C\n', temps.ddc_fpga);
fprintf('  APPS FPGA temperature: %.1f C\n', temps.apps_fpga);
fprintf('  PCB temperature      : %.1f C\n\n', temps.pcb);

W = double(info.width);   % 2560
H = double(info.height);  % 1600

%% Single pixel lines
img = zeros(H, W, 'uint8');
cRow = round(H/2);  cCol = round(W/2);
for off = [-3, 0, 4]
    img(cRow + off, :) = 255;
    img(:, cCol + off) = 255;
end
dmd.displayFrame(img);
pause(0.5);

%% Single central dot
dotRadius = 100;
img = zeros(H, W, 'uint8');
[xx, yy] = meshgrid(1:W, 1:H);
dot = (xx - cCol).^2 + (yy - cRow).^2 <= dotRadius^2;
img(dot) = 255;
dmd.displayFrame(img);
pause(0.5);

%% Test 1: All-white
fprintf('Test 1: All-white frame (2 seconds)...\n');
dmd.on();
pause(2);

%% Test 2: All-black
fprintf('Test 2: All-black frame (2 seconds)...\n');
dmd.off();
pause(2);

%% Test 3: Checkerboard pattern
fprintf('Test 3: Checkerboard pattern (3 seconds)...\n');
blockSize = 64;
[xx, yy] = meshgrid(1:W, 1:H);
checker = logical(mod(floor((xx-1)/blockSize) + floor((yy-1)/blockSize), 2));
dmd.displayFrame(checker);
pause(3);

% %% Test 4: Horizontal gradient (Thresholded to 1-bit)
% fprintf('Test 4: Horizontal gradient (1-bit, 3 seconds)...\n');
% gradient_img = repmat(linspace(0, 1, W), H, 1) > 0.5;
% dmd.displayFrame(gradient_img);
% pause(3);

% %% Test 5: Multi-frame sequence (sine wave scrolling) at 30 fps
% fprintf('Test 5: Scrolling sine wave sequence (30 fps, 2 seconds)...\n');
% nFrames = 30;
% imgStack = false(H, W, nFrames);
% for f = 1:nFrames
%     phase = 2*pi*(f-1)/nFrames;
%     row_profile = (sin(2*pi*(1:W)/200 + phase) > 0);
%     imgStack(:,:,f) = repmat(row_profile, H, 1);
% end
% dmd.displaySequence(imgStack, 30, 0);  % 0 = infinite loop
% pause(2);

% %% Test 6: 8-bit Grayscale (Horizontal Gradient)
% fprintf('Test 6: 8-bit Grayscale Gradient (3 seconds)...\n');
% gradient8 = uint8(repmat(linspace(0, 255, W), H, 1));
% % Pass '8' as the fourth argument to use 8-bit depth
% dmd.displayFrame(gradient8, [], 8);
% pause(3);

%% Test 7: Concentric rings + plus
fprintf('Test 7: Concentric rings (3 seconds)...\n');
cx = W/2; cy = H/2; armHalfWidth = 50;
[xx, yy] = meshgrid(1:W, 1:H);
r = sqrt((xx-cx).^2 + (yy-cy).^2);
rings = logical(mod(floor(r / 50), 2));
rings(:, cx-armHalfWidth:cx+armHalfWidth) = true;
rings(cy-armHalfWidth:cy+armHalfWidth, :) = true;
% rings(1:cy, :) = false; rings(:, cx:end) = false;
dmd.displayFrame(rings);
pause(3);

% %% Test 7: Concentric rings + plus, fit into top-right quadrant
% fprintf('Test 7: Concentric rings, top-right quadrant (3 seconds)...\n');
% qW = W/2; qH = H/2; armHalfWidth = 50;
% qcx = qW/2; qcy = qH/2;
% [xx, yy] = meshgrid(1:qW, 1:qH);
% r = sqrt((xx-qcx).^2 + (yy-qcy).^2);
% quadrant = logical(mod(floor(r / 50), 2));
% quadrant(:, qcx-armHalfWidth:qcx+armHalfWidth) = true;
% quadrant(qcy-armHalfWidth:qcy+armHalfWidth, :) = true;
% rings = false(H, W);
% rings(H-qH+1:H, 1:qW) = quadrant;
% dmd.displayFrame(rings);
% pause(3);

%% Test 8: Full-resolution checkerboard (every alternate mirror on)
fprintf('Test 8: Full-resolution checkerboard (3 seconds)...\n');
[xx, yy] = meshgrid(0:W-1, 0:H-1);
checker_fullres = logical(mod(xx + yy, 2));
dmd.displayFrame(checker_fullres);
pause(3);

%% -------------------------------------------------------------------------
%  CLEANUP — run this section when you want to turn the DMD off
%% -------------------------------------------------------------------------
% fprintf('\nTest complete. Halting and disconnecting...\n');
% dmd.halt();
% pause(0.5);
% dmd.disconnect();
% fprintf('Done.\n');

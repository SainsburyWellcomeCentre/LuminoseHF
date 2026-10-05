function seq = buildDMDSlaveSequence(dmd, patternsFolder, imgIdx, illuminateTime_us, nFrames)
% buildDMDSlaveSequence  Load BMP frame(s) and return an ALP sequence.
%
%   seq = buildDMDSlaveSequence(dmd, patternsFolder, imgIdx, illuminateTime_us)
%   seq = buildDMDSlaveSequence(dmd, patternsFolder, imgIdx, illuminateTime_us, nFrames)
%
%   dmd               - DMDController.DMD object (must be connected)
%   patternsFolder    - path to folder containing BMP pattern files
%   imgIdx            - 1-based index into the sorted BMP file list (first frame)
%   illuminateTime_us - mirror-on time per frame (microseconds)
%   nFrames           - number of consecutive frames to load (default 1)
%
%   Single frame (nFrames=1): slave mode, waits for external BNC trigger.
%   Multi-frame  (nFrames>1): caller must switch device to master mode and
%                             use dmd.startFinite(seq,1) to play immediately.

    if nargin < 5 || isempty(nFrames)
        nFrames = 1;
    end

    files = dir(fullfile(char(patternsFolder), '*.bmp'));
    H = dmd.device.height;
    W = dmd.device.width;

    if nFrames == 1
        if imgIdx <= numel(files)
            img = imread(fullfile(char(patternsFolder), files(imgIdx).name));
            if ndims(img) == 3
                img = rgb2gray(img);
            end
            img = img > 127;
        else
            warning('buildDMDSlaveSequence: index %d exceeds %d files in %s', ...
                imgIdx, numel(files), char(patternsFolder));
            img = false(H, W);
        end
        seq = dmd.device.allocSequence(1, 1);
        seq.put(0, 1, img);
        seq.setBinaryMode(true);
        illuTime = round(illuminateTime_us);
        setFrameTiming(seq, illuTime);
        seq.setRepeat(1);
    else
        % Multi-frame: load nFrames consecutive BMPs starting at imgIdx
        frameStack = false(H, W, nFrames);
        for k = 1:nFrames
            idx = imgIdx + k - 1;
            if idx <= numel(files)
                img = imread(fullfile(char(patternsFolder), files(idx).name));
                if ndims(img) == 3
                    img = rgb2gray(img);
                end
                frameStack(:,:,k) = img > 127;
            end
        end
        seq = dmd.device.allocSequence(1, nFrames);
        for k = 1:nFrames
            seq.put(k-1, 1, frameStack(:,:,k));
        end
        seq.setBinaryMode(true);
        illuTime = round(illuminateTime_us);
        setFrameTiming(seq, illuTime);  % uniform per-frame duration
        seq.setRepeat(1);
    end
end

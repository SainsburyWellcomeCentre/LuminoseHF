function sz = dmdFrameSize(dmd)
% dmdFrameSize  The DMD's [rows cols] (getInfo), or the V-7002's 768 x 1024.
    sz = [768 1024];
    try
        info = dmd.getInfo();
        sz = double([info.height info.width]);
    catch
    end
end

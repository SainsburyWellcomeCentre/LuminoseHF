function haltQuietly(dmd)
% haltQuietly  Halts the DMD; never throws (cleanup).
    try dmd.halt(); catch, end
end

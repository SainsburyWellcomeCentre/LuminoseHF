function list = history(cal, folder)
% lhf.cal.history  A calibration's saved results, newest (the one in use) first.
%
%   list = lhf.cal.history(cal, folder)
%
%   cal from lhf.cal.catalog; folder luminoseData/calibration. list: struct array
%   file, stamp (yyyymmdd_HHMMSS from the name, which orders them, as
%   lhf.cam.loadRegistration does), inUse (true for the newest: what the rig uses).
%
% See also lhf.cal.load, lhf.cal.catalog

    list = struct('file', {}, 'stamp', {}, 'inUse', {});
    found = dir(fullfile(char(folder), cal.files));
    if isempty(found), return; end
    names = {found.name};
    stamps = regexp(names, '\d{8}_\d{6}(?=\.mat$)', 'match', 'once');
    keep = ~cellfun(@isempty, stamps);
    names = names(keep);
    stamps = stamps(keep);
    [stamps, order] = sort(stamps);
    names = names(order);
    for k = numel(names):-1:1
        list(end + 1) = struct('file', fullfile(char(folder), names{k}), 'stamp', stamps{k}, ...
            'inUse', k == numel(names)); %#ok<AGROW>
    end
end

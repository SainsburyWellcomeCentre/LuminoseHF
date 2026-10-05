function folder = patternFolder(dmdConfig, ~)
% lhf.patternFolder  The folder pattern designs are saved in and loaded from.
%
%   folder = lhf.patternFolder(luminose.dmd, patternType)
%
%   luminose.dmd.patternsFolder, shared by every protocol and type. A
%   protocol keeps a type's designs apart by their file name instead
%   (lhf.patternFileType). The Pattern Designer, the DMD handlers and the
%   design loaders all ask here.

    folder = char(dmdConfig.patternsFolder);
end

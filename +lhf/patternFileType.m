function fileType = patternFileType(dmdConfig, patternType)
% lhf.patternFileType  The name a pattern type's design files carry: designed_<fileType>_r<row>_*.
%
%   fileType = lhf.patternFileType(luminose.dmd, patternType)
%
%   Normally the type itself. A protocol can save a type under another name
%   by setting luminose.dmd.typeFileNames.<type> at startup: powercal's CS-
%   designs are designed_powercal_*, and its CS+ designs designed_powercalCSplus_*,
%   so they sit in the shared folder apart from goNogo's CSminus and CSplus.
%   The Pattern Designer, lhf.patternDesign and the design loaders all ask here.

    fileType = char(patternType);
    if isfield(dmdConfig, 'typeFileNames') && isfield(dmdConfig.typeFileNames, patternType)
        fileType = char(dmdConfig.typeFileNames.(patternType));
    end
end

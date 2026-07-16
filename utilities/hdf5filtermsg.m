function msg = hdf5filtermsg(filename, dsetpath, ME)
% ***********************************************
% Copyright (c) 2026 UChicago Argonne, LLC
% See LICENSE file.
% ***********************************************
%
% HDF5FILTERMSG Build a descriptive error message for a failed HDF5 dataset read.
%   MSG = HDF5FILTERMSG(FILENAME, DSETPATH, ME) inspects the HDF5 filters used
%   by the dataset DSETPATH in FILENAME and, if any of them are not part of
%   MATLAB's native/built-in filter set, returns a message identifying the
%   offending filter(s) and pointing the user at hdf5_recompress_gui.py to
%   re-encode the file to gzip. ME is the caught MException from the failed
%   H5READ/H5INFO call; its message is included as-is when the filter can't
%   be identified, or when all filters are native (unexplained failure).
%
%   This function never throws and does not display any UI - the caller is
%   responsible for deciding how to surface MSG (e.g. ERRORDLG or ERROR).

%   $Revision: 1.0 $  $Date: 2026/07/16 $

nativeFilters = {'deflate','shuffle','fletcher32','nbit','scaleoffset'};

badFilters = {};
try
    info = h5info(filename, dsetpath);
    if isfield(info,'Filters') && ~isempty(info.Filters)
        for i = 1:numel(info.Filters)
            name = info.Filters(i).Name;
            if ~any(cellfun(@(f) contains(lower(name),lower(f)), nativeFilters))
                badFilters{end+1} = name; %#ok<AGROW>
            end
        end
    end
catch
    % h5info itself failed (e.g. corrupt file) - fall through to generic message.
end

if ~isempty(badFilters)
    msg = sprintf(['Cannot read dataset "%s" in file:\n%s\n\n', ...
        'This file was compressed with a filter MATLAB''s built-in HDF5 library ', ...
        'cannot decode: %s.\n\n', ...
        'MATLAB only supports the native HDF5 filters (deflate/gzip, shuffle, ', ...
        'fletcher32, nbit, scaleoffset) without an external plugin.\n\n', ...
        'Fix: use hdf5_recompress_gui.py (in the repo root) to re-encode this file ', ...
        'to gzip compression, then load the resulting "*_recompressed.h5" file instead.'], ...
        dsetpath, filename, strjoin(badFilters, ', '));
else
    msg = sprintf('Failed to read dataset "%s" in file:\n%s\n\n%s', ...
        dsetpath, filename, ME.message);
end

end

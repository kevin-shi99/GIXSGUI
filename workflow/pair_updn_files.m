function [pairs, report] = pair_updn_files(fnames)
% pair_updn_files.m
% ------------------------------------------------------------------
% Pair "up" and "dn" detector images for gap filling, by filename only.
%
%   [PAIRS, REPORT] = PAIR_UPDN_FILES(FNAMES) takes a cell array of file
%   names (with extension, no folder) and returns:
%     PAIRS  - struct array with fields up, dn, scanUp, scanDn, key
%     REPORT - struct with fields
%                unmatchedUp : up files with no partner (cell, with reason)
%                unmatchedDn : dn files not used in any pair
%                ignored     : files with no scan number or no up/dn token
%
% Only two parts of the filename are assumed to be fixed:
%   1) Scan number token  P<digits>, delimited by start-of-name or '_'
%      and by '_' or end-of-name (normally the prefix, e.g. P0256_...).
%   2) Position token     _up / _dn, followed by '_' or end-of-name.
% Everything else (sample, orientation, angle, ... and the extension) is
% treated as opaque metadata. A dn file is paired with an up file when:
%   scan(dn) == scan(up) + 1   AND   metadata(dn) == metadata(up)
% where metadata = filename with the scan token removed and the up/dn
% token replaced by a placeholder. No knowledge of the metadata naming
% convention is needed, so it may change freely.
%
% Example:
%   P0256_KS5_xpos000_deg0080_eps0000_up_deg0080.hdf
%   P0257_KS5_xpos000_deg0080_eps0000_dn_deg0080.hdf
%   -> both have metadata '_KS5_xpos000_deg0080_eps0000_<updn>_deg0080.hdf'
% ------------------------------------------------------------------

fnames = fnames(:);
n = numel(fnames);
scan = nan(n,1);
role = cell(n,1);      % 'up', 'dn' or ''
key  = cell(n,1);
report.ignored = {};
for ii = 1:n
    [scan(ii), role{ii}, key{ii}] = parse_name(fnames{ii});
    if isnan(scan(ii)) || isempty(role{ii})
        report.ignored{end+1,1} = fnames{ii};
    end
end

isUp = strcmp(role,'up');
isDn = strcmp(role,'dn');
dnUsed = false(n,1);
pairs = struct('up',{},'dn',{},'scanUp',{},'scanDn',{},'key',{});
report.unmatchedUp = {};

upIdx = find(isUp);
[~, order] = sort(scan(upIdx));
upIdx = upIdx(order);
for ii = upIdx'
    nextScan = isDn & scan == scan(ii)+1;
    cand = find(nextScan & strcmp(key, key{ii}));
    if numel(cand) == 1
        dnUsed(cand) = true;
        pairs(end+1) = struct('up',fnames{ii},'dn',fnames{cand}, ...
            'scanUp',scan(ii),'scanDn',scan(cand),'key',key{ii}); %#ok<AGROW>
    elseif numel(cand) > 1
        report.unmatchedUp{end+1,1} = sprintf('%s  (ambiguous: %d dn files match)', ...
            fnames{ii}, numel(cand));
    elseif any(nextScan)
        mismatch = fnames(nextScan);
        report.unmatchedUp{end+1,1} = sprintf('%s  (P%d dn file has different metadata: %s)', ...
            fnames{ii}, scan(ii)+1, strjoin(mismatch', ', '));
    else
        report.unmatchedUp{end+1,1} = sprintf('%s  (no dn file with scan P%d)', ...
            fnames{ii}, scan(ii)+1);
    end
end
report.unmatchedDn = fnames(isDn & ~dnUsed);


function [scan, role, key] = parse_name(fname)
scan = NaN; role = ''; key = '';
[~, stem, ext] = fileparts(fname);
% scan number token: P<digits> bounded by start/'_' and '_'/end
[s, e, tok] = regexp(stem, '(?<=^|_)[Pp](\d+)(?=_|$)', 'start', 'end', 'tokens', 'once');
if isempty(s), return; end
scan = str2double(tok{1});
rest = [stem(1:s-1), '<scan>', stem(e+1:end)];
% position token: _up / _dn followed by '_' or end; must occur exactly once
[s, e, tok] = regexp(rest, '_(up|dn)(?=_|$)', 'start', 'end', 'tokens', 'ignorecase');
if numel(s) ~= 1, return; end
role = lower(tok{1}{1});
key = [rest(1:s-1), '_<updn>', rest(e+1:end), lower(ext)];

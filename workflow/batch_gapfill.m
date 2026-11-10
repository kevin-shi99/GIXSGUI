% batch_gapfill.m
% ------------------------------------------------------------------
% Batch script: for every up/dn image pair in INPUTDIR, fill the Pilatus
% module gaps and bad pixels with gapfillgui and export one
% <up file name>_GapFilled.tif per pair to OUTPUTDIR.
%
%   Base image            : the "_up" file
%   Vertical offset image : the "_dn" file, at X = 0, Y = offsetY pixels
%
% Pairing (see pair_updn_files.m): the dn partner of an up file with
% scan number P<N> is the dn file with scan number P<N+1> whose remaining
% filename (sample, orientation, angle, ..., extension) is identical.
% Only the P<N> scan token and the _up/_dn token are assumed to be fixed;
% the rest of the naming convention may change.
%
% The fill is done by driving the gapfillgui window (same approach as
% mgapfill.m), so its current flat field, gap mask, bad pixel mask and
% export image type are used. Adjust those in the GUI and re-run this
% script to change them. Pairs that fail are skipped and reported.
%
% A log gapfill_log.csv (up file, dn file, output file, status) is
% written to OUTPUTDIR, including unmatched up/dn files.
%
% Assumes gixsgui's toolbox path is already on MATLAB's path (run
% gixsgui once, or addpath(genpath('<repo root>')) manually).
% ------------------------------------------------------------------

%% ---------------- USER CONFIGURATION ----------------
offsetY = -25;              % dn image vertical offset (pixels) wrt up image; X offset is 0
outputSuffix = '_GapFilled';
dryRun = false;             % true = only print/log the pairing, do not fill

if isempty(which('gapfillgui'))
    error('gapfillgui is not on the MATLAB path. Run gixsgui once first.');
end

inputDir = uigetdir(pwd, 'Select folder containing up/dn image files');
if isequal(inputDir, 0)
    disp('No input folder selected. Aborting.');
    return;
end

outputDir = uigetdir(inputDir, 'Select folder to save GapFilled .tif files');
if isequal(outputDir, 0)
    disp('No output folder selected. Aborting.');
    return;
end

imageExts = {'.tif', '.tiff', '.cbf', '.hdf', '.h5'};

%% ---------------- PAIR FILES ----------------
flist = dir(inputDir);
flist = flist(~[flist.isdir]);
fnames = {flist.name}';
[~, ~, fexts] = cellfun(@fileparts, fnames, 'UniformOutput', false);
keep = ismember(lower(fexts), imageExts) & ~contains(fnames, outputSuffix);
fnames = unique(fnames(keep));

[pairs, report] = pair_updn_files(fnames);

fprintf('\n%d image files in %s\n', numel(fnames), inputDir);
fprintf('%d up/dn pairs found:\n', numel(pairs));
for kk = 1:numel(pairs)
    fprintf('  %s  +  %s\n', pairs(kk).up, pairs(kk).dn);
end
if ~isempty(report.unmatchedUp)
    fprintf('Unmatched up files (skipped):\n');
    fprintf('  %s\n', report.unmatchedUp{:});
end
if ~isempty(report.unmatchedDn)
    fprintf('Unmatched dn files (skipped):\n');
    fprintf('  %s\n', report.unmatchedDn{:});
end
if ~isempty(report.ignored)
    fprintf('%d files without P<scan> or _up/_dn token ignored.\n', numel(report.ignored));
end

logRows = cell(0, 4);
for kk = 1:numel(report.unmatchedUp)
    logRows(end+1, :) = {report.unmatchedUp{kk}, '', '', 'unmatched up'}; %#ok<SAGROW>
end
for kk = 1:numel(report.unmatchedDn)
    logRows(end+1, :) = {'', report.unmatchedDn{kk}, '', 'unmatched dn'}; %#ok<SAGROW>
end

if dryRun || isempty(pairs)
    write_log(outputDir, logRows);
    disp('Nothing filled (dryRun = true or no pairs found).');
    return;
end

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% ---------------- SET UP GAPFILL GUI ----------------
hFig = findall(0, 'Tag', 'gapfill_fig');
if isempty(hFig)
    gapfillgui;
    hFig = findall(0, 'Tag', 'gapfill_fig');
end
figure(hFig);

% vertical offset image #1 at [0 offsetY]
set(findall(hFig, 'tag', 'gapfill_EditPosX1'), 'String', '0');
hEditPosY1 = findall(hFig, 'tag', 'gapfill_EditPosY1');
set(hEditPosY1, 'String', num2str(offsetY));
cb = get(hEditPosY1, 'callback');
feval(cb{1}, [], [], cb{2:end});

% only image #1 may be loaded, so clear images #2 and #3
for ii = 2:3
    hEditImage = findall(hFig, 'tag', ['gapfill_EditImage', num2str(ii)]);
    set(hEditImage, 'String', '');
    feval(get(hEditImage, 'callback'), [], [], ii);
end

udata = get(hFig, 'UserData');
if ~isequal(udata.pos1, [0 offsetY])
    error('Could not set gapfillgui vertical offset to [0 %d].', offsetY);
end
hPopupmenuImageType = findall(hFig, 'tag', 'gapfill_PopupmenuImageType');
typeStr = get(hPopupmenuImageType, 'string');
exportType = typeStr{get(hPopupmenuImageType, 'value')};

fprintf('\nGap fill settings (from gapfillgui):\n');
fprintf('  Flat field     : %s\n', udata.fffile);
fprintf('  Gap mask       : %s\n', udata.gapmaskfile);
fprintf('  Bad pixel mask : %s\n', udata.badpixmaskfile);
fprintf('  Offset [X Y]   : [%d %d]\n', udata.pos1);
fprintf('  Export type    : %s\n\n', exportType);

hEditBase = findall(hFig, 'tag', 'gapfill_EditBase');
hEditImage1 = findall(hFig, 'tag', 'gapfill_EditImage1');
fillCallback = get(findall(hFig, 'tag', 'gapfill_PushbuttonFill'), 'callback');
closeAllCallback = get(findall(hFig, 'tag', 'gapfill_PushbuttonCloseAll'), 'callback');

%% ---------------- BATCH LOOP ----------------
nOK = 0;
for kk = 1:numel(pairs)
    fup = fullfile(inputDir, pairs(kk).up);
    fdn = fullfile(inputDir, pairs(kk).dn);
    [~, upStem] = fileparts(fup);
    outFile = fullfile(outputDir, [upStem, outputSuffix, '.tif']);
    fprintf('%d of %d: %s ... ', kk, numel(pairs), pairs(kk).up);
    try
        check_hdf_readable(fup);
        check_hdf_readable(fdn);

        % gapfillgui keeps the previous file/data when a load fails, so
        % verify that the requested files are the ones actually loaded
        set(hEditBase, 'String', fup);
        feval(get(hEditBase, 'callback'));
        set(hEditImage1, 'String', fdn);
        feval(get(hEditImage1, 'callback'), [], [], 1);
        udata = get(hFig, 'UserData');
        if ~strcmp(udata.imbasefile, fup) || isempty(udata.imbasedata)
            error('Failed to load up file %s', pairs(kk).up);
        end
        if ~strcmp(udata.imfile1, fdn) || isempty(udata.imdata1)
            error('Failed to load dn file %s', pairs(kk).dn);
        end

        udata.imfdata = [];
        set(hFig, 'UserData', udata);
        feval(fillCallback);
        feval(closeAllCallback);
        udata = get(hFig, 'UserData');
        if isempty(udata.imfdata)
            error('Gap fill failed (see gapfillgui error dialog).');
        end

        imwrite2tif(udata.imfdata, [], outFile, exportType);
        status = 'OK';
        nOK = nOK + 1;
        fprintf('saved %s\n', [upStem, outputSuffix, '.tif']);
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        status = ['FAILED: ', regexprep(ME.message, '\s*\n\s*', ' ')];
        outFile = '';
    end
    logRows(end+1, :) = {pairs(kk).up, pairs(kk).dn, outFile, status}; %#ok<SAGROW>
end

write_log(outputDir, logRows);
fprintf('\nDone. %d of %d pairs gap filled. Output folder: %s\n', nOK, numel(pairs), outputDir);


%% ---------------- LOCAL FUNCTIONS ----------------
function check_hdf_readable(f)
% Read one element of an HDF/H5 dataset so unsupported compression filters
% raise an error here instead of an error dialog inside gapfillgui.
[~, ~, ext] = fileparts(f);
if ~any(strcmpi(ext, {'.hdf', '.h5'})), return; end
dset = '/entry/data/data';
try
    info = h5info(f, dset);
    nd = numel(info.Dataspace.Size);
    h5read(f, dset, ones(1, nd), ones(1, nd));
catch ME
    error('%s', hdf5filtermsg(f, dset, ME));
end
end

function write_log(outputDir, logRows)
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
T = cell2table(logRows, 'VariableNames', {'up_file', 'dn_file', 'output_file', 'status'});
writetable(T, fullfile(outputDir, 'gapfill_log.csv'));
end

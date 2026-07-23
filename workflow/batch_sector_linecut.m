% batch_sector_linecut.m
% ------------------------------------------------------------------
% Batch script: for every .tif file in INPUTDIR, perform constrained
% q-axis linecuts in Chi sectors and export each result as a separate
% .mat file to OUTPUTDIR.
%
% Assumes gixsgui's toolbox path is already on MATLAB's path (run
% gixsgui once, or addpath(genpath('<repo root>')) manually).
% ------------------------------------------------------------------

%% ---------------- USER CONFIGURATION ----------------
repoRoot = fileparts(mfilename('fullpath'));

inputDir = uigetdir(repoRoot, 'Select folder containing .tif files');
if isequal(inputDir, 0)
    disp('No input folder selected. Aborting.');
    return;
end

outputDir = uigetdir(inputDir, 'Select folder to save sector linecut .mat results');
if isequal(outputDir, 0)
    disp('No output folder selected. Aborting.');
    return;
end

filePattern = '*.tif';

[paramFileName, paramFilePath] = uigetfile(fullfile(repoRoot, '*.mat'), ...
    'Select calibration .mat file (exported from gixsgui via Export Parameters)');
if isequal(paramFileName, 0)
    disp('No calibration file selected. Aborting.');
    return;
end
paramFile = fullfile(paramFilePath, paramFileName);

X = 1;                  % linecut predictor: 1 = q
NOfPts = 600;           % number of points in each linecut
DataFlagOverride = 2;   % [] to auto-pick (2 if available, else 1)

qRange = [0.2, 2.5];   % q range for linecut (in Angstrom^-1)
chiCenters = [0, -5, -15, -25, -35, -45, -55, -65, -75, -85];  % azimuthal sector centers in degrees
chiHalfWidth = 5;   % half-width of azimuthal sector in degrees

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% ---------------- BUILD TEMPLATE INSTRUMENT PARAMETERS ----------------
% Calibration is loaded from a .mat file exported by gixsgui's
% "Export Parameters" button (single variable containing a gixsdata object).
paramData = load(paramFile);
if ~isstruct(paramData)
    error('Calibration file ''%s'' is not a valid .mat file.', paramFile);
end

paramFields = fieldnames(paramData);
if numel(paramFields) ~= 1
    error(['Calibration file ''%s'' must contain exactly one variable ', ...
        '(a gixsdata object exported via gixsgui''s Export Parameters button).'], paramFile);
end

paramObj = paramData.(paramFields{1});
if ~strcmpi(class(paramObj), 'gixsdata')
    error(['Calibration file ''%s'' does not contain a gixsdata object ', ...
        '(found class ''%s''). Export calibration parameters from gixsgui first.'], ...
        paramFile, class(paramObj));
end

template = copyhobj(paramObj);

%% ---------------- BATCH LOOP ----------------
flist = dir(fullfile(inputDir, filePattern));
if isempty(flist)
    disp('No .tif files found in input folder. Nothing to process.');
    return;
end

varname_list = {'q', 'phi', 'qz', 'qx', 'qy', 'qr', '2theta', 'alpha_f', 'chi', 'x_pixel', 'y_pixel'};

for ii = 1:numel(flist)
    imFile = fullfile(flist(ii).folder, flist(ii).name);
    fprintf('Processing %s (%d/%d)...\n', flist(ii).name, ii, numel(flist));

    gdata = copyhobj(template);
    try
        gdata.ImFile = imFile;
    catch ME
        warning('Failed to load %s: %s. Skipping.', imFile, ME.message);
        delete(gdata);
        continue;
    end

    if isempty(gdata.QMap)
        warning('No q-maps for %s (check instrument parameters). Skipping.', flist(ii).name);
        delete(gdata);
        continue;
    end

    if ~isempty(DataFlagOverride)
        dataflag = DataFlagOverride;
    elseif isempty(gdata.SolidAngleCorrectedData)
        dataflag = 1;   % MaskedData
    else
        dataflag = 2;   % SolidAngleCorrectedData
    end

    [~, baseName] = fileparts(flist(ii).name);

    for jj = 1:numel(chiCenters)
        chiCenter = chiCenters(jj);
        chiLow = chiCenter - chiHalfWidth;
        chiHigh = chiCenter + chiHalfWidth;

        % constraint format: [OPERATOR, FLAG, LOWER, UPPER]
        % FLAG 1 = q, FLAG 9 = chi
        constraint = [1, 1, qRange(1), qRange(2); ...
                      1, 9, chiLow, chiHigh];

        [linecutdata, linefit_obj] = do_linecut(gdata, X, constraint, NOfPts, dataflag, varname_list);
        saveName = sprintf('%s_sector_%ddeg.mat', baseName, chiCenter);
        save(fullfile(outputDir, saveName), 'linecutdata', 'linefit_obj');
    end

    delete(gdata);   % gixsdata is a handle class
end

disp('Batch sector linecut export complete.');

%% ---------------- HELPER ----------------
function [linecutdata, linefit_obj] = do_linecut(gdata, X, constraint, NOfPts, dataflag, varname_list)
    [xdata, ydata, nofpixels, mapdata] = gdata.linecut(X, constraint, NOfPts, dataflag);

    linecutdata.ImFileName = gdata.ImFileName;
    linecutdata.XVarName = varname_list(X);
    linecutdata.XData = xdata;
    linecutdata.YData = ydata;
    linecutdata.NOfPixels = nofpixels;
    linecutdata.MapData = mapdata;
    linecutdata.Constraint = constraint;

    linefit_obj = linefit([xdata(:), ydata(:)]);
end

% batch_chi_linecut.m
% ------------------------------------------------------------------
% Batch script: for every .tif file in INPUTDIR, perform a constrained
% Chi-axis linecut and export each result as a .mat file and .csv file
% to OUTPUTDIR.
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

outputDir = uigetdir(inputDir, 'Select folder to save Chi linecut results');
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

X = 9;                  % linecut predictor: 9 = chi
NOfPts = 1000;          % number of points in each linecut
DataFlagOverride = 2;   % [] to auto-pick (2 if available, else 1)

qRange = [1.66, 1.7];   % q range constraint (in Angstrom^-1)

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
constraint = [1, 1, qRange(1), qRange(2)];
qRangeToken = format_q_range_token(qRange);

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
    [linecutdata, linefit_obj] = do_linecut(gdata, X, constraint, NOfPts, dataflag, varname_list);

    outputBaseName = [baseName, '_', qRangeToken, '_I-chi'];
    matPath = fullfile(outputDir, [outputBaseName, '.mat']);
    csvPath = fullfile(outputDir, [outputBaseName, '.csv']);

    save(matPath, 'linecutdata', 'linefit_obj');
    write_linecut_csv(csvPath, linecutdata.XData, linecutdata.YData);

    delete(gdata);   % gixsdata is a handle class
end

disp('Batch Chi linecut export complete.');

%% ---------------- HELPERS ----------------
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

function write_linecut_csv(csvPath, xdata, ydata)
    fid = fopen(csvPath, 'w');
    if fid == -1
        error('Could not open CSV file for writing: %s', csvPath);
    end

    cleanupObj = onCleanup(@() fclose(fid));

    fprintf(fid, 'Chi,Intensity\n');
    for kk = 1:min(numel(xdata), numel(ydata))
        fprintf(fid, '%.15g,%.15g\n', xdata(kk), ydata(kk));
    end

    clear cleanupObj;
end

function token = format_q_range_token(qRange)
    qMin = strrep(sprintf('%.15g', qRange(1)), '.', 'p');
    qMax = strrep(sprintf('%.15g', qRange(2)), '.', 'p');
    token = ['q', qMin, '-', qMax];
end
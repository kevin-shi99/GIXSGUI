% batch_reshape_image.m
% ------------------------------------------------------------------
% Batch script: for every GapFilled .tif file in INPUTDIR, reshape the
% image using gixsdata.reshape_image and export both:
%   1) a plotted PNG image
%   2) a MAT file containing reshaped numeric results and metadata
% to OUTPUTDIR.
%
% Assumes gixsgui's toolbox path is already on MATLAB's path (run
% gixsgui once, or addpath(genpath('<repo root>')) manually).
% ------------------------------------------------------------------

%% ---------------- USER CONFIGURATION ----------------
repoRoot = fileparts(mfilename('fullpath'));

inputDir = uigetdir(repoRoot, 'Select folder containing GapFilled .tif files');
if isequal(inputDir, 0)
    disp('No input folder selected. Aborting.');
    return;
end

outputDir = uigetdir(repoRoot, 'Select folder to save reshaped PNG/MAT results');
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

DataFlagOverride = [];   % [] = auto-pick (2 if available, else 1)

% Default reshape parameter for qz vs qr.
param_reshape.X = 6;          % qr
param_reshape.Y = 3;          % qz
param_reshape.XNOfPts = 700;  % number of points on X axis
param_reshape.YNOfPts = 700;  % number of points on Y axis
param_reshape.XRange = [-2.4, 0.24];  % range for X axis
param_reshape.YRange = [0, 2.4];  % range for Y axis

log_plot_Clim = [2, 3.7];  % log10 scale color limits for reshaped image plot

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
    disp('No matching GapFilled .tif files found in input folder. Nothing to process.');
    delete(template);
    return;
end

for ii = 1:numel(flist)
    imFile = fullfile(flist(ii).folder, flist(ii).name);
    fprintf('Processing %s (%d/%d)...\n', flist(ii).name, ii, numel(flist));

    gdata = copyhobj(template);
    hFig = [];
    try
        gdata.ImFile = imFile;

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

        [x, y, img_reshaped, countdata] = reshape_image(gdata, param_reshape, dataflag);

        [~, baseName] = fileparts(flist(ii).name);

        reshapedata.ImFileName = gdata.ImFileName;
        reshapedata.SourceFilePath = imFile;
        reshapedata.XFlag = param_reshape.X;
        reshapedata.YFlag = param_reshape.Y;
        reshapedata.XVarName = axis_label(param_reshape.X);
        reshapedata.YVarName = axis_label(param_reshape.Y);
        reshapedata.XData = x;
        reshapedata.YData = y;
        reshapedata.ImageData = img_reshaped;
        reshapedata.CountData = countdata;
        reshapedata.DataFlag = dataflag;
        reshapedata.ReshapeParam = param_reshape;
        reshapedata.LogPlotCLim = log_plot_Clim;

        matName = sprintf('%s_reshaped.mat', baseName);
        save(fullfile(outputDir, matName), 'reshapedata');

        hFig = figure('Visible', 'off', 'Color', 'w');
        plotData = img_reshaped;
        plotData(plotData <= 0) = NaN;

        imagesc(x, y, log10(plotData), log_plot_Clim);
        axis ij;
        set(gca, 'ydir', 'norm');
        xlabel(axis_label(param_reshape.X));
        ylabel(axis_label(param_reshape.Y));

        titleStr = sprintf('%s_reshaped', flist(ii).name);
        title(titleStr, 'Interpreter', 'none');

        pngName = sprintf('%s_reshaped.png', baseName);
        pngPath = fullfile(outputDir, pngName);
        print(hFig, pngPath, '-dpng', '-r200');
    catch ME
        warning('Failed to reshape %s: %s. Skipping.', imFile, ME.message);
    end

    if ~isempty(hFig) && ishandle(hFig)
        close(hFig);
    end
    delete(gdata);   % gixsdata is a handle class
end

delete(template);
disp('Batch reshape PNG + MAT export complete.');

%% ---------------- HELPER ----------------
function label = axis_label(flag)
    switch flag
        case 1
            label = 'q (A^{-1})';
        case 2
            label = 'phi (deg)';
        case 3
            label = 'q_z (A^{-1})';
        case 4
            label = 'q_x (A^{-1})';
        case 5
            label = 'q_y (A^{-1})';
        case 6
            label = 'q_r (A^{-1})';
        case 7
            label = '2theta (deg)';
        case 8
            label = 'alpha_f (deg)';
        case 9
            label = 'chi (deg)';
        case 10
            label = 'x pixel';
        case 11
            label = 'y pixel';
        otherwise
            label = 'axis';
    end
end

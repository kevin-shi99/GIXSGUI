% batch_constrained_linecut.m
% ------------------------------------------------------------------
% Batch script: for every GapFilled tif file in INPUTDIR, perform two
% constrained linecuts (in-plane and out-of-plane azimuthal sectors) and
% export each result as a separate .mat file to OUTPUTDIR.
%
% Assumes gixsgui's toolbox path is already on MATLAB's path (run
% gixsgui once, or addpath(genpath('<repo root>')) manually).
% ------------------------------------------------------------------

%% ---------------- USER CONFIGURATION ----------------
repoRoot    = fileparts(mfilename('fullpath'));

inputDir = uigetdir(repoRoot, 'Select folder containing GapFilled tif files');
if isequal(inputDir,0)
    disp('No input folder selected. Aborting.');
    return;
end

outputDir = uigetdir(repoRoot, 'Select folder to save linecut .mat results');
if isequal(outputDir,0)
    disp('No output folder selected. Aborting.');
    return;
end

filePattern = '*_GapFilled.tif';                    % file selection pattern

[paramFileName, paramFilePath] = uigetfile(fullfile(repoRoot, '*.mat'), ...
    'Select calibration .mat file (exported from gixsgui via Export Parameters)');
if isequal(paramFileName,0)
    disp('No calibration file selected. Aborting.');
    return;
end
paramFile = fullfile(paramFilePath, paramFileName);

X       = 1;    % linecut predictor: 1 = q (total q). See gixsdata.linecut help.
NOfPts  = 600;  % number of points in each linecut
DataFlagOverride = 2;   % leave [] to auto-pick (2 if SolidAngleCorrectedData exists, else 1)

% constraints: [OPERATOR, FLAG, LOWER, UPPER]; FLAG: 1 = q, 2 = phi
% (1st row's OPERATOR is ignored - see gixsdata.get_cmask)
constraintIP  = [1,2,170,180;  1,1,0.25,2.5];   % in-plane:      170<=phi<=180,  0.25<=q<=2.5
constraintOOP = [1,2,85,95; 1,1,0.25,2.5];   % out-of-plane: 85<=phi<=95, 0.25<=q<=2.5

if ~exist(outputDir,'dir'), mkdir(outputDir); end

%% ---------------- BUILD TEMPLATE INSTRUMENT PARAMETERS ----------------
% Calibration is loaded from a .mat file exported by gixsgui's "Export Parameters"
% button (a single variable holding a gixsdata object with Camera/Geometry/
% PixelSize/Beam0/SDD/XEnergy/Specular/IncidentAngle already set).
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
varname_list = {'q','phi','qz','qx','qy','qr','2theta','alpha_f','chi','x_pixel','y_pixel'};

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
        dataflag = 1;   % fall back to MaskedData
    else
        dataflag = 2;   % SolidAngleCorrectedData
    end

    [~, baseName] = fileparts(flist(ii).name);

    % --- linecut 1: in-plane sector (phi 0-10 deg)
    [linecutdata, linefit_obj] = do_linecut(gdata, X, constraintIP, NOfPts, dataflag, varname_list);
    save(fullfile(outputDir, [baseName, '_linecut_IP.mat']), 'linecutdata', 'linefit_obj');

    % --- linecut 2: out-of-plane sector (phi 85-95 deg)
    [linecutdata, linefit_obj] = do_linecut(gdata, X, constraintOOP, NOfPts, dataflag, varname_list);
    save(fullfile(outputDir, [baseName, '_linecut_OOP.mat']), 'linecutdata', 'linefit_obj');

    delete(gdata);   % gixsdata is a handle class - clear alone won't free it
end
disp('Batch linecut export complete.');

%% ---------------- HELPER ----------------
function [linecutdata, linefit_obj] = do_linecut(gdata, X, constraint, NOfPts, dataflag, varname_list)
    [xdata, ydata, nofpixels, mapdata] = gdata.linecut(X, constraint, NOfPts, dataflag);
    linecutdata.ImFileName = gdata.ImFileName;
    linecutdata.XVarName    = varname_list(X);
    linecutdata.XData       = xdata;
    linecutdata.YData       = ydata;
    linecutdata.NOfPixels   = nofpixels;
    linecutdata.MapData     = mapdata;
    linecutdata.Constraint  = constraint;
    % --- linefit object usable directly by linefitgui (same pattern as
    % gixsgui.m's own linecut export: linefitgui([XData,YData]))
    linefit_obj = linefit([xdata(:), ydata(:)]);
end
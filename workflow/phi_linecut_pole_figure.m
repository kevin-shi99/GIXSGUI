% phi_linecut_pole_figure.m
% ------------------------------------------------------------------
% For a single GIWAXS .tif file, perform one phi-axis linecut per q range
% and export each result as a .csv file to OUTPUTDIR.
%
% Shared constraints: X variable = phi, 500 points, 90 <= phi <= 180.
% One linecut per q range in qRanges (4 by default), each written to
%   <basename>_phi_90-180_q_<qmin>-<qmax>.csv
% with columns:
%   phi (deg), chi (deg), I (a.u.), chi (rad), sin(chi), I(X)*sin(X), isotropic
% where chi = phi - 90, so chi = 0 is out-of-plane and chi = 90 is
% in-plane. I(X)*sin(X) is the sin(chi)-corrected pole figure intensity.
% The isotropic column is I_min*sin(chi), where I_min is the minimum
% intensity found within isoPhiRange (100 <= phi <= 170, i.e.
% 10 <= chi <= 80).
%
% Assumes gixsgui's toolbox path is already on MATLAB's path (run
% gixsgui once, or addpath(genpath('<repo root>')) manually).
% ------------------------------------------------------------------

%% ---------------- USER CONFIGURATION ----------------
repoRoot = fileparts(mfilename('fullpath'));

[imFileName, imFilePath] = uigetfile(fullfile(repoRoot, '*.tif'), ...
    'Select GIWAXS .tif file');
if isequal(imFileName, 0)
    disp('No .tif file selected. Aborting.');
    return;
end
imFile = fullfile(imFilePath, imFileName);

outputDir = uigetdir(imFilePath, 'Select folder to save phi linecut .csv files');
if isequal(outputDir, 0)
    disp('No output folder selected. Aborting.');
    return;
end

[paramFileName, paramFilePath] = uigetfile(fullfile(repoRoot, '*.mat'), ...
    'Select calibration .mat file (exported from gixsgui via Export Parameters)');
if isequal(paramFileName, 0)
    disp('No calibration file selected. Aborting.');
    return;
end
paramFile = fullfile(paramFilePath, paramFileName);

X = 2;                  % linecut predictor: 2 = phi (see gixsdata.linecut XFLAG chart)
NOfPts = 500;           % number of points in each linecut
DataFlagOverride = 2;   % [] to auto-pick (2 if available, else 1)

phiRange = [90, 180];   % phi range constraint (in degrees)
isoPhiRange = [100, 170];   % phi window used to pick I_min for the isotropic curve
                            % (100..170 deg phi = 10..80 deg chi)
qRanges = [0.28, 0.4; ...
           0.5,  0.6; ...
           1.2,  1.45; ...
           1.6,  1.85]; % q range constraints (in Angstrom^-1), one linecut per row

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% ---------------- BUILD INSTRUMENT PARAMETERS ----------------
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

%% ---------------- LINECUT LOOP ----------------
% The image is loaded once and reused for all q ranges; only the
% constraint changes between linecuts.
gdata = copyhobj(template);
try
    gdata.ImFile = imFile;
catch ME
    delete(gdata);
    delete(template);
    error('Failed to load %s: %s', imFile, ME.message);
end

if isempty(gdata.QMap)
    delete(gdata);
    delete(template);
    error('No q-maps for %s (check instrument parameters).', imFileName);
end

if ~isempty(DataFlagOverride)
    dataflag = DataFlagOverride;
elseif isempty(gdata.SolidAngleCorrectedData)
    dataflag = 1;   % MaskedData
else
    dataflag = 2;   % SolidAngleCorrectedData
end

[~, baseName] = fileparts(imFileName);
phiToken = ['phi_', format_range_token(phiRange)];

fprintf('Processing %s (%d q ranges)...\n', imFileName, size(qRanges, 1));

for ii = 1:size(qRanges, 1)
    qRange = qRanges(ii, :);

    % constraint format: [OPERATOR, FLAG, LOWER, UPPER]
    % FLAG 2 = phi, FLAG 1 = q; both rows AND-ed together.
    % The phi row is required, not redundant: gixsdata.linecut spans its
    % bins over min..max of the *constrained* pixels, so without it the
    % cut would run over the full detector phi range.
    constraint = [1, 2, phiRange(1), phiRange(2); ...
                  1, 1, qRange(1),   qRange(2)];

    [xdata, ydata] = gdata.linecut(X, constraint, NOfPts, dataflag);

    % Constraint bounds are strictly exclusive, so the cut covers
    % (90,180) and the end bin centers land just inside. Empty bins are
    % dropped by linecut, so fewer than NOfPts rows may come back.
    if isempty(xdata)
        warning('No pixels within %g <= q <= %g and %g <= phi <= %g. Skipping.', ...
            qRange(1), qRange(2), phiRange(1), phiRange(2));
        continue;
    end

    csvName = [baseName, '_', phiToken, '_q_', format_range_token(qRange), '.csv'];
    csvPath = fullfile(outputDir, csvName);
    write_pole_figure_csv(csvPath, xdata, ydata, isoPhiRange);

    fprintf('  q %g-%g: %d points -> %s\n', qRange(1), qRange(2), numel(xdata), csvName);
end

delete(gdata);      % gixsdata is a handle class
delete(template);

disp('Phi linecut pole figure export complete.');

%% ---------------- HELPERS ----------------
function write_pole_figure_csv(csvPath, xdata, ydata, isoPhiRange)
    xdata = xdata(:);
    ydata = ydata(:);
    n = min(numel(xdata), numel(ydata));
    xdata = xdata(1:n);
    ydata = ydata(1:n);

    chiDeg = xdata - 90;            % chi = phi - 90
    chiRad = deg2rad(chiDeg);
    sinChi = sin(chiRad);
    corrected = ydata .* sinChi;    % sin(chi)-corrected pole figure intensity

    % Isotropic curve: take the minimum intensity inside the isotropic phi
    % window (inclusive bounds) and scale it by sin(chi). The window
    % excludes the noisy ends of the cut near chi = 0 and chi = 90.
    isoMask = xdata >= isoPhiRange(1) & xdata <= isoPhiRange(2);
    if any(isoMask)
        iMin = min(ydata(isoMask));
    else
        warning(['No linecut points within %g <= phi <= %g; ', ...
            'isotropic column written as NaN.'], isoPhiRange(1), isoPhiRange(2));
        iMin = NaN;
    end
    isotropic = iMin * sinChi;

    fid = fopen(csvPath, 'w');
    if fid == -1
        error('Could not open CSV file for writing: %s', csvPath);
    end

    cleanupObj = onCleanup(@() fclose(fid));

    fprintf(fid, 'phi (deg),chi (deg),I (a.u.),chi (rad),sin(chi),I(X)*sin(X),isotropic\n');
    for kk = 1:n
        fprintf(fid, '%.15g,%.15g,%.15g,%.15g,%.15g,%.15g,%.15g\n', ...
            xdata(kk), chiDeg(kk), ydata(kk), chiRad(kk), sinChi(kk), ...
            corrected(kk), isotropic(kk));
    end

    clear cleanupObj;
end

function token = format_range_token(range)
    % Dots are preserved (e.g. 0.28 -> '0.28') to match the naming of the
    % existing hand-exported pole_figure/*.txt files.
    token = [sprintf('%g', range(1)), '-', sprintf('%g', range(2))];
end

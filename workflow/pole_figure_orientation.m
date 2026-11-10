% pole_figure_orientation.m
% ------------------------------------------------------------------
% Pole figure, S2D, and Herman's orientation parameter (HOP) from the
% 7-column pole figure linecut .csv files written by
% workflow/phi_linecut_pole_figure.m.
%
% Physics
% -------
% Input is an azimuthal linecut I(chi) at a fixed q range around one Bragg
% peak. The angle convention is the GIXSGUI/thin-film one:
%
%     chi =  0 deg -> out-of-plane direction (qz axis, meridian)
%     chi = 90 deg -> in-plane direction     (qxy axis, equator)
%
% 1. Geometric (sin-chi) correction. A sector of constant angular width
%    subtends a solid angle on the Debye-Scherrer ring that grows as
%    sin(chi), so the raw intensity is weighted to become a pole density:
%
%        P(chi) = I(chi) * sin(chi)
%
% 2. Second moment of the orientation distribution. Unlike the 18-point,
%    5-degree sector data handled by workflow/giwaxs_pole_figure_analysis.py
%    (where equal bin widths cancel and a plain weighted sum is exact), these
%    linecuts carry ~500 densely sampled points, so the moment is obtained by
%    NUMERICAL INTEGRATION over chi:
%
%        <cos^2 chi> = int[ I(chi) * cos^2(chi) * sin(chi) dchi ]
%                      ------------------------------------------
%                      int[ I(chi) * sin(chi) dchi ]
%
%    The dchi factor cancels between numerator and denominator, so the
%    result is the same whether chi is integrated in degrees or radians.
%    Integration limits are NOT hard-coded: by default they are the min and
%    max chi actually present in the file. Set chiLimits below to restrict
%    the window. The limits actually used are reported per file.
%
% 3. Order parameters (both from the same <cos^2 chi>):
%
%        S2D = 2 * <cos^2 chi> - 1          (range -1 .. +1)
%        HOP = (3 * <cos^2 chi> - 1) / 2    (3D Herman's function)
%
%    Note on the isotropic reference: both are fed the SAME sin(chi)-weighted
%    <cos^2 chi>, which equals 1/3 for an isotropic sample. So isotropic
%    gives HOP = 0 but S2D = -1/3, not 0. S2D reads 0 at isotropy only when
%    <cos^2 chi> is computed WITHOUT the sin(chi) weight. Compare S2D values
%    only against other samples processed the same way.
%
% Both parameter sets are reported per file: once on the raw intensity, and
% once on the anisotropic part I - I_min, where I_min is recovered from the
% file's own isotropic column (isotropic = I_min*sin(chi)).
%
% Assumes gixsgui's toolbox path is already on MATLAB's path (run gixsgui
% once, or addpath(genpath('<repo root>')) manually).
% ------------------------------------------------------------------

%% ---------------- USER CONFIGURATION ----------------
repoRoot = fileparts(mfilename('fullpath'));

[fileNames, fileDir] = uigetfile(fullfile(repoRoot, '*.csv'), ...
    'Select pole figure linecut .csv file(s)', 'MultiSelect', 'on');
if isequal(fileNames, 0)
    disp('No .csv files selected. Aborting.');
    return;
end
if ischar(fileNames)        % a single selection comes back as a char row
    fileNames = {fileNames};
end

outputDir = uigetdir(fileDir, 'Select folder to save orientation results');
if isequal(outputDir, 0)
    disp('No output folder selected. Aborting.');
    return;
end

chiLimits = [0 85];          % integration window in degrees. [] = use the full
                         % chi range present in the file. Set e.g. [0 90] to
                         % restrict it.
PlotResolution = 600;    % PNG export resolution (dpi)

summaryName = 'orientation_summary.csv';

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% ---------------- PROCESS FILES ----------------
records = struct('source_file', {}, 'n_points', {}, ...
    'chi_min_deg', {}, 'chi_max_deg', {}, 'I_min', {}, ...
    'cos2_avg_raw', {}, 'S2D_raw', {}, 'HOP_raw', {}, ...
    'cos2_avg_sub', {}, 'S2D_sub', {}, 'HOP_sub', {});

for ii = 1:numel(fileNames)
    csvName = fileNames{ii};
    csvPath = fullfile(fileDir, csvName);
    fprintf('Processing %s (%d/%d)...\n', csvName, ii, numel(fileNames));

    try
        [chiDeg, intensity, isotropic] = read_pole_figure_csv(csvPath);
    catch ME
        warning('Failed to read %s: %s Skipping.', csvName, ME.message);
        continue;
    end

    sinChi = sin(deg2rad(chiDeg));

    % Recover the scalar baseline from the isotropic column
    % (isotropic = I_min*sin(chi)). Evaluate it where sin(chi) is largest so
    % the division stays away from chi = 0.
    [~, kMax] = max(sinChi);
    if sinChi(kMax) > 0
        iMin = isotropic(kMax) / sinChi(kMax);
    else
        warning('%s: sin(chi) is zero everywhere; I_min set to NaN.', csvName);
        iMin = NaN;
    end

    anisotropic = intensity - iMin;
    nNeg = sum(anisotropic < 0);
    if nNeg > 0
        warning('%s: %d of %d points fall below the isotropic baseline.', ...
            csvName, nNeg, numel(anisotropic));
    end

    try
        raw = compute_order_parameters(chiDeg, intensity, chiLimits);
        sub = compute_order_parameters(chiDeg, anisotropic, chiLimits);
    catch ME
        warning('Failed to analyze %s: %s Skipping.', csvName, ME.message);
        continue;
    end

    fprintf('  integrated over %g <= chi <= %g deg (%d points)\n', ...
        raw.chiMin, raw.chiMax, raw.nPoints);
    fprintf('  raw intensity:        <cos^2 chi> = %.4f   S2D = %.4f   HOP = %.4f\n', ...
        raw.cos2avg, raw.S2D, raw.HOP);
    fprintf('  baseline subtracted:  <cos^2 chi> = %.4f   S2D = %.4f   HOP = %.4f\n', ...
        sub.cos2avg, sub.S2D, sub.HOP);

    [~, stem] = fileparts(csvName);
    pngPath  = fullfile(outputDir, [stem, '_pole_figure.png']);
    figPath  = fullfile(outputDir, [stem, '_pole_figure.fig']);
    dataPath = fullfile(outputDir, [stem, '_pole_figure_data.csv']);

    fig = plot_pole_figure(chiDeg, intensity, sinChi, isotropic, anisotropic, csvName);
    exportgraphics(fig, pngPath, 'Resolution', PlotResolution);
    savefig(fig, figPath);
    close(fig);

    write_pole_figure_data(dataPath, chiDeg, intensity, sinChi, isotropic, anisotropic);

    fprintf('  wrote %s\n', [stem, '_pole_figure.png']);
    fprintf('  wrote %s\n', [stem, '_pole_figure.fig']);
    fprintf('  wrote %s\n', [stem, '_pole_figure_data.csv']);

    records(end+1) = struct( ...
        'source_file',  csvName, ...
        'n_points',     raw.nPoints, ...
        'chi_min_deg',  raw.chiMin, ...
        'chi_max_deg',  raw.chiMax, ...
        'I_min',        iMin, ...
        'cos2_avg_raw', raw.cos2avg, ...
        'S2D_raw',      raw.S2D, ...
        'HOP_raw',      raw.HOP, ...
        'cos2_avg_sub', sub.cos2avg, ...
        'S2D_sub',      sub.S2D, ...
        'HOP_sub',      sub.HOP);   %#ok<SAGROW>
end

if isempty(records)
    disp('No files processed successfully. No summary written.');
    return;
end

summaryPath = fullfile(outputDir, summaryName);
writetable(struct2table(records), summaryPath);
fprintf('Summary: %s\n', summaryPath);
disp('Pole figure orientation analysis complete.');

%% ---------------- HELPERS ----------------
function [chiDeg, intensity, isotropic] = read_pole_figure_csv(csvPath)
    % Reads the 7-column .csv written by workflow/phi_linecut_pole_figure.m.
    expectedNames = {'phi (deg)', 'chi (deg)', 'I (a.u.)', 'chi (rad)', ...
        'sin(chi)', 'I(X)*sin(X)', 'isotropic'};

    T = readtable(csvPath, 'VariableNamingRule', 'preserve');

    if ~isequal(T.Properties.VariableNames, expectedNames)
        error(['''%s'' is not a pole figure linecut .csv. Expected the 7 ', ...
            'columns written by phi_linecut_pole_figure.m (%s) but found (%s).'], ...
            csvPath, strjoin(expectedNames, ', '), ...
            strjoin(T.Properties.VariableNames, ', '));
    end

    chiDeg    = T.('chi (deg)');
    intensity = T.('I (a.u.)');
    isotropic = T.('isotropic');

    if isempty(chiDeg)
        error('''%s'' contains no data rows.', csvPath);
    end
end

function out = compute_order_parameters(chiDeg, intensity, chiLimits)
    % <cos^2 chi> by numerical integration over chi, plus S2D and HOP.
    % chiLimits is [lower upper] in degrees, or [] to use the data range.
    chiDeg = chiDeg(:);
    intensity = intensity(:);

    mask = isfinite(chiDeg) & isfinite(intensity);
    if ~isempty(chiLimits)
        mask = mask & chiDeg >= min(chiLimits) & chiDeg <= max(chiLimits);
    end
    if nnz(mask) < 2
        error('Fewer than 2 usable points within the integration window.');
    end

    % trapz needs a monotonically increasing predictor.
    [chiRad, order] = sort(deg2rad(chiDeg(mask)));
    y = intensity(mask);
    y = y(order);

    pChi = y .* sin(chiRad);            % pole density P(chi)
    numerator   = trapz(chiRad, pChi .* cos(chiRad).^2);
    denominator = trapz(chiRad, pChi);

    if denominator == 0 || ~isfinite(denominator)
        error(['integral of I(chi)*sin(chi) is %g; ', ...
            '<cos^2 chi> is undefined for this linecut.'], denominator);
    end

    out.cos2avg  = numerator / denominator;
    out.S2D      = 2 * out.cos2avg - 1;
    out.HOP      = (3 * out.cos2avg - 1) / 2;
    out.nPoints  = numel(chiRad);
    out.chiMin   = rad2deg(chiRad(1));
    out.chiMax   = rad2deg(chiRad(end));
end

function fig = plot_pole_figure(chiDeg, intensity, sinChi, isotropic, anisotropic, titleText)
    pChi = intensity .* sinChi;
    pAniso = anisotropic .* sinChi;

    fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 4.8 3]);
    hold on;
    plot(chiDeg, pChi,      'LineWidth', 1.1, 'DisplayName', 'I(\chi)\cdotsin(\chi)');
    plot(chiDeg, isotropic, 'LineWidth', 1.1, 'LineStyle', '--', ...
        'DisplayName', 'isotropic');
    plot(chiDeg, pAniso,    'LineWidth', 1.1, 'DisplayName', 'anisotropic');

    ax = gca;
    ax.Box = 'on';
    ax.TickDir = 'out';
    ax.XRuler.TickLength = [0.015 0];
    ax.YRuler.TickLength = [0.015 0];
    ax.XRuler.MinorTick = 'off';
    ax.YRuler.MinorTick = 'off';
    ax.LineWidth = 1.2;
    ax.FontSize = 12;
    ax.FontName = 'Arial';

    xlabel('\chi (deg)', 'FontSize', 13);
    ylabel('I(\chi)\cdotsin(\chi) (a.u.)', 'FontSize', 13);
    title(titleText, 'Interpreter', 'none', 'FontSize', 9, 'FontWeight', 'normal');
    legend('Location', 'best', 'Box', 'off', 'FontSize', 10);
    hold off;
end

function write_pole_figure_data(csvPath, chiDeg, intensity, sinChi, isotropic, anisotropic)
    fid = fopen(csvPath, 'w');
    if fid == -1
        error('Could not open CSV file for writing: %s', csvPath);
    end

    cleanupObj = onCleanup(@() fclose(fid));

    fprintf(fid, 'chi_deg,I,sin_chi,P_chi,isotropic,P_chi_anisotropic\n');
    for kk = 1:numel(chiDeg)
        fprintf(fid, '%.15g,%.15g,%.15g,%.15g,%.15g,%.15g\n', ...
            chiDeg(kk), intensity(kk), sinChi(kk), ...
            intensity(kk)*sinChi(kk), isotropic(kk), anisotropic(kk)*sinChi(kk));
    end

    clear cleanupObj;
end

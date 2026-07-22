clear; close all;

repoRoot = fileparts(mfilename('fullpath'));
defaultInputDir = fullfile(repoRoot);
if ~exist(defaultInputDir, 'dir')
    defaultInputDir = repoRoot;
end

[fileNames, fileDir] = uigetfile(fullfile(defaultInputDir, '*.mat'), ...
    'Select sector .mat files to plot together', 'MultiSelect', 'on');
if isequal(fileNames, 0)
    disp('No .mat files selected. Aborting.');
    return;
end

if ischar(fileNames)
    fileNames = {fileNames};
end

outputDir = uigetdir(fileDir, 'Select output directory for PNG, FIG, and CSV exports');
if isequal(outputDir, 0)
    disp('No output directory selected. Aborting.');
    return;
end

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

nFiles = numel(fileNames);
records = struct('fileName', {}, 'sectorDeg', {}, 'x', {}, 'y', {});

for i = 1:nFiles
    thisFile = fullfile(fileDir, fileNames{i});
    S = load(thisFile);

    if ~isfield(S, 'linecutdata')
        warning('Skipping %s: missing variable "linecutdata".', fileNames{i});
        continue;
    end

    lc = S.linecutdata;
    if ~isstruct(lc) || ~isfield(lc, 'XData') || ~isfield(lc, 'YData')
        warning('Skipping %s: linecutdata missing XData/YData.', fileNames{i});
        continue;
    end

    x = lc.XData(:);
    y = lc.YData(:);

    if isempty(x) || isempty(y)
        warning('Skipping %s: empty XData/YData.', fileNames{i});
        continue;
    end

    n = min(numel(x), numel(y));
    x = x(1:n);
    y = y(1:n);
    y(y <= 0) = NaN;

    sectorDeg = parse_sector_from_name(fileNames{i});
    if isnan(sectorDeg)
        sectorDeg = parse_sector_from_constraint(lc);
    end
    if isnan(sectorDeg)
        warning('Skipping %s: could not determine sector center degree.', fileNames{i});
        continue;
    end

    rec.fileName = fileNames{i};
    rec.sectorDeg = sectorDeg;
    rec.x = x;
    rec.y = y;
    records(end + 1) = rec; %#ok<SAGROW>
end

if isempty(records)
    error('No valid sector files were selected.');
end

[~, sortIdx] = sort([records.sectorDeg], 'ascend');
records = records(sortIdx);
nCurves = numel(records);

[~, firstStem] = fileparts(records(1).fileName);
baseName = regexprep(firstStem, '_sector_-?\d+(\.\d+)?deg$', '');
if isempty(baseName)
    baseName = firstStem;
end

cmap = parula(nCurves+1);
cmap = cmap(1:end-1, :);  % exclude last color of bright yellow for better visibility

fig1 = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 4.8 3]);
hold on;

for i = 1:nCurves
    plot(records(i).x, records(i).y, 'LineWidth', 1.1, 'Color', cmap(i, :));
end

ax = gca;
ax.Box = 'on';
ax.TickDir = 'out';
ax.XRuler.TickLength = [0.015 0];
ax.YRuler.TickLength = [0.015 0];
ax.XAxisLocation = 'bottom';
ax.YAxisLocation = 'left';
ax.XRuler.MinorTick = 'off';
ax.YRuler.MinorTick = 'off';
ax.LineWidth = 1.2;
ax.FontSize = 12;
ax.FontName = 'Arial';
set(ax, 'YScale', 'log');
xlim([0.2 2.5]);

xlabel('$$q \: (\mathrm{\AA^{-1}})$$', 'FontSize', 13, 'Interpreter', 'latex');
ylabel('Intensity (a.u.)', 'FontSize', 13);
% title(ax, baseName, 'Interpreter', 'none', 'FontSize', 13);

colormap(cmap);
chiMin = min([records.sectorDeg]);
chiMax = max([records.sectorDeg]);
if chiMin == chiMax
    caxis([chiMin - 0.5, chiMax + 0.5]);
else
    caxis([chiMin, chiMax]);
end

cb = colorbar;
cb.Label.String = '\chi (degree)';
cb.Label.FontSize = 12;
cb.FontSize = 10;
cb.Box = 'off';
cb.TickDirection = 'out';
cb.Ticks = unique([records.sectorDeg]);

pngPath = fullfile(outputDir, [baseName '_sector_azimuth.png']);
figPath = fullfile(outputDir, [baseName '_sector_azimuth.fig']);
csvPath = fullfile(outputDir, [baseName '_sector_azimuth.csv']);

exportgraphics(fig1, pngPath, 'Resolution', 600);
savefig(fig1, figPath);

maxLen = max(arrayfun(@(r) numel(r.x), records));
csvData = cell(maxLen + 2, 2 * nCurves);

for i = 1:nCurves
    colQ = 2 * i - 1;
    colI = 2 * i;
    chiTxt = num2str(records(i).sectorDeg, '%.15g');

    csvData{1, colQ} = ['q_chi' chiTxt];
    csvData{1, colI} = ['intensity_chi' chiTxt];
    csvData{2, colQ} = records(i).sectorDeg;
    csvData{2, colI} = records(i).sectorDeg;

    x = records(i).x;
    y = records(i).y;
    n = numel(x);

    for k = 1:n
        csvData{k + 2, colQ} = x(k);
        csvData{k + 2, colI} = y(k);
    end

    for k = n + 1:maxLen
        csvData{k + 2, colQ} = NaN;
        csvData{k + 2, colI} = NaN;
    end
end

writecell(csvData, csvPath);

fprintf('Export complete.\n');
fprintf('PNG: %s\n', pngPath);
fprintf('FIG: %s\n', figPath);
fprintf('CSV: %s\n', csvPath);

function sectorDeg = parse_sector_from_name(fileName)
    sectorDeg = NaN;
    [~, stem, ~] = fileparts(fileName);
    t = regexp(stem, '_sector_(-?\d+(?:\.\d+)?)deg$', 'tokens', 'once');
    if ~isempty(t)
        sectorDeg = str2double(t{1});
    end
end

function sectorDeg = parse_sector_from_constraint(linecutdata)
    sectorDeg = NaN;
    if ~isstruct(linecutdata) || ~isfield(linecutdata, 'Constraint')
        return;
    end

    c = linecutdata.Constraint;
    if ~isnumeric(c) || size(c, 2) < 4
        return;
    end

    chiRows = find(c(:, 2) == 9, 1, 'first');
    if isempty(chiRows)
        return;
    end

    sectorDeg = mean(c(chiRows, 3:4));
end
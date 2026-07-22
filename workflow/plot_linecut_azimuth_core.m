function result = plot_linecut_azimuth_core(fileDir, fileNames, outputDir, varargin)
% plot_linecut_azimuth_core
% Shared load/plot/export pipeline for azimuthal sector linecuts.

p = inputParser;
p.addParameter('OutputBaseName', '', @(x) ischar(x) || isstring(x));
p.addParameter('ExpectedSectors', [], @isnumeric);
p.addParameter('ExpectedSectorTolerance', 0.51, @isnumeric);
p.addParameter('SectorMismatchTolerance', 0.75, @isnumeric);
p.addParameter('WarnOnSectorMismatch', true, @islogical);
p.addParameter('CloseFigureAfterExport', false, @islogical);
p.parse(varargin{:});
opt = p.Results;

if ischar(fileNames)
    fileNames = {fileNames};
end

if ~iscell(fileNames) || isempty(fileNames)
    error('fileNames must be a non-empty cell array of .mat filenames.');
end

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

records = struct('fileName', {}, 'sectorDeg', {}, 'x', {}, 'y', {});
skipped = struct('fileName', {}, 'reason', {});

for i = 1:numel(fileNames)
    thisFile = fullfile(fileDir, fileNames{i});

    if ~exist(thisFile, 'file')
        skipped(end + 1) = struct('fileName', fileNames{i}, 'reason', 'file not found'); %#ok<AGROW>
        warning('Skipping %s: file not found.', fileNames{i});
        continue;
    end

    S = load(thisFile);

    if ~isfield(S, 'linecutdata')
        skipped(end + 1) = struct('fileName', fileNames{i}, 'reason', 'missing linecutdata'); %#ok<AGROW>
        warning('Skipping %s: missing variable "linecutdata".', fileNames{i});
        continue;
    end

    lc = S.linecutdata;
    if ~isstruct(lc) || ~isfield(lc, 'XData') || ~isfield(lc, 'YData')
        skipped(end + 1) = struct('fileName', fileNames{i}, 'reason', 'missing XData/YData'); %#ok<AGROW>
        warning('Skipping %s: linecutdata missing XData/YData.', fileNames{i});
        continue;
    end

    x = lc.XData(:);
    y = lc.YData(:);

    if isempty(x) || isempty(y)
        skipped(end + 1) = struct('fileName', fileNames{i}, 'reason', 'empty XData/YData'); %#ok<AGROW>
        warning('Skipping %s: empty XData/YData.', fileNames{i});
        continue;
    end

    n = min(numel(x), numel(y));
    x = x(1:n);
    y = y(1:n);
    y(y <= 0) = NaN;

    sectorFromName = parse_sector_from_name(fileNames{i});
    sectorFromConstraint = parse_sector_from_constraint(lc);

    if ~isnan(sectorFromName)
        sectorDeg = sectorFromName;
    else
        sectorDeg = sectorFromConstraint;
    end

    if isnan(sectorDeg)
        skipped(end + 1) = struct('fileName', fileNames{i}, 'reason', 'sector not resolved'); %#ok<AGROW>
        warning('Skipping %s: could not determine sector center degree.', fileNames{i});
        continue;
    end

    if opt.WarnOnSectorMismatch && ~isnan(sectorFromName) && ~isnan(sectorFromConstraint)
        if abs(sectorFromName - sectorFromConstraint) > opt.SectorMismatchTolerance
            warning(['Sector mismatch in %s: filename=%.3f deg, ', ...
                'constraint=%.3f deg. Using filename value.'], ...
                fileNames{i}, sectorFromName, sectorFromConstraint);
        end
    end

    rec.fileName = fileNames{i};
    rec.sectorDeg = sectorDeg;
    rec.x = x;
    rec.y = y;
    records(end + 1) = rec; %#ok<AGROW>
end

if ~isempty(opt.ExpectedSectors)
    expected = opt.ExpectedSectors(:)';
    keepMask = false(1, numel(records));
    for ii = 1:numel(records)
        keepMask(ii) = any(abs(records(ii).sectorDeg - expected) <= opt.ExpectedSectorTolerance);
    end

    dropped = records(~keepMask);
    records = records(keepMask);

    for ii = 1:numel(dropped)
        warning('Skipping %s: sector %.3f deg is outside expected sector set.', ...
            dropped(ii).fileName, dropped(ii).sectorDeg);
        skipped(end + 1) = struct('fileName', dropped(ii).fileName, ...
            'reason', 'sector outside expected range'); %#ok<AGROW>
    end
end

if isempty(records)
    error('No valid sector files were selected.');
end

[~, sortIdx] = sort([records.sectorDeg], 'ascend');
records = records(sortIdx);
nCurves = numel(records);

baseName = char(opt.OutputBaseName);
if isempty(strtrim(baseName))
    [~, firstStem] = fileparts(records(1).fileName);
    baseName = regexprep(firstStem, '_sector_-?\d+(\.\d+)?deg$', '');
    if isempty(baseName)
        baseName = firstStem;
    end
end

cmap = parula(nCurves + 1);
cmap = cmap(1:end-1, :);  % exclude last bright yellow for better visibility

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

colormap(cmap);
chiMin = min([records.sectorDeg]);
chiMax = max([records.sectorDeg]);
if chiMin == chiMax
    clim([chiMin - 0.5, chiMax + 0.5]);
else
    clim([chiMin, chiMax]);
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

if opt.CloseFigureAfterExport && ishghandle(fig1)
    close(fig1);
end

missingSectors = [];
if ~isempty(opt.ExpectedSectors)
    expected = opt.ExpectedSectors(:)';
    present = [records.sectorDeg];
    missingMask = true(size(expected));
    for ii = 1:numel(expected)
        missingMask(ii) = ~any(abs(present - expected(ii)) <= opt.ExpectedSectorTolerance);
    end
    missingSectors = expected(missingMask);
end

fprintf('Export complete.\n');
fprintf('PNG: %s\n', pngPath);
fprintf('FIG: %s\n', figPath);
fprintf('CSV: %s\n', csvPath);

result.baseName = baseName;
result.nCurves = nCurves;
result.sectors = [records.sectorDeg];
result.missingSectors = missingSectors;
result.pngPath = pngPath;
result.figPath = figPath;
result.csvPath = csvPath;
result.skipped = skipped;

end

function sectorDeg = parse_sector_from_name(fileName)
sectorDeg = NaN;
[~, stem, ~] = fileparts(fileName);
t = regexp(stem, '_sector_(-?\d+(?:\.\d+)?)deg', 'tokens');
if ~isempty(t)
    sectorDeg = str2double(t{end}{1});
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

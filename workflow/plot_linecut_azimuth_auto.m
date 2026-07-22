clear; close all;

repoRoot = fileparts(mfilename('fullpath'));
defaultInputDir = fullfile(repoRoot);
if ~exist(defaultInputDir, 'dir')
    defaultInputDir = repoRoot;
end

inputDir = uigetdir(defaultInputDir, 'Select folder containing sector .mat files');
if isequal(inputDir, 0)
    disp('No input folder selected. Aborting.');
    return;
end

outputDir = uigetdir(inputDir, 'Select output directory for PNG, FIG, and CSV exports');
if isequal(outputDir, 0)
    disp('No output directory selected. Aborting.');
    return;
end

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

targetSectors = -5:-10:-85;

files = dir(fullfile(inputDir, '*.mat'));
if isempty(files)
    disp('No .mat files found in selected input folder. Aborting.');
    return;
end

groups = struct('scanId', {}, 'fileNames', {});
unmatched = {};

for i = 1:numel(files)
    fname = files(i).name;
    scanId = parse_scan_id(fname);
    if isempty(scanId)
        unmatched{end + 1} = fname; %#ok<SAGROW>
        continue;
    end

    idx = find(strcmp({groups.scanId}, scanId), 1, 'first');
    if isempty(idx)
        g.scanId = scanId;
        g.fileNames = {fname};
        groups(end + 1) = g; %#ok<SAGROW>
    else
        groups(idx).fileNames{end + 1} = fname; %#ok<SAGROW>
    end
end

if isempty(groups)
    error('No files with recognizable scan token Pxxxx were found.');
end

allMissing = struct('scanId', {}, 'missing', {});
allErrors = struct('scanId', {}, 'message', {});

fprintf('Found %d scan group(s) by Pxxxx in %s\n', numel(groups), inputDir);

for i = 1:numel(groups)
    scanId = groups(i).scanId;
    fileNames = sort(groups(i).fileNames);
    outputBaseName = basename_from_first_file(fileNames{1});

    fprintf('\nProcessing scan group %s (%d file(s))...\n', scanId, numel(fileNames));
    fprintf('Output basename: %s\n', outputBaseName);

    try
        result = plot_linecut_azimuth_core(inputDir, fileNames, outputDir, ...
            'OutputBaseName', outputBaseName, ...
            'ExpectedSectors', targetSectors, ...
            'CloseFigureAfterExport', true);

        if ~isempty(result.missingSectors)
            fprintf('Warning: missing sectors for %s (deg): %s\n', ...
                scanId, num2str(result.missingSectors));
            allMissing(end + 1).scanId = scanId; %#ok<SAGROW>
            allMissing(end).missing = result.missingSectors;
        end

        if ~isempty(result.skipped)
            fprintf('Skipped %d file(s) within %s due to validation/parsing checks.\n', ...
                numel(result.skipped), scanId);
        end
    catch ME
        warning('Failed to process scan group %s: %s', scanId, ME.message);
        allErrors(end + 1).scanId = scanId; %#ok<SAGROW>
        allErrors(end).message = ME.message;
    end
end

fprintf('\nAuto azimuth plotting complete.\n');
fprintf('Processed groups: %d\n', numel(groups));
fprintf('Groups with missing sectors: %d\n', numel(allMissing));
fprintf('Groups with errors: %d\n', numel(allErrors));

if ~isempty(unmatched)
    fprintf('Ignored files without Pxxxx token: %d\n', numel(unmatched));
end

if ~isempty(allMissing)
    fprintf('\nMissing sector summary:\n');
    for i = 1:numel(allMissing)
        fprintf('  %s: %s\n', allMissing(i).scanId, num2str(allMissing(i).missing));
    end
end

if ~isempty(allErrors)
    fprintf('\nError summary:\n');
    for i = 1:numel(allErrors)
        fprintf('  %s: %s\n', allErrors(i).scanId, allErrors(i).message);
    end
end

%% --- Helper function to parse scan ID from filename
function scanId = parse_scan_id(fileName)
scanId = '';
[~, stem, ~] = fileparts(fileName);

m = regexp(stem, '(^|_)(P\d{4})(_|$)', 'tokens', 'once', 'ignorecase');
if ~isempty(m)
    scanId = upper(m{2});
    return;
end

m = regexp(stem, 'P\d{4}', 'match', 'once', 'ignorecase');
if ~isempty(m)
    scanId = upper(m);
end
end

function baseName = basename_from_first_file(fileName)
[~, stem, ~] = fileparts(fileName);
baseName = regexprep(stem, '_sector_-?\d+(\.\d+)?deg$', '');
if isempty(baseName)
    baseName = stem;
end
end

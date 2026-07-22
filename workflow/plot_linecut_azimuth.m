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
result = plot_linecut_azimuth_core(fileDir, fileNames, outputDir);

if ~isempty(result.missingSectors)
    fprintf('Missing sectors (deg): %s\n', num2str(result.missingSectors));
end
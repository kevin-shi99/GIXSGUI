%function plot_linefit_result()
% PLOT_LINEFIT_RESULT Load a saved linefit object, plot fit, and export peak metrics.
%
%   This helper prompts for a .mat file containing a saved linefit object
%   (usually linefit_obj), reproduces the fit plot outside linefitgui using
%   a single fit panel (no residual panel), and writes a CSV report with one
%   row per fitted peak. The CSV includes background parameter values.

repoRoot = fileparts(mfilename('fullpath'));
[matFileName, matFilePath] = uigetfile(fullfile(repoRoot, '*.mat'), ...
    'Select a .mat file containing linefit_obj');
if isequal(matFileName, 0)
    disp('No input file selected. Aborting.');
    return;
end

matFile = fullfile(matFilePath, matFileName);
linefitObj = load_linefit_object(matFile);
if numel(linefitObj) ~= 1
    error('Expected a scalar linefit object in ''%s''.', matFile);
end

if isempty(fieldnames(linefitObj.FitOutput))
    error(['The selected linefit object does not contain fit results. ', ...
        'Run Start Fit in linefitgui first, then save the object again.']);
end

fittedObj = acceptfit(linefitObj);
[xData, yData, yFit, yComponents, yBackground] = evaluate_fit(fittedObj);

[~, baseName, ~] = fileparts(matFileName);
plotFile = fullfile(matFilePath, [baseName, '_fit.png']);
csvFile = fullfile(matFilePath, [baseName, '_peak_report.csv']);

fig = figure('Color', 'w', 'Name', ['LineFit fit - ', baseName], 'NumberTitle', 'off');
if isempty(fittedObj.FitOutput)
    error('Unexpected empty fit output after acceptfit.');
end

ax1 = axes('Parent', fig);
plot_fit_panel(ax1, fittedObj, xData, yData, yFit, yComponents, yBackground, matFileName);

set(fig, 'PaperPositionMode', 'auto');
print(fig, plotFile, '-dpng', '-r300');

reportTable = build_peak_report(fittedObj, matFileName);
writetable(reportTable, csvFile);

disp(['Saved fit plot to ', plotFile]);
disp(['Saved peak report to ', csvFile]);

%end

%% -------------------- HELPER FUNCTIONS -------------------

function linefitObj = load_linefit_object(matFile)
    s = load(matFile);
    if ~isstruct(s)
        error('File ''%s'' is not a valid MAT file.', matFile);
    end

    if isfield(s, 'linefit_obj')
        linefitObj = s.linefit_obj;
    else
        f = fieldnames(s);
        linefitObj = [];
        for ii = 1:numel(f)
            candidate = s.(f{ii});
            if isa(candidate, 'linefit')
                linefitObj = candidate;
                break;
            end
        end
        if isempty(linefitObj)
            error('No linefit object found in ''%s''.', matFile);
        end
    end

    if ~isa(linefitObj, 'linefit')
        error('The selected variable is not a linefit object.');
    end
end

function [xData, yData, yFit, yComponents, yBackground] = evaluate_fit(fittedObj)
    xData = fittedObj.Data(:, 1);
    yData = fittedObj.Data(:, 2);
    [yFit, yComponents, yBackground] = evalmodel(fittedObj);
end

function plot_fit_panel(ax, fittedObj, xData, yData, yFit, yComponents, yBackground, matFileName)
    axes(ax); %#ok<LAXES>
    hold(ax, 'on');
    box(ax, 'on');

    plot(ax, xData, yData, '-', ...
        'LineWidth', 3, ...
        'Color', [0.35 0.35 0.35], ...
        'DisplayName', 'Raw Data');

    plot(ax, xData, yFit, '-', ...
        'LineWidth', 2, ...
        'Color', '#FF00FF', ...
        'DisplayName', 'Cumulative Fit');

    if ~isempty(yBackground)
        plot(ax, xData, yBackground, '--', ...
            'LineWidth', 1.5, ...
            'Color', [0.45 0.45 0.45], ...
            'DisplayName', 'Background');
    end

    if ~isempty(yComponents)
        colorOrder = lines(size(yComponents, 2));
        for ii = 1:size(yComponents, 2)
            plot(ax, xData, yComponents(:, ii), '-', ...
                'LineWidth', 1.5, ...
                'Color', colorOrder(ii, :), ...
                'DisplayName', ['Fit Peak ', num2str(ii)]);
        end
    end

    if fittedObj.FlagLogScale == 1
        set(ax, 'YScale', 'log');
    end

    xlabel(ax, '$$q \: (\AA^{-1})$$', 'Interpreter', 'latex');
    ylabel(ax, 'Intensity');
    xlim(ax, [min(xData), max(xData)]);
    title(ax, matFileName, 'Interpreter', 'none');
    legend(ax, 'Location', 'best');
    set(ax, 'XMinorTick', 'on', 'YMinorTick', 'on');
    hold(ax, 'off');
end

function reportTable = build_peak_report(fittedObj, sourceFileName)
    xReport = linspace(min(fittedObj.Data(:, 1)), max(fittedObj.Data(:, 1)), ...
        max(1000, size(fittedObj.Data, 1))).';

    if fittedObj.CurveModelIndex == -1
        objList = splitmultimodel(fittedObj);
    else
        objList = fittedObj;
    end

    rows = {};
    for objIdx = 1:numel(objList)
        thisObj = objList(objIdx);
        if isempty(fieldnames(thisObj.FitOutput))
            thisObj = acceptfit(thisObj);
        end

        props = getmodelprops(thisObj, xReport);
        rows{end+1, 1} = expand_props(props, sourceFileName, objIdx, thisObj); %#ok<AGROW>
    end

    if isempty(rows)
        reportTable = table();
    else
        reportTable = vertcat(rows{:});
    end
end

function rowTables = expand_props(props, sourceFileName, objIdx, thisObj)
    if isfield(props, 'fwhm')
        nCurve = numel(props.fwhm);
    else
        nCurve = size(props.peak, 2);
    end

    curveIndex = (1:nCurve).';
    peakPosition = props.peak(1, :).';
    peakAmplitude = props.peak(2, :).';
    peakWidth = props.fwhm(:);
    peakWidthCenter = props.fwhm_x(:);

    bkgdParams = thisObj.Model.BkgdModel.StartParams(:).';
    nBkgdParams = numel(bkgdParams);

    coreTable = table(repmat(string(sourceFileName), nCurve, 1), ...
        repmat(objIdx, nCurve, 1), ...
        curveIndex, ...
        repmat(string(thisObj.Model.CurveModel.ModelName), nCurve, 1), ...
        repmat(thisObj.CurveModelIndex, nCurve, 1), ...
        repmat(string(thisObj.Model.BkgdModel.ModelName), nCurve, 1), ...
        repmat(thisObj.BkgdModelIndex, nCurve, 1), ...
        peakAmplitude, peakPosition, peakWidth, peakWidthCenter, ...
        'VariableNames', {'SourceFile', 'ObjectIndex', 'CurveIndex', 'ModelName', ...
        'CurveModelIndex', 'BkgdModelName', 'BkgdModelIndex', 'PeakAmplitude', ...
        'PeakPosition', 'PeakWidth', 'PeakWidthCenter'});

    if nBkgdParams > 0
        bkgdVarNames = arrayfun(@(k)sprintf('BkgdParam%d', k), 1:nBkgdParams, ...
            'UniformOutput', false);
        bkgdTable = array2table(repmat(bkgdParams, nCurve, 1), ...
            'VariableNames', bkgdVarNames);
        rowTables = [coreTable, bkgdTable];
    else
        rowTables = coreTable;
    end
end
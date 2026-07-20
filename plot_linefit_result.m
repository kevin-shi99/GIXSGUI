function plot_linefit_result()
% PLOT_LINEFIT_RESULT Load a saved linefit object, plot the fit, and export peak metrics.
%
%   This helper prompts for a .mat file containing a saved linefit object
%   (usually linefit_obj), reproduces the fit plot outside linefitgui, and
%   writes a CSV report with one row per fitted curve/peak.

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

    ax1 = subplot(2, 1, 1, 'Parent', fig);
    plot_fit_panel(ax1, fittedObj, xData, yData, yFit, yComponents, yBackground);

    ax2 = subplot(2, 1, 2, 'Parent', fig);
    plot_residual_panel(ax2, fittedObj);

    set(fig, 'PaperPositionMode', 'auto');
    print(fig, plotFile, '-dpng', '-r300');

    reportTable = build_peak_report(fittedObj, matFileName);
    writetable(reportTable, csvFile);

    disp(['Saved fit plot to ', plotFile]);
    disp(['Saved peak report to ', csvFile]);
end

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

function plot_fit_panel(ax, fittedObj, xData, yData, yFit, yComponents, yBackground)
    axes(ax); %#ok<LAXES>
    hold(ax, 'on');
    box(ax, 'on');

    plot(ax, xData, yData, 'o', ...
        'MarkerSize', 4, ...
        'MarkerFaceColor', [0.82 0.82 0.82], ...
        'MarkerEdgeColor', [0.25 0.25 0.25], ...
        'Color', [0.35 0.35 0.35], ...
        'DisplayName', 'Data');

    plot(ax, xData, yFit, '-', ...
        'LineWidth', 2.0, ...
        'Color', [0.00 0.35 0.65], ...
        'DisplayName', 'Fit');

    if ~isempty(yBackground)
        plot(ax, xData, yBackground, '--', ...
            'LineWidth', 1.6, ...
            'Color', [0.45 0.45 0.45], ...
            'DisplayName', 'Background');
    end

    if ~isempty(yComponents)
        colorOrder = lines(size(yComponents, 2));
        for ii = 1:size(yComponents, 2)
            plot(ax, xData, yComponents(:, ii), ':', ...
                'LineWidth', 1.2, ...
                'Color', colorOrder(ii, :), ...
                'DisplayName', ['Curve ', num2str(ii)]);
        end
    end

    if fittedObj.FlagLogScale == 1
        set(ax, 'YScale', 'log');
    end

    xlabel(ax, 'X');
    ylabel(ax, 'Intensity');
    title(ax, ['Curve: ', fittedObj.Model.CurveModel.ModelName, ...
        ' | Background: ', fittedObj.Model.BkgdModel.ModelName]);
    legend(ax, 'Location', 'best');
    set(ax, 'XMinorTick', 'on', 'YMinorTick', 'on');
    hold(ax, 'off');
end

function plot_residual_panel(ax, fittedObj)
    if isempty(fittedObj.FitOutput) || ~isfield(fittedObj.FitOutput, 'residual')
        cla(ax);
        axis(ax, 'off');
        return;
    end

    residual = fittedObj.FitOutput.residual;
    plot(ax, fittedObj.Data(:, 1), residual, 'o', ...
        'MarkerSize', 4, ...
        'MarkerFaceColor', [0.85 0.85 0.85], ...
        'MarkerEdgeColor', [0.25 0.25 0.25], ...
        'Color', [0.35 0.35 0.35]);
    box(ax, 'on');
    set(ax, 'XMinorTick', 'on', 'YMinorTick', 'on');
    xlabel(ax, 'X');
    ylabel(ax, 'Residual');

    if isfield(fittedObj.FitOutput, 'ydata') && ~isempty(fittedObj.FitOutput.ydata)
        chi2 = sum((residual(:)).^2 ./ fittedObj.FitOutput.ydata(:));
        title(ax, ['\chi^2 = ', num2str(chi2), ...
            ' | Resnorm = ', num2str(fittedObj.FitOutput.resnorm), ...
            ' | Exitflag = ', num2str(fittedObj.FitOutput.exitflag)]);
    else
        title(ax, ['Resnorm = ', num2str(fittedObj.FitOutput.resnorm), ...
            ' | Exitflag = ', num2str(fittedObj.FitOutput.exitflag)]);
    end
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

    rowTables = table(repmat(string(sourceFileName), nCurve, 1), ...
        repmat(objIdx, nCurve, 1), ...
        curveIndex, ...
        repmat(string(thisObj.Model.CurveModel.ModelName), nCurve, 1), ...
        repmat(thisObj.CurveModelIndex, nCurve, 1), ...
        repmat(thisObj.BkgdModelIndex, nCurve, 1), ...
        peakAmplitude, peakPosition, peakWidth, peakWidthCenter, ...
        'VariableNames', {'SourceFile', 'ObjectIndex', 'CurveIndex', 'ModelName', ...
        'CurveModelIndex', 'BkgdModelIndex', 'PeakAmplitude', 'PeakPosition', ...
        'PeakWidth', 'PeakWidthCenter'});
end
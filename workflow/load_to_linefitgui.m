repoRoot    = fileparts(mfilename('fullpath'));
[linefitFileName, linefitFilePath] = uigetfile(repoRoot, 'Select .mat linefit_obj files');
if isequal(linefitFileName,0)
    disp('No input file selected. Aborting.');
    return;
end

load(fullfile(linefitFilePath, linefitFileName));
linefitgui(linefit_obj)

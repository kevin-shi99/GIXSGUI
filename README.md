# GIXSGUI
MATLAB toolbox for grazing-incidence X-ray scattering data visualization and reduction, and indexing of buried three-dimensional periodic nanostructured films

Last update: 2019.08.23 Revision 1.7.3

Use the code at your own risk. 

Please acknowledges its use by citing the following article 
[Z. Jiang, GIXSGUI: a MATLAB toolbox for grazing-incidence X-ray scattering data visualization and reduction, and indexing of buried
three-dimensional periodic nanostructured films, J. Appl. Crystallogr. 48, 917-926 (2015).](https://doi.org/10.1107/S1600576715004434)

A short tutorial about GIXSGUI is here: http://gisaxs.com/files/Strzalka.pdf (from slide 24)

Comments and questions: gixsgui@anl.gov 

## Batch constrained linecut export

`batch_constrained_linecut.m` (repo root) performs constrained linecuts on a folder of
GapFilled TIF images without opening the `gixsgui` GUI, and exports each result as a `.mat`
file. For every input image it produces two linecuts:

- **In-plane**: `0 <= phi <= 10` and `0.25 <= q <= 2.5`
- **Out-of-plane**: `85 <= phi <= 95` and `0.25 <= q <= 2.5`

### Usage

1. Make sure `gixsgui`'s toolbox path is on MATLAB's path (run `gixsgui` once, or
   `addpath(genpath('<repo root>'))` manually).
2. Open and run `batch_constrained_linecut.m` in MATLAB.
3. A folder-selection dialog prompts for the **input** folder containing `*_GapFilled.tif`
   files (defaults to the repo root).
4. A second dialog prompts for the **output** folder to save results into (defaults to the
   repo root).
5. A file-selection dialog prompts for the **calibration `.mat` file** — a `gixsdata` object
   exported from `gixsgui` via its "Export Parameters" button (Parameters panel), containing
   the correct beam center, SDD, energy, pixel size, incidence angle and specular position for
   the data being processed. Any of the three dialogs can be cancelled to abort the run.
6. For each matching TIF, the script writes two files to the output folder:
   `<name>_linecut_IP.mat` and `<name>_linecut_OOP.mat`, each containing two variables:
   - `linecutdata`, a struct with fields `ImFileName`, `XVarName`, `XData`, `YData`,
     `NOfPixels`, `MapData`, `Constraint` — the same layout produced by `gixsgui`'s own
     linecut "Export to File" (.mat) button.
   - `linefit_obj`, a `linefit` object constructed from `[XData,YData]` (same pattern as
     `gixsgui`'s `linefitgui([XData,YData])` call), which can be loaded directly into
     `linefitgui` via its "Load..." → "LineFit from file" option.

Instrument geometry is taken entirely from the selected calibration `.mat` file (the script
errors out if the file doesn't contain a `gixsdata` object), so to use different instrument
parameters, export a new calibration file from `gixsgui` and select it when prompted. The
linecut predictor (`X`, default `1` = total q), number of points (`NOfPts`), and the two
constraint definitions (`constraintIP`/`constraintOOP`) are also configurable at the top of
the script.

## Batch sector linecut export

`batch_sector_linecut.m` (repo root) performs q-axis linecuts in multiple Chi (azimuth)
sectors for every `.tif` image in a selected input folder, without opening the `gixsgui` GUI.

For each input image, the script applies these constraints per sector:

- **q range**: `0.25 <= q <= 2.5`
- **Chi range**: `x - 5 <= Chi <= x + 5`

where sector centers are:

- `x = [-5, -15, -25, -35, -45, -55, -65, -75, -85]` (degrees)

This produces **9 exported linecut files per input image**.

### Usage

1. Make sure `gixsgui`'s toolbox path is on MATLAB's path (run `gixsgui` once, or
   `addpath(genpath('<repo root>'))` manually).
2. Open and run `batch_sector_linecut.m` in MATLAB.
3. Select the **input** folder containing `.tif` files.
4. Select the **output** folder for `.mat` results.
5. Select the **calibration `.mat` file** exported from `gixsgui` via "Export Parameters"
   (must contain one `gixsdata` object with the instrument geometry for the dataset).
6. For each input file and each sector center `x`, the script writes:
   `<name>_sector_<x>deg.mat`

Examples of output suffixes:

- `_sector_-5deg`
- `_sector_-15deg`
- `_sector_-85deg`

Each output `.mat` contains:

- `linecutdata` struct with fields `ImFileName`, `XVarName`, `XData`, `YData`,
  `NOfPixels`, `MapData`, `Constraint`
- `linefit_obj` (`linefit` object built from `[XData,YData]`, loadable in `linefitgui`)

Implementation notes:

- Predictor axis is fixed to `X = 1` (q-axis linecut).
- Data source defaults to `SolidAngleCorrectedData` (`dataflag = 2`) with fallback support in
  script logic.
- If a file cannot be read or q-maps are unavailable, the script warns and continues.

## Batch reshape image export

`batch_reshape_image.m` (repo root) performs batch image reshaping for GapFilled TIF images,
without opening the `gixsgui` GUI, and exports both a plotted PNG and a MAT
file containing reshaped numeric results per input file.

### Usage

1. Make sure `gixsgui`'s toolbox path is on MATLAB's path (run `gixsgui` once, or
   `addpath(genpath('<repo root>'))` manually).
2. Open and run `batch_reshape_image.m` in MATLAB.
3. Select the **input** folder containing `*_GapFilled.tif` files.
4. Select the **output** folder for PNG/MAT results.
5. Select the **calibration `.mat` file** exported from `gixsgui` via "Export Parameters"
   (must contain one `gixsdata` object with instrument geometry for the dataset).
6. For each input file, the script writes:
   - `<name>_reshaped.png`
   - `<name>_reshaped.mat` (contains one struct variable: `reshapedata`)

### Default reshape and plot settings

- Reshape axes: `X = 6` (qr), `Y = 3` (qz)
- Grid size: `XNOfPts = 700`, `YNOfPts = 700`
- Axis ranges: `XRange = [-2.4, 0.24]`, `YRange = [0, 2.4]`
- Plot scale: `log10` intensity
- Plot color limits: `log_plot_Clim = [1.5, 3.8]`
- Plot title: `<input_filename>.tif_reshaped` (exact input filename with `_reshaped` suffix)

### Notes

- The MAT file stores `reshapedata` fields:
   `ImFileName`, `SourceFilePath`, `XFlag`, `YFlag`, `XVarName`, `YVarName`,
   `XData`, `YData`, `ImageData`, `CountData`, `DataFlag`, `ReshapeParam`,
   `LogPlotCLim`.
- If a file cannot be loaded or q-maps are unavailable, the script warns and continues.
- If any folder/file dialog is cancelled, the script aborts cleanly.

## Plot linefit result and export peak report

`plot_linefit_result.m` (repo root) loads a saved `.mat` file containing a `linefit` object
(typically variable name `linefit_obj`, exported from `linefitgui`), draws a customized fit
plot, and exports a peak report CSV.

### Usage

1. Make sure `gixsgui`'s toolbox path is on MATLAB's path (run `gixsgui` once, or
   `addpath(genpath('<repo root>'))` manually).
2. Open and run `plot_linefit_result.m` in MATLAB.
3. In the file dialog, select a `.mat` file containing a fitted `linefit` object.
4. The script saves outputs to the same folder as the selected MAT file:
   - `<name>_fit.png`
   - `<name>_peak_report.csv`

### Plot style and behavior

- Single fit panel only (no residual panel).
- X-axis label is `q (\AA_{-1})`.
- Fit-panel title is the selected MAT filename (including `.mat`).
- Legend uses `Peak 1`, `Peak 2`, ... for component curves.

### CSV content

The CSV contains one row per fitted peak/curve and includes:

- Source/model metadata: `SourceFile`, `ObjectIndex`, `CurveIndex`, `ModelName`,
  `CurveModelIndex`, `BkgdModelName`, `BkgdModelIndex`
- Peak metrics: `PeakAmplitude`, `PeakPosition`, `PeakWidth`, `PeakWidthCenter`
- Background parameter columns: `BkgdParam1`, `BkgdParam2`, ... (depending on the
  background model)

## HDF5/H5 file support

Both `gixsgui`'s main image loader (`gixsdata.m`, `loadimage`) and
`analysis/gapfill_pilatus/gapfillgui.m` (`update_edit`) can load `.hdf`/`.h5` files
directly, alongside TIF/TIFF and CBF. The loader:

- Reads image data from the standard location `/entry/data/data`.
- If the dataset has multiple frames (a 3D array), sums along the 3rd dimension; a
  single-frame (2D) dataset is used as-is.
- Transposes the result for compatibility with the rest of the toolbox.

### Filter/compression errors

MATLAB's built-in HDF5 library can only decode a fixed set of native filters
(`deflate`/gzip, `shuffle`, `fletcher32`, `nbit`, `scaleoffset`). Some HDF5 files are
written with third-party compression filters (e.g. `lz4`, `bitshuffle`) that require an
external HDF5 plugin MATLAB does not have configured by default. Loading such a file now
fails with a clear error naming the offending filter(s), instead of a raw
`H5PL__find_plugin_in_path` stack trace.

To fix this, use `hdf5_recompress_gui.py` (repo root) to re-encode the problem file to
gzip compression, then load the resulting file instead:

1. Install dependencies: `pip install h5py hdf5plugin` (`tkinter` is part of the Python
   standard library), or use the `env_gixsgui` virtual environment described below.
2. Run `python hdf5_recompress_gui.py`.
3. Click "Add Files..." and select the problem `.h5`/`.hdf` file(s).
4. Click "Output Directory..." and choose where to save the converted file(s).
5. Choose a gzip compression level (1-9, default 4) and click "Convert".
6. Each input file produces `<output_dir>/<stem>_recompressed.h5`, with every chunked
   dataset re-written using gzip compression (structure, groups, and attributes are
   preserved). Load that file in `gixsgui`/`gapfillgui` instead of the original.

This script is standalone and is not called from any MATLAB code in this repository (the
same convention as `correction_functions.py`).

### `env_gixsgui` virtual environment

`env_gixsgui/` (repo root, not tracked in git) is a Python virtual environment created so
`hdf5_recompress_gui.py` has an isolated, reproducible set of dependencies instead of relying on
whatever packages happen to be installed system-wide. It contains `h5py` and `hdf5plugin` (plus
their dependency `numpy`); `tkinter` is not included because it ships with the standard Python
installation.

To activate it (PowerShell):

```powershell
.\env_gixsgui\Scripts\Activate.ps1
```

Once activated, the prompt is prefixed with `(env_gixsgui)` and `python`/`pip` resolve to the
environment's copies. Run the tool with `python hdf5_recompress_gui.py`.

To leave the environment:

```powershell
deactivate
```

If the environment ever needs to be rebuilt (e.g. renamed or corrupted), delete the
`env_gixsgui` folder and recreate it with:

```powershell
python -m venv env_gixsgui
.\env_gixsgui\Scripts\python.exe -m pip install --upgrade pip h5py hdf5plugin
```

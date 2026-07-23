# GIXSGUI
MATLAB toolbox for grazing-incidence X-ray scattering data visualization and reduction, and indexing of buried three-dimensional periodic nanostructured films

Last update: 2019.08.23 Revision 1.7.3

Use the code at your own risk. 

Please acknowledges its use by citing the following article 
[Z. Jiang, GIXSGUI: a MATLAB toolbox for grazing-incidence X-ray scattering data visualization and reduction, and indexing of buried
three-dimensional periodic nanostructured films, J. Appl. Crystallogr. 48, 917-926 (2015).](https://doi.org/10.1107/S1600576715004434)

A short tutorial about GIXSGUI is here: http://gisaxs.com/files/Strzalka.pdf (from slide 24)

Comments and questions: gixsgui@anl.gov 

## HDF4/H5 file support

Both `gixsgui`'s main image loader (`gixsdata.m`, `loadimage`) and
`analysis/gapfill_pilatus/gapfillgui.m` (`update_edit`) can load `.hdf`/`.h4` files
directly, alongside TIF/TIFF and CBF. The loader:

- Reads image data from the standard location `/entry/data/data`.
- If the dataset has multiple frames (a 2D array), sums along the 3rd dimension; a
  single-frame (1D) dataset is used as-is.
- Transposes the result for compatibility with the rest of the toolbox.

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

- `x = [0, -5, -15, -25, -35, -45, -55, -65, -75, -85]` (degrees)

This produces **10 exported linecut files per input image**.

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

## Plot azimuthal sector linecuts and export combined CSV

Azimuth plotting is implemented by three scripts under `workflow/`:

- `plot_linecut_azimuth.m` (manual selection workflow)
- `plot_linecut_azimuth_auto.m` (automatic grouping workflow)
- `plot_linecut_azimuth_core.m` (shared load/plot/export engine used by both scripts)

Both user-facing workflows generate the same figure style and CSV layout.

### 1) Manual plotting workflow (`workflow/plot_linecut_azimuth.m`)

This script loads selected sector linecut `.mat` files (for example, files produced by
`batch_sector_linecut.m`), plots all selected sectors on one log-scale q-intensity figure,
and exports plot/data files.

### Usage

1. Make sure `gixsgui`'s toolbox path is on MATLAB's path (run `gixsgui` once, or
   `addpath(genpath('<repo root>'))` manually).
2. Open and run `workflow/plot_linecut_azimuth.m` in MATLAB.
3. In the file dialog, select one or more sector `.mat` files to plot together
   (`MultiSelect` is enabled).
4. Select an output folder for exports.
5. The script sorts curves by sector center degree, then exports:
   - `<base>_sector_azimuth.png`
   - `<base>_sector_azimuth.fig`
   - `<base>_sector_azimuth.csv`

`<base>` is auto-derived from the first selected filename by removing the trailing
`_sector_<x>deg` suffix.

### 2) Automatic grouping workflow (`workflow/plot_linecut_azimuth_auto.m`)

This script scans a selected folder and groups files by scan token `Pxxxx`, then processes
each group automatically.

Usage summary:

1. Run `workflow/plot_linecut_azimuth_auto.m`.
2. Select an input folder containing sector `.mat` files.
3. Select an output folder.
4. For each detected `Pxxxx` group, the script plots available sector files and exports:
    - `<base>_sector_azimuth.png`
    - `<base>_sector_azimuth.fig`
    - `<base>_sector_azimuth.csv`

Output naming in auto mode:

- `<base>` is derived from the first filename in each group (after sorting), with trailing
   `_sector_<x>deg` removed.
- This keeps dataset-specific naming (for example, sample/condition tokens) rather than using
   only `Pxxxx`.

Grouping and sector behavior:

- Primary grouping key: scan token `Pxxxx` found in filename.
- Target sector set: `[-5, -15, -25, -35, -45, -55, -65, -75, -85]` degrees.
- If some sectors are missing, the script exports using available sectors and reports warnings.

### 3) Shared core function (`workflow/plot_linecut_azimuth_core.m`)

This is an internal shared function used by both workflows. It should normally be called by the
two scripts above, not run directly as a standalone script.

Responsibilities:

- Load and validate `linecutdata` from input `.mat` files.
- Parse sector center from filename (`_sector_<x>deg`) with fallback to
   `linecutdata.Constraint` (Chi row).
- Sort by sector degree, plot log-scale curves, and export PNG/FIG/CSV.
- Keep CSV format consistent across manual and auto workflows.

### Input expectations

Each selected MAT file should contain `linecutdata` with fields:

- `XData` (q)
- `YData` (intensity)

The script reads sector center degree from filename suffix `_sector_<x>deg`. If that parse
fails, it attempts fallback from `linecutdata.Constraint` (Chi constraint row).

### CSV format

The exported CSV uses paired columns per sector (`Layout B`):

- Column pair per sector: `q_chiX`, `intensity_chiX`
- **Row 1**: symbols (column names such as `q_chi-15`, `intensity_chi-15`)
- **Row 2**: sector center degree repeated for both columns in that pair
- **Row 3+**: numeric q/intensity values

If selected sectors have different linecut lengths, shorter columns are padded with `NaN` so all
column pairs align in one combined table.

## Batch reshape image export

`batch_reshape_image.m` (repo root) performs batch image reshaping for GapFilled TIF images,
without opening the `gixsgui` GUI, and exports both a plotted PNG and a MAT
file containing reshaped numeric results per input file, plus a MATLAB FIG
file for interactive post-adjustment.

### Usage

1. Make sure `gixsgui`'s toolbox path is on MATLAB's path (run `gixsgui` once, or
   `addpath(genpath('<repo root>'))` manually).
2. Open and run `batch_reshape_image.m` in MATLAB.
3. Select the **input** folder containing `*_GapFilled.tif` files.
4. Select the **output** folder for PNG/MAT/FIG results.
5. Select the **calibration `.mat` file** exported from `gixsgui` via "Export Parameters"
   (must contain one `gixsdata` object with instrument geometry for the dataset).
6. For each input file, the script writes:
   - `<name>_reshaped.png`
   - `<name>_reshaped.mat` (contains one struct variable: `reshapedata`)
   - `<name>_reshaped.fig`

### Default reshape and plot settings

- Reshape axes: `X = 6` (qr), `Y = 3` (qz)
- Grid size: `XNOfPts = 700`, `YNOfPts = 700`
- Axis ranges: `XRange = [-2.4, 0.24]`, `YRange = [0, 2.4]`
- Plot scale: `log10` intensity
- Plot color limits: `log_plot_Clim = [2, 3.7]`
- Plot title: `<input_filename>.tif_reshaped` (exact input filename with `_reshaped` suffix)

### Notes

- The MAT file stores `reshapedata` fields:
   `ImFileName`, `SourceFilePath`, `XFlag`, `YFlag`, `XVarName`, `YVarName`,
   `XData`, `YData`, `ImageData`, `CountData`, `DataFlag`, `ReshapeParam`,
   `LogPlotCLim`.
- The FIG file can be reopened in MATLAB to adjust color limits/colormap
   directly without rerunning reshape.
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
- X-axis label is `$$q (\AA_{-1})$$` rendered by `latex` interpreter.
- Fit-panel title is the selected MAT filename (including `.mat`).
- Legend uses `Peak 1`, `Peak 2`, ... for component curves.

### CSV content

The CSV contains one row per fitted peak/curve and includes:

- Source/model metadata: `SourceFile`, `ObjectIndex`, `CurveIndex`, `ModelName`,
  `CurveModelIndex`, `BkgdModelName`, `BkgdModelIndex`
- Peak metrics: `PeakAmplitude`, `PeakPosition`, `PeakWidth`, `PeakWidthCenter`
- Background parameter columns: `BkgdParam1`, `BkgdParam2`, ... (depending on the
  background model)


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

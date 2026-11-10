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

## Batch gap fill (up/dn pairs)

`workflow/batch_gapfill.m` gap fills every up/dn image pair in a folder by driving the
`gapfillgui` window (same approach as `mgapfill.m`), and writes one `<up file name>_GapFilled.tif`
per pair. The `_up` file is the base image; the `_dn` file is the vertical offset image at
`X = 0`, `Y = offsetY` (default `-25` pixels).

### Pairing rule

Pairing is done by `workflow/pair_updn_files.m` from the filenames only. Two tokens are assumed
fixed: the scan number `P<digits>` (bounded by start-of-name or `_` and by `_` or end-of-name)
and the position token `_up` / `_dn` (followed by `_` or end-of-name). Everything else in the
name, including the extension, is treated as opaque metadata, so the sample/orientation/angle
naming convention may change. A dn file is paired with an up file when

- `scan(dn) == scan(up) + 1`, and
- the rest of the name is identical (scan token removed, `_up`/`_dn` ignored).

For example `P0256_KS5_xpos000_deg0080_eps0000_up_deg0080.hdf` pairs with
`P0257_KS5_xpos000_deg0080_eps0000_dn_deg0080.hdf`. A `*_recompressed.h5` up file only pairs
with a `*_recompressed.h5` dn file. Files without both tokens (e.g. `P0255_KS5_deg0150.hdf`)
are ignored. Up/dn files that cannot be paired are listed in the command window and the log.

### Usage

1. Make sure `gixsgui`'s toolbox path is on MATLAB's path (run `gixsgui` once).
2. Optional: open `gapfillgui` and set the flat field, gap mask, bad pixel mask and export image
   type. Otherwise the `gapfillgui` defaults are used (export type `single`).
3. Run `workflow/batch_gapfill.m`, select the input folder (`.tif`/`.tiff`/`.cbf`/`.hdf`/`.h5`)
   and the output folder.
4. The output folder receives `<up file name>_GapFilled.tif` per pair, plus `gapfill_log.csv`
   (`up_file`, `dn_file`, `output_file`, `status`) covering all pairs and unmatched files.

Set `dryRun = true` at the top of the script to only print and log the pairing. A pair whose
file cannot be loaded (e.g. an `.h5` using the lz4 filter, see "Filter/compression errors") is
skipped and reported, and the rest of the batch continues.

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

## Batch Chi linecut export

`workflow/batch_chi_linecut.m` performs one Chi-axis linecut for every `.tif` image in a
selected input folder, without opening the `gixsgui` GUI.

For each input image, the script applies these fixed settings:

- **Predictor axis**: `Chi` (`X = 9`)
- **q range**: `1.15 <= q <= 1.5`
- **Number of points**: `1000`

This produces **two exported files per input image**:

- `<name>_q<qmin>-<qmax>_I-chi.mat`
- `<name>_q<qmin>-<qmax>_I-chi.csv`

### Usage

1. Make sure `gixsgui`'s toolbox path is on MATLAB's path (run `gixsgui` once, or
   `addpath(genpath('<repo root>'))` manually).
2. Open and run `workflow/batch_chi_linecut.m` in MATLAB.
3. Select the **input** folder containing `.tif` files.
4. Select the **output** folder for `.mat` and `.csv` results.
5. Select the **calibration `.mat` file** exported from `gixsgui` via "Export Parameters"
   (must contain one `gixsdata` object with the instrument geometry for the dataset).
6. For each input file, the script writes:
   - `<name>_q<qmin>-<qmax>_I-chi.mat`
   - `<name>_q<qmin>-<qmax>_I-chi.csv`

For the default constraint `1.15 <= q <= 1.5`, the q-range portion of the filename is written as:

- `_q1p15-1p5_`

Each output `.mat` contains:

- `linecutdata` struct with fields `ImFileName`, `XVarName`, `XData`, `YData`,
  `NOfPixels`, `MapData`, `Constraint`
- `linefit_obj` (`linefit` object built from `[XData,YData]`, loadable in `linefitgui`)

Each output `.csv` contains exactly two columns:

- Column 1: `Chi`
- Column 2: `Intensity`

The first CSV row is the header:

- `Chi,Intensity`

Implementation notes:

- Predictor axis is fixed to `X = 9` (Chi-axis linecut).
- Constraint is fixed to `1.15 <= q <= 1.5`.
- Data source defaults to `SolidAngleCorrectedData` (`dataflag = 2`) with fallback support in
  script logic.
- If a file cannot be read or q-maps are unavailable, the script warns and continues.

## Phi linecut pole figure export

`workflow/phi_linecut_pole_figure.m` takes a **single** `.tif` image and performs one phi-axis
linecut per q range, without opening the `gixsgui` GUI. It automates what was previously done by
hand in the GUI to produce the files under `pole_figure/`.

Shared settings for every linecut:

- **Predictor axis**: `phi` (`X = 2`)
- **phi range**: `90 <= phi <= 180`
- **Number of points**: `500`

Four q ranges are cut, producing **four `.csv` files** (no `.mat`):

| q range | output file |
| --- | --- |
| `0.28 - 0.4` | `<name>_phi_90-180_q_0.28-0.4.csv` |
| `0.5 - 0.6` | `<name>_phi_90-180_q_0.5-0.6.csv` |
| `1.2 - 1.45` | `<name>_phi_90-180_q_1.2-1.45.csv` |
| `1.6 - 1.85` | `<name>_phi_90-180_q_1.6-1.85.csv` |

Unlike `batch_chi_linecut.m`, decimal points are **preserved** in the filename (`q_0.28-0.4`, not
`q0p28-0p4`) to match the naming of the existing `pole_figure/*.txt` files.

### Usage

1. Make sure `gixsgui`'s toolbox path is on MATLAB's path (run `gixsgui` once, or
   `addpath(genpath('<repo root>'))` manually).
2. Open and run `workflow/phi_linecut_pole_figure.m` in MATLAB.
3. Select the **`.tif` image** to process.
4. Select the **output** folder for the `.csv` results.
5. Select the **calibration `.mat` file** exported from `gixsgui` via "Export Parameters"
   (must contain one `gixsdata` object with the instrument geometry for the dataset).

### CSV content

Each output `.csv` has a header row followed by seven columns:

`phi (deg),chi (deg),I (a.u.),chi (rad),sin(chi),I(X)*sin(X),isotropic`

| column | value |
| --- | --- |
| `phi (deg)` | linecut predictor, from `gixsdata.linecut` |
| `chi (deg)` | `phi - 90` (0 = out-of-plane, 90 = in-plane) |
| `I (a.u.)` | linecut intensity |
| `chi (rad)` | `deg2rad(chi)` |
| `sin(chi)` | `sin` of the radian value |
| `I(X)*sin(X)` | `I * sin(chi)` — the sin(chi)-corrected pole figure intensity |
| `isotropic` | `I_min * sin(chi)` — the isotropic baseline curve |

`I_min` is the **minimum** intensity found within `isoPhiRange`, by default
`100 <= phi <= 170` (equivalently `10 <= chi <= 80`). The window deliberately excludes the
ends of the cut near `chi = 0` and `chi = 90`, where the tails are noisiest. Bounds are
inclusive. If no linecut point falls inside the window, the script warns and writes `NaN`
for the whole column.

Implementation notes:

- The image is loaded once and reused for all four linecuts; only the constraint changes.
- The constraint is two rows, `[1,2,90,180; 1,1,qmin,qmax]` (`FLAG 2 = phi`, `FLAG 1 = q`). The
  phi row is required, not redundant: `gixsdata.linecut` spans its bins over the min/max of the
  *constrained* pixels only, so without it the cut would run over the full detector phi range.
- Constraint bounds are strictly exclusive, so the cut covers `(90,180)` and the first/last bin
  centers land just inside. Empty bins are dropped by `linecut`, so a file may contain slightly
  fewer than 500 rows.
- Data source defaults to `SolidAngleCorrectedData` (`dataflag = 2`).
- If a q range selects no pixels, the script warns and continues to the next range.
- These CSVs are consumed by `workflow/pole_figure_orientation.m`, which computes `<cos^2 chi>`,
  S2D and HOP from them by numerical integration. They are **not** directly consumable by
  `workflow/giwaxs_pole_figure_analysis.py`, which expects a two-column file of 18 points at
  5-degree bin centers.

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

`workflow/giwaxs_pole_figure_analysis.py` additionally needs `matplotlib`, which is **not**
installed in `env_gixsgui` by default. Either add it to the environment
(`.\env_gixsgui\Scripts\python.exe -m pip install matplotlib`) or run that script with another
interpreter that already has `numpy` + `matplotlib` (e.g. an Anaconda base environment).

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

## GIWAXS pole figure, S2D, and Herman's orientation parameter (HOP)

`workflow/giwaxs_pole_figure_analysis.py` turns azimuthal (Chi) linecuts into sin(χ)-corrected
pole figures and the associated orientation parameters. It is a **standalone Python script**, not
called from any MATLAB code in this repository (the same convention as `correction_functions.py`
and `hdf5_recompress_gui.py`).

### Physics

The input is `I(χ)` from sector integration of a 2D GIWAXS pattern at a fixed q-range around one
Bragg peak, in the usual thin-film convention:

- `χ = 0°` → out-of-plane direction (qz axis, meridian)
- `χ = 90°` → in-plane direction (qxy axis, equator)

1. **Geometric correction.** A constant-width azimuthal sector subtends a solid angle on the
   Debye-Scherrer ring that grows as `sin(χ)`, so the pole figure is
   `P(χ) = I(χ)·sin(χ)`.
2. **Second moment**, as a direct weighted sum over the discrete sector bins (*not* a trapezoidal
   or other continuous-integration rule, because each point is already a sector average):

   ```
   <cos^2 chi> = sum_i [ I(chi_i) * cos^2(chi_i) * sin(chi_i) ] / sum_i [ I(chi_i) * sin(chi_i) ]
   ```

   All bins share the same 5° width, so the width cancels between numerator and denominator and
   never appears explicitly. (For unevenly-spaced or variable-width bins each term would need an
   explicit `* delta_chi_i` weight — noted in the code, not implemented.)
3. **Order parameters**, both from that same `<cos^2 chi>`:

   ```
   S2D = 2 * <cos^2 chi> - 1
   HOP = (3 * <cos^2 chi> - 1) / 2
   ```

> **Isotropic reference.** Because both parameters are fed the same *sin(χ)-weighted*
> `<cos^2 chi>` (which equals `1/3` for an isotropic sample), an isotropic linecut gives
> `HOP = 0` but `S2D = -1/3`, **not** `0`. S2D only reads 0 at isotropy when `<cos^2 chi>` is
> computed *without* the `sin(χ)` weight. Compare S2D values only between samples processed the
> same way.

### Input data

Two-column text, one row per azimuthal bin:

- Column 1: χ in **degrees** — 5° sector bin centres
- Column 2: intensity `I(χ)`, background-subtracted, arbitrary units

Both headerless whitespace/tab/comma-separated `.txt` and the `Chi,Intensity` `.csv` written by
`workflow/batch_chi_linecut.m` are accepted; a non-numeric header row, blank lines and `#`/`%`
comment lines are skipped, and rows are sorted by χ ascending. The expected shape is **18 points
spanning 2.5°–87.5°** (bin centres over 0–90°, endpoints not included).

Input filenames are parsed for the metadata tokens `P####` (scan), `KS##` (sample),
`para`/`perp` (orientation), `deg####` (incident angle), `Chi_0-90` (χ range) and `q_#-#`
(q range, also the MATLAB `q1p15-1p5` spelling where `p` is the decimal point). Missing tokens
produce a warning and an empty field — a file with an unexpected name still processes.

### Usage

```powershell
# every .txt/.csv linecut in a folder
python workflow\giwaxs_pole_figure_analysis.py .\linecuts

# a single file
python workflow\giwaxs_pole_figure_analysis.py .\linecuts\P0028_KS12_para_deg0120_Chi_0-90_q_1-2.txt

# custom output folder, also display the figures
python workflow\giwaxs_pole_figure_analysis.py .\linecuts --outdir .\pole_figures --show
```

Options:

- `--outdir DIR` — output directory (default: a `pole_figure/` sub-folder next to the input data)
- `--pattern GLOB` — filename filter in folder mode (default `*`)
- `--dpi N` — PNG resolution (default 200)
- `--show` — display the figures as well as saving them

The default input path when no argument is given is the `DEFAULT_INPUT_PATH` variable at the top
of the script; the expected bin count, χ range, extensions and DPI are configurable there too.

### Outputs

Per input file:

- `<name>_pole_figure.png` — χ (deg) vs `I(χ)·sin(χ)` (a.u.), markers + line
- `<name>_pole_figure_data.csv` — columns `chi_deg,intensity,P_chi`
- `<name>_orientation_summary.json` — `cos2_avg`, `S2D`, `HOP`, the parsed filename metadata,
  the source path, point count, and the list of warnings raised for that file

Plus one combined table over all processed files:

- `orientation_summary_all.csv` — one row per file, columns `source_file`, `scan`, `sample`,
  `orientation`, `incidence`, `chi_range`, `q_range`, `n_points`, `cos2_avg`, `S2D`, `HOP`

The three order parameters are also printed to stdout per file:

```
  <cos^2 chi> = 0.7477
  S2D         = 0.4954
  HOP         = 0.6216
```

### Warnings and data handling

Nothing is silently dropped. The script warns and continues when:

- the point count is not 18, or the χ range differs from 2.5°–87.5°
- χ spacing is non-uniform (the equal-bin-width cancellation above no longer holds)
- χ values fall outside 0–90°
- non-finite (NaN/Inf) intensities are present — they are kept, so `<cos^2 chi>`, `S2D` and `HOP`
  come out non-finite (written as `null` in the JSON, `nan` in the CSVs) rather than being
  quietly interpolated away
- negative intensities are present (over-subtracted background)
- filename metadata tokens are missing
- non-numeric or short rows were skipped while reading

No missing-wedge handling is performed. A file that cannot be read at all is reported and skipped;
the remaining files still process. Outputs written by a previous run are never re-ingested as
input.

## Pole figure orientation analysis (MATLAB)

`workflow/pole_figure_orientation.m` computes ⟨cos²χ⟩, S2D and the Herman's orientation parameter
(HOP) from the 7-column pole figure linecut `.csv` files written by
`workflow/phi_linecut_pole_figure.m`.

It is the MATLAB counterpart to `workflow/giwaxs_pole_figure_analysis.py` above and uses the same
physics — see [Physics](#physics) for the sin(χ) correction, the S2D/HOP formulas, and the caveat
that an isotropic sample reads `HOP = 0` but `S2D = -1/3`. The one deliberate difference is the
**second moment is computed by numerical integration (`trapz`), not by a weighted sum**:

```
<cos^2 chi> = int[ I(chi) * cos^2(chi) * sin(chi) dchi ] / int[ I(chi) * sin(chi) dchi ]
```

The Python script's weighted sum is exact only because its 18 points are equal-width 5° sector
bins, so the bin width cancels. These linecuts carry ~500 densely sampled points where that
reasoning buys nothing, and `trapz` is the right tool. On a uniform grid the two converge:

| points | `trapz` | weighted sum | difference |
| --- | --- | --- | --- |
| 18 | 0.483824 | 0.469539 | 1.4e-02 |
| 100 | 0.472064 | 0.469402 | 2.7e-03 |
| 500 | 0.469932 | 0.469397 | 5.4e-04 |
| 2000 | 0.469531 | 0.469397 | 1.3e-04 |

**Integration limits are not hard-coded.** By default they are the minimum and maximum χ actually
present in the file. Set `chiLimits = [lower upper]` (degrees) near the top of the script to
restrict the window. Either way the limits actually integrated over are recorded per file in the
summary table, so a number is always traceable to the window that produced it.

The dχ factor cancels between numerator and denominator, so integrating in degrees or radians
gives the same answer.

### Usage

1. Make sure `gixsgui`'s toolbox path is on MATLAB's path (run `gixsgui` once, or
   `addpath(genpath('<repo root>'))` manually).
2. Open and run `workflow/pole_figure_orientation.m` in MATLAB.
3. Select one or more pole figure linecut `.csv` files (the dialog is multi-select, so all four
   q ranges from one scan can be done in a single run).
4. Select the **output** folder for the results.

### Input data

Only the 7-column `.csv` written by `workflow/phi_linecut_pole_figure.m` is accepted. The header is
checked exactly:

`phi (deg),chi (deg),I (a.u.),chi (rad),sin(chi),I(X)*sin(X),isotropic`

A file with any other header is reported and skipped, and the run continues with the remaining
selections. The two-column `pole_figure/*.txt` files belong to the Python script, not this one.

### Outputs

Two parameter sets are reported for every file:

- **raw** — computed from `I (a.u.)` as-is, directly comparable to the Python script's numbers.
- **baseline subtracted** — computed from `I - I_min`, the anisotropic part only. `I_min` is
  recovered from the file's own `isotropic` column (`isotropic = I_min*sin(chi)`), evaluated where
  `sin(chi)` is largest so the division stays away from χ = 0.

Per input file, with `<stem>` the input basename:

| file | content |
| --- | --- |
| `<stem>_pole_figure.png` | χ vs `I·sin(χ)`, the isotropic baseline, and the anisotropic difference (600 dpi) |
| `<stem>_pole_figure.fig` | the same figure, re-openable in MATLAB |
| `<stem>_pole_figure_data.csv` | `chi_deg,I,sin_chi,P_chi,isotropic,P_chi_anisotropic` |

Plus one combined table per run, `orientation_summary.csv` in the output folder, with one row per
file:

`source_file, n_points, chi_min_deg, chi_max_deg, I_min, cos2_avg_raw, S2D_raw, HOP_raw,
cos2_avg_sub, S2D_sub, HOP_sub`

The three numbers of each set are also printed to the command window as each file is processed.

### Implementation notes

- Non-finite χ or intensity values are excluded from the integration; `trapz` is fed a sorted
  predictor, so an unsorted input file gives the same answer.
- If the integral of `I(χ)·sin(χ)` is zero or non-finite, ⟨cos²χ⟩ is undefined — the file is
  reported and skipped rather than yielding a silent `NaN`.
- Points falling below the isotropic baseline are **warned about, not dropped**, matching the
  warn-only policy of the Python script. This is expected for χ beyond the `isoPhiRange` window
  used to pick `I_min`.
- One bad file never aborts the batch: reading and analysis are each wrapped so the run continues.

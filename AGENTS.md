# GIXSGUI

MATLAB toolbox for grazing-incidence X-ray scattering (GIXS) data visualization, reduction, and
indexing of buried 3D periodic nanostructures. See [README.md](README.md) for citation info and
background.

## Architecture

- [gixsgui.m](gixsgui.m) is the main entry point. Its first line
  (`addpath(genpath(fileparts(which('gixsgui'))));`) adds the entire toolbox tree to the MATLAB
  path at launch — subfolders never need to be added manually, and scripts/demos assume `gixsgui`
  has been run at least once in the session (or the path is otherwise already set).
- [gixsdata.m](gixsdata.m) is the core data model: a `handle` class holding one loaded detector
  image plus instrument geometry (camera, pixel size, beam center, SDD, energy, incidence angle)
  and correction state (flat field, efficiency, polarization, Lorentz factor, solid angle). Because
  it's a `handle` class, `clear obj` does not free it — call `delete(obj)`. Both the interactive GUI
  and scripts under `demos/` operate on `gixsdata` instances directly.
- `analysis/<subsystem>/` contains independent tool GUIs, each launched by a no-argument function
  named `<subsystem>gui.m` (e.g. `gapfillgui`, `roiscangui`, `sddcalibgui`, `sumimggui`,
  `gfitgui`). `analysis/indexing/` is a library of crystallography math (metric tensors, space
  group lookups) with no GUI. `analysis/gapfill_pilatus/` fills Pilatus detector module
  gaps/bad-pixels using calibration assets in `pilatus_1mf/`.
- `matlabimtools/` (functions prefixed `gu_`, e.g. `gu_getpts.m`) is a vendored/adapted subset of
  Image Processing Toolbox interactive picking tools, used so parts of the toolbox work without
  that license.
- `utilities/`, `readcbf/` (CBF reader, MEX-accelerated on Linux only, no Windows `.mexw64`), and
  `xrayrefraction/` (optical-constant calculations from `periodictable.mat`) are shared helpers.
- `linefit/` is a standalone 1D curve-fitting subsystem (`classdef linefit`, not a `handle` class)
  with its own GUI (`linefitgui.m`).
- [correction_functions.py](correction_functions.py) is a standalone NumPy port of a few
  `gixsdata.m` correction methods (solid angle, efficiency, polarization). It is not called from
  any MATLAB code — treat MATLAB as the source of truth and update this file manually if the
  MATLAB corrections change.
- [hdf5_recompress_gui.py](hdf5_recompress_gui.py) is another standalone, non-integrated Python
  tool (same convention as `correction_functions.py`): a Tkinter GUI that re-encodes HDF5 files
  using non-native compression filters (e.g. lz4) to gzip, so they can be loaded by MATLAB's HDF5
  loaders below.
- `demos/` holds runnable example scripts paired with saved `.mat` parameter sets. They hardcode
  the original author's network paths (e.g. `N:\2014-2\...`) — treat as templates to adapt, not
  as scripts to run unmodified.
- [workflow/batch_gapfill.m](workflow/batch_gapfill.m) batch gap fills up/dn image pairs by driving
  the `gapfillgui` window (like `mgapfill.m`; uses the GUI's current FF/masks/export type), with the
  `_up` file as base and the `_dn` file as vertical offset image at `[0 offsetY]` (default `-25`).
  Pairing lives in [workflow/pair_updn_files.m](workflow/pair_updn_files.m): only the `P<scan>` and
  `_up`/`_dn` tokens are parsed; dn must be scan+1 and the rest of the filename (incl. extension)
  must match exactly, so metadata naming may change. Because `gapfillgui`'s loader keeps the old
  file/data on a failed load, the script verifies the loaded file names after every load. See the
  "Batch gap fill (up/dn pairs)" section of [README.md](README.md).
- [workflow/batch_constrained_linecut.m](workflow/batch_constrained_linecut.m) is a standalone batch
  script that drives `gixsdata` directly (no GUI): it builds one template `gixsdata` object from
  [giwaxs_configure.json](giwaxs_configure.json), `copyhobj`s it per input TIF (mirroring the
  load pattern in `gixsgui.m`), runs two constrained `linecut` calls (in-plane and out-of-plane
  azimuthal sectors) per file, and saves each result to a `.mat` file containing both a
  `linecutdata` struct (the same schema as `gixsgui`'s own "Export current linecut to file"
  (`.mat`) output) and a `linefit_obj` (`linefit` object built from `[XData,YData]`, loadable
  directly by `linefitgui`). See the "Batch constrained linecut export" section of
  [README.md](README.md) for usage.
- [workflow/batch_sector_linecut.m](workflow/batch_sector_linecut.m) is a standalone batch script for
  sector-resolved q linecuts: it iterates all `.tif` files in a selected input folder, applies
  `0.25<=q<=2.5` plus Chi-window constraints `x-5<=Chi<=x+5` for
  `x=[-5,-15,-25,-35,-45,-55,-65,-75,-85]`, and exports one `.mat` per sector with suffix
  `_sector_<x>deg`, each containing `linecutdata` and `linefit_obj`. See the "Batch sector
  linecut export" section of [README.md](README.md) for usage.
- [workflow/batch_chi_linecut.m](workflow/batch_chi_linecut.m) is a standalone batch script for
  Chi-axis linecuts: it iterates all `.tif` files in a selected input folder, applies the fixed
  constraint `1.15<=q<=1.5`, performs a `Chi` linecut with `1000` points, and exports one `.mat`
  plus one two-column `.csv` per input file with suffix `_q<qmin>-<qmax>_I-chi`. The `.mat` contains
  `linecutdata` and `linefit_obj`; the `.csv` contains `Chi,Intensity`. See the "Batch Chi
  linecut export" section of [README.md](README.md) for usage.
- [workflow/phi_linecut_pole_figure.m](workflow/phi_linecut_pole_figure.m) is a standalone script
  for phi-axis pole-figure linecuts on a **single** `.tif` (contrast with the `batch_*` scripts,
  which iterate a folder with one constraint — this one inverts that: one file, four constraints).
  It prompts for the `.tif`, an output folder, and a calibration `.mat`, loads the image once, and
  runs four `phi` linecuts (`X=2`, `500` points, `90<=phi<=180`) at q ranges `0.28-0.4`, `0.5-0.6`,
  `1.2-1.45`, `1.6-1.85`. It exports `.csv` only (no `.mat`/`linefit_obj`), named
  `<basename>_phi_90-180_q_<qmin>-<qmax>.csv` with decimal points preserved (matching
  `pole_figure/*.txt`, unlike `batch_chi_linecut.m`'s `p`-for-dot mangling). Each `.csv` has seven
  columns: `phi (deg)`, `chi (deg)` (`=phi-90`), `I (a.u.)`, `chi (rad)`, `sin(chi)`,
  `I(X)*sin(X)` (the sin(chi)-corrected pole figure intensity), and `isotropic`
  (`I_min*sin(chi)`, where `I_min` is the minimum intensity inside `isoPhiRange`, by default
  `100<=phi<=170` i.e. `10<=chi<=80`). See the "Phi linecut pole figure export" section of
  [README.md](README.md) for usage.
- [workflow/pole_figure_orientation.m](workflow/pole_figure_orientation.m) is the MATLAB
  counterpart to `giwaxs_pole_figure_analysis.py`: it consumes the 7-column `.csv` files from
  `phi_linecut_pole_figure.m` (header checked exactly; no 2-column fallback) and computes
  `<cos^2 chi>`, `S2D` and the Herman's orientation parameter by **numerical integration**
  (`trapz`) rather than the Python script's equal-bin weighted sum, which is only exact for the
  18-point 5-degree sector data. Integration limits are not hard-coded: they default to the chi
  range present in the file, overridable via `chiLimits`, and the effective limits are recorded
  per file. Input is multi-select. Two parameter sets are reported per file - raw `I`, and the
  anisotropic part `I - I_min` where `I_min` is recovered from the file's own `isotropic` column.
  Outputs per file are `<stem>_pole_figure.png`/`.fig`/`_pole_figure_data.csv`, plus one combined
  `orientation_summary.csv` per run. See the "Pole figure orientation analysis (MATLAB)" section
  of [README.md](README.md) for usage.
- [workflow/plot_linecut_azimuth.m](workflow/plot_linecut_azimuth.m) is the interactive/manual
  post-processing script for sector linecuts: it prompts for multiple sector `.mat` files,
  plots selected azimuthal sectors together (log-scale intensity vs q), and exports PNG/FIG plus
  a combined CSV table with paired `q`/`intensity` columns per sector and two metadata header
  rows (symbol row and sector-center-degree row).
- [workflow/plot_linecut_azimuth_auto.m](workflow/plot_linecut_azimuth_auto.m) is the automatic
  folder workflow: it groups sector `.mat` files by scan token `Pxxxx` and exports one
  azimuthal plot set per group.
- [workflow/plot_linecut_azimuth_core.m](workflow/plot_linecut_azimuth_core.m) is the shared
  internal load/plot/export function used by both manual and auto scripts.
- [workflow/giwaxs_pole_figure_analysis.py](workflow/giwaxs_pole_figure_analysis.py) is a third
  standalone, non-integrated Python tool (same convention as `correction_functions.py` and
  `hdf5_recompress_gui.py`): a CLI that reads two-column azimuthal linecuts (`.txt`, or the
  `Chi,Intensity` `.csv` from `batch_chi_linecut.m`), applies the `sin(chi)` geometric
  correction, plots the pole figure, and computes `<cos^2 chi>`, `S2D` and the Herman's
  orientation parameter (HOP) by a discrete weighted sum over equal-width 5-degree sector bins.
  Accepts a folder or a single file; needs `numpy` + `matplotlib` (matplotlib is NOT in
  `env_gixsgui`). See the "GIWAXS pole figure, S2D, and Herman's orientation parameter (HOP)"
  section of [README.md](README.md).

## Conventions

- **Singleton figure pattern**: every `*gui.m` checks for an existing figure by `Tag` before
  creating a new one (`hFig = findall(0,'Tag','<tag>'); if ~isempty(hFig), figure(hFig); return; end`).
  Follow this when adding a new tool GUI.
- **State storage**: GUIs are single monolithic files with nested/local callback functions. State
  lives in a struct called `udata` stored via `set(hFig,'UserData',udata)` /
  `get(hFig,'UserData')` — not `guidata`/`setappdata`. Follow the existing pattern in a file
  (e.g. [analysis/gapfill_pilatus/gapfillgui.m](analysis/gapfill_pilatus/gapfillgui.m)) rather than
  introducing a different state-management style.
- Files carry an ANL/UChicago copyright banner and a manual `$Revision$ $Date$` changelog comment
  block at the top; preserve/update this rather than removing it when editing existing files.

## No build/test/CI

There is no automated test suite, CI pipeline, or MATLAB toolbox packaging (`.mltbx`/`.prj`) in
this repo — do not assume one exists or try to invoke `matlab -batch runtests`. Validate changes by
running the relevant `*gui.m` or demo script manually in MATLAB. Optional toolbox dependencies are
checked at runtime via `license(...)`: Optimization Toolbox (`sddcalibgui.m`, diffraction-position
solving in `gixsgui.m`), Image Processing Toolbox (`linefitgui.m`, `matlabimtools`), Curve Fitting
Toolbox (linecut export).

## Recent work

See the "HDF5/H5 file support" section of [README.md](README.md) for the HDF/H5 loading support
in `gixsdata.m` and `analysis/gapfill_pilatus/gapfillgui.m` (reads `/entry/data/data`), and for the
filter-mismatch error handling (`utilities/hdf5filtermsg.m`) plus the `hdf5_recompress_gui.py`
workaround for files using non-native HDF5 compression filters.

See also the "Batch constrained linecut export", "Batch sector linecut export",
"Batch Chi linecut export", and "Phi linecut pole figure export" sections of
[README.md](README.md) for non-GUI batch linecut workflows.

See the "GIWAXS pole figure, S2D, and Herman's orientation parameter (HOP)" section of
[README.md](README.md) for the Python post-processing step that consumes those Chi linecuts, and
the "Pole figure orientation analysis (MATLAB)" section for the MATLAB script that computes the
same order parameters from the 7-column phi linecut CSVs by numerical integration.

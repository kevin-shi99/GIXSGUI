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

See also the "Batch constrained linecut export" and "Batch sector linecut export" sections of
[README.md](README.md) for non-GUI batch linecut workflows.

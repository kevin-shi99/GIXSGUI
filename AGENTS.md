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
- `demos/` holds runnable example scripts paired with saved `.mat` parameter sets. They hardcode
  the original author's network paths (e.g. `N:\2014-2\...`) — treat as templates to adapt, not
  as scripts to run unmodified.

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

See [GAPFILLGUI_HDF_UPDATE_SUMMARY.md](GAPFILLGUI_HDF_UPDATE_SUMMARY.md) for the HDF/H5 loading
support added to `analysis/gapfill_pilatus/gapfillgui.m` (reads `/entry/data/data`, matching the
pattern already used in `gixsdata.m`).

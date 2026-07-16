# GIXSGUI
MATLAB toolbox for grazing-incidence X-ray scattering data visualization and reduction, and indexing of buried three-dimensional periodic nanostructured films

Last update: 2019.08.23 Revision 1.7.3

Use the code at your own risk. 

Please acknowledges its use by citing the following article 
[Z. Jiang, GIXSGUI: a MATLAB toolbox for grazing-incidence X-ray scattering data visualization and reduction, and indexing of buried
three-dimensional periodic nanostructured films, J. Appl. Crystallogr. 48, 917-926 (2015).](https://doi.org/10.1107/S1600576715004434)

A short tutorial about GIXSGUI is here: http://gisaxs.com/files/Strzalka.pdf (from slide 24)

Comments and questions: gixsgui@anl.gov 

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

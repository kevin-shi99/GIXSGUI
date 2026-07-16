# Plan: HDF5 filter-mismatch error handling + Python re-encode GUI

## Context / root cause (already diagnosed)
- `analysis/gapfill_pilatus/gapfillgui.m` (`update_edit`, HDF branch ~L396-403) and
  `gixsdata.m` (`loadimage`, HDF branch ~L1629-1634) both call `h5read(f,'/entry/data/data')`
  with no error handling.
- Files compressed with a non-native HDF5 filter (e.g. `lz4`, seen via
  `info.Filters.Name = 'HDF5 lz4 filter; ...'`) make `h5read` fail at the C-library level with
  `H5PL__find_plugin_in_path ... can't open directory` because MATLAB has no plugin dir configured.
- Files using `deflate` (built-in gzip, e.g. `Name:'deflate', Data:4`) work fine — no plugin needed.
- User explicitly wants to KEEP default HDF5 plugin folder behavior (no `HDF5_PLUGIN_PATH` setup) and
  instead: (1) catch the error, (2) inspect the filter, (3) show an actionable message, (4) provide a
  Python GUI tool to re-encode problem files to gzip so they load in MATLAB.
- `gixsgui.m`'s image-load callback (~L1776-1830) already wraps `gdata.ImFile = imFile` in
  try/catch and shows `errordlg(['Error loading file: ' ME.message], 'Loading Error')` — so
  improving the message thrown from `gixsdata.m`'s `loadimage` is enough for the main GUI path;
  no change needed to `gixsgui.m` itself.
- `gapfillgui.m` does NOT go through the `gixsdata` class — it reads HDF5 directly in
  `update_edit`, so it needs its own try/catch + `errordlg` (matching existing patterns in that
  function, e.g. `errordlg('Invalid file name.','File Open Error','modal')`).

## Decisions (confirmed with user)
- New Python script location: **repo root** (`hdf5_recompress_gui.py`), matching the existing
  `correction_functions.py` standalone-Python convention.
- `GAPFILLGUI_HDF_UPDATE_SUMMARY.md`: merge its content into `README.md`, then **delete** the
  standalone file (avoid duplicated docs).
- Python recompression scope: **recompress every chunked dataset to gzip** (simple/uniform),
  not just ones using non-native filters.

## Steps

### Phase 1 — Shared MATLAB filter-check helper (no dependencies, do first)
1. Create `utilities/hdf5filtermsg.m`: a function
   `msg = hdf5filtermsg(filename, dsetpath, ME)` that:
   - Defines a native/built-in filter allowlist: `{'deflate','shuffle','fletcher32','nbit','scaleoffset'}`
     (HDF5 filters MATLAB can always decode, no external plugin).
   - Calls `h5info(filename, dsetpath)` (wrapped in its own try/catch — must not itself throw) to
     get `info.Filters`, and matches each `Filters.Name` against the allowlist using `contains`
     (case-insensitive), since real-world names are descriptive strings like
     `'HDF5 lz4 filter; see http://...'`, not bare keywords.
   - If any filter name doesn't match the allowlist: build a detailed message identifying the
     filter name(s) found, explaining MATLAB's default HDF5 install can't decode them, and
     pointing the user at `hdf5_recompress_gui.py` (Phase 2) as the fix — re-encode the file to
     gzip, then load the re-encoded copy.
   - Otherwise (filters are all native, or filter info unavailable): fall back to a generic
     message that just wraps `ME.message`.
   - Return the composed string; do not show any UI from this helper (caller decides
     `errordlg` vs `error`).

### Phase 2 — Python re-encoding GUI (parallel with Phase 1)
2. Create `hdf5_recompress_gui.py` at repo root:
   - Header docstring: purpose, `pip install h5py hdf5plugin` requirement (tkinter is stdlib),
     and a note that this is a standalone tool, not called from MATLAB (same convention as
     `correction_functions.py`, documented in `AGENTS.md`).
   - `import hdf5plugin` wrapped in try/except so the app still runs (with a warning) if it's
     missing — needed to *decode* non-native filters (lz4/bitshuffle/etc.) on read; writing is
     always done with plain gzip so no plugin is needed on the MATLAB side afterward.
   - Tkinter UI (plain functions + module-level widget refs, no need for extra abstraction):
     - "Add Files..." button → `filedialog.askopenfilenames(filetypes=[('HDF5 files','*.h5 *.hdf')])`,
       appends to a `Listbox` showing selected input files (dedup, allow removing selection/"Clear").
     - "Output Directory..." button → `filedialog.askdirectory()`, shown in a label/entry.
     - Compression level `Spinbox` (1-9, default 4 — matches the known-good sample file's level).
     - "Convert" button → validates at least 1 file + an output dir chosen; warns/skips (does not
       abort the batch) if a file's output path would collide with the input path.
     - A `ScrolledText` log area that appends one line per file (success/failure + reason), and a
       final `messagebox.showinfo` summary (N succeeded / M failed).
   - Conversion logic per file: open source with `h5py.File(path,'r')`; recursively copy every
     group (with its attributes) and every dataset (with its attributes) into a new file at
     `<output_dir>/<stem>_recompressed.h5`; for any dataset that is chunked, write with
     `compression='gzip', compression_opts=<level>`; non-chunked/scalar datasets are copied as-is.
     Wrap each file's conversion in try/except so one bad file doesn't stop the batch; log the
     exception message.

### Phase 3 — MATLAB call sites (depends on Phase 1)
3. `gixsdata.m` `loadimage`, HDF branch (~L1629-1634): wrap `h5info`/`h5read`/transpose logic in
   try/catch. On catch, call `msg = hdf5filtermsg(obj.ImFile, '/entry/data/data', ME);` then
   `error('gixsdata:hdf5ReadFailed', '%s', msg);` — this propagates up through the `set.ImFile`
   property setter to `gixsgui.m`'s existing try/catch (~L1776-1830), which already shows
   `errordlg(['Error loading file: ' ME.message], 'Loading Error')` — no `gixsgui.m` edits needed.
4. `analysis/gapfill_pilatus/gapfillgui.m` `update_edit`, HDF branch (~L396-403): wrap the
   `h5info`/`h5read`/sum/transpose logic in try/catch. On catch, call
   `msg = hdf5filtermsg(f, '/entry/data/data', ME);` then show
   `errordlg(msg, 'HDF5 Read Error', 'modal')` and restore `oldfile`/`oldpath`/`olddata` exactly
   like the other error branches in this function (`Invalid file name.` / `Invalid file format.`
   patterns just above/below it), so the edit box and cached data don't get corrupted.

### Phase 4 — Docs (depends on Phases 1-3 being decided, so filenames/behavior are final)
5. Update `README.md`: add an "HDF5/H5 file support" section that:
   - Summarizes the original HDF/H5 loading support (content merged from
     `GAPFILLGUI_HDF_UPDATE_SUMMARY.md`: reads `/entry/data/data`, sums along the 3rd dim if
     multi-frame, transposes; supported in both `gixsgui`'s main loader and `gapfillgui`).
   - Documents the new behavior: if a file uses a compression filter MATLAB's HDF5 can't decode
     (e.g. lz4/bitshuffle), loading now fails with a clear error naming the filter and pointing at
     `hdf5_recompress_gui.py`.
   - Documents how to run `hdf5_recompress_gui.py` (dependencies, what it does, that it writes
     `<stem>_recompressed.h5` files with gzip compression into the chosen output directory).
6. Delete `GAPFILLGUI_HDF_UPDATE_SUMMARY.md` (content now lives in README).
7. Update `AGENTS.md`'s "Recent work" section: it currently links to
   `GAPFILLGUI_HDF_UPDATE_SUMMARY.md` (being deleted) — repoint that link/summary to the new
   README section instead, and add a one-line mention of `hdf5_recompress_gui.py` alongside the
   existing note about `correction_functions.py` being a standalone, non-integrated Python file.

## Relevant files
- `utilities/hdf5filtermsg.m` — new shared helper (Phase 1)
- `hdf5_recompress_gui.py` — new standalone Python GUI tool, repo root (Phase 2)
- `gixsdata.m` — `loadimage` HDF branch, ~L1629-1634 (Phase 3)
- `analysis/gapfill_pilatus/gapfillgui.m` — `update_edit` HDF branch, ~L396-403 (Phase 3)
- `README.md` — new HDF5 support section (Phase 4)
- `GAPFILLGUI_HDF_UPDATE_SUMMARY.md` — delete after merge (Phase 4)
- `AGENTS.md` — update "Recent work" link + Python-tooling note (Phase 4)

## Verification
1. In MATLAB, open the known-bad LZ4 file via `gapfillgui` → should get a dialog naming the `lz4`
   filter and pointing at the Python tool, edit box reverts to previous value (no crash/corrupt state).
2. In MATLAB, open the same file via `gixsgui`'s image loader → should get the existing
   "Loading Error" dialog, now containing the filter-specific message instead of the raw HDF5
   stack trace.
3. Open a known-good `deflate`-compressed file via both paths → loads successfully, unaffected by
   the new try/catch (regression check).
4. Run `hdf5_recompress_gui.py`, select the problem file(s) + an output directory, convert, confirm
   `<stem>_recompressed.h5` is created and loads successfully in both `gapfillgui` and `gixsgui`
   with no error.
5. Confirm `README.md` reads coherently as the single source for HDF5 support info, and
   `GAPFILLGUI_HDF_UPDATE_SUMMARY.md` no longer exists / isn't linked from anywhere (`AGENTS.md`
   updated).

## Scope boundaries
- NOT setting up `HDF5_PLUGIN_PATH` or installing MATLAB-side decoder plugins (explicitly rejected
  by user in favor of the Python re-encode workaround).
- NOT changing `gixsgui.m` (its existing generic error handler is reused as-is).
- NOT adding automated tests (repo has no test suite/CI — consistent with `AGENTS.md`).

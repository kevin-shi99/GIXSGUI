"""
hdf5_recompress_gui.py
=======================

Standalone Tkinter GUI to re-encode HDF5/H5 files that use a compression
filter (e.g. lz4, bitshuffle) MATLAB's built-in HDF5 library cannot decode.

Why this exists
----------------
GIXSGUI's MATLAB loaders (``gixsdata.m`` and
``analysis/gapfill_pilatus/gapfillgui.m``) read image data from HDF5 files via
``h5read``. MATLAB ships with a stock HDF5 library that can only decode the
native/built-in filters (deflate/gzip, shuffle, fletcher32, nbit,
scaleoffset). Files chunked/compressed with a non-native filter fail to load
in MATLAB with an ``H5PL__find_plugin_in_path`` error, unless an external
HDF5 plugin directory is configured (which this project intentionally does
NOT set up - see AGENTS.md / plan notes).

This script is a workaround: it opens a source HDF5 file, copies its full
group/dataset/attribute structure into a new file, and (re-)compresses every
chunked dataset with plain gzip - a filter MATLAB can always read. The
original file is left untouched; a new "<stem>_recompressed.h5" file is
written to a chosen output directory.

This is a standalone tool. It is NOT called from any MATLAB code in this
repository (same convention as ``correction_functions.py`` - see AGENTS.md).

Requirements
------------
    pip install h5py hdf5plugin

``tkinter`` is part of the Python standard library and does not need to be
installed separately. ``hdf5plugin`` is only needed to *read* source files
that use non-native filters (lz4, bitshuffle, zstd, etc.) - if it's missing,
this script still runs, but source files using such filters may fail to
open; writing is always done with plain gzip, so no plugin is ever required
to read the recompressed output in MATLAB.
"""

import os
import traceback
import tkinter as tk
from tkinter import filedialog, messagebox
from tkinter import ttk
from tkinter.scrolledtext import ScrolledText

try:
    import hdf5plugin  # noqa: F401  (registers decoder plugins with h5py on import)
    HDF5PLUGIN_AVAILABLE = True
except ImportError:
    HDF5PLUGIN_AVAILABLE = False

import h5py

# ---------------------------------------------------------------------------
# Conversion logic
# ---------------------------------------------------------------------------


def _copy_attrs(src_obj, dst_obj):
    for key, value in src_obj.attrs.items():
        dst_obj.attrs[key] = value


def _copy_item(name, obj, dst_file, compression_level):
    """h5py.File.visititems callback: recreate one group or dataset in dst_file."""
    if isinstance(obj, h5py.Group):
        dst_group = dst_file.require_group(name)
        _copy_attrs(obj, dst_group)
    elif isinstance(obj, h5py.Dataset):
        parent = name.rsplit('/', 1)[0] if '/' in name else '/'
        if parent != '/':
            dst_file.require_group(parent)
        if obj.chunks is not None:
            dst_dset = dst_file.create_dataset(
                name,
                data=obj[()],
                shape=obj.shape,
                dtype=obj.dtype,
                chunks=obj.chunks,
                compression='gzip',
                compression_opts=compression_level,
            )
        else:
            dst_dset = dst_file.create_dataset(
                name, data=obj[()], shape=obj.shape, dtype=obj.dtype
            )
        _copy_attrs(obj, dst_dset)


def recompress_file(input_path, output_dir, compression_level):
    """Recreate input_path's full structure into <output_dir>/<stem>_recompressed.h5.

    Every chunked dataset is written with gzip compression at the given
    level; non-chunked/scalar datasets are copied as-is. Raises on failure -
    caller is responsible for catching/logging.
    """
    stem = os.path.splitext(os.path.basename(input_path))[0]
    output_path = os.path.join(output_dir, f'{stem}_recompressed.h5')

    if os.path.abspath(output_path) == os.path.abspath(input_path):
        raise ValueError('output path would overwrite the input file - skipped')

    with h5py.File(input_path, 'r') as src, h5py.File(output_path, 'w') as dst:
        _copy_attrs(src, dst)
        src.visititems(lambda name, obj: _copy_item(name, obj, dst, compression_level))

    return output_path


# ---------------------------------------------------------------------------
# GUI
# ---------------------------------------------------------------------------

root = None
file_listbox = None
output_dir_var = None
compression_spinbox = None
log_text = None


def add_files():
    paths = filedialog.askopenfilenames(
        title='Select HDF5 files',
        filetypes=[('HDF5 files', '*.h5 *.hdf'), ('All files', '*.*')],
    )
    existing = set(file_listbox.get(0, tk.END))
    for p in paths:
        if p not in existing:
            file_listbox.insert(tk.END, p)
            existing.add(p)


def remove_selected():
    for index in reversed(file_listbox.curselection()):
        file_listbox.delete(index)


def clear_files():
    file_listbox.delete(0, tk.END)


def choose_output_dir():
    d = filedialog.askdirectory(title='Select output directory')
    if d:
        output_dir_var.set(d)


def log(message):
    log_text.insert(tk.END, message + '\n')
    log_text.see(tk.END)
    log_text.update_idletasks()


def convert_files():
    files = list(file_listbox.get(0, tk.END))
    output_dir = output_dir_var.get().strip()

    if not files:
        messagebox.showwarning('No files selected', 'Add at least one HDF5 file first.')
        return
    if not output_dir or not os.path.isdir(output_dir):
        messagebox.showwarning('No output directory', 'Choose a valid output directory first.')
        return

    try:
        level = int(compression_spinbox.get())
    except ValueError:
        level = 4

    if not HDF5PLUGIN_AVAILABLE:
        log('Warning: hdf5plugin is not installed - files using non-native '
            'filters (lz4, bitshuffle, etc.) may fail to open.')

    succeeded = 0
    failed = 0
    for path in files:
        try:
            out_path = recompress_file(path, output_dir, level)
            log(f'OK: {path} -> {out_path}')
            succeeded += 1
        except Exception as exc:  # noqa: BLE001 - one bad file must not stop the batch
            log(f'FAILED: {path} ({exc})')
            log(traceback.format_exc(limit=1))
            failed += 1

    messagebox.showinfo(
        'Conversion complete',
        f'{succeeded} file(s) succeeded, {failed} file(s) failed.\nSee log for details.',
    )


def build_gui():
    global root, file_listbox, output_dir_var, compression_spinbox, log_text

    root = tk.Tk()
    root.title('HDF5 Recompress to Gzip')
    root.geometry('640x520')

    frame_files = ttk.LabelFrame(root, text='Input files')
    frame_files.pack(fill='both', expand=True, padx=8, pady=8)

    file_listbox = tk.Listbox(frame_files, selectmode=tk.EXTENDED)
    file_listbox.pack(side='left', fill='both', expand=True, padx=(8, 0), pady=8)

    scrollbar = ttk.Scrollbar(frame_files, orient='vertical', command=file_listbox.yview)
    scrollbar.pack(side='left', fill='y', pady=8)
    file_listbox.config(yscrollcommand=scrollbar.set)

    frame_file_buttons = ttk.Frame(frame_files)
    frame_file_buttons.pack(side='left', fill='y', padx=8, pady=8)
    ttk.Button(frame_file_buttons, text='Add Files...', command=add_files).pack(fill='x', pady=2)
    ttk.Button(frame_file_buttons, text='Remove Selected', command=remove_selected).pack(fill='x', pady=2)
    ttk.Button(frame_file_buttons, text='Clear', command=clear_files).pack(fill='x', pady=2)

    frame_output = ttk.LabelFrame(root, text='Output')
    frame_output.pack(fill='x', padx=8, pady=(0, 8))

    output_dir_var = tk.StringVar()
    ttk.Entry(frame_output, textvariable=output_dir_var).pack(
        side='left', fill='x', expand=True, padx=8, pady=8
    )
    ttk.Button(frame_output, text='Output Directory...', command=choose_output_dir).pack(
        side='left', padx=8, pady=8
    )

    frame_options = ttk.Frame(root)
    frame_options.pack(fill='x', padx=8, pady=(0, 8))
    ttk.Label(frame_options, text='Gzip compression level (1-9):').pack(side='left')
    compression_spinbox = ttk.Spinbox(frame_options, from_=1, to=9, width=5)
    compression_spinbox.set(4)
    compression_spinbox.pack(side='left', padx=8)
    ttk.Button(frame_options, text='Convert', command=convert_files).pack(side='right')

    frame_log = ttk.LabelFrame(root, text='Log')
    frame_log.pack(fill='both', expand=True, padx=8, pady=(0, 8))
    log_text = ScrolledText(frame_log, height=10)
    log_text.pack(fill='both', expand=True, padx=8, pady=8)

    if not HDF5PLUGIN_AVAILABLE:
        log('Warning: hdf5plugin is not installed. Run "pip install hdf5plugin" if source '
            'files use non-native filters (lz4, bitshuffle, zstd, etc.). Writing always uses '
            'plain gzip regardless.')

    return root


def main():
    app = build_gui()
    app.mainloop()


if __name__ == '__main__':
    main()

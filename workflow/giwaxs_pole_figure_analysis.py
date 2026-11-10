"""
giwaxs_pole_figure_analysis.py
==============================

Pole figure, S2D, and Herman's orientation parameter (HOP) from GIWAXS
azimuthal (Chi) linecuts.

Physics
-------
Input is an azimuthal linecut I(chi) taken from a 2D GIWAXS pattern by sector
integration at a fixed q-range around one Bragg peak of interest. The angle
convention used here is the GIXSGUI/thin-film convention:

    chi =  0 deg  -> out-of-plane direction (qz axis, meridian)
    chi = 90 deg  -> in-plane direction     (qxy axis, equator)

1. Geometric (sin-chi) correction
   A sector of constant angular width subtends a solid angle on the Debye-
   Scherrer ring that grows as sin(chi), so the raw sector-averaged intensity
   must be weighted by sin(chi) to become a pole density:

       P(chi) = I(chi) * sin(chi)

2. Second moment of the orientation distribution
   Because the bins are equal-width azimuthal sectors, the bin width cancels
   between numerator and denominator and a plain weighted sum is exact:

       <cos^2 chi> = sum_i [ I(chi_i) * cos^2(chi_i) * sin(chi_i) ]
                     ---------------------------------------------
                     sum_i [ I(chi_i) * sin(chi_i) ]

3. Order parameters (both from the same <cos^2 chi>)

       S2D = 2 * <cos^2 chi> - 1          (range -1 .. +1)
             +1 = fully aligned along chi = 0 deg (out-of-plane)
             -1 = fully aligned along chi = 90 deg (in-plane)

       HOP = (3 * <cos^2 chi> - 1) / 2    (standard 3D Herman's function)
             +1 = fully aligned along chi = 0 deg
              0 = isotropic
           -0.5 = fully aligned along chi = 90 deg

   Note on the isotropic reference: both parameters are fed the SAME
   sin(chi)-weighted <cos^2 chi> above, which equals 1/3 for an isotropic
   sample. So isotropic gives HOP = 0 but S2D = -1/3, not 0. S2D only reads
   0 at isotropy when <cos^2 chi> is computed WITHOUT the sin(chi) weight
   (the purely 2D, in-plane-of-detector definition, where isotropic gives
   <cos^2 chi> = 1/2). Compare S2D values only against other samples
   processed the same way.

Input data
----------
Two-column text file, one row per azimuthal bin:

    column 1 : chi in DEGREES (bin centres, e.g. 2.5, 7.5, ..., 87.5)
    column 2 : intensity I(chi), background-subtracted, arbitrary units

Both headerless whitespace/tab/comma-separated ``.txt`` and the
``Chi,Intensity`` ``.csv`` written by ``workflow/batch_chi_linecut.m`` are
accepted; a non-numeric header row is skipped automatically.

The default expectation is 18 points spanning 2.5-87.5 deg (5 deg sector bin
centres over 0-90 deg, endpoints not included). Anything else is processed
anyway but warned about.

Outputs (per input file, written to an output directory)
--------------------------------------------------------
    <stem>_pole_figure.png            chi vs I(chi)*sin(chi)
    <stem>_pole_figure_data.csv       chi_deg, intensity, P_chi
    <stem>_orientation_summary.json   <cos^2 chi>, S2D, HOP + metadata

plus one combined table over all processed files:

    orientation_summary_all.csv

Usage
-----
    python giwaxs_pole_figure_analysis.py <folder-or-file> [options]
    python giwaxs_pole_figure_analysis.py data.txt
    python giwaxs_pole_figure_analysis.py ./linecuts --outdir ./pole_figures --show

This script is standalone: it is NOT called from any MATLAB code in this
repository (same convention as ``correction_functions.py`` and
``hdf5_recompress_gui.py``). Requires ``numpy`` and ``matplotlib``.
"""

import argparse
import json
import os
import re
import sys

import numpy as np
import matplotlib.pyplot as plt

# ---------------------------------------------------------------------------
# User configuration - edit these instead of hardcoding paths further down
# ---------------------------------------------------------------------------

# Default input, used when no path is given on the command line. May be a
# single two-column linecut file or a folder containing several of them.
DEFAULT_INPUT_PATH = "."

# Name of the sub-folder created inside the input folder for the results,
# unless --outdir is given.
DEFAULT_OUTPUT_SUBDIR = "pole_figure"

# File extensions treated as linecut data when the input is a folder.
INPUT_EXTENSIONS = (".txt", ".csv")

# Expected azimuthal binning (5 deg sectors over 0-90 deg -> 18 bin centres).
EXPECTED_N_BINS = 18
EXPECTED_CHI_FIRST = 2.5
EXPECTED_CHI_LAST = 87.5
CHI_EDGE_TOLERANCE = 0.5    # deg, how far first/last centre may drift silently

# Plot settings.
PLOT_DPI = 200

# Combined summary table written alongside the per-file outputs.
COMBINED_SUMMARY_NAME = "orientation_summary_all.csv"

# Suffixes this script writes itself; skipped when scanning an input folder so
# a previous run's output is never re-ingested as input data.
_OUTPUT_SUFFIXES = ("_pole_figure_data.csv", "_orientation_summary.json")


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------


def load_linecut(path):
    """Load a two-column (chi_deg, intensity) linecut file.

    Accepts whitespace-, tab-, comma- or semicolon-separated columns, blank
    lines, and ``#``/``%`` comment lines. A non-numeric leading row (e.g. the
    ``Chi,Intensity`` header written by ``batch_chi_linecut.m``) is skipped.

    Returns
    -------
    (chi_deg, intensity) : tuple of 1-D numpy arrays, sorted by chi ascending.
    """
    chi_values = []
    intensity_values = []
    skipped_rows = []

    with open(path, "r", encoding="utf-8-sig", errors="replace") as fid:
        for lineno, raw_line in enumerate(fid, start=1):
            line = raw_line.strip()
            if not line or line.startswith("#") or line.startswith("%"):
                continue

            fields = line.replace(",", " ").replace(";", " ").split()
            if len(fields) < 2:
                skipped_rows.append(lineno)
                continue

            try:
                chi = float(fields[0])
                intensity = float(fields[1])
            except ValueError:
                # Header row or stray text - record it and move on.
                skipped_rows.append(lineno)
                continue

            chi_values.append(chi)
            intensity_values.append(intensity)

    if not chi_values:
        raise ValueError(
            "No numeric two-column rows found in '{0}'.".format(path)
        )

    chi_deg = np.asarray(chi_values, dtype=float)
    intensity = np.asarray(intensity_values, dtype=float)

    # Sort by chi ascending if not already sorted.
    order = np.argsort(chi_deg, kind="stable")
    chi_deg = chi_deg[order]
    intensity = intensity[order]

    if skipped_rows:
        _warn(
            "skipped {0} non-numeric/short row(s) at line(s) {1}".format(
                len(skipped_rows),
                ", ".join(str(n) for n in skipped_rows[:5])
                + ("..." if len(skipped_rows) > 5 else ""),
            )
        )

    return chi_deg, intensity


def check_linecut(chi_deg, intensity):
    """Sanity-check the loaded linecut and print warnings (nothing is dropped).

    Returns the list of warning strings so callers can record them.
    """
    messages = []

    n_pts = chi_deg.size
    if n_pts != EXPECTED_N_BINS:
        messages.append(
            "expected {0} bin centres (5 deg sectors over 0-90 deg), found {1}".format(
                EXPECTED_N_BINS, n_pts
            )
        )

    if abs(chi_deg[0] - EXPECTED_CHI_FIRST) > CHI_EDGE_TOLERANCE or \
            abs(chi_deg[-1] - EXPECTED_CHI_LAST) > CHI_EDGE_TOLERANCE:
        messages.append(
            "chi range {0:.3g}-{1:.3g} deg differs from the expected "
            "{2:.3g}-{3:.3g} deg bin centres".format(
                chi_deg[0], chi_deg[-1], EXPECTED_CHI_FIRST, EXPECTED_CHI_LAST
            )
        )

    if chi_deg[0] < 0.0 or chi_deg[-1] > 90.0:
        messages.append(
            "chi values fall outside 0-90 deg; S2D/HOP below assume a "
            "0-90 deg uniaxial (fibre-symmetric) domain"
        )

    if n_pts > 2:
        spacing = np.diff(chi_deg)
        # Equal bin widths are what lets the width cancel out of the weighted
        # sum in compute_order_parameters(); flag it if that no longer holds.
        if np.nanmax(spacing) - np.nanmin(spacing) > 1e-6:
            messages.append(
                "chi spacing is not uniform ({0:.4g}-{1:.4g} deg); the equal-"
                "bin-width assumption of the weighted sum no longer holds"
                .format(np.nanmin(spacing), np.nanmax(spacing))
            )

    n_nan = int(np.count_nonzero(~np.isfinite(intensity)))
    if n_nan:
        messages.append(
            "{0} non-finite intensity value(s) (NaN/Inf) present; they are kept "
            "as-is, so <cos^2 chi>, S2D and HOP will come out non-finite".format(n_nan)
        )

    n_negative = int(np.count_nonzero(intensity < 0.0))
    if n_negative:
        messages.append(
            "{0} negative intensity value(s) present (over-subtracted "
            "background?); they are kept as-is".format(n_negative)
        )

    for message in messages:
        _warn(message)

    return messages


# ---------------------------------------------------------------------------
# Physics
# ---------------------------------------------------------------------------


def compute_order_parameters(chi_deg, intensity):
    """sin(chi)-correct the linecut and compute the orientation parameters.

    Parameters
    ----------
    chi_deg : 1-D array of azimuthal bin centres in DEGREES.
    intensity : 1-D array of sector-averaged intensities I(chi).

    Returns
    -------
    (cos2_avg, s2d, hop, chi_deg, p_chi)
        cos2_avg : <cos^2 chi>
        s2d      : 2 * <cos^2 chi> - 1
        hop      : (3 * <cos^2 chi> - 1) / 2
        chi_deg  : the input angles (degrees), unchanged
        p_chi    : the sin(chi)-corrected pole figure I(chi) * sin(chi)
    """
    chi_deg = np.asarray(chi_deg, dtype=float)
    intensity = np.asarray(intensity, dtype=float)

    # Single explicit degree -> radian conversion; every trig call below uses it.
    chi_rad = np.radians(chi_deg)
    sin_chi = np.sin(chi_rad)
    cos2_chi = np.cos(chi_rad) ** 2

    # Geometric correction: pole figure P(chi) = I(chi) * sin(chi).
    p_chi = intensity * sin_chi

    # Direct weighted sum over the discrete sector bins - NOT a trapezoidal or
    # other continuous-integration rule, because each point is already the
    # average over one finite-width azimuthal sector.
    #
    # All bins share the same angular width (5 deg), so that width appears
    # identically in numerator and denominator and cancels. If this script is
    # ever adapted to unevenly-spaced or variable-width bins, each term needs
    # an explicit ``* delta_chi_i`` weight here.
    numerator = np.sum(p_chi * cos2_chi)
    denominator = np.sum(p_chi)

    if denominator == 0.0:
        raise ValueError(
            "sum of I(chi)*sin(chi) is zero; <cos^2 chi> is undefined for this linecut"
        )

    cos2_avg = numerator / denominator
    s2d = 2.0 * cos2_avg - 1.0
    hop = (3.0 * cos2_avg - 1.0) / 2.0

    return cos2_avg, s2d, hop, chi_deg, p_chi


# ---------------------------------------------------------------------------
# Filename metadata
# ---------------------------------------------------------------------------

_META_PATTERNS = (
    ("scan", re.compile(r"(?<![A-Za-z0-9])(P\d+)", re.IGNORECASE)),
    ("sample", re.compile(r"(?<![A-Za-z0-9])(KS\d+)", re.IGNORECASE)),
    ("orientation", re.compile(r"(?<![A-Za-z])(para|perp)(?![A-Za-z])", re.IGNORECASE)),
    ("incidence", re.compile(r"(?<![A-Za-z])deg[_-]?(\d+(?:[p.]\d+)?)", re.IGNORECASE)),
    ("chi_range", re.compile(
        r"(?<![A-Za-z])Chi[_-]?(-?\d+(?:[p.]\d+)?)-(-?\d+(?:[p.]\d+)?)", re.IGNORECASE)),
    ("q_range", re.compile(
        r"(?<![A-Za-z])q[_-]?(\d+(?:[p.]\d+)?)-(\d+(?:[p.]\d+)?)", re.IGNORECASE)),
)

# Metadata fields in the order they appear in the combined summary CSV.
META_FIELDS = ("scan", "sample", "orientation", "incidence", "chi_range", "q_range")


def parse_filename_metadata(path):
    """Pull scan/sample/orientation/incidence/chi-range/q-range out of a filename.

    Recognises the naming convention ``P####``, ``KS##``, ``para``/``perp``,
    ``deg####``, ``Chi_0-90``, ``q_1-2`` (also the MATLAB ``q1p15-1p5`` spelling,
    where ``p`` stands in for the decimal point).

    Tokens that are absent are returned as empty strings - a file with an
    unexpected name still processes, it just carries less metadata.
    """
    stem = os.path.splitext(os.path.basename(path))[0]
    metadata = {"stem": stem}
    missing = []

    for key, pattern in _META_PATTERNS:
        match = pattern.search(stem)
        if match is None:
            metadata[key] = ""
            missing.append(key)
        elif len(match.groups()) == 2:
            metadata[key] = "{0}-{1}".format(
                match.group(1).replace("p", "."), match.group(2).replace("p", ".")
            )
        else:
            metadata[key] = match.group(1)

    if missing:
        _warn(
            "filename '{0}' is missing token(s): {1}".format(stem, ", ".join(missing))
        )

    return metadata


def format_metadata_label(metadata):
    """One-line human-readable label for plot titles, e.g. 'P0028 KS12 para'."""
    parts = [metadata.get(key, "") for key in ("scan", "sample", "orientation")]
    parts = [part for part in parts if part]

    if metadata.get("incidence"):
        parts.append("{0} deg".format(metadata["incidence"]))
    if metadata.get("q_range"):
        parts.append("q {0}".format(metadata["q_range"]))

    return "  ".join(parts) if parts else metadata.get("stem", "")


# ---------------------------------------------------------------------------
# Plotting and output
# ---------------------------------------------------------------------------


def plot_pole_figure(chi_deg, p_chi, outpath, title=None, dpi=PLOT_DPI):
    """Plot chi (deg) vs the sin(chi)-corrected pole figure and save it as PNG.

    Returns the matplotlib figure object (not closed here, so the caller can
    display it or close it).
    """
    fig, ax = plt.subplots(figsize=(6.0, 4.5))

    ax.plot(chi_deg, p_chi, marker="o", markersize=5, linewidth=1.4, color="#1f77b4")

    ax.set_xlabel(r"$\chi$ (deg)")
    ax.set_ylabel(r"$I(\chi)\cdot\sin(\chi)$ (a.u.)")

    plot_title = r"sin($\chi$)-corrected pole figure"
    if title:
        plot_title = "{0}\n{1}".format(plot_title, title)
    ax.set_title(plot_title, fontsize=11)

    ax.set_xlim(0.0, 90.0)
    ax.set_xticks(np.arange(0.0, 91.0, 15.0))
    ax.grid(True, linestyle=":", linewidth=0.6, alpha=0.7)
    fig.tight_layout()

    fig.savefig(outpath, dpi=dpi)

    return fig


def write_pole_figure_csv(outpath, chi_deg, intensity, p_chi):
    """Write the corrected pole figure data (chi_deg, intensity, P_chi) to CSV."""
    with open(outpath, "w", encoding="utf-8", newline="") as fid:
        fid.write("chi_deg,intensity,P_chi\n")
        for chi, raw, corrected in zip(chi_deg, intensity, p_chi):
            fid.write("{0:.15g},{1:.15g},{2:.15g}\n".format(chi, raw, corrected))


def _json_safe(value):
    """NaN/Inf are not valid JSON - write them as null so the file stays parseable."""
    if isinstance(value, float) and not np.isfinite(value):
        return None
    return value


def write_summary_json(outpath, record):
    """Write the per-file orientation summary (<cos^2 chi>, S2D, HOP + metadata)."""
    with open(outpath, "w", encoding="utf-8") as fid:
        json.dump({k: _json_safe(v) for k, v in record.items()}, fid, indent=2)
        fid.write("\n")


def write_combined_summary(outpath, records):
    """Write one row per processed file: metadata + the three order parameters."""
    columns = ("source_file",) + META_FIELDS + ("n_points", "cos2_avg", "S2D", "HOP")

    with open(outpath, "w", encoding="utf-8", newline="") as fid:
        fid.write(",".join(columns) + "\n")
        for record in records:
            values = []
            for column in columns:
                value = record.get(column, "")
                if isinstance(value, float):
                    values.append("{0:.6f}".format(value))
                else:
                    values.append(str(value).replace(",", " "))
            fid.write(",".join(values) + "\n")


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------


# Warnings raised while processing the current file, so they can be recorded in
# that file's summary as well as printed.
_WARNING_LOG = []


def _warn(message):
    _WARNING_LOG.append(message)
    print("  [warn] {0}".format(message))


def collect_input_files(input_path, pattern):
    """Resolve the input argument to a sorted list of linecut files."""
    if os.path.isfile(input_path):
        return [input_path]

    if not os.path.isdir(input_path):
        raise FileNotFoundError("Input path does not exist: {0}".format(input_path))

    import fnmatch

    files = []
    for name in sorted(os.listdir(input_path)):
        full_path = os.path.join(input_path, name)
        if not os.path.isfile(full_path):
            continue
        if os.path.splitext(name)[1].lower() not in INPUT_EXTENSIONS:
            continue
        if name == COMBINED_SUMMARY_NAME or name.endswith(_OUTPUT_SUFFIXES):
            continue    # never re-ingest this script's own output
        if not fnmatch.fnmatch(name, pattern):
            continue
        files.append(full_path)

    return files


def process_file(path, outdir, dpi=PLOT_DPI, show=False):
    """Run the full pole figure analysis on one linecut file.

    Returns the summary record dict for the combined table.
    """
    print("Processing {0}".format(os.path.basename(path)))

    del _WARNING_LOG[:]     # warnings collected below belong to this file only

    metadata = parse_filename_metadata(path)
    chi_deg, intensity = load_linecut(path)
    check_linecut(chi_deg, intensity)

    cos2_avg, s2d, hop, chi_deg, p_chi = compute_order_parameters(chi_deg, intensity)

    stem = metadata["stem"]
    png_path = os.path.join(outdir, stem + "_pole_figure.png")
    csv_path = os.path.join(outdir, stem + "_pole_figure_data.csv")
    json_path = os.path.join(outdir, stem + "_orientation_summary.json")

    figure = plot_pole_figure(
        chi_deg, p_chi, png_path, title=format_metadata_label(metadata), dpi=dpi
    )
    if show:
        plt.show(block=False)
    else:
        plt.close(figure)

    write_pole_figure_csv(csv_path, chi_deg, intensity, p_chi)

    record = {
        "source_file": os.path.basename(path),
        "source_path": os.path.abspath(path),
        "n_points": int(chi_deg.size),
        "cos2_avg": float(cos2_avg),
        "S2D": float(s2d),
        "HOP": float(hop),
        "warnings": list(_WARNING_LOG),
    }
    record.update({key: metadata.get(key, "") for key in META_FIELDS})
    write_summary_json(json_path, record)

    print("  <cos^2 chi> = {0:.4f}".format(cos2_avg))
    print("  S2D         = {0:.4f}".format(s2d))
    print("  HOP         = {0:.4f}".format(hop))
    print("  wrote {0}".format(os.path.basename(png_path)))
    print("  wrote {0}".format(os.path.basename(csv_path)))
    print("  wrote {0}".format(os.path.basename(json_path)))

    return record


def main(argv=None):
    parser = argparse.ArgumentParser(
        description=(
            "sin(chi)-corrected GIWAXS pole figure plus <cos^2 chi>, S2D and "
            "Herman's orientation parameter (HOP) from azimuthal linecut files."
        )
    )
    parser.add_argument(
        "input",
        nargs="?",
        default=DEFAULT_INPUT_PATH,
        help=(
            "Linecut file, or folder of linecut files ({0}). "
            "Default: {1}".format("/".join(INPUT_EXTENSIONS), DEFAULT_INPUT_PATH)
        ),
    )
    parser.add_argument(
        "--outdir",
        default=None,
        help=(
            "Output directory. Default: a '{0}' sub-folder next to the input "
            "data.".format(DEFAULT_OUTPUT_SUBDIR)
        ),
    )
    parser.add_argument(
        "--pattern",
        default="*",
        help="Glob filter applied to filenames in folder mode (default: '*').",
    )
    parser.add_argument(
        "--dpi", type=int, default=PLOT_DPI,
        help="PNG resolution (default: {0}).".format(PLOT_DPI),
    )
    parser.add_argument(
        "--show", action="store_true",
        help="Display the figures as well as saving them.",
    )
    args = parser.parse_args(argv)

    try:
        files = collect_input_files(args.input, args.pattern)
    except FileNotFoundError as err:
        print("ERROR: {0}".format(err))
        return 1

    if not files:
        print("No {0} linecut files found in '{1}'.".format(
            "/".join(INPUT_EXTENSIONS), args.input))
        return 1

    if args.outdir:
        outdir = args.outdir
    else:
        base = args.input if os.path.isdir(args.input) else os.path.dirname(
            os.path.abspath(args.input))
        outdir = os.path.join(base, DEFAULT_OUTPUT_SUBDIR)

    if not os.path.isdir(outdir):
        os.makedirs(outdir)

    print("Input : {0}".format(os.path.abspath(args.input)))
    print("Output: {0}".format(os.path.abspath(outdir)))
    print("{0} file(s) to process\n".format(len(files)))

    records = []
    for path in files:
        try:
            records.append(process_file(path, outdir, dpi=args.dpi, show=args.show))
        except (ValueError, OSError) as err:
            print("  ERROR: {0} - skipped".format(err))
        print("")

    if not records:
        print("No file was processed successfully.")
        return 1

    combined_path = os.path.join(outdir, COMBINED_SUMMARY_NAME)
    write_combined_summary(combined_path, records)
    print("Wrote combined summary: {0}".format(combined_path))
    print("Done: {0}/{1} file(s) processed.".format(len(records), len(files)))

    if args.show:
        plt.show()

    return 0


if __name__ == "__main__":
    sys.exit(main())

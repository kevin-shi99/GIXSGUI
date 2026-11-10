# Task: GIWAXS Pole Figure, S2D, and Herman's Orientation Parameter (HOP)

## Background

I have azimuthal linecut data from a 2D GIWAXS pattern, extracted by sector integration
(5° sectors) over χ = 0° to 90°, at a fixed q-range around a single Bragg peak of interest.
χ = 0° corresponds to the out-of-plane direction (qz axis / meridian), χ = 90° corresponds
to the in-plane direction (qxy axis / equator).

I need a Python script that:
1. Reads all linecut data in a specified folder.
2. Applies the geometric sin(χ) correction to obtain the pole figure.
3. Plots χ vs. the corrected intensity I(χ)·sin(χ).
4. Computes ⟨cos²χ⟩, the 2D orientation parameter S2D, and the Herman's orientation
   parameter (HOP).
5. the pthon script should be placed in the `.\workflow\`.

## Input data

- Plain text file (`.txt`), two whitespace/tab/comma-separated columns, no header.
  - filename contains scan number (P####), sample number (KS##), orientation (para|perp), 
    incident angle (deg####), chi range (Chi_0-90) amd q range (q_#-#).
  - Column 1: χ in **degrees** — these are **bin centers** from 5° sector binning over the
    0–90° range, so there are **18 points total**, NOT including the 0° and 90° endpoints
    themselves (e.g. 2.5, 7.5, 12.5, ..., 87.5).
  - Column 2: intensity I(χ), background-subtracted, arbitrary units.
  - Each point represents the average intensity over a 5°-wide azimuthal sector centered
    on that χ value.
- File path should be a variable at the top of the script, not hardcoded deep in the logic.

## Processing steps

1. **Load data** with `numpy` or `pandas`. Sort by χ ascending if not already sorted.
2. **Sanity checks**: confirm there are 18 points spanning roughly 2.5°–87.5° (5° bin
   centers, warn if the count or range looks off); check for NaNs or negative intensities
   and warn (don't silently drop unless asked).
3. **Convert χ to radians** only for use inside trig functions; keep the degree values
   for axis labeling/plotting.
4. **Compute geometric correction**:
   `P(chi) = I(chi) * sin(chi_in_radians)`
5. **Plot**: χ (degrees, x-axis) vs. P(χ) = I(χ)·sin(χ) (y-axis).
   - Label axes clearly: x = "χ (deg)", y = "I(χ)·sin(χ) (a.u.)".
   - Title indicating this is the sin(χ)-corrected pole figure.
   - Save as a PNG (e.g. `pole_figure_corrected.png`) at reasonable DPI (150–300),
     and also display/return the figure object.
6. **Weighted sum (not integration)** — the data are already discrete sector-averaged
   points (18 bins, each representing an equal-width 5° azimuthal sector), so do **not**
   use trapezoidal or other continuous-integration rules. Instead compute a direct
   weighted sum over the 18 points:

   ```
   <cos^2 chi> = sum_i [ I(chi_i) * cos^2(chi_i) * sin(chi_i) ]   /   sum_i [ I(chi_i) * sin(chi_i) ]
   ```

   where `chi_i` are the 18 bin-center values (converted to radians for the trig
   functions) and the sum runs over all 18 points. Because every bin has the same
   angular width (5°), the bin width cancels out of the ratio, so it does not need to
   appear explicitly — a plain `numpy.sum(...)` over the two arrays is sufficient. (If the
   script is later adapted for unevenly-spaced or variable-width bins, each term would
   need an explicit `* delta_chi_i` weight — leave a short comment noting this for future
   robustness, but do not implement it now.)

7. **Compute order parameters**:
   - `S2D = 2 * <cos^2 chi> - 1`
     (range −1 to +1; +1 = fully "edge-on"/aligned along χ=0, 0 = isotropic,
     −1 = fully oriented along χ=90°)
   - `HOP = (3 * <cos^2 chi> - 1) / 2`
     (standard 3D Herman's orientation function, same ⟨cos²χ⟩ input, different
     normalization/prefactor than S2D)
8. **Print a clear summary** to stdout, e.g.:
   ```
   <cos^2 chi> = 0.xxxx
   S2D          = x.xxxx
   HOP          = x.xxxx
   ```
   Also write these three numbers to a small output file (e.g. `orientation_summary.txt`
   or `.json`) alongside the plot.
9. Optionally, also save the corrected pole figure data (χ, I(χ), P(χ)) to a CSV for
   later reuse/plotting elsewhere.

## Notes / things to get right

- **Degrees vs. radians**: all `sin`/`cos` calls must use radians. Keep a single
  explicit conversion (`np.radians(chi_deg)`) rather than converting in multiple places.
- **Domain of the sum**: the 18 bin-center points effectively span 0°–90° (not 0–180°),
  consistent with how S2D/HOP are conventionally defined for this kind of uniaxial
  (fiber-symmetric) thin-film texture, even though the endpoints 0° and 90° themselves are
  not explicitly present as data points.
- **No missing-wedge handling needed for now** — assume this particular linecut already
  has all 18 sector bins present and complete. (If gaps/NaNs are present, just note them in
  the printed warnings rather than trying to extrapolate — that's a separate step I'll
  handle later if needed.)
- Keep the script modular: a function `load_linecut(path)`, a function
  `compute_order_parameters(chi_deg, intensity)` returning `(cos2_avg, S2D, HOP, chi_deg, P_chi)`,
  and a function `plot_pole_figure(chi_deg, P_chi, outpath)`. Wrap in a `main()` with
  argparse so it's runnable as `python giwaxs_pole_figure.py data.txt`.
- Use `matplotlib` for plotting (no seaborn needed). Keep style simple/clean — markers +
  line, gridlines optional.
- Add a docstring at the top of the script summarizing the physics (sin(χ) correction,
  S2D and HOP formulas) so the script is self-documenting.

## Deliverables

- `giwaxs_pole_figure_analysis.py` — the script described above.
- Example run producing: `pole_figure_corrected.png`, `orientation_summary.txt` (or `.json`),
  and `pole_figure_corrected_data.csv`.

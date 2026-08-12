# CMB Sonification — Agent Guide

## Project overview

Sonifies the Cosmic Microwave Background (CMB) angular power spectrum,
making the acoustic peaks of the early universe audible.  The peaks arise
from sound waves (baryon acoustic oscillations) in the photon-baryon plasma
before recombination at z ~ 1100; their positions and relative heights encode
the universe's geometry, baryon density, and dark matter density.

Two modes expose different aspects of CMB data:

| Mode | Data | Output |
|------|------|--------|
| `spectrum` | D_l = l(l+1)C_l/2π vs. multipole l | Mono WAV; pitch + volume follow D_l |
| `sky` | Simulated flat-sky temperature anisotropy map | Mono WAV; Hilbert traversal of sky patch |

## Project structure

```
cosmology/
  main.wl            — thin orchestrator: loads stem-core + src/, parses config, calls functions
  config.json        — default simulation parameters
  experiments.wl     — 8 curated preset invocations (RunExperiment)
  AGENTS.md          — this file
  src/
    fetch.wl         — FetchPlanckSpectrum (Planck Legacy Archive HTTP fetch)
    model.wl         — $cmbPeakSpecs, SimulatedDl, DlToCl, LoadSpectrum,
                       CMBPhysicsChecks, GenerateSkyMap
    sonify.wl        — SonifySpectrum, SonifySkyMap
    animate.wl       — AnimateSpectrum (PNG), AnimateSky (GIF)
    output.wl        — ExportSpectrumData (CSV), ExportSkyData (PNG + CSV)
  tests/
    test_model.wl    — unit tests for model.wl (spectrum formulae, peak detection)
  output/            — generated files (gitignored)
```

## How to run

```sh
# Default: spectrum mode, simulated LCDM
wolframscript -file cosmology/main.wl

# Sky mode
wolframscript -file cosmology/main.wl -- --simulation.mode=sky

# Real Planck 2018 data (requires network)
wolframscript -file cosmology/main.wl -- --simulation.cosmology.source=planck

# Higher l_max
wolframscript -file cosmology/main.wl -- --simulation.cosmology.l_max=3000

# 128x128 sky patch
wolframscript -file cosmology/main.wl -- --simulation.mode=sky \
  --simulation.cosmology.sky_resolution=128

# Unit tests
wolframscript -file cosmology/tests/test_model.wl

# All experiments
wolframscript -file cosmology/experiments.wl
```

## Output files

| File | Description |
|------|-------------|
| `cmb_spectrum_audio.wav` | Mono WAV: multipole l -> pitch, D_l -> volume |
| `cmb_spectrum.png` | Power spectrum plot with first 3 acoustic peaks marked |
| `cmb_spectrum_data.csv` | Table: l, C_l, D_l, is_peak flag |
| `cmb_sky_audio.wav` | Mono WAV: temperature -> pitch via Hilbert traversal |
| `cmb_sky.gif` | Hilbert traversal animation over the sky map |
| `cmb_sky.png` | Grayscale temperature map |
| `cmb_sky_data.csv` | Table: Hilbert index, col, row, temperature_uK, frequency_hz |

## Data flow

```
config.json + CLI args
        |
   LoadConfig (stem-core)
        |
   LoadSpectrum[src, lMax]      calls FetchPlanckSpectrum if src="planck"
        |                        returns {lArr, dlArr, clArr}
        |
   CMBPhysicsChecks             prints checks 1-3; returns peak Association
        |
        +-- spectrum mode:
        |   SonifySpectrum      -> WAV
        |   AnimateSpectrum     -> PNG
        |   ExportSpectrumData  -> CSV
        |
        +-- sky mode:
            GenerateSkyMap      Gaussian random field; checks 4; returns skyModel
            SonifySkyMap        -> WAV
            AnimateSky          -> GIF
            ExportSkyData       -> PNG + CSV
```

## Model Association shapes

### Spectrum (checks Association from CMBPhysicsChecks)

| Key | Type | Description |
|-----|------|-------------|
| `"peakIdxs"` | List[Integer] | Indices into lArr/dlArr of detected acoustic peaks |
| `"peakLVals"` | List[Integer] | Multipole l at each peak |
| `"peakDlVals"` | List[Real] | D_l value at each peak in muK^2 |

### Sky (skyModel Association from GenerateSkyMap)

| Key | Type | Description |
|-----|------|-------------|
| `"mapT"` | 2D Real Array | Temperature map in muK (actualN x actualN) |
| `"traversal"` | {{col,row},...} | Hilbert traversal coordinates (1-based) |
| `"nPix"` | Integer | actualN^2 |
| `"pixTemps"` | List[Real] | Temperature at each traversal pixel in muK |
| `"tNorm"` | List[Real] | Normalized temperatures [0,1] for pitch mapping |
| `"actualN"` | Integer | Grid side length (= 2^hilbertN) |
| `"freqLo"` | Real | Pitch at minimum temperature (Hz) |
| `"freqHi"` | Real | Pitch at maximum temperature (Hz) |
| `"noteDur"` | Real | Seconds per pixel |

## Analytic CMB model

`SimulatedDl[l]` combines three physical components:

1. **Sachs-Wolfe plateau** (low l): `1100 / (1 + (l/50)^2)` muK^2 —
   decays for l >> 50 as the angular scale enters the horizon.
2. **Inter-peak floor**: `200 * exp(-(l/600)^2)` muK^2 — smooth background
   beneath the acoustic peaks.
3. **Acoustic peaks**: five Gaussian bumps centred at l = 220, 540, 810,
   1120, 1430 with amplitudes 5400, 2500, 2200, 1100, 550 muK^2.
   The second peak is lower than the third due to baryon loading
   (even harmonics are suppressed when the baryons are compressed at
   maximum compression at recombination).

This is NOT a Boltzmann-code (CAMB/CLASS) output.  It captures the
correct qualitative structure but not fine details like the exact
baryon loading asymmetry or the reionisation bump at l < 10.

## Flat-sky sky map generation

`GenerateSkyMap` draws a Gaussian random field:

1. Compute 2D DFT mode l-values: `l(k_x, k_y) = |k| * 2pi / theta_patch`
2. Look up `C_l` via linear interpolation of the power spectrum
3. Draw complex Gaussian coefficients: `a(k) ~ Normal(0, sigma(k))`,
   where `sigma(k)^2 = C_l * N^4 / Omega_patch` (see the amplitude-bug
   note in `model.wl` for the full derivation — an earlier version of
   this formula was `C_l/2 * (N/sqrt(Omega))^2`, missing a full factor
   of `N`, which made the simulated map's RMS temperature ~90x too
   quiet and scale down as resolution increased instead of staying
   fixed for a fixed patch; both this formula and the correctness
   check below were fixed together, since the check had the same
   missing factor and was falsely passing on the too-quiet map)
4. Apply InverseFourier with `FourierParameters -> {1, -1}`
5. Take Re[] — the result is a real-valued temperature field

Seed is fixed (`SeedRandom[271828]`) so outputs are reproducible.
The pixel variance should match `sum_k C_l(k) / Omega_patch` (no `N`
dependence — the total large-scale power a fixed patch shows should
not shrink just because it's resolved into more pixels).

**Resolution caps what's representable, and this is deliberately
capped rather than auto-grown.** A patch of fixed angular size
sampled at `N x N` pixels can only resolve multipoles up to
`lNyquist = (N/2) * (2pi/theta_patch)` — real acoustic structure above
that simply isn't present in `lGrid` by construction, regardless of
`l_max` in the loaded spectrum. `GenerateSkyMap` computes `lNyquist`
and reports, every run, what fraction of total spectral power falls
inside the achievable range and which of `$cmbPeakSpecs`'s named
peaks are and aren't reachable (default 64x64/20deg: `lNyquist~576`,
~89% of power, peaks 1-2 reachable, 3-5 not). The alternative design —
silently growing `sky_resolution` to whatever a configured `l_max`
would need — was deliberately rejected: it would change this mode's
grid size, runtime, and audio duration without the user asking for
that. Capping to the user's chosen resolution and clearly reporting
the tradeoff respects the resolution they picked instead of second-
guessing it.

## Physical correctness checks

1. **D_l >= 0**: No negative power (trivially satisfied for simulated data).
2. **First peak at 180 <= l <= 260**: Sound horizon scale at last scattering.
3. **Silk damping**: Peak 1 > last peak overall (strict pairwise monotonicity
   is not required — the physical spectrum has peak 3 > peak 2).
4. **Sky variance**: Pixel variance / flat-sky expected variance must be in
   [0.5, 2.0] — confirms the DFT normalisation matches the continuum
   flat-sky target `sum_k C_l(k) / Omega_patch`, independently derived
   from `Var[T] = Integral[d^2l/(2 Pi)^2, C_l]` rather than restated
   from the generator's own formula (that was the original bug: the
   check used to share its formula with the generator, so a shared
   missing factor made both agree with each other while both were
   wrong relative to the actual physics — see `model.wl`).

## Common pitfalls

1. **Planck fetch requires HTTPS inspection not blocked**: some corporate
   proxies or security software intercepts HTTPS and causes `URLFetch` to
   fail even when the URL is reachable in a browser.  The code falls back
   to simulated data automatically.

2. **`FetchPlanckSpectrum` returns {}**: Always returned on network failure.
   The caller in `LoadSpectrum` checks `Length[result] === 2 && Length[result[[1]]] > 50`
   before using it.

3. **`clInterp` domain**: The Planck spectrum only covers l = 2 to ~2500.
   Any l outside that range falls back to `SimulatedDl[l]`.  Do not call
   `clInterp[l]` without the bounds check in `LoadSpectrum`.

4. **Sky map `tNorm` division**: Protected by `Max[tMax - tMin, 1.0e-10]`
   to guard against a uniform-temperature map producing division by zero.

5. **`SeedRandom[271828]`** is called inside `GenerateSkyMap`.  This ensures
   reproducible outputs but means all sky experiments see the same random
   realisation.  Change the seed to explore different CMB realisations.

6. **`hilbertN` clamp**: `Min[8, Max[4, Round[Log2[skyN]]]]` — minimum
   order 4 (16x16), maximum order 8 (256x256).  Values of `sky_resolution`
   between powers of two are rounded to the nearest power of two.

## Animation framing: GIF/WAV duration sync (fixed post-v1.5.0)

**The bug.** `AnimateSky` rendered a hardcoded 32 frames at a hardcoded
10 fps — a fixed 3.2s clip regardless of how long the accompanying
`SonifySkyMap` WAV actually ran. `SonifySkyMap`'s duration is
`nPix * noteDur` (one `StemSynthNote` per Hilbert-traversal pixel), which
scales with `sky_resolution` (`nPix = actualN^2`) and `time_stretch`
(folded into `noteDur` at the `main.wl` call site). At the default
64x64 resolution this measured as GIF=3.2s vs WAV=131.1s — a ~41x
mismatch, the GIF finishing before the sonification was 3% done. Every
`sky_resolution` preset was wrong in the same way, just by a different
factor (`sky_small` 32x32: GIF 3.2s vs WAV 8.2s; `sky_large` 128x128:
GIF 3.2s vs WAV 131.1s again capped by the same fixed 32 frames).

**Root cause.** Same shape as the bug already fixed in `lorenz/`
(see `lorenz/src/animate.wl`): GIF frame count/rate was a literal
constant unrelated to the value driving WAV length.

**The fix.** `AnimateSky[skyModel, outGIF, frameBudget_Integer:32]` in
`cosmology/src/animate.wl` now derives `targetDuration = nPix * noteDur`
from `skyModel` (which already carries both — no call-site signature
change needed in `main.wl`/`experiments.wl`, unlike `lorenz` where the
duration isn't otherwise available to the animator). `frameBudget`
(default 32, same as the old literal) is a render-rate budget, not a
frame count: `frameRate = Clip[frameBudget/targetDuration,
{$MinAnimationFps, $MaxAnimationFps}]` (2-30 fps, `$MinAnimationFps`/
`$MaxAnimationFps` defined at the top of `animate.wl`), then
`nGIFFrames = Max[2, Round[frameRate * targetDuration]]` so playback
duration lands on `targetDuration` exactly at any resolution — frame
count is what flexes at the fps clamp boundary, not duration.
`ExportGIF`/`STEMDescribeGIF` are called with the actual computed
`frameRate`/`nGIFFrames` instead of the old `10`/`nGIFFrames` literals.

**Verification** (regenerated via `wolframscript -file main.wl --
--simulation.mode=sky` and `wolframscript -file experiments.wl`,
measured with `PIL`/`wave` frame-duration summation):

| Preset | sky_resolution | Before (GIF / WAV) | After (GIF / WAV) |
|---|---|---|---|
| `sky_small`  | 32x32  | 3.2s / 8.2s   | 8.32s / 8.20s (ratio 1.015) |
| `sky_medium` (default) | 64x64 | 3.2s / 131.1s | 33.0s / 32.8s (ratio 1.007) |
| `sky_large`  | 128x128 | 3.2s / 131.1s | 131.0s / 131.1s (ratio 0.999) |

`sky_medium` and `sky_large` both land on the 2 fps floor (their
`frameBudget/targetDuration` is below 2), so `sky_medium`'s frame count
grows to 66 and `sky_large`'s to 262 to keep exact duration sync at that
floor rate; `sky_small`'s 3.91 fps is unclamped. `spectrum` mode has no
GIF output and is unaffected. All 27 `tests/test_model.wl` unit tests
still pass after the change (they cover the analytic model and physical
correctness checks, not rendering).

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSay`, `STEMPrintN`, `STEMDescribeWAV`,
  `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`, `STEMPlayCmd`,
  `HilbertTraversalOrder`, `StemSynthNote`, `NormalizeBuffer`,
  `ExportAudioBuffer`, `ExportGIF`, `ExportCSV`
- **Mathematica/WL**: `URLFetch`, `Interpolation`, `InverseFourier`,
  `NormalDistribution`, `RandomVariate`, `SeedRandom`, `Variance`,
  `ListLinePlot`, `Graphics`, `Raster`, `Image`, `Export`

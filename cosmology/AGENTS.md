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
   where `sigma(k)^2 = C_l / 2 * (N / sqrt(Omega))^2`
4. Apply InverseFourier with `FourierParameters -> {1, -1}`
5. Take Re[] — the result is a real-valued temperature field

Seed is fixed (`SeedRandom[271828]`) so outputs are reproducible.
The pixel variance should match `sum_k C_l(k) / (N^2 * Omega_patch)`.

## Physical correctness checks

1. **D_l >= 0**: No negative power (trivially satisfied for simulated data).
2. **First peak at 180 <= l <= 260**: Sound horizon scale at last scattering.
3. **Silk damping**: Peak 1 > last peak overall (strict pairwise monotonicity
   is not required — the physical spectrum has peak 3 > peak 2).
4. **Sky variance**: Pixel variance / flat-sky expected variance must be in
   [0.5, 2.0] — confirms correct DFT normalisation.

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

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSay`, `STEMPrintN`, `STEMDescribeWAV`,
  `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`, `STEMPlayCmd`,
  `HilbertTraversalOrder`, `StemSynthNote`, `NormalizeBuffer`,
  `ExportAudioBuffer`, `ExportGIF`, `ExportCSV`
- **Mathematica/WL**: `URLFetch`, `Interpolation`, `InverseFourier`,
  `NormalDistribution`, `RandomVariate`, `SeedRandom`, `Variance`,
  `ListLinePlot`, `Graphics`, `Raster`, `Image`, `Export`

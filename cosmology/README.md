# CMB Power Spectrum Sonification

Sonifies the Cosmic Microwave Background (CMB) angular power spectrum,
making the acoustic peaks of the early universe audible.

## What is the CMB?

The Cosmic Microwave Background is the oldest light in the universe —
thermal radiation released about 380,000 years after the Big Bang when
the universe cooled enough for hydrogen atoms to form, letting photons
travel freely for the first time.  It reaches us from all directions
at a nearly uniform temperature of 2.725 K, with tiny fluctuations of
roughly ±100 microkelvin (one part in 100,000).  These fluctuations
are the seeds of all structure in the universe: the galaxies, clusters,
and cosmic web we see today grew from them.

## The acoustic peaks

Before recombination, matter existed as a hot photon-baryon plasma —
a fluid in which photons and protons were tightly coupled.  Slight
density perturbations in this plasma drove acoustic oscillations: sound
waves propagating through the fluid at roughly 57% of the speed of
light.  At recombination, this acoustic wave was "frozen in" to the CMB
at whatever phase each scale had reached.

Perturbations whose wavelength fit exactly one half-oscillation into
the age of the universe at recombination were enhanced: they had either
reached maximum compression or maximum rarefaction at the moment the
plasma cleared.  These preferred scales appear as peaks in the angular
power spectrum, indexed by multipole moment ℓ (where ℓ ≈ 180°/θ).

The **first acoustic peak** near ℓ ≈ 220 (angular scale ≈ 0.82°)
corresponds to the mode that completed exactly half an oscillation
before recombination.  Higher peaks at ℓ ≈ 540, 810, 1120, … are
the second, third, and fourth harmonics — the universe ringing at
its natural frequencies.

### What the peaks reveal

The positions and relative heights of the peaks are a precision probe
of fundamental cosmology:

- **Angular position of peak 1** (ℓ ≈ 220): tells us the geometry of
  the universe.  That it falls at ℓ ≈ 220 and not higher or lower
  means the universe is spatially flat.  A curved universe would shift
  all the peaks.

- **Relative height of peak 2 vs peak 1**: the even peaks (2nd, 4th, …)
  are suppressed relative to odd peaks by baryon loading — baryons
  (ordinary matter: protons and neutrons) add extra inertia that damps
  the rarefaction phases.  The depth of the 2nd-to-1st peak ratio
  measures the baryon density directly.  Planck finds Ω_b h² ≈ 0.022.

- **Relative height of peak 3 vs peak 2**: dark matter does not couple
  to radiation, so it does not participate in the acoustic oscillations
  but does deepen the gravitational potential wells.  The 3rd peak
  amplitude relative to the others constrains the dark matter density.
  Planck finds Ω_c h² ≈ 0.12.

- **Damping tail (ℓ ≳ 1000)**: photon diffusion washes out perturbations
  on small scales (Silk damping).  The exponential fall-off beyond the
  third peak reveals the photon mean free path at recombination.

## The three satellite missions

Three major space missions measured the CMB with progressively finer
resolution:

**COBE** (1989–1993): first detection of CMB anisotropies (ΔT ≈ 10 μK
fluctuations at ≥7° scales).  Angular resolution too coarse to resolve
the acoustic peaks — sensitive only to the Sachs-Wolfe plateau at low ℓ.
Nobel Prize in Physics 2006.

**WMAP** (2001–2010): resolved the first three acoustic peaks clearly.
Confirmed spatial flatness, measured baryon and dark matter densities.
Angular resolution ~0.2°, corresponding to ℓ up to ~800.

**Planck** (2009–2013, data to 2018): measured the spectrum to ℓ ≈ 2500,
resolving at least seven acoustic peaks.  Angular resolution ~5 arcmin.
The most precise cosmological parameter measurements to date; results
are consistent with the standard flat ΛCDM model (with a cosmological
constant Λ and cold dark matter).

## What to listen for

### Spectrum mode (default)

The sonification traverses the power spectrum from ℓ = 2 (largest
scales, ~90°) to ℓ = 2000 (smallest scales, ~0.09°).  Each multipole
becomes one note; pitch and volume both track the power D_ℓ.

**Listen for:**

1. **The Sachs-Wolfe plateau** (first few seconds): a steady, moderately
   pitched drone at low ℓ.  This is the large-scale imprint of gravity
   — photons escaping from slight density perturbations lose energy
   climbing out.

2. **The rise to the first peak** (around ℓ ≈ 220): a clear swell
   upward in both pitch and volume, louder than anything that follows.
   A distinct accent tone marks the moment.  This is the fundamental
   acoustic resonance of the universe.

3. **The first trough** (ℓ ≈ 400): pitch and volume fall back — modes
   that were caught between compression and rarefaction at recombination.

4. **The second and third peaks** (ℓ ≈ 540, 810): two more swells, each
   accented, each smaller than the last.  The second peak is noticeably
   lower than the first (baryon loading); the third is comparable to
   the second.

5. **The Silk damping tail** (ℓ ≳ 1000): a long, gradually quietening
   descent as diffusion erases small-scale structure.

### Sky mode

Sonifies a simulated flat-sky temperature anisotropy map (a 64 × 64
or larger patch of ~20°) via Hilbert-curve traversal.  Neighbouring
pixels in the traversal are also neighbours on the sky, so spatial
temperature gradients become temporal pitch sweeps.

**Listen for:**

- **Texture**: not a smooth signal but a speckled, correlated noise —
  the raw spatial imprint of the acoustic oscillations, before the
  power spectrum averaging that reveals the peaks.
- **Cold spots and hot spots**: patches of sustained low or high pitch
  as the traversal lingers in a cold or hot region of the sky.
- **Scale correlation**: nearby pixels tend to sound similar because
  the Hilbert curve preserves locality.  Rapid pitch jumps mark
  boundaries between hot and cold regions.

## Simulated vs Planck mode

`--simulation.cosmology.source=simulated` (default) uses an analytic
approximation: a sum of five Gaussians centred at the first five
acoustic peak positions, plus a Sachs-Wolfe plateau at low ℓ.  Peak
positions and approximate amplitudes match Planck 2018 results.  **This
is not a Boltzmann code (CAMB or CLASS) output.**  It is suitable for
accessible demonstration and education, not for scientific analysis.

`--simulation.cosmology.source=planck` fetches the actual Planck 2018
best-fit TT power spectrum (D_ℓ from ℓ = 2 to 2508) from the Planck
Legacy Archive.  This is research-grade data.  If the fetch fails (no
internet, URL changed), the app prints a warning and falls back to
simulated mode automatically.

## Running

```sh
# Default: spectrum mode, simulated source
wolframscript -file cosmology/main.wl

# Sky mode
wolframscript -file cosmology/main.wl -- --simulation.mode=sky

# Real Planck data (requires internet)
wolframscript -file cosmology/main.wl -- --simulation.cosmology.source=planck

# Higher resolution sky, limited l range
wolframscript -file cosmology/main.wl -- \
  --simulation.mode=sky \
  --simulation.cosmology.sky_resolution=128 \
  --simulation.cosmology.l_max=1500

# Play the result (macOS)
afplay cosmology/output/cmb_spectrum_audio.wav
```

## Output files

| File | Description |
|------|-------------|
| `cmb_spectrum_audio.wav` | Spectrum sonification (spectrum mode) |
| `cmb_spectrum.png` | D_ℓ vs log ℓ plot with peak markers |
| `cmb_spectrum_data.csv` | l, C_l, D_l, is_peak table |
| `cmb_sky_audio.wav` | Sky map sonification (sky mode) |
| `cmb_sky.gif` | Animated Hilbert traversal of the sky patch |
| `cmb_sky.png` | Static false-colour temperature map |
| `cmb_sky_data.csv` | Per-pixel temperature and frequency table |

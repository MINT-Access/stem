# Blackbody — Planck Black Body Radiation

Sonifies Planck's law — the formula that ended the "ultraviolet
catastrophe", founded quantum mechanics in 1900, and explains why
hotter things glow bluer. Every object with a temperature radiates a
continuous spectrum shaped only by that temperature; this app sweeps
the spectrum itself, sweeps temperature, and tours six real stars and
stellar remnants across it.

**New to this app?** Start with
[`blackbody/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — the recommended
four-step listening sequence across all three modes.

## The physics

### Planck's law

The spectral radiance emitted by a black body at temperature `T`, as a
function of photon frequency `nu`:

    B(nu,T) = (2*h*nu^3 / c^2) / (exp(h*nu / k*T) - 1)

Two classical limits, both checked against the exact formula every run:

| Regime | Approximation | Historical significance |
|---|---|---|
| Low frequency (`h*nu << k*T`) | `B ~ 2*nu^2*k*T/c^2` (Rayleigh-Jeans) | Diverges as `nu` grows — the "ultraviolet catastrophe" |
| High frequency (`h*nu >> k*T`) | `B ~ (2*h*nu^3/c^2)*exp(-h*nu/k*T)` (Wien) | Correctly predicts the falloff Rayleigh-Jeans misses |

Planck's exact formula is the only one that matches both limits — the
result that forced quantum mechanics into existence.

### Wien's displacement law

The wavelength at which `B` peaks scales inversely with temperature:

    lambda_peak * T = b,   b = 2.8978e-3 m*K

At the Sun's photosphere temperature (5778 K), `lambda_peak` is about
502 nm — squarely in the visible band. This is not a coincidence human
vision was built around: it is *why* the visible band is where it is.

### The Stefan-Boltzmann law

Total emitted power per unit area grows as `T^4` — an extremely fast
function. Between this app's coolest and hottest temperature-mode
endpoints (2500 K and 40000 K), that is a factor of over 65,000. Mapped
directly to audio volume this would be silent at one end or clipped at
the other; `temperature` mode compresses it logarithmically instead
(see Sonification mapping below).

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically
- Optional for the spoken intro: macOS `say` (built in), Linux
  `espeak-ng`/`espeak`, or Windows PowerShell (built in) — falls back
  to text-only output if none is available

## Quick start

```sh
# Spectrum mode (default): solar temperature, chord then radio-to-X-ray sweep
wolframscript -file main.wl

# Spectrum mode at a different temperature
wolframscript -file main.wl -- --simulation.blackbody.temperature=3200

# Temperature mode: 2500K red dwarf to 40000K blue giant sweep
wolframscript -file main.wl -- --simulation.mode=temperature

# Star mode: a single named preset
wolframscript -file main.wl -- --simulation.mode=star \
                                --simulation.blackbody.preset=rigel

# Star mode: the full tour, red dwarf to white dwarf
wolframscript -file main.wl -- --simulation.mode=star \
                                --simulation.blackbody.preset=all

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Modes

### spectrum (default)

Fixes temperature (default 5778 K, solar) and sweeps photon frequency
from radio through microwave, infrared, visible, ultraviolet, to
X-ray — about 13 orders of magnitude. `B(nu,T)` is discretised into
`n_bins` log-spaced bins and sonified the way `thermo/`'s `distribution`
mode sonifies the Maxwell-Boltzmann curve: as a spectral envelope, many
simultaneous sine partials whose amplitudes trace the Planck curve
directly. A held **chord** (the full curve at once) plays first,
marked with two soft taps at the 400 nm/700 nm visible-band edges; a
sequential **sweep** through the same bins follows, the chord-then-sweep
structure `hydrogen/`'s `spectrum` mode uses for its emission lines.

**Best for:** hearing directly how little of a star's total output
falls between the two taps — the "you cannot see most of the light a
star emits" demonstration.

### temperature

Sweeps temperature itself from `temp_min` to `temp_max` (default 2500 K
red dwarf to 40000 K blue giant) in `n_steps` steps, reusing the same
spectral-envelope technique per step (as `thermo/`'s `cooling` mode
reuses its own per-step envelope). Two physical laws are sonified at
once:

- **Wien's law → pitch**: a soft marker tone sounds at each step's
  peak frequency, audibly rising as temperature increases.
- **Stefan-Boltzmann's law → loudness**: overall amplitude follows
  `log(T^4)`, rescaled onto a listenable range — the true `T^4` growth
  would otherwise be silent at the cool end or clipped at the hot end.

**Best for:** hearing both laws operate simultaneously and independently
— pitch and loudness rising together but for entirely different physical
reasons.

### star

Six named presets spanning a wide range of real stars and remnants:
`red_dwarf` (~3200 K), `betelgeuse` (~3500 K, red supergiant), `sun`
(5778 K, default), `sirius_a` (~9940 K), `rigel` (~12100 K, blue
supergiant), `white_dwarf` (~25000 K). A single `preset` reuses
`spectrum` mode's chord-then-sweep for that star's temperature; `preset=all`
plays a sequential tour, coolest to hottest, each announced by name —
an audible walk from red dwarf to white dwarf that demonstrates Wien's
law across real objects rather than an abstract sweep.

**Best for:** outreach — "why do stars have colour" answered with six
concrete, named examples.

## Sonification mapping

| Quantity | Encoding |
|---|---|
| Photon frequency `nu` | Mapped logarithmically onto `[audio_freq_min, audio_freq_max]` (default 100-4000 Hz) — matches human pitch perception, and `thermo`/`hydrogen`'s own log frequency maps |
| `B(nu,T)` (spectral radiance) | Partial amplitude within a frame (`spectrum` chord, `temperature`/`star` per-step frames) |
| Visible-band edges (400/700 nm) | Two accent taps (`spectrum` chord) / bell overlay (`spectrum` sweep) |
| Wien's-law peak frequency | Soft marker tone per frame (`temperature`, `star preset=all`) |
| Total power (`T^4`, Stefan-Boltzmann) | Overall frame loudness, log-compressed (`temperature`, `star preset=all`) |

## Correctness checks

All four checks are properties of the Planck formula itself, so all
four run on every invocation regardless of mode:

1. **Rayleigh-Jeans limit** — exact formula converges to the
   low-frequency approximation within 0.1% as `h*nu/k*T -> 0`.
2. **Wien approximation limit** — exact formula converges to the
   high-frequency approximation within 0.0001% as `h*nu/k*T -> infinity`.
3. **Wien's displacement law** — numerically locates the peak of
   `B(lambda,T)` (independently of the closed-form constant) for several
   temperatures and verifies `lambda_peak * T` matches `b` within 0.1%.
4. **Stefan-Boltzmann law** — numerically integrates `B(nu,T)` over all
   `nu` for two temperatures and verifies the ratio matches `(T1/T2)^4`
   within 0.1%.

## Outputs

| File | Description |
|------|-------------|
| `output/spectrum_audio.wav` | Spoken intro/outro + chord + sweep, solar (or configured) temperature |
| `output/spectrum.gif` | Animated sweep marker tracing the curve, bin by bin |
| `output/spectrum.png` | Static curve, visible band shaded, peak marked |
| `output/spectrum_data.csv` | Per-bin: frequency, wavelength, relative radiance, audio frequency |
| `output/temperature_audio.wav` | Spoken intro + per-step frames, peak-marked, loudness-compressed |
| `output/temperature.gif` | Animated curve shifting/broadening as T rises, peak marked |
| `output/temperature.png` | Composite of representative curves across the sweep, peaks marked |
| `output/temperature_data.csv` | Per-step: temperature, peak frequency/wavelength, loudness scale |
| `output/star_audio.wav` | Single-preset chord+sweep, or the full spoken tour (`preset=all`) |
| `output/star.gif` | Single-preset sweep animation, or sequential tour reveal (`preset=all`) |
| `output/star.png` | Single-preset static plot, or all-preset composite (`preset=all`) |
| `output/star_data.csv` | Single-preset bin table, or per-preset long-format table (`preset=all`) |

## Configuration parameters (`blackbody/config.json`)

| Key | Default | Used by |
|-----|---------|---------|
| `simulation.mode` | `"spectrum"` | all |
| `simulation.blackbody.temperature` | `5778` | spectrum |
| `simulation.blackbody.temp_min` / `temp_max` | `2500` / `40000` | temperature |
| `simulation.blackbody.n_steps` | `100` | temperature |
| `simulation.blackbody.preset` | `"sun"` | star (`red_dwarf`, `betelgeuse`, `sun`, `sirius_a`, `rigel`, `white_dwarf`, or `all`) |
| `simulation.blackbody.freq_min` / `freq_max` | `1e6` / `1e19` | spectrum, temperature, star (physical Hz, radio to X-ray) |
| `simulation.blackbody.n_bins` | `64` | spectrum, temperature, star |
| `simulation.blackbody.audio_freq_min` / `audio_freq_max` | `100` / `4000` | all (Hz, audio pitch range) |
| `simulation.blackbody.chord_duration` | `4.0` | spectrum, star (single preset) |
| `simulation.blackbody.note_duration` | `0.08` | spectrum, star (single preset) — sweep note length |
| `simulation.blackbody.frame_duration` | `0.12` | temperature — seconds per temperature step |
| `simulation.blackbody.tour_segment_duration` | `2.5` | star (`preset=all`) — seconds per star |

## Project structure

```
blackbody/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl        — 6 curated preset invocations
  config.json            — App defaults
  LISTENING_GUIDE.md      — Recommended listening sequence
  src/
    model.wl              — PlanckRadianceFreq/Wavelength, RJ/Wien approximations,
                            correctness checks, Stefan-Boltzmann loudness, star presets
    sonify.wl               — Additive synthesis engine (SynthesizeAdditiveFrame),
                            BlackbodySpectrumBins, per-mode Build*Audio functions
    speech.wl                 — Spoken intro synthesis and per-mode intro text
    animate.wl                  — Per-mode GIF/PNG renderers
    output.wl                    — CSV export and correctness-check/summary printing
  tests/
    test_model.wl              — Unit tests
  output/                       — Output files (not committed)
  README.md
  AGENTS.md
```

## Console output

Step numbers `[1/5]` through `[5/5]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements in
addition to the intro:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

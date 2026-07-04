# Thermo — Classical Statistical Mechanics

Sonifies the Maxwell-Boltzmann speed distribution, particle ensembles
under elastic collisions, thermal relaxation, and the equipartition
theorem — the statistical mechanics of a classical ideal gas. Purely
classical: no quantum statistics anywhere in this app.

**New to this app?** Start with
[`thermo/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — the recommended
five-step listening sequence across all four modes.

## The physics

### Maxwell-Boltzmann speed distribution

At thermal equilibrium, the probability density of molecular speed `v`
in an ideal gas is:

    f(v) = 4*pi * (m / 2*pi*k*T)^(3/2) * v^2 * exp(-m*v^2 / 2*k*T)

where `m` is molecular mass, `k` is Boltzmann's constant, and `T` is
absolute temperature. Three characteristic speeds satisfy
`v_p < v_mean < v_rms` always:

| Speed | Formula | Meaning |
|-------|---------|---------|
| Most probable, `v_p` | `Sqrt[2kT/m]` | the peak of the distribution |
| Mean, `v_mean` | `Sqrt[8kT/(pi*m)]` | the arithmetic average |
| RMS, `v_rms` | `Sqrt[3kT/m]` | relevant for kinetic energy |

The RMS speed is always highest because the distribution has a long
high-speed tail — a few fast molecules pull the average (and especially
the mean square) upward more than they pull the peak.

### The equipartition theorem

Each quadratic degree of freedom contributes `(1/2)kT` to a molecule's
mean energy:

| Gas type | DOF | Mean energy | Heat capacity ratio (gamma) |
|---|---|---|---|
| Monatomic (He, Ar) | 3 translational | `(3/2)kT` | 5/3 ≈ 1.67 |
| Diatomic, room temp (N2, O2, H2) | 3 translational + 2 rotational | `(5/2)kT` | 7/5 = 1.40 |

Translational energy is identical for every ideal gas at the same
temperature — a monatomic and a diatomic gas at the same `T` have
*exactly* the same speed distribution. The diatomic gas simply stores
additional energy rotationally, which is why it has a higher heat
capacity.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically
- Optional for the spoken intro: macOS `say` (built in), Linux
  `espeak-ng`/`espeak`, or Windows PowerShell (built in) — falls back
  to text-only output if none is available

## Quick start

```sh
# Distribution mode (default): sweep T, hear f(v) as a spectral envelope
wolframscript -file main.wl

# Ensemble mode: 20 particles, sonified as a reshuffling chord
wolframscript -file main.wl -- --simulation.mode=ensemble

# Cooling mode: thermal relaxation from hot to cold
wolframscript -file main.wl -- --simulation.mode=cooling

# Equipartition mode: monatomic vs diatomic, binaural
wolframscript -file main.wl -- --simulation.mode=equipartition

# Named gas presets
wolframscript -file main.wl -- --simulation.thermo.preset=nitrogen
wolframscript -file main.wl -- --simulation.thermo.preset=hydrogen

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Modes

### distribution (default)

Sweeps temperature from `T_start` to `T_end` (default 100K to 1000K)
in `n_steps` steps (default 100). At each step, the MB speed
distribution `f(v)` is discretised into `n_bins` frequency bins
(default 64) and synthesised as a chord of simultaneous sine partials
weighted by density — the frame's spectral envelope literally *is* the
MB curve. A soft triple-tap (330/440/550 Hz) marks each temperature
step. Frames concatenate into one continuous sweep.

**Best for:** hearing the distribution itself broaden and rise in
pitch as temperature increases — the most direct sonification of the
physics.

### ensemble

Samples `n_particles` (default 20, max 50) speeds from the MB
distribution at a fixed temperature (`T_fixed`, default 300K), then
runs `n_timesteps` (default 200) elastic-collision steps: each step
picks one random pair of particles and exchanges their speeds exactly
(the correct physics for an equal-mass 1D elastic collision). Each
particle is one simultaneous voice in a chord, at a fixed stereo pan
position spread across the field.

**Best for:** hearing the same physics as `distribution`, but as
discrete, individually-trackable voices — and noticing that collisions
constantly reshuffle who has which pitch while the chord's overall
character stays stable. That's thermal equilibrium: a fixed
macroscopic state built from a restlessly fluctuating microscopic one.

### cooling

Starts at `T_hot` (default 1000K) and relaxes exponentially toward
`T_cold` (default 50K) over a 5-second audio duration, following
Newton's law of cooling: `T(t) = T_cold + (T_hot-T_cold)*exp(-t/tau)`.
The spectral envelope contracts and quiets (amplitude `~ Sqrt[T]`) as
the gas cools. An accent tone marks the moment the gas reaches within
10% of `T_cold`.

**Best for:** hearing the same distribution physics as `distribution`
mode, but run in time as an actual relaxation process rather than a
parameter sweep.

### equipartition

Compares a monatomic and a diatomic gas at the same temperature.
Sweeps T from `T_start` to `T_end` for the molecule type selected via
`--simulation.thermo.molecule` (`monatomic` or `diatomic`, default
diatomic). The **left channel** is always the translational MB
spectrum (identical physics to `distribution` mode); the **right
channel** is a rotational-energy drone, present only for diatomic
gases, growing louder and higher as temperature rises.

**Best for:** making the equipartition theorem directly audible — the
left channel is identical either way, but the right channel's presence
or absence *is* the extra heat capacity of a diatomic gas.

## Sonification mapping

| Quantity | Encoding |
|---|---|
| Speed `v` | Frequency, mapped logarithmically onto `[freq_min, freq_max]` (default 80-4000 Hz) — matches human pitch perception |
| `f(v)` (MB density) | Partial amplitude within a frame (`distribution`/`cooling`/`equipartition` left channel) |
| Particle speed | Per-voice frequency (`ensemble` mode) |
| Rotational energy | Right-channel drone frequency/amplitude (`equipartition`, diatomic only) |
| Stereo pan (`ensemble`) | Fixed per-particle position spread across `[-1, 1]` |

## Correctness checks

Every run prints checks 1-2; `ensemble` and `equipartition` print an
additional mode-specific check:

1. **Normalisation** — `f(v)` integrates to 1.0 over `[0, v_max]` within 0.001.
2. **Characteristic speed ratios** — `v_mean/v_p = Sqrt[4/pi] ≈ 1.1284`,
   `v_rms/v_p = Sqrt[3/2] ≈ 1.2247`, exact algebraic identities.
3. **Ensemble equilibration** (`ensemble` only) — final ensemble mean
   speed within 10% of the analytic `v_mean`.
4. **Equipartition** (`equipartition` only) — mean translational KE
   equals `(3/2)kT` within 1%, checked for both a monatomic- and
   diatomic-representative mass.

## Outputs

| File | Description |
|------|-------------|
| `output/distribution_audio.wav` | Spoken intro + MB temperature sweep (16-bit PCM, 44100 Hz, stereo) |
| `output/distribution.gif` | Animated MB curve, colour shifting blue->red as T rises |
| `output/distribution_data.csv` | Per-step: T, v_p, v_mean, v_rms |
| `output/ensemble_audio.wav` | Spoken intro + particle-ensemble chord |
| `output/ensemble.gif` | Animated speed histogram vs the analytic MB curve |
| `output/ensemble_data.csv` | Per-(timestep, particle): speed, collided flag |
| `output/cooling_audio.wav` | Spoken intro + thermal relaxation sonification |
| `output/cooling.gif` | Two-panel: T(t) curve + current MB distribution |
| `output/cooling_data.csv` | Per-frame: time, T, amplitude scale, equilibrium flag |
| `output/equipartition_audio.wav` | Spoken intro + binaural translational/rotational comparison |
| `output/equipartition.gif` | Side-by-side monatomic vs diatomic energy-partition pie charts |
| `output/equipartition_data.csv` | Per-step: T, translational/rotational/total energy, rotational fraction |

## Configuration parameters (`thermo/config.json`)

| Key | Default | Used by |
|-----|---------|---------|
| `simulation.mode` | `"distribution"` | all |
| `simulation.thermo.preset` | `"helium"` | distribution, ensemble, cooling (`hydrogen`, `helium`, `nitrogen`, `oxygen`, `argon`) |
| `simulation.thermo.mass_amu` | `4` | fallback mass if `preset` is unrecognised |
| `simulation.thermo.T_start` / `T_end` | `100` / `1000` | distribution, equipartition |
| `simulation.thermo.T_fixed` | `300` | ensemble |
| `simulation.thermo.T_hot` / `T_cold` | `1000` / `50` | cooling |
| `simulation.thermo.n_steps` | `100` | distribution, equipartition |
| `simulation.thermo.n_particles` | `20` (max 50) | ensemble |
| `simulation.thermo.n_timesteps` | `200` | ensemble |
| `simulation.thermo.n_bins` | `64` | distribution, cooling, equipartition |
| `simulation.thermo.frame_duration` | `0.1` | all (seconds per temperature step / timestep) |
| `simulation.thermo.freq_min` / `freq_max` | `80` / `4000` | all (Hz) |
| `simulation.thermo.molecule` | `"diatomic"` | equipartition (`monatomic` or `diatomic`) |

## Project structure

```
thermo/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl        — 8 curated preset invocations
  config.json            — App defaults
  LISTENING_GUIDE.md      — Recommended listening sequence
  src/
    model.wl              — MBDensity, characteristic speeds, correctness checks,
                            equipartition energetics, ensemble collisions, cooling curve
    sonify.wl               — Additive synthesis engine (SynthesizeAdditiveFrame),
                            per-mode Build*Audio functions
    speech.wl                 — Spoken intro synthesis and per-mode intro text
    animate.wl                  — Per-mode GIF renderers
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

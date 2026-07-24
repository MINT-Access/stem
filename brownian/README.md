# Brownian — Brownian Motion

Sonifies Brownian motion: the random walk a microscopic particle follows
under countless collisions with the fluid molecules surrounding it. This
is the app in this batch that needs no physics background to land —
"Einstein proved atoms exist by watching pollen jiggle in water" is a
genuinely great story, and its punch line is the sound itself: a
particle's own trajectory is a running Central Limit Theorem experiment,
happening in real space, all the time.

**New to this app?** Start with
[`brownian/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — the recommended
listening sequence across all three modes.

## The physics

### Robert Brown, Einstein, and Perrin

In 1827, botanist Robert Brown watched pollen grains jiggle erratically
under a microscope, at first wondering whether the motion indicated some
kind of life activity — then ruled that out by observing the identical
jiggling in grains of inorganic dust. The explanation waited until 1905,
when Einstein showed the motion was the visible, macroscopic signature
of countless invisible collisions with individual water molecules —
direct observational evidence for the molecular-kinetic theory of heat,
at a time when the physical reality of atoms was still genuinely
disputed among scientists. Jean Perrin's experiments (1908-1909)
quantitatively confirmed Einstein's predictions and are generally
credited with settling that dispute for good (Perrin, Nobel Prize 1926).

### The random walk model

Each small time step `dt`, a particle's displacement in each of `x` and
`y` is an independent draw from `Normal(0, sqrt(2 D dt))`, where `D` is
the diffusion coefficient. Because a sum of independent Gaussians is
EXACTLY Gaussian (not just asymptotically — see "Three connections"
below), the particle's net displacement after `N` such steps
(`t = N dt`) has an exact closed-form distribution:

    x(t), y(t) ~ Normal(0, 2Dt)  independently
    <r^2(t)> = 4Dt   exactly, where r^2 = x^2 + y^2

**The key, audible fact**: RMS displacement grows as `sqrt(t)`, not
linearly in `t` — utterly unlike ballistic, deterministic motion, where
displacement grows linearly with time. A single walker's own `r(t)` is
far too noisy to reveal this cleanly; an ensemble average, by contrast,
follows it exactly (see `ensemble` mode below, and the plot it produces
in `output/`).

### Three genuine connections to sibling apps

- **`thermo/`** — this random walk is a direct, microscopic picture of
  the same thermal-fluctuation physics `thermo/`'s Maxwell-Boltzmann
  distribution describes statistically: molecular collisions are what's
  actually jostling the particle, and `temperature` mode's D(T) sweep
  makes that temperature-dependence audible directly.
- **`dynamical/`** — a genuine "random vs. deterministic trajectories"
  counterpart: `dynamical/`'s logistic map is fully deterministic yet
  looks chaotic; this app's walk is genuinely random yet obeys an exact
  statistical law. Two different roads to "individually unpredictable,
  collectively lawful."
- **`clt/`** — this random walk *is* a running sum of iid random
  variables: literally the Central Limit Theorem setup, just applied to
  spatial displacement instead of an abstract sample mean. Unlike
  `clt/`'s general sources, a sum of GAUSSIAN steps is exactly Gaussian
  at every step count, not just asymptotically — see Correctness check 3
  and `AGENTS.md` for the direct, illuminating contrast between the two
  apps' kurtosis checks.

### The Stokes-Einstein relation

    D = k_B T / (6 pi eta r)

where `k_B = 1.380649e-23 J/K` (exact, by the 2019 SI redefinition — not
measured, not rounded), `T` is temperature, `eta` is the fluid's dynamic
viscosity, and `r` is the particle's radius. For a micron-scale particle
in water at room temperature, this produces `D` on the order of
`1e-13 m^2/s` — squarely inside the well-known realistic range for
Brownian motion of micron-sized particles in water (see Correctness
check 2).

**A real simplification, stated plainly**: water's own viscosity is
itself temperature-dependent — and rather more so than a first guess
might suggest: standard reference values put it at 1.792 mPa·s at 0°C
and 0.6527 mPa·s at 40°C, a drop by a factor of about **2.75**, not
merely "roughly halving" (a claim from this app's own original build
brief that didn't survive verification — see `AGENTS.md` design decision
6 for the correction). `temperature` mode holds `eta` fixed while
sweeping `T`, rather than also modelling `eta(T)` — a deliberate
simplification, the same spirit as `quantum_tunnelling/`'s
`alpha_decay` preset and `fluid/`'s vortex-method simplifications being
stated plainly rather than left implicit.

**A second correction**: the original build brief suggested sweeping
temperature over "~250K-350K, comfortably spanning water's liquid range
near room temperature" — but 250K is -23.15°C, well below freezing.
`temperature` mode instead sweeps **275K-350K** (2°C to 77°C) by
default, safely liquid at both ends.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically
- Optional for the spoken intro: macOS `say` (built in), Linux
  `espeak-ng`/`espeak`, or Windows PowerShell (built in) — falls back
  to text-only output if none is available

## Quick start

```sh
# Walk mode (default): a single random walk, 1 micron particle in water at room temperature
wolframscript -file main.wl

# Ensemble mode: 150 independent walkers, the sqrt(t) law made audible
wolframscript -file main.wl -- --simulation.mode=ensemble

# Temperature mode: D(T) via Stokes-Einstein, 275K to 350K
wolframscript -file main.wl -- --simulation.mode=temperature

# A larger, less agitated particle
wolframscript -file main.wl -- --simulation.brownian.particle_radius_um=5.0

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Modes

### walk (default)

A single 2D random walk, sonified continuously — the same
`SpatialLayer`/`MotionLayer`/`EventLayer` pipeline `lorenz/` and
`henon/attractor` use, with `x` driving stereo pan and `y` driving
pitch, matching those apps' established convention. **One deliberate
deviation**: volume here comes from `r = sqrt(x^2+y^2)`, the
displacement from the origin — not from speed, the convention every
other trajectory app in this codebase uses. Local jitter (speed) says
nothing about diffusion specifically; how far the particle has actually
wandered is the physically meaningful quantity. See `AGENTS.md` design
decision 1 for the full reasoning, including a side effect this has on
the audio's envelope. The GIF renders the wandering path growing over
time, colour-graded like `lorenz/`'s own progressive reveal.

**Best for:** hearing a single random walk directly, and noticing that
its volume tracks net wandering, not jitter.

### ensemble

Tracks 150 independent walkers (default) starting from the same origin,
and sonifies the ensemble-*averaged* RMS(t) as a single continuously
rising tone — reusing the phase-accumulation glissando idiom from
`compton/sweep` and `relativity/`'s chirp, but driven by an interpolated
real Monte Carlo curve rather than a recomputed closed-form formula
(there is no closed form for a finite ensemble average — see
`AGENTS.md` design decision 3). The rising tone's slope visibly (and
audibly) decays over time: fast climbing at first, flattening later —
the concave `sqrt(t)` shape that distinguishes diffusion from ballistic
motion. The PNG output overlays a few individual walkers' own noisy
`r(t)` (grey), the clean ensemble RMS(t) (blue), and the theoretical
`sqrt(4Dt)` curve (dashed) — the three should visibly coincide except
for Monte Carlo noise in the individual paths.

**Best for:** hearing (and seeing) the actual mathematical law, not
just a single noisy walker's own unpredictable path.

### temperature

Sweeps temperature from 275K to 350K (default), computing `D(T)` via
Stokes-Einstein at each step and generating a short representative walk
whose per-step jiggle amplitude scales directly with `sqrt(D(T))` at a
FIXED time-step size — reusing `thermo/distribution`'s per-temperature-
step-frame concatenation idiom. Audible goal: hotter is more agitated,
colder is calmer. **Honestly stated**: because `D` scales linearly with
`T` (viscosity held fixed) and water's realistic liquid range only spans
a temperature ratio of about 1.3-1.4, this effect is real and correctly
directioned but genuinely modest (roughly a 10-15% jiggle-amplitude
change end to end) — not a dramatic contrast. See `AGENTS.md` design
decision 7 for why this app doesn't try to make it sound bigger than it
physically is.

**Best for:** hearing the Stokes-Einstein relation's direction of effect
directly, alongside the honest scale of a real physical quantity's
temperature-dependence within water's actual liquid range.

## Correctness checks

All four run unconditionally, every invocation, regardless of mode,
always at canonical parameters (1 micron particle, water viscosity, room
temperature, `dt=0.01s`), and all four exercise the REAL Monte Carlo
step-generation code, not a restatement of the formulas they validate
(diagnostic-only: print `[PASS]`/`[FAIL]`, never abort):

1. **MSD scaling** — empirical `<r^2(t)>` from a real ensemble matches
   `4Dt` within 5%.
2. **Stokes-Einstein realistic scale** — `D` at representative micron-
   particle/water/room-temperature parameters lands in the well-known
   ~1e-13 to 1e-12 m^2/s range.
3. **Exact-zero excess kurtosis at N=8** — a sum of Gaussian steps is
   exactly Gaussian at any step count, unlike `clt/`'s general sources
   where excess kurtosis only decays asymptotically (see `AGENTS.md`
   design decision 4 for the direct comparison).
4. **sqrt(t) growth shape** — RMS at two step counts a factor of 4 apart
   matches the predicted `sqrt(4)=2` ratio within 5%, explicitly ruling
   out linear-in-t (ballistic) growth.

## Outputs

| File | Description |
|------|-------------|
| `output/brownian_walk.wav` | Narrated continuous-trajectory sonification |
| `output/brownian_walk.gif` | Growing random-walk path animation |
| `output/brownian_walk.png` | Full static path, colour-graded by time |
| `output/brownian_walk.csv` | Per-step: n, t, x, y, r |
| `output/brownian_ensemble.wav` | Rising glissando tracking ensemble RMS(t) |
| `output/brownian_ensemble.png` | RMS(t) vs. individual walkers vs. sqrt(4Dt) theory |
| `output/brownian_ensemble.csv` | Per-step: n, t, ensemble RMS, ensemble MSD, 3 sample walker r(t) columns |
| `output/brownian_temperature.wav` | Per-temperature-step audio, coldest to hottest |
| `output/brownian_temperature.png` | Small-multiples panel: one representative walk per temperature |
| `output/brownian_temperature.csv` | Per-step: T, D, final/max/RMS displacement of that step's walk |

## Configuration parameters (`brownian/config.json`)

| Key | Default | Used by |
|-----|---------|---------|
| `simulation.mode` | `"walk"` | all |
| `simulation.brownian.particle_radius_um` | `1.0` | walk, ensemble, temperature |
| `simulation.brownian.viscosity_pa_s` | `0.001` | walk, ensemble, temperature (water at room temp) |
| `simulation.brownian.temperature_k` | `293.15` | walk, ensemble (room temperature) |
| `simulation.brownian.n_steps` | `2000` | walk, ensemble |
| `simulation.brownian.dt` | `0.01` | all |
| `simulation.brownian.n_walkers` | `150` | ensemble |
| `simulation.brownian.temp_min` / `temp_max` | `275.0` / `350.0` | temperature (see the liquid-range correction above) |
| `simulation.brownian.n_temp_steps` | `6` | temperature |
| `simulation.brownian.n_steps_per_frame` | `40` | temperature (per-step snippet length) |
| `simulation.brownian.frame_duration` | `3.0` | temperature (seconds per snippet) |
| `simulation.brownian.seed` | `7` | all (reproducible runs) |

## Project structure

```
brownian/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl         — 6 curated preset invocations
  config.json             — App defaults
  LISTENING_GUIDE.md       — Recommended listening sequence
  src/
    model.wl                — StokesEinsteinD, WalkTrajectory, EnsembleModel,
                            four correctness checks (all against the real Monte
                            Carlo step-generation code, not a formula restatement)
    sonify.wl                 — lorenz/henon-style continuous trajectory (walk,
                            with volume-from-r deviation), compton/relativity-style
                            glissando on an interpolated ensemble curve (ensemble),
                            thermo-style per-step-frame concatenation (temperature)
    speech.wl                  — Spoken intro synthesis and per-mode intro text
    animate.wl                   — Per-mode GIF/PNG renderers
    output.wl                     — CSV export and console summaries
  tests/
    test_model.wl                — Unit tests
  output/                          — Output files (not committed)
  README.md
  AGENTS.md
```

## Connection to `lorenz/`, `henon/`, `thermo/`, `dynamical/`, and `clt/`

`brownian/` reuses `lorenz/`/`henon/attractor`'s continuous-trajectory
technique for `walk` mode (with one deliberate deviation — see
"Modes" above), `compton/sweep`/`relativity/`'s phase-accumulation
glissando for `ensemble` mode, and `thermo/distribution`'s per-step-
frame concatenation for `temperature` mode — three established
techniques, each reused because it's genuinely the right tool for that
mode, not because of an arbitrary rotation through this codebase's
existing idioms. Its deepest conceptual link, though, is to `clt/`: this
app's random walk is `clt/`'s exact same "running sum of iid random
variables" setup, just embodied in real, physical, two-dimensional space
rather than an abstract sample mean — see "Three genuine connections"
above.

## Console output

Step numbers `[1/5]` through `[5/5]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements in
addition to the intro:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

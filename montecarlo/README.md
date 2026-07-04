# Montecarlo — 2D Ising Model via Metropolis Monte Carlo

Sonifies the most physically rich Monte Carlo application in
statistical physics: the two-dimensional ferromagnetic Ising model,
whose phase transition has an exact analytic solution (Onsager, 1944)
— one of the most celebrated exact results in statistical mechanics.

**New to this app?** Start with
[`montecarlo/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — the recommended
three-mode listening sequence.

## The Ising model

A square lattice of `N x N` spins, each `s_i` in `{+1, -1}`, coupled to
its four nearest neighbours (periodic/toroidal boundary conditions):

    E = -J * Sum_<i,j> s_i * s_j

`J > 0` favours aligned neighbours (ferromagnetism). Two observables
track the system's state:

- **Magnetisation** `M = (1/N^2) Sum_i s_i` — ranges from -1 (all
  down) to +1 (all up); |M| near 1 means the system is ordered.
- **Susceptibility** `chi = N^2 (<M^2> - <M>^2) / kT` — a measure of
  how much magnetisation fluctuates; it diverges at the critical point.

Despite this simple rule, the model exhibits a genuine phase
transition: below a critical temperature `T_c`, the system
spontaneously magnetises (ferromagnetic order); above `T_c`, thermal
noise wins and magnetisation averages to zero (paramagnetic disorder).

## The Metropolis algorithm

Sampling every possible spin configuration is impossible (`2^(N^2)`
of them for an `N x N` lattice), so the Metropolis algorithm builds a
random walk through configuration space that spends time in each state
proportional to its Boltzmann probability:

1. Pick a random spin.
2. Compute the energy cost `dE` of flipping it.
3. If `dE <= 0` (flipping lowers energy), accept unconditionally.
4. If `dE > 0`, accept anyway with probability `exp(-dE/kT)`.

Step 4 is the essential trick: **always** accepting only downhill moves
would get the system stuck in a local minimum; occasionally accepting
an uphill move is what lets the system explore the full configuration
space and correctly sample thermal fluctuations. One Monte Carlo
*sweep* is `N^2` such attempts — one flip attempt per spin on average.

## The Onsager exact solution

For the 2D square-lattice Ising model, the critical temperature has an
exact closed form (Lars Onsager, 1944):

    T_c = 2J/k / ln(1 + sqrt(2))  ~=  2.2692 J/k

This is one of the few exactly-solved phase transitions in statistical
physics, and it took mathematical physics decades after Onsager's
result to find exact solutions for any other 2D model with a genuine
phase transition.

## Critical exponents and universality

Near `T_c`, magnetisation and susceptibility scale as power laws:

    |M|  ~ |T - T_c|^beta,   beta  = 1/8
    chi  ~ |T - T_c|^(-gamma), gamma = 7/4

These exponents are **universal** — every system in the same
universality class (the liquid-gas critical point, binary fluid
mixtures, and others with entirely different microscopic physics)
shares the *exact same* exponents. The 2D Ising model is the simplest
member of this universality class, which is why it has been studied so
intensively since the 1920s.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically
- Optional for the spoken intro: macOS `say` (built in), Linux
  `espeak-ng`/`espeak`, or Windows PowerShell (built in) — falls back
  to text-only output if none is available

## Quick start

```sh
# Sweep mode (default): descend T from 4.0 to 0.5, crossing T_c
wolframscript -file main.wl

# Critical mode: fixed at T_c, scale-free fluctuation
wolframscript -file main.wl -- --simulation.mode=critical

# Quench mode: instantaneous T_hot -> T_cold drop
wolframscript -file main.wl -- --simulation.mode=quench

# Larger lattice, finer sweep, off-critical exploration
wolframscript -file main.wl -- --simulation.montecarlo.lattice_size=64
wolframscript -file main.wl -- --simulation.montecarlo.N_T_steps=100
wolframscript -file main.wl -- --simulation.montecarlo.T_fixed=3.0
wolframscript -file main.wl -- --simulation.montecarlo.T_fixed=1.5

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Modes

### sweep (default)

Descends temperature from `T_start` to `T_end` (default 4.0 to 0.5,
passing through `T_c ≈ 2.269`) in `N_T_steps` steps. At each
temperature: `n_equilibration` sweeps are discarded (letting the
system settle), then `n_measurement` sweeps are recorded. The audio
traverses disorder (loud, noisy, low-pitched) through the critical
point (loudest, most turbulent moment) into order (quiet, steady,
high-pitched).

**Best for:** hearing the entire phase transition in one continuous
listening experience.

### critical

Fixes temperature at `T_c` (or any value via `T_fixed`, e.g. for
comparison) and runs `n_sweeps` sweeps from a random start. The system
never fully orders or disorders — magnetisation fluctuates at every
timescale, correlated domains form and dissolve at every size. This is
the literal audio signature of a continuous phase transition.

**Best for:** an isolated, extended listen to the most complex regime.

### quench

Starts from a fully random (high-temperature-equivalent) configuration
and simulates at `T_cold` from the very first sweep — an instantaneous
temperature drop. The audio starts turbulent (competing domains
forming), gradually settles as larger domains absorb smaller ones, and
approaches a quiet ordered tone, occasionally interrupted by domain-wall
events.

**Best for:** the clearest narrative arc — disorder, struggle, order.

## Sonification mapping

Two simultaneous layers, mixed together:

**Layer 1 — global observables** (stem-core's `SpatialLayer`/`MotionLayer` continuous carrier):

| Quantity | Encoding |
|---|---|
| `\|M(t)\|` | Pitch — ordered states (high \|M\|) sound higher; both ferromagnetic phases (up or down) sound equally ordered |
| Energy per spin `e(t)` | Stereo pan — ordered (low e) pans left, disordered (high e) pans right |
| `\|dM/dt\|` | Volume — rapid fluctuation near T_c is loud |
| T_c crossing (sweep only) | 440 Hz / 150 ms accent — the moment of phase transition |
| Magnetisation sign flip | 220 Hz / 50 ms click — a domain-reversal event |
| Susceptibility peak | 660 Hz / 100 ms accent — the most turbulent moments |

**Layer 2 — spatial Hilbert scan** (quieter, `spatial_layer_gain` dB relative to Layer 1, default -12 dB): each sonified sweep's spin grid is traversed in Hilbert-curve order (locality-preserving — nearby cells sound nearby in time); consecutive same-spin cells become a single held tone (spin +1 = C5, spin -1 = C3), so large aligned domains sound like long sustained tones and disordered regions sound like rapid alternation.

## Correctness checks

Every run prints checks 1-3; `sweep` mode additionally prints check 4:

1. **Onsager T_c** — the formula `2/ln(1+sqrt(2))` matches the known numeric value to 5+ decimal places.
2. **Energy bounds** — energy per spin lies within `[-2J, ~0]` for every recorded configuration.
3. **Detailed balance** — the Metropolis criterion's forward/reverse acceptance ratio for a real spin flip equals `exp(-dE/kT)` exactly.
4. **Magnetisation convergence** (`sweep` only) — `|M| > 0.8` for every recorded temperature below 1.0.

## Outputs

| File | Description |
|------|-------------|
| `output/sweep_audio.wav` | Spoken intro + temperature-sweep sonification (16-bit PCM, 44100 Hz, stereo) |
| `output/sweep.gif` | Two-panel: spin grid + M(T) curve with a T_c marker |
| `output/sweep_data.csv` | Per-sweep: T, M, E_per_spin, \|dM\|, chi_estimate, articulated |
| `output/critical_audio.wav` | Spoken intro + fixed-T_c sonification |
| `output/critical.gif` | Spin grid at T_c, fractal-like domain structure |
| `output/critical_data.csv` | Per-sweep data at fixed T |
| `output/quench_audio.wav` | Spoken intro + quench sonification |
| `output/quench.gif` | Spin grid coarsening from noise to large domains |
| `output/quench_data.csv` | Per-sweep data during the quench |

## Configuration parameters (`montecarlo/config.json`)

| Key | Default | Used by |
|-----|---------|---------|
| `simulation.mode` | `"sweep"` | all |
| `simulation.montecarlo.lattice_size` | `32` | all (coerced to the nearest power of 2) |
| `simulation.montecarlo.T_start` / `T_end` | `4.0` / `0.5` | sweep |
| `simulation.montecarlo.N_T_steps` | `50` | sweep |
| `simulation.montecarlo.n_equilibration` / `n_measurement` | `200` / `100` | sweep |
| `simulation.montecarlo.T_fixed` | `2.2692` | critical |
| `simulation.montecarlo.T_hot` / `T_cold` | `4.0` / `0.5` | quench |
| `simulation.montecarlo.n_sweeps` | `500` | critical, quench (quench defaults its own count to 400 in `main.wl`) |
| `simulation.montecarlo.random_seed` | `42` | quench |
| `simulation.montecarlo.J` | `1.0` | all |
| `simulation.montecarlo.pixel_duration` | `0.001` | all (Layer 2, before run-length grouping) |
| `sonification.montecarlo.spatial_layer_gain` | `-12` (dB) | all |

**Note:** total audio duration scales with lattice size — the spatial
layer sonifies a fixed number of snapshots (60), but each snapshot's
duration is `lattice_size^2 * pixel_duration`, so a 64x64 lattice
produces roughly 4x the duration of the 32x32 default (~260s vs ~80s).
Lower `pixel_duration` proportionally if you want larger lattices to
stay closer to the default length.

## Connection to other stem apps

- **`cellular/`** — both are 2D grids with local update rules; the key
  difference is Ising's temperature-driven *stochastic* Metropolis
  updates versus Life's *deterministic* rule. The spatial Hilbert layer
  here directly reuses cellular's run-length note-holding technique.
- **`thermo/`** — the Ising phase transition is the same kind of
  phenomenon as thermo's classical gas: a qualitative change in
  macroscopic behaviour driven by temperature, both governed by the
  same statistical-mechanics framework (Boltzmann weighting).
- **`dynamical/`** — the temperature sweep through `T_c` is
  structurally similar to the logistic map's sweep through its
  bifurcation cascade: a single control parameter driving a system
  through a qualitative change in long-term behaviour.

## Project structure

```
montecarlo/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl        — 7 curated preset invocations
  config.json            — App defaults
  LISTENING_GUIDE.md      — Recommended listening sequence
  src/
    model.wl              — Ising energy/magnetisation, Onsager T_c, Metropolis sweep,
                            correctness checks, sweep/critical/quench mode drivers
    sonify.wl               — Two-layer sonification (global-observable carrier +
                            run-length Hilbert spatial scan)
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

Step numbers `[1/5]` through `[4/5]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements in
addition to the intro:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

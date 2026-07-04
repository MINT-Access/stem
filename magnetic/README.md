# Magnetic

Simulates and sonifies charged-particle motion under the Lorentz force,
across four distinct field configurations: cyclotron orbits, E x B
drift, magnetic mirror trapping, and a multi-particle cyclotron chord.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`

## The physics: the Lorentz force

A particle of charge-to-mass ratio `q/m` moving with velocity `v`
through electric field `E` and magnetic field `B` obeys

```
dv/dt = (q/m) (E + v x B)
dr/dt = v
```

This app uses SI-inspired dimensionless units and supplies `q/m`
directly as `charge_mass_ratio` (equivalently, mass = 1), integrated
numerically with `NDSolve`.

### Why a magnetic field alone produces a circle

Because `v x B` is always perpendicular to `v`, a pure magnetic force
can never speed a particle up or slow it down — it only turns it. For
a uniform field `B = Bz zhat`, the result is uniform circular motion
(or a helix, if there's also a velocity component along `B`) at the
**cyclotron frequency**:

```
omega_c = (q/m) * Bz
```

The defining feature of `omega_c` is that it does not depend on the
particle's speed at all — only on its charge-to-mass ratio and the
field strength. That is what makes it such a clean, direct thing to
sonify: the audio frequency of the `cyclotron` mode tone literally *is*
the cyclotron frequency (after a fixed Hz-per-`omega_c` scale factor).

### E x B drift

Add a uniform electric field `E = Ex xhat` perpendicular to `B`, and
the particle picks up a steady drift velocity on top of its circular
motion:

```
v_drift = (E x B) / |B|^2 = -(Ex/Bz) yhat
```

(The direction depends on an arbitrary axis/handedness convention;
what's physically meaningful and constant is the *magnitude*,
`|Ex/Bz|` — independent of the particle's charge, mass, or speed.) The
combined motion — circular, riding on a steady drift — traces a
cycloid. This is one of the most important pieces of physics in
plasma confinement: it is the reason a tokamak's confining fields must
be shaped so carefully, since any stray perpendicular E field drives
plasma to drift straight out of the trap.

### Magnetic mirror

A magnetic field that gets stronger away from some midplane —
`Bz(z) = B0(1 + alpha z^2)` here — creates a "magnetic bottle." A
particle spiralling along the field gets pushed back toward the
midplane as it approaches the stronger field region, provided its
pitch angle `theta` (the angle between its velocity and the field
line) is steep enough:

```
sin^2(theta_0) > B0 / Bmax   =>   trapped
sin^2(theta_0) <= B0 / Bmax  =>   escapes through the mirror point
```

A field that only varies along `z` cannot actually produce this
reflecting force on its own (the Lorentz force from a purely-axial
field never has an axial component) — a real mirror also needs the
small radial field component required by `div B = 0`. See
`AGENTS.md` for the exact near-axis field expansion this app uses.

### The multi-particle chord

Three particles — proton, alpha particle (He2+), and electron — share
the same magnetic field but have wildly different charge-to-mass
ratios, so they gyrate at wildly different frequencies:

| Particle | q/m (relative to proton) | Audio frequency |
|---|---|---|
| Proton | 1 | `base_freq_hz` (110 Hz = A2, default) |
| Alpha particle | 0.5 | `base_freq_hz / 2` (one octave down) |
| Electron | 1836 | `base_freq_hz * 8` (frequency-scaled; the real ratio is explained in the spoken intro) |

Hearing all three at once is a chord that directly encodes their mass
ratios — the same physics behind a mass spectrometer or a cyclotron
particle accelerator.

## Modes

### `cyclotron` (default)

Uniform `B_z`, no electric field. A single particle orbits at a
constant frequency; set `v_parallel` nonzero for a helix. **What you
hear:** a rock-steady tone at the cyclotron frequency, panning
left-right-left-right with the orbit, with an accent "ping" at every
completed revolution.

### `drift`

Uniform `B_z` and `E_x`. **What you hear:** the stereo pan sliding
steadily from one side to the other (the drift) while the pitch
oscillates underneath (the circular motion riding along on top of it)
— together, a cycloid.

### `mirror`

Non-uniform `Bz(z)`. **What you hear:** pitch rising as the particle
approaches a mirror point and falling as it retreats, with a sharp
accent at each reflection. An escaping particle's pitch trends upward
overall rather than settling into a bounded rise-fall pattern — the
near-axis field's coupling into the axial motion can still give it a
wobble on the way out, so don't expect a perfectly clean climb.

### `multi`

Three particles, one field. **What you hear:** three simultaneous
tones — proton (left), alpha (centre), electron (right, scaled) — each
panning at its own rate, forming a chord that encodes the three
particles' mass ratios.

## Config keys (`config.json`)

| Key | Default | Meaning |
|---|---|---|
| `simulation.mode` | `"cyclotron"` | `cyclotron` \| `drift` \| `mirror` \| `multi` |
| `simulation.magnetic.B_z` | `1.0` | Uniform field strength (cyclotron/drift/multi) |
| `simulation.magnetic.E_x` | `0.5` | Electric field strength (drift only) |
| `simulation.magnetic.B_0` | `1.0` | Minimum field strength at the mirror midplane |
| `simulation.magnetic.alpha` | `0.5` | Mirror field gradient (larger = stronger, shorter mirror) |
| `simulation.magnetic.charge_mass_ratio` | `1.0` | q/m for the single-particle modes |
| `simulation.magnetic.v_perp` | `1.0` | Initial speed perpendicular to B |
| `simulation.magnetic.v_parallel` | `0.0` | Initial speed along B (cyclotron helix / mirror pitch angle) |
| `simulation.magnetic.n_periods` | `5` | Cyclotron periods to simulate (cyclotron/drift/multi) |
| `simulation.magnetic.mirror_duration` | `30.0` | Total integration time for mirror mode |
| `simulation.magnetic.base_freq_hz` | `110.0` | Hz mapped to `omega_c = 1` (all four modes; see AGENTS.md) |

See `LISTENING_GUIDE.md` for a guided listening sequence and
`AGENTS.md` for the physics and engineering decisions behind the
implementation.

## Connection to `relativity/`

`relativity/`'s `geodesic` mode integrates a *different* orbit-shaping
force (spacetime curvature rather than a magnetic field) but faces the
identical audio-design problem this app does: a tone whose frequency
must equal a physical rate exactly. Both apps solve it the same way —
manual frequency-array + phase-accumulated carrier synthesis — rather
than stem-core's generic `SonifyTrajectory` pipeline (see `AGENTS.md`
design decision 1). A natural future extension of this app: at
relativistic speeds, the cyclotron frequency picks up a
`1/gamma` correction from relativistic mass increase
(`omega_c = qB/(gamma m)`), which would make `cyclotron` mode's pitch
*decrease* as speed approaches `c` — currently out of scope, since all
motion here is non-relativistic.

## Running

```sh
# Default: cyclotron orbit
wolframscript -file magnetic/main.wl

# E x B drift
wolframscript -file magnetic/main.wl -- --simulation.mode=drift

# Magnetic mirror
wolframscript -file magnetic/main.wl -- --simulation.mode=mirror

# Multi-particle chord
wolframscript -file magnetic/main.wl -- --simulation.mode=multi

# Helix orbit
wolframscript -file magnetic/main.wl -- --simulation.magnetic.v_parallel=0.5

# Play the output (macOS)
afplay magnetic/output/cyclotron_audio.wav
```

## Correctness checks

Printed on every run:

1. **Cyclotron period** (`cyclotron`) — measured from positive-going
   zero-crossings of `x(t)`, compared to `2*Pi/omega_c` within 1%.
2. **E x B drift velocity** (`drift`) — mean `vy` compared to the
   analytic `-Ex/Bz` within 2%.
3. **Mirror trapping** (`mirror`) — analytic `sin^2(theta_0) > B0/Bmax`
   compared against the simulated outcome (reflected vs. escaped).
4. **Energy conservation** (all modes) — `|v|^2` constant to 0.1% for
   `cyclotron`/`mirror`/`multi` (the magnetic force does no work);
   periodic return to 0.1% for `drift` (the electric field does
   instantaneous but not net work over whole cyclotron periods).

## Output files

| File | Description |
|------|-------------|
| `output/cyclotron_audio.wav` | Steady cyclotron tone, panning with the orbit |
| `output/cyclotron.gif` | 2D circle or 3D helix trajectory |
| `output/cyclotron_data.csv` | Time series: position, velocity, speed, kinetic energy |
| `output/drift_audio.wav` | Oscillating pitch, drifting pan |
| `output/drift.gif` | 2D cycloid trajectory, coloured by speed |
| `output/drift_data.csv` | Drift trajectory time series |
| `output/mirror_audio.wav` | Rising/falling pitch, reflection accents |
| `output/mirror.gif` | 3D spiral trajectory with field-strength gradient |
| `output/mirror_data.csv` | Mirror trajectory time series |
| `output/multi_audio.wav` | Three-particle cyclotron chord |
| `output/multi.gif` | Three simultaneous orbits (proton/alpha/electron) |
| `output/multi_data.csv` | Long-format time series (one row per particle per step) |

## Project structure

```
magnetic/
  main.wl           — Entry point (thin orchestrator)
  experiments.wl    — Curated preset runs
  config.json       — App defaults
  src/
    model.wl        — EOM, NDSolve integration, correctness checks
    sonify.wl       — Manual carrier synthesis, spoken intro
    animate.wl      — GIF rendering (all four modes)
    output.wl       — CSV export
  tests/
    test_model.wl   — Unit tests (period, drift, trapping, energy, radius)
  output/           — Output files (not committed)
  README.md
  AGENTS.md
  LISTENING_GUIDE.md
```

## Console output

Step numbers `[1/4]` through `[4/4]` mark each pipeline stage.
Correctness-check results print `[PASS]` or `[FAIL]` with the measured
value. Export confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`,
and `STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage
announcements:

```sh
STEM_SPEAK=1 wolframscript -file magnetic/main.wl
```

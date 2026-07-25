# Qubit — A Single Qubit

Sonifies a single qubit: its Bloch-sphere representation, gate operations,
Rabi oscillation, and measurement. The foundational piece of a small
quantum-computing batch — `bell/` (entanglement) and `grover/` (a search
algorithm) build directly on the ideas introduced here.

**New to this app?** Start with
[`qubit/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — the recommended
listening sequence across all three modes.

## The physics

### The qubit and the Bloch sphere

A qubit's pure state is `|psi> = alpha|0> + beta|1>`, `|alpha|^2+|beta|^2=1`.
Every such state corresponds to exactly one point on the unit sphere (the
**Bloch sphere**), via (verified before use — see `AGENTS.md`):

    |psi> = Cos[theta/2]|0> + Exp[I phi] Sin[theta/2]|1>
    r = (sin(theta)cos(phi), sin(theta)sin(phi), cos(theta))

Equivalently, and the form this app actually computes with throughout
(phase-gauge-free, so it works for any global phase of `alpha,beta`, not
just the "alpha real" convention theta/phi assumes):

    r_x = 2 Re[Conjugate[alpha] beta]
    r_y = 2 Im[Conjugate[alpha] beta]
    r_z = |alpha|^2 - |beta|^2

`|0>` sits at the north pole, `|1>` at the south pole; every other pure
state is somewhere on the sphere's surface, never inside it — a
consequence of `|alpha|^2+|beta|^2=1` that correctness check 2 verifies
directly.

### Gates

Gates are 2x2 unitary matrices. This app includes Pauli X, Y, Z; Hadamard
H; phase gates S, T; and parametrized rotations Rx(theta), Ry(theta),
Rz(theta) — every one verified to satisfy `U^dagger U = I` to
near-machine precision (correctness check 1). Geometrically, every gate
is a rotation of the Bloch vector about some axis; `gates` mode makes
that rotation continuous and audible rather than a discrete jump between
states (see Modes below).

### Rabi oscillation

A qubit driven on resonance by a classical field, `H = -(hbar*Omega/2)
sigma_x` in the rotating frame, starting in `|0>`, has the closed-form
solution `P(measure 1 at time t) = sin(Omega t / 2)^2` — derived from the
Schrodinger equation via matrix exponentiation of `sigma_x`, and verified
two independent ways before use (matrix exponentiation AND direct
`NDSolve` integration of the coupled Schrodinger equation; both agree
with the closed form to ~1e-12 or better — see `AGENTS.md`). This
connects directly to [`quantum/`](../quantum/README.md)'s own
coherent-state and particle-in-a-box sonifications: `rabi` mode is the
two-level-system companion to that app's continuous-time-evolution
modes, in the same exact-quantum-mechanics domain.

### Measurement

The Born rule: measuring `|psi> = alpha|0> + beta|1>` gives outcome 0
with probability `|alpha|^2` and outcome 1 with probability `|beta|^2`,
collapsing the state to the corresponding basis state. `measurement`
mode simulates many independent repeated measurements and sonifies the
running empirical frequency converging toward the true `|alpha|^2` — the
quantum analogue of [`bayes/coin`](../bayes/README.md)'s flip-by-flip
belief update, using the same Monte Carlo technique (`SeedRandom`'d
Bernoulli draws, running `Accumulate`), though not the same audio
technique — see `AGENTS.md` design decision 5 for why.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically
- Optional for the spoken intro: macOS `say` (built in), Linux
  `espeak-ng`/`espeak`, or Windows PowerShell (built in) — falls back
  to text-only output if none is available

## Quick start

```sh
# Gates mode (default): H, T, H, S, X applied to |0>
wolframscript -file main.wl

# Rabi mode: continuous oscillation, Omega=1.5
wolframscript -file main.wl -- --simulation.mode=rabi

# Measurement mode: 2000 Born-rule measurements of an equal superposition
wolframscript -file main.wl -- --simulation.mode=measurement

# A single Hadamard gate, easiest to see clearly on the Bloch sphere
wolframscript -file main.wl -- --simulation.qubit.gate_sequence='["H"]'

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Modes

### gates (default)

Applies a configurable sequence of named gates (default: H, T, H, S, X)
to an initial state, sonifying the Bloch vector's path continuously as
it rotates — reusing `lorenz/`'s and `henon/attractor`'s continuous-
trajectory pipeline directly, since the Bloch vector's own `{x,y,z}`
coordinates map onto the trajectory's spatial columns with no invented
mapping needed. A short accent tone marks the start of each new gate,
giving the "narrated per-gate" structure `compton/scatter`'s discrete
event sequence has, adapted to a continuous underlying signal. The GIF
renders an actual 3D Bloch sphere with the path traced on its surface,
growing gate by gate.

**Best for:** seeing (and hearing) that a gate genuinely IS a rotation,
and that the state never leaves the sphere's surface.

### rabi

Continuous Rabi oscillation, `P(1)(t) = sin(Omega t/2)^2`, sonified as a
smoothly bending pitch (not amplitude — see `AGENTS.md` design decision
6 for why): the oscillation RATE `Omega` is audible directly as how fast
the pitch wobbles up and down, the same "the equation IS the pitch bend"
logic `compton/sweep` and `relativity/`'s chirp already use for their own
governing formulas.

**Best for:** hearing a textbook two-level system's exact solution
directly, and comparing it to `quantum/`'s own continuous-time-evolution
sonifications.

### measurement

Prepares a configurable superposition state (default: equal
superposition, `|alpha|^2=|beta|^2=0.5`) and simulates 2000 independent
repeated measurements, sonifying the running empirical P(0) frequency as
a pitch that wobbles and gradually settles onto the true value — reusing
`rabi` mode's own continuous pitch-tracking technique (see `AGENTS.md`
design decision 5), not `bayes/coin`'s spectral-density layering, since
there is no evolving distribution shape here, only a converging estimate.

**Best for:** hearing quantum randomness became statistical certainty,
one measurement at a time — literally the same "evidence accumulating"
structure as `bayes/coin`, just for a qubit instead of an ordinary coin.

## Correctness checks

All four run unconditionally, every invocation, regardless of mode,
always at canonical parameters (diagnostic-only: print `[PASS]`/`[FAIL]`,
never abort):

1. **Gate unitarity** — `U^dagger U = I` for all 6 fixed gates plus 3
   representative rotation angles. Exact relation, tight tolerance.
2. **Bloch length conservation** — a 7-gate sequence, `|r|=1` verified
   after every gate, not just the final state. Exact relation, tight
   tolerance.
3. **Rabi formula** — the closed form vs. an independent `NDSolve`
   integration of the Schrodinger equation (sharing no code with the
   closed form). Exact relation, tight tolerance.
4. **Born rule via Monte Carlo** — empirical frequency vs. `|alpha|^2`
   over 20000 trials, tolerance sized as a binomial standard-error band
   (matching `scattering/`'s check 4 convention), not an arbitrary flat
   percentage.

## Outputs

| File | Description |
|------|-------------|
| `output/qubit_gates.wav` | Narrated continuous Bloch-vector rotation, per-gate accents |
| `output/qubit_gates.gif` | 3D Bloch sphere, path traced gate by gate |
| `output/qubit_gates.png` | Full static Bloch sphere with the complete path |
| `output/qubit_gates.csv` | Per-gate: gate name, resulting state, Bloch coordinates |
| `output/qubit_rabi.wav` | Continuous pitch-glissando tracking P(1)(t) |
| `output/qubit_rabi.png` | P(1)(t) curve |
| `output/qubit_rabi.csv` | Per-sample: t, P(0), P(1) |
| `output/qubit_measurement.wav` | Continuous pitch-glissando tracking the running frequency |
| `output/qubit_measurement.png` | Running empirical P(0) vs. trial, with the true value dashed |
| `output/qubit_measurement.csv` | Per-trial: trial number, outcome, running P(0) |

## Configuration parameters (`qubit/config.json`)

| Key | Default | Used by |
|-----|---------|---------|
| `simulation.mode` | `"gates"` | all |
| `simulation.qubit.gate_sequence` | `["H","T","H","S","X"]` | gates |
| `simulation.qubit.initial_theta_deg` / `initial_phi_deg` | `0.0` / `0.0` | gates (starts at `\|0>`) |
| `simulation.qubit.n_steps_per_gate` | `30` | gates (animation/trajectory resolution) |
| `simulation.qubit.rabi_frequency` | `1.5` | rabi |
| `simulation.qubit.rabi_duration` | `10.0` | rabi |
| `simulation.qubit.n_trials` | `2000` | measurement |
| `simulation.qubit.measurement_theta_deg` / `measurement_phi_deg` | `90.0` / `0.0` | measurement (equal superposition) |
| `simulation.qubit.seed` | `7` | measurement (reproducible runs) |

## Project structure

```
qubit/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl         — 7 curated preset invocations
  config.json             — App defaults
  LISTENING_GUIDE.md       — Recommended listening sequence
  src/
    model.wl                — Gate matrices, Bloch vector, GatesTrajectory,
                            Rabi formula (+ independent Schrodinger check),
                            measurement Monte Carlo, four correctness checks
    sonify.wl                 — lorenz/henon-style continuous trajectory (gates),
                            shared phase-accumulation glissando (rabi, measurement)
    speech.wl                  — Spoken intro synthesis and per-mode intro text
    animate.wl                   — 3D Bloch sphere (gates), 2D curve plots (rabi,
                            measurement)
    output.wl                     — CSV export and console summaries
  tests/
    test_model.wl                — Unit tests
  output/                          — Output files (not committed)
  README.md
  AGENTS.md
```

## Connection to `quantum/`, `bayes/`, and the rest of the quantum-computing batch

`qubit/` reuses `lorenz/`'s and `henon/attractor`'s continuous-trajectory
sonification technique for `gates` mode, and the phase-accumulation
glissando technique (`compton/sweep`, `relativity/`'s chirp,
`brownian/ensemble`) for `rabi` and `measurement` — each because it's
genuinely the right tool for that mode, not an arbitrary rotation through
existing idioms. Its deepest conceptual links are to `quantum/` (the same
exact-quantum-mechanics domain, `rabi` mode as a direct companion to
`quantum/`'s coherent-state sonification) and `bayes/` (`measurement`
mode as the quantum analogue of `bayes/coin`'s belief-updating structure).
This app is also the deliberate foundation for two follow-on apps:
`bell/` (two entangled qubits — the Bloch-sphere and gate machinery built
here extends directly) and `grover/` (a search algorithm built from
single-qubit and multi-qubit gates).

## Console output

Step numbers `[1/5]` through `[5/5]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements in
addition to the intro:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

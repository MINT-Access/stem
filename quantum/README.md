# Quantum Mechanics

A Wolfram Language simulation of quantum wave-packet evolution in two
exactly-solvable systems, runnable entirely from the terminal via
`wolframscript`. Each run exports an animated probability-density GIF, a
3×3 snapshot PNG, a time-series CSV, and a sonification WAV.

## The mathematics

The time-dependent Schrödinger equation (ħ = m = 1) is solved analytically
by expanding the initial state in energy eigenstates and applying the
time-evolution operator to each:

    ψ(x, t) = Σₙ cₙ φₙ(x) exp(−i Eₙ t)

where cₙ = ⟨φₙ|ψ(x,0)⟩. The probability density |ψ(x,t)|² is computed at
each timestep and verified to integrate to 1 ± 1%.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`

## Usage

```bash
# Default (QHO coherent state)
wolframscript -file main.wl

# Explicit modes
wolframscript -file main.wl -- --simulation.mode=qho
wolframscript -file main.wl -- --simulation.mode=box

# Override parameters
wolframscript -file main.wl -- --simulation.qho.alpha=3.0
wolframscript -file main.wl -- --simulation.qho.omega=2.0

# Inspect merged config
wolframscript -file main.wl -- --config-dump

# Play sonification (macOS)
afplay output/qho_audio.wav
afplay output/box_audio.wav
```

## Modes

### `qho` — Quantum harmonic oscillator (coherent state)

Evolves the coherent state |α⟩ in the potential V(x) = ω²x²/2. A coherent
state is a minimum-uncertainty Gaussian wave packet that follows the classical
trajectory exactly — oscillating back and forth without spreading.

- Eigenfunctions: φₙ(x) = (2ⁿ n! √π)^(−½) Hₙ(x) exp(−x²/2)
- Coefficients: cₙ = exp(−|α|²/2) · αⁿ / √(n!)
- Mean energy: ⟨E⟩ = ω(|α|² + ½)

Default: α = 2, ω = 1, duration = 2π (one full oscillation period).

### `box` — Particle in a box

Evolves an equal superposition of the ground state and first excited state in
an infinite square well of length L. The wave packet oscillates between the
walls with period T = 4L²/(3π) (natural units).

- Eigenfunctions: φₙ(x) = √(2/L) sin(nπx/L), n = 1, 2, …
- Energy levels: Eₙ = n²π²/(2L²)
- Initial state: (φ₁ + φ₂)/√2 → ⟨E⟩ = (E₁ + E₂)/2

Default: L = 10, duration = 20 (roughly half an oscillation period).

## Outputs

All outputs are prefixed with the mode name so both modes coexist in `output/`.

| File | Description |
|------|-------------|
| `{mode}_density.gif` | Animated \|ψ(x,t)\|² — up to 100 frames at 10 fps |
| `{mode}_density.png` | 3×3 snapshot grid at 9 equal time intervals |
| `{mode}_timeseries.csv` | Time series: t, ⟨x⟩, Var(x), \|d⟨x⟩/dt\| |
| `{mode}_audio.wav` | Sonification: pan tracks ⟨x⟩, pitch tracks Var(x), volume tracks speed |
| `{mode}_description.wav` | Spoken description of the quantum state (macOS `say`) |

## Sonification

The density field is mapped to the stem-core trajectory format via
`DensityToTrajectory`:

| Trajectory column | Quantum quantity | Audio dimension |
|-------------------|-----------------|----------------|
| x | ⟨x⟩(t) — mean position | stereo pan |
| y | Var(x)(t) — position variance | pitch |
| speed | \|d⟨x⟩/dt\| — speed of mean position | volume |

`SonifyTrajectory` then applies spatial, motion, and event layers. For the
QHO coherent state, Var(x) is nearly constant so pitch varies little, but
volume pulses with the oscillation — giving the audio a wave-like feel. For
the box mode, both pitch and volume oscillate as the wave packet bounces.

## Project structure

    quantum/
    ├── main.wl              Entry point
    ├── config.json          App-level defaults
    ├── src/
    │   ├── model.wl         QHOModel, BoxModel
    │   ├── animate.wl       GIF + PNG visualisation (AnimateQuantum)
    │   └── sonify.wl        Trajectory adapter + audio export (SonifyQuantum)
    ├── output/              Output files (not committed)
    ├── AGENTS.md            Guidance for Claude Code
    └── README.md

## Console output

Step numbers `[1/4]` through `[4/4]` mark each pipeline stage. Mean energy
and normalisation status are printed after solving. Export confirmations use
`STEMDescribeCSV`, `STEMDescribeWAV`, and `STEMDescribeGIF`.

To enable speech at each stage, set `STEM_SPEAK=1`:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

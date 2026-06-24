# Pendulum

A pendulum physics simulation written in Wolfram Language, runnable entirely
from the terminal via `wolframscript`. Produces CSV data, an animated GIF,
and a musical WAV sonification.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`

## Quick start

```bash
# Full run: CSV + GIF + WAV
wolframscript -file main.wl

# Parameter experiments (baseline, long/short pendulum, large angle, moon gravity, pushed)
wolframscript -file experiments.wl

# Tests
wolframscript -file tests/test_model.wl
```

## Outputs

| File | Description |
|------|-------------|
| `data/results.csv` | Time, angle, velocity, energy per time step |
| `data/pendulum_animation.gif` | Looping animated GIF of the pendulum |
| `data/pendulum_audio.wav` | Musical sonification (A minor pentatonic, WAV) |

## Sonification

Angle is mapped to an A minor pentatonic scale. Each note lasts one
half-swing (zero crossing to zero crossing), and volume is proportional
to angular velocity — so the pendulum literally plays itself.

## Project structure

```
main.wl          — Entry point
experiments.wl   — Batch runs across parameter variations
src/model.wl     — ODE solver and energy calculation
src/output.wl    — CSV export and console summary
src/animate.wl   — Animated GIF export
src/sonify.wl    — WAV audio export
tests/           — Unit tests
data/            — Output directory (not committed)
```

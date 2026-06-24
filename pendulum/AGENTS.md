# AGENTS.md — Guidance for Claude Code

This file tells AI coding assistants how to work effectively in this project.

## Project overview

A simple pendulum simulation written in Wolfram Language, runnable entirely
from the terminal via `wolframscript`. Designed as a reusable template for
physics simulation projects. Produces CSV data, an animated GIF, and a
musical WAV sonification.

## Project structure

- `main.wl`          — Entry point. Runs simulation, exports CSV, GIF, WAV.
- `src/model.wl`     — ODE definition (`SolvePendulum`) and `PendulumEnergy`.
- `src/output.wl`    — CSV export (`ExportResults`) and `PrintSummary`.
- `src/animate.wl`   — Animated GIF export (`ExportAnimation`, `PendulumFrame`).
- `src/sonify.wl`    — Musical WAV export (`FindZeroCrossings`, `ExportSonification`).
- `tests/test_model.wl` — Unit tests for the physics and solver.
- `data/`            — Output directory. Do not commit this directory.

## How to run

```bash
# Full run: CSV + GIF + WAV
wolframscript -file main.wl

# Parameter experiments (produces named files in data/)
wolframscript -file experiments.wl

# Tests only
wolframscript -file tests/test_model.wl
```

## Outputs

| File                          | Description                            |
|-------------------------------|----------------------------------------|
| data/results.csv              | Time, angle, velocity, energy per step |
| data/pendulum_animation.gif   | Looping animated GIF of the pendulum   |
| data/pendulum_audio.wav       | Musical sonification as WAV audio      |

## Conventions

- All source files use `.wl` extension.
- Functions use `Module` for proper variable scoping.
- Parameters are always passed as an `Association` (never as globals).
- Physical quantities use SI units. Variable names include units where helpful.
- Tests use `Exit[1]` on failure so CI tools can detect failures.

## Important: WAV synthesis

`sonify.wl` uses stem-core's `StemSynthNote` + `ExportAudioBuffer` for all
audio synthesis — not `SoundNote`, `Audio[]`, or MIDI. `ExportAudioBuffer`
wraps samples in `SampledSoundList` (not `Audio[]`), which exports a valid WAV
in headless `wolframscript` sessions. Do not switch to `Audio[]` or `SoundNote`;
both fail silently in terminal contexts on macOS.

## Sonification design (src/sonify.wl)

- Pitch: pendulum angle mapped to `$StemScales["MinorPentatonic"]`, root A3 (220 Hz).
- Duration: each note lasts one half-swing (zero crossing to zero crossing).
- Volume: proportional to angular velocity at each zero crossing.
- Timbre: pure sine (`harmonics = {1.0}`) with decay fraction 1/3 via `StemSynthNote`.
- To change scale: pass a different key from `$StemScales` to `ScaleLookup` in `sonify.wl`.

## Animation design (src/animate.wl)

- Exports an animated GIF at 25 fps by default.
- Bob colour shifts from blue (centre) to red-violet (maximum swing).
- A motion trail shows the recent path of the bob.
- `ExportAnimation[solution, params, file, frameRate, speedup]`
  accepts optional frameRate (default 25) and speedup (default 1.0).

## When modifying the physics (src/model.wl)

- If you change the ODE, update `PendulumEnergy` to match.
- Always run the tests after changes to `src/model.wl`.
- The sonification and animation read from the `solution` list directly,
  so they adapt automatically to any new simulation.

## Dependencies

- Mathematica or Wolfram Engine (any recent version)
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`
- No external paclets required

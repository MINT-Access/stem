# AGENTS.md — Guidance for Claude Code

## Project overview

Lorenz attractor simulation in Wolfram Language, runnable from the terminal
via `wolframscript`. Produces a trajectory CSV, an animated GIF of the
butterfly-shaped attractor, and a musical WAV sonification.

## Project structure

- `main.wl`               — Full pipeline: solve → CSV → GIF → WAV
- `experiment.wl`         — Named presets for parameter exploration
- `src/model.wl`          — Lorenz ODE (`SolveLorenz`), pair solver
                            (`SolveLorenzPair`), divergence (`LorenzDivergence`)
- `src/output.wl`         — CSV export (`ExportResults`, `ExportDivergence`,
                            `PrintSummary`)
- `src/animate.wl`        — GIF export (`ExportAnimation`, `ExportDualAnimation`)
- `src/sonify.wl`         — WAV export (`ExportSonification`)
- `tests/test_model.wl`   — Unit tests
- `output/`                 — All output files (not committed)

## How to run

```bash
wolframscript -file main.wl          # full run
wolframscript -file experiment.wl    # experiment with presets
wolframscript -file tests/test_model.wl
afplay output/lorenz_audio.wav         # play audio on macOS
```

## Parameters (passed as Association)

| Key       | Meaning                        | Classic value |
|-----------|-------------------------------|---------------|
| Sigma     | Prandtl number                | 10.0          |
| Rho       | Rayleigh number               | 28.0          |
| Beta      | Geometric factor              | 8/3           |
| InitX/Y/Z | Initial conditions            | 1.0, 1.0, 1.0 |
| TimeEnd   | Simulation duration (seconds) | 40.0          |
| TimeStep  | Max ODE step size             | 0.005         |

## Chaos regimes

- rho < 1:        fixed point at origin
- 1 < rho < 24.74: stable fixed points (two symmetric spirals)
- rho > 24.74:    chaotic strange attractor

## Sonification design (src/sonify.wl)

- Note events triggered at each local extremum of x(t)
- Pitch: x-value mapped to chosen scale (default MinorPentatonic)
- Volume: proportional to |x| at each extremum
- Timbre: additive sine synthesis (3 harmonics) + exponential decay
- Available scales: MinorPentatonic, MajorPentatonic, Major, Minor, WholeTone, Phrygian
- Root note: Middle C (261.63 Hz), hardcoded as the `rootHz` argument to `ScaleLookup` in `BuildWaveform` — edit there to transpose

## Animation design (src/animate.wl)

- Projects 3D trajectory onto x-z plane (classic butterfly view)
- Colour gradient: blue → cyan → orange → red (early to recent)
- Dark background for contrast
- `ExportDualAnimation` shows two trajectories side-by-side

## Conventions

- Functions scoped with `Module`
- Parameters always in an `Association`; never global
- SI units throughout
- Tests use `Exit[1]` on failure
- `PrintSummary` uses `STEMPrintN` (stem-core) for the step count line. The
  x/y/z range lines each carry two values (`[min, max]`) and remain as bare
  `Print`. Follow the same rule for any additions: `STEMPrintN` for one value,
  bare `Print` for two.

## Dependencies

- Mathematica or Wolfram Engine (any recent version)
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`
- No external paclets required

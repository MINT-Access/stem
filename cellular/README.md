# Cellular Automata

A Wolfram Language simulation of two cellular automata — Conway's Game of Life
and Wolfram's Rule 110 — runnable entirely from the terminal via `wolframscript`.
Produces an animated GIF, a statistics CSV, and an audio sonification of the
population dynamics.

## The mathematics

### Conway's Game of Life (mode: `life`)

A two-dimensional cellular automaton on an 80×80 toroidal grid, evolving by
the B3/S23 rule: a dead cell with exactly 3 live neighbours is born; a live
cell with 2 or 3 live neighbours survives; all others die. Despite its
simplicity, the rule supports gliders, oscillators, and arbitrarily complex
computation.

### Wolfram Rule 110 (mode: `rule110`)

A one-dimensional elementary cellular automaton. Each cell's next state
depends only on itself and its two neighbours, according to lookup table 110
(binary `01101110`). Rule 110 is Turing complete — it can simulate any
computable process — yet has a deceptively simple definition.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`

## Usage

```bash
# Default (Game of Life, R-pentomino seed)
wolframscript -file main.wl

# Game of Life with different starting patterns (--key=value and --key value both accepted)
wolframscript -file main.wl -- --simulation.mode=life --simulation.life.starting_pattern=rpentomino
wolframscript -file main.wl -- --simulation.mode=life --simulation.life.starting_pattern=gliderlgun
wolframscript -file main.wl -- --simulation.mode=life --simulation.life.starting_pattern=random

# Rule 110
wolframscript -file main.wl -- --simulation.mode=rule110
wolframscript -file main.wl -- --simulation.mode rule110

# Inspect merged config
wolframscript -file main.wl -- --config-dump

# Play audio (macOS)
afplay output/life_rpentomino_audio.wav
afplay output/rule110_audio.wav
```

## Starting patterns (Game of Life)

| Pattern | Description |
|---------|-------------|
| `rpentomino` | 5-cell seed that evolves chaotically for centuries before stabilising |
| `gliderlgun` | Gosper Glider Gun — emits a glider every 30 generations |
| `random` | 30% random density — varies each run |

## Outputs

All outputs are prefixed with the mode and pattern name.

| File | Description |
|------|-------------|
| `life_{pattern}_animation.gif` | One frame per generation, 10 fps |
| `life_{pattern}_audio.wav` | Sonification of population dynamics |
| `life_{pattern}_stats.csv` | Per-generation: population, density, deltas |
| `rule110_animation.gif` | Single-frame GIF of the spacetime diagram |
| `rule110_animation_spacetime.png` | Full spacetime PNG (200 gen × 120 cells) |
| `rule110_audio.wav` | Sonification of Rule 110 population dynamics |
| `rule110_stats.csv` | Per-generation statistics |

## Sonification

The sonification maps population dynamics to audio parameters:

| Parameter | Mapping |
|-----------|---------|
| Pitch | Population density (live cells / total cells) |
| Pan | Left/right density asymmetry |
| Volume | Rate of population change |

Special events trigger short tone bursts:
- **Extinction** (>40% population drop in one step): 150 Hz low burst
- **Explosion** (>40% population rise in one step): 900 Hz high burst

Audio duration is 0.1 seconds per generation (30 s for 300 Life generations,
20 s for 200 Rule 110 generations).

## Project structure

    cellular/
    ├── main.wl              Entry point
    ├── config.json          App-level defaults
    ├── src/
    │   ├── model.wl         LifeModel, Rule110Model, GoLStep, LifeGrid
    │   ├── output.wl        ExportCellularStats, PrintCellularSummary
    │   ├── animate.wl       AnimateCellular, CellularFrame
    │   └── sonify.wl        SonifyCellular, GridToTrajectory, SynthBurst
    ├── output/              Output files (not committed)
    ├── AGENTS.md            Guidance for Claude Code
    └── README.md

## Console output

Step numbers `[1/4]` through `[4/4]` mark each pipeline stage. A cellular
automata summary with population statistics is printed after simulation.
`STEMDescribeCSV`, `STEMDescribeWAV`, and `STEMDescribeGIF` confirm each
export. `STEMSay` announces each phase ("Starting Game of Life…",
"Rendering animation", "Synthesising audio") and the final completion
message with an `afplay` command.

To enable speech at each stage, set `STEM_SPEAK=1`:

```sh
STEM_SPEAK=1 wolframscript -file main.wl -- --simulation.mode=life
```

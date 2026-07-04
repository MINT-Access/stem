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

# Play audio
# macOS
afplay output/life_rpentomino_audio.wav
afplay output/rule110_audio.wav

# Linux
aplay output/life_rpentomino_audio.wav
aplay output/rule110_audio.wav

# Windows PowerShell
Start-Process wmplayer output\life_rpentomino_audio.wav
Start-Process wmplayer output\rule110_audio.wav
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
| `life_{pattern}_data.csv` | Per-generation: population, note articulation, run length |
| `rule110_animation.gif` | Single-frame GIF of the spacetime diagram |
| `rule110_animation_spacetime.png` | Full spacetime PNG (200 gen × 120 cells) |
| `rule110_audio.wav` | Sonification of Rule 110 population dynamics |
| `rule110_stats.csv` | Per-generation statistics |
| `rule110_data.csv` | Per-generation: population, note articulation, run length |

## Sonification

Population dynamics are rendered as **held notes** rather than a continuous
stream: during stable periods the colony holds a single sustained note;
population changes produce new notes. The longer a note is held, the longer
the colony spent at that population level. A colony holding steady for many
generations produces one long note; rapid growth or collapse produces a
quick sequence of short notes.

A new note starts (an "articulation") only when the population changes
enough to cross a threshold; otherwise consecutive generations are grouped
into one run and rendered as a single note.

| Parameter | Mapping |
|-----------|---------|
| Pitch | Mean population of the run, mapped onto the minor pentatonic scale |
| Duration | Run length × `base_note_duration` |
| Pan | Left/right density asymmetry, averaged over the run |
| Volume | Max rate of population change within the run |

Special events trigger short tone bursts, independent of note articulation:
- **Extinction** (>40% population drop in one step): 150 Hz low burst
- **Explosion** (>40% population rise in one step): 900 Hz high burst

### Config keys

| Key | Default | Description |
|-----|---------|--------------|
| `simulation.cellular.articulation_mode` | `"relative"` | `"relative"` (percent change) or `"absolute"` (cell-count change) |
| `simulation.cellular.articulation_threshold` | `0.15` | Relative-mode threshold (fraction of previous population) |
| `simulation.cellular.articulation_threshold_abs` | `5` | Absolute-mode threshold (cell count) |
| `simulation.cellular.base_note_duration` | `0.06` | Seconds per generation; a run of N generations produces one note of `N × base_note_duration` seconds |

`articulation_threshold` controls how sensitive note articulation is to
population change. Lower values (e.g. `0.03`) produce more frequent
articulation, tracking smaller population changes. Higher values (e.g.
`0.30`) produce fewer, longer notes, emphasising only major population
shifts. Game of Life populations fluctuate by a few cells almost every
generation from ordinary oscillators, so a very low threshold (e.g. `0.03`)
articulates on nearly every generation; the default `0.15` keeps genuinely
stable stretches held as one note while still responding to real growth or
collapse (~48 notes for the default 300-generation R-pentomino run).

Audio duration is `generations × base_note_duration` seconds (18 s for 300
Life generations, 12 s for 200 Rule 110 generations, at the default 0.06
s/generation).

```bash
# Less sensitive articulation — fewer, longer notes
wolframscript -file main.wl -- --simulation.cellular.articulation_threshold=0.30

# More sensitive articulation — more, shorter notes
wolframscript -file main.wl -- --simulation.cellular.articulation_threshold=0.05
wolframscript -file main.wl -- --simulation.cellular.articulation_threshold=0.01

# Absolute-change mode instead of relative
wolframscript -file main.wl -- --simulation.cellular.articulation_mode=absolute
wolframscript -file main.wl -- --simulation.cellular.articulation_threshold_abs=10

# Faster / slower base tempo
wolframscript -file main.wl -- --simulation.cellular.base_note_duration=0.04
wolframscript -file main.wl -- --simulation.cellular.base_note_duration=0.10
```

## Project structure

    cellular/
    ├── main.wl              Entry point
    ├── config.json          App-level defaults
    ├── src/
    │   ├── model.wl         LifeModel, Rule110Model, GoLStep, LifeGrid
    │   ├── output.wl        ExportCellularStats, PrintCellularSummary
    │   ├── animate.wl       AnimateCellular, CellularFrame
    │   └── sonify.wl        SonifyCellular, GridToTrajectory,
    │                        ComputeRuns, BuildNoteAudio, SynthBurst
    ├── output/              Output files (not committed)
    ├── AGENTS.md            Guidance for Claude Code
    └── README.md

## Console output

Step numbers `[1/4]` through `[4/4]` mark each pipeline stage. A cellular
automata summary with population statistics is printed after simulation.
`STEMDescribeCSV`, `STEMDescribeWAV`, and `STEMDescribeGIF` confirm each
export. `STEMSay` announces each phase ("Starting Game of Life…",
"Rendering animation", "Synthesising audio") and the final completion
message with the platform-appropriate play command.

To enable speech at each stage, set `STEM_SPEAK=1`:

```sh
STEM_SPEAK=1 wolframscript -file main.wl -- --simulation.mode=life
```

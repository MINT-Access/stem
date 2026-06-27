# AGENTS.md — Guidance for Claude Code

## Project overview

Cellular automata simulation in Wolfram Language. Two modes — Conway's Game of
Life (2D, toroidal) and Wolfram Rule 110 (1D) — share a common 3D grid shape
`{generations, rows, cols}` so all downstream pipeline functions are completely
mode-agnostic.

## Project structure

- `main.wl`          — Entry point; mode branching; 4-step pipeline
- `config.json`      — App defaults (mode, life config, rule110 config)
- `src/model.wl`     — `LifeModel[cfg]`, `Rule110Model[cfg]`,
                       `GoLStep`, `GoLNeighbors`, `LifeGrid`
- `src/output.wl`    — `ExportCellularStats[grid3D, filePath]`,
                       `PrintCellularSummary[grid3D, modeName]`
- `src/animate.wl`   — `AnimateCellular[grid3D, cfg, outPath]`,
                       `CellularFrame[genGrid, cellPx]`
- `src/sonify.wl`    — `SonifyCellular[grid3D, cfg, outPath]`,
                       `GridToTrajectory[grid3D, cfg]`,
                       `SynthBurst`
- `output/`          — All output files (not committed)

## How to run

```bash
wolframscript -file main.wl                                           # default (life/rpentomino)
wolframscript -file main.wl -- --simulation.mode=life --simulation.life.starting_pattern=gliderlgun
wolframscript -file main.wl -- --simulation.mode=rule110
wolframscript -file main.wl -- --config-dump
afplay output/life_rpentomino_audio.wav
```

CLI override format: `--key=value` (with `=`). Space-separated `--key value`
is NOT accepted by `ParseCliOverrides` in stem-core.

## Grid shape convention

Both models return a 3D integer array of shape `{generations, rows, cols}`:
- `LifeModel` — `{300, 80, 80}` — rows and cols both non-trivial
- `Rule110Model` — `{200, 1, 120}` — singleton row dimension achieved via
  `List /@ result` (reshapes `{gens, width}` to `{gens, 1, width}`)

All downstream functions (`AnimateCellular`, `GridToTrajectory`,
`ExportCellularStats`) dispatch on `nRows === 1` to distinguish Rule 110 from
Game of Life.

## Critical implementation detail: GoLStep must use integer arithmetic

`GoLStep` uses `Unitize`, `Abs`, and `Clip` instead of `==` comparisons:

```wolfram
born    = 1 - Unitize[Abs[n - 3]]
survive = grid * (1 - Unitize[(n - 2) * (n - 3)])
Clip[born + survive, {0, 1}]
```

Using `n == 3` on a packed integer array produces symbolic `True/False` values
that unpack the 300×80×80 history array and make `Total[grid3D, {2, 3}]`
extremely slow (minutes instead of seconds). The integer-only form above keeps
all arrays packed throughout.

## Sonification data flow

```
grid3D
  → GridToTrajectory → trajectory {t, pan, density, 0, |Δpop|+ε}
  → SpatialLayer, MotionLayer (stem-core)
  → SynthBurst for extinction/explosion events
  → MixLayers → RenderAudio
```

Trajectory column mapping:
- `x` (pan)   — `(left_pop − right_pop) / cols`
- `y` (pitch) — `total_pop / (rows * cols)`
- `z`         — always 0.0
- `speed`     — `|Δpopulation| + 0.01` (ε prevents MinMax degeneracy)

Audio duration: `gens × 0.1` seconds, injected via `DeepMerge` before
calling `SpatialLayer`/`MotionLayer`.

## Animation dispatch

`AnimateCellular` branches on grid shape:
- `nRows > 1` (Life): renders one `ArrayPlot` frame per generation → animated GIF
- `nRows == 1` (Rule 110): renders full spacetime diagram as PNG + single-frame GIF

## Common pitfalls

- `Total[grid3D, {2, 3}]` sums over the row and column dimensions, leaving a
  `{nGen}` list of per-generation population counts. This is correct and fast
  on packed integer arrays; slow on unpacked arrays.
- `CellFrame` is a protected WL symbol — the function is named `CellularFrame`.
- Event detection in `SonifyCellular` uses fractional population change
  `(cur − prev) / prev`. Guard against `prev == 0` before dividing.
- Audio duration must be injected into cfg via `DeepMerge` before calling
  stem-core's `SpatialLayer`/`MotionLayer`, which read `sonification.duration`.

## Dependencies

- Mathematica or Wolfram Engine (any recent version)
- `stem-core` (sibling `../stem-core`) — `SpatialLayer`, `MotionLayer`,
  `MixLayers`, `RenderAudio`, `ExportGIF`, `ExportCSV`, `EnsureDir`,
  `STEMSay`, `STEMDescribe*`, `GetCfg`, `DeepMerge`, `LoadConfig`
- No external paclets required

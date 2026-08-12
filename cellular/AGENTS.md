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
- `src/animate.wl`   — `AnimateCellular[grid3D, cfg, outPath, targetDuration]`,
                       `CellularFrame[genGrid, cellPx]`
- `src/sonify.wl`    — `SonifyCellular[grid3D, cfg, outPath]`,
                       `GridToTrajectory[grid3D, cfg]`,
                       `ComputeArticulations`, `ComputeRuns`, `RunNoteDuration`,
                       `BuildNoteAudio`, `DetectPopulationEvents`,
                       `ExportArticulationCSV`, `SynthBurst`,
                       `ResolveBaseNoteDuration`, `CellularAudioDuration`
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

## Sonification data flow — run-length note articulation

```
grid3D
  → GridToTrajectory        → trajectory {t, pan, density, 0, |Δpop|+ε}
                               (pan column reused; rescaled + clipped
                               into [-1,1] before use — see below)
  → ComputeArticulations     → 0/1 list: does generation g start a new note?
  → ComputeRuns              → one Association per run {start, end,
                               length, meanPop, maxDelta}
  → BuildNoteAudio           → one StemSynthNote per run, pitch =
                               ScaleLookup(meanPop) on MinorPentatonic,
                               volume = maxDelta rescaled to dB range,
                               pan = mean pan over the run
  → DetectPopulationEvents   → extinction/explosion generation lists
                               (unchanged logic)
  → SynthBurst accent tones mixed additively into the same stereo buffer
  → RenderAudio + ExportArticulationCSV (writes `{name}_data.csv`)
```

Instead of the previous continuous per-generation pitch glissando
(stem-core's `SpatialLayer`/`MotionLayer`), population dynamics are now
rendered as discrete held notes: consecutive generations whose
population doesn't change enough to cross the articulation threshold
are grouped into a single run, and each run produces exactly one note
whose duration is `run length × base_note_duration`.

**Two threshold modes** (`--simulation.cellular.articulation_mode`):
- `"relative"` (default) — a new note starts when
  `|Δpop| / max(pop_prev, 1) > articulation_threshold` (default `0.15`,
  i.e. 15%).
- `"absolute"` — a new note starts when
  `|Δpop| > articulation_threshold_abs` (default `5` cells).

`base_note_duration` (default `0.06` s/generation) sets both the note
"tick" length and the overall audio duration: total duration is always
exactly `generations × base_note_duration` regardless of how the
generations are grouped into runs, since run lengths always sum to the
total generation count.

`base_note_duration` can be overridden per simulation mode via
`ResolveBaseNoteDuration` — e.g. `simulation.cellular.rule110.base_note_duration`
(currently `0.10`) applies only when `simulation.mode === "rule110"`,
falling back to the shared `simulation.cellular.base_note_duration`
(`0.06`, used by `life`) otherwise. Add further `simulation.cellular.<mode>.*`
keys the same way if a mode needs its own tempo.

**Articulation is independent of `DetectPopulationEvents`.** The
extinction (150 Hz) and explosion (900 Hz) accent tones fire from raw
population fraction-change thresholds (>40% drop/rise) exactly as
before the refactor; run-length grouping only affects which pitch/
volume/duration a generation contributes to, never whether an event
tone plays. `DetectPopulationEvents` is exposed as its own function
specifically so this independence can be unit-tested directly.

**Measured articulation counts (debugging reference):** at the default
15% relative threshold, the R-pentomino's 300-generation evolution
produces **~48 articulations** (avg run length ~6.25 generations) — in
the expected 40–80 order of magnitude, with clearly audible held notes
during quieter stretches. Note that Game of Life population rarely
holds exactly still for more than a few generations at these
population magnitudes (5–237) — a single blinker or oscillator
changing by 1–2 cells easily exceeds a 3% threshold, which is why the
default was raised from an initial 3% (which produced ~230
articulations, mostly length 1–2, effectively defeating the
sustained-note effect) to 15%. Lower the threshold (e.g. `0.03`) for
denser, more reactive articulation, or switch to absolute mode with a
larger `articulation_threshold_abs` for a similar sparser effect on a
different basis.

Trajectory column mapping (from `GridToTrajectory`, retained for pan
and API stability — density/speed columns are no longer consumed by
the note-based pitch/volume mapping):
- `x` (pan)   — `(left_pop − right_pop) / cols` — **not** bounded to
  [-1,1]; `SonifyCellular` rescales + clips it before use (see pitfall
  below).
- `y` (density) — `total_pop / (rows * cols)` — unused by pitch now
- `z`         — always 0.0
- `speed`     — `|Δpopulation| + 0.01` — unused by volume now (volume
  comes from each run's max |Δpop| instead)

## Animation dispatch

`AnimateCellular[grid3D, cfg, outPath, targetDuration]` branches on grid shape:
- `nRows > 1` (Life): renders frames subsampled from the `nGen` generations → animated GIF
- `nRows == 1` (Rule 110): renders full spacetime diagram as PNG + single-frame GIF

## Animation framing: GIF/WAV duration sync (fixed post-v1.5.0)

**The bug.** GIF playback duration was hardcoded independent of the
WAV it accompanies. Measured before the fix: Life variants (`chaos`,
`glider_gun`, `rpentomino_default`) rendered exactly `nGen` frames at
the config's fixed `animation.fps` (10) — always 30s regardless of
audio length — while the WAV ran `nGen * base_note_duration` (18s at
the 0.06s/generation default), a 1.667x GIF/WAV ratio. Rule 110
(`rule110`, `rule110_sparse`, `rule110_dense`) was far worse: its
spacetime-diagram branch exports the single static frame via
`ExportGIF[{spacetimePlot}, outPath, fps]` with the same `fps=10`,
which for a **one-frame** GIF means a 0.1s hold — against a ~20s WAV
(`200 gens * 0.10s`, rule110's own `base_note_duration` override), a
~200x mismatch, an order of magnitude worse than the Life case because
frame count wasn't the free variable there at all — it was pinned at 1
by design (the triangular pattern is only legible as a whole; see
"Animation dispatch" above), so the usual "hardcoded fps" framing
doesn't even apply to it.

**The fix — two different mechanisms, not one, because the two grid
shapes have fundamentally different GIF structures:**
1. **Life** — `AnimateCellular` now treats `nGen` as a render budget
   rather than a literal frame count: `frameRate = Clip[nGen /
   targetDuration, {$MinAnimationFps, $MaxAnimationFps}]` (2-30 fps,
   mirrors lorenz's `src/animate.wl`), then `actualNFrames =
   Round[frameRate * targetDuration]`, then frames are subsampled from
   the `nGen` generations via evenly-spaced indices
   (`Round[Subdivide[1, nGen, actualNFrames - 1]]`). At the default
   0.06s/generation tempo this clamp never bites (`nGen/targetDuration
   = 1/base_note_duration ≈ 16.7 fps`, comfortably inside `[2,30]`,
   so `actualNFrames == nGen` and every generation still gets its own
   frame) — the subsampling path only activates at tempo extremes
   outside that range.
2. **Rule 110** — there is no frame rate to clamp; the single spacetime
   frame's GIF delay is set directly to `targetDuration` (`frameRate =
   1.0 / Max[targetDuration, 0.1]`), so one loop cycle holds the image
   on screen for exactly as long as the WAV plays, instead of
   inheriting the Life branch's `animation.fps`, which was never
   meaningful for a one-frame export.

Both branches derive `targetDuration` the same way: `nGen *
ResolveBaseNoteDuration[cfg]`, exposed as `CellularAudioDuration[nGen,
cfg]` in `sonify.wl` so call sites (`main.wl`, `experiments.wl`) can
compute it *before* running `SonifyCellular` and pass it into
`AnimateCellular` as `targetDuration` — the same value used to size
`nSamples` in `BuildNoteAudio`, so GIF and WAV are provably the same
length rather than independently-computed values that happen to
match. `AnimateCellular` returns `{actualNFrames, frameRate}` for
`STEMDescribeGIF` reporting.

**Verification** (`gif_duration`/`wav_duration` via PIL/`wave`, summed
per-frame `DisplayDurations` vs. WAV frame count / sample rate):

| file | before (gif/wav) | after (gif/wav) |
|---|---|---|
| `life_rpentomino_animation.gif` | 30.0s / 18.0s = 1.667x | 18.0s / 18.0s = 1.000x |
| `chaos_animation.gif` | 30.0s / 18.0s = 1.667x | 18.0s / 18.0s = 1.000x |
| `glider_gun_animation.gif` | 30.0s / 18.0s = 1.667x | 18.0s / 18.0s = 1.000x |
| `rule110_animation.gif` | 0.1s / 20.0s = 0.005x (200x off) | 20.0s / 20.0s = 1.000x |
| `rule110_sparse_animation.gif` | 0.1s / 20.0s = 0.005x | 12.0s / 12.0s = 1.000x |
| `rule110_dense_animation.gif` | 0.1s / 20.0s = 0.005x | 12.0s / 12.0s = 1.000x |

(`rule110_sparse`/`rule110_dense` land on 12.0s not 20.0s because
`experiments.wl`'s literal per-experiment `cfg` Associations don't
include `simulation.cellular.rule110.base_note_duration`, so
`ResolveBaseNoteDuration` falls through to the shared 0.06s default —
pre-existing behaviour, unrelated to this fix; the sync invariant
holds regardless of which tempo actually applies.)

`life_gliderlgun_animation.gif`/`_audio.wav` (dated Jun 27, predating
the run-length-note `sonify.wl` refactor) were deliberately **not**
regenerated — no current code path writes that filename (`main.wl`
writes `life_<pattern>_*`, `experiments.wl` writes `glider_gun_*`), so
it is orphaned output from a stale pipeline, not a case this fix
needed to touch.

## Common pitfalls

- `Total[grid3D, {2, 3}]` sums over the row and column dimensions, leaving a
  `{nGen}` list of per-generation population counts. This is correct and fast
  on packed integer arrays; slow on unpacked arrays.
- `CellFrame` is a protected WL symbol — the function is named `CellularFrame`.
- Event detection in `SonifyCellular` uses fractional population change
  `(cur − prev) / prev`. Guard against `prev == 0` before dividing.
- `GridToTrajectory`'s pan column, `(left_pop − right_pop) / cols`, is **not**
  bounded to `[-1, 1]` — population counts routinely exceed the column count.
  Feeding it unclipped into a constant-power pan law
  (`Sqrt[(1 ± pan) / 2]`) drives the square root negative and silently
  produces complex samples, which unpacks the audio array and makes
  `Export[...,"WAV"]` fail with `Export::nodta` — with no other symptom
  until export time. `SonifyCellular` rescales pan via
  `Rescale[pan, MinMax[pan], panRange]` then `Clip`s it before every use
  (both note panning and event-burst panning) precisely to avoid this.
  If you add a new panning consumer, clip it too.

## Dependencies

- Mathematica or Wolfram Engine (any recent version)
- `stem-core` (sibling `../stem-core`) — `ScaleLookup`, `$StemScales`,
  `StemSynthNote`, `RenderAudio`, `ExportGIF`, `ExportCSV`, `EnsureDir`,
  `STEMSay`, `STEMDescribe*`, `GetCfg`, `DeepMerge`, `LoadConfig`.
  `SpatialLayer`/`MotionLayer`/`MixLayers` are no longer used by
  `sonify.wl` (replaced by direct per-run `StemSynthNote` synthesis)
  but remain available for other apps.
- No external paclets required

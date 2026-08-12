# AGENTS.md — Guidance for Claude Code

## Project overview

Prime number pattern visualisation and sonification in Wolfram Language. Two modes —
`ulam` (Ulam spiral prime grid) and `gaps` (prime gap rhythm) — each compute a model,
export a CSV, render a visual, and produce audio output. `ulam` uses stem-core's
`SonifyTrajectory` pipeline; `gaps` builds its PCM buffer directly.

## Project structure

- `main.wl`          — Entry point; mode branching; 4-step pipeline
- `config.json`      — App defaults (mode, ulam sub-config, gaps sub-config)
- `src/model.wl`     — `UlamCoords[n]`, `UlamModel[cfg]`, `GapsModel[cfg]`
- `src/animate.wl`   — `AnimatePrimes[model, cfg, outDir]`
                       dispatches to `AnimateUlam` or `AnimateGaps`
- `src/sonify.wl`    — `SonifyPrimes[model, cfg, outDir]`
                       dispatches to `SonifyUlam` or `SonifyGaps`
- `output/`          — All output files (not committed)

## How to run

```bash
wolframscript -file main.wl                                    # ulam 101×101 (default)
wolframscript -file main.wl -- --simulation.mode=gaps
wolframscript -file main.wl -- --simulation.ulam.size=201
wolframscript -file main.wl -- --simulation.gaps.count=10000
wolframscript -file main.wl -- --config-dump
afplay output/ulam_audio.wav
afplay output/gaps_audio.wav
afplay output/gaps_slow.wav
```

CLI override format: `--key=value` (with `=`). Space-separated `--key value`
is also accepted — main.wl pre-processes args before passing to `LoadConfig`.

## Data flow

```
config → UlamModel / GapsModel
           ↓
         model Association  (keys depend on mode — see below)
           ↙              ↘
  AnimatePrimes          SonifyPrimes
  ulam: PNG+GIF+zoom       ulam: SonifyTrajectory → ulam_audio.wav
  gaps: animated GIF       gaps: direct PCM  → gaps_audio.wav
           ↓                                 → gaps_slow.wav
         CSV
```

## Model Association shapes

### UlamModel

| Key | Type | Description |
|-----|------|-------------|
| `"grid"` | `{n, n}` integer matrix | 1 = prime, 0 = composite |
| `"size"` | Integer | Grid side length (always odd) |
| `"prime_count"` | Integer | Number of primes in the grid |
| `"prime_density"` | Real | `prime_count / n²` |
| `"coords"` | length-`n²` list of `{row,col}` | `coords[[k]]` = position of integer k |
| `"mode"` | `"ulam"` | |

### GapsModel

| Key | Type | Description |
|-----|------|-------------|
| `"primes"` | length-`count` integer list | First `count` primes |
| `"gaps"` | length-`count−1` integer list | `Differences[primes]` |
| `"mean_gap"` | Real | `Mean[gaps]` |
| `"max_gap"` | Integer | `Max[gaps]` |
| `"twin_prime_count"` | Integer | Number of gaps equal to 2 |
| `"gap_distribution"` | Association | `gap_value → frequency` |
| `"mode"` | `"gaps"` | |

## UlamCoords algorithm

Generates the spiral by walking the grid with mutable state:

```wolfram
dirs = {{0,1},{-1,0},{0,-1},{1,0}}  (* right, up, left, down *)
start at Ceiling[n/2], Ceiling[n/2]
d=1, segLen=1, segsAtLen=0, stepsDone=0

Do[
  move one step in dirs[[d]];
  Sow[{row, col}];
  stepsDone++;
  If[stepsDone === segLen,
    stepsDone = 0; d = Mod[d,4]+1; segsAtLen++;
    If[segsAtLen === 2, segsAtLen = 0; segLen++]
  ],
  {n²−1}
]
```

After this loop `coords[[k]]` gives the `{row,col}` of integer k. The layout for
n=5 is:

```
17 16 15 14 13
18  5  4  3 12
19  6  1  2 11
20  7  8  9 10
21 22 23 24 25
```

## Ulam sonification (SonifyUlam)

Row-by-row scan; each of the n rows produces one trajectory point:

| Trajectory column | Quantity | Audio dimension |
|-------------------|----------|----------------|
| `x` | right − left prime density asymmetry, clipped to [−1, +1] | stereo pan |
| `y` | row prime density | pitch |
| `z` | 0 | unused |
| `speed` | \|row-to-row density change\| (prepend 0 for row 1) | volume |

Time axis is rescaled to [0, 10.0] seconds regardless of grid size. The duration
override is injected via `DeepMerge` before `SonifyTrajectory` is called.

## Gaps sonification (SonifyGaps)

Bypasses `SonifyTrajectory`. Builds PCM directly:

**Attack time** for prime pₙ:

    attackTimes = (primes − First[primes]) * timeUnit
    timeUnit    = baseDuration / (Last[primes] − First[primes])
    baseDuration = 30.0 * 120.0 / tempo_bpm   (* 30 s at default 120 bpm *)

All relative gap ratios are preserved exactly. **Slow version**: `slowDuration = 4 × baseDuration`.

**Tone generation** for each prime i:

    audio[[start ;; start+len−1]] +=
      0.3 * Table[Sin[2π freq k / sr] * Exp[−5 k / toneSamples], {k, 0, len−1}]

where `start = Round[attackTimes[[i]] * sr] + 1` and `len = Min[toneSamples, nBase − start + 1]`.

Buffer is peak-normalised to 0.95 via `NormalizeBuffer` before export.

## GIF/WAV duration sync — `gaps_animation.gif` (fixed post-v1.5.0)

**The bug.** Like nearly every other app in this repo, `AnimateGaps`
built `gaps_animation.gif` from a frame count and frame rate that had
nothing to do with `gaps_audio.wav`'s actual length. Frame count came
from `step = Max[50, Ceiling[nGaps/50]]` (a data-driven cap on how many
progressive-reveal snapshots to render), and playback rate was the fixed
`animation.fps` config value (12). **Measured** on the untouched repo
before any fix (default config, count=5000, tempo_bpm=120):
`gaps_animation.gif` played for **4.000 s** (50 frames @ 12 fps, via
Python `PIL`/`wave` duration measurement) while `gaps_audio.wav` played
for **30.080 s** — a **7.52x** mismatch. Applying that same old formula
(verified against the measured default above) to the other `gaps_*`
presets in `experiments.wl`: `first_thousand` (count=1000) → 20 old
frames / 12 fps = 1.67 s vs. a 30.08 s WAV, an **18.0x** mismatch;
`ten_thousand` (count=10000) → 50 old frames / 12 fps = 4.17 s vs.
30.08 s, **7.2x**; `twin_primes` (tempo_bpm=60, doubling audio to
60.08 s) → 50 old frames / 12 fps = 4.17 s vs. 60.08 s, **14.4x**. None
of these ratios have anything to do with each other or with
`count`/`tempo_bpm`, because frame count and audio duration were computed
from entirely unrelated formulas.

**Root cause.** `SonifyGaps`'s duration (`baseDuration = 30.0 * 120.0 /
tempo_bpm`) depends only on `tempo_bpm`, never on `nGaps`/`count`. But
`AnimateGaps`'s old frame count depended only on `nGaps` (via `step`),
and its frame rate was a flat config constant — neither term in the GIF
side of the equation referenced `tempo_bpm` or `baseDuration` at all.

**The fix**, in `AnimateGaps` (`src/animate.wl`): compute the *same*
`targetDuration = 30.0 * 120.0 / tempo_bpm` that `SonifyGaps` uses (same
config key, same formula — this is gaps' equivalent of lorenz's
`solution[[-1,1]]` duration basis, adapted to an index-scan model that
has no time-ODE). `$GapsFrameBudget` (50) is now a *render budget*, not
a literal frame count: `frameRate = Clip[$GapsFrameBudget/targetDuration,
{$MinAnimationFps, $MaxAnimationFps}]` (fps clamped to [2, 30], mirroring
`lorenz/src/animate.wl`'s `ExportAnimation`), then the actual frame count
is solved backward from the clamped rate — `Max[2, Round[frameRate *
targetDuration]]`, capped at `nGaps` — so total playback time equals
`targetDuration` (not just approximately close to it). Frame endpoints
are then spread evenly across the gap sequence via `Subdivide[1, nGaps,
actualNFrames-1]` instead of the old fixed `step`, preserving the
progressive-reveal effect. No call-site changes were needed in `main.wl`
or `experiments.wl` — both already pass the same `cfg` to `AnimatePrimes`
and `SonifyPrimes`, and `tempo_bpm` is read independently by each, so the
two stay in lockstep automatically for every mode/preset.

**Verified by regenerating and re-measuring** (`wolframscript -file
main.wl -- --simulation.mode=gaps` and `wolframscript -file
experiments.wl`, then the same Python `PIL`/`wave` measurement used for
the "before" numbers above): at the default config, `frameRate` solves
to 50/30=1.67 fps, clamped up to the 2 fps floor — console reported
"Building 60 animation frames at 2 fps (30s, matching audio duration
30.s)", and the regenerated file measured **exactly 30.000 s** (60
frames), against `gaps_audio.wav`'s **30.080 s** — ratio **1.0027x**
(down from the measured 7.52x). At `tempo_bpm=60` (the `twin_primes`
preset via `experiments.wl`, `targetDuration=60.0`, `toneDurMs=120`):
120 frames at 2 fps, GIF measured **exactly 60.000 s** against
`gaps_audio.wav`'s **60.120 s** — ratio **1.002x** (down from the
computed 14.4x for that preset). `first_thousand` and `ten_thousand`
both hit the identical 60-frames-@-2fps-=30.000s result (console-
confirmed; `targetDuration` depends only on `tempo_bpm`, which is 120
for both, matching the default). The residual ~0.08–0.12 s in every
case is the per-tone release tail (`toneDurMs`, 80 ms default / 120 ms
for `twin_primes`) trailing the nominal `baseDuration` in the WAV
buffer — the same kind of small envelope-tail slack lorenz's WAVs have
past `solution[[-1,1]]`, not a residual sync bug.

`tests/test_model.wl` (17 tests, covers `model.wl` only — no existing
coverage of `animate.wl`) re-run after the fix: **17 passed, 0 failed**,
confirming no regression.

**Not fixed, and why: `ulam_spiral.gif`.** `ulam_spiral.gif` is a
genuine outlier, not the same bug. It's a deliberate **single-frame**
GIF ("pipeline consistency" per the existing code comment) built from
`ExportGIF[{primePlot}, gifPath, fps]` with `AnimationRepetitions ->
Infinity` (stem-core's `ExportGIF`) — every loop redraws the *same*
frame, so its per-loop delay (`1/fps`) is visually meaningless; a viewer
sees an unchanging static image no matter what `fps` or "duration" the
file metadata reports. Measured: 0.08 s (1 frame @ 12 fps) vs.
`ulam_audio.wav`'s 10.0 s — a huge ratio by the raw-duration metric, but
stretching a single repeated frame's nominal delay to 10 s would not
change anything a viewer perceives, and building a real animated
row-by-row reveal (to genuinely pair with `SonifyUlam`'s row scan) is a
much larger content change than a timing fix — deliberately left alone
here as out of scope for a sync-only fix.

## Output naming

| Mode | Files |
|------|-------|
| `ulam` | `ulam_spiral.png`, `ulam_spiral.gif`, `ulam_centre_zoom.png`, `ulam_spiral.csv`, `ulam_audio.wav` |
| `gaps` | `gaps_animation.gif`, `gaps_stats.csv`, `gaps_audio.wav`, `gaps_slow.wav` |

The final `STEMSay` in main.wl uses `mode <> "_audio.wav"` — valid for both modes.

## Common pitfalls

- **Grid size must be odd.** `UlamModel` silently adds 1 to even sizes. If a user
  passes an even size and expects a specific cell count, the result may be
  unexpected. The warning is printed to stdout and spoken via `STEMSay`.
- **`UlamCoords` uses 1-based row/col indices.** `grid[[row, col]]` in WL is
  1-indexed. `coords[[k]]` directly gives the correct `{row, col}` for Part access.
- **`Reap/Sow` result shape.** `Reap[...][[2,1]]` extracts the sown list:
  `Reap[...]` returns `{lastValue, {sownList}}`, so `[[2]]` is `{sownList}` and
  `[[1]]` unwraps it.
- **`Total[grid, {2}]`** sums along columns (returns a length-n list of row sums).
  `Total[grid, 2]` sums all elements (returns a scalar). These are not the same.
- **`Differences[primes]`** returns a list of length `count−1`, not `count`. The
  CSV loop runs from `i=1` to `Length[gaps]` (= count−1), pairing `primes[[i]]`
  with `primes[[i+1]]`. Do not index beyond `Length[gaps]`.
- **Large `gaps_slow.wav`**: at count=5000 with tempo=120, the slow WAV is 120 s
  at 44100 Hz ≈ 21M samples ≈ 10 MB. The Do loop over 5000 tones runs twice (base
  + slow). This is expected; do not optimise away the second loop.
- **`AnimateGaps` frame count is duration-driven, not a fixed cap.** `$GapsFrameBudget`
  (50) is a render-budget target, not a literal frame count — see "GIF/WAV
  duration sync" below. For the default config (count=5000, tempo_bpm=120) this
  currently resolves to 60 frames at 2 fps (`$MinAnimationFps` floor), not 50.
- **`ExportGIF` for single-frame Ulam**: `ExportGIF[{primePlot}, gifPath, fps]`
  wraps the single frame in a list. Do not pass the Graphics object directly.

## Dependencies

- Mathematica or Wolfram Engine (any recent version with `PrimeQ`, `Prime`, `Counts`)
- `stem-core` (sibling `../stem-core`) — `SonifyTrajectory`, `ExportGIF`,
  `ExportCSV`, `ExportAudioBuffer`, `NormalizeBuffer`, `EnsureDir`,
  `STEMHeading`, `STEMDescribeCSV`, `STEMDescribeWAV`, `STEMDescribeGIF`,
  `STEMSay`, `FmtN`, `GetCfg`, `DeepMerge`, `LoadConfig`
- No external paclets required

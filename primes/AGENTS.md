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
- **`AnimateGaps` step size**: capped at `Ceiling[nGaps/50]` to keep frame count
  ≤ 50. For the default 4999 gaps the step is 100, not 50 — consistent with the
  "50 frames" output shown in console and `STEMDescribeGIF`.
- **`ExportGIF` for single-frame Ulam**: `ExportGIF[{primePlot}, gifPath, fps]`
  wraps the single frame in a list. Do not pass the Graphics object directly.

## Dependencies

- Mathematica or Wolfram Engine (any recent version with `PrimeQ`, `Prime`, `Counts`)
- `stem-core` (sibling `../stem-core`) — `SonifyTrajectory`, `ExportGIF`,
  `ExportCSV`, `ExportAudioBuffer`, `NormalizeBuffer`, `EnsureDir`,
  `STEMHeading`, `STEMDescribeCSV`, `STEMDescribeWAV`, `STEMDescribeGIF`,
  `STEMSay`, `FmtN`, `GetCfg`, `DeepMerge`, `LoadConfig`
- No external paclets required

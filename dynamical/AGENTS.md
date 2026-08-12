# Dynamical Systems — Agent Guide

## Project overview

Sonifies the logistic map (x_{n+1} = r x_n (1-x_n)) and its
period-doubling route to chaos. First mode of a `dynamical/` app that
may receive additional modes (Hénon map, circle map, etc.) in future
sessions — keep `model.wl`/`sonify.wl`/`animate.wl` organised so a
second map type can be added as parallel functions rather than requiring
a rewrite.

| Mode | r | Time axis | Output |
|------|---|-----------|--------|
| `sweep` | swept r_start -> r_end | r-step index (attractor recorded at each r) | Stereo WAV; progressive bifurcation-diagram GIF |
| `iterate` | fixed (or named preset) | iteration index n | Stereo WAV; x_n vs n time-series GIF |

## Key design decisions (read before modifying sonify.wl)

### 1. Discrete notes, not stem-core's continuous SonifyTrajectory

The original spec for this app called for using stem-core's
`SonifyTrajectory` pipeline (the same continuous, phase-accumulated
carrier used by `lorenz`/`pendulum`), mapping the logistic map onto the
`{t, x, y, z, speed}` column format. **This app does not do that** —
`sonify.wl` instead uses discrete per-point note bursts (`StemSynthNote`
placed at precise attack times, mixed additively into pre-allocated
stereo buffers via in-place `Part`-assignment), the same
"event-driven note triggering" pattern as `primes/src/sonify.wl`'s
`SonifyGaps`.

**Why the deviation:** the entire point of this app is that
period-doubling must be *audibly countable* as a rhythm — "period-4
sounds like a four-note cycle" is not a nice-to-have, it is an explicit,
testable verification requirement ("confirm the rhythmic character of
each preset is clearly distinguishable"). `SonifyTrajectory`'s carrier
is `Sin[2 Pi * Accumulate[pitch] / sr]` with spline-interpolated
pitch/pan/volume over the *whole* configured duration — consecutive
attractor values would blend into a continuous glide/vibrato, not
crisp, separately countable notes. A continuous carrier could very
plausibly fail the "distinguishable rhythmic character" requirement
outright. Pitch mapping still reuses stem-core's `ScaleLookup`/
`SemitoneToHz` (the same scale-lookup utilities lorenz and pendulum
use), so the *pitch mapping convention* is shared even though the
*event-triggering architecture* follows primes' pattern instead.

If you are asked to make this app's audio "more like the other chaos
apps" (continuous, vibrato-like), that request is in tension with the
rhythm-distinguishability requirement — flag it rather than silently
picking one.

### 2. x0 = 0.5 is degenerate at r = 4 — SafeX0 nudges it

x0 = 0.5 is an *exact* pre-periodic point of the logistic map at r = 4:
sin²(π/4) = 0.5, and x_n = sin²(2ⁿ π/4) for n ≥ 2 is exactly 0 (2ⁿ/4 is
an integer). A trajectory started at x0 = 0.5 with r = 4 is therefore
not chaotic at all — it lands on the repelling fixed point 0 after
exactly two steps and stays there. This is a real mathematical fact
about the map (verified: at r=4, x0=0.5 collapses; the collapse is
present regardless of floating-point precision used, though the exact
step it locks in at can shift slightly with precision). Since r=4 is
literally the `chaos` preset and the config default `x0` is 0.5, this
would otherwise silently break the flagship "chaos" listening
experience.

`SafeX0[x0]` in `model.wl` nudges x0 by 1e-6 when it is within 1e-6 of
0.5. **The epsilon must be at least ~1e-6, not smaller** — verified
empirically that 1e-9 still collapses (eps² underflows relative to the
0.25 scale involved in the map on the very first iteration, landing
right back on the exact same degenerate orbit this nudge exists to
avoid). If you ever need to change this epsilon, re-verify against
`LyapunovCheck[]` — it will silently fail (return a lambda roughly 2x
too high, from averaging in the collapsed trajectory's finite tail)
if the nudge stops working.

### 3. `period3_window` preset uses r = 3.830, not the textbook 3.8284

r = 3.8284 is the tangent-bifurcation *opening edge* of the period-3
window, where convergence to the 3-cycle is pathologically slow
("intermittency" — a well-known phenomenon at tangent bifurcations).
Verified numerically: at 300 iterations from x0=0.5, r=3.8284 has not
converged at all (still looks chaotic); r=3.830, just 0.0016 further
into the window's interior, converges to machine precision by around
iteration 270. Using the literal textbook value would make the
`period3_window` preset — one of the five presets the recommended
listening sequence depends on — sound chaotic instead of periodic. See
`LISTENING_GUIDE.md`'s note on this for the user-facing explanation.

### 4. Sweep mode only sonifies 8 of each r-step's recorded attractor points

`$sweepNotesPerStep = 8` in `sonify.wl`. All `n_attractor` recorded
points at a given r-step are already post-transient (equally valid
attractor points), so sonifying a small fixed subset per step is lossless
for audible periodicity while keeping total sweep duration bounded
(`r_steps * $sweepNotesPerStep * note_duration`, ~5.3 minutes at
defaults) — using all 100 default `n_attractor` points at 500 default
`r_steps` would produce a ~66-minute file. This constant is intentionally
not exposed via config (the config surface matches the spec's exact
`config.json` block); if it needs to be tunable later, add
`notes_per_step` under `simulation.dynamical` and thread it through
`SonifySweep`.

## Project structure

```
dynamical/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json            — default simulation parameters
  experiments.wl          — 9 curated preset invocations (RunExperiment)
  LISTENING_GUIDE.md       — user-facing recommended listening sequence
  AGENTS.md                — this file
  src/
    model.wl              — LogisticMap, SafeX0, $dynamicalPresets, PresetR/PresetDescription,
                            IterateTrajectory, AttractorPoints, BifurcationPoint,
                            FeigenbaumCheck, FixedPointCheck, Period2Check,
                            LyapunovExponent/LyapunovCheck, SweepEventRValues,
                            SweepModel, IterateModelData
    sonify.wl               — PitchScale3Octaves, SynthesizeDiscreteNotes, OverlayEvent,
                            SonifySweep, SonifyIterate ($sweepNotesPerStep constant)
    speech.wl                — ResampleLinear, DynamicalSpeakToBufferPlatform, BuildIntroBuffer,
                            BuildSweepIntroText, BuildIterateIntroText
    animate.wl                — RenderSweepFrame/AnimateSweepBifurcation,
                            RenderIterateFrame/AnimateIterateTimeSeries
    output.wl                  — PitchPanVolume, ExportSweepCSV, ExportIterateCSV,
                            PrintCorrectnessChecks, PrintSweepSummary, PrintIterateSummary
  tests/
    test_model.wl            — unit tests (fixed point, period-2, Feigenbaum, Lyapunov, presets)
  output/                     — generated files (gitignored)
```

## How to run

```sh
wolframscript -file dynamical/main.wl                                              # sweep, defaults
wolframscript -file dynamical/main.wl -- --simulation.mode=iterate                  # iterate at r=3.8
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=fixed_point
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=period2
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=period4
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=period3_window
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=chaos
wolframscript -file dynamical/main.wl -- --simulation.dynamical.r=3.83
wolframscript -file dynamical/main.wl -- --simulation.dynamical.r_steps=1000
wolframscript -file dynamical/main.wl -- --simulation.dynamical.note_duration=0.04

wolframscript -file dynamical/tests/test_model.wl
wolframscript -file dynamical/experiments.wl
```

## Data flow

```
config.json + CLI args
        |
   LoadConfig (stem-core)
        |
   [correctness checks: FeigenbaumCheck, FixedPointCheck,
    Period2Check, LyapunovCheck — always run, printed PASS/FAIL]
        |
   sweep mode:                          iterate mode:
     SweepModel                           PresetR + IterateModelData
        |                                    |
     SonifySweep -> {leftBuf,rightBuf,...}  SonifyIterate -> {leftBuf,rightBuf,...}
        |                                    |
   BuildSweepIntroText/BuildIntroBuffer    BuildIterateIntroText/BuildIntroBuffer
        |                                    |
   Join[intro, pause, channel] per channel, single final WAV export (main.wl)
        |                                    |
   AnimateSweepBifurcation -> GIF          AnimateIterateTimeSeries -> GIF
   ExportSweepCSV -> CSV                   ExportIterateCSV -> CSV
```

`SonifySweep`/`SonifyIterate` return buffers, not exported files — same
pattern as the images/ enhancement, so main.wl can prepend the spoken
intro before a single final export and the reported `STEMDescribeWAV`
duration includes the intro.

## Model/result Association shapes

`SweepModel[rStart, rEnd, rSteps, x0, nTransient, nAttractor]` returns:

| Key | Type | Description |
|-----|------|--------------|
| `"rValues"` | List[Real] | The `rSteps` sampled r values, ascending |
| `"attractors"` | List[List[Real]] | `attractors[[k]]` = the `nAttractor` recorded points at `rValues[[k]]` |

`SonifySweep[...]` returns (in addition to `leftBuf`/`rightBuf`/`nSamples`):

| Key | Description |
|-----|--------------|
| `"xVals"`, `"times"`, `"speeds"` | Parallel per-note arrays (flattened across all r-steps) |
| `"rVals"`, `"iterIdx"` | The r-value and local iteration index each note came from (for CSV) |
| `"eventRs"` | `<\|"first_bifurcation"->.., "chaos_onset"->.., "period3_window"->..\|>` |
| `"eventStepIndices"` | Which r-step index each *in-range* event landed on (used for CSV `event_label`; an event outside `[r_start, r_end]` is simply absent from this Association — see pitfall 3 below) |

`IterateModelData[r, x0, nIterations, preset]` returns `"r"`, `"x0"`,
`"nIterations"`, `"preset"`, `"trajectory"` (length `nIterations + 1`,
including x0).

## Common pitfalls

1. **`_?test : default` in function signatures is broken syntax** —
   `gamma_?NumericQ : 1.0` parses as `gamma_?(NumericQ : 1.0)`, a
   pattern that never matches, so the whole function silently fails to
   evaluate on *every* call (no error — just an unevaluated expression
   comes back). Always use `Optional[gamma_?NumericQ, 1.0]` instead.
   This bit the Feigenbaum root-finder during development (see images/
   AGENTS.md for the original occurrence) — every function in this app
   with an optional constrained argument uses the explicit `Optional[]`
   form for this reason.

2. **Don't sonify all of `n_attractor` per r-step in sweep mode** — see
   design decision 4 above. If you change `$sweepNotesPerStep`, recompute
   the expected default sweep duration and update README's "Performance
   notes" table.

3. **Events outside the sweep's r range must not fire** — `SonifySweep`
   checks `eventR >= First[rValues] && eventR <= Last[rValues]` before
   placing an accent tone or adding to `eventStepIndices`. Without this
   guard, `Nearest[rValues -> "Index", eventR]` happily snaps to
   whichever boundary is closest and fires an event for an r-value the
   sweep never actually reached (caught via the `sweep_cascade_zoom`
   experiment, which restricts r to [2.9, 3.6] — outside the period-3
   window's r ≈ 3.83).

4. **CSV `event_label` empty cells import as `Missing["NotAvailable"]`**
   — this is `Import`'s standard behaviour for empty quoted CSV fields,
   not an export bug. The raw exported file correctly contains `""` for
   unlabelled rows; verify with a text-level read (`grep`/`head`) rather
   than round-tripping through `Import` if this looks wrong during
   debugging.

5. **`FmtN` on an exact `Rational`** (e.g. `Period2Check[]["sum"]`,
   which can come back as an exact fraction like `21/16`) can produce
   unexpected `NumberForm` output. Wrap in `N[...]` before passing to
   `FmtN` when the value might be exact.

## Animation framing: GIF/WAV duration mismatch (fixed post-v1.5.0)

**The bug.** `AnimateSweepBifurcation`/`AnimateIterateTimeSeries` in
`src/animate.wl` built a fixed-size batch of frames (default `nFrames
= 60`, hardcoded `ExportGIF[frames, outGIF, 12]` — 12 fps) with no
reference to the WAV's actual duration. The WAV's length is driven
entirely by the sonification's own event timing — `nSteps *
$sweepNotesPerStep * noteDuration` for sweep mode, `n * noteDuration`
for iterate mode, both plus the spoken intro and pause — which has
nothing to do with 60 frames at 12 fps (a fixed 5.0s of GIF playback
before quantization). Measured on the pre-fix `dynamical/output/`
files: `iterate.gif` played 4.8s against a 36.45s WAV (7.6x too fast),
and `sweep.gif` played 4.8s against a 120.11s WAV (25.0x too fast) —
in both cases the GIF finished its loop and restarted many times over
before the audio was even a fraction done.

**Root cause.** Same pattern as lorenz/pendulum/rossler: frame count
and frame rate were literal constants disconnected from the
sonification's true length, rather than derived from it.

**The fix.** `AnimateSweepBifurcation` and `AnimateIterateTimeSeries`
now take a required `targetDuration_?NumericQ` argument — callers pass
`totalDurSec` (the same WAV-length value already computed and passed
to `STEMDescribeWAV` right before the animation call, so no new state
is needed). `nFrames` (default 150) is reinterpreted as a *render
budget*, not a literal count: `frameRate = Clip[nFrames /
targetDuration, {$MinAnimationFps, $MaxAnimationFps}]` with
`$MinAnimationFps = 2` and `$MaxAnimationFps = 30`, then
`actualNFrames = Max[2, Round[frameRate * targetDuration]]` is what
actually gets rendered. The clamp keeps a short iterate run (~30-40s)
from demanding a strobing frame rate and a long sweep (300s+) from
demanding an implausibly slow one; frame count is what flexes at the
clamp boundary, so playback duration always lands on `targetDuration`
exactly (modulo GIF's 1/100s `DisplayDurations` quantization). Both
functions return `{actualNFrames, frameRate}` for `STEMDescribeGIF`.
`main.wl` and `experiments.wl` were updated to pass `totalDurSec` and
capture/report the returned pair instead of the old hardcoded `60, 12`.

**Verification.** Re-rendered default sweep and iterate outputs plus
6 experiment presets and compared GIF vs. WAV duration with a Python
`PIL`/`wave` script:

| file | before (gif / wav / ratio) | after (gif / wav / ratio) |
|---|---|---|
| `sweep.gif` | 4.8s / 120.11s / 25.0x | 344.0s / 344.11s / 1.0003x |
| `iterate.gif` | 4.8s / 36.45s / 7.6x | 33.0s / 32.55s / 0.986x |
| `sweep_full.gif` | n/a (new) | 99.0s / 98.86s / 0.999x |
| `sweep_cascade_zoom.gif` | n/a (new) | 81.5s / 81.58s / 1.001x |
| `iterate_fixed_point.gif` | n/a (new) | 36.0s / 35.77s / 0.994x |
| `iterate_deep_chaos.gif` | n/a (new) | 33.0s / 32.53s / 0.986x |

All post-fix ratios sit within ~1.5% of 1.0, the residual being GIF's
inherent centisecond duration quantization, not a code error.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSection`, `STEMSay`, `STEMPrintN`,
  `STEMDescribeWAV`, `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`,
  `STEMPlayCmd`, `ScaleLookup`, `SemitoneToHz`, `StemSynthNote`,
  `NormalizeBuffer`, `ExportAudioBuffer`, `ExportGIF`, `ExportCSV`,
  `EnsureDir`. Deliberately **not** used: `SonifyTrajectory`,
  `SpatialLayer`, `MotionLayer`, `EventLayer`, `MixLayers`,
  `RenderAudio` — see design decision 1.
- **Mathematica/WL**: `FindRoot`, `D` (symbolic, for the Feigenbaum
  root-finder's stability condition), `NestList`/`Nest`, `Sound`,
  `SampledSoundList`, `Graphics`, `Point`, `Line`, `Export`,
  `SpeechSynthesize`, `AudioQ`, `AudioData`, `AudioSampleRate`,
  `RunProcess` (platform TTS fallback), `Import` (reading TTS-generated
  WAV files).

## Speech synthesis note

`speech.wl`'s three-tier fallback (`SpeechSynthesize[]` -> platform TTS
-> text-only `STEMSay`) duplicates the pattern in
`images/src/speech.wl`, which itself duplicates logic from
`signal/src/sonify.wl`'s `SpeakToBuffer`. `SpeechSynthesize[]` was
observed to return `$Failed` in this development environment — the
platform-native TTS tier (macOS `say`/`afconvert`) is what actually
produces audio in practice. This is now the third independent copy of
this pattern across the codebase; a good candidate for stem-core
consolidation in a future pass (explicitly out of scope here per this
app's build spec, which excludes stem-core changes).

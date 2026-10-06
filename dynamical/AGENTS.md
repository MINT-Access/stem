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
| `sweep` | swept r_start -> r_end | r-step index (attractor recorded at each r) | Stereo WAV (intro + notes + outro); progressive bifurcation-diagram GIF |
| `iterate` | fixed (or named preset) | iteration index n | Stereo WAV (intro + notes + outro); x_n vs n time-series GIF |
| `lyapunov` | swept r_min -> r_max | seconds, r linear in time | Stereo WAV (λ tone vs. λ = 0 reference, markers, intro + outro); two-panel bifurcation / λ(r) GIF with cursor |
| `divergence` | fixed (or preset) | iteration index n | Stereo WAV (orbit x0 hard left, orbit x0 + δ hard right, separation tone centre, intro + outro); two-panel orbits / log10 separation GIF with cursor |

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

### 5. Lyapunov mode is a continuous glide — the one deliberate exception to decision 1

`lyapunov` mode sonifies one scalar per r, λ(r), and its most important
event — λ crossing zero, the boundary between order and chaos — is
heard as *beating* between the λ tone and a steady reference tone at
λ = 0. Beating needs two sustained tones a few hertz apart, which
discrete note bursts cannot produce, so this mode uses a phase-
accumulated continuous tone (λ linearly interpolated between steps,
`Accumulate` of the per-sample frequency) instead of decision 1's
discrete notes. Nothing in it needs to be rhythmically countable, so
decision 1's rationale does not apply. It still does not use
`SonifyTrajectory`: the reference tone, the harmonics and the
equal-loudness gain are all specific to this mode.

The design was chosen by listening: `prototype_lyapunov.wl` (kept in the
repository as a record, not part of the app) rendered three variants
over r 3.40–3.90 — A: λ sine + reference sine; B: λ tone with 2nd/3rd
harmonics (0.25, 0.12) so it is distinguishable from the pure reference
when they meet; C: reference faded in only near λ = 0. **B was chosen.**
The `lyapunov_window` preset reproduces the prototype's range, steps
and duration for direct comparison; the mode itself averages longer
(1000 + 10000 iterations vs. the prototype's 500 + 2000) and floors at
−0.5 instead of −1 — see decision 6.

### 6. The λ floor is −0.5 because of the λ tone's harmonics — do not lower it casually

The λ tone's harmonic k sits at k · reference · 2^(λ · octaves_per_unit).
At λ · octaves_per_unit = −1 the 2nd harmonic lands exactly on the
reference (220 Hz) and beats with it — a *false unison* that sounds
exactly like a zero crossing. The prototype's floor of −1 allowed this.
With floor −0.5 and 1 octave per unit, the 2nd harmonic never comes
closer than a tritone (6 semitones) above the reference, the 3rd
harmonic 13 semitones. `LyapunovHarmonicClearance` (sonify.wl) computes
this, and `tests/test_model.wl` reads `floor` and `octaves_per_unit`
from `config.json` and fails if any harmonic can come within one
semitone of the reference. If you change either key, run the tests.

Consequences of the floor to remember:
- Check 5 (`LyapunovCurveCheck`) computes λ with a floor of −100, not
  −0.5: the period-2 value at r = 3.2 is −0.916 (below the floor), and
  at r = 3.835 a floored value would be negative whatever the orbit did,
  so "λ < 0" would be vacuous.
- λ is truly −∞ at superstable parameters (x = 0.5 on the cycle); a
  finite average there plunges arbitrarily low (the lowest grid value in
  3.40–3.90 is −2.16 at r ≈ 3.832). The floor also keeps the λ tone's
  pitch range bounded there.
- `Log[0.]` is `Indeterminate` in machine arithmetic, not `-Infinity`, so
  `LyapunovExponent` clamps |f′| at `$MinMachineNumber` before the `Log`.

### 7. Lyapunov-mode loudness, markers and GIF timing

- **Equal-loudness compensation uses A-weighting (IEC 61672-1)**, the
  closed-form approximation to the inverse 40-phon ISO 226 contour.
  `LyapunovLoudnessGain` weights each of the three partials at its own
  frequency, root-sum-squares them, and divides the value at the
  reference frequency by the value at the current fundamental, so the
  gain is exactly 1 at λ = 0 (λ tone and reference then match in level,
  which makes beating deepest). Range at the defaults: +3.3 dB at the
  floor (156 Hz), −3.9 dB at λ = log 2 (356 Hz). At listening levels well
  above 40 phon A-weighting slightly over-boosts the low end; ISO 226 at
  a stated phon level would be the refinement if that is ever audible.
- **Markers**: the sweep mode's three accents (660/440/528 Hz) plus a
  period-4 marker at r = 3.449, 880 Hz, 80 ms. 440 : 528 : 660 : 880 =
  1 : 6/5 : 3/2 : 2, a just A minor triad with its octave, so the new
  marker is from the same family; it takes the other period-doubling
  marker's 80 ms. Markers only fire inside [r_min, r_max] (pitfall 3).
- **GIF covers the whole WAV** (intro + sweep + outro), not just the
  sweep: the cursor waits at r_min during the intro and rests at r_max
  during the outro, so GIF and WAV can simply start together (e.g. in
  tools/make_presentation_video.wl). `SyncWAVToGIF` is therefore called
  without `IntroSeconds`/`OutroSeconds`. Frame i shows the r heard at
  the middle of its display interval.
- **Rendering**: both panels are static, so they are drawn and
  rasterised once at 144 dpi (the 2x pixel size `Export` gives this
  app's other GIFs, 1440 × 1200 here) with fixed `ImageSize`,
  `ImagePadding` and `AspectRatio -> Full`; each frame is that image
  plus the cursor and text in the same coordinates. Without
  `AspectRatio -> Full` the plot area follows the plot range's aspect
  ratio and the panels come out narrow, breaking the r-to-column
  mapping.
- **Zero crossings** are located by linear interpolation between grid
  points (`LyapunovZeroCrossings`), the same interpolation the audio
  uses, so the printed time is when the crossing is heard. Crossings in
  the chaotic region come in close down/up pairs at each periodic
  window; a pair at r ≈ 3.786 in the prototype's shorter-average data
  disappears with the mode's longer averaging (λ there is +0.029, the
  2000-iterate estimate was −0.0004).

### 8. Divergence mode: two orbits, one separation tone

`divergence` shows what λ *means*: two orbits at the same r, started at
x0 and x0 + δ (defaults 0.3 and 1e-6), separate or converge as
δ e^(λ n) until the separation saturates. `DivergenceFit` fits a line to
Log[separation] vs. n up to the first n above `saturation` (0.1), and the
prediction comes from `LyapunovExponent` (1000 + 10000 iterations, no
floor), so the mode checks lambda mode's numbers against a direct
experiment. Things to know before changing it:

- **Voices 1 and 2 are iterate mode's note mapping with two deliberate
  changes**, both needed for the stereo image to be exactly centred while
  the orbits agree: the volume's normalising max step is *shared* by both
  orbits (per-orbit maxima would give identical notes different
  volumes), and the volume is *quantised to 16 levels* like the pitch's 16
  scale degrees. With iterate mode's continuous volume the two voices
  differ by ~1e-6 from the first note, which flips 16-bit rounding in some
  samples, so the left and right channels would never be sample-identical.
  `SynthesizeDiscreteNotes` itself is untouched (sweep/iterate unchanged).
- **The mapping's audible resolution is one quantisation step**: 1/15 of
  the x range in pitch and 1/15 of the shared max step in volume
  (`DivergenceNoteMapping["resolution"]` is the smaller, in x units).
  Separations above it always change the note; smaller ones change it
  only when the two values sit on either side of a rounding boundary
  (chance about separation/bin per note). Measured at r = 4: channels
  sample-identical for iterations 0–14, first difference at iteration 15
  (separation 0.026, 0.4 bins: x 0.1770 vs. y 0.1505 straddle the pitch
  boundary at 0.1667), one iteration before the separation reaches the
  resolution (n = 16). At r = 3.57, 3.2 and 2.8 the channels are
  identical for the whole file.
- **Voice 3** is continuous and centred, odd harmonics only (1, 0.2 at
  3f, 0.08 at 5f), pitch linear in Log10[separation]: δ -> 220 Hz,
  1 -> 880 Hz, so growth at rate λ is a steady rise of
  2 λ / (Ln[10] · −Log10[δ]) octaves per iteration. Separations below
  `$divergenceSeparationFloor` (1e-12) hold at the bottom (55 Hz for
  δ = 1e-6). Converging orbits really reach separation 0.0 (same double)
  — at iteration 42 for r = 3.2 and 102 for r = 2.8 — so the floor is
  needed for the pitch and for the fit (`Log[0.]` is `Indeterminate`).
  `separation_voice: false` drops voice 3 for a stereo-only rendering;
  the saturation marker stays, since it is centred and keeps the
  channels identical where they should be.
- **Saturation marker: 1320 Hz, 0.12 s** (`$divergenceSaturationMarker`),
  once, at the first n above saturation. It is the marker family's
  3 × 440 Hz (the triad's fifth an octave above the 660 Hz marker) and
  no other event in the app uses it; it sits above every orbit note (the
  scale tops out at 1046.5 Hz) and above the separation tone's
  fundamental (at most 880 Hz). It used to reuse the 440 Hz chaos-onset
  accent, which made the same sound mean two different things.
- **Tempo**: `iterations_per_second` (default 3) sets the note length,
  1 / iterations_per_second; `iterations` defaults to 119, so the 120 notes
  x_0 … x_119 play for exactly 120 / 3 = 40 s (the notes include x_0, so
  n iterations give n + 1 notes). The old `note_duration` key
  (0.08 s) is gone.
- **The four presets render to the same length**: presets set r, the
  case and optionally x0, and main.wl builds the intro and outro text of
  the current run *and* all four presets (`DivergenceNarration`, each
  with its own x0), synthesises them, and pads the spoken intro and outro
  to the longest. Speech goes through `SpeakNarration`, which caches
  each sentence for the run, so the shared opening sentence is
  synthesised once, not once per preset. The intro is at most 12 s of
  speech: one shared sentence plus one case sentence.
- **Finite-time exponents**: check 6 allows 25 percent because one pair
  of orbits over a few dozen iterations gives a finite-time exponent.
  From x0 = 0.3 at r = 3.2 the orbit first lingers near the unstable
  fixed point (|f′| = 1.2), and the fit gives −0.40 against λ = −0.92
  (ratio 0.44). This is correct behaviour, and why check 6 uses r = 4 and
  r = 2.8. The `divergence_periodic` preset therefore starts at
  x0 = 0.513, on the 2-cycle (0.51304), where the fit gives −0.9164
  against −0.9163 (ratio 1.0001).
- **Edge preset (r = 3.57)**: λ from x0 = 0.3 is +0.011, so the predicted
  saturation is ~1070 iterations; within 119 the separation only grows
  from 1e-6 to 9.1e-6 at the last iterate (it peaks higher on the way).
- **GIF** covers the whole WAV like lyapunov mode's (cursor at n = 0
  during the intro, at the last n during the outro) and shares its
  renderer, `RenderTwoPanelFrame`.

### 9. Narration: population framing, intros, outros, sentence cache

Every mode's WAV is spoken intro, 0.4 s pause, notes, 0.4 s pause,
spoken outro (`ExportNarratedWAV` in output.wl, which also returns the
timing that `PrintTimingLine` prints). The rules, for any new text:

- **Every sentence starts with a capital letter and ends with a full
  stop.** Never begin a sentence with "r" or a digit ("Here r is 2.8.",
  not "r equals 2.8."). `NarrationConventionIssues` checks this; main.wl
  prints a `[WARNING]` line for a failing sentence, and the tests run it
  over every mode and preset's text.
- **Every mode has an outro**, the audible end marker: "End of the
  sweep …", "… End of the iteration.", "End of the Lyapunov sweep …",
  "End of the chaotic case: …".
- **The talk frames the map as a bug-population model.** Sweep and
  iterate intros say that the map gives next year's population from this
  year's, that x is the fraction of the maximum population and r the
  growth rate. Both stay under 15 s of speech; the divergence intro stays
  at or under 12 s. Measured lengths are in VERIFICATION_narration.md;
  re-measure after a wording change (macOS `say` runs at about 2.5 words
  per second).
- **Iterate outros state the fixed point x* = 1 − 1/r and its stability
  from |f′(x*)| = |2 − r|** (`FixedPointStability`, `FixedPointSentences`
  — computed, never typed in): the number, below or above one, attracts
  or repels. For r < 1 (the `extinction` preset) x* is negative, so the
  outro also gives the slope r at x = 0, which is what attracts.
- **Lyapunov intro and outro are computed from the run**: the intro names
  the period doublings inside the range (`PeriodDoublingRs`, the same
  root-finder as check 1); the outro names the three widest windows
  (`LyapunovWindows`), with a period when the window opens within 0.005
  of a known one (`$lyapunovKnownWindows`), else "period not identified".
- **Sentence cache**: `SpeakNarration` splits text into sentences and
  synthesises each distinct sentence once per run
  (`$dynamicalSpeechCache`), joining them with 0.2 s of silence, about
  the pause `say` leaves between sentences. main.wl prints how many
  sentences were requested, synthesised and reused.
- **Sweep and iterate GIFs follow the lyapunov timing contract**: the
  picture waits at the start during the intro, moves with the notes and
  rests at the end during the outro (`timing` Association with
  "intro", "stepDuration"/"noteDuration", "total"). Before the outros
  were added, the frames were spread evenly over the whole WAV, intro
  included, so the diagram ran ahead of the sound.

## Project structure

```
dynamical/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json            — default simulation parameters
  experiments.wl          — 11 curated preset invocations (RunExperiment)
  prototype_lyapunov.wl    — listening prototype for lyapunov mode (record only; see decision 5)
  LISTENING_GUIDE.md       — user-facing recommended listening sequence
  AGENTS.md                — this file
  src/
    model.wl              — LogisticMap, SafeX0, $dynamicalPresets, PresetR/PresetX0/PresetDescription,
                            FixedPointStability, LyapunovWindows ($lyapunovKnownWindows),
                            PeriodDoublingRs,
                            IterateTrajectory, AttractorPoints, BifurcationPoint,
                            FeigenbaumCheck, FixedPointCheck, Period2Check,
                            LyapunovCheck, SweepEventRValues, SweepModel, IterateModelData,
                            $lyapunovPresets, LyapunovExponent, LyapunovSweep,
                            LyapunovZeroCrossings, Period2LyapunovExact, LyapunovCurveCheck,
                            $divergenceSeparationFloor, DivergenceOrbits, DivergenceFit,
                            DivergencePredictedSaturation, AttractorPeriod, DivergenceCase,
                            DivergenceCheck, $divergencePresets
    sonify.wl               — PitchScale3Octaves, SynthesizeDiscreteNotes, OverlayEvent,
                            SonifySweep, SonifyIterate ($sweepNotesPerStep constant),
                            LyapunovMarkers, LyapunovToneHz, AWeightingResponse,
                            LyapunovLoudnessGain, LyapunovHarmonicClearance,
                            LyapunovTimeOfR, SonifyLyapunov,
                            DivergenceSeparationHz, DivergenceNoteMapping,
                            DivergenceNoteBuffer, SonifyDivergence ($divergenceSaturationMarker)
    speech.wl                — ResampleLinear, DynamicalSpeakToBufferPlatform, BuildIntroBuffer,
                            sentence cache (NarrationSentences, SpeakSentence, SpeakNarration),
                            NarrationConventionIssues, SpokenDec/SpokenFixed/SpokenList,
                            BuildSweepIntroText/OutroText, BuildIterateIntroText/OutroText,
                            FixedPointSentences, BuildLyapunovIntroText, BuildLyapunovOutroText,
                            SpokenSmall, DivergenceNarration
    animate.wl                — RenderSweepFrame/AnimateSweepBifurcation,
                            RenderIterateFrame/AnimateIterateTimeSeries,
                            LyapunovBackground/RenderLyapunovFrame/AnimateLyapunov,
                            RenderTwoPanelFrame (shared),
                            DivergenceBackground/AnimateDivergence
    output.wl                  — PitchPanVolume, ExportSweepCSV, ExportIterateCSV,
                            PrintCorrectnessChecks, PrintSweepSummary, PrintIterateSummary,
                            PrintLyapunovCurveCheck, ExportLyapunovCSV, PrintLyapunovSummary,
                            PrintLoudnessLine, PrintDivergenceCheck,
                            ExportDivergenceCSV, PrintDivergenceSummary,
                            ExportNarratedWAV, PrintTimingLine, PrintNarration
  tests/
    test_model.wl            — unit tests (fixed point, period-2, Feigenbaum, Lyapunov, presets,
                              lyapunov mode incl. the config-driven false-unison guard,
                              divergence mode incl. left/right buffer identity,
                              fixed-point stability, windows, narration conventions)
  output/                     — generated files (gitignored)
```

## How to run

```sh
wolframscript -file dynamical/main.wl                                              # sweep, defaults
wolframscript -file dynamical/main.wl -- --simulation.mode=iterate                  # iterate at r=3.8
wolframscript -file dynamical/main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=extinction
wolframscript -file dynamical/main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=growth
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=fixed_point
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=period2
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=period4
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=period3_window
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=chaos
wolframscript -file dynamical/main.wl -- --simulation.dynamical.r=3.83
wolframscript -file dynamical/main.wl -- --simulation.dynamical.r_steps=1000
wolframscript -file dynamical/main.wl -- --simulation.dynamical.note_duration=0.04
wolframscript -file dynamical/main.wl -- --simulation.mode=lyapunov
wolframscript -file dynamical/main.wl -- --simulation.mode=lyapunov --simulation.dynamical.preset=lyapunov_window
wolframscript -file dynamical/main.wl -- --simulation.mode=lyapunov --simulation.dynamical.lyapunov.duration_seconds=60
wolframscript -file dynamical/main.wl -- --simulation.mode=divergence                                    # r = 4
wolframscript -file dynamical/main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_chaotic
wolframscript -file dynamical/main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_edge
wolframscript -file dynamical/main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_periodic
wolframscript -file dynamical/main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_stable
wolframscript -file dynamical/main.wl -- --simulation.mode=divergence --simulation.dynamical.divergence.separation_voice=false

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
    Period2Check, LyapunovCheck, LyapunovCurveCheck, DivergenceCheck —
    always run, printed PASS/FAIL; checks 5 and 6 print one sentence
    per r value]
        |
   sweep mode:                          iterate mode:
     SweepModel                           PresetR + IterateModelData
        |                                    |
     SonifySweep -> {leftBuf,rightBuf,...}  SonifyIterate -> {leftBuf,rightBuf,...}
        |                                    |
   BuildSweepIntroText/OutroText           BuildIterateIntroText/OutroText
        |      SpeakNarration (sentence cache)       |
   ExportNarratedWAV: [intro, pause, notes, pause, outro] -> -17 LUFS -> WAV
        |                                    |
   AnimateSweepBifurcation -> GIF          AnimateIterateTimeSeries -> GIF
   ExportSweepCSV -> CSV                   ExportIterateCSV -> CSV
```

Lyapunov mode:

```
   $lyapunovPresets (optional) -> LyapunovSweep -> {{r, lambda}, ...}
        |                          AttractorPoints per r (bifurcation panel)
        |                          LyapunovZeroCrossings
   SonifyLyapunov -> {leftBuf, rightBuf, markers}
        |
   ExportNarratedWAV: [intro, pause, sweep, pause, outro] -> -17 LUFS -> WAV
        |
   LyapunovWindows (down/up crossing pairs, period by known start)
   PrintLyapunovSummary (onset of chaos, windows, min/max, floor count)
   AnimateLyapunov -> GIF (covers the whole WAV); SyncWAVToGIF; PrintLoudnessLine
   ExportLyapunovCSV -> CSV
```

Divergence mode:

```
   $divergencePresets (optional) -> DivergenceOrbits -> {x, y, separation}
        |                           DivergenceFit, LyapunovExponent -> prediction
   SonifyDivergence -> {leftBuf (orbit x), rightBuf (orbit y), + centre separation tone, marker}
        |
   DivergenceNarration for this run and the 4 presets -> speech padded to the longest
   ExportNarratedWAV: [intro, pause, notes, pause, outro] -> -17 LUFS -> WAV
        |
   PrintDivergenceSummary; AnimateDivergence -> GIF; SyncWAVToGIF; PrintLoudnessLine
   ExportDivergenceCSV -> CSV
```

`SonifySweep`/`SonifyIterate` return buffers, not exported files — same
pattern as the images/ enhancement, so main.wl can add the spoken intro
and outro before a single final export and the reported `STEMDescribeWAV`
duration includes them.

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
| `"eventFreqs"`, `"eventTimes"` | Each event's accent frequency, and (in-range events only) its time in seconds from the first note; main.wl adds the intro to print when it is heard |

`IterateModelData[r, x0, nIterations, preset]` returns `"r"`, `"x0"`,
`"nIterations"`, `"preset"`, `"trajectory"` (length `nIterations + 1`,
including x0).

`LyapunovSweep[rMin, rMax, steps, x0, transient, nAverage, floor]` returns
a plain list `{{r, lambda}, ...}` (steps rows, r ascending, lambda >= floor).
`LyapunovZeroCrossings[sweep]` returns `<|"r", "direction" ("upward" |
"downward"), "index"|>` per sign change. `SonifyLyapunov[...]` returns
`"leftBuf"`, `"rightBuf"`, `"nSamples"` (= Round[duration * sr]),
`"markers"` (the in-range markers, each with its `"time"` in seconds into
the sweep), `"gainRangeDB"` and `"toneHzRange"` (for the console line).
`LyapunovWindows[crossings]` returns `<|"rStart", "rEnd", "width",
"period" (Integer or Missing[])|>` per downward crossing directly followed
by an upward one. The lyapunov CSV records every crossing in its
`crossing` / `crossing_r` columns, on the row of the step before it.

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

(Superseded by design decision 9: both functions now take a `timing`
Association and hold the picture during the intro and outro; the frame
count and rate still come from the same render-budget logic, now in
stem-core `GIFFramePlan`.)

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
4 experiment presets (of 9 total in `experiments.wl`) and compared GIF
vs. WAV duration with a Python `PIL`/`wave` script:

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
`signal/src/sonify.wl`'s `SpeakToBuffer`. On top of it, this app's
`SpeakNarration` synthesises one sentence at a time and caches each
distinct sentence for the run (design decision 9). `SpeechSynthesize[]` was
observed to return `$Failed` in this development environment — the
platform-native TTS tier (macOS `say`/`afconvert`) is what actually
produces audio in practice. This is one of many independent copies of
this pattern scattered across the codebase, each app calling
`SpeechSynthesize[]` directly rather than through a shared helper; a
good candidate for stem-core consolidation in a future pass (explicitly
out of scope here per this app's build spec, which excludes stem-core
changes).

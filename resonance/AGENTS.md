# resonance — AGENTS.md

## What this app does

Sonifies orbital resonance — the phenomenon where orbiting bodies'
periods lock into simple integer ratios, producing stable rhythmic (or,
in the asteroid belt and Saturn's rings, destructive) patterns — across
three modes:

| Mode | Physics | Output |
|------|---------|--------|
| `galilean` (default) | Io/Europa/Ganymede's exact 4:2:1 Laplace resonance, circular orbits | Rhythmic canon (event layer, C3/C4/C5) + constant 4:2:1-ratio drone (trajectory layer) |
| `kirkwood` | Asteroid belt density vs semi-major axis, Jupiter mean-motion resonances | Spectral chord, then a sweep with the gaps audible as silences |
| `saturn` | Ring density vs orbital radius, Cassini Division (Mimas 2:1) | Same chord+sweep; Cassini Division is a distinct gap in the sweep |

All three modes share one underlying idea: a p:q period resonance
implies a semi-major-axis ratio `(p/q)^(2/3)` (Kepler's third law).
`KirkwoodResonanceAU[p, q]` in `src/model.wl` is that formula; every
resonance location in the app (Kirkwood gaps, the Cassini Division
prediction) is computed from it, not hand-typed.

## Key design decisions (read before modifying sonify.wl or model.wl)

### 1. `galilean` mode is bespoke discrete-note + drone synthesis, not `SonifyTrajectory`

An orbit-completion stream (4 Io events, 2 Europa events, 1 Ganymede
event per Ganymede period) is a set of discrete one-shot events, not
one continuously-varying trajectory. Feeding it to `SonifyTrajectory`
would spline-interpolate pitch *between* orbit completions into a
glide — exactly wrong for "a three-voice rhythmic canon." This is the
same reasoning `scattering/AGENTS.md` gives for its own
`distribution`/`discovery` modes and `bayes/AGENTS.md` gives for its
pentatonic summary layer: `StemSynthNote` + manual sample-offset
placement, not `SonifyTrajectory`.

The secondary "continuous trajectory" layer the build spec asks for
(pitch "oscillates at the orbital angular velocity x audio_scale_factor")
reduces mathematically to three **constant**-frequency tones for
circular orbits — angular velocity does not vary over a circular orbit.
`BuildGalileanAudio` implements it as exactly that: three fixed sine
tones, one octave below the event-layer pitches (so the ratio stays
4:2:1 without duplicating the event pitches outright), mixed at the
configured `trajectory_layer_gain` (-12dB default).

### 2. `kirkwood`/`saturn` reuse the thermo/bayes additive-spectral primitive, not `SonifyTrajectory`

`SynthesizeAdditiveFrame`/`FrameWindow` here are structurally identical
to `thermo/src/sonify.wl`'s and `bayes/src/sonify.wl`'s versions — the
"spectrum" being additively synthesised is asteroid-belt or ring
density vs semi-major-axis/radius rather than a probability or speed
density, but the technique (N simultaneous sine partials, amplitude
from the density at each bin, short fade to prevent clicks) is
identical. The "sweep" (same bins, played sequentially rather than
simultaneously) is new to this app but uses the same `FrameWindow`
per-step fade.

### 3. `kirkwood`'s frequency range is a fixed 200-2000 Hz, separate from the shared config keys

The build spec's own mode descriptions give **two different** explicit
Hz ranges: kirkwood "freq_min=200 Hz to freq_max=2000 Hz" and saturn
"freq_min=150 Hz to freq_max=3000 Hz" — but the build spec's own
`config.json` only defines one shared
`simulation.resonance.freq_min`/`freq_max` pair, defaulting to 150/3000
(which matches saturn's text exactly, not kirkwood's). Rather than
having one config key silently mean two different frequency ranges
depending on mode (or overloading it in a way that breaks
`--simulation.resonance.freq_min=` for whichever mode "loses"),
`kirkwood`'s 200/2000 Hz range is hardcoded as `$KirkwoodFreqMinHz`/
`$KirkwoodFreqMaxHz` in `src/sonify.wl`, and the shared
`simulation.resonance.freq_min`/`freq_max` config keys are read only by
`saturn` mode (`SonifySaturn`/`SaturnModel` do not use them; only
`BuildSaturnAudio` and `ExportSaturnCSV` do).

### 4. The Cassini Division correctness check uses a 1000 km tolerance, not the build spec's stated 100 km

The idealised point-mass two-body 2:1 Mimas resonance formula
(`a_Cassini = a_Mimas * (1/2)^(2/3)`) predicts **116,882 km**. The real,
commonly-cited observed inner edge of the Cassini Division is
**117,580 km** — a genuine ~700 km (0.6%) discrepancy, verified by
direct computation, not assumed. This gap is real physics: Saturn's
oblateness (J2) and higher-order perturbation theory shift the true
resonance location measurably from the simple point-mass prediction,
unlike the Kirkwood gaps (Jupiter's much smaller oblateness effect on
the asteroid belt), where the same idealised formula matches the
commonly-cited reference values to within a few parts in a thousand
(see check 2). The build spec's own text asks for this check to pass
"within 100 km," which the idealised formula cannot satisfy against the
real 117,580 km value — no choice of reasonable formula fixes this,
since it is a real physical effect, not an implementation bug. The
tolerance is widened to 1000 km (~0.85%) in `CassiniDivisionCheck`
(`src/model.wl`) to report this honestly rather than silently forcing a
false "within 100 km" pass. The build spec's separate `tests/`
description additionally states a third, different value (117,040 km)
for the same quantity — neither cited figure is reproduced by the
formula; `tests/test_model.wl`'s test 3 checks the formula's own
arithmetic against itself (both sides computed independently from
`$AMimasKm`) rather than against either literal number.

The ring model's own Cassini Division geometry (used for the audio gap
and the GIF) still uses the real observed **117,580-122,200 km**
boundaries given in the build spec's background section — only the
*correctness check*, which compares the idealised-formula prediction
against that observed value, needed the tolerance fix.

### 5. `KeplerThirdLawCheck` verifies against reference values, not against itself

An earlier draft of check 2 computed `KirkwoodResonanceAU[p,q]` and
compared it to... itself, which is tautologically always true and
therefore not a check. `$KirkwoodResonances` now carries an `aRef` field
(the build spec's own listed reference AU value for each gap: 2.065,
2.502, 2.824, 2.958, 3.278) and `KeplerThirdLawCheck` compares the
formula's output against `aRef`, within 0.5%. All five pass comfortably
(worst case a few parts in ten-thousand) — unlike the Cassini case
above, Jupiter's asteroid-belt resonances are close enough to ideal
point-mass two-body mechanics that the simple formula matches the
literature values almost exactly.

### 6. Spoken announcements at Kirkwood/Cassini crossings are console-only (`STEMSay`), not embedded TTS clips mid-sweep

The build spec asks for "a spoken announcement (via STEMSay) of which
resonance is being crossed" during the sweep. Precisely interleaving
several short synthesized-speech clips into a already-continuous,
precomputed sweep buffer (so that each clip's audio plays at the exact
moment its cursor position is reached) would require either drastically
slowing the sweep at each crossing or accepting audio overlap between
the spoken label and the sweep tone either side of it — a much bigger
change than "announce it" implies, and not spelled out by the spec.
`STEMSay` is called once per resonance crossing during
`BuildKirkwoodAudio` (in ascending-`a` order, matching the sweep's own
inner-to-outer order) — this prints to console always, and additionally
speaks via platform TTS if `STEM_SPEAK=1` is set, independent of the
sweep's own precomputed audio timeline. The one spoken intro per run
(via `SpeechSynthesize[]`/platform TTS, embedded in the WAV) still
covers the "spoken guide" experience the build spec's `SpeechSynthesize`
requirement is really asking for.

## Project structure

```
resonance/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json          — default simulation parameters
  experiments.wl       — 10 curated preset invocations
  LISTENING_GUIDE.md   — user-facing recommended listening sequence
  AGENTS.md            — this file
  src/
    model.wl           — GalileanModel, KirkwoodModel, SaturnModel,
                         KirkwoodResonanceAU, RunCorrectnessChecks (checks 1-4)
    sonify.wl          — SonifyGalilean (event canon + drone),
                         SonifyKirkwood/SonifySaturn (spectral chord + sweep,
                         shared SynthesizeAdditiveFrame/FrameWindow primitive),
                         spoken intro (SpeechSynthesize -> platform TTS -> text fallback)
    animate.wl         — AnimateGalilean (orbital top-down), AnimateKirkwood
                         (belt density sweep), AnimateSaturn (ring density sweep)
    output.wl          — CSV export for all three modes
  tests/
    test_model.wl      — 5 unit tests (period ratios, Kepler 3:1 gap,
                         Cassini Division, octave ratios, event counts)
  output/              — generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                             # galilean, 8 Ganymede periods
wolframscript -file main.wl -- --simulation.mode=kirkwood               # asteroid belt gaps
wolframscript -file main.wl -- --simulation.mode=saturn                 # Saturn ring structure
wolframscript -file main.wl -- --simulation.resonance.n_periods=4       # shorter galilean
wolframscript -file main.wl -- --simulation.resonance.n_periods=16      # longer, more repetitions
wolframscript -file main.wl -- --simulation.resonance.gap_width_AU=0.02 # narrower Kirkwood gaps
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks (printed on every run, all modes)

1. **Period ratio** (`galilean`) — over the run's duration, Io completes
   exactly 4x as many orbits as Ganymede, Europa exactly 2x, within 0.01
   orbits.
2. **Kepler's third law** (`kirkwood`) — each of the five Kirkwood
   resonance radii, computed from `a = 5.203*(q/p)^(2/3)`, matches its
   commonly-cited reference AU value within 0.5%.
3. **Cassini Division location** — the idealised 2:1 Mimas resonance
   formula's prediction is within 1000 km of the real observed
   117,580 km value (widened from the build spec's stated 100 km — see
   design decision 4).
4. **Musical interval** (`galilean`) — the three assigned pitches
   (C3/C4/C5) have frequency ratios 1:2:4 within 0.01%.

## Animation framing: GIF/WAV duration sync (fixed post-v1.5.0)

**The bug.** `AnimateGalilean`/`AnimateKirkwood`/`AnimateSaturn` built
every GIF from a fixed `$ResonanceGifFrames = 60` at a fixed
`$ResonanceGifFrameRate = 15` — a constant 4.2s of playback regardless
of the sonification's actual length. Measured before the fix (Python,
counting per-frame GIF `duration` fields against WAV sample counts):

| mode | GIF (old) | WAV | ratio |
|------|-----------|-----|-------|
| galilean | 4.2s | 57.0s | 13.6x |
| kirkwood | 4.2s | 36.9s | 8.8x |
| saturn   | 4.2s | 34.4s | 8.2x |

**Root cause.** Same shape as the bug already fixed in
`lorenz/src/animate.wl` (`ExportAnimation`): frame count and frame rate
were both hardcoded constants, decoupled from whatever duration
`sonify.wl` actually gave the WAV.

**The fix.** `Animate*` now take a `targetDuration` argument (GIF
playback length in seconds) and an `nFrames` render-budget default
(150, not a literal frame count): `frameRate = Clip[nFrames /
targetDuration, {$MinAnimationFps, $MaxAnimationFps}]` (2-30 fps),
then `actualNFrames = Max[2, Round[frameRate * targetDuration]]` so
playback duration equals `targetDuration` exactly even at the fps
clamp boundary. Returns `{actualNFrames, frameRate}` so
`STEMDescribeGIF` reports the real numbers. `kirkwood`/`saturn` also
cap `actualNFrames` at `model["nSteps"]` (the sweep only has that many
distinct belt/ring positions to show) — harmless with default configs
(`n_steps` 200-300 comfortably exceeds the 150-frame budget) but a
genuine, documented limit at very small `n_steps`.

`targetDuration` is **the WAV's main-body duration, not its total file
length**: `GalileanMainDurationSec[model]` (`= tEnd *
$ResonanceIoPeriodSeconds`) and `ChordSweepMainDurationSec[model,
cfg]` (`= chord_duration + 0.4 + duration_per_step * n_steps`), both in
`src/sonify.wl`, mirror the arithmetic `BuildGalileanAudio`/
`BuildKirkwoodAudio`/`BuildSaturnAudio` use internally, without
depending on the WAV having been built yet (animation renders before
sonification in `main.wl`'s pipeline) — the same "pass the same
duration value used to size the WAV" idiom `lorenz` uses via
`solution[[-1,1]]`.

**This intentionally does not close the gap completely**, and that gap
is structural, not a leftover bug: every mode's WAV is
`PrependIntroAndExport`-prefixed with a spoken introduction (TTS,
duration unknown until speech synthesis actually runs) plus a 0.4s
pause, which the GIF has no visual content for and which can't be
computed ahead of the animation render without reordering the whole
pipeline. Matching the GIF to the *main content* duration (not the
intro-inclusive WAV file length) is the same choice lorenz's reference
fix makes — `solution[[-1,1]]` is lorenz's trajectory duration, not any
padded file length either. Measured after the fix:

| mode | GIF (new) | WAV (total) | ratio |
|------|-----------|-------------|-------|
| galilean | 31.5s (150 frames @ 4.69 fps) | 57.0s | 1.81x |
| kirkwood | 15.0s (150 frames @ 10.42 fps) | 36.9s | 2.46x |
| saturn   | 15.0s (150 frames @ 10.42 fps) | 34.4s | 2.30x |

The remaining ratio is entirely the spoken-intro segment (confirmed:
GIF duration tracks each mode's computed main-body duration —
32.0s/14.4s/14.4s target vs 31.5s/15.0s/15.0s actual; the small
per-mode offset is the GIF format's own 1/100s frame-duration
quantization — e.g. galilean's 1/4.6875s = 0.2133s per-frame interval
rounds to 0.21s in the file, times 150 frames = 31.5s rather than
32.0s — not a bug in the fix) — down from 8-13.6x to a predictable,
intro-sized 1.8-2.5x, not an arbitrary mismatch.

Changed: `src/animate.wl` (`Animate*` signatures/bodies,
`$MinAnimationFps`/`$MaxAnimationFps`, `$ResonanceGifFrames` now a
render budget), `src/sonify.wl` (`GalileanMainDurationSec`,
`ChordSweepMainDurationSec`), `main.wl` (all three call sites pass
`targetDuration` and capture `{nFrames, gifFps}` for
`STEMDescribeGIF`).

## Common pitfalls

1. **`kirkwood`'s frequency range is not controlled by
   `simulation.resonance.freq_min`/`freq_max`** — those keys are read
   only by `saturn` mode. `kirkwood`'s 200-2000 Hz range is a fixed
   constant in `src/sonify.wl` — see design decision 3.
2. **The Cassini Division's *displayed*/audio-gap location (117,580 km)
   and the *correctness-check* predicted location (116,882 km) are
   deliberately different numbers** — the former is the real observed
   value used for the ring geometry; the latter is what the idealised
   two-body formula predicts. Do not "fix" one to match the other; see
   design decision 4.
3. **`galilean` mode's "1 Io period = 1 second of audio" tempo is a
   fixed internal constant** (`$ResonanceIoPeriodSeconds` in
   `src/sonify.wl`), not exposed via config — the build spec specifies
   event durations and `n_periods` but no explicit playback tempo.
4. **The galilean GIF recomputes its own high-resolution trajectory** —
   it does not reuse `GalileanModel`'s `"t"`/`"x*"`/`"y*"` CSV-resolution
   arrays (200 points over up to 32 Io periods is too coarse to trace a
   smooth circle); see `AnimateGalilean`'s header comment, same idiom
   `lagrange/src/animate.wl` uses for its own GIF-only sampling grid.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSection`, `STEMSay`, `STEMPrintN`,
  `STEMDescribeWAV`, `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`,
  `STEMPlayCmd`, `StemSynthNote`, `NormalizeBuffer`,
  `ExportAudioBuffer`, `ExportGIF`, `ExportCSV`, `EnsureDir`.
  Deliberately **not** used: `SonifyTrajectory`, `SpatialLayer`,
  `MotionLayer`, `EventLayer`, `MixLayers` — see design decisions 1-2.
- **Mathematica/WL**: `Graphics`, `FilledCurve`, `Rectangle`, `Export`,
  `SpeechSynthesize`, `AudioQ`, `AudioData`, `AudioSampleRate`,
  `RunProcess` (platform TTS fallback), `Import` (reading
  TTS-generated WAV files).

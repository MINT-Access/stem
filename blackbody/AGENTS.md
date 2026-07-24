# Blackbody — Agent Guide

## Project overview

Sonifies Planck's law of black body radiation: the spectral radiance
`B(nu,T)` emitted by any object purely as a function of its temperature.
The formula whose exact-fit to both the low- and high-frequency limits
(Rayleigh-Jeans and Wien) forced quantum mechanics into existence in
1900.

| Mode | Physics | Output |
|------|---------|--------|
| `spectrum` (default) | Fixed T, sweep nu (radio->X-ray) | Stereo WAV (chord then sweep); animated sweep-marker GIF; static curve PNG |
| `temperature` | Sweep T (2500K-40000K); Wien's law (pitch) + Stefan-Boltzmann (loudness) | Stereo WAV; animated shifting-curve GIF; composite PNG |
| `star` | Named real presets; single preset reuses `spectrum`, `preset=all` is a sequential tour | Stereo WAV; GIF; PNG |

Closest sibling apps: `thermo/` (the spectral-envelope additive-synthesis
technique — many simultaneous partials tracing a physical curve
directly — is reused verbatim, driven by photon frequency instead of
molecular speed) and `hydrogen/` (the chord-then-sweep structure of
`spectrum`/`star` mode, and the continuum-plus-marked-features
visualisation style).

## Key design decisions (read before modifying sonify.wl or model.wl)

### 1. Physical frequency sweep vs. audio pitch range are two separate config keys

`freq_min`/`freq_max` (default `1e6`/`1e19` Hz) are the *physical*
sweep bounds — radio through X-ray. `audio_freq_min`/`audio_freq_max`
(default `100`/`4000` Hz) are the *audio* pitch range the physical
sweep is log-mapped onto. This differs from `thermo/`'s single
`freq_min`/`freq_max` pair (which only ever means the audio range,
since `thermo` has no separate "physical frequency" axis to sweep) —
blackbody genuinely needs both, so it uses two distinct key pairs
rather than overloading one name for two different quantities.

### 2. Wien's displacement law uses the wavelength form, not the frequency form

`PlanckRadianceWavelength[lambda,T]` and `PlanckRadianceFreq[nu,T]` are
**not** related by simply substituting `nu = c/lambda` into one to get
the other — `B_lambda = B_nu * |dnu/dlambda|`, and the extra Jacobian
factor means the two forms' peaks sit at different locations (the
classic "two Wien peaks" subtlety: `B_nu`'s peak is not at `c` divided
by `B_lambda`'s peak wavelength). Wien's displacement law as usually
quoted (`lambda_peak*T = b = 2.8978e-3 m*K`) is specifically a property
of `PlanckRadianceWavelength`. `PeakFrequencyFromWavelength[T]`
therefore always converts the *wavelength*-domain peak to a frequency
via `c = lambda*nu` (an exact unit conversion of one already-known
wavelength value) rather than separately locating `PlanckRadianceFreq`'s
own peak — this keeps a single, consistent "where does emission peak"
answer used everywhere in the app (spectrum mode's visible-band edges,
temperature mode's pitch mapping), rather than silently mixing two
different, similarly-named quantities.

### 2a. `WienDisplacementCheck` solves a dimensionless equation, not `FindMaximum` on raw `lambda`

An earlier version of this check called `FindMaximum[PlanckRadianceWavelength[lambda,T], {lambda, $WienB/T}]`
directly and failed to converge (`FindMaximum::lstol`) with over 2000%
error — both the domain (`lambda ~ 1e-6`) and the range (`B ~ 1e-30`ish)
are far enough from order-1 scale that `FindMaximum`'s default
tolerances cannot navigate them. The fix: substitute
`x = h*c/(lambda*k*T)` and solve the well-known dimensionless peak
equation `x = 5*(1-Exp[-x])` via `FindRoot` starting at `x=5.0` — a
well-scaled O(1) root-find, not a badly-scaled maximisation. `x* ≈
4.965114231744276`; `lambda_peak = h*c/(k*T*x*)` (**not**
`h*c*x*/(k*T)` — an inverted first draft of this formula produced the
2365% failure this check's docstring warns about; verify the division
direction if you ever touch this line). The check then independently
confirms each computed `lambda_peak` is an actual local maximum by
comparing `B` at `lambda_peak*1.02` and `lambda_peak*0.98`.

### 3. Correctness checks run every invocation, unconditionally — and never abort

All four checks (Rayleigh-Jeans, Wien approximation, Wien's
displacement, Stefan-Boltzmann) are properties of the Planck formula
itself, not of any particular mode, so they run once before the mode
dispatch (matching `hydrogen/`'s `EnergyLevelCheck`/`RydbergCheck`
placement, not `thermo/`'s mode-conditional checks 3-4). Checks print
`[PASS]`/`[FAIL]` and the run continues regardless — **no app in this
codebase aborts via `LogError` on a failed correctness check**; that is
a printed diagnostic convention, not a hard gate, verified by grepping
every other app's `main.wl` before writing this app's checks the same
way.

### 4. `RayleighJeansCheck`/`WienApproxCheck` are parametrised by dimensionless `x`, not raw Hz

Both checks take an `x = h*nu/(k*T)` value (`1e-6` and `40` by default)
and derive `nu = x*k*T/h` internally, rather than taking a fixed
frequency in Hz. Two reasons: (a) the physically relevant regime is "x
small" or "x large" regardless of T, so a fixed Hz value would probe a
different *relative* position on the curve at different temperatures;
(b) a naive fixed `nu = 1.0` Hz test frequency was tried first and
failed — at T~5778K, `x ~ 8e-15` is so far below machine epsilon that
`Exp[x] - 1` loses almost all precision to catastrophic cancellation
(computing `1 + tiny` then subtracting `1`), producing a spurious 1.1%
"error" that had nothing to do with the Rayleigh-Jeans approximation
itself. `x = 1e-6` keeps the cancellation loss negligible while
remaining deep in the regime the approximation is valid in.

### 5. Subnormal-amplitude underflow is clamped once, at the source, not chased downstream

`BlackbodySpectrumBins` clamps any peak-normalised amplitude below
`1e-12` to exactly `0.0`. Without this, a bin deep in the curve's tail
can carry a legitimate but subnormal (`~1e-307`) float value that is
perfectly finite on its own, but underflows into `General::munfl`
warnings the moment *any* caller scales it further (dividing by
`Sqrt[nBins]` for additive-synthesis normalisation, multiplying by a
loudness factor `<1`, etc.). An earlier draft chased this by wrapping
every downstream scaling operation in `Quiet[...,General::munfl]`
individually (three separate call sites); clamping once at the source
in `BlackbodySpectrumBins` is simpler and catches every future caller
automatically. `PlanckRadianceFreq` itself is still called inside
`Quiet[...,General::munfl]` in every hot path (`BlackbodySpectrumBins`,
`NormalizedCurvePoints`, `StefanBoltzmannCheck`'s `NIntegrate`) since
the *raw* radiance value can legitimately underflow before any
normalisation happens at all — that part of the physics is correct
(radiance really is astronomically close to zero far from the peak),
just noisy to print.

### 6. `star` mode's single-preset path reuses `spectrum` mode's function, not a parallel implementation

`BuildSpectrumAudio`/`AnimateSpectrum`/`ExportSpectrumCSV` are called
directly for `star` mode with a single named preset (just narrated with
the star's name instead of "spectrum at T"). Only `preset=all` uses the
separate `BuildStarTourSegments`/`AnimateStarTour`/`ExportStarCSV`
functions (a short chord per star instead of a full chord+sweep, since
six consecutive chord+sweep pairs would run to nearly a minute).
`BuildStarTourSegments` returns segments **unconcatenated** specifically
so `main.wl` can splice a spoken star-name announcement before each one
— concatenating inside `sonify.wl` would have no way to interleave
speech built by `speech.wl`/`main.wl`.

## Project structure

```
blackbody/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json          — default simulation parameters
  experiments.wl        — 7 curated preset invocations (3 x spectrum at different T,
                          2 x temperature range, star tour)
  LISTENING_GUIDE.md     — user-facing recommended listening sequence
  AGENTS.md               — this file
  src/
    model.wl              — PlanckRadianceFreq/Wavelength, RayleighJeansFreq, WienApproxFreq,
                            WienPeakWavelength, PeakFrequencyFromWavelength, correctness
                            checks 1-4, StefanBoltzmannLoudness, $StarPresets/StarOrder
    sonify.wl                — SynthesizeAdditiveFrame/FrameWindow (core primitive),
                            BlackbodySpectrumBins, AddVisibleBandMarkers/AddPeakMarker,
                            BuildSpectrumAudio, BuildTemperatureAudio, BuildStarTourSegments
    speech.wl                 — Spoken intro synthesis (SpeechSynthesize -> platform TTS ->
                            text-only fallback), BuildXIntroText per mode
    animate.wl                  — NormalizedCurvePoints/VisibleBandShading/PeakMarkerGraphics
                            (shared), per-mode Render*/Animate* functions
    output.wl                    — PrintBlackbodyChecks, Export*CSV per mode, Print*Summary per mode
  tests/
    test_model.wl              — unit tests (RJ/Wien limits, Wien's law, Stefan-Boltzmann,
                            known physical facts, loudness mapping, star presets)
  output/                     — generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                                       # spectrum, solar
wolframscript -file main.wl -- --simulation.mode=temperature                       # 2500K->40000K
wolframscript -file main.wl -- --simulation.mode=star                             # star mode, sun
wolframscript -file main.wl -- --simulation.mode=star --simulation.blackbody.preset=rigel
wolframscript -file main.wl -- --simulation.mode=star --simulation.blackbody.preset=all
wolframscript -file main.wl -- --simulation.blackbody.temperature=3200
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks

All four run unconditionally, every invocation, regardless of mode:

1. **Rayleigh-Jeans limit** — exact formula matches the low-frequency
   approximation within 0.1% at `x = h*nu/k*T = 1e-6`.
2. **Wien approximation limit** — exact formula matches the
   high-frequency approximation within 0.0001% at `x = 40`.
3. **Wien's displacement law** — `FindRoot`-located peak wavelength
   times temperature matches `b = 2.8978e-3 m*K` within 0.1%, for T in
   `{2500, 5778, 10000, 25000}`, with an independent local-maximum
   verification at each point.
4. **Stefan-Boltzmann law** — numerically integrated total radiance
   ratio between T=5778K and T=2889K matches `16` (`= 2^4`) within 0.1%.

## Common pitfalls

1. **`gamma_?NumericQ : 1.0` in function signatures is broken syntax**
   — parses as `gamma_?(NumericQ : 1.0)`, a pattern that never matches.
   Always use `Optional[gamma_?NumericQ, 1.0]` instead (same pitfall
   documented in `dynamical/AGENTS.md` and `thermo/AGENTS.md`).
2. **A stray `*)` inside a prose comment silently truncates it.** An
   earlier draft of `model.wl`'s Check 3 docstring wrote
   `lambda_peak = h*c/(k*T*x*)` — the `x*` immediately followed by `)`
   forms `*)`, which WL's tokeniser reads as the comment's *own*
   closing delimiter, regardless of surrounding prose. Everything after
   that point becomes live code until the *next* `*)`, producing a
   `Syntax::sntx` error pointing at an unrelated later line. Any
   variable name ending in an implied multiplication (`x*`, `T*`, `nu*`)
   immediately before a `)` in a comment needs a space or a rename
   (this file now spells it `xStar` throughout for exactly this reason).
3. **`Animate*` functions return their actual rendered frame count**,
   not the requested `nFrames` — `main.wl` passes this return value to
   `STEMDescribeGIF` directly rather than hardcoding the requested count
   (same convention as `thermo/AGENTS.md` pitfall 2).
4. **Composite PNGs (temperature/star `preset=all`) stagger peak labels
   vertically by curve index** (`PeakMarkerGraphics`'s `labelRow`
   argument) — with 5-6 curves whose peaks can sit within a couple of
   tenths of a decade of each other (e.g. `red_dwarf` 3200K vs.
   `betelgeuse` 3500K), unstaggered labels overlap into an unreadable
   smear. If you add more presets or curves, increase the row spacing
   (`0.16` per row) or the image height (`14` px per row) rather than
   removing the stagger.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSection`, `STEMSay`, `STEMPrintN`, `STEMDescribeWAV`,
  `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`, `STEMPlayCmd`,
  `NormalizeBuffer`, `ExportAudioBuffer`, `ExportGIF`, `ExportCSV`,
  `EnsureDir`, `StemSynthNote` (sweep notes and the visible-band-edge
  bell overlay only — the chord/envelope itself is bespoke additive
  synthesis, same pattern as `thermo/`/`hydrogen/`). Deliberately
  **not** used: `SonifyTrajectory`, `SpatialLayer`, `MotionLayer`,
  `EventLayer`, `MixLayers`, `RenderAudio`, `ScaleLookup` — see design
  decision 1 in `thermo/AGENTS.md`, which applies identically here.
- **Mathematica/WL**: `NIntegrate`, `FindRoot`, `Sound`,
  `SampledSoundList`, `Graphics`, `PieChart`-free (no pie charts in this
  app), `Export`, `SpeechSynthesize`, `AudioQ`, `AudioData`,
  `AudioSampleRate`, `RunProcess` (platform TTS fallback), `Import`
  (reading TTS-generated WAV files).

## Speech synthesis note

`speech.wl`'s three-tier fallback (`SpeechSynthesize[]` -> platform TTS
-> text-only `STEMSay`) duplicates the pattern in `thermo/src/speech.wl`
and `hydrogen/src/speech.wl` (itself duplicated from `images/` and
`dynamical/`) — now a fifth independent copy, still out of scope for
stem-core consolidation per every prior app's own build spec.

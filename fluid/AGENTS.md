# Karman Vortex Street — Agent Guide

## Project overview

Simulates and sonifies vortex shedding behind a bluff body using a simplified
discrete-vortex (vortex particle) method, making the Strouhal frequency —
the pitch a wire or flagpole sings in the wind — directly audible.

| Mode | Physics | Key phenomenon |
|------|---------|-----------------|
| `karman` | Fixed Re Karman vortex street | Periodic lift oscillation at f_shed = St·U/D, heard as a steady Strouhal tone + alternating shed clicks |
| `strouhal` | Re swept from 20 to 300 | Silence below Re≈47 → sudden tone at onset → broadening toward turbulence |
| `flag` | Damped-driven flag-tip oscillator | Flutter frequency f_flag = 0.15·U/L, heard as a tone panning left-right with each flap |

This is the fluid-dynamics complement to `waves/` (wave equation — conservative,
non-dissipative) and shares the "particle trajectories in a field" spirit of
`magnetic/` (charged particles in B/E fields).

## Key design decisions (read before modifying model.wl or sonify.wl)

### 1. Manual carrier synthesis, not stem-core's SonifyTrajectory

Every mode needs a tone at an exact **calibrated physical frequency**
(`audio_freq_target`, scaled from the real Strouhal/flutter frequency — not
re-derived from `MinMax[value]` the way `SpatialLayer`'s `Rescale` works)
plus **ScaleLookup-quantised pitch** (explicitly requested by the spec for
both karman and flag modes — `SpatialLayer` only does a continuous linear
Rescale to Hz, never scale quantisation) plus **event bursts timed by real
physics** (vortex-shedding times, y_tip zero-crossings — not `EventLayer`'s
built-in apex/crossing detectors). This is the identical situation `magnetic/
src/sonify.wl` already documents (see its design decision 1) and the
resolution is the same: manual carriers built from stem-core's lower-level
primitives (`ScaleLookup`, `StemSynthNote`-style burst synthesis,
`NormalizeBuffer`, `ExportAudioBuffer`, `SpeechSynthesize`), not the
`SonifyTrajectory` wrapper. If asked to route this app through
`SonifyTrajectory` directly, flag the tension with these three requirements
rather than silently dropping one of them.

### 2. LiftProxy is an event-driven decaying-pulse construction, not a literal centroid difference

The spec's own karman-mode text says `L(t) = y-centroid of positive vortices
minus y-centroid of negative vortices`. This was tried first and rejected:
with only ~7-15 vortices ever present in the domain at once (see decision 4),
the two group centroids sit almost exactly at ±0.5D regardless of time —
verified numerically, the resulting L(t) varied by less than 10% of its mean
and its autocorrelation peak measured a period more than 2x off the true
`1/f_shed`. `LiftProxy` instead sums one causal exponentially-decaying pulse
per shedding event, alternating sign (+1 top, -1 bottom):

```
L(t) = sum_k sign_k * exp(-(t - t_k)/tau) * [t >= t_k]
```

Because events alternate sign and land exactly `dtShed` apart, this has its
fundamental Fourier component at exactly `f_shed = 1/(2 dtShed)` **by
construction** (one full lift cycle = one top shed + one bottom shed),
matching the real fact that lift oscillates at f_shed while drag (shed-rate
only, sign-independent) oscillates at 2·f_shed. Verified via FFT: <2% error
vs the formula's own f_shed prediction at Re=150. This is a documented
"impulse response" simplification, not the literal centroid formula.

### 3. FlagOscillator returns the closed-form steady-state solution, not an NDSolve integration from rest

The spec's flag ODE is `y'' + 2ζω₀y' + ω₀²y = F(t)` with ζ=0.05 (light
damping) integrated from `y(0)=y'(0)=0`. At default parameters
(U=1, flagLength=5, stiffness=0.1) this gives ω₀≈0.0632 rad/time, so the
natural decay time `1/(ζω₀) ≈ 316` time units — vastly longer than any
sensible `--duration`. Verified: integrating from rest over the default
`duration=30` produces a **monotonically growing, non-periodic** transient
that overshoots the eventual steady-state amplitude by ~4x (peaking near
y≈125 at t≈24 for a steady-state amplitude of ~32) before it even begins
oscillating — nothing like "periodic flutter with slight amplitude
modulation." `FlagOscillator` instead evaluates the **closed-form particular
(steady-state) solution** of the same linear ODE — one term per forcing
harmonic, `y_p = amp/D · [(ω₀²-w²)sin(wt) - 2ζω₀w·cos(wt)]` — which models a
flag that has already been fluttering for a while before the recording
starts (the physically interesting regime this app is about) and is exact,
bounded, and ~50x faster than NDSolve. Verified: <0.1% error vs the
predicted `f_flag` over a 12-period check window.

### 4. Vortex counts stay small (~7-15) by design — this is a real feature of the chosen units, not a bug

With `St(150)≈0.172`, `dtShed≈2.91` time units, and a fixed domain length
`xMax=20D` (advection speed ≈U=1), only vortices shed within the last ~20
time units remain in frame — about 7 events, alternating sides, so ~3-4
visible per row at once. `n_vortices_max` (default 200) is a generous safety
cap that never binds at default parameters; it only matters for much longer
`--duration` values. The GIF's staggered double row is real but sparse —
documented in README as an expected limitation of the simplified method, not
compensated for by shedding extra "filler" vortices per event (the spec's
model literally sheds one vortex per event).

### 5. Biot-Savart unit test uses a corrected expected value

The spec's check 4 claims the velocity induced by a Γ=1 vortex at (0,1),
evaluated at (1,0), is `(1/(2π), 0)`. Verified two independent ways (complex
notation `w* = Γ/(2πi(z-zj))`, and the standard real-component 2D point-vortex
formula): both give `(1/(4π), 1/(4π)) ≈ (0.0795775, 0.0795775)`. This is not
a rounding difference — the separation vector `(1,-1)` sits at exactly 45°
to both axes, so under **any** consistent circulation-sign convention the
induced velocity's x and y components must have equal magnitude, making
`(1/(2π), 0)` unreachable from these exact positions. `tests/test_model.wl`
checks against the corrected value.

### 6. StrouhalRangeCheck validates Re in [250, 2000], not the spec's literal "40 < Re < 180"

`StrouhalNumber[Re] = 0.198(1 - 19.7/Re)` is documented (including in the
spec's own prose) as valid for `250 < Re < 2×10⁵`. Over `40 < Re < 180`
(the literal check-3 window) this formula returns St ≈ 0.10–0.176 — it
**never reaches 0.18**, so a check asserting `St ∈ [0.18, 0.22]` there would
fail on every run regardless of implementation correctness. `StrouhalRangeCheck[]`
instead samples `Re ∈ [250, 2000]` (inside the formula's own stated domain),
where it does stay within the classic St≈0.2 empirical band.

### 7. Per-Re "St_measured" in strouhal mode uses its own dedicated 40-unit measurement window, not `duration_per_Re`

FFT frequency-bin spacing is set by the **total observed duration**, not by
sample count. At the default `duration_per_Re=10`, bin spacing is
`1/10 = 0.1` — wider than the entire St≈0.1–0.2 range of interest, so every
measured value snapped to one of only two spurious plateaus (~0.098 or
~0.197) instead of tracking the reference curve. Each shedding step now
additionally calls `StrouhalFrequencyCheck[Re, U, D, 40.0]` (bin spacing
~0.025) purely for this measurement, decoupled from `duration_per_Re` (which
still controls the short per-step *audio* segment). This roughly doubles
`StrouhalSweepModel`'s build time (~7s instead of ~0.3s at defaults) —
still trivial in absolute terms.

## Common pitfalls (all found and fixed during development — read before touching sonify.wl)

1. **`SemitoneToHz[semitones_?NumericQ, ...]` does not thread over a list
   argument.** Its pattern requires a scalar; calling it with an array
   (`scale[[idx]]`, a whole audio-length array of scale-degree indices)
   returns **unevaluated** with no error, and that huge unevaluated symbolic
   expression silently poisons every downstream `Accumulate`/`Sin` call —
   turning a sub-second vectorised pipeline into one that runs for minutes
   with no error message. `VectorScaleLookup` in `sonify.wl` inlines the
   formula (`rootHz * 2.0^(scale[[idx]]/12.0)`) directly instead of calling
   `SemitoneToHz`.

2. **`InterpolatingFunction` evaluated on a list argument does not reliably
   return a packed array.** `Interpolation[...][audioTimeArray]` came back
   unpacked in testing, and once one array in the pipeline unpacks, every
   arithmetic operation built from it (via `Times`, `Sin`, `Accumulate`)
   silently falls into Mathematica's much slower general/unpacked numeric
   path. At audio sample counts (10^5–10^6) this alone turns milliseconds
   into minutes. `SafeInterpToAudioGrid` and `VectorScaleLookup` both force
   `Developer\`ToPackedArray` immediately after the operation that produced
   the unpacked result. If you add a new interpolation or vectorised
   mapping step, check `Developer\`PackedArrayQ` on its output before
   assuming it is fast.

3. **Cubic-spline interpolation can overshoot a source array's own range.**
   Flag mode's pan value is rescaled to the *full* `[-1,1]` range (touching
   both endpoints), and `SafeInterpToAudioGrid`'s spline interpolation
   between sample points overshot to ~1.000003 — just enough that
   `Sqrt[(1-pan)/2]` in `PanAndCarrierToStereo` took the square root of a
   tiny negative number and silently went **complex**. That complex value
   then poisoned `MinMax`/`Export`'s WAV writer, which failed with a
   `"SampledSoundList[...] contains no data that can be exported"` message
   whose text included the *entire* multi-hundred-MB array (because the
   array itself is embedded in the failure message). `PanAndCarrierToStereo`
   now `Clip`s its pan argument to `[-1,1]` defensively before the `Sqrt`,
   regardless of which mode or how the caller computed it. Karman mode's
   pan happened to be pre-clipped to `[-0.8,0.8]` (headroom absorbs
   overshoot) which is why this bug did not surface there first.

4. **`Clip[x, lo, hi]` is not valid syntax** — `Clip` takes a `{lo,hi}` pair
   as its second argument, not two separate arguments. `Clip[x, 0.0, 0.35]`
   fails with `Clip::rtwo` and `Greater::nord2`, not with a clean numeric
   result; always use `Clip[x, {lo, hi}]`.

5. **Mismatched x/y scales collapse a `Graphics`' rendered height to near
   zero.** `strouhal.gif`'s bottom panel plots Re (range ~280) against St
   (range ~0.3) — a ~933:1 data aspect ratio. Without an explicit
   `AspectRatio`, `Graphics` locks to the *data's* aspect ratio by default,
   which for an `ImageSize -> {520, 260}` canvas computes an effective
   plot height of under 1 pixel — the frame border, axis, and labels all
   collapse and overlap into an unreadable sliver with no visible box.
   Every `Graphics` call in `animate.wl` sets `AspectRatio -> height/width`
   explicitly to override this; do the same for any new panel.

## GIF/WAV duration sync (fixed post-v1.5.0)

**The bug.** All three GIFs played far shorter than their matching WAVs:
`karman.gif` measured 4.16s vs `karman_audio.wav` 45.65s (11x), `flag.gif`
4.16s vs `flag_audio.wav` 39.80s (9.6x), `strouhal.gif` 6.5s vs
`strouhal_audio.wav` 47.28s (7.3x).

**Root cause.** `AnimateKarman`/`AnimateStrouhal`/`AnimateFlag` used a
fixed frame count (32, or up to 50 for strouhal) at a fixed
`$FluidGifFrameRate` (8 fps) — the same fixed-nFrames/fixed-frameRate
pattern found across the repo, decoupled from how long the matching
sonification actually plays. Unlike lorenz (this app's reference fix),
fluid's WAVs also carry a **spoken intro** baked directly into the audio
buffer (`FluidPrependIntroAndExport` in `sonify.wl`) whose length depends
on the platform TTS engine and isn't known until it's actually
synthesised — so `model["duration"]` alone (the deterministic sim-time
value) undershoots the true WAV length by whatever the intro adds (here,
roughly 20s out of karman's 45.65s total).

**The fix.** `ExportGIF`'s frame rate is now solved from a frame-count
*budget* (150) divided by a `targetDuration` argument, clamped to
`[$FluidMinGifFps, $FluidMaxGifFps]` (2-30 fps), with the frame count
itself recomputed at the clamp boundary (`Round[frameRate *
targetDuration]`) so playback duration always lands almost exactly on
`targetDuration` — same reasoning as `lorenz/src/animate.wl`'s
`ExportAnimation` (see its header comment for the full derivation).
Because the true target duration is only known once the intro speech has
been synthesised, `FluidPrependIntroAndExport` now **returns the actual
total WAV duration** instead of `Null`, and `main.wl`/`experiments.wl`
were reordered to call `SonifyKarman`/`SonifyStrouhal`/`SonifyFlag`
*before* `AnimateKarman`/`AnimateStrouhal`/`AnimateFlag`, passing the
returned duration straight through as `targetDuration`.

**Verification (regenerated via `wolframscript -file main.wl` for all
three modes):**

| Mode | GIF before | WAV | GIF after | Ratio after |
|------|-----------|-----|-----------|-------------|
| karman | 4.16s | 45.65s | 45.00s | 0.99x |
| strouhal | 6.5s | 47.28s | 48.00s | 1.02x |
| flag | 4.16s | 39.80s | 40.50s | 1.02x |

The residual ~1-2% is GIF frame-delay quantisation (delays round to
1/100s), the same order of drift seen in lorenz's own fixed GIFs — not a
remaining bug. `tests/test_model.wl` (5/5 tests, unaffected by this
change) still passes.

## Project structure

```
fluid/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json           — default simulation parameters
  experiments.wl          — 9 curated preset invocations (RunExperiment)
  LISTENING_GUIDE.md        — user-facing recommended listening sequence
  AGENTS.md                  — this file
  src/
    model.wl                — StrouhalNumber/SheddingFrequency/SheddingInterval/
                              SheddingCirculation, BiotSavartVelocity, LiftProxy,
                              RunVortexStreet (N-vortex kinematic sim), FlagOscillator
                              (closed-form steady state), correctness checks 1-4,
                              KarmanModel/StrouhalSweepModel/FlagModel
    sonify.wl                — VectorScaleLookup, SafeInterpToAudioGrid,
                              BuildEventBurstArrayVar, PanAndCarrierToStereo,
                              Fluid*(speech helpers), SonifyKarman/SonifyStrouhal/SonifyFlag
    animate.wl                — RenderVortexFlowGraphic, AnimateKarman,
                              RenderStrouhalFrame/AnimateStrouhal (two-panel),
                              FlagShapeAt/RenderFlagFrame/AnimateFlag
    output.wl                  — ExportKarmanCSV/ExportStrouhalCSV/ExportFlagCSV
  tests/
    test_model.wl              — 5 unit tests (Strouhal chain, Biot-Savart, flag frequency)
  output/                       — generated files (gitignored)
```

## How to run

```sh
wolframscript -file fluid/main.wl                                               # karman, Re=150
wolframscript -file fluid/main.wl -- --simulation.mode=strouhal                 # Re sweep 20->300
wolframscript -file fluid/main.wl -- --simulation.mode=flag                     # flag flutter
wolframscript -file fluid/main.wl -- --simulation.fluid.Re=80                  # lower Re, cleaner tone
wolframscript -file fluid/main.wl -- --simulation.fluid.Re=250                 # higher Re, noisier
wolframscript -file fluid/main.wl -- --simulation.fluid.audio_freq_target=440  # higher pitch base
wolframscript -file fluid/main.wl -- --simulation.fluid.flag_length=10.0       # longer flag, lower flutter
wolframscript -file fluid/main.wl -- --simulation.fluid.duration=80            # longer simulation

wolframscript -file fluid/tests/test_model.wl
wolframscript -file fluid/experiments.wl
```

## Data flow

```
config.json + CLI args
        |
   LoadConfig (stem-core)
        |
   [correctness checks 1-4: StrouhalFrequencyCheck, OnsetReynoldsCheck,
    StrouhalRangeCheck, FlagFrequencyCheck -- always run, PASS/FAIL printed]
        |
        +-- karman mode:
        |     KarmanModel[cfg]          RunVortexStreet + LiftProxy; returns model
        |     ExportKarmanCSV           -> CSV
        |     AnimateKarman             -> GIF
        |     SonifyKarman              -> WAV (manual carrier + shed-event clicks)
        |
        +-- strouhal mode:
        |     StrouhalSweepModel[cfg]   Re sweep; each step re-uses RunVortexStreet +
        |                               a dedicated 40-unit StrouhalFrequencyCheck for
        |                               St_measured; returns model
        |     ExportStrouhalCSV         -> CSV
        |     AnimateStrouhal           -> GIF (two-panel: flow snapshot + St-vs-Re)
        |     SonifyStrouhal            -> WAV (per-step segments concatenated)
        |
        +-- flag mode:
              FlagModel[cfg]            FlagOscillator (closed-form steady state)
              ExportFlagCSV             -> CSV
              AnimateFlag               -> GIF
              SonifyFlag                -> WAV
```

## Model Association shapes

### `RunVortexStreet[Re, U, D, duration, nVorticesMax]`

| Key | Type | Description |
|-----|------|--------------|
| `"St"`, `"fShed"`, `"dtShed"`, `"gammaShed"` | Real | Strouhal number, shedding frequency, interval, circulation |
| `"shedTimes"`, `"shedSigns"` | List[Real] | Event record (time, +1/-1) — used by `LiftProxy` |
| `"stepHistory"` | List[List[{x,y,gamma}]] | Full per-`dtSim`-step vortex list, indexed 1..nSteps+1 |
| `"dtSim"`, `"nSteps"` | Real, Integer | Simulation step size and count (use `VortexFrameAt[sim,t]` to sample) |
| `"xShed"`, `"xMax"` | Real | Shedding x-position and domain length (20D) |

### `KarmanModel[cfg]` (adds on top of its internal `"sim"`)

`"tData"`, `"lRaw"`, `"lNorm"` (centred+normalised lift proxy), `"xCentroidData"`,
`"nPosData"`, `"nNegData"`, `"panData"`, `"pitchData"`, `"audioFreq"`, `"modeCheck"`.

### `StrouhalSweepModel[cfg]`

`"steps"` — list of per-Re Associations (`"Re"`, `"shedding"`, `"tLocal"`, `"lRaw"`,
`"fShedPredicted"`, `"fShedMeasured"`, `"stPredicted"`, `"stMeasured"`, `"sim"`,
`"onsetFlag"`), plus `"reValues"`, `"reSteps"`, `"reStart"`, `"reEnd"`, `"durationPerRe"`,
`"audioFreqTarget"`.

### `FlagModel[cfg]`

`"model"` (the `FlagOscillator` result: `"tArr"`, `"yArr"`, `"vArr"`, `"fFlag"`,
`"omega0"`, `"zeta"`), plus `"panData"`, `"pitchData"`, `"volumeData"`, `"audioFreq"`,
`"modeCheck"`.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`, `STEMHeading`,
  `STEMSection`, `STEMSay`, `STEMPrintN`, `STEMDescribeWAV`, `STEMDescribeGIF`,
  `STEMDescribeCSV`, `FmtN`, `STEMPlayCmd`, `$StemScales`, `ScaleLookup` (scalar
  form, used directly in a couple of small `Map`s), `NormalizeBuffer`,
  `ExportAudioBuffer`, `EnsureDir`, `ExportGIF`. Deliberately **not** used:
  `SonifyTrajectory`, `SpatialLayer`, `MotionLayer`, `EventLayer`, `MixLayers`,
  `RenderAudio`, `SemitoneToHz` (see design decision 1 and pitfall 1).
- **Mathematica/WL**: `NDSolve` (correctness-check integrations only — the main
  flag model itself is closed-form), `Interpolation`, `Fourier`, `Developer\`ToPackedArray`,
  `Graphics`, `Column`, `Disk`, `Point`, `Line`, `Blend`, `Export`, `SpeechSynthesize`,
  `AudioQ`, `AudioData`, `AudioSampleRate`, `RunProcess` (platform TTS fallback).

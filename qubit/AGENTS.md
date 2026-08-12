# Qubit — Agent Guide

## Project overview

Sonifies a single qubit: its Bloch-sphere representation, gate operations,
Rabi oscillation, and measurement — the foundational piece two follow-on
apps (`bell/`, `grover/`, separate sessions) build on conceptually. Three
modes:

| Mode | Physics | Output |
|------|---------|--------|
| `gates` (default) | A configurable gate sequence, each gate a continuous Bloch-vector rotation | Narrated continuous-trajectory WAV; 3D Bloch-sphere GIF/PNG with the path traced |
| `rabi` | Continuous Rabi oscillation, P(1)(t)=sin²(Ωt/2) | Pitch-glissando WAV; P(1)(t) curve PNG |
| `measurement` | Many repeated Born-rule measurements, Monte Carlo | Pitch-glissando WAV; running-frequency-convergence PNG |

Closest sibling apps: `quantum/` (same exact-QM domain — `rabi` mode is a
direct companion to `quantum/`'s own coherent-state and particle-in-a-box
modes, though the underlying state representation is completely
different, see design decision 1) and `bayes/` (`measurement` mode is the
quantum analogue of `bayes/coin`'s flip-by-flip belief update — same
Monte Carlo structure, different sonification technique, see design
decision 5).

## Key design decisions (read before modifying sonify.wl or model.wl)

### 1. State representation: a 2-vector {alpha,beta}, NOT a spatial density like `quantum/`

`quantum/`'s `QHOModel`/`BoxModel` represent state as `|psi(x,t)|^2` on a
spatial grid — appropriate there because position is the physically
meaningful continuous variable. A qubit has no position; its state lives
in a 2-dimensional complex Hilbert space, so this app represents it
directly as `{alpha, beta}` (a length-2 complex vector) and derives the
Bloch vector from it via Pauli expectation values, rather than forcing
either app's representation onto the other's problem.

### 2. Bloch-sphere convention — verified, not assumed, and consistent throughout

`|psi> = Cos[theta/2]|0> + Exp[I phi] Sin[theta/2]|1>`, giving
`r = (sin(theta)cos(phi), sin(theta)sin(phi), cos(theta))`. The build
brief for this app explicitly warned that more than one sign/phase
convention circulates for this — verified before writing any code:

- `EllipticK[0]`-style sanity check equivalent: at `theta=0`, `r=(0,0,1)`
  (matches `|0>`); at `theta=Pi`, `r=(0,0,-1)` (matches `|1>`) — confirmed
  numerically, not assumed.
- **The actual `BlochVector[alpha,beta]` implementation does NOT use
  theta/phi at all** — it uses the equivalent, phase-gauge-free Pauli
  expectation-value form: `r_x = 2 Re[Conjugate[alpha] beta]`,
  `r_y = 2 Im[Conjugate[alpha] beta]`, `r_z = |alpha|^2 - |beta|^2`.
  Verified to agree with the theta/phi form exactly (to ~1e-10) at
  several test angles before adopting it as the canonical
  implementation. This form is used everywhere in this app instead of
  the theta/phi form specifically because it works for ANY global phase
  of `alpha,beta` — the theta/phi parametrization implicitly assumes
  `alpha` is real and non-negative (a phase gauge choice), which
  `GatesTrajectory`'s intermediate states do not generally satisfy.
- `|r|=1` verified numerically for random normalized `alpha,beta`
  (several trials, arbitrary complex phases) before use — this is also
  exactly what correctness check 2 verifies, but as an actual
  application-wide invariant, not just a printed diagnostic.

### 3. Gate-to-rotation extraction: the naive antisymmetric-part formula divides by zero for THIS app's own gates

Every gate's action on the Bloch vector is a 3D rotation, extracted via
`BlochRotationMatrix[U]` (`R_ij = (1/2) Tr[sigma_i . U . sigma_j .
U^dagger]`, global-phase-invariant by construction — conjugation
`rho'=U rho U^dagger` cancels any phase on `U` automatically, so this
sidesteps ever needing to fix `U`'s phase to land in `SU(2)`).

**Extracting the rotation axis and angle from `R` is NOT one formula for
all angles.** The standard "axis proportional to `R`'s antisymmetric
part, divided by `Sin[angle]`" approach divides by (near-)zero at
`angle=Pi` — and X, Y, Z, and H are ALL exactly 180-degree rotations, so
this is not a rare edge case for this app, it is four of the six fixed
gates. `AxisAngleFromR` falls back to the symmetric-part method
(`axis.axis^T = (R+I)/2` at `angle=Pi`) whenever `angle` is within
`1e-6` of `Pi`. Verified end-to-end for all six fixed gates (apply the
gate directly via its 2x2 matrix to a test state, separately apply the
extracted 3D rotation to that state's Bloch vector, confirm they agree)
before trusting this for the `gates` mode animation. Residual precision
near `angle=Pi`: ~1e-8 (from `ArcCos`'s own ill-conditioning near
`cos=-1`, amplifying tiny input error) — irrelevant to correctness (see
decision 4), only affects animation smoothness, and is far below any
visually or audibly perceptible threshold.

### 4. None of the four correctness checks depend on the axis/angle extraction

Checks 1 and 2 act on the exact 2x2 gate matrices directly (unitarity,
and Bloch length after applying a real gate sequence via matrix
multiplication) — `AxisAngleFromR`'s ~1e-8 precision near `angle=Pi`
(decision 3) has zero bearing on either check. `AxisAngleFromR` and
`GateRotationPath` exist purely to make `gates` mode's ANIMATION and
SONIFICATION continuous rather than discretely jumping between states;
they are not part of the physics being verified.

### 5. `measurement` mode reuses `rabi`'s glissando technique, not `bayes/coin`'s spectral layering

`bayes/coin` renders its posterior as an additive-spectral layer (many
simultaneous sine partials tracing the Beta density's actual shape) plus
a discrete per-flip note layer. `measurement` mode has no evolving
DISTRIBUTION SHAPE to render this way — the true probability `|alpha|^2`
is fixed for the whole run; only the RUNNING ESTIMATE of it changes.
What actually evolves here is a single scalar (the running frequency),
exactly the same shape of problem `rabi` mode already has (a single
scalar, `P(1)(t)`, evolving over an index axis) — so `measurement` mode
reuses `rabi`'s own `BuildGlissandoBuffer` (continuous phase-accumulated
pitch tracking) directly, rather than building a second, mostly-
redundant continuous-signal technique. The connection to `bayes/coin` is
structural (`SeedRandom`'d `RandomVariate[BernoulliDistribution[...]]`
draws, running `Accumulate`) and conceptual (evidence accumulating
toward the truth), not a shared audio pipeline.

### 6. Rabi mode: pitch tracks P(1)(t), not amplitude — and this is a deliberate choice, not an arbitrary one

Rabi oscillation is fundamentally a FREQUENCY phenomenon: the entire
physical content of the effect is the drive frequency `Omega`, and the
question "how fast does the population oscillate" is a question about
*rate*, not *magnitude*. Continuous pitch bend directly encodes rate — a
listener perceives `Omega` as literally how fast the pitch wobbles up
and down — the same "the equation IS the pitch bend" logic
`compton/sweep` and `relativity/`'s chirp already establish in this
codebase for their own governing formulas. An amplitude-only mapping
would convey magnitude (how excited the qubit currently is) but not rate
nearly as directly; volume was considered and rejected for this reason.

### 7. `gates` mode's per-gate accent tone skips the first (t=0) boundary

`gatesResult["gateBoundaries"]` includes an entry for `t=0` (before any
gate has been applied) as well as one per actual gate. `GatesStereoBuffer`
starts its `Do` loop at `k=2`, not `k=1`, specifically to avoid placing a
spurious accent tone at the very start of the audio before anything has
happened — the accents mark GATE APPLICATIONS, and there is no gate
applied at `t=0`.

## Rabi formula derivation (verified two independent ways before use)

`H = -(Omega/2) sigma_x` (rotating frame, `hbar=1`), starting in `|0>`.
Since `H` is time-independent, the exact solution is
`|psi(t)> = Exp[-I H t]|psi(0)> = Exp[I (Omega t/2) sigma_x]|0>`. Using
`sigma_x^2=I`: `Exp[I theta sigma_x] = Cos[theta] I + I Sin[theta]
sigma_x`. Applied to `|0>=(1,0)` with `theta=Omega t/2`:
`|psi(t)> = (Cos[Omega t/2], I Sin[Omega t/2])`, giving
`P(1) = |I Sin[Omega t/2]|^2 = Sin[Omega t/2]^2`.

Verified two independent ways before trusting this in any check:

1. **Matrix exponentiation**: `MatrixExp[-I*H*t]` applied to `{1,0}`,
   compared against the closed form at several `t` — agree to machine
   precision (`diff=0` or `~1e-16` at every test point).
2. **Direct `NDSolve` integration** of the coupled Schrodinger equation
   for the two complex amplitudes (`I c0'[t] = H11 c0 + H12 c1`, etc.,
   from `c0(0)=1,c1(0)=0`) — agrees with the closed form to `~1e-12`.
   `RabiFormulaCheck` (correctness check 3) uses THIS method
   (`RabiSchrodingerSolve`), not the matrix-exponential method, since it
   shares no code at all with `RabiProbability1` — a genuinely
   independent verification path, not a restatement of the formula
   being checked.

## Project structure

```
qubit/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json            — default simulation parameters
  experiments.wl          — 7 curated preset invocations (gates default/Hadamard-only/
                          long sequence, rabi default/fast, measurement default/skewed)
  LISTENING_GUIDE.md       — user-facing recommended listening sequence
  AGENTS.md                 — this file
  src/
    model.wl                 — Gate matrices, BlochVector, GatesTrajectory
                          (+ BlochRotationMatrix/AxisAngleFromR/GateRotationPath for
                          the continuous rotation path), RabiProbability1/
                          RabiSchrodingerSolve, MeasurementTrials, four correctness checks
    sonify.wl                  — GatesStereoBuffer (lorenz/henon-style, via
                          SpatialLayer/MotionLayer/EventLayer/MixLayers directly —
                          see henon/'s and brownian/'s same workaround for intro-
                          prepending), BuildGlissandoBuffer (shared by rabi/measurement)
    speech.wl                   — Spoken intro synthesis and per-mode intro text
    animate.wl                    — 3D Bloch-sphere GIF/PNG (gates), 2D curve PNGs
                          (rabi, measurement)
    output.wl                     — CSV export and console summaries
  tests/
    test_model.wl                — Unit tests (gate actions, Bloch vector facts,
                          GatesTrajectory shape/invariants, Rabi formula, measurement
                          reproducibility, all four checks)
  output/                          — generated files (gitignored)
```

## Animation framing: GIF/WAV duration sync (fixed post-v1.5.0)

**The bug.** `gates` mode is the only mode with a GIF (`rabi`/`measurement`
are plot/audio-only, so they were never affected). `ExportGatesAnimation`
took hardcoded `frameRate_:10, nFrames_:80` — always exactly 8.00s of
playback — regardless of the paired WAV's actual length. Measured before
the fix: `gates_default` GIF 8.00s vs WAV 24.50s (3.06x), `gates_hadamard_only`
8.00s vs 22.14s (2.77x), `gates_long_sequence` 8.00s vs 27.48s (3.43x).

**Root cause, and why it's not the lorenz pattern verbatim.** lorenz's
WAV duration is `solution[[-1,1]]`, a physically meaningful quantity
known right after simulating. `gates` mode has no such quantity: the
*raw* sonification content (`GatesStereoBuffer`, via `SpatialLayer`/
`MotionLayer`/`EventLayer`) is resampled to a **fixed configured length**
(`sonification.duration`, 10.0s by default, from `$HardcodedDefaults` and
`config/config.json`) regardless of gate count — `Rescale` inside those
stem-core layers stretches or compresses whatever `rPath` length exists
onto that fixed window. What actually varies the WAV's *total* length
per run is the spoken intro (`BuildGatesIntroText`, naming every gate in
the sequence) prepended ahead of a 0.4s pause and the 10.0s raw buffer —
longer sequences literally take longer to narrate. So the correct sync
target isn't a property of `rPath` or of `sonification.duration` alone;
it's the actual rendered `Length[finalLeft]/sr` — the same value already
passed to `STEMDescribeWAV` — which isn't known until intro speech has
been synthesized.

**The fix.** `ExportGatesAnimation` in `src/animate.wl` now takes
`targetDuration_?NumericQ` (the caller's already-known total WAV length)
plus `nFrames_:80` as a render budget rather than a literal count, with
the same `frameRate = Clip[nFrames/targetDuration, {$MinAnimationFps,
$MaxAnimationFps}]` / `actualNFrames = Round[frameRate*targetDuration]`
scheme lorenz uses (`$MinAnimationFps=2, $MaxAnimationFps=30`, duplicated
into this file per the no-shared-src/ convention), returning
`{actualNFrames, frameRate}` for `STEMDescribeGIF`. Because the WAV's
length depends on intro-speech synthesis, `main.wl`'s gates branch had
to be **reordered** — audio ([4/5]) now runs before animation ([5/5]),
the reverse of before — so `totalDurSec` exists before `ExportGatesAnimation`
is called. `experiments.wl`'s `RunExperiment` already synthesized audio
before calling `ExportGatesAnimation`, so it only needed the new
`targetDuration` argument, not reordering.

**Verified after the fix** (same GIF/WAV pairs, PIL `ImageSequence` frame
durations vs `wave` module frame count): `gates_default` 24.80s vs
24.50s WAV (0.988x), `gates_hadamard_only` 22.40s vs 22.14s (0.988x),
`gates_long_sequence` 30.40s vs 30.38s (1.000x). The residual ~1-2% gap
is GIF's own per-frame duration field being quantized to integer
centiseconds — an inherent format limit, not an app bug, matching the
same residual lorenz's reference fix leaves.

## How to run

```sh
wolframscript -file main.wl                                            # gates, H-T-H-S-X from |0>
wolframscript -file main.wl -- --simulation.mode=rabi                   # Rabi oscillation, Omega=1.5
wolframscript -file main.wl -- --simulation.mode=measurement            # 2000 Born-rule measurements
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks

All four run unconditionally, every invocation, regardless of mode,
always at canonical parameters (Omega=1.5 for the Rabi check, a fixed
representative superposition for the Born-rule check):

1. **Gate unitarity** — `U^dagger U = I` for all 6 fixed gates plus 3
   representative rotation angles. Exact relation, tight tolerance.
2. **Bloch length conservation** — a 7-gate sequence applied in a row,
   `|r|=1` verified after EVERY gate, not just the final state. Exact
   relation, tight tolerance.
3. **Rabi formula** — the closed form vs. `RabiSchrodingerSolve`'s
   independent `NDSolve` integration (see derivation above). Exact
   relation, tight tolerance.
4. **Born rule via Monte Carlo** — empirical measurement frequency vs.
   `|alpha|^2` over 20000 trials, tolerance sized as a binomial
   standard-error band (`>=4 sigma`, matching `scattering/`'s check 4
   convention), not an arbitrary flat percentage.

## Common pitfalls

1. **`tolerance_?NumericQ:0.05`-style optional-argument patterns parse
   WRONG** in WL — binds as `tolerance_ ? (NumericQ:0.05)`, not
   `Optional[tolerance_?NumericQ, 0.05]`. Same pitfall documented in
   every prior v1.5.0 app's `AGENTS.md`; this app avoids it by
   using plain `Optional[x_?NumericQ, default]` or dropping the test
   (`x_:default`) throughout.
2. **`ToString[x]` on a machine real keeps only ~6 significant digits**
   — `ToString[2.0*Pi]` gives `"6.28319"`, not the full value. A test
   that round-trips a computed angle through a `"Rz:" <> ToString[angle]`
   gate-spec string and back via `ToExpression[]` will silently lose
   precision (discovered when a `Rz(2 Pi) = -identity` test failed with
   a `~2.3e-6` residual instead of the expected `~1e-16`) unless you use
   `ToString[x, InputForm]` instead, which round-trips exactly. Only
   matters for code that CONSTRUCTS gate-spec strings from computed
   numbers (tests, mainly) — config.json's own gate sequences are
   already plain JSON strings and don't go through this conversion.
3. **The naive axis-extraction-from-rotation-matrix formula divides by
   zero at `angle=Pi`** — see design decision 3. If you add a new fixed
   gate that happens to also be a 180-degree rotation (many single-qubit
   gates are), `AxisAngleFromR`'s existing `Pi`-fallback branch already
   handles it; don't revert to the single-formula version.
4. **`gateBoundaries` has one more entry than the gate count** (it
   includes the `t=0` starting boundary) — see design decision 7 for why
   `GatesStereoBuffer`'s accent-tone loop starts at index 2, not 1.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `SpatialLayer`, `MotionLayer`, `EventLayer`, `MixLayers` (`gates` mode,
  called directly rather than via `SonifyTrajectory` — see henon/'s and
  brownian/'s identical workaround), `StemSynthNote` (accent tones),
  `STEMHeading`, `STEMSection`, `STEMSay`, `STEMPrintN`, `STEMDescribeWAV`,
  `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`, `STEMPlayCmd`,
  `NormalizeBuffer`, `ExportGIF`, `ExportCSV`, `EnsureDir`.
- **Mathematica/WL**: `MatrixExp`, `ConjugateTranspose`, `RotationMatrix`
  (gate/rotation math), `NDSolve` (independent Rabi verification),
  `RandomVariate`/`BernoulliDistribution` (measurement Monte Carlo),
  `Accumulate`/`Interpolation` (running-frequency and glissando curves),
  `Graphics3D`/`Sphere` (Bloch sphere rendering), `Sound`,
  `SampledSoundList`, `Export`, `SpeechSynthesize`, `AudioQ`, `AudioData`,
  `AudioSampleRate`, `RunProcess` (platform TTS fallback), `Import`
  (reading TTS-generated WAV files).

## Speech synthesis note

`speech.wl`'s three-tier fallback (`SpeechSynthesize[]` -> platform TTS
-> text-only `STEMSay`) duplicates the pattern already used in
`henon/src/speech.wl`, `brownian/src/speech.wl`, and every other app's
`speech.wl` file — still out of scope for stem-core consolidation per
every prior app's own build spec.

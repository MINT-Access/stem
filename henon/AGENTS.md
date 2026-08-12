# Hénon — Agent Guide

## Project overview

Sonifies the Hénon map (Michel Hénon, 1976): `x_{n+1} = 1 - a x_n^2 + y_n`,
`y_{n+1} = b x_n`. Hénon built this as the simplest 2D invertible map that
still reproduces the essential dynamics of a Poincaré section through the
Lorenz attractor — a genuine, concrete historical link to `lorenz/` already
in this codebase. Three modes:

| Mode | Physics | Output |
|------|---------|--------|
| `attractor` (default) | Settled trajectory at canonical a=1.4, b=0.3 | Narrated continuous-trajectory WAV; growing point-cloud GIF; static PNG |
| `sweep` | Parameter `a` sweeps 0.2-1.4 (b=0.3 fixed): the full period-doubling route to chaos | Discrete-note WAV with 3 landmark events; bifurcation-diagram GIF/PNG |
| `reverse` | Forward segment, reversed replay, short exact-inverse demonstration | Discrete-note WAV with 2 marker events; 3-colour-coded overlay PNG |

Closest sibling apps: `lorenz/` (the map's own historical origin, and the
continuous-trajectory sonification technique `attractor` mode reuses
directly) and `dynamical/` (the discrete-note-per-iterate idiom `sweep` and
`reverse` reuse, and the general shape of a period-doubling correctness
audit).

## Key design decisions (read before modifying sonify.wl or model.wl)

### 1. `attractor` reuses lorenz/'s technique; `sweep`/`reverse` reuse dynamical/'s — deliberately, not inconsistently

This app has THREE modes and uses TWO different sonification techniques,
split for a reason, not by accident:

- **`attractor`** calls stem-core's `SpatialLayer`/`MotionLayer`/`EventLayer`
  -> `MixLayers` directly (the same layers `SonifyTrajectory` calls
  internally, but called by hand here — see design decision 2 for why) on a
  `{t,x,y,z,speed}` matrix built from the settled trajectory, exactly
  `lorenz/src/sonify.wl`'s technique. This is the right tool when the point
  is the continuous, flowing character of riding an attractor: pan and
  pitch interpolate smoothly sample-to-sample, and stem-core's built-in
  "apex" event detector fires on local turning points automatically.
- **`sweep`** and **`reverse`** instead use `dynamical/`'s discrete
  note-per-point idiom: `StemSynthNote` bursts Part-assigned directly into
  pre-allocated stereo buffers at precise attack times. This is the right
  tool when individual iterates — and specifically their PERIOD — must be
  audibly countable. `sweep`'s entire narrative is "how many notes before
  it repeats?", which a continuous interpolated pitch curve cannot convey;
  a listener needs to hear one, two, four, eight discrete notes per cycle.
  `reverse` borrows the same idiom for the same reason: the three phases
  (forward/reversed/inverse-demo) need to read as distinguishable NOTE
  SEQUENCES, not a single continuous curve that happens to fold back.

Do not "fix" this by making `sweep` use `SonifyTrajectory` for consistency
with `attractor` — the periodicity would become inaudible. Do not make
`attractor` use discrete notes either — the fractal, continuously-folding
character of riding the attractor is the entire point of that mode, and a
handful of Hénon-map-per-step's already-full attractor trajectory would
produce a smoother experience through `SonifyTrajectory`'s spline
interpolation than any discrete-note idiom could.

### 2. `attractor` calls the three sonification layers directly, not the one-shot `SonifyTrajectory[..., filePath]`

`SonifyTrajectory[trajectory, cfg, filePath, eventTypes]` writes straight to
disk via `RenderAudio` and returns only a file path — no way to prepend a
spoken intro buffer afterwards. `lorenz/main.wl` never needed this (it never
prepends spoken intros). Since every mode in this app DOES prepend one (see
design decision 5), `AttractorStereoBuffer` in `src/sonify.wl` instead calls
`SpatialLayer`/`MotionLayer`/`EventLayer` -> `MixLayers` directly and
returns the `{left,right}` arrays, exactly the same workaround
`montecarlo/src/sonify.wl` uses for the same reason. `main.wl` prepends the
intro buffer, then exports once.

### 3. Column mapping for `attractor` mode: x->pan, y->pitch, NOT "position drives pan, something else drives pitch" in the abstract

stem-core's `SpatialLayer` defaults are `pan_axis="x"`, `pitch_axis="y"`
(configurable, but `lorenz/config.json` only overrides `pan_axis` — matching
the default anyway — and leaves `pitch_axis` at its default). Speed drives
VOLUME, not pitch (`MixLayers`' `amp = 10^(vol/20)`) — despite an earlier,
looser reading of stem-core's docs that speed drives pitch, the actual
`sonification.wl` source (re-verified while building this app) shows
`pitchAxis` defaults to `"y"` and volume comes from `speed`.

This app follows the identical convention: Hénon's `x_n` feeds the
trajectory's `x` column (drives pan), `y_n` feeds the `y` column (drives
pitch AND the default "apex" event detector, which fires on local maxima of
`|y|`). Since `y_n = b*x_{n-1}` is just a scaled, one-step-lagged copy of
`x_n`, pitch and apex events both end up tracking the same underlying
folding structure a listener would expect — this is not a coincidence,
it's why `y` was a sensible choice for both roles simultaneously. `z` is
unused (Hénon is a 2D map, not 3D like Lorenz) and set to 0 throughout.
Speed is a genuine 2D finite-difference speed (`sqrt(vx^2+vy^2)`, collapsed
from lorenz's 3D `sqrt(vx^2+vy^2+vz^2)`), driving volume exactly as in
`lorenz/`.

### 4. `sweep` mode's pitch/pan mapping is the OPPOSITE of `attractor`'s — also deliberate

`sweep` (and `reverse`, which reuses the same synthesiser) map `x` to
PITCH and `y` to PAN — the reverse of `attractor`'s x->pan/y->pitch. This
follows the task's own "second spatial dimension -> stereo" convention for
discrete-note idioms (matching how a 1D map like `dynamical/`'s logistic
map uses its single value for BOTH pitch and pan simultaneously; a 2D map
naturally splits its two values across the two channels instead, and `x`
carries the map's larger-magnitude, more dramatic swings — full range
roughly [-1.5, 1.5] vs `y`'s roughly [-0.45, 0.45] since `y=b*x_prev` with
`b=0.3` — so pitch, the more attention-grabbing channel, was given the
bigger signal). This is not an oversight relative to `attractor`'s mapping;
the two modes have different sonification techniques (design decision 1)
and there's no requirement that a discrete-note idiom mirror a continuous
one's axis choices.

### 5. Every mode prepends a spoken intro — `attractor` needed a workaround to make that possible (see decision 2); `sweep`/`reverse` do not

`sweep` and `reverse` build their stereo buffers directly via
`SynthesizeDiscreteNotesHenon`, already returning arrays (no `RenderAudio`
call in the discrete-note path at all), so prepending an intro there is the
same straightforward `Join[introBuffer, pauseBuffer, mainBuffer]` pattern
`dynamical/main.wl` uses.

### 6. Correctness checks always run at canonical (a,b)=(1.4,0.3), independent of the active mode's configured parameters

Matches `dynamical/main.wl`'s own convention: its `FixedPointCheck`,
`Period2Check`, and `LyapunovCheck` all run at their own hardcoded r values
(2.8, 3.2, 4.0) regardless of whatever r the actual run configures. Here,
checks 1 (constant Jacobian), 2 (Lyapunov sum), and 4 (inverse exactness)
are true for ANY (a,b) — but check 3 (the ~0.42 literature benchmark) is
only meaningful AT the canonical parameters, and `sweep` mode doesn't even
have a single `a` value to check against. Running all four checks at fixed
canonical values every invocation, regardless of mode, avoids that
ambiguity entirely and keeps the four checks' printed output identical
across all three modes.

### 7. Checks 1, 2, and 4 use tight tolerances; check 3 uses a deliberately generous one — and this is not an oversight

- **Check 1 (Jacobian determinant)**: `det = -b` is an EXACT algebraic
  identity, true for every `(x,y)` in the plane (the `x`-dependent term
  cancels identically — see `HenonJacobianAt`'s comment). Verified at
  several ARBITRARY points, not points on the attractor, since the fact
  being tested has nothing to do with the attractor specifically. Tight
  tolerance (`1e-9`) is appropriate: any larger deviation is a code bug,
  not numerical noise (observed max error in practice: ~5.5e-17).
- **Check 2 (Lyapunov sum)**: `lambda1+lambda2 = log(b)` is a direct
  algebraic CONSEQUENCE of check 1 (the sum of Lyapunov exponents equals
  the time-average log of the absolute Jacobian determinant, which here is
  the CONSTANT `log(b)`). Also an exact relation; also tight tolerance
  (`1e-6`, looser than check 1 only because it accumulates floating-point
  noise over 50,000 QR-decomposition steps — observed max error in
  practice: ~1.1e-15, well inside tolerance).
- **Check 3 (largest Lyapunov benchmark)**: the `~0.42` figure is an
  EMPIRICAL literature value that itself carries estimation uncertainty,
  and our own estimate depends on iteration count, transient length, and
  starting point. Generous tolerance (30% relative) deliberately — the
  check only needs to confirm "positive, and in the right neighbourhood."
  Kept as a SEPARATE check from #2 specifically so the two tolerance
  philosophies (exact relation vs. empirical benchmark) are never blurred
  into one pass/fail, per the build spec's explicit instruction.
- **Check 4 (inverse map exactness)**: forward-then-inverse on random test
  points is an exact algebraic identity (holds for ANY `(x,y)`, on or off
  the attractor), same reasoning and same tight tolerance (`1e-9`) as
  check 1 (observed max error in practice: ~4.6e-16).

All four are diagnostic-only (print `[PASS]`/`[FAIL]`, never `Exit[1]`),
per `blackbody/AGENTS.md`'s convention as corrected in `compton/AGENTS.md`
— none of them gate a numerically-integrated trajectory's runtime health
(this app has no `NDSolve` at all; every trajectory is a discrete map
iteration), they verify closed-form/algebraic facts at hand-picked or
random test points.

### 8. The `reverse` mode's inverse formula is applied for a HANDFUL of steps only — this is a hard boundary, not a style choice

The forward map is area-CONTRACTING (`|det J| = b = 0.3 < 1`, dissipative),
so the inverse map is area-EXPANDING by the same factor: floating-point
error that the forward map suppresses at rate `b` per step, the inverse
map amplifies at rate `1/b` per step. Empirically, applying
`HenonMapInverse` 10 times in a row (the default `reverse_steps`) amplifies
starting error from ~1e-16 (machine epsilon) to ~2e-11 — a factor of
`(1/0.3)^10 ≈ 1.7e5`, matching the theoretical amplification rate almost
exactly. This is still comfortably "near machine precision" for a 10-step
demonstration. It would NOT still be true for hundreds of steps: at 50
steps the same arithmetic predicts amplification by `(1/0.3)^50 ≈ 1.8e26`
— utterly swamping the original signal. This is why `reverse` mode:

- replays the reversed segment via simple `Reverse[]` (exact, no
  arithmetic re-derivation, no error amplification at all), and
- applies the actual inverse-map FORMULA only to the last
  `reverse_steps` (default 10) points, as a deliberately short,
  clearly-labelled "proof of invertibility" demonstration.

Do NOT extend `reverse_steps` far beyond ~10-15 expecting a longer
faithful "reverse trajectory" — the numbers will still print, but they
will no longer mean what the mode's own framing claims they mean. If you
need to demonstrate this boundary explicitly, `PrintReverseSummary`
already reports the actual round-trip error achieved, which grows visibly
with `reverse_steps`.

### 9. Sweep bifurcation landmarks are located empirically, not assumed from logistic-map intuition — and the first one has an exact closed form

A coarse scan (`a` from 0.2 to 1.42 in steps of 0.02, `b=0.3` fixed,
classifying the settled period from a 300-point tail) located the entire
cascade before any bounds were hardcoded:

| Landmark | a-value | How located |
|---|---|---|
| Period 1 -> 2 (first flip bifurcation) | 0.3675 | EXACT closed form `3(1-b)^2/4`, derived from the fixed-point eigenvalue crossing -1, cross-verified via `FindRoot` on the simultaneous system |
| Period 2 -> 4 | 0.9108 | Empirical bisection (`BisectPeriodDoubling`) |
| Period 4 -> 8 | 1.0252 | Empirical bisection |
| Onset of chaos (period 8 -> aperiodic) | 1.0508 | Empirical bisection |
| Period-7 window inside the chaotic band | 1.227 | Empirical fine-grid scan for the LOWEST settled period in `[1.18,1.34]` (`FindPeriodicWindowA`) |

The period-7 window is this app's `dynamical/`-`period3_window` analogue:
an "island of order" narrative beat inside an otherwise chaotic sweep,
located the same way dynamical's own AGENTS.md documents its r=3.830 choice
— by actually running the numbers, not by assuming a textbook value
transfers. (There is no textbook value to assume here in the first place;
Hénon's period-doubling structure at b=0.3 isn't as commonly tabulated as
the logistic map's.) The ratio of successive bifurcation gaps
`(a2-a1)/(a3-a2) ≈ 4.75` sits within ~2% of the universal Feigenbaum
constant 4.6692 — printed as an informational figure in the sweep summary
(NOT one of the four gating correctness checks), confirming this is a
genuine period-doubling cascade in the same universality class as the
logistic map, computed rather than assumed.

### 10. Box-counting dimension is diagnostic-only, never a pass/fail check

`BoxCountingDimension` estimates the attractor's fractal dimension via a
least-squares fit of `log N(eps)` vs `log eps` across ~9 geometrically-
spaced box sizes. At the canonical parameters with ~2000-4000 attractor
points, this returns approximately 1.15-1.25 — in the right neighbourhood
of the commonly-cited ~1.25-1.28 (usually obtained via the more
sample-efficient correlation-dimension method, which this app does NOT
implement), but box-counting from a finite point set has real
methodological uncertainty (epsilon range choice, grid alignment, finite
N) that a correlation-dimension estimate from the same data would resolve
differently. Printed as an informational figure alongside the attractor
summary, never gated.

## Project structure

```
henon/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json           — default simulation parameters
  experiments.wl         — 7 curated preset invocations (attractor, sweep, reverse,
                          2 sweep zooms, a weakly-dissipative attractor, a longer
                          reverse-mode demo)
  LISTENING_GUIDE.md      — user-facing recommended listening sequence
  AGENTS.md                — this file
  src/
    model.wl                — HenonMap/HenonMapInverse, HenonJacobianAt/DetAt,
                          HenonFixedPointX, FirstFlipBifurcationA (+closed form),
                          ClassifyPeriod, BisectPeriodDoubling, FindPeriodicWindowA,
                          HenonSweepLandmarks, HenonLyapunovExponents (QR method),
                          BoxCountingDimension, four correctness checks,
                          HenonAttractorModel/HenonSweepModel/HenonReverseModel
    sonify.wl                 — BuildAttractorTrajectory + AttractorStereoBuffer
                          (lorenz-style, via SpatialLayer/MotionLayer/EventLayer/
                          MixLayers directly — see decision 2), SynthesizeDiscreteNotesHenon
                          + SonifySweep/SonifyReverse (dynamical-style discrete notes)
    speech.wl                  — Spoken intro synthesis (SpeechSynthesize -> platform
                          TTS -> text-only fallback), BuildXIntroText per mode
    animate.wl                   — attractor point-cloud GIF/PNG, sweep bifurcation-diagram
                          GIF/PNG, reverse three-phase overlay PNG
    output.wl                     — Export*CSV per mode, Print*Summary per mode
  tests/
    test_model.wl               — unit tests (map/inverse, Jacobian, fixed point,
                          bifurcation landmarks, Lyapunov exponents, all four checks,
                          mode data-assembly shapes, dimension estimate sanity range)
  output/                      — generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                          # attractor, canonical a=1.4,b=0.3
wolframscript -file main.wl -- --simulation.mode=sweep                # full period-doubling sweep
wolframscript -file main.wl -- --simulation.mode=reverse               # forward/reversed/inverse-demo
wolframscript -file main.wl -- --simulation.henon.a=1.05 --simulation.henon.b=0.5   # weakly-dissipative attractor (b alone, unadjusted a, diverges — see decision 8-adjacent pitfall)
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks

All four run unconditionally, every invocation, regardless of mode, always
at canonical (a,b)=(1.4,0.3) (see design decision 6 for why):

1. **Constant Jacobian determinant** — `det = -b` at several arbitrary
   (off-attractor) points, tight tolerance.
2. **Lyapunov exponent sum** — `lambda1+lambda2 = log(b)`, tight tolerance.
3. **Largest Lyapunov exponent** — positive, within 30% of the ~0.42
   literature benchmark, generous tolerance (see design decision 7).
4. **Inverse map exactness** — forward-then-inverse round trip on random
   test points, tight tolerance.

## Common pitfalls

1. **`step_?NumericQ:0.001` in a function signature parses WRONG** — it
   binds as `step_ ? (NumericQ:0.001)`, a `PatternTest` against
   `Optional[NumericQ,0.001]`, not `Optional[step_?NumericQ, 0.001]` as
   intended. The pattern silently never matches any call (the DownValue
   exists but the head never fires), so `FindPeriodicWindowA[...]` etc.
   return unevaluated symbolic expressions with NO error message — this
   is easy to miss since nothing looks obviously wrong until you print the
   result and see the function call staring back at you. Fix: drop the
   `?NumericQ` test on any optional parameter (`step_:0.001`), or wrap the
   whole pattern explicitly. Caught by testing `FindPeriodicWindowA[...]`
   directly right after writing it, rather than trusting it silently
   inside `HenonSweepLandmarks`.
2. **A stray `*)` inside a prose comment silently truncates it** — a
   comment describing the fixed-point substitution originally read
   `...y*=b x* into x*=1-a x*^2+y*). Exact...`, where `+y*)` reads as the
   comment's own closing `*)`, turning the rest of the sentence into
   top-level code and producing a syntax error at a DIFFERENT line than
   the actual mistake. Same failure mode documented in
   `blackbody/AGENTS.md` and `compton/AGENTS.md`; fixed here by writing
   fixed-point notation as `x_fp` instead of `x*` in comments.
3. **Bare `Graphics[...]` with an extreme x:y data-range aspect ratio
   renders squished unless `AspectRatio` is set explicitly.** The
   canonical Hénon attractor's own bounding box is naturally very wide and
   flat (x spans roughly [-1.3,1.3], y only [-0.4,0.4] since y=b*x_prev
   with b=0.3) — this is NOT a plotting bug when you see it, it's the
   real shape of the attractor, but `AspectRatio -> Automatic` (not the
   Graphics default of `1/GoldenRatio`) is required so the export
   actually shows that real shape rather than squishing/distorting it.
   The `sweep` bifurcation diagram needed the opposite fix: its guide
   lines were originally drawn at a hardcoded `{-3,3}` y-extent, which
   then dominated `PlotRange -> All` and squished the actual attractor
   data (which only spans about `[-1.3,1.3]`) into a thin central band —
   fixed by computing the real y-range from the data first and drawing
   guide lines to match it, not a fixed constant. Caught by actually
   rendering and viewing the PNGs during development, not by inspecting
   the code.
4. **Chaotic-map iterates should NOT be connected with a path line across
   an entire segment** — an early draft of `reverse` mode's PNG drew a
   line through all ~40 consecutive forward-segment points, producing a
   tangle of crossing diagonals (adjacent iterates of a chaotic map are
   NOT adjacent in (x,y) space — that is what "chaotic" means). Fixed by
   only connecting the short highlighted subsequence actually used in the
   inverse-map demonstration (10-11 points, small enough to read as a
   path) and leaving the rest as unconnected scatter points.
5. **`Animate*` functions return their actual rendered frame count**, not
   the requested `nFrames` — `main.wl` passes `aSteps - 1` (the actual
   number of bifurcation-diagram frames rendered, since frame 1 is
   skipped) to `STEMDescribeGIF` for `sweep` mode, matching what
   `AnimateSweepBifurcation` actually produces.
6. **`NumericQ[Overflow[]]` and `NumberQ[Overflow[]]` are BOTH `True`** —
   WL's floating-point-overflow tag passes the exact predicates you'd
   reach for to detect it, so `VectorQ[pt, NumericQ]` or a bare
   `Max[Abs[pt]] < limit` comparison silently do NOT catch a diverged
   trajectory: the comparison itself returns unevaluated (WL can't order
   `Overflow[]` against a number, raising `Max::nord` but not producing
   `True`/`False`), and an `If` on a non-boolean condition just stays
   unevaluated too, letting execution fall through into whatever comes
   next with garbage data — this is exactly what happened during
   development when testing an (a,b) pair that diverges (see design
   decision 9's boundedness note): the correctness checks and mode
   header printed fine, then the run silently produced megabytes of
   cascading `Rescale`/`Accumulate` "unequal length" messages instead of
   a clean error. `TrajectoryIsBounded` in `model.wl` instead uses
   `FreeQ[pt, Overflow[] | Underflow[] | Indeterminate | ComplexInfinity
   | DirectedInfinity[___]]` first — `FreeQ` correctly distinguishes the
   symbolic head regardless of what predicates think of it — AND ONLY
   THEN compares magnitude. If you add another boundedness-style guard
   anywhere in this app, use the same `FreeQ`-first pattern, not a
   predicate check alone.

## GIF/WAV duration sync (fixed post-v1.5.0)

**The bug.** `henon_attractor.gif` measured 8.0s vs `henon_attractor.wav`
28.57s (3.6x); `henon_sweep.gif` 19.92s vs `henon_sweep.wav` 140.33s
(7.0x). Preset-derived GIFs showed the same pattern
(`attractor_weakly_dissipative.gif` 8.0s vs 28.72s;
`sweep_cascade_zoom.gif`/`sweep_chaos_zoom.gif` 11.92s vs ~74.3s each).

**Root cause.** `ExportAttractorAnimation` and `AnimateSweepBifurcation`
exported at a fixed 12 fps with a frame count tied only to the number of
discrete simulated states (100 evenly-spaced trajectory points for
attractor mode; `a_steps - 1` for sweep mode) — the same
fixed-nFrames/fixed-frameRate pattern found repo-wide, decoupled from
how long the matching WAV actually plays. Both modes' WAVs also carry a
spoken intro baked directly into the audio buffer (`BuildIntroBuffer` in
`speech.wl`, prepended in `main.wl`/`experiments.wl`) whose length isn't
known until the platform TTS engine actually renders it — for attractor
mode this intro (a full descriptive sentence) is longer than the 10s
core sonification itself (`sonification.duration`'s global default),
which is why the mismatch is dominated by intro length, not just frame
count. Note: Hénon is a discrete map, not an ODE — there is no
`solution[[-1,1]]`-style continuous simulated time to size a GIF against;
the correct sync target here is the WAV's own actual total sample count.

**The fix.** Both `Animate*` functions now take a `targetDuration`
argument and solve `frameRate` from a frame-count *budget* (150) divided
by `targetDuration`, clamped to `[$HenonMinGifFps, $HenonMaxGifFps]`
(2-30 fps), with the frame count recomputed at the clamp boundary so
playback duration lands almost exactly on `targetDuration` — same
reasoning as `lorenz/src/animate.wl`'s `ExportAnimation`. Sweep mode has
only `a_steps` discrete bifurcation-diagram states (no "in between"
values); when the render budget forces more frames than that (as it does
at the `$HenonMinGifFps` floor for a ~140s sweep), `Subdivide`'s
rounding holds a state across several consecutive frames rather than
erroring — the same handling `fluid/AnimateStrouhal` uses. Because the
true duration is only known once the intro speech is synthesised,
`main.wl` was reordered to build the WAV *before* rendering the GIF
for both modes, passing the WAV's actual total sample count `/ sr`
straight through as `targetDuration`; `experiments.wl` already built
audio before animating and only needed the value threaded into its
`ExportAttractorAnimation`/`AnimateSweepBifurcation` calls. `reverse`
mode has no GIF (PNG only) and was untouched.

**Verification (regenerated via `wolframscript -file main.wl` for both
modes, plus 5 experiment presets via `experiments.wl`):**

| Output | GIF before | WAV | GIF after | Ratio after |
|--------|-----------|-----|-----------|-------------|
| henon_attractor | 8.0s | 28.57s | 28.50s | 1.00x |
| henon_sweep | 19.92s | 140.33s | 140.50s | 1.00x |
| attractor_weakly_dissipative | 8.0s | 28.72s | 28.50s | 0.99x |
| sweep_cascade_zoom | 11.92s | 74.34s | 75.00s | 1.01x |
| sweep_chaos_zoom | 11.92s | 74.24s | 73.50s | 0.99x |

`tests/test_model.wl` (39/39 tests, unaffected by this change) still
passes.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `SpatialLayer`, `MotionLayer`, `EventLayer`, `MixLayers` (attractor mode,
  called directly rather than via `SonifyTrajectory` — see decision 2),
  `ScaleLookup`, `SemitoneToHz`, `StemSynthNote` (sweep/reverse discrete
  notes), `STEMHeading`, `STEMSection`, `STEMSay`, `STEMPrintN`,
  `STEMDescribeWAV`, `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`,
  `STEMPlayCmd`, `NormalizeBuffer`, `ExportGIF`, `ExportCSV`, `EnsureDir`.
- **Mathematica/WL**: `QRDecomposition` (Lyapunov exponents — WL convention
  `m == q.r`, `q` orthogonal, `r` upper-triangular; verified interactively
  before use, not assumed from memory), `FindRoot` (first bifurcation),
  `NestList` (trajectory iteration and the inverse-demo backward walk),
  `Sound`, `SampledSoundList`, `Graphics`, `Export`, `SpeechSynthesize`,
  `AudioQ`, `AudioData`, `AudioSampleRate`, `RunProcess` (platform TTS
  fallback), `Import` (reading TTS-generated WAV files).

## Speech synthesis note

`speech.wl`'s three-tier fallback (`SpeechSynthesize[]` -> platform TTS ->
text-only `STEMSay`) duplicates the pattern already used in
`dynamical/src/speech.wl` and several other apps' `speech.wl` files — still
out of scope for stem-core consolidation per every prior app's own build
spec.

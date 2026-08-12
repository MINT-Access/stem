# CLT — Agent Guide

## Project overview

Sonifies the Central Limit Theorem across three modes:

| Mode | Physics/statistics | Output |
|------|---------|--------|
| `sweep` (default) | Raw sample mean of N draws from one source | Narrowing-and-smoothing WAV; animated histogram GIF; small-multiple PNG |
| `compare` | Binaural: two sources' STANDARDIZED means | Shape-convergence WAV; overlaid-densities GIF/PNG |
| `dice` | Raw SUM of N fair dice (not mean) | Flat-to-bell WAV; animated bar-chart GIF; classic small-multiple PNG |

Closest sibling apps: `thermo/` and `bayes/` (the additive-spectral-
synthesis technique — discretise a density over `nBins` points on a
fixed domain, weight simultaneous sine partials by density — is reused
directly from both) and `montecarlo/` (this codebase's established
Monte Carlo sampling/seeding conventions).

## Key design decisions (read before modifying sonify.wl or model.wl)

### 1. Two distinct facts, deliberately never conflated

"The sample mean narrows and its shape converges to Gaussian" is
actually TWO separate facts bundled into one sentence, and this app
keeps them apart on purpose:

- **Variance scaling** (`Var(mean)=sigma^2/N`) is exact for any N —
  nothing asymptotic, nothing about shape.
- **The Central Limit Theorem itself** is about SHAPE convergence as
  N→∞, and says nothing about how fast the variance shrinks.

`sweep` mode sonifies the RAW mean, where both facts are simultaneously
and correctly true together (the one quantity honest for that framing).
`compare` mode sonifies the STANDARDIZED mean
`(mean-mu)/(sigma/Sqrt[N])`, which by construction has variance
EXACTLY 1 at every N — it never narrows, only symmetrises — isolating
fact 2 alone, appropriate for a mode whose whole point is comparing
shape convergence independent of each source's own scale. These are
two deliberately different choices for two different pedagogical
points, not an inconsistency between the two modes — do not "fix"
`compare` mode to use the raw mean; that would make two sources with
wildly different variances (e.g. Exponential(1)'s variance=1 vs.
Uniform(0,1)'s variance=1/12) impossible to compare on a shared
frequency domain in any meaningful way.

### 2. Correctness checks are built against EXACT, independently-derivable references — never the app's own formula

Per this app's build spec, itself citing a lesson from this codebase's
ongoing correctness audit (`cosmology/AGENTS.md`'s flat-sky sky-map
generation section): a correctness check that shares its formula with
the code it checks can pass while BOTH are wrong (cosmology's own sky-
variance check originally shared a missing factor of N with its
generator, and both silently agreed on the wrong answer). Every one of
this app's four checks avoids that trap specifically:

- **Variance scaling** uses the source's own hand-verified EXACT
  `sigma^2` (1/12 for Uniform(0,1)), not a value computed from this
  check's own Monte Carlo sample.
- **Irwin-Hall** uses a closed-form combinatorial PDF implemented
  independently of `HistogramSpectrumBins` (the function it validates),
  verified itself (integral=1, matches a large MC sample) before being
  trusted as ground truth.
- **Dice combinatorics** uses 6/36=1/6, an elementary fact checkable by
  hand-enumeration, not derived from `SampleDiceSumN`.
- **Kurtosis decay** uses `Kurtosis[UniformDistribution[{0,1}]]-3` and
  `Kurtosis[ExponentialDistribution[1]]-3` — WL's own closed-form
  symbolic distribution moments, verified directly (`-6/5` and `6`
  respectively) rather than hand-derived or restated from this app's
  sampling code.

None of the four abort on failure — this is the same diagnostic-only
reasoning `blackbody/AGENTS.md` section 3 (as corrected in
`compton/AGENTS.md`) gives: these checks test closed-form/combinatorial
facts and Monte Carlo convergence, not the runtime health of a
numerical integration, so a hard gate would only ever catch a code bug
a unit test already catches at development time.

### 3. `compare` mode's channel assignment: a fixed convention, verified to agree across three files

`sourceLeft` is ALWAYS panned hard left (`pan=-1`), `sourceRight` ALWAYS
hard right (`pan=+1`) — a literal fixed constant per source, not a
derived/computed value, so there is no sign-convention ambiguity for a
formula error to hide in (the same "fixed literal, not a derived
quantity" reasoning `quantum_tunnelling/AGENTS.md` design decision 7
gives for its own reflected/transmitted pan assignment). This matters
here specifically because `compton/AGENTS.md` design decision 8
documents a REAL bug of exactly this shape (a computed value silently
using the wrong sign, contradicting its own docstring) caught only
because two different consumers disagreed with each other. This app's
three consumers of the left/right assignment — `sonify.wl`'s
`BuildCompareAudio` (audio pan), `animate.wl`'s `RenderCompareFrame`/
`RenderCompareStaticPNG` (which histogram/colour goes in which visual
role), and `output.wl`'s `ExportCompareCSV` (column order:
`left_source`/`left_mean`/... then `right_source`/`right_mean`/...) —
were verified BY INSPECTION to agree on this same assignment while
writing this app, not assumed to agree because the code "should" be
consistent. If you add a fourth consumer, verify it the same way.

### 4. Display domains are fixed per-run, and the "widest case" is DIFFERENT depending on the mode

All three modes fix their sonification/visualisation domain ONCE at
the start of the run (never re-derived per N step) — the same
reasoning `bayes/`'s `MuSpectrumBins` gives for its fixed `muLo`/`muHi`:
a pitch shift is only meaningful if the frequency<->value mapping
stays consistent across the whole sweep. But WHICH N gives the
"widest" (domain-defining) case is NOT the same across modes, and
getting this backwards for a given mode would silently clip most of
the interesting range:

- `sweep`/`compare`: the mean's variance `sigma^2/N` only ever SHRINKS
  as N grows, so N=1 (or the fixed +/-4-sigma standardized range,
  itself source-independent) is the widest case.
- `dice`: the sum's variance `N*35/12` only ever GROWS as N grows, so
  `n_max` (not N=1) is the widest case -- `DiceDisplayDomain[nMax]`
  takes `nMax` as its argument specifically because of this, the exact
  opposite asymmetry from `RawMeanDisplayDomain`. Do not "simplify" this
  to reuse sweep mode's N=1-based logic; it would silently make every
  N>1 dice frame's high-sum tail (and much of its probability mass at
  large N) fall outside the fixed domain and get clipped to zero.

### 5. `n_max`'s per-mode default only works because `clt/config.json` does NOT declare it

`sweep`/`compare` default `n_max` to 30; `dice` defaults it to 10
(dice sums are visibly bell-shaped much sooner). Both read the exact
SAME config key (`simulation.clt.n_max`) via `GetCfg[cfg, {...}, 30]`
vs. `GetCfg[cfg, {...}, 10]` — this ONLY works because `clt/config.json`
has no `"n_max"` entry at all. If it did, that value would win over
EVERY mode's own inline default (config.json outranks the hardcoded
fallback in the 4-layer merge: `$HardcodedDefaults -> config/config.json
-> app config.json -> CLI`), silently forcing `dice` mode to also use
30 regardless of what default is written in `main.wl` — exactly the
bug an earlier version of this app shipped with, caught only by
actually running `dice` mode and noticing `N: 1 -> 30` printed instead
of the intended `N: 1 -> 10`. If you ever add `n_max` to `config.json`
for convenience, you must also give `dice` mode its own distinctly-named
key (e.g. `dice_n_max`) at the same time, or this bug returns.

### 6. `Histogram`/`BinCounts` silently drop values exactly at the domain's upper edge

`Histogram[data, {lo,hi,dx}]`'s bins are half-open even for the LAST
bin — a value exactly equal to `hi` is dropped, not counted, contrary
to what its visual position in the plot would suggest (verified
directly: `BinCounts[{1.0}, {0.,1.,0.025}]` returns all zeros). This
bit hard in practice, not just in principle: the `bernoulli` source's
N=1 sample mean is EXACTLY `0.0` or `1.0` (a single coin flip), so
roughly `p` of every N=1 sample silently vanished from both the
sonification (`HistogramSpectrumBins`, `sonify.wl`) and every histogram
plot (`animate.wl`) before this was caught — by actually rendering the
`bernoulli`-source sweep PNG and noticing the N=1 panel showed only ONE
spike (at 0) instead of two (at 0 and 1), not by reading the code.
Fixed via `ClampToDomain`/an equivalent inline nudge: any sample at or
above `domainHi` is moved a negligible amount (`binWidth*0.0001`)
inside the range before binning, landing it in the intended last bin
rather than a fabricated new one. This is a real WL behaviour, not a
bug in this app's own binning math — any FUTURE code in this app (or
any other app) that bins Monte Carlo samples with an explicit
`{lo,hi,dx}` spec should apply the same nudge, or verify its own
samples can never land exactly on the upper edge (true for genuinely
continuous sources at N>1, but NOT true for discrete sources like
`bernoulli` or `dice`'s all-sixes/all-ones extremes).

### 7. `SampleXbarN`/`SampleDiceSumN` return machine floats, not exact rationals — wrapped with `N[...]` at the source, not at every call site

`Mean` of a list of exact integers (from a discrete source like
`bernoulli`, or `Total` of dice draws) produces an exact WL `Rational`,
not a machine float. An exact `Rational` fed to `FmtN`/`NumberForm`
elsewhere in this app renders in headless `wolframscript` as a literal
2D "numerator over a horizontal bar over denominator" text box — the
console output showed garbled dashes and truncated numbers where a
clean decimal should have appeared, caught only by actually running
`dice` mode and reading the console output, not by reading the code
(the same "OutputForm renders unusual number forms as multi-line in
headless mode" family of issue `stem-core/AGENTS.md`'s `FmtN` docstring
warns about for scientific notation specifically — this is the same
failure mode one level upstream, in the raw samples themselves, for a
different number representation). Fixed by wrapping the ENTIRE sample
list in `N[...]` inside `SampleXbarN`/`SampleDiceSumN` themselves, so
every downstream consumer (`sonify.wl`, `animate.wl`, `output.wl`,
`model.wl`'s own checks) automatically gets floats without needing to
remember to wrap `Mean[...]`/`Variance[...]`/`Kurtosis[...]` individually
at each call site. A side effect: any code comparing dice sums against
literal integers (e.g. `Count[sums, 7]`) must compare against `7.0`,
not `7` (`7 === 7.0` is `False` in WL) — `ExactDiceProbability`'s
callers and the correctness checks were updated accordingly.

### 8. GIF/WAV duration sync — the GIF used to play at a fixed 8/4 fps unrelated to the audio's actual length

**The bug.** `AnimateSweep`/`AnimateCompare` exported at a hardcoded 8
fps and `AnimateDice` at a hardcoded 4 fps, both completely decoupled
from `frame_duration` (the config key that actually sizes each N-step's
audio chunk in `sonify.wl`, default 0.2s). Measured before the fix,
GIF vs its paired WAV:

| File | GIF (old) | WAV | ratio |
|---|---|---|---|
| `sweep.gif` / `sweep_audio.wav` (main.wl, with spoken intro) | 3.90s | 23.78s | 6.10x |
| `compare.gif` / `compare_audio.wav` (main.wl, with spoken intro) | 3.90s | 26.62s | 6.83x |
| `dice.gif` / `dice_audio.wav` (main.wl, with spoken intro) | 2.50s | 24.32s | 9.73x |
| `sweep_bernoulli_animation.gif` / `..._audio.wav` (experiments.wl, no intro) | 3.90s | 6.00s | 1.54x |
| `dice_default_animation.gif` / `..._audio.wav` (experiments.wl, no intro) | 2.50s | 2.00s | 0.80x |

**Root cause.** Unlike `lorenz/`'s continuous ODE trajectory, CLT's
animations have exactly one rendered frame per integer `N=1..nMax` —
frame COUNT is fixed by the content (there is no continuous curve to
resample at an arbitrary density), so `lorenz/src/animate.wl`'s
"flex the frame count, keep the frame rate fixed to a render budget"
approach does not transfer directly. What CAN flex here is the
playback frame RATE.

**The fix.** `AnimationFrameRate[nMax, targetDuration]` (in
`src/animate.wl`) computes
`Clip[nMax/targetDuration, {$MinAnimationFps, $MaxAnimationFps}]`
(2-30 fps, same clamp bounds as `lorenz/`'s), and all three
`Animate*` functions now take `targetDuration` as their final argument
and export at that computed rate instead of a literal 8 or 4. Callers
(`main.wl`'s three modes, `experiments.wl`'s five presets) pass
`nMax * frameDur` — the sonified content's OWN length, i.e. exactly
what `BuildSweepAudio`/`BuildCompareAudio`/`BuildDiceAudio` actually
return as `"left"`/`"right"` before `main.wl` prepends a spoken intro
and a 0.4s pause. The intro is deliberately excluded from the sync
target: it has no visual counterpart (the GIF has nothing to show
during narration) and its length is TTS-engine/OS-dependent (`say` on
macOS, `espeak`/`espeak-ng` on Linux, or silent if neither is
available) — baking a nondeterministic narration length into the
render pipeline would make the GIF's own duration non-reproducible.
Within the fps clamp, GIF duration matches `targetDuration` EXACTLY
(`nMax/frameRate = nMax/(nMax/targetDuration) = targetDuration`); only
at the clamp's boundary (e.g. an unusually small `nMax` with a long
`frameDuration`) does it deviate, the same tradeoff `lorenz/`'s own fps
clamp accepts. Both `Animate*` and `STEMDescribeGIF` now report the
actual computed fps (previously `STEMDescribeGIF` was called with the
same hardcoded 8/4 literal, independently of what `ExportGIF` used).

**Verification (after fix).** Content-only sync is exact wherever
there is no spoken intro (`experiments.wl`'s presets, and the
`_default` outputs); `main.wl`'s three modes (which DO add a spoken
intro to the WAV) now sync the GIF to the sweep's own 6.00s/2.00s
content instead of an arbitrary 3.90s/2.50s, with the intro's spoken
seconds remaining as an intentional, expected excess (not a bug):

| File | GIF (fixed) | WAV | ratio | frame rate |
|---|---|---|---|---|
| `sweep.gif` (main.wl, with intro) | 6.00s | 23.78s | 3.96x (intro speech only) | 5.0 fps |
| `compare.gif` (main.wl, with intro) | 6.00s | 26.62s | 4.44x (intro speech only) | 5.0 fps |
| `dice.gif` (main.wl, with intro) | 2.00s | 24.32s | 12.16x (intro speech only) | 5.0 fps |
| `sweep_bernoulli_animation.gif` (experiments.wl, no intro) | 6.00s | 6.00s | 1.00x | 5.0 fps |
| `dice_default_animation.gif` (experiments.wl, no intro) | 2.00s | 2.00s | 1.00x | 5.0 fps |

## Project structure

```
clt/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json          — default simulation parameters (deliberately WITHOUT n_max,
                          see design decision 5)
  experiments.wl        — 5 curated preset invocations (3 sweep sources, compare,
                          dice)
  LISTENING_GUIDE.md     — user-facing recommended listening sequence
  AGENTS.md               — this file
  src/
    model.wl              — SourceDistribution/Mean/Variance/ExcessKurtosis (exact,
                            verified against WL's own closed-form moments),
                            SampleXbarN/SampleDiceSumN (Monte Carlo, N[...]-wrapped),
                            IrwinHallDensity (exact, check-only), display domains,
                            correctness checks 1-4
    sonify.wl                — HistogramSpectrumBins (shared primitive, with the
                            domain-edge-clamp fix), Build{Sweep,Compare,Dice}Audio
    speech.wl                 — Spoken intro synthesis, BuildXIntroText per mode
    animate.wl                  — ClampToDomain (shared with sonify.wl's fix, same
                            reasoning), per-mode Render*/Animate* functions
    output.wl                    — Export*CSV per mode, Print*Summary per mode,
                            ExactDiceProbability (brute-force enumeration, N<=2 only)
  tests/
    test_model.wl              — unit tests (variance scaling, Irwin-Hall, dice
                            combinatorics, kurtosis decay, exact moments, display
                            domains)
  output/                     — generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                                # sweep, uniform
wolframscript -file main.wl -- --simulation.clt.source=exponential
wolframscript -file main.wl -- --simulation.clt.source=bernoulli \
                                --simulation.clt.bernoulli_p=0.3
wolframscript -file main.wl -- --simulation.mode=compare                   # uniform vs exponential
wolframscript -file main.wl -- --simulation.mode=dice                      # sum of N fair dice
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks

All four run unconditionally, every invocation, regardless of mode
(see design decision 2 for why none of them abort):

1. **Variance scaling** — `Var(mean of 10)` matches `sigma^2/10` within
   10% (Monte Carlo tolerance, 20000 samples), for the default source.
2. **Irwin-Hall exact density** — this app's own Monte Carlo histogram
   estimate of the sum of 3 Uniform(0,1) draws matches the exact
   closed-form density within 10% at five test points (calibrated
   against a 300000-sample run: typical error was under 1%).
3. **Dice combinatorics** — empirical P(sum=7, two dice) matches the
   exact 1/6 within 5%.
4. **Kurtosis decay** — at N=30, the standardized mean's empirical
   excess kurtosis is both closer to 0 than the source's own raw
   kurtosis, AND within 0.02 (absolute) of the predicted
   `(source kurtosis)/N` rate (calibrated across 5 seeds at 500000
   samples: typical deviation was under 0.005).

## Common pitfalls

1. **`gamma_?NumericQ : 1.0` in function signatures is broken syntax**
   — parses as `gamma_?(NumericQ : 1.0)`, a pattern that never matches.
   Always use `Optional[gamma_?NumericQ, 1.0]` instead (same pitfall
   documented in every prior v1.5.0 app's `AGENTS.md`).
2. **`Histogram[data,{lo,hi,dx}]` drops values exactly at `hi`** — see
   design decision 6. Any new binning code in this app must apply
   `ClampToDomain` (or an equivalent nudge) first, unless the samples
   are provably continuous and therefore essentially never land
   exactly on the boundary.
3. **Discrete-source sample lists need `N[...]` wrapping at the point
   of generation, not at every downstream `Mean`/`Variance`/`Kurtosis`
   call** — see design decision 7. If you add a new Monte Carlo sampler
   to this app, wrap its whole return value in `N[...]` the way
   `SampleXbarN`/`SampleDiceSumN` do, rather than trusting every future
   caller to remember to do it themselves.
4. **`clt/config.json` must never declare `"n_max"`** — see design
   decision 5. This is the one config key in this app where "add it to
   config.json for discoverability" is actively wrong.
5. **`Count[sums, someInteger]` will not match float dice sums** — since
   `SampleDiceSumN` returns floats (design decision 7), compare against
   `N[someInteger]` (or a literal float), not a bare integer literal.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSection`, `STEMSay`, `STEMPrintN`,
  `STEMDescribeWAV`, `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`,
  `STEMPlayCmd`, `NormalizeBuffer`, `ExportAudioBuffer`, `ExportGIF`,
  `ExportCSV`, `EnsureDir`. Deliberately **not** used: `SonifyTrajectory`,
  `SpatialLayer`, `MotionLayer`, `EventLayer`, `MixLayers`, `RenderAudio`,
  `ScaleLookup`, `StemSynthNote` — every mode's audio is a sequence of
  additive-synthesis frames (thermo/bayes's technique), not a
  trajectory or a discrete-note stream.
- **Mathematica/WL**: `RandomVariate`, `UniformDistribution`,
  `ExponentialDistribution`, `BernoulliDistribution`,
  `DiscreteUniformDistribution`, `BinCounts`, `Histogram`, `BarChart`,
  `Mean`, `Variance`, `Kurtosis`, `Tuples` (exact dice enumeration),
  `Export`, `SpeechSynthesize`, `AudioQ`, `AudioData`, `AudioSampleRate`,
  `RunProcess` (platform TTS fallback), `Import` (reading TTS-generated
  WAV files).

## Speech synthesis note

`speech.wl`'s three-tier fallback (`SpeechSynthesize[]` -> platform TTS
-> text-only `STEMSay`) duplicates the pattern in
`quantum_tunnelling/src/speech.wl`, `compton/src/speech.wl`, and
`blackbody/src/speech.wl` — one of many independent copies scattered
across the codebase, still out of scope for stem-core consolidation
per every prior app's own build spec.

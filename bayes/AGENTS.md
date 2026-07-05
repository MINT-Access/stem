# Bayesian Inference — Agent Guide

## Project overview

Sonifies Bayesian updating itself — probability distributions
narrowing as evidence accumulates. The most conceptually distinct app
in the project: no differential equations, no orbital mechanics, no
wave functions, just probability updating made directly audible.

| Mode | Model | Time axis | Output |
|------|-------|-----------|--------|
| `coin` (default) | Beta-Binomial: unknown coin bias theta | flip index | Stereo WAV (spectral posterior + pentatonic summary layer); Beta-curve-narrowing GIF |
| `gaussian` | Normal-Normal: unknown mean mu | observation index | Stereo WAV (spectral posterior + pentatonic summary layer); Gaussian-shifting-and-narrowing GIF |
| `model` | Bayes factor: two point hypotheses about a coin | flip index | Stereo WAV (single continuous carrier); Bayes-factor-meter GIF |

## Key design decisions (read before modifying sonify.wl/animate.wl)

### 1. The "summary trajectory" secondary layer is discrete notes, not a literal SonifyTrajectory call

The build spec calls for `coin`/`gaussian`'s secondary layer (posterior
mean -> pitch, posterior mode -> pan, posterior variance -> volume) to
use stem-core's `SonifyTrajectory` pipeline, and separately calls for
pitch to be quantised via `ScaleLookup` on a pentatonic scale. These two
requirements are in tension: `SonifyTrajectory`'s `SpatialLayer` always
linearly *rescales* pan/pitch to the trajectory's own observed min/max
(`Rescale[x, MinMax[x], panRange]`) — it has no mechanism for
`ScaleLookup`'s scale-quantised pitch, and it cannot express a pan
mapped to theta/mu's fixed absolute domain regardless of how far a
particular run's mode/mean actually wandered.

`sonify.wl`'s `SecondaryNote`/`MixSecondaryNotes` therefore build the
secondary layer directly with `StemSynthNote` + `ScaleLookup` (the same
primitives `dynamical/src/sonify.wl`'s `SynthesizeDiscreteNotes`
established), mixed at the configured `summary_layer_gain` (-12dB
default) beneath the primary spectral layer. This is the same category
of principled deviation `dynamical/AGENTS.md` documents for its own
sonify.wl — see that file for the precedent.

### 2. `model` mode's carrier is bespoke, not SonifyTrajectory either — and for the same reason

`model` mode has no posterior density to render spectrally (theta1 and
theta2 are two point hypotheses, not a distribution), so its one
continuous layer covers pan (from log10 K), pitch (from |log10 K|), and
volume (from the per-flip change in log10 K) directly.
`BuildModelAudio` builds this with a phase-accumulated carrier
(`Sin[2 Pi Accumulate[pitch]/sr]` — the exact formula stem-core's
`MixLayers` uses) driven by spline-interpolated *absolute*-domain
control curves, again because `SpatialLayer`'s autoscaling can't express
"K=1 is always centred, |log10K|=3 is always the saturation point"
regardless of what the run's data happened to produce.

### 3. Pan/gauge sign: positive log10(K) means H1, but H1 is "hard left"

`LogBayesFactor10[h,t,theta1,theta2]` is `P(data|H1)/P(data|H2)` on a
log10 scale — **positive** means H1 (fair coin) is favoured. But the
build spec's stereo convention is the opposite of the sign: "K>>1 (H1
favoured): hard **left**. K<<1 (H2 favoured): hard **right**." Combined
with stem-core's own pan convention (`-1` = left, `+1` = right, see
`sonification.wl`'s `SpatialLayer` comment), this means the audio pan
and the GIF gauge's needle position must both be **`-log10(K)`**
(saturated via `Tanh` for the audio, clipped directly for the gauge),
not `+log10(K)`. This was caught during verification (the very first
implementation used the unnegated sign and the default run's audio
panned left while claiming in its own spoken intro to be panning
right) — if you touch `BuildModelAudio`'s `pan` line or
`RenderModelFrame`'s `gaugeX` line, re-run `--simulation.mode=model`
with both a biased-favouring and a fair-favouring `theta_true` and
check the printed `Final evidence` line agrees with which side the CSV
`pan` column and the spoken intro (`BuildModelIntroText`, which
computes its own expected direction independently) land on.

### 4. The build spec's own worked Bayes-factor example is arithmetically wrong

The spec states `log10K = 7*log10(0.5/0.7) + 3*log10(0.5/0.3) = -0.5686`
for the correctness-check example (h=7, t=3, H1 theta=0.5, H2
theta=0.7). Evaluating the spec's own formula
(`N[7*Log10[0.5/0.7] + 3*Log10[0.5/0.3]]`) gives **-0.35735**, not
-0.5686 — verified independently, not assumed. `BetaFactorCheck` in
`model.wl` and the test in `tests/test_model.wl` use the correct
-0.35735. Either value correctly signs H2 as favoured (both are
negative), so this did not change any conclusion, only the numeric
target the correctness check compares against.

### 5. `EvidenceLevel`'s four-band labels are not the same thresholds as the EventLayer accent tones

`EvidenceLevel` (in `model.wl`, used for the `model_data.csv`
`evidence_level` column) uses the commonly-cited "Jeffreys' scale" per
Wagenmakers et al. — K<3 anecdotal, K<10 moderate, K<30 strong, else
very_strong — matching the table in README.md. The two EventLayer
accent tones in `BuildModelAudio` fire at fixed `|log10K|` thresholds
of 1 and 2 (K=10 and K=100) per the build spec's explicit instruction.
These two things share no threshold in common by design (K=10 falls at
the moderate/strong boundary of the verbal scale, not at either accent
tone's "meaning" if you tried to name them "substantial"/"strong" as
the build spec's own EventLayer bullet text loosely suggested) — do
not try to unify them into one table; they answer different questions
("how should a reader classify this Bayes factor" vs "when should a
milestone chime fire").

### 6. `General::munfl` underflow warnings are expected in gaussian mode, not bugs

As `gaussian` mode's posterior narrows (variance shrinking toward
~0.01 by the end of an 80-observation run), `MuSpectrumBins` evaluates
the posterior density at points many standard deviations out in the
tails of a *fixed* [muLo, muHi] display range — those density values
correctly underflow toward 0 in machine-precision arithmetic. Both the
`BuildGaussianAudio` frame loop (`sonify.wl`) and `RenderGaussianFrame`
(`animate.wl`) wrap their PDF evaluations in
`Quiet[..., General::munfl]` for this reason. If you see this warning
reappear, check that a new PDF call site has the same wrapping — do not
"fix" it by widening the domain or raising the floor variance, since
that would defeat the point of a fixed display range (see design note
in `MuSpectrumBins`'s docstring).

## Project structure

```
bayes/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json           — default simulation parameters
  experiments.wl        — 9 curated preset invocations (RunExperiment)
  LISTENING_GUIDE.md    — user-facing recommended listening sequence
  AGENTS.md             — this file
  src/
    model.wl            — BetaPosteriorParams/Mean/Variance/Mode, GaussianPosteriorMean/Variance,
                          LogBayesFactor10, EvidenceLevel, CoinPosteriorSequence,
                          GaussianPosteriorSequence, ModelPosteriorSequence,
                          BetaPosteriorCheck, GaussianPosteriorCheck, BayesFactorCheck,
                          ConvergenceCheck, BetaNormalizationCheck
    sonify.wl            — SynthesizeAdditiveFrame/FrameWindow (spectral primitive),
                          ThetaSpectrumBins, MuSpectrumBins, SecondaryNote/MixSecondaryNotes
                          (pentatonic summary layer), OverlayBurst (EventLayer markers),
                          BuildCoinAudio, BuildGaussianAudio, BuildModelAudio
    speech.wl             — Spoken intro synthesis (SpeechSynthesize -> platform TTS ->
                          text-only fallback), BuildCoinIntroText, BuildGaussianIntroText,
                          BuildModelIntroText
    animate.wl              — RenderCoinFrame/AnimateCoin, RenderGaussianFrame/AnimateGaussian,
                          RenderModelFrame/AnimateModel (Bayes factor meter + flip sequence)
    output.wl                — ExportCoinCSV, ExportGaussianCSV, ExportModelCSV,
                          PrintCoreChecks, PrintConvergenceCheck, per-mode summaries
  tests/
    test_model.wl            — unit tests (posterior formulas, BetaMode edge cases,
                          sequence builders, EvidenceLevel labels)
  output/                     — generated files (gitignored)
```

## How to run

```sh
wolframscript -file bayes/main.wl                                        # coin, defaults
wolframscript -file bayes/main.wl -- --simulation.mode=gaussian
wolframscript -file bayes/main.wl -- --simulation.mode=model
wolframscript -file bayes/main.wl -- --simulation.bayes.theta_true=0.5
wolframscript -file bayes/main.wl -- --simulation.bayes.theta_true=0.9
wolframscript -file bayes/main.wl -- --simulation.bayes.n_flips=200
wolframscript -file bayes/main.wl -- --simulation.bayes.random_seed=123
wolframscript -file bayes/main.wl -- --simulation.bayes.mu_true=0.5
wolframscript -file bayes/main.wl -- --config-dump

wolframscript -file bayes/tests/test_model.wl
wolframscript -file bayes/experiments.wl
```

## Data flow

```
config.json + CLI args
        |
   LoadConfig (stem-core)
        |
   [correctness checks: BetaPosteriorCheck, GaussianPosteriorCheck,
    BayesFactorCheck, ConvergenceCheck — always run, printed PASS/FAIL,
    independent of which mode is active]
        |
   coin mode:              gaussian mode:            model mode:
     GenerateCoinFlips        GenerateGaussianObs        GenerateCoinFlips
     CoinPosteriorSequence    GaussianPosteriorSequence  ModelPosteriorSequence
        |                        |                          |
     BuildCoinAudio           BuildGaussianAudio          BuildModelAudio
        |                        |                          |
   BuildCoinIntroText/       BuildGaussianIntroText/    BuildModelIntroText/
   BuildIntroBuffer          BuildIntroBuffer            BuildIntroBuffer
        |                        |                          |
   Join[intro, pause, channel] per channel, single final WAV export (main.wl)
        |                        |                          |
   AnimateCoin -> GIF        AnimateGaussian -> GIF      AnimateModel -> GIF
   ExportCoinCSV -> CSV      ExportGaussianCSV -> CSV    ExportModelCSV -> CSV
```

`BuildCoinAudio`/`BuildGaussianAudio`/`BuildModelAudio` return buffers,
not exported files — same pattern as `thermo`/`dynamical`, so `main.wl`
can prepend the spoken intro before a single final export and the
reported `STEMDescribeWAV` duration includes the intro.

## Model/result Association shapes

`CoinPosteriorSequence[flips]` returns a list of per-flip Associations
with keys `"flip"`, `"outcome"`, `"h"`, `"t"`, `"alpha"`, `"beta"`,
`"mean"`, `"variance"`, `"mode"`.

`GaussianPosteriorSequence[obs, mu0, sigma0, sigma]` returns a list of
per-observation Associations with keys `"observation"`, `"x_obs"`,
`"mean"`, `"variance"`, `"ci_low"`, `"ci_high"`.

`ModelPosteriorSequence[flips, theta1, theta2]` returns a list of
per-flip Associations with keys `"flip"`, `"outcome"`,
`"log_bayes_factor"`.

`BuildCoinAudio[...]`/`BuildGaussianAudio[...]` return (in addition to
`"left"`/`"right"`/`"sr"`) `"convergenceFlipIdx"`/`"convergenceObsIdx"`
(an Integer, or `Missing["NotFound"]` if the run never reached the
milestone).

`BuildModelAudio[...]` returns (in addition to `"left"`/`"right"`/
`"sr"`) `"logK"`, `"pan"`, `"pitchHz"` (parallel per-flip arrays, for
CSV export) and `"crossOneIdx"`/`"crossTwoIdx"`.

## Common pitfalls

1. **`BetaMode[1,1]` is 0.5, not `(alpha-1)/(alpha+beta-2)`'s literal
   0/0** — the uniform-prior case (no flips yet) is handled as an
   explicit special case in `BetaMode`; do not remove the `Which[]`
   guard or the mode will silently return `Indeterminate` for the very
   first frame of every coin-mode run.

2. **`MuSpectrumBins`'s `[muLo, muHi]` range is fixed for the whole
   run, not re-derived per frame** — this is deliberate (see the
   function's docstring): a per-frame range would make the pitch axis
   itself a moving target and the "pitch shifts toward mu_true" effect
   the build spec calls for would not be audible as a *consistent*
   shift. If you ever parametrise this range, keep it computed once in
   `main.wl` from `mu_0`/`mu_true`/`sigma_0` and threaded through, not
   recomputed inside the per-frame loop.

3. **Pan sign in `model` mode is intentionally negated** — see design
   decision 3 above. Do not "simplify" `pan = -Tanh[logK]` back to
   `Tanh[logK]`; that reintroduces the direction bug caught during
   verification.

4. **The Bayes-factor correctness-check target is -0.35735, not the
   build spec's stated -0.5686** — see design decision 4. If a future
   spec/doc cites -0.5686 again, that document is repeating the
   original arithmetic error; recompute rather than reconcile
   `model.wl` to match it.

5. **`FmtN` on an exact result from `BetaPosteriorParams`/etc.** — all
   the model.wl functions here are written to return machine reals
   (via `1.0`/`N[...]` literals), unlike `dynamical`'s occasional exact
   `Rational` results, so this particular pitfall from `dynamical`'s
   own AGENTS.md does not apply here — but keep it in mind if you add
   a new exact-arithmetic helper.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSection`, `STEMSay`, `STEMPrintN`,
  `STEMDescribeWAV`, `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`,
  `STEMPlayCmd`, `ScaleLookup`, `SemitoneToHz`, `$StemScales`,
  `StemSynthNote`, `NormalizeBuffer`, `ExportAudioBuffer`, `ExportGIF`,
  `ExportCSV`, `EnsureDir`. Deliberately **not** used:
  `SonifyTrajectory`, `SpatialLayer`, `MotionLayer`, `EventLayer`,
  `MixLayers`, `RenderAudio` — see design decisions 1-2.
- **Mathematica/WL**: `BetaDistribution`, `NormalDistribution`,
  `BernoulliDistribution`, `PDF`, `RandomVariate`, `SeedRandom`,
  `NIntegrate` (unit-test coverage only), `Interpolation` (Method ->
  "Spline", for `model` mode's control curves), `Accumulate`,
  `Sound`, `SampledSoundList`, `Graphics`, `Plot`, `Show`, `Export`,
  `SpeechSynthesize`, `AudioQ`, `AudioData`, `AudioSampleRate`,
  `RunProcess` (platform TTS fallback), `Import` (reading
  TTS-generated WAV files).

## Speech synthesis note

`speech.wl`'s three-tier fallback (`SpeechSynthesize[]` -> platform TTS
-> text-only `STEMSay`) duplicates the pattern in `thermo/src/speech.wl`
and `dynamical/src/speech.wl` — this is now the fourth independent copy
of this pattern across the codebase; a good candidate for stem-core
consolidation in a future pass (explicitly out of scope here per this
app's build spec, which excludes stem-core changes). `model` mode's
`BuildModelIntroText` computes its expected pan direction independently
from `BuildModelAudio`'s actual computation (see design decision 3) —
if the two ever disagree for a given config, that is a real bug, not
an acceptable inconsistency; re-run `--simulation.mode=model` and
compare the spoken "toward the left/right" claim against the CSV `pan`
column's sign.

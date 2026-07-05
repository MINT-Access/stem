# Bayesian Inference

Sonifies the process of updating probability distributions as evidence
accumulates — the most conceptually distinct app in this project. No
differential equations, no orbital mechanics, no wave functions: just
probability updating, made directly audible.

**New to this app?** Start with
[`bayes/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — the recommended
listening sequence across all three modes.

## What is Bayesian inference?

Say you don't know whether a coin is fair. A **frequentist**
statistician asks "is this coin fair?" and answers with a yes/no test
and a p-value. A **Bayesian** statistician asks a different question:
"given everything I currently believe, and the data I've now seen,
what is my updated belief about the coin's bias — and how confident am
I?" The answer is not a single number but an entire probability
distribution: a range of possible biases, each with a degree of
plausibility attached, updated every time new data arrives.

That updating rule is Bayes' theorem:

    P(theta | data)  proportional to  P(data | theta) * P(theta)

- **Prior** P(theta): what you believed about the parameter *before*
  seeing this data.
- **Likelihood** P(data | theta): how probable the observed data would
  be, if theta were the true value.
- **Posterior** P(theta | data): your *updated* belief, after
  combining the prior with the data.

Every time a new coin flip, observation, or measurement arrives, the
posterior from the previous step becomes the prior for the next — the
distribution narrows, step by step, as uncertainty is replaced by
evidence. That narrowing — broad and uncertain at first, sharp and
confident after enough data — is exactly what this app makes audible.

## Conjugate priors: why the updates here are exact, not approximate

In general, computing a Bayesian posterior requires numerical
integration (the "evidence" term P(data) in the denominator has no
closed form for most models). But for a handful of special
prior/likelihood pairings — **conjugate priors** — the posterior has
the *same algebraic family* as the prior, and updating it is simple
arithmetic. This app uses two of the best-known conjugate pairs, so
every posterior computed here is exact, not an approximation:

- **Beta-Binomial** (`coin` mode): a Beta(alpha, beta) prior over a
  coin's bias theta, updated by h heads and t tails, becomes exactly
  Beta(alpha+h, beta+t). Starting from the uniform prior Beta(1,1)
  (every bias equally plausible), the posterior after any number of
  flips is just Beta(1+heads, 1+tails).
- **Normal-Normal** (`gaussian` mode): a Normal(mu_0, sigma_0^2) prior
  over an unknown mean mu, updated by n observations with known noise
  sigma and sample mean x-bar, becomes exactly Normal with mean
  `(mu_0/sigma_0^2 + n*x-bar/sigma^2) / (1/sigma_0^2 + n/sigma^2)` and
  variance `1 / (1/sigma_0^2 + n/sigma^2)`.

## The Bayes factor: weighing evidence between two hypotheses

`model` mode asks a different kind of question: not "what is theta?"
but "which of these two specific claims about theta does the data
support?" Given two hypotheses H1 and H2, the **Bayes factor**

    K = P(data | H1) / P(data | H2)

measures how many times more likely the observed data is under H1 than
under H2. Crucially, K is a measure of the *weight of evidence*, not a
probability that either hypothesis is true — it only compares how well
each hypothesis explains what was actually observed.

### The Jeffreys scale

Because K can range from near-zero to enormous, it's usually
interpreted on a log scale, with conventional verbal labels (this
project uses the commonly-cited version of Jeffreys' scale, as
popularised by Wagenmakers et al.):

| K | log10(K) | Evidence for the favoured hypothesis |
|---|---|---|
| 1 – 3 | 0 – 0.48 | Anecdotal |
| 3 – 10 | 0.48 – 1 | Moderate |
| 10 – 30 | 1 – 1.48 | Strong |
| > 30 | > 1.48 | Very strong |

`model` mode's audio marks two fixed milestones as the run progresses
— `|log10(K)| = 1` (K=10) and `|log10(K)| = 2` (K=100) — with accent
tones; these are audio cues at round log-scale thresholds, not a
restatement of the verbal table above (see `bayes/AGENTS.md` if you're
extending either).

## The three modes

### `coin` (default)

An unknown coin bias theta in [0,1]. Starting from a uniform prior
(every bias equally plausible), `n_flips` simulated flips update the
Beta posterior one flip at a time. The posterior density is sonified
directly as a spectral shape — broad and noisy across the whole pitch
range at first, narrowing to a focused tone near the true bias as
flips accumulate.

### `gaussian`

An unknown Gaussian mean mu, with known observation noise. The
posterior both narrows *and* shifts in pitch — from the prior's centre
toward the true mean — as observations accumulate. This makes belief
revision directly audible as a change in pitch, not just a change in
sharpness.

### `model`

Two competing hypotheses about a coin (H1: fair, theta=0.5; H2: biased,
theta=`theta_alt`). As flips accumulate, the stereo position drifts
toward whichever hypothesis the data actually supports — audibly
"weighing" the evidence in real time.

See [`bayes/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) for the full
recommended listening order and what to listen for in each mode.

## Connection to thermo/

This app's spectral posterior sonification (`coin`/`gaussian` modes)
uses the exact same additive-synthesis technique as
[`thermo/`](../thermo/)'s Maxwell-Boltzmann `distribution` mode: a
probability density discretised into N frequency bins, each bin's
amplitude weighted by the density at that point, all bins summed into
one spectral "frame." Both apps produce the same audible phenomenon —
a broad, noisy sound converging to a narrow, focused tone — but by
completely different mechanisms: `thermo/` is driven by *temperature*
(a physical control parameter), while `bayes/` is driven by
*information* (accumulating data). Comparing the two side-by-side is a
striking demonstration that "spectral narrowing" is a general
sonification technique for "any process that concentrates
probability," not something specific to either statistical mechanics
or Bayesian statistics.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically
- Optional for the spoken intro: macOS `say` (built in), Linux
  `espeak-ng`/`espeak`, or Windows PowerShell (built in) — falls back
  to text-only output if none is available

## Quick start

```sh
# Coin mode (default): theta_true=0.7, 100 flips, uniform prior
wolframscript -file main.wl

# Gaussian mode: mu_true=2.5, prior N(0,4), 80 observations
wolframscript -file main.wl -- --simulation.mode=gaussian

# Model mode: H1 fair vs H2 biased, 100 flips
wolframscript -file main.wl -- --simulation.mode=model

# Fair coin (slow convergence) vs strongly biased (fast convergence)
wolframscript -file main.wl -- --simulation.bayes.theta_true=0.5
wolframscript -file main.wl -- --simulation.bayes.theta_true=0.9

# More data, a different random draw, or a subtler Gaussian shift
wolframscript -file main.wl -- --simulation.bayes.n_flips=200
wolframscript -file main.wl -- --simulation.bayes.random_seed=123
wolframscript -file main.wl -- --simulation.bayes.mu_true=0.5

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Sonification mapping

### `coin` / `gaussian` (both modes share this structure)

| Layer | Encoding |
|---|---|
| Primary (spectral) | Posterior density discretised into `n_bins` frequency bins (logarithmic mapping onto `[freq_min, freq_max]`), one frame (`frame_duration`) per flip/observation — the sound's spectral shape *is* the posterior |
| Secondary (pentatonic, -12dB) | Posterior mean -> pitch (minor pentatonic scale); posterior mode -> stereo pan; posterior variance -> volume (louder while uncertain, quieter as it resolves) |
| Event markers | `coin`: flip 10 (440 Hz), variance < 0.01 (528 Hz), final flip (660 Hz). `gaussian`: posterior mean within 0.1 of `mu_true` (528 Hz) |

### `model`

| Quantity | Encoding |
|---|---|
| Stereo pan | log10(Bayes factor), sigmoid-saturated — hard left = H1 (fair) strongly favoured, hard right = H2 (biased) strongly favoured, centre = no evidence either way |
| Pitch | \|log10(Bayes factor)\| — low pitch = maximum uncertainty (K=1), rising as evidence accumulates in either direction |
| Volume | Per-flip change in log10(Bayes factor) — an informative flip is louder than an uninformative one |
| Event markers | \|log10(K)\| crosses 1 (K=10, 440 Hz) and 2 (K=100, 660 Hz) |

## Correctness checks

Every run prints four physical/mathematical correctness checks:

1. **Beta posterior** (h=7, t=3, uniform prior): mean = 8/12 = 0.6667,
   mode = 7/10 = 0.7, both within 0.001.
2. **Gaussian posterior** (prior N(0,4), sigma=1, one observation x=3):
   mean = 2.4, variance = 0.8, both within 0.001.
3. **Bayes factor** (h=7, t=3, H1 theta=0.5, H2 theta=0.7): log10(K) =
   -0.35735 within 0.001, correctly favouring H2 (the higher-bias
   hypothesis, consistent with 7 of 10 flips landing heads).
4. **Convergence**: 5 independent 100-flip realisations at
   `theta_true`; at least 4 of 5 must converge to a posterior mode
   within 0.1 of the true value — a statistical sanity check on the
   simulation itself, not an exact analytic identity.

## Outputs

| File | Description |
|------|-------------|
| `output/coin_audio.wav` | Spoken intro + coin sonification (16-bit PCM, 44100 Hz, stereo) |
| `output/coin.gif` | Beta posterior density narrowing toward theta_true |
| `output/coin_data.csv` | Per-flip table: flip, outcome, alpha, beta, posterior_mean, posterior_variance, posterior_mode |
| `output/gaussian_audio.wav` | Spoken intro + Gaussian sonification (16-bit PCM, 44100 Hz, stereo) |
| `output/gaussian.gif` | Gaussian posterior shifting toward mu_true and narrowing, with 95% credible interval shaded |
| `output/gaussian_data.csv` | Per-observation table: observation, x_obs, posterior_mean, posterior_variance, posterior_credible_interval_low, posterior_credible_interval_high |
| `output/model_audio.wav` | Spoken intro + Bayes factor sonification (16-bit PCM, 44100 Hz, stereo) |
| `output/model.gif` | Bayes factor meter with revealed flip sequence |
| `output/model_data.csv` | Per-flip table: flip, outcome, log_bayes_factor, pan, pitch_hz, evidence_level |

## Configuration parameters (`bayes/config.json`)

| Key | Default | Description |
|-----|---------|--------------|
| `simulation.mode` | `"coin"` | `coin`, `gaussian`, or `model` |
| `simulation.bayes.theta_true` | `0.7` | True coin bias (`coin`/`model` modes) |
| `simulation.bayes.theta_alt` | `0.7` | H2's hypothesised bias (`model` mode) |
| `simulation.bayes.mu_true` | `2.5` | True Gaussian mean (`gaussian` mode) |
| `simulation.bayes.mu_0` | `0.0` | Prior mean (`gaussian` mode) |
| `simulation.bayes.sigma_0` | `2.0` | Prior standard deviation (`gaussian` mode) |
| `simulation.bayes.sigma` | `1.0` | Observation noise standard deviation (`gaussian` mode) |
| `simulation.bayes.n_flips` | `100` | Number of coin flips (`coin`/`model` modes) |
| `simulation.bayes.n_obs` | `80` | Number of observations (`gaussian` mode) |
| `simulation.bayes.random_seed` | `42` | Seed for reproducible data generation |
| `simulation.bayes.frame_duration` | `0.15` | Seconds per spectral frame (`coin`/`gaussian`) or per flip step (`model`) |
| `simulation.bayes.freq_min` | `100` | Lowest frequency in the spectral/pitch mapping (Hz) |
| `simulation.bayes.freq_max` | `4000` | Highest frequency in the spectral/pitch mapping (Hz) |
| `simulation.bayes.n_bins` | `128` | Frequency bins in the spectral posterior (`coin`/`gaussian`) |
| `sonification.bayes.summary_layer_gain` | `-12` | Gain (dB) of the pentatonic summary layer relative to the spectral layer (`coin`/`gaussian`) |

## Project structure

```
bayes/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl        — 9 curated preset invocations
  config.json           — App defaults
  LISTENING_GUIDE.md     — Recommended listening sequence
  src/
    model.wl            — Beta/Gaussian/Bayes-factor math, posterior sequences,
                          correctness checks
    sonify.wl            — Additive spectral synthesis (posterior),
                          pentatonic summary layer, Bayes-factor carrier
    speech.wl             — Spoken intro synthesis (SpeechSynthesize -> platform TTS ->
                          text-only fallback)
    animate.wl              — Beta/Gaussian posterior GIFs, Bayes factor meter GIF
    output.wl                — CSV export, correctness-check printing, console summaries
  tests/
    test_model.wl         — Unit tests
  output/                 — Output files (not committed)
  README.md
  AGENTS.md
```

## Console output

Step numbers `[1/5]` through `[5/5]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements in
addition to the intro:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

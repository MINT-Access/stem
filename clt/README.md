# CLT — Central Limit Theorem

Sonifies the Central Limit Theorem: sums and means of independent
random variables become approximately Gaussian as more of them are
combined, regardless of the source distribution's own shape. The most
accessible statistics app in this batch — no physics background
needed, and the story is genuinely surprising the first time you hear
a flat coin flip's average curve into a bell shape.

**New to this app?** Start with
[`clt/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — the recommended
four-step listening sequence across all three modes.

## The physics (well — the statistics)

Given N independent, identically-distributed random variables
X₁,...,X_N with mean μ and variance σ², **two related but distinct
facts** are both true, and both worth keeping separate:

| Fact | Statement | Character |
|---|---|---|
| Variance scaling | `Var(mean of N) = sigma^2 / N`, exactly, for any N | Basic, exact, non-asymptotic — no bell curve required |
| The Central Limit Theorem itself | The *shape* of the mean's distribution approaches Gaussian as N→∞, regardless of the source's own shape | Asymptotic — the genuinely surprising part |

Conflating these into one vague "things average out" story is an easy
mistake — this app deliberately keeps them apart (see `AGENTS.md`).

### Computing the density: Monte Carlo, checked against exact math

To support "any" source generically with one shared code path, this
app builds every density it sonifies via **Monte Carlo**: draw
thousands of independent realizations of the sample mean (or sum), bin
into a histogram over a domain fixed once at the start of the sweep.
Exact closed forms (the Irwin-Hall distribution for sums of uniforms;
elementary combinatorics for dice) are used **only** as an independent
reference for the correctness checks, never as the main sonification
path — see Correctness checks below.

## Modes

### sweep (default)

Sweeps N from 1 to `n_max` (default 30) for one source distribution
(`uniform`, `exponential`, or `bernoulli` — a configurable-bias coin,
connecting to `bayes/`'s coin theme). At each N, sonifies the empirical
density of the **raw (unstandardized) sample mean** as a spectral
envelope — the same additive-synthesis technique `thermo/`'s
Maxwell-Boltzmann sweep and `bayes/`'s posterior narrowing use — over a
domain fixed at N=1's spread (the widest case, since the mean's
variance only ever shrinks). The raw mean is the one quantity where
"narrows AND symmetrises" are simultaneously and correctly true
together.

### compare

Binaural: two different source distributions (default `uniform` left,
`exponential` right — deliberately as different-looking as possible)
sweep N simultaneously, but sonify the **standardized** sample mean
`(mean - mu)/(sigma/Sqrt[N])` instead of the raw mean. Standardizing
removes each source's own scale (fixed variance 1 for every N, by
construction — it never narrows, only symmetrises), isolating the
*shape convergence* fact alone: two starting shapes as different as a
flat distribution and a one-sided exponential decay converge to the
same limiting bell shape.

### dice

The single most recognisable illustration of the CLT: the **sum**
(not mean — the natural, intuitive quantity for physical dice) of N
fair six-sided dice, N=1 (flat, six equally likely outcomes) through
N≈10 (visibly smooth and bell-shaped). Framed around **shape
smoothing**, not narrowing — the sum's spread genuinely *grows* with N
(`Var = N*35/12` for fair dice) — see `LISTENING_GUIDE.md` for why this
is not a contradiction of the CLT.

## Correctness checks

All four checks are diagnostic-only (print `[PASS]`/`[FAIL]`, never
abort — see `AGENTS.md` for why) and, per a lesson from this codebase's
ongoing correctness audit (`cosmology/AGENTS.md`), each is built against
an **exact, independently-derivable reference** — never a re-statement
of this app's own Monte Carlo pipeline's formula:

1. **Variance scaling** — `Var(mean of N) = sigma^2/N`, checked against
   the source's own exactly-known `sigma^2` (Uniform(0,1): 1/12;
   Exponential(1): 1).
2. **Irwin-Hall exact density** — the sum of 3 Uniform(0,1) draws has a
   known, closed-form (piecewise-quadratic) density; this app's Monte
   Carlo histogram estimate is checked against it directly, validating
   the sampling/histogram pipeline itself against ground truth.
3. **Dice-sum exact combinatorics** — P(sum=7, two fair dice) = 6/36 =
   1/6 exactly; checked against this app's own Monte Carlo estimate.
4. **Kurtosis-decay rate** — the standardized mean's excess kurtosis
   decays as `(source excess kurtosis)/N`; checked at N=30 against the
   source's own exact excess kurtosis (Uniform(0,1): −1.2;
   Exponential(1): 6, both verified against WL's own closed-form
   `Kurtosis[dist]`) — a genuine check of convergence *rate*, not just
   direction.

## Sonification mapping

| Quantity | Encoding |
|---|---|
| Sample mean / sum value | Log-frequency mapped onto `[audio_freq_min, audio_freq_max]` across a domain fixed once per run (per-mode: see `AGENTS.md`) |
| Empirical density | Partial amplitude within a frame, peak-normalised (matches `thermo/`/`bayes/`) |
| `compare` mode channels | Left = `source_left` (standardized), right = `source_right` (standardized) — see `AGENTS.md` for the explicit channel-assignment note |

## Outputs

| File | Description |
|------|-------------|
| `output/sweep_audio.wav` | Narrowing-and-smoothing spectral sweep, N=1..n_max |
| `output/sweep.gif` | Animated sample-mean histogram |
| `output/sweep.png` | Small multiple: N=1, a middle value, n_max |
| `output/sweep_data.csv` | N, empirical mean, empirical variance, per-bin density |
| `output/compare_audio.wav` | Binaural standardized-shape convergence |
| `output/compare.gif` | Animated overlaid standardized densities |
| `output/compare.png` | Static overlay at n_max |
| `output/compare_data.csv` | N, both channels' empirical standardized moments |
| `output/dice_audio.wav` | Flat-to-bell-shaped dice-sum sweep |
| `output/dice.gif` | Animated dice-sum bar chart |
| `output/dice.png` | Small multiple: N=1, 2, n_max (the classic textbook figure) |
| `output/dice_data.csv` | N, sum value, empirical probability, exact probability (N=1,2) |

## Configuration parameters (`clt/config.json`)

| Key | Default | Used by |
|-----|---------|---------|
| `simulation.mode` | `"sweep"` | all |
| `simulation.clt.source` | `"uniform"` | sweep (`uniform`, `exponential`, `bernoulli`) |
| `simulation.clt.bernoulli_p` | `0.5` | sweep/compare (`bernoulli` source only) |
| `simulation.clt.source_left` / `source_right` | `"uniform"` / `"exponential"` | compare |
| `simulation.clt.n_max` | `30` (sweep/compare); dice mode uses its own inline default of `10` | all — **not declared in config.json**, see `AGENTS.md` for why |
| `simulation.clt.n_samples` | `5000` | all (Monte Carlo samples per N) |
| `simulation.clt.n_bins` | `48` | all (spectral envelope resolution, matches `bayes/`) |
| `simulation.clt.audio_freq_min` / `audio_freq_max` | `100` / `4000` | all (Hz) |
| `simulation.clt.frame_duration` | `0.2` | all (seconds per N step) |
| `simulation.clt.random_seed` | `42` | all |

## Project structure

```
clt/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl        — 5 curated preset invocations
  config.json            — App defaults
  LISTENING_GUIDE.md      — Recommended listening sequence
  src/
    model.wl              — SourceDistribution/Mean/Variance/ExcessKurtosis,
                            Monte Carlo samplers, IrwinHallDensity (exact,
                            check-only), display domains, correctness checks 1-4
    sonify.wl               — HistogramSpectrumBins (shared "distribution ->
                            partials" primitive), Build{Sweep,Compare,Dice}Audio
    speech.wl                — Spoken intro synthesis and per-mode intro text
    animate.wl                 — Per-mode GIF/PNG renderers, ClampToDomain
                            (Histogram right-edge-exclusion fix)
    output.wl                    — CSV export and console summaries
  tests/
    test_model.wl              — Unit tests
  output/                       — Output files (not committed)
  README.md
  AGENTS.md
```

## Connection to `thermo/`, `bayes/`, and `montecarlo/`

`sweep`/`compare`'s additive spectral synthesis is `thermo/`'s
Maxwell-Boltzmann-sweep and `bayes/`'s posterior-narrowing technique,
reused directly. `bayes/`'s coin (Beta-Binomial) theme is the same coin
this app's `bernoulli` source draws from — two very different lenses
on the same simple random experiment. `montecarlo/` establishes this
codebase's Monte Carlo sampling conventions (seeding, sample-count
defaults) this app's own Monte Carlo pipeline follows.

## Console output

Step numbers `[1/4]` through `[4/4]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements in
addition to the intro:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

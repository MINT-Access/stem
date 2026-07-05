# Listening Guide — Bayesian Inference

## Recommended listening sequence

1. **`coin` mode, defaults** (theta_true=0.7, 100 flips):

   ```sh
   wolframscript -file main.wl
   ```

   Listen for the broad, noisy opening sound gradually focusing down
   to a narrow tone. The narrowing *is* the inference — uncertainty
   collapsing to near-certainty as flips accumulate. A soft accent
   marks flip 10 (the first meaningful update), another marks the
   moment the posterior variance drops below 0.01 (the convergence
   milestone), and a final accent marks the last flip.

2. **`coin` mode, a fair coin** (theta_true=0.5):

   ```sh
   wolframscript -file main.wl -- --simulation.bayes.theta_true=0.5
   ```

   The posterior converges much more slowly to a narrow peak centred
   in the frequency range — a fair coin is much harder to pin down
   than a clearly biased one, and you can hear the difference directly
   in how much longer the sound stays broad.

3. **`gaussian` mode, defaults**:

   ```sh
   wolframscript -file main.wl -- --simulation.mode=gaussian
   ```

   Listen specifically for the **pitch shift** — the posterior mean
   moving from the prior's centre toward the true value. This makes
   belief revision directly audible as a change in pitch, not just a
   change in sharpness.

4. **`model` mode, defaults**:

   ```sh
   wolframscript -file main.wl -- --simulation.mode=model
   ```

   Listen for the stereo position drifting to one side. The speed of
   the drift tells you how strongly the data favours one hypothesis
   over the other; two accent tones mark the moments the evidence
   crosses "substantial" (K=10) and "very strong" (K=100) thresholds.

## What the sound's width means

In `coin`/`gaussian` modes, the width of the spectral sound directly
encodes uncertainty:

- **Broad, complex sound** — high uncertainty; many parameter values
  remain plausible.
- **Narrow, focused sound** — low uncertainty; the data has pinpointed
  the parameter.
- **A nearly pure tone** — near-certainty; almost all posterior
  probability mass sits at one value.

This is the same spectral encoding [`thermo/`](../thermo/) uses for the
Maxwell-Boltzmann speed distribution, but here the narrowing is driven
by *information* rather than *temperature*. Both apps produce the same
audible convergence-to-a-peak; the underlying mechanism is completely
different. Worth listening to both back-to-back if you have the time.

## The frequentist contrast

A frequentist statistician asks "is the coin fair?" and answers with a
yes/no test and a p-value. A Bayesian statistician asks "what is my
current best estimate of the bias, and how uncertain am I?" The sound
you hear in `coin`/`gaussian` modes *is* the Bayesian answer — an
entire distribution over possible values, continuously updated as data
arrives. A p-value has no direct audio equivalent; a posterior
distribution does.

## Why `coin` mode converges faster with a more extreme bias

If `theta_true=0.9`, almost every flip lands heads — strong, consistent
evidence, and the posterior narrows quickly. If `theta_true=0.51`,
flips look nearly like a coin toss either way — weak, inconsistent
evidence, and the posterior narrows slowly. Try both and compare: the
speed of convergence directly encodes the strength of the signal
buried in the data.

```sh
wolframscript -file main.wl -- --simulation.bayes.theta_true=0.9
wolframscript -file main.wl -- --simulation.bayes.theta_true=0.51
```

## `model` mode: reading the drift direction

The stereo position always drifts toward whichever hypothesis the true
data-generating process actually favours — **left** for H1 (the fair
coin, theta=0.5), **right** for H2 (the biased coin, `theta_alt`). The
default configuration sets `theta_true` equal to `theta_alt` (0.7), so
the data really does come from the biased coin and the drift goes
right. Try flipping the true value to the fair side instead, and the
drift reverses:

```sh
wolframscript -file main.wl -- --simulation.mode=model --simulation.bayes.theta_true=0.5
```

## Tips for listening

- Use headphones for `coin`/`gaussian`'s secondary pentatonic layer and
  especially for `model` mode's stereo drift — both rely on a clear
  left/right image.
- In `coin`/`gaussian` modes, the quiet pentatonic notes underneath the
  main spectral sound are the "summary" layer: pitch tracks the
  posterior mean/location, loudness tracks the posterior variance
  (louder while uncertain, quieter as it resolves).
- Try `--simulation.bayes.n_flips=200` (coin/model) or a different
  `--simulation.bayes.random_seed` to hear how much run-to-run
  variability a single random draw of data can produce, even at a
  fixed true parameter.

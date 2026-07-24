# Central Limit Theorem — Listening Guide

## Recommended listening sequence

1. Start with `sweep` mode at the default (uniform source). Listen for
   the spectrum both narrowing — the pitch spread shrinking as N grows
   — and smoothing into a symmetric bell shape, even though the
   starting distribution (N=1) is completely flat.

   ```sh
   wolframscript -file main.wl
   afplay output/sweep_audio.wav
   ```

2. Try the exponential and bernoulli sources and notice how differently
   lopsided N=1 sounds each time, yet all three converge toward the
   same kind of smooth, symmetric sound by N=30.

   ```sh
   wolframscript -file main.wl -- --simulation.clt.source=exponential
   wolframscript -file main.wl -- --simulation.clt.source=bernoulli \
                                   --simulation.clt.bernoulli_p=0.3
   ```

3. Move to `compare` mode: a uniform distribution in the left channel,
   an exponential distribution in the right — as different as two
   distributions can sound. Listen for the two channels starting
   completely differently and ending up sounding nearly identical.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=compare
   afplay output/compare_audio.wav
   ```

4. Finish with `dice` mode — the most familiar illustration of them
   all. A single die is flat and jagged; ten dice summed together sound
   smooth and unmistakably bell-shaped.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=dice
   afplay output/dice_audio.wav
   ```

## Two facts, not one — don't let them blur together

It is easy to describe the Central Limit Theorem as "things average out
and get more predictable," but that sentence quietly conflates two
separate, both-true facts:

- **The sample mean's own spread genuinely shrinks.** This has nothing
  to do with shape — it is exact and true for any N, from `Var(mean) =
  variance/N`. A coin flipped once has a wildly uncertain "average";
  a coin flipped a thousand times has an average pinned down very
  precisely. This is just the law of large numbers at work, no bell
  curve required.
- **The *shape* becomes Gaussian.** This is the actual Central Limit
  Theorem, and it is the surprising part: it says nothing about *how
  precise* the average becomes, only that its distribution's shape
  converges to one specific universal curve, regardless of whether you
  started from a coin flip, a uniform distribution, or anything else.

`sweep` mode plays both facts happening together, honestly, because
the raw sample mean is where both are simultaneously and correctly
true. `compare` mode isolates the second fact alone by *standardizing*
away the first — the two channels' spreads are artificially forced to
exactly 1 at every N, so the only thing left to converge is shape.

## Why `dice` mode doesn't narrow

A single die's sum has mean 3.5 and variance 35/12 ≈ 2.92. Ten dice
summed have mean 35 and variance 10×35/12 ≈ 29.2 — the variance grew
by a factor of 10, not shrunk. This is not a contradiction of the CLT;
it is what happens when you sonify the raw **sum** instead of the
**mean** (sum = N × mean, and multiplying a shrinking quantity by a
growing N can grow, shrink, or stay flat depending on how fast each
happens — for the sum specifically, it grows). The shape still becomes
Gaussian regardless; `dice` mode's story is honestly about smoothing,
not narrowing.

## Why 511 keV and its cousins don't appear here, but 1/6 does

Unlike `blackbody/`'s visible-light taps or `compton/`'s 511 keV
marker, this app has no single physically-privileged threshold to mark
with an accent tone — the Central Limit Theorem holds for essentially
any source distribution with finite variance, not at one particular
value. What this app *does* have, and checks explicitly, is a piece of
exact combinatorics anyone can verify by hand: two fair dice sum to 7
in exactly 6 of 36 equally likely ways (1+6, 2+5, 3+4, 4+3, 5+2, 6+1) —
probability exactly 1/6, the peak of the classic triangular
two-dice distribution `dice` mode's N=2 panel shows directly.

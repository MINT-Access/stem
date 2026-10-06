# Listening Guide — Logistic Map / Route to Chaos

## The story: a bug population

Think of x as a population of bugs, measured as a fraction of the most
the habitat can hold, and of r as their growth rate. The logistic map
gives next year's population from this year's: x_next = r x (1 − x).
Every note is one year. Each recording opens with a short spoken intro
and closes with a short spoken outro, so you always know when it has
ended.

## Recommended listening sequence (iterate mode presets)

Follow this order to hear the complete route from extinction to chaos:

1. **`extinction`** (r=0.8): the notes sink to the bottom and stay there — the bugs die out.
2. **`growth`** (r=2.0, starting from 0.1): the notes climb for a few years, then hold one pitch — the population grows and settles at half the maximum.
3. **`fixed_point`** (r=2.8): after a short wobble, one note repeating — the population is stable.
4. **`period2`** (r=3.2): two notes alternating — the population oscillates between two values.
5. **`period4`** (r=3.5): four notes cycling — two doublings have occurred.
6. **`period3_window`** (r=3.830): three notes cycling — a surprising island of order inside the chaotic region.
7. **`chaos`** (r=4.0): no pattern — the sequence never repeats.

Each preset's outro explains why: it names the fixed point x* = 1 − 1/r
and the size of the map's slope there, |2 − r|. Below one, the fixed
point attracts and the population settles on it (`growth`: 0.00,
`fixed_point`: 0.80). Above one, it repels, and the population has to do
something else — alternate, cycle or wander (`period2`: 1.20 up to
`chaos`: 2.00). For `extinction` the fixed point is negative, −0.250, so
it is no population at all; the slope at zero is r = 0.80, below one, so
zero attracts and the bugs die out.

```sh
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=extinction
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=growth
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=fixed_point
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=period2
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=period4
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=period3_window
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=chaos
```

Each preset writes its own files, `output/iterate_<preset>_audio.wav`,
`output/iterate_<preset>.gif` and `output/iterate_<preset>_data.csv`
(for example `iterate_growth_audio.wav`), so you can render the whole
sequence and play it back in order. Without a preset the files are
`iterate_audio.wav`, `iterate.gif` and `iterate_data.csv`.

Then listen to `sweep` mode, which traverses the full route from stable
to chaotic in a single audio file:

```sh
wolframscript -file main.wl
```

Finally, listen to `lyapunov` mode, which measures the chaos you have
just heard:

```sh
wolframscript -file main.wl -- --simulation.mode=lyapunov
wolframscript -file main.wl -- --simulation.mode=lyapunov --simulation.dynamical.preset=lyapunov_window
```

## Listening to the Lyapunov exponent (lyapunov mode)

The Lyapunov exponent λ says how fast two almost identical starting
points drift apart. Positive λ: they separate exponentially — chaos.
Negative λ: they converge onto the same cycle — order.

- **The steady tone is zero.** A pure 220 Hz sine sounds throughout.
- **The moving tone is λ.** It is slightly buzzier (it has two quiet
  overtones), so you can tell it from the steady tone even when they
  meet. One octave up or down is one unit of λ.
- **Above the steady tone, chaos; below it, order.**
- **Beating means a crossing is near.** When the two tones are within a
  few hertz of each other you hear a slow pulsing; the pulse slows to
  nothing exactly at the crossing.
- **The moving tone bottoms out** at half an octave below the steady
  tone (λ = −0.5). Deep inside periodic windows λ is far lower; it is
  held there so that none of the moving tone's overtones can ever meet
  the steady tone and fake a crossing.
- **Marker tones**: 660 Hz at the first period doubling (r ≈ 3.0), 880 Hz
  at the second (period 4, r ≈ 3.449), 440 Hz at the onset of chaos
  (r ≈ 3.57), 528 Hz at the period-3 window (r ≈ 3.83). Together they
  make an A minor chord.

What to listen for in the default sweep (2.5 to 4.0, 120 s after the
intro; the intro tells you all of this too): on the way up the moving
tone comes up to the steady tone and falls away again at each period
doubling (r = 3, 3.449 and 3.544). The exponent is exactly zero at a
bifurcation, so you hear slow beating there; on the sweep's grid λ
reaches −0.001, −0.0006 and −0.004 and does not cross. Just after the
onset-of-chaos marker it rises through the steady tone for the first
time, near r = 3.570. From there on it mostly stays above, and each dip
below the steady tone is a window of order inside the chaos. The spoken
outro names the widest three, computed from the run: 3.626 to 3.634
(period 6), 3.739 to 3.744 (period 5) and 3.829 to 3.848 (period 3,
beginning at the 528 Hz marker). At r = 4 the tone ends at λ = log 2,
about 0.69 octave above the steady tone.

The console prints the onset of chaos, then one sentence per window of
order: where it opens and closes, how wide it is in r and in seconds of
audio, and its period when it opens within 0.005 of a known window
(period 3 at 3.828, period 5 at 3.739 and 3.906, period 6 at 3.626). In
the default sweep the period-3 window lasts 1.57 s of audio, the period-6
window 0.6 s and the period-5 window 0.38 s; the other dips are narrower
than 0.1 s. A dip that is below zero at only one r step of the sweep is
reported as spanning a single step, with the grid spacing as the bound
on its width, rather than with a width of zero. Every crossing, and the
five period-doubling points of check 1, are also in the CSV.

The `lyapunov_window` preset zooms into r 3.40 to 3.90 over 40 s, where
the crossings come thick and fast; it matches the listening prototype
this mode was built from.

## Two nearby orbits (divergence mode)

Lyapunov mode tells you *how fast* nearby starting points separate;
divergence mode lets you hear it happen. Two populations start one part
in a million apart and are iterated side by side:

- **Left ear**: the first population, played exactly like iterate mode's
  notes. **Right ear**: the second. While they agree you hear one sound
  in the middle of your head; as they drift apart the sound splits into
  two, one in each ear.
- **The middle tone** (hollow, sustained) is the distance between them:
  up one octave for every three powers of ten. Exponential growth is a
  steady climb, exponential shrinking a steady fall — and the steepness of
  that climb or fall is the Lyapunov exponent.
- **A high 1320 Hz marker** sounds once when the distance first exceeds
  one tenth: from here on the two populations are unrelated. No other
  sound in the app uses this pitch.
- **Tempo**: three years per second, 120 notes (x_0 to x_119, 40 s of
  notes).

Play the four presets in this order (all four are the same length,
63.12 s):

```sh
wolframscript -file main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_chaotic
wolframscript -file main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_edge
wolframscript -file main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_periodic
wolframscript -file main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_stable
```

1. **`divergence_chaotic`** (r = 4.0): the middle tone climbs steadily
   and the marker sounds at iteration 18 (λ predicts 16.6), 6 s into
   the notes; three iterations earlier, at iteration 15, the sound
   has already split into two, and from then on the two ears play unrelated notes.
2. **`divergence_edge`** (r = 3.57): λ is almost zero (+0.011). The
   middle tone creeps up only a little: the separation never exceeds one
   tenth, and its maximum is 2.6 parts in ten thousand (at iteration
   110), as the outro says; the two ears stay together
   throughout.
3. **`divergence_periodic`** (r = 3.2, both populations starting on the
   2-cycle at 0.513): the middle tone falls steadily, at the rate λ
   predicts (fitted slope −0.9164 against λ = −0.9163), then holds at the
   bottom; by iteration 25 the two populations are the same number. The
   two ears are identical throughout.
4. **`divergence_stable`** (r = 2.8): a steady, slow fall — both
   populations settle onto the same fixed point, identical by
   iteration 102. The two ears are identical throughout.

`--simulation.dynamical.divergence.separation_voice=false` leaves only
the two orbits, for pure stereo listening.

## What the event markers mean (sweep mode)

- **First accent tone** (660 Hz): the first period-doubling bifurcation —
  the moment one note became two.
- **Second accent tone** (440 Hz): the onset of chaos — beyond this
  point, long-term prediction becomes impossible.
- **Third accent tone** (528 Hz): the period-3 window — an unexpected
  island of order discovered by mathematicians and guaranteed to exist
  by the Li-Yorke theorem ("period three implies chaos").

## The Feigenbaum constant

The intervals between successive period-doublings shrink by a factor
that tends to 4.669201609… — the Feigenbaum constant. It appears in any
smooth one-dimensional map with a single hump; it is a universal
constant of chaos, like pi is a universal constant of circles.

What this app actually computes (correctness check 1, printed every
time you start it): the first five period-doubling points, where the
period-2, 4, 8, 16 and 32 cycles are born, each located by bisection to
better than 1e-12 in r:

| | r | period born |
|---|---|---|
| r1 | 3.0000000 | 2 |
| r2 | 3.4494897 | 4 |
| r3 | 3.5440904 | 8 |
| r4 | 3.5644073 | 16 |
| r5 | 3.5687594 | 32 |

and from them three ratios of successive intervals:

| ratio | value | difference from 4.669201609 |
|---|---|---|
| δ1 = (r2 − r1)/(r3 − r2) | 4.75145 | +0.0822 (1.8 %) |
| δ2 = (r3 − r2)/(r4 − r3) | 4.65625 | −0.0130 (0.28 %) |
| δ3 = (r4 − r3)/(r5 − r4) | 4.66824 | −0.00096 (0.021 %) |

The ratios do not equal the constant; they approach it, alternating
above and below, each one closer than the last. The check passes when
δ3 is within 0.5 % of the constant and the differences shrink at every
step. The constant itself is the limit of this sequence. In the
lyapunov animation the five points are the small green ticks above the
top panel: r3, r4 and r5 crowd together within 0.025 of each other
just before chaos begins at r ≈ 3.5699, which is what "shrinking by a
factor of 4.669" looks like.

## A note on the period-3 window value

The period-3 window is often cited as beginning at r = 3.8284. That
value is the window's exact opening point (a tangent bifurcation), and
convergence to the clean 3-cycle right at that point is extremely slow
— you would need many thousands of iterations to hear a clean rhythm
there. The `period3_window` preset instead uses r = 3.830, just inside
the window's interior, where the 3-cycle is reached solidly within the
default 300 iterations. If you want to explore the window's edge
yourself: `--simulation.dynamical.r=3.8284 --simulation.dynamical.n_iterations=5000`.

## Tips for listening

- Use headphones — stereo pan tracks the map's value directly (low x
  is panned left, high x is panned right), so periodic cycles have a
  audibly stable left-right pattern while chaos wanders unpredictably.
- Volume tracks how much the value changed from the previous iteration
  — periodic attractors settle into a fairly steady volume, while the
  chaotic region sounds more energetic and varied.
- In sweep mode, the spoken introduction says what to listen for — the
  rhythm doubling, then chaos, with a brief return to order — and the
  three accent tones mark those moments.
- Try `--simulation.dynamical.r_steps=1000` for a much finer sweep, or
  `--simulation.dynamical.note_duration=0.04` for a faster rhythm.

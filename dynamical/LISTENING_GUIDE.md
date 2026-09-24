# Listening Guide — Logistic Map / Route to Chaos

## Recommended listening sequence (iterate mode presets)

Follow this order to hear the complete route from order to chaos:

1. **`fixed_point`** (r=2.8): one note, repeating forever — the population is stable.
2. **`period2`** (r=3.2): two notes alternating — the population oscillates between two values.
3. **`period4`** (r=3.5): four notes cycling — two doublings have occurred.
4. **`period3_window`** (r=3.830): three notes cycling — a surprising island of order inside the chaotic region.
5. **`chaos`** (r=4.0): no pattern — the sequence never repeats.

```sh
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=fixed_point
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=period2
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=period4
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=period3_window
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=chaos
```

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
intro): the moving tone stays below the steady tone, rising to touch it
at each period doubling (r = 3.0, 3.449 and 3.544, where λ reaches
−0.001, −0.0006 and −0.004) and falling away again — you hear slow
beating there although λ does not cross zero. Just
after the onset-of-chaos marker it rises through the steady tone for the
first time, near r = 3.570. From there on it mostly stays above, with
brief dives below at each periodic window — the widest is the period-3
window, which begins at the 528 Hz marker. At r = 4 it ends at λ = log 2,
about 0.69 octave above the steady tone. The console lists every
crossing with the time you hear it.

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
- **A 440 Hz marker** sounds once when the distance first exceeds one
  tenth: from here on the two populations are unrelated.

Play the four presets in this order (all four are the same length,
about a minute):

```sh
wolframscript -file main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_chaotic
wolframscript -file main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_edge
wolframscript -file main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_periodic
wolframscript -file main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_stable
```

1. **`divergence_chaotic`** (r = 4.0): the middle tone climbs steadily
   and the marker sounds at iteration 18 (λ predicts 16.6, 1.44 s into
   the notes); three iterations earlier, at iteration 15, the sound
   has already split into two, and from then on the two ears play unrelated notes.
2. **`divergence_edge`** (r = 3.57): λ is almost zero (+0.011). The
   middle tone creeps up only a little, from one part in a million to
   three parts in ten thousand; the two ears stay together throughout.
3. **`divergence_periodic`** (r = 3.2): the middle tone falls, then holds
   at the bottom once the distance is below one part in a million
   million; by iteration 42 the two populations are the same number.
   The two ears are identical throughout. (It first rises a little: both
   orbits linger near an unstable point before they settle.)
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
of approximately 4.669 each time. This number appears in any smooth
one-dimensional map with a single hump — it is a universal constant
of chaos, like pi is a universal constant of circles. The correctness
checks that run every time you start this app locate the first three
bifurcation points numerically and verify this ratio directly (see
`--simulation.mode` output, "Correctness checks").

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
- In sweep mode, the spoken introduction previews all three event
  r-values before the sweep begins, so you know what to listen for.
- Try `--simulation.dynamical.r_steps=1000` for a much finer sweep, or
  `--simulation.dynamical.note_duration=0.04` for a faster rhythm.

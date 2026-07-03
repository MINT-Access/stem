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

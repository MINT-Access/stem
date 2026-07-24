# Listening Guide — The Hénon Map

## Recommended listening sequence

Follow this order to hear the map from three complementary angles: the
attractor itself, its route to chaos, and proof that it can run
backwards.

1. **`attractor`** (default): the settled strange attractor, sonified as
   a continuous, flowing trajectory — pan tracks `x_n` left-to-right,
   pitch tracks `y_n`, and accent tones mark the turning points where the
   trajectory folds back on itself.
2. **`sweep`**: the full period-doubling route to chaos, `a` from 0.2 to
   1.4. Listen for the rhythm doubling — one note, then two, then four,
   then eight — before dissolving into chaos, and for a brief, surprising
   return to a 7-note cycle partway through the chaotic region.
3. **`reverse`**: a short forward segment, a marker tone, the same
   segment played backwards, another marker, then a short proof that the
   map's inverse formula genuinely recovers the earlier points exactly.

```sh
wolframscript -file main.wl
wolframscript -file main.wl -- --simulation.mode=sweep
wolframscript -file main.wl -- --simulation.mode=reverse
```

## What the event markers mean

### sweep mode

- **First accent tone** (660 Hz): the first period-doubling bifurcation,
  at `a≈0.3675` — an EXACT value, derived from where the fixed point's
  stability eigenvalue crosses -1 (not just located empirically, though
  it was independently cross-checked that way too).
- **Second accent tone** (440 Hz): the onset of chaos, at `a≈1.0508` —
  beyond this point, the settled trajectory no longer repeats at all.
- **Third accent tone** (528 Hz): a period-7 window, at `a≈1.227` — an
  unexpected pocket of order inside the otherwise chaotic region, the
  same "island of order" idea `dynamical/`'s period-3 window
  demonstrates for the logistic map.

### reverse mode

- **First marker tone** (990 Hz): the turn from the forward segment into
  its reversed replay.
- **Second marker tone** (990 Hz): the turn from the reversed replay into
  the short exact-inverse demonstration — listen for the recovered notes
  matching the corresponding forward notes almost exactly (they are
  numerically identical to within about 2e-11).

## Why the Hénon map sounds different from `dynamical/`'s logistic map

The logistic map is one-dimensional: a single value bounces around
`[0,1]`, so `dynamical/sweep`'s pitch and pan are BOTH driven by that one
number. The Hénon map is genuinely two-dimensional, so `sweep`/`reverse`
mode here has two independent numbers to work with — `x_n` drives pitch,
`y_n` drives pan — giving a noticeably richer stereo image even in the
period-1 and period-2 regions where the logistic map would sound
completely static.

## A note on `attractor` mode's pitch/pan mapping

`attractor` mode uses the OPPOSITE convention from `sweep`/`reverse`: `x_n`
drives pan, `y_n` drives pitch. This isn't an inconsistency — `attractor`
mode reuses `lorenz/`'s own continuous-trajectory sonification technique
(and its exact column conventions) directly, while `sweep`/`reverse` reuse
`dynamical/`'s discrete-note idiom instead, which made its own independent
choice about which axis serves which role. See `AGENTS.md` design
decisions 3-4 for the full reasoning.

## Tips for listening

- Use headphones — stereo pan carries real spatial information in every
  mode, and the two modes' opposite x/y-to-pitch/pan conventions are
  easiest to notice with a stereo image you can actually localise.
- In `sweep` mode, the spoken introduction previews all three event
  a-values before the sweep begins, so you know what to listen for.
- Try `--simulation.henon.a_steps=500` for a much finer sweep, or
  `--simulation.henon.note_duration=0.05` for a faster rhythm.
- In `attractor` mode, try `--simulation.henon.n_points=5000` for a
  denser, longer-riding trajectory (also improves the box-counting
  dimension estimate's accuracy).
- `--simulation.henon.reverse_steps=20` in `reverse` mode makes the
  round-trip error visibly larger in the printed summary — a direct,
  audible-adjacent way to see the area-expansion effect described in
  `README.md` without breaking anything (20 steps is still comfortably
  short of where it would actually matter).

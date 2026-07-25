# Listening Guide — Grover's Search Algorithm

## Recommended listening sequence

Follow this order to hear Grover's algorithm from three complementary
angles: the optimal-stopping probability curve, the speedup as a
literal race, and the exact geometric mechanism behind both.

1. **`search`** (default): a rising sequence of notes peaking at a
   bright accent tone (the optimal iteration), then falling again if
   the notes continue. Listen for the accent — and for the fact that
   the notes *keep going* past it, getting quieter/lower again, proof
   that more iterations is not automatically better.
2. **`compare`**: two channels tick at once. Listen for which channel
   reaches its "found" chime first — the right (quantum) channel
   should finish dramatically sooner than the left (classical) one,
   which keeps ticking long after.
3. **`geometry`**: a continuously rotating stereo position with a
   pitch that peaks each time the rotation swings closest to the
   marked state. Listen for the same peaks `search` mode's accent
   marked, now heard as points along a smooth, continuous sweep.

```sh
wolframscript -file main.wl
wolframscript -file main.wl -- --simulation.mode=compare
wolframscript -file main.wl -- --simulation.mode=geometry
```

## Why `search` mode keeps playing notes after the accent tone

The accent marks the mathematically optimal stopping point, but the
app deliberately keeps iterating a few steps further (see
`simulation.grover.n_iterations` in `config.json`) so you can hear
`P(marked)` fall again — over-rotating past the optimum genuinely
makes the search worse, not just "no better." This is worth listening
for specifically: it is the single clearest audible demonstration that
Grover's algorithm has a real, non-obvious optimal stopping point, not
just "do more iterations, get a better answer."

## Why `compare` mode's two channels don't sound symmetric

They are not meant to. The left (classical) channel plays roughly
`N/2` ticks — a realistic *average-case* estimate of how many items a
plain linear search would need to check. The right (quantum) channel
plays only `~(Pi/4)*Sqrt[N]` ticks — Grover's exact optimal count. Both
start together; the right channel's "found" chime rings out first, by
a wide margin, and then the left channel continues alone for a while
longer. That asymmetry — one channel finishing while the other is
still working — *is* the quantum speedup, made audible without needing
any numbers at all.

## Why `geometry` mode's pitch and `search` mode's pitch are the same curve

Both modes ultimately track `P(marked)` as pitch — `geometry` mode
just derives it from a continuously rotating angle instead of a
discrete iteration count. Listen to `search` and `geometry` back to
back: the moments where `geometry`'s pitch peaks should line up with
`search`'s accented notes. They are the same physics, sonified two
ways.

## Tips for listening

- Use headphones — `compare` mode's race and `geometry` mode's
  rotation both rely on genuine stereo separation.
- Try `--simulation.grover.n_items=1024` for a much larger search
  space — `search` mode's optimal iteration count grows substantially,
  and `compare` mode's speedup becomes far more dramatic.
- Try `--simulation.grover.n_iterations=25` in `search` or `geometry`
  mode (with the default N=64) to hear/see a second, smaller rise
  begin after the first fall — the probability curve is genuinely
  periodic, not just "rises once."
- `output/grover_compare.png` shows the classical/quantum gap growing
  across a wide range of N, on a log-log scale — worth viewing
  alongside listening to a single-N `compare` run.
- `output/grover_geometry.gif` shows the literal 2D rotation the audio
  sonifies — watch the vector sweep toward `|w>` and back as you
  listen.

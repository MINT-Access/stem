# Listening Guide — Entanglement and the CHSH Inequality

## Recommended listening sequence

Follow this order to hear entanglement from three complementary
angles: a continuous quantum-vs-classical comparison, the actual
inequality-violating number, and quantum randomness on each side
individually resolving into an unmistakable correlation.

1. **`correlations`** (default): a sweeping angle difference. Listen
   for the gap between the LEFT channel (what any local hidden-variable
   theory could produce) and the RIGHT channel (the real quantum
   correlation) — the two curves agree at the extremes but pull apart
   everywhere else.
2. **`chsh`**: four short notes build up to a sustained two-tone
   verdict. Listen for the gap between the LEFT tone (the classical
   ceiling, `S=2`) and the RIGHT tone (the actual measured `S`,
   `2*Sqrt[2] ~= 2.83`) — that gap is Bell's theorem made audible.
3. **`measurement`**: individually unpredictable clicks (Alice left,
   Bob right), then a continuous glissando. Listen for the clicks
   sounding random on each side alone, and the glissando settling onto
   a steady pitch as the running correlation converges.

```sh
wolframscript -file main.wl
wolframscript -file main.wl -- --simulation.mode=chsh
wolframscript -file main.wl -- --simulation.mode=measurement
```

## Why `correlations` mode is binaural, not a single tone

The whole point of a Bell test is comparing two predictions side by
side — what quantum mechanics says will happen, and what the best
possible local (non-quantum) explanation could say instead. Putting
each in its own ear lets you track both curves at once and hear
exactly where they agree (at `delta=0` and `delta=+-180`, both predict
perfect correlation/anti-correlation) and where they diverge most
(around `delta=+-90`, where the classical model's V-shape crosses zero
early while the real cosine curve is still strongly correlated).

## What the `chsh` mode build-up notes mean

Each of the four short notes is one of the four terms that sum to
`S`: `E(a,b)`, then `-E(a,b')`, then `+E(a',b)`, then `+E(a',b')`.
Watch `output/bell_chsh.gif` alongside the audio — the gauge needle
moves after each note, landing on the final `S` exactly when the
fourth note ends and the sustained verdict tones begin.

## Why `measurement` mode sounds random on each side but correlated overall

Individually, Alice's clicks and Bob's clicks are exactly 50/50
unpredictable — no way to guess the next one from the previous ones,
on either side alone. This is not a flaw; it is required for
entanglement to be compatible with relativity (no signal can be sent
by looking at one side alone — see `AGENTS.md` design decision 3). The
correlation only becomes apparent by comparing the TWO STREAMS against
each other, which is exactly what the running-correlation glissando
does: it is silent about either side's individual randomness and
audible only about how the two sides relate.

## Tips for listening

- Use headphones — every mode in this app relies on genuine stereo
  separation (left vs. right, not just left-right panning of a single
  signal).
- Try `--simulation.bell.chsh_a_deg=0 --simulation.bell.chsh_ap_deg=90
  --simulation.bell.chsh_b_deg=0 --simulation.bell.chsh_bp_deg=90` for
  the "naive" 90-degree-separated CHSH angles — the verdict tones
  should land on almost the same pitch, since this choice only reaches
  the classical bound, not the quantum one.
- Try `--simulation.bell.alice_angle_deg=0 --simulation.bell.bob_angle_deg=90`
  in measurement mode for perpendicular settings — the running
  correlation should settle near zero, audibly wandering rather than
  converging to a clear pitch.
- Try `--simulation.bell.alice_angle_deg=0 --simulation.bell.bob_angle_deg=180`
  in measurement mode for perfect anti-correlation — every single
  trial, Alice and Bob get opposite outcomes.
- `output/bell_correlations.png` and `output/bell_chsh.png` both show
  the same classical/quantum gap that the audio makes audible — worth
  viewing alongside listening.

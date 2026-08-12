# Listening Guide — A Single Qubit

## Recommended listening sequence

Follow this order to hear a qubit from three complementary angles: gate
operations as continuous rotations, a textbook two-level system's exact
oscillation, and quantum randomness becoming statistical certainty.

1. **`gates`** (default): a sequence of gates (H, T, H, S, X) applied to
   `|0>`. Listen for the continuous rotation each gate produces — pan and
   pitch trace the Bloch vector's own path — and a short accent tone
   marking the start of each new gate.
2. **`rabi`**: continuous Rabi oscillation. Listen for the pitch rising
   and falling smoothly — the rate of that rise and fall IS the drive
   frequency Omega, made directly audible.
3. **`measurement`**: 2000 repeated measurements of an equal
   superposition. Listen for a wobbly pitch that gradually settles as
   more measurements accumulate — the empirical frequency converging
   toward the true probability.

```sh
wolframscript -file main.wl
wolframscript -file main.wl -- --simulation.mode=rabi
wolframscript -file main.wl -- --simulation.mode=measurement
```

## What the gate accent tones mean

Each accent tone (660 Hz) marks the moment a new gate begins its
rotation. Between accents, the continuous pitch/pan glide IS that gate's
rotation happening — count the accents to know how many gates have
completed.

## Why `gates` mode sounds continuous, not like discrete clicks

A gate is not really a "jump" from one state to another — it's a genuine
rotation of the Bloch vector about some axis, happening continuously
(physically, over the gate's actual operation time). This app makes that
rotation audible AS a rotation: the pan/pitch glide smoothly from the
pre-gate state to the post-gate state along the sphere's surface, rather
than snapping discretely. Watch `output/qubit_gates.gif` alongside the
audio — the path traced on the 3D sphere and the audio's glide should
feel like the same motion viewed two ways.

## Why `rabi` and `measurement` sound similar

Both modes use the exact same underlying sonification technique — a
single scalar value tracked continuously as a pitch glissando — because
both are, mathematically, "one number evolving over an index axis"
(`P(1)(t)` for `rabi`, the running measurement frequency for
`measurement`). Listen for the difference in CHARACTER rather than
technique: `rabi`'s pitch is smooth and perfectly periodic (an exact
closed-form solution); `measurement`'s pitch is noisy and irregular at
first, gradually smoothing out as more trials accumulate (a Monte Carlo
estimate, not an exact formula).

## Tips for listening

- Use headphones — `gates` mode's stereo pan carries real spatial
  information tracking the Bloch vector's x-coordinate.
- Try `--simulation.qubit.rabi_frequency=4.0` for a much faster Rabi
  oscillation — the pitch wobble noticeably speeds up.
- Try `--simulation.qubit.measurement_theta_deg=36.87` for a skewed
  (non-50/50) state — the pitch should settle near a different point
  than the equal-superposition default.
- `output/qubit_measurement.png` shows the true probability as a dashed
  reference line — compare where the noisy curve actually settles
  against it.

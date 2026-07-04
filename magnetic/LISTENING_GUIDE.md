# Magnetic — Listening Guide

## Recommended listening sequence

1. **`cyclotron`** (default) — a steady tone whose pitch *is* the
   cyclotron frequency. Count the accent tones (one "ping" per
   completed orbit) against a clock to measure the orbital period
   directly by ear.

   ```sh
   wolframscript -file main.wl
   ```

2. **Add a helix** — same steady panning, but the particle now also
   drifts along the field line, adding a slow pitch glide on top of
   the steady tone.

   ```sh
   wolframscript -file main.wl -- --simulation.magnetic.v_parallel=0.5
   ```

3. **`drift`** — hear the cycloid as a stereo pan that slides steadily
   from one side to the other while the pitch oscillates underneath
   it. The pan sweep *is* the E x B drift; the oscillation *is* the
   circular motion riding along on top of it.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=drift
   ```

4. **`mirror`** — the most dramatic narrative arc: pitch rises as the
   particle approaches a mirror point, falls as it retreats, with a
   sharp accent at each reflection. Try both the trapped default and
   a shallow pitch angle that escapes instead.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=mirror
   wolframscript -file main.wl -- --simulation.mode=mirror \
     --simulation.magnetic.v_perp=0.4 --simulation.magnetic.v_parallel=2.0 \
     --simulation.magnetic.alpha=0.08
   ```

5. **`multi`** — a chord of three cyclotron frequencies encoding the
   mass ratios of fundamental particles: proton left, alpha centre,
   electron right (frequency-scaled so it stays audible).

   ```sh
   wolframscript -file main.wl -- --simulation.mode=multi
   ```

## Why the cyclotron frequency is musically natural

`omega_c = qB/m` depends only on the charge-to-mass ratio and the
field strength — never on the particle's speed. That is exactly why
it maps so cleanly onto a musical pitch: it is an intrinsic resonance
of the particle-field system, not a property of any one moment of the
motion. Changing `B_z` is like changing the key; changing
`charge_mass_ratio` is like changing the instrument.

## The magnetic mirror and the Van Allen belts

Earth's magnetic field is a natural magnetic mirror: it is weakest
over the equator and strengthens toward each pole. Charged particles
from the solar wind get trapped in this geometry, bouncing back and
forth between mirror points near the two poles — this is exactly what
forms the Van Allen radiation belts. The `mirror` mode sonifies the
same physics, compressed onto a human timescale: the rising-falling
pitch is the particle's approach to and retreat from a mirror point,
and the accent tones are the reflections themselves.

## The `multi` mode chord

The three cyclotron frequencies sit in the ratio `1 : 1/2 : 1836`
(proton : alpha : electron). Proton and alpha are exactly one octave
apart (ratio 2:1) — a clean musical interval, and not a coincidence:
the alpha particle's charge-to-mass ratio is exactly half the
proton's. The electron's actual frequency (1836x the proton's) sits
far above the audio range, so it is rescaled to three octaves above
the proton (8x) instead — this preserves the musical *shape* of "much
higher" while keeping the actual ratio's true scale explained in the
spoken introduction.

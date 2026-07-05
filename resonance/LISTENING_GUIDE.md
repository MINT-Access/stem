# Resonance — Listening Guide

## Recommended listening sequence

1. Start with `galilean` mode. Count the Io notes (highest pitch, C5)
   between each Ganymede note (lowest pitch, C3) — you should hear
   exactly 4 Io notes per Ganymede note, and exactly 2 Europa notes
   (C4). The repeating pattern is a three-voice musical canon that has
   been playing in the Jovian system for billions of years.

   ```sh
   wolframscript -file main.wl
   ```

2. Listen to `kirkwood` mode — first the chord (all simultaneously),
   then the sweep. During the sweep, listen for the silences: these are
   the Kirkwood gaps, regions of the asteroid belt emptied by Jupiter's
   gravitational resonances.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=kirkwood
   ```

3. Finally listen to `saturn` mode. Follow the sweep from left (inner
   rings) to right (outer rings). The long silence in the middle is the
   Cassini Division — visible as a dark gap in Saturn's rings through
   any small telescope, and audible here as a pause in the ring sound.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=saturn
   ```

## Why 4:2:1 sounds like music

The frequency ratio 2:1 is a musical octave — the most consonant
interval in Western music theory. The ratio 4:1 is two octaves. So the
Galilean resonance 4:2:1 literally places three sounds an octave apart
from each other — the most harmonious possible spacing. This is not a
coincidence or a metaphor: the same mathematical property of integer
ratios that makes octaves sound stable to the ear is what makes orbital
resonances dynamically stable over billions of years.

## Resonance as clearing mechanism

In the Kirkwood gaps and Saturn's Cassini Division, resonance acts as
an ejection mechanism rather than a stabilising one. Asteroids or ring
particles at these resonances receive repeated gravitational kicks from
Jupiter or Mimas at the same orbital phase, accumulating perturbations
that eventually drive them into eccentric orbits — they are ejected
from the resonance location rather than locked in. The silences in the
audio are the aftermath of billions of years of this clearing.

## Kepler's Harmonices Mundi

In 1619, Johannes Kepler published Harmonices Mundi (The Harmony of the
World), arguing that the planets move in ratios corresponding to
musical intervals. He was numerologically overenthusiastic — most of
his specific claims don't hold up. But the Galilean moons, discovered
by Galileo in 1610, really do orbit in exact musical ratios. Kepler was
right about the idea, even if he was wrong about most of the details.

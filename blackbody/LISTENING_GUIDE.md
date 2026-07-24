# Black Body Radiation — Listening Guide

## Recommended listening sequence

1. Start with `spectrum` mode at the default solar temperature. Listen
   to the chord first (the whole radio-to-X-ray curve sounding at
   once), then the sweep (the same curve, one bin at a time, low
   frequency to high). Two soft taps mark the edges of the visible
   band — notice how briefly they occur relative to the whole sweep.

   ```sh
   wolframscript -file main.wl
   afplay output/spectrum_audio.wav
   ```

2. Then try `spectrum` mode at a much cooler and much hotter
   temperature, and notice the taps landing in a completely different
   place in the sweep — cooler stars emit almost nothing in the
   visible band; hotter ones have already moved past it into the
   ultraviolet.

   ```sh
   wolframscript -file main.wl -- --simulation.blackbody.temperature=3200
   wolframscript -file main.wl -- --simulation.blackbody.temperature=25000
   ```

3. Move to `temperature` mode and listen for two things changing at
   once: the marked peak rising in pitch (Wien's law), and the overall
   chord growing louder (Stefan-Boltzmann's law, compressed so it stays
   listenable across the whole sweep).

   ```sh
   wolframscript -file main.wl -- --simulation.mode=temperature
   afplay output/temperature_audio.wav
   ```

4. Finally, take the `star` mode tour through six real objects, coolest
   to hottest — the same two trends from step 3, now attached to real
   stars and stellar remnants instead of an abstract sweep.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=star \
                                   --simulation.blackbody.preset=all
   afplay output/star_audio.wav
   ```

## Why the Sun looks white (and yellow only near the horizon)

At 5778 K, the Sun's emission peaks at almost exactly 502 nm — squarely
in the visible band, close to the green-blue boundary. Human colour
vision evolved under this exact spectrum, which is why sunlight (a
broad mixture spanning the whole visible band, not a single colour)
reads as "white" rather than any one hue. The Sun looks yellow or
orange near sunset only because the atmosphere scatters away more blue
light along the long, low-angle path the light travels at dusk — not
because the Sun's own spectrum has shifted.

## Why you cannot see most of the light a star emits

`spectrum` mode's sweep runs from radio waves to X-rays — around 13
orders of magnitude in frequency. The visible band (400-700 nm) that
the two accent taps mark off is a sliver of that whole range, typically
well under a tenth of it in log-frequency terms. Every star emits
across the *entire* curve, not just the visible sliver; human eyes
evolved to see only the narrow band where the Sun's own curve happens
to peak.

## Why loudness in `temperature` mode is compressed

Total emitted power grows as T⁴ (the Stefan-Boltzmann law) — across
this app's 2500 K to 40000 K range, that is a factor of over 65,000.
Mapped directly to volume, the cool end would be silent and the hot end
would clip instantly. `temperature` mode instead maps loudness to
`log(T⁴)`, rescaled onto a comfortable range — the compression itself
is part of the point: it is the only way to make a genuinely
enormous physical range audible at all without losing either end.

## Reading the "Peak" marker

Every plot in this app marks the wavelength where the curve is loudest
with a red dot labelled "Peak" (or a star's name, in `star` mode's
composite plot) — the same red-dot convention `cosmology/`'s CMB
spectrum plot uses for its acoustic peaks. In `spectrum` and `star`
mode's single-preset runs, this is the one number Wien's law predicts
for that temperature; in the composite `temperature` and `star`
(`preset=all`) plots, watching the dot walk from right to left across
several curves *is* Wien's displacement law, drawn directly.

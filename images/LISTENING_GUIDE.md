# Listening Guide — Image Sonification

## What this app does

This app sonifies 2D scientific images — temperature maps, probability
densities, spectral plots, false-colour visualisations — so that their
spatial structure is accessible through audio. Unlike the other stem apps,
which sonify time-series data produced by a physics simulation (a pendulum
swinging, an attractor evolving, a wave propagating), this app sonifies a
*spatial field*: a single static image, traversed pixel by pixel and turned
into a sequence of notes. Every run begins with a short spoken introduction
that tells you what image you're about to hear, its size, the mode in use,
and how to interpret the pitches and timbres that follow.

## How to start (recommended listening sequence)

1. **Run `scan_horizontal` mode first**, on the Gaussian test image:

   ```sh
   wolframscript -file main.wl -- --simulation.mode=scan_horizontal
   ```

   Listen to the simple left-to-right, row-by-row sweep. Pitch rises as
   the scan crosses the bright centre of the image on each row, then falls
   as it moves back toward the dark edges on the next row — but the jump
   back to the start of each new row is abrupt, because raster order isn't
   spatially local.

2. **Then run `brightness` (Hilbert) mode** on the same image:

   ```sh
   wolframscript -file main.wl -- --simulation.mode=brightness
   ```

   Compare the two directly. The Hilbert version should feel more
   coherent and less jumpy, because nearby pixels in the image stay
   nearby in time in the audio — the curve never teleports across the
   image the way a raster scan does at the end of every row.

3. **Then try `colour` mode** with the temperature map test image:

   ```sh
   wolframscript -file main.wl -- --simulation.mode=colour --simulation.images.test_image=temperature
   ```

   Use the pitch table below to follow along as concentric colour bands
   become held notes.

4. **Finally, try a real scientific image of your own:**

   ```sh
   wolframscript -file main.wl -- --simulation.images.input_file=yourimage.png
   ```

## Colour mode pitch table

Colours are ordered by their position in the visible light spectrum —
violet (shortest wavelength) to red (longest) — with white and black as
endpoints for broadband/saturated and absent/zero colour. Pitch rises
with spectral position, so the pitch contour tracks the rainbow directly.

| Colour | Pitch | Frequency | What it sounds like in a scientific image |
|--------|-------|-----------|---------------------------------------------|
| Violet | C3 | 130.81 Hz | Shortest-wavelength regions; often edges or cold extremes |
| Blue   | D3 | 146.83 Hz | Cool regions in false-colour temperature/density maps |
| Cyan   | F3 | 174.61 Hz | Transition zone between cool and mid-range values |
| Green  | G3 | 196.00 Hz | Mid-range values |
| Yellow | A3 | 220.00 Hz | Warm-transition values |
| Orange | C4 | 261.63 Hz | Warm regions |
| Red    | D4 | 293.66 Hz | Longest-wavelength regions; often peaks or hot extremes |
| White  | G4 | 392.00 Hz | Broadband or fully saturated pixels |
| Black  | — (silent) | 0 Hz | Absent or zero-value regions — heard as a rest, not a note |

A long held note means a large uniform colour region — the run-length
encoding merges consecutive same-colour pixels into one note whose
duration is proportional to the region's size, so you can literally hear
how big an area of a given colour is.

## Tips for listening

- **Use headphones.** Stereo position carries scientific information in
  `hsb` mode — the same fundamental pitch plays in both ears, but only
  comparing the two tells you the difference between the pure reference
  tone (left) and the brightness-enriched timbre (right).
- **Duration = region size.** In `colour` mode, the length of a held note
  tells you the size of a uniform region — a long note means a large area
  of that colour, a rapid flicker of short notes means a busy, detailed
  boundary.
- **The spoken intro previews the range.** In `brightness` mode, the
  intro's scaling announcement (linear vs. logarithmic) tells you how
  pitch will map to brightness before you hear a single pixel — logarithmic
  scaling (the default) matches how human hearing perceives frequency and
  suits most scientific data, which is rarely uniformly distributed.
- **Large images take longer, but have orientation clicks.** Images
  128×128 or larger take longer to sonify. In `brightness` and `hsb`
  modes, soft 880 Hz click markers at the 25%, 50%, and 75% points of the
  traversal help you stay oriented without interrupting the audio with
  speech.

## Connection to Rao's work

The Hilbert-curve traversal and the row-by-row brightness/colour mapping
in this app build on Neha Rao's 2025 Wolfram Summer Research Program work,
*Sonification Strategies for 2D Images*, which explored general-purpose
image accessibility using a chord-tone palette and nearest-colour matching
(`compareColor[]`). This app adapts those ideas for a scientific context:
the colour palette is reordered by physical wavelength rather than musical
chord tones, so pitch tracks a meaningful physical quantity (spectral
position) instead of an arbitrary harmonic choice; the nearest-colour
lookup uses perceptually uniform Lab colour distance rather than raw RGB
Euclidean distance; brightness mapping defaults to a logarithmic scale to
match both human hearing and the statistical distribution of most
scientific data; and the run-length-encoding principle behind held notes
is kept and extended with a configurable duration-per-pixel factor. The
`hsb` mode's timbre-as-brightness design and the spoken/click orientation
layers are stem-specific additions with no counterpart in Rao's original
work.

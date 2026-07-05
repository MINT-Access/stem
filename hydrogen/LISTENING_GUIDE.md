# Hydrogen Atom — Listening Guide

## Recommended listening sequence

1. Start with `spectrum` mode. Listen to the chord first (all lines
   simultaneously), then the sweep (each line in turn). The four Balmer
   lines — marked with bell tones — are the visible light lines that
   appear as dark absorption lines in the solar spectrum and in the
   spectra of every star observed with a telescope.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=spectrum
   afplay output/spectrum_audio.wav
   ```

2. Then listen to `transitions` mode starting from n=5. Listen for 20
   different quantum melodies, each a different path down the energy
   ladder. Notice which notes appear in most realisations (the most
   probable transitions) and which are rare.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=transitions
   afplay output/transitions_audio.wav
   ```

3. Finally try `orbitals` mode with different orbitals — compare the
   smooth central sweep of the 1s orbital with the two-lobe structure
   of the 2p, and the complex multi-lobe structure of the 3d.

   ```sh
   wolframscript -file main.wl -- --simulation.hydrogen.orbital=100
   wolframscript -file main.wl -- --simulation.hydrogen.orbital=210
   wolframscript -file main.wl -- --simulation.hydrogen.orbital=321
   ```

## What the Balmer series means

The four Balmer lines (Hα, Hβ, Hγ, Hδ) were discovered empirically by
Johann Balmer in 1885 — he found a simple formula fitting the
wavelengths without knowing why. In 1913, Niels Bohr explained them
using the first quantum model of the atom. In 1926, the Schrödinger
equation gave the exact solution still used today. These four
frequencies are literally the colour of hydrogen — they appear in
stellar atmospheres, nebulae, and discharge tubes everywhere.

## Why orbitals have nodes

A node is a surface where the wave function is exactly zero — the
electron has zero probability of being found there. The 2s orbital has
one radial node (a spherical shell of zero probability); the 2p has one
angular node (a plane); the 3d has various nodal surfaces depending on
m. In the Hilbert scan, nodes appear as silences — brief gaps in the
pitch stream that mark the boundaries between lobes of the wave
function.

## Quantum randomness in the cascade

No two cascade realisations follow the same path, even starting from
the same state. This is not a limitation of the simulation — it is
fundamental quantum mechanics. The selection of which transition occurs
is genuinely random, governed only by the relative transition
probabilities. The fact that all paths end on the same note (the ground
state) is one of the few things that is certain.

One curiosity worth knowing about: the 2s state is metastable — an
electron that lands there cannot decay to 1s by ordinary (electric
dipole) photon emission at all, because the required change in orbital
angular momentum (Δl = 0) is forbidden. Real hydrogen atoms that land in
2s survive for a comparatively enormous time (milliseconds, versus
nanoseconds for most excited states) before decaying via a much rarer
two-photon process. This app's cascade simulation treats 2s as an
excluded stepping stone for exactly this reason, so every realisation
you hear is guaranteed to reach the true 1s ground state.

## Listening for the spectral series by ear

- **Lyman** (→ n=1): the shortest wavelengths, ultraviolet, mapped to
  the highest audio pitches in spectrum mode's sweep.
- **Balmer** (→ n=2): visible light, the four lines marked with bell
  accents — this is the light you would actually see coming from
  a hydrogen discharge tube.
- **Paschen** (→ n=3) and beyond: infrared, the lowest audio pitches,
  invisible to the eye but audible here.

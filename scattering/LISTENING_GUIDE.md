# Scattering — Listening Guide

## Recommended listening sequence

1. **`scatter`, backscatter preset** (`b=0`, `theta=180 deg`) — the
   simplest possible scattering event. The particle approaches head-on,
   hits maximum pitch and volume, then retreats along the exact same
   line. A clean approach-peak-retreat shape.

   ```sh
   wolframscript -file main.wl -- --simulation.scattering.preset=backscatter
   ```

2. **`scatter`, moderate preset** (`b=1`, `theta=90 deg`, the default) —
   the particle curves around the nucleus at a right angle. Listen for
   the asymmetric approach and departure as the stereo pan moves.

   ```sh
   wolframscript -file main.wl
   ```

3. **`scatter`, glancing preset** (`b=5`, small `theta`) — the particle
   barely deflects. The pitch peak at closest approach is subtle and
   the pan barely moves.

   ```sh
   wolframscript -file main.wl -- --simulation.scattering.preset=glancing
   ```

4. **`distribution`** (200 particles) — the contrast between the quiet
   background hiss and the occasional dramatic loud, high-pitched
   backscatter event *is* the Rutherford cross-section, heard directly
   rather than read off a graph.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=distribution
   ```

5. **`discovery`**, with headphones — the historical payoff. Focus on
   one channel at a time, then listen to both together. The right
   (Rutherford) channel's large-angle events are clearly, audibly
   absent from the left (Thomson) channel — that absence is exactly
   what Rutherford had to explain with the atomic nucleus.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=discovery
   ```

## What the impact parameter means

The impact parameter `b` is the perpendicular distance between the
nucleus and the particle's original, undeflected line of approach —
how far "off-centre" the shot is. A head-on shot (`b=0`) bounces
straight back. A near-miss (small `b`) deflects through a large angle.
A distant shot (large `b`) barely deflects at all. The remarkable thing
Rutherford discovered: some alpha particles *do* bounce nearly straight
back — a result that requires the positive charge to be concentrated
in something tiny and dense (the nucleus), not spread through the whole
atom.

## The `1/sin^4(theta/2)` cross-section

The Rutherford formula says the rate of particles scattered near angle
`theta` is proportional to `1/sin^4(theta/2)`. This rises very steeply
as `theta -> 0` (almost every particle deflects by only a tiny amount)
and falls off steeply for large `theta` (large deflections are rare).
In the `distribution` mode audio, the dense quiet background and the
rare loud tones directly encode this shape: a foundation of numerous
quiet small-angle events, punctuated by the occasional loud, high-
pitched large-angle outlier.

## Historical significance

Ernest Rutherford, Hans Geiger, and Ernest Marsden ran this experiment
at the University of Manchester between 1909 and 1911, firing alpha
particles at thin gold foil. Under J.J. Thomson's then-standard "plum
pudding" model — positive charge spread evenly through the atom —
large-angle scattering should have been essentially impossible. Geiger
and Marsden observed it anyway, rarely but unmistakably. Rutherford
described the result as being "almost as incredible as if you fired a
15-inch shell at a piece of tissue paper and it came back and hit you."
The only explanation was a tiny, dense, positively charged nucleus at
the atom's centre — the model, announced in 1911, that is still
essentially correct today.

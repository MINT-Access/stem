# Compton Scattering — Listening Guide

## Recommended listening sequence

1. Start with `scatter` mode at the default — Compton's own 1923
   measurement (molybdenum X-rays, 71 pm, scattered 90 degrees). Listen
   for four events: the incoming photon, a sharp click at the collision,
   the outgoing photon (centred, but at a measurably lower pitch), and
   a soft low thud for the recoiling electron.

   ```sh
   wolframscript -file main.wl
   afplay output/scatter_audio.wav
   ```

2. Try `scatter` at backscatter (180 degrees) — the maximum possible
   shift for any given wavelength — and then at a gamma-ray energy,
   where the shift becomes dramatic rather than subtle.

   ```sh
   wolframscript -file main.wl -- --simulation.compton.angle_deg=180
   wolframscript -file main.wl -- --simulation.compton.wavelength_pm=1.24  # ~1 MeV
   ```

3. Move to `sweep` mode and listen to the same formula as a continuous
   glissando — notice the pitch falling fastest through the middle of
   the sweep (near 90 degrees) and slowest near the two ends.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=sweep
   afplay output/sweep_audio.wav
   ```

4. Then `energy` mode: the incoming and outgoing pitches start in near
   unison at low energy and visibly (audibly) pull apart as energy
   climbs past 511 keV, the electron's own rest energy — marked by an
   accent tone.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=energy
   afplay output/energy_audio.wav
   ```

5. Finish with `discovery` mode — the historical argument itself, in
   binaural stereo: left channel flat (classical Thomson), right
   channel dropping (real Compton). The gap between the two channels,
   growing as the sweep proceeds, is the actual 1923 measurement that
   won Compton the Nobel Prize.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=discovery
   afplay output/discovery_audio.wav
   ```

## Why the shift is modest at X-ray energies but dramatic at gamma-ray energies

Compton's formula for the wavelength shift, `Delta_lambda =
lambda_C(1-cos theta)`, depends only on the scattering angle — but the
*fractional* energy loss depends on how large that fixed shift is
*relative to* the incident wavelength. A 71 pm X-ray photon (Compton's
own experiment) loses only about 3-6% of its energy even at maximum
(backscatter): the absolute shift (up to ~4.85 pm) is small next to 71
pm. A 1.24 pm gamma-ray photon carries the *same* absolute maximum
shift, but relative to its own much shorter wavelength, that is a
enormous fractional loss — over half its energy, gone in one collision.
`energy` mode sonifies exactly this transition.

## Why 511 keV is the meaningful reference scale

511 keV is not an arbitrary number — it is `m_e c^2`, the electron's
own rest energy, the only energy scale the physics itself supplies.
Photons far below it barely perturb the electron (the Thomson limit);
photons at or above it can hand the electron a kinetic energy
comparable to its entire rest mass, which is precisely why Compton
scattering only becomes dramatic in the X-ray-to-gamma-ray regime and
is utterly negligible for visible light (a few eV — five orders of
magnitude below 511 keV).

## The two appearances of J.J. Thomson

The "Thomson" in `discovery` mode's classical prediction is the same
J.J. Thomson as `scattering/`'s plum-pudding atomic model — but here he
appears in a very different role. In `scattering/`, Thomson's model was
*wrong* about where an atom's charge lives. Here, "Thomson scattering"
(elastic, wavelength-independent) is the *correct* classical limit of
Compton's own quantum-relativistic formula — the equation this app
sonifies reduces exactly to Thomson's classical result as photon energy
falls far below the electron's rest energy. Thomson was the teacher who
proposed the wrong atom and, unknowingly, the right low-energy limit of
the very effect that helped confirm the photon.

## What the recoil angle means

Momentum conservation requires the recoiling electron to carry away
exactly the momentum the photon gave up — including its *transverse*
component. Since the scattered photon always deflects to one side, the
electron must always recoil to the *other* side (see `scatter` mode's
diagram: the electron arrow points opposite the outgoing photon arrow).
At backscatter (theta=180 degrees), the photon has no transverse
momentum left to give away, so the electron recoils straight forward,
along the original photon's own direction — angle 0.

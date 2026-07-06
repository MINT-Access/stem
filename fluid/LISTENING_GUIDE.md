# Karman Vortex Street — Listening Guide

## Recommended listening sequence

1. Start with `karman` mode at Re=150 (the default). Listen for the steady
   periodic tone — this is the Strouhal frequency — and the alternating
   clicks marking each vortex shed from the top and bottom of the cylinder.
   Count the clicks: there should be two per tone cycle (one from each side).

   ```sh
   wolframscript -file fluid/main.wl
   ```

2. Try `karman` at Re=80 (cleaner, more regular) and then Re=250 (noisier,
   more complex). The tone becomes less pure at higher Reynolds numbers as
   the wake edges toward the turbulent transition.

   ```sh
   wolframscript -file fluid/main.wl -- --simulation.fluid.Re=80
   wolframscript -file fluid/main.wl -- --simulation.fluid.Re=250
   ```

3. Listen to `strouhal` mode — the full sweep from silence to onset to
   evolution. Listen specifically for the moment the tone appears from
   silence: that is the Hopf bifurcation from steady to periodic flow, a
   qualitative change in the nature of the fluid motion, not just a volume
   change.

   ```sh
   wolframscript -file fluid/main.wl -- --simulation.mode=strouhal
   ```

4. Finally try `flag` mode. The panning tone is the flag flapping — the
   flag tip sweeps left and right across the stereo field at the flutter
   frequency.

   ```sh
   wolframscript -file fluid/main.wl -- --simulation.mode=flag
   ```

## What the Strouhal frequency means

The Strouhal number St ≈ 0.2 is one of the most useful dimensionless numbers
in fluid mechanics: it says that the vortex shedding frequency is always
about 20% of U/D, regardless of the specific fluid or size of the obstacle,
across a wide range of Reynolds numbers. A 1 cm cylinder in a 1 m/s wind
sheds vortices at about 20 Hz — barely audible. A 1 mm wire in the same wind
sheds at 200 Hz — clearly audible. This is why thin wires hum in the wind
and thick cables do not. (Near the onset of shedding, around Re≈47, St is
actually a bit lower — around 0.10-0.13 — and climbs toward the ≈0.2
plateau as Re increases through the hundreds; the `strouhal` mode's St-vs-Re
curve makes this rise audible and visible at once.)

## The Karman street in nature

Karman vortex streets are visible in satellite images of clouds downstream
of isolated islands — the island acts as the bluff body, the atmosphere as
the fluid. They are visible in the wake of ships. They cause the "galloping"
of suspension bridges in wind (the Tacoma Narrows Bridge collapse in 1940
was partly due to a related aeroelastic instability). They are heard
whenever wind passes a wire, flagpole, or antenna. The sound you hear in
`karman` mode is the sound these objects make.

## Connection to `waves/`

The `waves/` app covers the wave equation — a conservative, non-dissipative
phenomenon. The `fluid/` app covers viscous, dissipative flow. Both involve
continuous media but the physics is qualitatively different: waves conserve
energy and propagate indefinitely; vortices dissipate energy through
viscosity and eventually diffuse away. The contrast between the two apps
illustrates the difference between ideal and real fluid behaviour.

## A note on the approximation

The vortex particle method used here is a genuine simulation — vortices are
shed, advected by each other's induced velocity, and drift downstream — but
it is a deliberately simplified, educational one, not a research CFD tool.
At the default parameters only a handful of vortices (roughly 3-4 per row)
are ever visible in the domain at once, since the domain window (20
diameters) only holds about 20 time-units' worth of shedding at the default
Strouhal frequency. The staggered double-row pattern is real, just sparse.
See `fluid/README.md` for the full list of simplifications.

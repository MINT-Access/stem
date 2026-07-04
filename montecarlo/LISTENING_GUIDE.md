# Listening Guide — 2D Ising Model

## Recommended listening sequence

1. **Start with `sweep` mode.** Listen for three distinct phases: a
   quiet, low, noisy opening (disorder at T=4); a turbulent, loud
   middle (the critical point near T≈2.27); and a settling into a
   steady, high-pitched tone (order at T=0.5). The loudest moment is
   the phase transition itself.

   ```sh
   wolframscript -file main.wl
   ```

2. **Then listen to `quench` mode.** This is the same journey from
   disorder to order, but compressed into a single moment — the
   temperature drops instantly and you hear the system scrambling to
   reorganise.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=quench
   ```

3. **Finally, listen to `critical` mode**, which isolates just the
   middle section of the sweep — the critical point — and holds it
   there indefinitely. Listen for the complex, non-repeating texture:
   this is scale-free fluctuation.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=critical
   ```

## What the two audio layers mean

- **The main layer** tracks global magnetisation: pitch rises as the
  system orders, volume rises as fluctuations increase. Stereo pan
  tracks energy per spin — ordered configurations pan left, disordered
  ones pan right.
- **A quieter background layer** scans the spin grid in Hilbert-curve
  order (a locality-preserving traversal — nearby cells on the grid
  stay nearby in time). Consecutive same-spin cells become one held
  tone: long runs of the same pitch mean large aligned domains; rapid
  pitch alternation means small, mixed, or disordered regions.

At the critical point, both layers are simultaneously as complex as
they ever get — that's not a coincidence, it's the definition of
criticality.

## What the three accent tones mean

- **440 Hz, 150 ms** (sweep mode only): the moment the sweep crosses
  `T_c` — the phase transition itself.
- **220 Hz, 50 ms**: a magnetisation sign flip — the system's overall
  orientation reversed (common near/above `T_c`, rare deep in the
  ordered phase).
- **660 Hz, 100 ms**: a susceptibility peak — a moment of unusually
  large fluctuation, a local echo of the critical point's own behaviour.

## The universality connection

The critical behaviour of the 2D Ising model — how magnetisation,
susceptibility, and correlation length diverge near `T_c` — belongs to
a universality class shared by the liquid-gas critical point, binary
fluid mixtures, and other systems with completely different
microscopic physics. The critical exponents `beta = 1/8` and
`gamma = 7/4` are exactly the same for all of them. The Ising model is
the simplest member of this class, which is why it has been studied so
intensively since the 1920s: solve the simplest example exactly, and
you learn something true about an entire family of physically
unrelated systems.

## Connection to other stem apps

- **`cellular/`** — both are 2D grids evolving under local rules; the
  key difference is that the Ising model's updates are
  temperature-driven and stochastic (Metropolis), while Game of Life's
  are deterministic. Listen for how much "noisier" and more
  probabilistic the Ising spin grid sounds compared to Life's crisp,
  rule-bound population changes.
- **`thermo/`** — the Ising phase transition is the same *kind* of
  event as thermo's classical gas cooling: a qualitative change in
  macroscopic behaviour driven purely by temperature, both grounded in
  the same Boltzmann-weighted statistical mechanics.
- **`dynamical/`** — sweeping T through `T_c` here is structurally the
  same experience as dynamical/'s sweep through the period-doubling
  cascade: a single control parameter, one qualitative transition, and
  a moment (the phase transition / the onset of chaos) that is audibly
  the most complex point in the whole journey.

## Tips for listening

- Use headphones — the pan (ordered=left, disordered=right) and the
  quieter Hilbert-scan layer are both easiest to follow in stereo.
- Try `--simulation.montecarlo.T_fixed=3.0` (above T_c) and
  `--simulation.montecarlo.T_fixed=1.5` (below T_c) in `critical` mode
  to hear the contrast against the critical point itself.
- Try `--simulation.montecarlo.lattice_size=64` for a larger lattice —
  domains take longer to coarsen in `quench` mode, and the critical
  texture has more scales to fluctuate across.
- Try `--simulation.montecarlo.N_T_steps=100` in `sweep` mode for a
  finer-grained approach to the transition.

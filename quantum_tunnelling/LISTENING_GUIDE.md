# Quantum Tunnelling — Listening Guide

## Recommended listening sequence

1. Start with `barrier` mode at the default preset. Listen for four
   sounds: the incoming tone, a marker click at the barrier, then a
   reflected tone bouncing back and a transmitted tone passing through
   — sounding *simultaneously*, each loud in proportion to its
   probability. The particle had no classical way across; it crosses
   anyway, sometimes.

   ```sh
   wolframscript -file main.wl
   afplay output/barrier_audio.wav
   ```

2. Try the `stm` and `alpha_decay` presets and notice the transmitted
   tone growing almost inaudibly quiet — a real scanning tunnelling
   microscope's current, and a real nucleus's alpha decay, both depend
   on a transmission probability this small.

   ```sh
   wolframscript -file main.wl -- --simulation.quantum_tunnelling.preset=stm
   wolframscript -file main.wl -- --simulation.quantum_tunnelling.preset=alpha_decay
   ```

3. Move to `sweep` mode and listen to the tunnelling probability fade
   toward silence as the barrier grows thicker across the sweep — a
   smooth, continuous collapse, not a sudden drop.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=sweep
   afplay output/sweep_audio.wav
   ```

4. Finish with `energy` mode: listen for the volume rising as the
   particle's energy approaches the barrier height (marked by an
   accent tone), then — past that mark — a genuine wobble as
   transmission oscillates, reaching a moment of perfect, total
   transmission despite the barrier still being there.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=energy
   afplay output/energy_audio.wav
   ```

## Why the outcome isn't a coin flip

`barrier` mode plays the reflected and transmitted tones *together*,
not one-or-the-other at random. This is deliberate and physically
accurate: quantum tunnelling is a statement about a whole ensemble of
identically-prepared particles (or, equivalently, about one particle's
wavefunction, which genuinely has amplitude in both the reflected and
transmitted regions at once). A single measurement does collapse to
one outcome — but sonifying "the physics," not "one random trial," is
this app's whole point, exactly as `compton/scatter`'s narrated event
plays a single well-defined answer rather than a random one.

## Why alpha decay is astronomically improbable — yet happens anyway

The `alpha_decay` preset's transmission probability is roughly
7 x 10⁻¹⁰ — about one chance in one and a half billion, *per attempt*.
An alpha particle inside a nucleus attempts to escape roughly 10²¹
times per second (bouncing back and forth at nuclear speeds across a
nuclear-scale distance). Multiply the two together and even a
probability this small adds up to a nucleus actually decaying on a
human-relevant timescale. This is the real reason alpha-decay
half-lives span 24 orders of magnitude for barriers that differ only
modestly in height or width: the transmission probability is
*exponentially* sensitive to both (see `sweep` mode), so a small change
in the barrier compounds into an enormous change in half-life. (This
preset's *specific* numbers are illustrative, not a real half-life
calculation — see the README's caveat.)

## The particle-in-a-box connection

`energy` mode's perfect-transmission resonances occur exactly when
`k*L = n*Pi` for integer `n` — the identical standing-wave condition
that quantizes the energy levels of `quantum/`'s particle-in-a-box
(`BoxModel`'s `E_n = n^2*Pi^2/(2*L^2)`, in that app's natural units).
The physical picture is the same in both cases: a wave that fits a
whole number of half-wavelengths across a fixed length interferes with
itself constructively. In `quantum/box`, that condition selects which
energies are *allowed at all* (only the discrete E_n exist). Here, the
barrier is not a box the particle is trapped in — the particle is free
to have any energy — but for a fixed barrier width, only certain
specific incident energies happen to satisfy that same resonance
condition, and at exactly those energies the barrier becomes
perfectly, completely transparent, as if it were not there.

## Why the STM preset's transmission is so sensitive to gap height

Scanning tunnelling microscopy images a surface by measuring tunnelling
current between a sharp tip and the sample as the tip scans across it,
without ever touching. Because `T` falls off exponentially with barrier
width `L` (see `sweep` mode), moving the tip just a fraction of an
Angstrom closer or farther changes the current by an order of magnitude
or more — which is precisely why STM can resolve individual atoms: the
tunnelling current is an extraordinarily sensitive probe of height.

# Listening Guide — Classical Statistical Mechanics

## Recommended listening sequence

1. **`distribution` mode, default helium preset.** Listen for the
   spectrum sweeping upward and broadening as the gas heats from 100K
   to 1000K.

   ```sh
   wolframscript -file main.wl
   ```

2. **`distribution` mode with the nitrogen preset.** Heavier nitrogen
   molecules move more slowly at the same temperature — the whole
   spectrum sits noticeably lower in pitch than helium.

   ```sh
   wolframscript -file main.wl -- --simulation.thermo.preset=nitrogen
   ```

3. **`cooling` mode.** The time-reverse of the distribution sweep —
   listen for the complexity and loudness draining away together as
   the gas cools, settling into a narrow, quiet, low hum at thermal
   equilibrium.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=cooling
   ```

4. **`ensemble` mode.** The same underlying physics, now heard as 20
   simultaneous voices spread across the stereo field rather than a
   continuous spectrum. Listen for individual pitches jumping abruptly
   at each collision, while the chord's overall character stays
   stable.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=ensemble
   ```

5. **`equipartition` mode.** Listen specifically to the right channel
   — silent for a monatomic gas, a warm rising drone for a diatomic
   one — while the left channel (translational motion) stays identical
   either way.

   ```sh
   wolframscript -file main.wl -- --simulation.mode=equipartition
   ```

## What the three characteristic-speed markers mean

A soft triple-tap appears at the start of each temperature step in
`distribution` mode (and its use of the shared MB-spectrum synthesis in
`cooling`):

- **First tap (lowest pitch, 330 Hz):** most probable speed `v_p` —
  the peak of the distribution, the speed most molecules actually
  have.
- **Second tap (middle pitch, 440 Hz):** mean speed `v_mean` — the
  arithmetic average over all molecules.
- **Third tap (highest pitch, 550 Hz):** RMS speed `v_rms` — the
  square root of the mean squared speed, the quantity relevant to
  kinetic energy.

These three pitches are fixed reference tones marking "a new
temperature step just started" — they do not encode the actual speed
values (the GIF's coloured dashed vertical lines do that visually).
The RMS speed is always the highest of the three because the
distribution has a long high-speed tail: a few very fast molecules
pull the average — and especially the *mean square* — upward more than
they pull the peak.

## Temperature and pitch

In every mode, higher temperature means higher pitch, because faster
molecules mean higher frequencies in the logarithmic speed-to-frequency
mapping. Equal musical intervals correspond to equal *ratios* of speed
— the same principle by which equal semitones correspond to equal
frequency ratios in ordinary music.

## Mass and pitch

Heavier molecules move more slowly at the same temperature
(`v ~ 1/Sqrt[mass]`), so heavier gases sonify at a lower pitch. At the
same T, hydrogen (2 amu) sits highest, then helium (4), then nitrogen
(28), oxygen (32), and argon (40) lowest.

## The ensemble paradox

In `ensemble` mode, the chord sounds stable overall but is constantly
changing internally. This is thermal equilibrium: the macroscopic
state (temperature) is fixed while the microscopic state (which
particle has which speed) fluctuates continuously through collisions.
In fact, in this app's collision model, an elastic collision between
two equal-mass particles is an *exact* speed exchange — the set of
speeds across the whole ensemble never changes at all, only which
particle holds which value. The stability of the whole despite the
restlessness of the parts is one of the central ideas of statistical
mechanics.

## Why the right channel is the equipartition theorem

In `equipartition` mode, the left channel (translational kinetic
energy) is identical for a monatomic and a diatomic gas at the same
temperature — this is not a simplification, it is the physics: every
ideal gas molecule has exactly 3 translational degrees of freedom
contributing `(3/2)kT` regardless of its internal structure. A
diatomic molecule additionally stores energy in rotation (2 more
degrees of freedom, `+kT`), which is audible *only* in the right
channel. The fact that the diatomic gas needs more energy input to
reach the same temperature (a higher heat capacity) is entirely
because of that extra channel — nothing on the translational side
changes at all.

## Tips for listening

- Use headphones for `equipartition` mode — the left/right contrast is
  the entire point, and it collapses on a mono speaker.
- In `ensemble` mode, individual voices are panned at fixed positions
  across the stereo field specifically so you can track single
  particles by ear.
- Try `--simulation.thermo.n_particles=50` for a denser ensemble
  chord, or `--simulation.thermo.T_fixed=600` for a higher-pitched one.
- Try `--simulation.thermo.T_start=300 --simulation.thermo.T_end=3000`
  on `distribution` mode for a much wider sweep.

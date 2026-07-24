# Listening Guide — Brownian Motion

## Recommended listening sequence

Follow this order to hear Brownian motion from three complementary
angles: a single walk, the statistical law many walks obey together, and
how temperature governs the whole thing.

1. **`walk`** (default): a single random walk. Pan tracks left-right
   position, pitch tracks up-down position, and volume tracks how far
   the particle has wandered from where it started — not how fast it's
   currently jittering.
2. **`ensemble`**: 150 independent walkers, averaged. Listen for a
   single continuously rising tone whose climb visibly slows over time
   — that slowing is the square-root-of-time law, made audible.
3. **`temperature`**: a sweep from 275K to 350K. Listen for the jiggling
   becoming gently more agitated as the sweep proceeds toward higher
   temperature — a real effect, honestly modest rather than dramatic
   (see `README.md` for why).

```sh
wolframscript -file main.wl
wolframscript -file main.wl -- --simulation.mode=ensemble
wolframscript -file main.wl -- --simulation.mode=temperature
```

## Why `walk` mode's volume is unusual for this codebase

Most trajectory apps in this project (`lorenz/`, `henon/attractor`) tie
volume to speed — how fast the thing is currently moving. This app ties
volume to `r`, the distance already travelled from the starting point.
A jittery particle that never really goes anywhere and a jittery
particle actively wandering away from its start would sound identical
under a speed-driven volume — but they are NOT the same phenomenon, and
`r`'s slow, noisy growth is specifically what "diffusion" means. Listen
for the volume swelling gradually over the course of the walk, layered
on top of the constant jitter in pitch and pan.

## What the ensemble plot shows

`output/brownian_ensemble.png` overlays three things on the same axes:
a handful of individual walkers' own noisy `r(t)` in grey, the clean
ensemble-averaged RMS(t) in blue, and the theoretical `sqrt(4Dt)` curve
in dashed white. The blue and dashed curves should sit almost exactly on
top of each other — that's the actual mathematical law, confirmed by a
real Monte Carlo simulation, not just asserted. The grey individual
paths, by contrast, wander well above and below the theory curve at any
given moment — a single walker is not a reliable guide to the law at
all, which is precisely why `ensemble` mode averages over many.

## A note on `temperature` mode's modest effect

This app could have exaggerated `temperature` mode's audible contrast to
make "hotter = faster" sound more dramatic. It doesn't, because the real
physics — with water's viscosity held fixed and its temperature kept
safely within its actual liquid range (2°C to 77°C by default) — only
supports a genuine ~10-15% change in jiggle amplitude end to end. Listen
for the trend, not a dramatic before/after contrast: across the sweep's
several temperature steps, the walks should feel progressively (if
subtly) more agitated as the pitch/pan pattern moves from the first
frame toward the last.

## Tips for listening

- Use headphones — stereo pan carries real spatial information in every
  mode.
- In `walk` mode, try `--simulation.brownian.particle_radius_um=0.2` for
  a much smaller (and correspondingly more agitated) particle, or
  `=10.0` for a much larger, calmer one — Stokes-Einstein's inverse
  dependence on radius, made audible.
- In `ensemble` mode, try `--simulation.brownian.n_walkers=500` for a
  cleaner (less individually-noisy) average, or a small value like `=5`
  to hear how unreliable a tiny ensemble still is.
- In `temperature` mode, try widening the sweep toward the edges of
  water's real liquid range (`--simulation.brownian.temp_min=274
  --simulation.brownian.temp_max=372`) to hear the largest honestly
  achievable contrast without leaving liquid water.

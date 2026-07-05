# Scattering

Simulates and sonifies Rutherford alpha-particle scattering — the
1909-1911 Geiger-Marsden experiment that discovered the atomic nucleus
— across a single trajectory, a realistic beam distribution, and a
binaural Thomson-vs-Rutherford historical comparison.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`

## The Rutherford experiment

Ernest Rutherford, Hans Geiger, and Ernest Marsden fired alpha
particles (helium nuclei, charge `+2e`) at thin gold foil at the
University of Manchester between 1909 and 1911. J.J. Thomson's
then-standard "plum pudding" model pictured the atom's positive charge
spread evenly through a sphere about 1 Angstrom across — under that
model, a single scattering event could deflect a fast alpha particle
by at most a fraction of a degree; large-angle scattering should have
been essentially impossible. Geiger and Marsden observed it anyway:
rare, but real, alpha particles bouncing back at large angles, some
almost straight back the way they came. Rutherford described the
result as being "almost as incredible as if you fired a 15-inch shell
at a piece of tissue paper and it came back and hit you." The only
consistent explanation was that almost all of the atom's mass and
positive charge is concentrated in a tiny, dense nucleus — the model
Rutherford announced in 1911, and one still essentially correct today.

### Why a diffuse Thomson atom cannot backscatter

In the plum-pudding model, the deflecting charge is spread over a
sphere of radius `R_atom`, so the maximum force any single pass can
exert is far weaker than a point charge's — the maximum deflection
angle scales as `~ k*q1*q2 / (E*R_atom)`, which for gold and a typical
~5 MeV alpha particle works out to only about `0.01` radians (~0.6
degrees). No single encounter with a diffuse positive charge can turn
a fast alpha particle through 90 or 180 degrees. A point-like nucleus
can, because the Coulomb force it exerts grows without bound as the
particle's distance from it shrinks.

### The Coulomb force and hyperbolic trajectories

An alpha particle (charge `q1=+2e`) approaching a gold nucleus
(charge `q2=+79e`) feels a repulsive force `F = k*q1*q2/r^2`. A
repulsive inverse-square force produces exactly the same family of
conic-section orbits an attractive one does (Kepler orbits), except
that repulsion only ever produces the *unbound* branch: a hyperbola
that curves around the force centre without ever closing into an
ellipse. Every trajectory in this app is one branch of that hyperbola.

### Impact parameter and scattering angle

The impact parameter `b` is the perpendicular distance between the
nucleus and the particle's original (undeflected) line of approach.
It relates to the scattering angle `theta` by

```
cot(theta/2) = 2*b*E / (k*q1*q2)
```

A head-on shot (`b=0`) scatters straight back (`theta=180 deg`); as `b`
grows the deflection shrinks toward zero. This app works in scaled
units where the head-on distance of closest approach and the
asymptotic speed are both set to 1, which reduces the formula to the
clean `theta = 2*ArcCot[b]` used throughout the code (see `AGENTS.md`
for the full scaled-units derivation, including how the conserved
specific energy (`1/2`) and specific angular momentum (`b`) fall out of
that choice).

### The Rutherford cross-section

The rate of particles scattered near angle `theta` is proportional to
`dSigma/dOmega = 1/sin^4(theta/2)` — steeply peaked toward `theta=0`
(almost every particle deflects only slightly) and small, but never
zero, at large `theta`. That non-zero large-angle tail is exactly what
Geiger and Marsden detected and Thomson's model could not produce.

## Modes

### `scatter` (default)

A single alpha particle's trajectory, integrated numerically in polar
coordinates (`NDSolve`) from a large starting distance, through
closest approach, back out to the same distance on the other side of
the nucleus. **What you hear:** pitch and volume rise as the particle
approaches, peak sharply (with an accent tone) at closest approach,
then fall away as it departs — a three-part approach/periapsis/
departure narrative.

Presets (`--simulation.scattering.preset`): `glancing` (`b=5`, gentle),
`moderate` (`b=1`, `theta=90 deg`, default), `headon` (`b=0.1`,
`theta~169 deg`), `backscatter` (`b=0`, `theta=180 deg` exactly).

### `distribution`

A beam of particles with impact parameters drawn from the physically
realistic distribution for a uniform beam cross-section
(`b ~ sqrt(Uniform[0,b_max^2])`, so the number of particles per unit
`b` grows linearly with `b`, matching the area of each annular ring).
**What you hear:** a dense, quiet stream of small-angle events (farthest
`b` first, closest last), punctuated by rare, loud, high-pitched
backscatter accents — the statistical texture of the cross-section
itself, played directly rather than plotted.

### `discovery`

Recreates the Geiger-Marsden comparison in binaural stereo: the same
beam geometry, scored against both nuclear models simultaneously.
**What you hear:** the left (Thomson) channel is a quiet, uniform hiss
confined to less-than-one-degree deflections and nothing more; the
right (Rutherford) channel has the same quiet background *plus*
occasional loud backscatter events the left channel structurally
cannot produce. A closing spoken line states the historical
conclusion.

## Config keys (`config.json`)

| Key | Default | Meaning |
|---|---|---|
| `simulation.mode` | `"scatter"` | `scatter` \| `distribution` \| `discovery` |
| `simulation.scattering.b` | `1.0` | Impact parameter, scaled units (`scatter`) |
| `simulation.scattering.preset` | `""` | `glancing` \| `moderate` \| `headon` \| `backscatter` (`scatter`) |
| `simulation.scattering.r_initial` | `20.0` | Starting distance, scaled units (`scatter`) |
| `simulation.scattering.n_points` | `500` | Trajectory sample resolution (`scatter`) |
| `simulation.scattering.n_particles` | `200` | Beam size (`distribution` only) |
| `simulation.scattering.b_max` | `8.0` | Maximum impact parameter (`distribution`/`discovery`) |
| `simulation.scattering.random_seed` | `42` | RNG seed (`distribution`/`discovery`) |
| `simulation.scattering.note_duration` | `0.08` | Seconds per particle note (`distribution`) |
| `simulation.scattering.n_seconds` | `8.0` | Total playback duration (`discovery`) |

See `LISTENING_GUIDE.md` for a guided listening sequence and
`AGENTS.md` for the physics and engineering decisions behind the
implementation.

## Connection to `magnetic/` and `hydrogen/`

`magnetic/` faces the identical numerical-integration problem this
app's `scatter` mode does — a charged particle's equation of motion,
solved with `NDSolve` and turned into a trajectory-shaped sonification
— though `magnetic/`'s uniform field produces closed or helical orbits
where this app's repulsive Coulomb force produces an open hyperbola.
`hydrogen/` uses the *same* nuclear model this app's `discovery` mode
argues for — a tiny, dense, positively charged nucleus — but takes the
story one step further: once you accept the nucleus, quantum mechanics
is needed to explain why the electrons around it don't simply spiral
in, which is exactly what `hydrogen/`'s orbitals sonify.

## Running

```sh
# Default: scatter, b=1.0 (90 degrees)
wolframscript -file scattering/main.wl

# Presets
wolframscript -file scattering/main.wl -- --simulation.scattering.preset=headon
wolframscript -file scattering/main.wl -- --simulation.scattering.preset=backscatter
wolframscript -file scattering/main.wl -- --simulation.scattering.preset=glancing

# Custom impact parameter
wolframscript -file scattering/main.wl -- --simulation.scattering.b=2.0

# Beam distribution
wolframscript -file scattering/main.wl -- --simulation.mode=distribution
wolframscript -file scattering/main.wl -- --simulation.scattering.n_particles=500

# Thomson vs Rutherford
wolframscript -file scattering/main.wl -- --simulation.mode=discovery
wolframscript -file scattering/main.wl -- --simulation.scattering.b_max=12.0

# Play the output (macOS)
afplay scattering/output/scatter_audio.wav
afplay scattering/output/distribution_audio.wav
afplay scattering/output/discovery_audio.wav
```

## Correctness checks

Printed on every run:

1. **Rutherford formula** (all modes) — `b=1.0` gives `theta=90.000 deg`
   within `0.01 deg`.
2. **Angular momentum conservation** (`scatter`) — `r^2*dphi/dt`
   constant at `b` within 0.1%.
3. **Energy conservation** (`scatter`) — total specific energy constant
   at `0.5` within 0.1%.
4. **Cross-section check** (`distribution`) — observed backscatter
   fraction consistent with the analytic `1/b_max^2` prediction within
   a statistically appropriate tolerance (see `AGENTS.md`).

## Output files

| File | Description |
|------|-------------|
| `output/scatter_audio.wav` | Approach/periapsis/departure trajectory sonification |
| `output/scatter.gif` | 2D hyperbolic trajectory around the nucleus |
| `output/scatter_data.csv` | Time series: position, speed, phi, pitch/pan/volume |
| `output/distribution_audio.wav` | Dense event stream with backscatter accents |
| `output/distribution.gif` | Impact parameter vs scattering angle scatter plot + histogram |
| `output/distribution_data.csv` | One row per particle: b, theta, weight, pitch/pan/volume |
| `output/discovery_audio.wav` | Binaural Thomson (left) vs Rutherford (right) |
| `output/discovery.gif` | Side-by-side growing angle histograms |
| `output/discovery_data.csv` | One row per particle: b, Thomson angle, Rutherford angle |

## Project structure

```
scattering/
  main.wl           — Entry point (thin orchestrator)
  experiments.wl    — Curated preset runs
  config.json       — App defaults
  src/
    model.wl        — NDSolve trajectory, beam sampling, correctness checks
    sonify.wl       — stem-core layers (scatter) + bespoke synthesis (distribution/discovery)
    animate.wl      — GIF rendering (all three modes)
    output.wl       — CSV export
  tests/
    test_model.wl   — Unit tests (90/180/small-angle, angular momentum, energy)
  output/           — Output files (not committed)
  README.md
  AGENTS.md
  LISTENING_GUIDE.md
```

## Console output

Step numbers `[1/4]` through `[4/4]` mark each pipeline stage.
Correctness-check results print `[PASS]` or `[FAIL]` with the measured
value. Export confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`,
and `STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage
announcements:

```sh
STEM_SPEAK=1 wolframscript -file scattering/main.wl
```

# Relativity

A Wolfram Language simulation of general relativistic phenomena, runnable
entirely from the terminal via `wolframscript`. Two modes:

- **chirp** — gravitational wave emission from a binary inspiral, modelled
  with the post-Newtonian approximation. The strain h(t) is literally an
  audio waveform — time-stretched to make it clearly audible, then exported
  as a WAV file you can play with `afplay`.
- **geodesic** — test-particle and photon orbits around a Schwarzschild black
  hole, solved numerically. Three orbit types: bound elliptical orbits (showing
  GR periapsis precession as a rosette), plunging orbits (particle falls past
  the event horizon), and photon lensing (light bending around the black hole).

## The physics — chirp mode

When two massive bodies orbit each other they lose energy by radiating
gravitational waves. As energy is lost the orbit shrinks, the orbital
frequency rises, and the wave amplitude grows. This continues until the bodies
merge — the resulting signal is a *chirp*: a rising frequency sweep that ends
abruptly at merger. This is what LIGO detected on 14 September 2015.

The simulation uses the **post-Newtonian (PN) approximation**, which gives an
analytic closed-form expression valid during the long inspiral phase. The key
quantity is the *chirp mass*:

    ℳ = (m₁ m₂)^(3/5) / (m₁ + m₂)^(1/5)

The gravitational wave frequency evolves as:

    f(t) = (1/π) · (5/256)^(3/8) · ℳ_sec^(−5/8) · (t_c − t)^(−3/8)

where t_c is the coalescence time and ℳ_sec = G ℳ M☉ / c³. The strain is:

    h(t) = A(t) · cos(2π φ(t))

with φ(t) = ∫ f dt and amplitude A(t) = (4/D)(ℳ_sec · c)(π ℳ_sec f)^(2/3).
After merger the remnant rings at its quasi-normal mode frequency (Echeverria
1989) and damps exponentially.

## The physics — geodesic mode

The **Schwarzschild metric** describes spacetime outside any non-rotating
spherical mass. In geometrised units (G = c = M = 1), the line element is:

    ds² = −(1 − 2/r) dt² + (1 − 2/r)⁻¹ dr² + r² dΩ²

The event horizon sits at r = 2M (one Schwarzschild radius, r_s = 2M).
Test particles follow timelike geodesics with two conserved quantities:
energy E and angular momentum L. The radial equation becomes:

    (dr/dτ)² = E² − (1 − 2/r)(1 + L²/r²)   [massive particle]
    (dr/dλ)² = E² − (1 − 2/r) b²/r²         [photon, b = L/E]

Combined with dφ/dτ = L/r², these are integrated numerically by NDSolve
in dimensionless units (everything in units of M).

**Bound orbits**: starting at apoapsis r₀ with L = f · L_circ(r₀), where
f < 1 makes the orbit elliptical. Because the radial and angular periods
differ in GR (unlike Newtonian gravity), the periapsis advances on each
orbit — the trajectory traces a rosette pattern.

**Plunging orbits**: L² < 12M² means no potential barrier exists; the
particle spirals inward past the event horizon in finite proper time.

**Photon orbits**: the critical impact parameter b_crit = 3√3 M ≈ 5.20 M
defines the photon sphere at r = 3M. For b > b_crit the photon is deflected
and escapes; for b < b_crit it is captured.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`

## Usage

### Chirp mode

```bash
# Default — GW150914 parameters (36+29 M☉ at 410 Mpc)
wolframscript -file main.wl

# Named preset
wolframscript -file main.wl -- --simulation.chirp.preset gw170817
wolframscript -file main.wl -- --simulation.chirp.preset stellar

# Override individual parameters
wolframscript -file main.wl -- --simulation.chirp.mass1_solar 50
wolframscript -file main.wl -- --simulation.chirp.distance_mpc 200
wolframscript -file main.wl -- --sonification.chirp.time_stretch 8

# Play the result (macOS)
afplay output/chirp.wav
afplay output/gw170817.wav
```

### Geodesic mode

```bash
# Bound orbit — 10 M☉ BH, particle from 10 r_s (default)
wolframscript -file main.wl -- --simulation.mode geodesic

# Plunging orbit — spirals past event horizon
wolframscript -file main.wl -- --simulation.mode geodesic \
  --simulation.geodesic.orbit_type plunging

# Photon lensing — b = 1.5 × b_crit (deflected, escapes)
wolframscript -file main.wl -- --simulation.mode geodesic \
  --simulation.geodesic.orbit_type photon

# Change black hole mass
wolframscript -file main.wl -- --simulation.mode geodesic \
  --simulation.geodesic.mass_solar 30

# More eccentric bound orbit (lower angular momentum factor)
wolframscript -file main.wl -- --simulation.mode geodesic \
  --simulation.geodesic.bound.angular_momentum_factor 0.70

# Closer photon pass (b = 1.05 × b_crit — multiple near-orbits)
wolframscript -file main.wl -- --simulation.mode geodesic \
  --simulation.geodesic.orbit_type photon \
  --simulation.geodesic.photon.impact_parameter_factor 1.05

# Play audio
afplay output/geodesic.wav

# Inspect merged configuration
wolframscript -file main.wl -- --config-dump
```

## Presets (chirp mode)

| Preset | Masses | Distance | Event |
|--------|--------|----------|-------|
| `gw150914` | 36 + 29 M☉ | 410 Mpc | First LIGO detection, Sep 2015 |
| `gw170817` | 1.17 + 1.36 M☉ | 40 Mpc | Neutron star merger, Aug 2017 |
| `stellar` | 10 + 8 M☉ | 100 Mpc | Typical stellar-mass binary |

GW150914 sweeps 20 → 412 Hz over ~0.85 s. GW170817 takes ~188 s to sweep
20 → 500 Hz; only the final 10 s before merger is used for the WAV.

## Outputs

### Chirp mode

| File | Description |
|------|-------------|
| `chirp.gif` | 60-frame animation revealing the waveform left-to-right; frequency dot tracks merger approach |
| `chirp.png` | Static two-panel: full strain waveform with merger marker + frequency evolution curve |
| `chirp.wav` | Main audio: h(t) time-stretched (4×) to be clearly audible, normalised to 0.9 peak |
| `chirp_timeseries.csv` | Every 10th sample: time_s, strain_h, frequency_hz, amplitude |
| `gw150914.wav` | GW150914 preset |
| `gw170817.wav` | GW170817 — final 10 s of neutron-star inspiral |
| `stellar.wav` | 10+8 M☉ stellar-mass binary |

### Geodesic mode

| File | Description |
|------|-------------|
| `geodesic.gif` | 60-frame animation of the particle/photon moving along its orbit |
| `geodesic.png` | Static full-trajectory plot with event horizon, photon sphere, and ISCO rings |
| `geodesic.wav` | Sonified orbit: pitch follows orbital frequency (bound) or gravitational blueshift (plunging/photon) |
| `geodesic_trajectory.csv` | Subsampled trajectory: tau_M, r_rs, phi_rad, x_rs, y_rs |

All coordinates in `r_s` units on the plot (event horizon = 1 r_s ring).
Dashed orange = photon sphere (1.5 r_s). Dashed grey = ISCO (3 r_s,
massive-particle modes only).

## Listening guide

### Chirp

The audio is time-stretched (default 4×). Listen for:

- **Rising pitch** — frequency climbing from ~20 Hz as the orbit tightens
- **Growing volume** — amplitude increasing as the bodies spiral closer
- **Abrupt cutoff** — the merger: orbit collapses in an instant
- **Fading ringdown** — the merged remnant ringing at its QNM frequency,
  damping away in a few milliseconds

Higher mass → shorter chirp, lower peak frequency.

### Geodesic

- **Bound orbit** — a wobbling tone that speeds up at periapsis and slows at
  apoapsis. The GR periapsis advance (differential precession of radial and
  angular periods) is audible as a slow drift in the wobble pattern over many
  orbital cycles.
- **Plunging orbit** — rising pitch (gravitational blueshift) combined with
  fading amplitude (gravitational redshift suppressing the signal). The
  combined effect gives the characteristic "falling into a black hole" sound.
- **Photon lensing** — a brief frequency blip as the photon is gravitationally
  blueshifted near closest approach and then redshifts back out.

## Physical correctness checks (chirp mode)

Four checks run automatically and are printed to the console:

1. **Frequency at t = 0 ≈ f_min** — verifies the coalescence-time formula
2. **Frequency monotonically increasing** — verifies the PN formula
3. **Amplitude monotonically increasing** — verifies the strain formula
4. **Strain DC offset ≈ 0** — verifies clean phase accumulation

If check 2 or 3 fails the run aborts.

## Project structure

    relativity/
    ├── main.wl              Entry point (mode dispatch, preset resolution, 4-step pipeline)
    ├── config.json          App defaults (chirp + geodesic sub-configs, presets)
    ├── src/
    │   ├── model.wl         ChirpModel, GeodesicModel
    │   ├── animate.wl       AnimateRelativity → AnimateGeodesic (GIF + PNG)
    │   └── sonify.wl        SonifyRelativity → SonifyGeodesic (WAV)
    ├── output/              Output files (not committed)
    ├── AGENTS.md            Guidance for Claude Code
    └── README.md

## Console output

Step numbers `[1/4]` through `[4/4]` mark each pipeline stage. Physical
correctness checks print `[PASS]` or `[FAIL]` with actual values. Export
confirmations use `STEMDescribeCSV`, `STEMDescribeWAV`, and `STEMDescribeGIF`.

To enable speech at each stage, set `STEM_SPEAK=1`:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

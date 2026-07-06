# Karman Vortex Street

Simulates and sonifies vortex shedding behind a bluff body — the Karman
vortex street — making the Strouhal frequency directly audible: the same
pitch a wire, flagpole, or power line sings in the wind.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`

## The physics

### The Karman vortex street

Flow past a circular cylinder at intermediate Reynolds numbers
(40 < Re < 1000) produces periodic alternating vortex shedding — the Karman
vortex street, named after Theodore von Karman, who analysed its stability
in 1911.

```
Re = rho U D / mu = U D / nu
```

where U is the freestream velocity, D the cylinder diameter, and nu the
kinematic viscosity. As Re increases:

| Re range | Behaviour |
|----------|-----------|
| Re < 40 | Steady symmetric wake, no shedding |
| 40 < Re < ~180 | Periodic laminar Karman street (clean alternating vortices) |
| 180 < Re < ~400 | Quasi-periodic, some three-dimensionality |
| Re > ~400 | Turbulent wake |

### The Strouhal number

The vortex shedding frequency follows the empirical Strouhal correlation:

```
St = 0.198 (1 - 19.7/Re)          [valid for 250 < Re < 2x10^5]
f_shed = St * U / D
```

St is nearly constant (≈0.2) across a wide range of Reynolds numbers — a
rare case of a fluid-mechanical quantity that barely depends on the details
of the flow. This app uses the same formula across the whole Re range it
sweeps (including below its stated 250 validity floor) as the simplest
available single closed-form St(Re); see `AGENTS.md` for how the unit tests
and correctness checks account for this.

### The vortex particle method

The wake is represented as a small number of discrete point vortices
`{x, y, Gamma}`, shed alternately from the top (+Gamma) and bottom (-Gamma)
of the cylinder every `dtShed = 1/(2 f_shed)`, then advected by the
freestream plus the mutual Biot-Savart velocity every other vortex induces:

```
w*(z) = Gamma_j / (2 pi i (z - z_j))
```

This reproduces the correct shedding frequency and the alternating
staggered-row structure of a real Karman street, but it is **not** a
Navier-Stokes solver: there is no viscous diffusion of vortex cores and no
resolved boundary layer — separation points are simply fixed just behind
the cylinder. It is an educational simulation, not a research CFD tool. The
unsteady lift force is likewise a simplified proxy (a sum of decaying
pulses timed to the real shedding events, tuned to genuinely oscillate at
f_shed — see `AGENTS.md` design decision 2 for why the naive
centroid-difference formula does not).

### Aeolian tones

A cylinder (or wire, or flagpole) shedding vortices experiences an
oscillating lift force at f_shed and an oscillating drag force at 2·f_shed.
If f_shed happens to fall near the object's own structural resonance, the
result is an audible "singing" — the Aeolian tone — the same phenomenon
behind humming power lines and wind-harps.

### The Tacoma Narrows Bridge and aeroelastic instability

The `flag` mode's flexible flag flapping in flow is a simplified cousin of
the aeroelastic flutter that famously destroyed the original Tacoma
Narrows Bridge in 1940: a flexible structure interacting with vortex
shedding and its own elastic restoring force can lock into a self-sustaining
oscillation. This app's flag model is a damped, driven linear oscillator —
far simpler than a full aeroelastic analysis — but it demonstrates the same
core idea: `d^2y/dt^2 + 2*zeta*omega0*dy/dt + omega0^2*y = F_fluid(t)`.

## The three modes

### `karman` (default)

A Karman vortex street at a fixed Reynolds number. The lift-proxy
oscillation at f_shed is sonified as a steady tone (the Strouhal frequency,
scaled to `audio_freq_target`) plus a slower melodic modulation, with a
click alternating between 330 Hz and 220 Hz at every vortex shed. Stereo pan
follows the vortex street's centroid as it drifts downstream.

### `strouhal`

Sweeps Reynolds number from `Re_start` to `Re_end`. Below Re≈47 the flow is
steady and the audio is silent; at onset a tone appears (announced via
speech and an accent tone); as Re climbs toward the turbulent transition
(≈200) the tone gradually broadens and becomes irregular. The GIF shows a
live flow snapshot alongside a building St-vs-Re curve.

### `flag`

A flexible flag flapping in a steady flow, modelled as a damped, driven
linear oscillator with a natural frequency `omega0 = sqrt(stiffness)*U/L`
driven near its flutter frequency `f_flag = 0.15*U/L`. Pitch and stereo pan
both follow the tip displacement; volume follows tip speed; an accent tone
marks each pass through the centre (each half-flap).

## Running

```sh
wolframscript -file fluid/main.wl                                               # karman, Re=150
wolframscript -file fluid/main.wl -- --simulation.mode=strouhal                 # Re sweep 20->300
wolframscript -file fluid/main.wl -- --simulation.mode=flag                     # flag flutter
wolframscript -file fluid/main.wl -- --simulation.fluid.Re=80                  # lower Re, cleaner tone
wolframscript -file fluid/main.wl -- --simulation.fluid.Re=250                 # higher Re, noisier
wolframscript -file fluid/main.wl -- --simulation.fluid.audio_freq_target=440  # higher pitch base
wolframscript -file fluid/main.wl -- --simulation.fluid.flag_length=10.0       # longer flag, lower flutter
wolframscript -file fluid/main.wl -- --simulation.fluid.duration=80            # longer simulation

# Play the output (macOS)
afplay fluid/output/karman_audio.wav
afplay fluid/output/strouhal_audio.wav
afplay fluid/output/flag_audio.wav
```

## Output files

| File | Description |
|------|-------------|
| `karman_audio.wav` / `karman.gif` / `karman_data.csv` | Fixed-Re vortex street |
| `strouhal_audio.wav` / `strouhal.gif` / `strouhal_data.csv` | Re sweep |
| `flag_audio.wav` / `flag.gif` / `flag_data.csv` | Flag flutter |

## Physical/mathematical correctness checks (printed on every run)

1. **Strouhal/shedding frequency** — the FFT spectral peak of a reference
   karman simulation's lift proxy must match `St*U/D` within 10%.
2. **Onset Reynolds number** — the hard shedding on/off threshold used by
   `strouhal` mode must sit within the experimentally observed range
   Re = 40-60.
3. **Strouhal number range** — `St(Re)` must stay within [0.18, 0.22] across
   its own documented valid domain, Re in [250, 2000].
4. **Flag flutter frequency** — a dedicated 12-period integration's measured
   zero-crossing frequency must match `0.15*U/flagLength` within 20%.

## Config key table

| Key | Default | Effect |
|-----|---------|--------|
| `simulation.mode` | `"karman"` | `karman`, `strouhal`, or `flag` |
| `simulation.fluid.Re` | 150 | Reynolds number (karman mode) |
| `simulation.fluid.U` | 1.0 | Freestream velocity |
| `simulation.fluid.D` | 1.0 | Cylinder diameter |
| `simulation.fluid.duration` | 40 (karman/strouhal), 30 (flag) | Simulation duration, convective time units |
| `simulation.fluid.n_vortices_max` | 200 | Max vortices retained in the domain |
| `simulation.fluid.Re_start` / `Re_end` | 20 / 300 | Strouhal sweep range |
| `simulation.fluid.Re_steps` | 50 | Number of sweep steps |
| `simulation.fluid.duration_per_Re` | 10 | Simulation time per sweep step |
| `simulation.fluid.audio_freq_target` | 220 | Reference pitch (Hz) at the canonical configuration |
| `simulation.fluid.flag_length` | 5.0 | Flag length (flag mode) |
| `simulation.fluid.flag_stiffness` | 0.1 | Dimensionless flag stiffness |

## Project structure

```
fluid/
  main.wl           — Entry point (thin orchestrator)
  experiments.wl    — Curated preset runs
  config.json       — App defaults
  src/
    model.wl        — RunVortexStreet, LiftProxy, FlagOscillator, correctness checks
    sonify.wl       — SonifyKarman, SonifyStrouhal, SonifyFlag
    animate.wl      — AnimateKarman, AnimateStrouhal, AnimateFlag
    output.wl       — ExportKarmanCSV, ExportStrouhalCSV, ExportFlagCSV
  tests/
    test_model.wl   — Unit tests (Strouhal formula chain, Biot-Savart, flag frequency)
  output/           — Output files (not committed)
  README.md
  LISTENING_GUIDE.md
  AGENTS.md
```

## Console output

Step numbers `[1/4]` through `[4/4]` mark each pipeline stage. Correctness
check results print `[PASS]` or `[FAIL]`. Export confirmations use
`STEMDescribeWAV`, `STEMDescribeGIF`, `STEMDescribeCSV`. Set `STEM_SPEAK=1`
for spoken announcements:

```sh
STEM_SPEAK=1 wolframscript -file fluid/main.wl
```

See `fluid/LISTENING_GUIDE.md` for the recommended listening sequence and
`fluid/AGENTS.md` for implementation notes, design decisions, and a full
list of the simplifications this educational simulation makes relative to a
real Navier-Stokes solve.

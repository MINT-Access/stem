# stem

[![Version](https://img.shields.io/badge/version-1.4.0-blue.svg)](RELEASE_NOTES_v1.4.0.md)
[![Wolfram Language](https://img.shields.io/badge/Wolfram_Language-13%2B-DD1100.svg)](https://www.wolfram.com/engine/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A monorepo of Wolfram Language physics simulations, data projects, and signal
processing demonstrations — each runnable from the terminal via `wolframscript`
and producing CSV data, an animated GIF, and audio output.

---

## Repository layout

```
stem/
  stem-core/        Shared library: config, sonification pipeline, PCM synthesis, file export
  pendulum/         Simple and double pendulum ODE simulation
  lorenz/           Lorenz and Rössler strange attractor simulation
  dynamical/        Logistic map and period-doubling route to chaos
  asteroids/        NASA near-Earth asteroid tracker (live API data)
  cellular/         Conway's Game of Life and Wolfram Rule 110
  signal/           Fourier analysis demonstration (chord, sweep, AM)
  quantum/          Quantum mechanics (coherent state QHO, particle-in-a-box)
  primes/           Prime number patterns (Ulam spiral, prime gap rhythm)
  images/           2D image sonification via Hilbert curve traversal (brightness, colour, HSB modes)
  relativity/       General relativity (chirp: PN binary inspiral; geodesic: Schwarzschild orbits)
  cosmology/        CMB angular power spectrum and sky map sonification
  waves/            2D wave propagation and interference (FEM simulation)
  lagrange/         Circular restricted three-body problem, Lagrange point orbits
  thermo/           Maxwell-Boltzmann distribution, ideal gas ensemble, thermal cooling, equipartition theorem
  montecarlo/       2D Ising model, Metropolis MCMC, ferromagnetic phase transition
  magnetic/         Charged particle motion: cyclotron orbits, E×B drift, magnetic mirror, multi-particle chord
  hydrogen/         Hydrogen atom: wave functions, emission spectrum, quantum cascade transitions
  bayes/            Bayesian inference: coin bias, Gaussian mean estimation, Bayes factor comparison
  scattering/       Rutherford scattering: hyperbolic trajectories, cross-section, Thomson vs Rutherford
  resonance/        Orbital resonances: Galilean 4:2:1 Laplace resonance, Kirkwood gaps, Cassini Division
  fluid/            Kármán vortex street: vortex shedding, Strouhal frequency, Reynolds sweep, flag flutter
  blackbody/        Planck black body radiation: spectrum sweep, Wien's law, Stefan-Boltzmann law, star presets
  compton/          Compton scattering: single-event collision, angle sweep, energy sweep, Thomson vs Compton
  config/           Global config defaults (config.json)
  docs/             Workflow guides
```

---

## Prerequisites

### Wolfram Engine

Download the free **Wolfram Engine** from https://www.wolfram.com/engine/ and
follow the installer for your platform. `wolframscript` is included in the
installer on all three platforms — no separate download needed.

Activate the free licence when prompted (requires a Wolfram account).

Verify your installation:

```sh
# macOS / Linux
wolframscript -version

# Windows (Command Prompt or PowerShell)
wolframscript -version
```

### Platform-specific audio tools

| Platform | Tool | Install |
|---|---|---|
| macOS | `afplay` | Built into macOS — no install needed |
| Linux | `aplay` | `sudo apt install alsa-utils` (Debian/Ubuntu) · `sudo dnf install alsa-utils` (Fedora) |
| Linux (alt) | `paplay` | `sudo apt install pulseaudio-utils` |
| Windows | Windows Media Player | Built into Windows 10/11 — no install needed |

### Platform-specific text-to-speech (optional — `STEM_SPEAK=1` only)

| Platform | Tool | Install |
|---|---|---|
| macOS | `say` | Built into macOS |
| Linux | `espeak-ng` | `sudo apt install espeak-ng` · `sudo dnf install espeak-ng` |
| Windows | System.Speech | Built into Windows 10/11 (PowerShell 5.1+) |

TTS is disabled by default. If the tool is missing the app prints a warning and continues.

### NASA API key (asteroids app only — optional)

Register for a free key at https://api.nasa.gov/. The built-in `DEMO_KEY` works
at 30 requests/hour; a personal key removes that limit.

Set the key as an environment variable before running:

```sh
# macOS / Linux — add to ~/.zshrc or ~/.bashrc to persist
export NASA_API_KEY=your_key_here

# Windows PowerShell — set for the current session
$env:NASA_API_KEY = "your_key_here"

# Windows — set permanently via System Properties → Environment Variables
# Variable name: NASA_API_KEY   Value: your_key_here
```

---

## Quick start

Run any project from the `stem/` root:

```sh
# Physics simulations
wolframscript -file pendulum/main.wl
wolframscript -file lorenz/main.wl

# Logistic map — period-doubling route to chaos
wolframscript -file dynamical/main.wl                                      # sweep mode, r 2.5→4.0
wolframscript -file dynamical/main.wl -- --simulation.mode=iterate         # iterate at r=3.8
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=period3_window

# Live NASA asteroid data
wolframscript -file asteroids/main.wl                                    # last 7 days
wolframscript -file asteroids/main.wl -- 2026-01-01 2026-12-31           # full year
wolframscript -file asteroids/main.wl -- 2026-01-01 2026-06-25 Phrygian  # date range + scale
wolframscript -file asteroids/main.wl -- 2026-06-20 2026-06-26 --no-orbital-elements

# Cellular automata
wolframscript -file cellular/main.wl                                     # Game of Life, R-pentomino
wolframscript -file cellular/main.wl -- --simulation.mode=rule110

# Signal processing
wolframscript -file signal/main.wl                                       # chord (default)
wolframscript -file signal/main.wl -- --simulation.mode=sweep
wolframscript -file signal/main.wl -- --simulation.mode=am

# Quantum mechanics
wolframscript -file quantum/main.wl                                      # QHO coherent state
wolframscript -file quantum/main.wl -- --simulation.mode=box             # particle-in-a-box
wolframscript -file quantum/main.wl -- --simulation.qho.alpha=3.0        # larger coherent amplitude

# Prime number patterns
wolframscript -file primes/main.wl                                       # Ulam spiral (default)
wolframscript -file primes/main.wl -- --simulation.mode=gaps             # prime gap rhythm
wolframscript -file primes/main.wl -- --simulation.ulam.size=201         # larger spiral
wolframscript -file primes/main.wl -- --simulation.gaps.count=10000      # more primes

# Gravitational waves — chirp mode
wolframscript -file relativity/main.wl                                   # GW150914 (36+29 M☉)
wolframscript -file relativity/main.wl -- --simulation.chirp.preset gw170817
wolframscript -file relativity/main.wl -- --simulation.chirp.mass1_solar 50 --simulation.chirp.mass2_solar 50
wolframscript -file relativity/main.wl -- --sonification.chirp.time_stretch 8

# Gravitational waves — geodesic mode (Schwarzschild black hole)
wolframscript -file relativity/main.wl -- --simulation.mode geodesic    # bound orbit (default)
wolframscript -file relativity/main.wl -- --simulation.mode geodesic --simulation.geodesic.orbit_type plunging
wolframscript -file relativity/main.wl -- --simulation.mode geodesic --simulation.geodesic.orbit_type photon

# CMB power spectrum sonification
wolframscript -file cosmology/main.wl                                    # spectrum mode, simulated ΛCDM
wolframscript -file cosmology/main.wl -- --simulation.mode=sky           # sky map via Hilbert traversal
wolframscript -file cosmology/main.wl -- --simulation.cosmology.source=planck  # real Planck 2018 data

# 2D wave propagation (FEM)
wolframscript -file waves/main.wl                                        # ripple mode (circular membrane)
wolframscript -file waves/main.wl -- --simulation.mode=interference      # two-source interference pattern
wolframscript -file waves/main.wl -- --simulation.waves.wave_speed=1.5   # faster propagation
wolframscript -file waves/main.wl -- --simulation.waves.source_frequency=3.0

# Lagrange point orbits (CR3BP)
wolframscript -file lagrange/main.wl                                     # L4 libration, Sun-Jupiter
wolframscript -file lagrange/main.wl -- --simulation.mode=l5             # L5 libration
wolframscript -file lagrange/main.wl -- --simulation.mode=l1             # L1 saddle-point escape
wolframscript -file lagrange/main.wl -- --simulation.lagrange.preset=earth_moon

# 2D image sonification
wolframscript -file images/main.wl                                       # brightness mode, Gaussian test image
wolframscript -file images/main.wl -- --simulation.mode=scan_horizontal  # pedagogical scan
wolframscript -file images/main.wl -- --simulation.mode=colour           # colour mode
wolframscript -file images/main.wl -- --simulation.mode=hsb              # full HSB stereo mode
wolframscript -file images/main.wl -- --simulation.images.test_image=temperature
wolframscript -file images/main.wl -- --simulation.images.brightness_scale=log

# Statistical mechanics — Maxwell-Boltzmann distribution
wolframscript -file thermo/main.wl                                              # distribution, helium, 100K→1000K
wolframscript -file thermo/main.wl -- --simulation.mode=ensemble               # particle ensemble at 300K
wolframscript -file thermo/main.wl -- --simulation.mode=cooling                # thermal cooling 1000K→50K
wolframscript -file thermo/main.wl -- --simulation.mode=equipartition          # monatomic vs diatomic

# Monte Carlo — 2D Ising model
wolframscript -file montecarlo/main.wl                                          # sweep, T 4.0→0.5
wolframscript -file montecarlo/main.wl -- --simulation.mode=critical            # at T_c
wolframscript -file montecarlo/main.wl -- --simulation.mode=quench              # instantaneous quench

# Charged particles in a magnetic field
wolframscript -file magnetic/main.wl                                            # cyclotron orbit
wolframscript -file magnetic/main.wl -- --simulation.mode=drift                 # E×B drift
wolframscript -file magnetic/main.wl -- --simulation.mode=mirror                # magnetic mirror
wolframscript -file magnetic/main.wl -- --simulation.mode=multi                 # proton+alpha+electron chord

# Hydrogen atom — wave functions and emission spectrum
wolframscript -file hydrogen/main.wl                                            # orbitals, 2p (210)
wolframscript -file hydrogen/main.wl -- --simulation.mode=spectrum              # emission spectrum
wolframscript -file hydrogen/main.wl -- --simulation.mode=transitions           # quantum cascade
wolframscript -file hydrogen/main.wl -- --simulation.hydrogen.orbital=320       # 3d orbital

# Bayesian inference
wolframscript -file bayes/main.wl                                               # coin, θ=0.7, 100 flips
wolframscript -file bayes/main.wl -- --simulation.mode=gaussian                 # Gaussian mean
wolframscript -file bayes/main.wl -- --simulation.mode=model                    # Bayes factor

# Rutherford scattering
wolframscript -file scattering/main.wl                                          # single trajectory b=1
wolframscript -file scattering/main.wl -- --simulation.scattering.preset=backscatter
wolframscript -file scattering/main.wl -- --simulation.mode=discovery           # Thomson vs Rutherford

# Orbital resonances
wolframscript -file resonance/main.wl                                           # Galilean 4:2:1
wolframscript -file resonance/main.wl -- --simulation.mode=kirkwood             # Kirkwood gaps
wolframscript -file resonance/main.wl -- --simulation.mode=saturn               # Cassini Division

# Kármán vortex street
wolframscript -file fluid/main.wl                                               # karman, Re=150
wolframscript -file fluid/main.wl -- --simulation.mode=strouhal                 # Reynolds sweep
wolframscript -file fluid/main.wl -- --simulation.mode=flag                     # flag flutter

# Black body radiation
wolframscript -file blackbody/main.wl                                          # spectrum, solar T=5778K
wolframscript -file blackbody/main.wl -- --simulation.mode=temperature          # 2500K -> 40000K sweep
wolframscript -file blackbody/main.wl -- --simulation.mode=star \
                                          --simulation.blackbody.preset=all     # tour, red dwarf -> white dwarf

# Compton scattering
wolframscript -file compton/main.wl                                            # scatter, Compton's own 1923 values
wolframscript -file compton/main.wl -- --simulation.mode=sweep                  # angle glissando, 0-180 deg
wolframscript -file compton/main.wl -- --simulation.mode=energy                 # incident-energy sweep, 1keV-5MeV
wolframscript -file compton/main.wl -- --simulation.mode=discovery              # Thomson vs Compton, binaural
```

Each project writes outputs into its own directory:

| Project | Output dir | File types |
|---------|-----------|------------|
| all twenty-three apps | `output/` | CSV, GIF, WAV (+ PNG for signal, quantum, primes, relativity, images, cosmology, waves, lagrange, hydrogen, blackbody, compton) |

Play audio:

```sh
# macOS
afplay signal/output/chord_narrative_full.wav
afplay pendulum/output/double_audio.wav
afplay lorenz/output/lorenz_audio.wav
afplay dynamical/output/sweep_audio.wav
afplay dynamical/output/iterate_audio.wav
afplay asteroids/output/asteroids_*.wav
afplay cellular/output/life_rpentomino_audio.wav
afplay quantum/output/qho_audio.wav
afplay primes/output/ulam_audio.wav
afplay primes/output/gaps_audio.wav
afplay relativity/output/chirp.wav
afplay relativity/output/gw170817.wav
afplay relativity/output/geodesic.wav
afplay cosmology/output/cmb_spectrum_audio.wav
afplay waves/output/ripple_audio.wav
afplay waves/output/interference_audio.wav
afplay lagrange/output/l4_audio.wav
afplay lagrange/output/l1_audio.wav
afplay images/output/images_brightness_audio.wav
afplay thermo/output/distribution_audio.wav
afplay thermo/output/cooling_audio.wav
afplay montecarlo/output/sweep_audio.wav
afplay montecarlo/output/critical_audio.wav
afplay magnetic/output/mirror_audio.wav
afplay magnetic/output/cyclotron_audio.wav
afplay hydrogen/output/spectrum_audio.wav
afplay hydrogen/output/transitions_audio.wav
afplay bayes/output/coin_audio.wav
afplay bayes/output/model_audio.wav
afplay scattering/output/discovery_audio.wav
afplay resonance/output/galilean_audio.wav
afplay resonance/output/kirkwood_audio.wav
afplay fluid/output/karman_audio.wav
afplay fluid/output/strouhal_audio.wav
afplay blackbody/output/spectrum_audio.wav
afplay blackbody/output/temperature_audio.wav
afplay blackbody/output/star_audio.wav
afplay compton/output/scatter_audio.wav
afplay compton/output/sweep_audio.wav
afplay compton/output/discovery_audio.wav

# Linux — replace afplay with aplay
aplay signal/output/chord_narrative_full.wav
aplay pendulum/output/double_audio.wav

# Windows PowerShell — replace afplay with Start-Process wmplayer
Start-Process wmplayer signal\output\chord_narrative_full.wav
Start-Process wmplayer pendulum\output\double_audio.wav
```

See [RELEASE_NOTES_v1.4.0.md](RELEASE_NOTES_v1.4.0.md) for full app descriptions, physics notes, and listening guides.

---

## Demo

Run all twenty-three apps with their most interesting presets and collect outputs into `demo/`:

```sh
wolframscript -file demo.wl
```

With spoken announcements:
```sh
# macOS / Linux
STEM_SPEAK=1 wolframscript -file demo.wl

# Windows PowerShell
$env:STEM_SPEAK = "1"; wolframscript -file demo.wl
```

With NASA asteroid data (requires API key):
```sh
# macOS / Linux
NASA_API_KEY=$NASA_API_KEY wolframscript -file demo.wl

# Windows PowerShell
$env:NASA_API_KEY = "your_key_here"; wolframscript -file demo.wl
```

Check whether a previous demo run completed successfully:
```sh
wolframscript -file demo.wl -- --check-only
```

Outputs are collected in `demo/` with a written report at `demo/demo-report.md`. A full run takes approximately five to six minutes (24/24 runs — 23 unique apps, `dynamical` runs twice — including live asteroid data).

---

## Projects

### pendulum

Solves the nonlinear pendulum ODE with `NDSolve`. Two modes: `simple` (one rod)
and `double` (two rods, chaotic). The simple pendulum maps swing angle to an A
minor pentatonic scale — each half-swing becomes one note, volume set by angular
velocity. The double pendulum sonifies both rods independently in binaural stereo.
See [`pendulum/README.md`](pendulum/README.md).

### lorenz

Simulates the Lorenz and Rössler strange attractors. Apex events on the
trajectory trigger pitched notes; spatial position controls the stereo pan. The
GIF renders the growing trajectory in x-z projection with a
blue→cyan→orange→red colour gradient.
See [`lorenz/README.md`](lorenz/README.md).

### dynamical

Sonifies the logistic map, x_{n+1} = r·x_n·(1−x_n), and its period-doubling
route to chaos. `sweep` mode traverses r from 2.5 to 4.0, sonifying the
long-term attractor at each step — the rhythm audibly doubles at r≈3.0,
doubles again, and dissolves into chaos, with a distinct island of order (a
clean three-note rhythm) at the period-3 window near r≈3.83, guaranteed to
exist by the Li-Yorke theorem ("period three implies chaos"). `iterate` mode
fixes r (or a named preset — `fixed_point`, `period2`, `period4`,
`period3_window`, `chaos`) and sonifies the map's actual time evolution,
transient included, as a directly countable rhythm: period-4 genuinely
sounds like a four-note cycle. Four correctness checks run on every
invocation, including locating the first three period-doubling bifurcation
points numerically and verifying their ratio against the universal
Feigenbaum constant (δ≈4.669) — a number that governs the route to chaos in
any smooth one-dimensional map, not just this one. The sweep mode GIF
animates the classic bifurcation diagram being drawn progressively, with a
moving cursor and dashed lines marking the three named events.
See [`dynamical/README.md`](dynamical/README.md).

### asteroids

Fetches live close-approach data from NASA's NeoWs API. Each asteroid becomes
one note — pitch reflects miss distance, timbre distinguishes hazardous from
safe. The GIF shows a top-down solar system view with asteroids revealed
farthest-to-closest, coloured cyan (safe) or red (hazardous). Asteroid
directions are computed from Keplerian orbital elements fetched from the JPL
Small Body Database. Accepts arbitrary date ranges and a musical scale argument.
See [`asteroids/README.md`](asteroids/README.md).

### cellular

Two cellular automata: Conway's Game of Life (2D, toroidal, B3/S23 rule) and
Wolfram's Rule 110 (1D, Turing-complete). Population dynamics are mapped to
pitch, pan, and volume; extinction and explosion events trigger short tone bursts.
See [`cellular/README.md`](cellular/README.md).

### signal

Demonstrates the discrete Fourier transform. Three modes — `chord` (sum of
sinusoids), `sweep` (linear chirp), and `am` (amplitude modulation) — each
generate a signal, corrupt it with Gaussian noise, recover it via
frequency-domain filtering, and export the three stages as WAV files plus a
spoken narrative. Unlike all other apps, the WAV output **is** the phenomenon
rather than a sonification of something else.
See [`signal/README.md`](signal/README.md).

### quantum

Simulates quantum mechanical wave-packet evolution in two exactly-solvable
systems. `qho` mode evolves a coherent state |α⟩ in the quantum harmonic
oscillator using a truncated Hermite-Gauss basis (ħ=m=1). `box` mode evolves
an equal superposition of the ground state and first excited state in a
particle-in-a-box. Both modes export an animated probability-density GIF, a
3×3 snapshot PNG, and a time-series CSV of ⟨x⟩, Var(x), and speed. Stereo pan
tracks mean position, pitch encodes position variance, and volume follows
|d⟨x⟩/dt|.
See [`quantum/README.md`](quantum/README.md).

### primes

Visualises prime number structure in two modes. `ulam` mode generates a size×size
grid winding the integers outward in a spiral — prime cells appear white, composites
black — revealing the diagonal stripes that emerge from polynomial prime-rich
progressions. The app also exports a 31×31 centre zoom with cell borders. `gaps`
mode maps the sequence of gaps between consecutive primes to percussive audio: each
prime triggers a short sine burst at a time proportional to its distance from p₁,
so twin primes (gap=2) produce near-simultaneous attacks and large gaps leave
audible rests. A second WAV at quarter tempo stretches the rhythm so individual gap
lengths become easier to count by ear.
See [`primes/README.md`](primes/README.md).

### relativity

Two modes of general relativity simulation.

**chirp** — gravitational wave strain from a binary inspiral using the
post-Newtonian (PN) approximation, the same analytic model behind LIGO's
matched filters. The strain h(t) is literally an audio waveform: a *chirp*
sweeping upward in frequency and amplitude, ending in an abrupt merger
followed by an exponentially damped ringdown. Three preset comparison WAVs
are produced automatically (`gw150914`, `gw170817`, `stellar`). Four physical
correctness checks verify the PN formulas on each run and abort if they fail.

**geodesic** — test-particle and photon orbits around a Schwarzschild black
hole, integrated numerically by NDSolve. Three orbit types: `bound` (elliptical
orbit; GR periapsis precession traces a rosette), `plunging` (particle spirals
past the event horizon in finite proper time), `photon` (light deflected by
gravity — impact parameter controls deflection vs. capture). Each orbit is
visualised as a polar plot showing the event horizon, photon sphere, and ISCO,
and sonified with pitch mapped to the orbital angular frequency or gravitational
blueshift depending on orbit type.
See [`relativity/README.md`](relativity/README.md).

### cosmology

Sonifies the Cosmic Microwave Background (CMB) angular power spectrum — the
oldest light in the universe. Two modes: `spectrum` traverses the angular power
spectrum from ℓ = 2 to ℓ = 2000, mapping each multipole to a note so the
Sachs-Wolfe plateau, the first acoustic peak near ℓ ≈ 220, and the Silk damping
tail are directly audible. `sky` generates a flat-sky Gaussian random field from
the spectrum and traverses it pixel by pixel in Hilbert curve order, making the
spatial temperature pattern of the CMB sound as a correlated noise texture.
Both modes accept a `--simulation.cosmology.source=planck` flag to fetch the
actual Planck 2018 best-fit spectrum from the Planck Legacy Archive (internet
required). The PNG output shows the power spectrum with peak markers.
See [`cosmology/README.md`](cosmology/README.md).

### waves

Solves the 2D wave equation using the finite element method (`NDSolveValue` on
a spatial `Region`). Two modes: `ripple` places a Gaussian impulse at the centre
of a circular membrane and records the wavefront as it reaches a set of listening
points at increasing distances — the stereo sweep of arrivals from left to right
makes the propagation speed directly audible. `interference` drives two coherent
point sources in a rectangular tank and sweeps a listening point across the
resulting fringe pattern — constructive and destructive fringes produce swells
and silences in the audio. Four sanity checks (numerical stability, arrival time,
causality, Dirichlet boundary) run on every execution.
See [`waves/README.md`](waves/README.md).

### lagrange

Integrates test-particle trajectories in the circular restricted three-body
problem (CR3BP) in the co-rotating reference frame. Three modes: `l4` and `l5`
place a particle near the stable triangular Lagrange points and let it librate
in a tadpole pattern for six orbital periods — the bounded, quasi-periodic orbit
of Jupiter's Trojan asteroids. `l1` places a particle near the unstable L1
saddle point, where it escapes within one to three orbital periods along the
unstable manifold. In all modes, pitch maps to instantaneous angular velocity
around the barycentre, pan to x-position in the co-rotating frame, and volume
to inverse distance to the nearest primary. Named presets cover Sun-Jupiter,
Earth-Moon, and Sun-Earth systems.
See [`lagrange/README.md`](lagrange/README.md).

### images

Converts 2D images into audio via Hilbert curve traversal. The Hilbert curve
visits every pixel in locality-preserving order — pixels adjacent in the audio
timeline are also spatially nearby — so spatial gradients become smooth pitch
sweeps and sharp edges become abrupt jumps. Four sonification modes:
`brightness` maps grayscale intensity to frequency, logarithmically by default
to match how human hearing perceives pitch (simplest, best for first-time
listeners); `scan_horizontal` is a pedagogical raster-scan counterpart to
`brightness`, letting a listener hear the Hilbert-curve locality benefit
directly by comparison; `colour` maps each pixel to the nearest of nine
colours ordered by position in the visible light spectrum — violet the
lowest pitch, red the highest — using perceptually uniform Lab colour
distance (good for categorical images); `hsb` encodes hue as a shared pitch
and brightness as timbre (pure tone → richer harmonics) on top of a
saturation-controlled amplitude (most information-dense). Three built-in
scientific test images are included: a 2D Gaussian, a false-colour
temperature map, and a quantum probability density. Every run opens with a
short spoken introduction describing the image, mode, and mapping in use.
See [`images/README.md`](images/README.md) and
[`images/LISTENING_GUIDE.md`](images/LISTENING_GUIDE.md) for the recommended
listening sequence.

### thermo

Sonifies classical statistical mechanics — what temperature means at the
molecular level. At thermal equilibrium, molecular speeds in an ideal gas
follow the Maxwell-Boltzmann distribution, a curve with three characteristic
speeds (most probable, mean, and RMS, always in that increasing order) that
broadens and shifts to higher speeds as the gas heats up. Four modes:
`distribution` sweeps temperature and synthesises the distribution curve
itself as a spectral envelope — many simultaneous sine partials whose
amplitudes trace `f(v)`, so the sound literally *is* the distribution, not a
sonification of something else; `ensemble` samples a fixed set of particles
from that distribution and lets them exchange speeds via elastic collisions,
audible as a chord that continuously reshuffles while its overall character
stays fixed; `cooling` relaxes the gas from hot to cold following Newton's
law of cooling; `equipartition` compares a monatomic and a diatomic gas
side by side, making audible the extra heat capacity a diatomic gas gets
from rotational degrees of freedom. Named gas presets cover hydrogen,
helium, nitrogen, oxygen, and argon.
See [`thermo/README.md`](thermo/README.md).

### montecarlo

Sonifies the 2D ferromagnetic Ising model — the canonical example of a
phase transition, and one of the few exactly solved in statistical physics
(Onsager, 1944). A square lattice of up/down spins is updated by the
Metropolis algorithm, which samples configurations in proportion to their
Boltzmann probability by occasionally accepting energetically unfavourable
moves — the trick that lets the system properly explore thermal
fluctuations rather than getting stuck in a local minimum. Below the
critical temperature `T_c ≈ 2.269 J/k` the spins spontaneously align
(ferromagnetic order); above it, thermal noise wins (disorder). Near `T_c`,
magnetisation and susceptibility follow universal power laws shared by
every system in the same critical-phenomena universality class, from
magnets to the liquid-gas transition. Three modes: `sweep` descends through
`T_c` in one continuous run; `critical` holds at `T_c` for an extended
listen to scale-free fluctuation; `quench` drops the temperature
instantaneously and follows the disorder-to-order coarsening that results.
Two simultaneous sonification layers: global observables (magnetisation,
energy, susceptibility) as a continuous carrier, plus a quieter Hilbert-curve
scan of the spin grid itself.
See [`montecarlo/README.md`](montecarlo/README.md).

### magnetic

Simulates and sonifies a charged particle moving under the Lorentz force,
`F = q(E + v×B)`, across four field configurations. A uniform magnetic
field alone can never speed a particle up or slow it down — it only turns
it — producing circular motion at the **cyclotron frequency**, a quantity
that depends only on the particle's charge-to-mass ratio and the field
strength, never on its speed; the `cyclotron` mode's tone literally *is*
that frequency. Adding a perpendicular electric field produces `drift` mode:
a steady sideways drift riding underneath the circular motion, tracing a
cycloid — the same physics that makes stray fields such a problem for
confining plasma in a tokamak. A magnetic field that strengthens away from
a midplane creates a `mirror` — the principle behind the Van Allen
radiation belts, where solar-wind particles bounce between reflection
points near Earth's poles. Finally, `multi` mode sounds a proton, an alpha
particle, and an electron gyrating in the same field simultaneously — a
three-tone chord whose frequency ratios directly encode the particles'
relative masses.
See [`magnetic/README.md`](magnetic/README.md).

### hydrogen

Sonifies the quantum mechanics of the hydrogen atom — the only atom whose
Schrödinger equation can be solved exactly in closed form, and the
foundation of all atomic physics and spectroscopy. Energy levels follow
`E_n = -13.6057/n^2 eV`, and a transition from an excited state releases a
photon whose energy is the difference — the Rydberg formula. The Balmer
series (transitions down to n=2) is the visible light emitted by hydrogen,
empirically discovered in 1885 and theoretically explained by Bohr in 1913;
these same wavelengths appear as absorption lines in the spectra of stars
across the universe, including the Sun. Three modes: `orbitals` sonifies
`|psi_nlm|^2` wave functions via Hilbert curve traversal, so an orbital's
lobes and nodes become audible sweeps and silences; `spectrum` sonifies the
full n=2..n_max emission spectrum as a chord and then a UV-to-IR sweep;
`transitions` simulates an electron cascading down to the ground state
through a sequence of random, selection-rule-respecting quantum jumps —
`|Delta l| = 1` — audible as a different "melody" on every run.
See [`hydrogen/README.md`](hydrogen/README.md).

### bayes

Sonifies Bayesian inference — belief updating made directly audible. A
prior distribution, combined with observed data via the likelihood,
produces a posterior: the updated belief. Three conjugate-update scenarios,
all exact: `coin` mode updates a Beta prior over a coin's bias flip by
flip, the clearest possible demonstration of a broad, uncertain prior
narrowing into a focused posterior as evidence accumulates; `gaussian`
mode updates a Normal prior over an unknown mean, both narrowing and
shifting in pitch toward the true value; `model` mode computes a Bayes
factor between two competing hypotheses about a coin, with stereo position
drifting toward whichever hypothesis the data favours (interpreted via the
commonly-cited Jeffreys scale: anecdotal, moderate, strong, very strong
evidence). The `coin`/`gaussian` posteriors are sonified with the same
spectral-narrowing additive-synthesis technique as `thermo/`'s
Maxwell-Boltzmann distribution mode — but driven by accumulating
*information* rather than *temperature*.
See [`bayes/README.md`](bayes/README.md).

### scattering

Simulates and sonifies Rutherford alpha-particle scattering — the
1909-1911 Geiger-Marsden experiment that discovered the atomic nucleus.
J.J. Thomson's "plum pudding" model, with positive charge spread evenly
through the atom, could not produce large-angle scattering; Rutherford
described the observed result as "almost as incredible as if you fired a
15-inch shell at a piece of tissue paper and it came back and hit you." The
only explanation was a tiny, dense, positively charged nucleus. Three
modes: `scatter` integrates a single alpha particle's hyperbolic trajectory
around the nucleus, pitch and volume rising through closest approach;
`distribution` sonifies a realistic beam of particles as a dense, quiet
stream of small-angle events punctuated by rare, loud backscatter accents —
the Rutherford cross-section `1/sin^4(theta/2)` played directly rather than
plotted; `discovery` recreates the historical comparison in binaural
stereo, Thomson's model (left channel, confined to under one degree) against
Rutherford's (right channel, with occasional dramatic backscatter events the
Thomson model structurally cannot produce).
See [`scattering/README.md`](scattering/README.md).

### resonance

Sonifies orbital resonance — the phenomenon where orbiting bodies' periods
lock into simple integer ratios — across three settings, in the app where
planetary mechanics and music theory meet most precisely: a 2:1 orbital
resonance *is* a musical octave. `galilean` mode simulates Jupiter's moons
Io, Europa, and Ganymede, whose periods lock into an almost exact 4:2:1
ratio (the Laplace resonance), sonified as a rhythmic canon — a two-octave
chord, C3:C4:C5, in a 1:2:4 ratio of note counts, locked in place by
gravity. `kirkwood` mode sonifies the asteroid belt's Kirkwood gaps — sharp
silences at semi-major axes where Jupiter's resonant gravitational kicks
have swept the belt clear. `saturn` mode applies the same technique to
Saturn's rings, where the Cassini Division is audible as a long silence,
the same 2:1 resonance mechanism at a different scale, caused by the moon
Mimas. Kepler spent much of his career searching for a "harmony of the
spheres" among the planets; the Galilean moons, discovered just nine years
before his death, are the genuine article he never got to see.
See [`resonance/README.md`](resonance/README.md).

### fluid

Simulates and sonifies vortex shedding behind a bluff body — the Kármán
vortex street — making the Strouhal frequency directly audible: the same
pitch a wire, flagpole, or power line sings in the wind (an Aeolian tone).
`karman` mode fixes the Reynolds number and sonifies the resulting periodic
vortex shedding as a steady tone with alternating shed-event clicks.
`strouhal` mode sweeps the Reynolds number from onset (Re≈47 — a genuine
bifurcation from steady to periodic flow) through the laminar regime toward
turbulence, audible as silence giving way to a sudden tone that gradually
broadens. `flag` mode models a flexible flag flapping in the flow as a
damped, driven oscillator — a simplified cousin of the aeroelastic flutter
that destroyed the original Tacoma Narrows Bridge in 1940 — with pitch and
pan following the flapping tip. The wake itself is modelled with the vortex
particle method: a handful of discrete point vortices advected by mutual
Biot-Savart induction, an educational approximation rather than a full
Navier-Stokes solve.
See [`fluid/README.md`](fluid/README.md).

### blackbody

Sonifies Planck's law — the 1900 formula whose exact fit to both the
low- and high-frequency limits (Rayleigh-Jeans and Wien) forced quantum
mechanics into existence. `spectrum` mode fixes a temperature and
sweeps photon frequency from radio through microwave, infrared,
visible, ultraviolet, to X-ray, sonifying the curve the same way
`thermo/`'s Maxwell-Boltzmann distribution is sonified: as a spectral
envelope, many simultaneous partials tracing the physics directly,
rather than a single value moving over time. Two soft taps mark the
edges of the 400-700nm visible band — at the Sun's own temperature
(5778K) that band sits almost exactly on the curve's peak, which is not
a coincidence: human colour vision evolved around precisely this
spectrum. `temperature` mode sweeps temperature itself from a 2500K red
dwarf to a 40000K blue giant, making Wien's displacement law (the peak
rising in pitch) and the Stefan-Boltzmann law (total power rising as
temperature to the fourth power, log-compressed so it stays audible
across the whole range) audible at once. `star` mode tours six named
presets, red dwarf to white dwarf, chord-then-sweep for a single
preset (reusing `hydrogen/`'s emission-spectrum structure) or a
sequential, spoken tour across all six. See [`blackbody/README.md`](blackbody/README.md).

### compton

Sonifies Compton scattering — the 1923 measurement that settled the
wave/particle debate: a photon loses energy to a recoiling electron and
shifts to a longer wavelength, something only a particle carrying
discrete momentum can do. `scatter` mode plays Compton's own historical
values (71pm molybdenum X-rays, 90 degrees) as a short narrated
sequence — incoming photon, collision click, outgoing photon at a
measurably lower pitch, and a soft thud for the recoiling electron,
panned to the opposite side by momentum conservation. `sweep` mode turns
the formula itself into a glissando — pitch falling fastest through
90 degrees, exactly where `sin(theta)` peaks, the same "equation IS the
pitch bend" relationship `relativity/`'s chirp has to its own governing
formula. `energy` mode sweeps incident photon energy from 1 keV to
5 MeV, crossing the electron's own rest energy (511 keV) where the
incoming and outgoing pitches audibly pull apart. `discovery` mode
revisits the same binaural classical-vs-quantum structure as
`scattering/discovery` — left channel flat (J.J. Thomson's classical
prediction, making a second appearance in this codebase, this time as
the *correct* low-energy limit rather than a superseded atomic model),
right channel dropping (the real result) — the actual gap that won
Arthur Compton the 1927 Nobel Prize, made audible. See
[`compton/README.md`](compton/README.md).

---

## Config system

Every project uses a four-layer configuration system:

```
$HardcodedDefaults  →  config/config.json  →  <app>/config.json  →  CLI --key=value
```

Inspect the fully merged config for any project:

```sh
wolframscript -file pendulum/main.wl -- --config-dump
wolframscript -file cellular/main.wl -- --config-dump | python3 -m json.tool
```

Override any parameter at runtime using dot-separated key paths:

```sh
wolframscript -file pendulum/main.wl -- --simulation.mode=double
wolframscript -file lorenz/main.wl -- --simulation.mode=rossler
wolframscript -file cellular/main.wl -- --simulation.life.starting_pattern=gliderlgun
wolframscript -file signal/main.wl -- --simulation.chord.noise_level=0.8
wolframscript -file asteroids/main.wl -- --simulation.days_ahead=14
wolframscript -file quantum/main.wl -- --simulation.qho.alpha=3.0
wolframscript -file relativity/main.wl -- --simulation.chirp.mass1_solar 50
```

See [`docs/APPS.md`](docs/APPS.md) for a full listing of each app's config keys.

---

## stem-core

All twenty-three projects load `stem-core` as a shared library. It provides:

- **Config** — `LoadConfig`, `GetCfg`, `DeepMerge` — four-layer config merging and safe key lookup
- **Sonification pipeline** — `SonifyTrajectory`, `SpatialLayer`, `MotionLayer`, `EventLayer`, `MixLayers`, `RenderAudio`
- **Scale and synth** — `ScaleLookup`, `StemSynthNote`, `NormalizeBuffer`, `ExportAudioBuffer`
- **Export** — `ExportCSV`, `ExportGIF`
- **Accessibility** — `STEMHeading`, `STEMSection`, `STEMPrintN`, `STEMDescribeCSV/WAV/GIF`, `STEMSay`
- **Utils** — `EnsureDir`, `FmtN`, `LogError`

See [`stem-core/README.md`](stem-core/README.md) for the full API and
[`stem-core/AGENTS.md`](stem-core/AGENTS.md) for parameter details.

---

## Accessibility

All projects run fully headlessly and write plain WAV files. Every console
output line is a self-contained announcement so screen readers (VoiceOver on
macOS, Orca on Linux, Narrator on Windows) read each item cleanly without
splitting numbers across lines.

To enable spoken announcements alongside normal printed output, set
`STEM_SPEAK=1` before running:

```sh
# macOS / Linux
STEM_SPEAK=1 wolframscript -file pendulum/main.wl
STEM_SPEAK=1 wolframscript -file signal/main.wl

# Windows PowerShell
$env:STEM_SPEAK = "1"; wolframscript -file pendulum/main.wl
```

Platform TTS: macOS uses `say`, Linux uses `espeak-ng` (install with
`sudo apt install espeak-ng`), Windows uses the built-in System.Speech.
If TTS is unavailable the app prints a warning and continues silently.

The `signal` app's `{mode}_narrative_full.wav` is the most accessible single
output — it chains spoken text with the clean, noisy, and recovered signals so
the entire Fourier demonstration can be followed by listening alone.

For the complete VoiceOver + wolframscript workflow see
[`docs/voiceover-wolframscript-guide.md`](docs/voiceover-wolframscript-guide.md)
and [`stem-core/ACCESSIBILITY.md`](stem-core/ACCESSIBILITY.md).

---

## About MINT Access

MINT Access is a Swiss organisation promoting accessible STEM education. Website: [mintaccess.ch](https://www.mintaccess.ch/) (German)

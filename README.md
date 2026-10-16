# stem

[![Version](https://img.shields.io/badge/version-1.6.0-blue.svg)](RELEASE_NOTES_v1.6.0.md)
[![Wolfram Engine](https://img.shields.io/badge/Wolfram_Engine-supported_platforms-DD1100.svg)](#supported-platforms)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A monorepo of Wolfram Language physics simulations, data projects, and signal
processing demonstrations — each runnable from the terminal via `wolframscript`
and producing CSV data, an animated GIF, and audio output.

---

## Supported platforms

- **Supported** (tested with `tools/smoke_test.wl` and `demo.wl` at this
  release):
  - macOS 26 on Apple silicon with Wolfram Engine 15.0.1
    ([smoke report](docs/smoke_test_MacOSX-ARM64_2026-10-16_1344.txt)).
  - Windows 11 x86-64 with Wolfram Engine 15.0.0
    ([smoke report](docs/smoke_test_Windows-x86-64_2026-10-10.txt),
    [demo report](docs/demo_report_Windows-x86-64_2026-10-11.md)). Tested in
    Parallels on Apple silicon, so the x64 engine runs under emulation,
    about three times slower than on the Mac.
  - Ubuntu 26.04 LTS x86-64 with Wolfram Engine 15.0.0: 32 of 32 apps and
    `demo.wl` 33 of 33 in two consecutive clean runs
    ([smoke report 17:19](docs/smoke_test_Linux-x86-64_2026-10-16_1719.txt),
    [smoke report 18:48](docs/smoke_test_Linux-x86-64_2026-10-16_1848.txt),
    [demo report](docs/demo_report_Linux-x86-64_2026-10-16.md), a separate
    standalone `demo.wl` run, 33 of 33),
    about four times slower than the Mac (3.9 times for the apps, 4.5 for
    `demo.wl`). The runs of 2026-10-13, 10-14 and 10-15 in `docs/` are the
    record of the failures fixed before that: intermittent GIF export
    errors, the memory of GIF export and of the frame check, and runs that
    stopped without saying why ([details](docs/VERIFICATION_linux_gif.md),
    [memory](docs/VERIFICATION_gif_memory.md),
    [wrapper](docs/VERIFICATION_smoke_wrapper.md)).
  - Ubuntu's apport does not keep crash reports for Wolfram Engine; the
    report's last line, written by the wrapper, is where a crash shows, and
    `tools/smoke_test.sh --resume` continues the run.
  - For an unattended run (overnight), first stop the machine sleeping: set
    `HandleLidSwitch=ignore` in `/etc/systemd/logind.conf`, then
    `sudo systemctl mask sleep.target suspend.target`; run the smoke test
    inside `tmux` through `tools/smoke_test.sh`, and read the result from the
    report's last line, which the wrapper writes when wolframscript ends
    (with the signal if the kernel was killed). Ubuntu's apport does not
    keep crash reports for Wolfram Engine, so a segmentation fault is
    visible only in that last line.
- **Not supported**: Linux on ARM, because Wolfram offers no general
  Linux-ARM build of the engine (only a Raspberry Pi package, untested
  here); Wolfram Engine before 15, untested.

Memory: the full smoke test, `demo.wl` included, peaks at 5.2 GB resident in
the Wolfram kernel (Mac, 2026-10-16, during `dynamical`), so 8 GB of RAM is
the minimum. The 6.0 GB measured the day before was the pendulum frame check
loading all 500 frames of its GIF; it now reads one frame at a time
([measurements](docs/VERIFICATION_smoke_wrapper.md)). Before GIFs were
exported in chunks, one GIF export alone could take 12.8 GB
([measurements](docs/VERIFICATION_gif_memory.md)).

Narration voice and length differ by platform: Samantha on macOS; on Linux
and Windows, SLT, the English voice bundled with Wolfram Engine, so no
espeak-ng or other speech package is needed. The same narration runs a
different length on each, and GIF/WAV sync is verified on every run
regardless (`SyncWAVToGIF`).

The asteroids loudness figure is not a regression indicator: the app
sonifies live NASA data, which differ from week to week, and a week's file
can be held below the -17 LUFS target by the peak ceiling (-18.1 LUFS in the
two Linux runs).

---

## Repository layout

```
stem/
  stem-core/        Shared library: config, sonification pipeline, PCM synthesis, file export
  pendulum/         Simple and double pendulum ODE simulation
  lorenz/           Lorenz and Rössler strange attractor simulation
  dynamical/        Logistic map and period-doubling route to chaos
  henon/            Hénon map: 2D invertible chaotic attractor, Lorenz Poincaré-section link
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
  quantum_tunnelling/  Quantum tunnelling: barrier-crossing event, width sweep, energy sweep to resonance
  clt/              Central Limit Theorem: sample-mean sweep, standardized comparison, sum of N dice
  brownian/         Brownian motion: random walk, ensemble sqrt(t) law, Stokes-Einstein temperature sweep
  qubit/            Single qubit: Bloch sphere, gates, Rabi oscillation, Born-rule measurement
  bell/             Entanglement: Bell correlations, CHSH inequality, paired measurement
  grover/           Grover's search algorithm: optimal stopping, classical vs quantum race, rotation geometry
  quantum_statistics/  Bose-Einstein, Fermi-Dirac, Maxwell-Boltzmann occupation numbers: the quantum/thermo bridge
  mandelbrot/       Mandelbrot and Julia sets, self-similarity, via Hilbert curve traversal
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

Tested platforms are listed under [Supported platforms](#supported-platforms);
`tools/smoke_test.wl` (below) checks a new installation in one run.

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
| Windows | PowerShell `Media.SoundPlayer` | Built into Windows 10/11 — plays a WAV in the terminal, no media player needed |

Audio plays only from an interactive desktop session; over SSH (or any
session without a sound device) the commands below run but nothing is heard.

### Text-to-speech (required for narration)

Twenty-two apps speak an intro (and often an outro) into their WAV files;
`signal` builds a fully narrated WAV. That narration is synthesised in three
tiers, the same on every platform (stem-core `STEMSpeakToBuffer`):

1. `SpeechSynthesize[]`, Wolfram's built-in speech, is tried first on all
   platforms. On the development Mac it produces every narration; on other
   installs it may not work headless (it needs Wolfram's voice resources),
   and then the platform tool takes over.
2. The platform text-to-speech tool, which is **required** for narration
   wherever `SpeechSynthesize[]` does not work:

| Platform | Tool | Install |
|---|---|---|
| macOS | `say` (with `afconvert`) | Built into macOS |
| Linux | `espeak-ng` (`espeak` is tried if it is missing) | `sudo apt install espeak-ng` · `sudo dnf install espeak-ng` |
| Windows | PowerShell with System.Speech | Built into Windows 10/11 (Windows PowerShell 5.1) |

3. If neither produces audio, the app prints one warning naming the app, the
   tiers tried and how many seconds of narration are missing, prints the
   text, and still writes a valid WAV without the speech (`signal` puts
   0.5 s of silence in each missing segment).

The text reaches the platform tool through a temporary UTF-8 text file, so
names such as "Hénon" are spoken correctly on every platform.

The voice is always English and chosen explicitly, never the system default
(which follows the system's language and could read the English text with a
German or French voice):

- `SpeechSynthesize[]`: Samantha, then Daniel, then the first en-US or en-GB
  voice by name (female before male), from Wolfram's own voice list. On the
  Mac this is Samantha, the voice it used before.
- macOS `say`: Samantha, then Daniel, then the first `en_` voice in
  `say -v ?`; with no English voice installed, `say` is skipped.
- Windows PowerShell: the first installed en-US voice by name, then en-GB.
- Linux `espeak-ng`: `-v en`.

The first narration of each app prints one line naming the voice and the
tier, for example `Narration voice: Samantha (en-US, female) through
SpeechSynthesize[], chosen automatically, at the voice's own rate.`

Two optional config keys override the choice, in `config.json` or on the
command line:

| Key | Effect |
|---|---|
| `simulation.speech.voice` | A voice name, used by every tier that has it (for example `Daniel`; espeak-ng gets it as `-v`) |
| `simulation.speech.rate_wpm` | Words per minute: `say -r` and `espeak-ng -s`; `SpeechSynthesize[]` and PowerShell output is time-stretched from the voice's own rate, measured once on a calibration sentence |

```sh
wolframscript -file henon/main.wl -- --simulation.speech.voice=Daniel
wolframscript -file henon/main.wl -- --simulation.speech.rate_wpm=200
```

This is separate from `STEM_SPEAK=1`, which only makes the console
announcements speak aloud as they are printed (see Accessibility below); the
narration inside the WAV files does not depend on it.

### Environment variables

| Variable | Effect |
|---|---|
| `STEM_SPEAK=1` | Also speak the console announcements aloud (uses the same platform tool) |
| `NASA_API_KEY` | Personal NASA key for the `asteroids` app (optional; `DEMO_KEY` otherwise) |
| `STEM_SPEECH=platform` | Skip `SpeechSynthesize[]` and narrate with the platform tool (`say`, `espeak-ng`, PowerShell) |
| `STEM_SPEECH=synthesize` | Use `SpeechSynthesize[]` only |
| `STEM_SPEECH=off` (or `STEM_SPEECH_OFF=1`) | Skip all narration synthesis (testing the no-speech path) |

Register for a free NASA key at https://api.nasa.gov/. The built-in
`DEMO_KEY` works at 30 requests/hour; a personal key removes that limit.

```sh
# macOS / Linux (bash or zsh) — for one command
STEM_SPEAK=1 wolframscript -file pendulum/main.wl
NASA_API_KEY=your_key_here wolframscript -file asteroids/main.wl

# macOS / Linux — for the session (add to ~/.zshrc or ~/.bashrc to persist)
export STEM_SPEAK=1
export NASA_API_KEY=your_key_here
```

```powershell
# Windows PowerShell — for the current session
$env:STEM_SPEAK = "1"
$env:NASA_API_KEY = "your_key_here"
wolframscript -file asteroids\main.wl

# Windows PowerShell — persist for your user account (new windows only)
[Environment]::SetEnvironmentVariable("NASA_API_KEY", "your_key_here", "User")
```

```bat
:: Windows Command Prompt (cmd) — for the current session
set STEM_SPEAK=1
set NASA_API_KEY=your_key_here
wolframscript -file asteroids\main.wl

:: Windows Command Prompt — persist for your user account (new windows only)
setx NASA_API_KEY your_key_here
```

---

## Quick start

Run any project from the `stem/` root. The commands below are for bash or
zsh (macOS, Linux); the Windows forms follow, and differ in four ways:

- **Windows PowerShell**: write the separator as `'--'` (quoted). Windows
  PowerShell 5.1 can drop a bare `--` before it reaches a native program
  such as wolframscript, and the app would then see no arguments. The
  quoted form is passed through by every PowerShell version. Lines
  continue with a backtick (`` ` ``) instead of `\`.
- **Command Prompt (cmd)**: `#` is not a comment, so the comments are
  removed (or turned into `REM` lines); lines continue with `^`.
- **Paths** use `\` on Windows.
- **`wolframscript -code`** strips double quotes from its argument on
  Windows, so `-code 'Print["hi"]'` arrives as `Print[hi]`. Put code that
  contains quoted strings in a `.wl` file and run it with `-file`.

```sh
# Physics simulations
wolframscript -file pendulum/main.wl
wolframscript -file lorenz/main.wl

# Logistic map — period-doubling route to chaos
wolframscript -file dynamical/main.wl                                      # sweep mode, r 2.5→4.0
wolframscript -file dynamical/main.wl -- --simulation.mode=iterate         # iterate at r=3.8
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=period3_window

# Hénon map — 2D invertible chaotic attractor
wolframscript -file henon/main.wl                                          # attractor, canonical a=1.4,b=0.3
wolframscript -file henon/main.wl -- --simulation.mode=sweep                # period-doubling sweep, a 0.2→1.4
wolframscript -file henon/main.wl -- --simulation.mode=reverse              # forward/reversed/inverse-demo

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

# Single qubit — Bloch sphere, gates, Rabi oscillation, measurement
wolframscript -file qubit/main.wl                                        # gates, H-T-H-S-X from |0>
wolframscript -file qubit/main.wl -- --simulation.mode=rabi              # continuous Rabi oscillation
wolframscript -file qubit/main.wl -- --simulation.mode=measurement       # 2000 Born-rule measurements

# Entanglement — Bell correlations, CHSH inequality, paired measurement
wolframscript -file bell/main.wl                                         # correlations, binaural quantum vs classical
wolframscript -file bell/main.wl -- --simulation.mode=chsh               # CHSH gauge at derived-optimal angles
wolframscript -file bell/main.wl -- --simulation.mode=measurement        # 2000 paired Bell measurements

# Grover's search algorithm — optimal stopping, classical vs quantum race, rotation geometry
wolframscript -file grover/main.wl                                       # search, N=64, rise then fall past optimum
wolframscript -file grover/main.wl -- --simulation.mode=compare          # binaural classical vs quantum race
wolframscript -file grover/main.wl -- --simulation.mode=geometry         # continuous 2D rotation

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

# Mandelbrot and Julia sets — Hilbert curve traversal, self-similarity
wolframscript -file mandelbrot/main.wl                                    # the classic set
wolframscript -file mandelbrot/main.wl -- --simulation.mode=julia         # fixed c, sweep z0
wolframscript -file mandelbrot/main.wl -- --simulation.mode=zoom          # 4 levels, seahorse valley

# Statistical mechanics — Maxwell-Boltzmann distribution
wolframscript -file thermo/main.wl                                              # distribution, helium, 100K→1000K
wolframscript -file thermo/main.wl -- --simulation.mode=ensemble               # particle ensemble at 300K
wolframscript -file thermo/main.wl -- --simulation.mode=cooling                # thermal cooling 1000K→50K
wolframscript -file thermo/main.wl -- --simulation.mode=equipartition          # monatomic vs diatomic

# Quantum statistics — Bose-Einstein, Fermi-Dirac, Maxwell-Boltzmann
wolframscript -file quantum_statistics/main.wl                                 # spectrum, three voices, T=300K
wolframscript -file quantum_statistics/main.wl -- --simulation.mode=temperature  # sweep T, fixed energy
wolframscript -file quantum_statistics/main.wl -- --simulation.mode=fermi_sea    # FD step, cold to warm

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

# Quantum tunnelling
wolframscript -file quantum_tunnelling/main.wl                                  # barrier, default preset (T~2.35%)
wolframscript -file quantum_tunnelling/main.wl -- --simulation.quantum_tunnelling.preset=stm
wolframscript -file quantum_tunnelling/main.wl -- --simulation.mode=sweep       # barrier-width sweep
wolframscript -file quantum_tunnelling/main.wl -- --simulation.mode=energy      # energy sweep, crosses V0

# Central Limit Theorem
wolframscript -file clt/main.wl                                                 # sweep, uniform source
wolframscript -file clt/main.wl -- --simulation.clt.source=exponential
wolframscript -file clt/main.wl -- --simulation.mode=compare                    # uniform vs exponential, binaural
wolframscript -file clt/main.wl -- --simulation.mode=dice                       # sum of N fair dice

# Brownian motion
wolframscript -file brownian/main.wl                                            # single random walk
wolframscript -file brownian/main.wl -- --simulation.mode=ensemble              # 150-walker sqrt(t) glissando
wolframscript -file brownian/main.wl -- --simulation.mode=temperature          # Stokes-Einstein D(T) sweep
```

<details><summary>Windows PowerShell</summary>

```powershell
# Physics simulations
wolframscript -file pendulum\main.wl
wolframscript -file lorenz\main.wl

# Logistic map — period-doubling route to chaos
wolframscript -file dynamical\main.wl   # sweep mode, r 2.5→4.0
wolframscript -file dynamical\main.wl '--' --simulation.mode=iterate   # iterate at r=3.8
wolframscript -file dynamical\main.wl '--' --simulation.dynamical.preset=period3_window

# Hénon map — 2D invertible chaotic attractor
wolframscript -file henon\main.wl   # attractor, canonical a=1.4,b=0.3
wolframscript -file henon\main.wl '--' --simulation.mode=sweep   # period-doubling sweep, a 0.2→1.4
wolframscript -file henon\main.wl '--' --simulation.mode=reverse   # forward/reversed/inverse-demo

# Live NASA asteroid data
wolframscript -file asteroids\main.wl   # last 7 days
wolframscript -file asteroids\main.wl '--' 2026-01-01 2026-12-31   # full year
wolframscript -file asteroids\main.wl '--' 2026-01-01 2026-06-25 Phrygian   # date range + scale
wolframscript -file asteroids\main.wl '--' 2026-06-20 2026-06-26 --no-orbital-elements

# Cellular automata
wolframscript -file cellular\main.wl   # Game of Life, R-pentomino
wolframscript -file cellular\main.wl '--' --simulation.mode=rule110

# Signal processing
wolframscript -file signal\main.wl   # chord (default)
wolframscript -file signal\main.wl '--' --simulation.mode=sweep
wolframscript -file signal\main.wl '--' --simulation.mode=am

# Quantum mechanics
wolframscript -file quantum\main.wl   # QHO coherent state
wolframscript -file quantum\main.wl '--' --simulation.mode=box   # particle-in-a-box
wolframscript -file quantum\main.wl '--' --simulation.qho.alpha=3.0   # larger coherent amplitude

# Single qubit — Bloch sphere, gates, Rabi oscillation, measurement
wolframscript -file qubit\main.wl   # gates, H-T-H-S-X from |0>
wolframscript -file qubit\main.wl '--' --simulation.mode=rabi   # continuous Rabi oscillation
wolframscript -file qubit\main.wl '--' --simulation.mode=measurement   # 2000 Born-rule measurements

# Entanglement — Bell correlations, CHSH inequality, paired measurement
wolframscript -file bell\main.wl   # correlations, binaural quantum vs classical
wolframscript -file bell\main.wl '--' --simulation.mode=chsh   # CHSH gauge at derived-optimal angles
wolframscript -file bell\main.wl '--' --simulation.mode=measurement   # 2000 paired Bell measurements

# Grover's search algorithm — optimal stopping, classical vs quantum race, rotation geometry
wolframscript -file grover\main.wl   # search, N=64, rise then fall past optimum
wolframscript -file grover\main.wl '--' --simulation.mode=compare   # binaural classical vs quantum race
wolframscript -file grover\main.wl '--' --simulation.mode=geometry   # continuous 2D rotation

# Prime number patterns
wolframscript -file primes\main.wl   # Ulam spiral (default)
wolframscript -file primes\main.wl '--' --simulation.mode=gaps   # prime gap rhythm
wolframscript -file primes\main.wl '--' --simulation.ulam.size=201   # larger spiral
wolframscript -file primes\main.wl '--' --simulation.gaps.count=10000   # more primes

# Gravitational waves — chirp mode
wolframscript -file relativity\main.wl   # GW150914 (36+29 M☉)
wolframscript -file relativity\main.wl '--' --simulation.chirp.preset gw170817
wolframscript -file relativity\main.wl '--' --simulation.chirp.mass1_solar 50 --simulation.chirp.mass2_solar 50
wolframscript -file relativity\main.wl '--' --sonification.chirp.time_stretch 8

# Gravitational waves — geodesic mode (Schwarzschild black hole)
wolframscript -file relativity\main.wl '--' --simulation.mode geodesic   # bound orbit (default)
wolframscript -file relativity\main.wl '--' --simulation.mode geodesic --simulation.geodesic.orbit_type plunging
wolframscript -file relativity\main.wl '--' --simulation.mode geodesic --simulation.geodesic.orbit_type photon

# CMB power spectrum sonification
wolframscript -file cosmology\main.wl   # spectrum mode, simulated ΛCDM
wolframscript -file cosmology\main.wl '--' --simulation.mode=sky   # sky map via Hilbert traversal
wolframscript -file cosmology\main.wl '--' --simulation.cosmology.source=planck   # real Planck 2018 data

# 2D wave propagation (FEM)
wolframscript -file waves\main.wl   # ripple mode (circular membrane)
wolframscript -file waves\main.wl '--' --simulation.mode=interference   # two-source interference pattern
wolframscript -file waves\main.wl '--' --simulation.waves.wave_speed=1.5   # faster propagation
wolframscript -file waves\main.wl '--' --simulation.waves.source_frequency=3.0

# Lagrange point orbits (CR3BP)
wolframscript -file lagrange\main.wl   # L4 libration, Sun-Jupiter
wolframscript -file lagrange\main.wl '--' --simulation.mode=l5   # L5 libration
wolframscript -file lagrange\main.wl '--' --simulation.mode=l1   # L1 saddle-point escape
wolframscript -file lagrange\main.wl '--' --simulation.lagrange.preset=earth_moon

# 2D image sonification
wolframscript -file images\main.wl   # brightness mode, Gaussian test image
wolframscript -file images\main.wl '--' --simulation.mode=scan_horizontal   # pedagogical scan
wolframscript -file images\main.wl '--' --simulation.mode=colour   # colour mode
wolframscript -file images\main.wl '--' --simulation.mode=hsb   # full HSB stereo mode
wolframscript -file images\main.wl '--' --simulation.images.test_image=temperature
wolframscript -file images\main.wl '--' --simulation.images.brightness_scale=log

# Mandelbrot and Julia sets — Hilbert curve traversal, self-similarity
wolframscript -file mandelbrot\main.wl   # the classic set
wolframscript -file mandelbrot\main.wl '--' --simulation.mode=julia   # fixed c, sweep z0
wolframscript -file mandelbrot\main.wl '--' --simulation.mode=zoom   # 4 levels, seahorse valley

# Statistical mechanics — Maxwell-Boltzmann distribution
wolframscript -file thermo\main.wl   # distribution, helium, 100K→1000K
wolframscript -file thermo\main.wl '--' --simulation.mode=ensemble   # particle ensemble at 300K
wolframscript -file thermo\main.wl '--' --simulation.mode=cooling   # thermal cooling 1000K→50K
wolframscript -file thermo\main.wl '--' --simulation.mode=equipartition   # monatomic vs diatomic

# Quantum statistics — Bose-Einstein, Fermi-Dirac, Maxwell-Boltzmann
wolframscript -file quantum_statistics\main.wl   # spectrum, three voices, T=300K
wolframscript -file quantum_statistics\main.wl '--' --simulation.mode=temperature   # sweep T, fixed energy
wolframscript -file quantum_statistics\main.wl '--' --simulation.mode=fermi_sea   # FD step, cold to warm

# Monte Carlo — 2D Ising model
wolframscript -file montecarlo\main.wl   # sweep, T 4.0→0.5
wolframscript -file montecarlo\main.wl '--' --simulation.mode=critical   # at T_c
wolframscript -file montecarlo\main.wl '--' --simulation.mode=quench   # instantaneous quench

# Charged particles in a magnetic field
wolframscript -file magnetic\main.wl   # cyclotron orbit
wolframscript -file magnetic\main.wl '--' --simulation.mode=drift   # E×B drift
wolframscript -file magnetic\main.wl '--' --simulation.mode=mirror   # magnetic mirror
wolframscript -file magnetic\main.wl '--' --simulation.mode=multi   # proton+alpha+electron chord

# Hydrogen atom — wave functions and emission spectrum
wolframscript -file hydrogen\main.wl   # orbitals, 2p (210)
wolframscript -file hydrogen\main.wl '--' --simulation.mode=spectrum   # emission spectrum
wolframscript -file hydrogen\main.wl '--' --simulation.mode=transitions   # quantum cascade
wolframscript -file hydrogen\main.wl '--' --simulation.hydrogen.orbital=320   # 3d orbital

# Bayesian inference
wolframscript -file bayes\main.wl   # coin, θ=0.7, 100 flips
wolframscript -file bayes\main.wl '--' --simulation.mode=gaussian   # Gaussian mean
wolframscript -file bayes\main.wl '--' --simulation.mode=model   # Bayes factor

# Rutherford scattering
wolframscript -file scattering\main.wl   # single trajectory b=1
wolframscript -file scattering\main.wl '--' --simulation.scattering.preset=backscatter
wolframscript -file scattering\main.wl '--' --simulation.mode=discovery   # Thomson vs Rutherford

# Orbital resonances
wolframscript -file resonance\main.wl   # Galilean 4:2:1
wolframscript -file resonance\main.wl '--' --simulation.mode=kirkwood   # Kirkwood gaps
wolframscript -file resonance\main.wl '--' --simulation.mode=saturn   # Cassini Division

# Kármán vortex street
wolframscript -file fluid\main.wl   # karman, Re=150
wolframscript -file fluid\main.wl '--' --simulation.mode=strouhal   # Reynolds sweep
wolframscript -file fluid\main.wl '--' --simulation.mode=flag   # flag flutter

# Black body radiation
wolframscript -file blackbody\main.wl   # spectrum, solar T=5778K
wolframscript -file blackbody\main.wl '--' --simulation.mode=temperature   # 2500K -> 40000K sweep
wolframscript -file blackbody\main.wl '--' --simulation.mode=star `
                                          --simulation.blackbody.preset=all   # tour, red dwarf -> white dwarf

# Compton scattering
wolframscript -file compton\main.wl   # scatter, Compton's own 1923 values
wolframscript -file compton\main.wl '--' --simulation.mode=sweep   # angle glissando, 0-180 deg
wolframscript -file compton\main.wl '--' --simulation.mode=energy   # incident-energy sweep, 1keV-5MeV
wolframscript -file compton\main.wl '--' --simulation.mode=discovery   # Thomson vs Compton, binaural

# Quantum tunnelling
wolframscript -file quantum_tunnelling\main.wl   # barrier, default preset (T~2.35%)
wolframscript -file quantum_tunnelling\main.wl '--' --simulation.quantum_tunnelling.preset=stm
wolframscript -file quantum_tunnelling\main.wl '--' --simulation.mode=sweep   # barrier-width sweep
wolframscript -file quantum_tunnelling\main.wl '--' --simulation.mode=energy   # energy sweep, crosses V0

# Central Limit Theorem
wolframscript -file clt\main.wl   # sweep, uniform source
wolframscript -file clt\main.wl '--' --simulation.clt.source=exponential
wolframscript -file clt\main.wl '--' --simulation.mode=compare   # uniform vs exponential, binaural
wolframscript -file clt\main.wl '--' --simulation.mode=dice   # sum of N fair dice

# Brownian motion
wolframscript -file brownian\main.wl   # single random walk
wolframscript -file brownian\main.wl '--' --simulation.mode=ensemble   # 150-walker sqrt(t) glissando
wolframscript -file brownian\main.wl '--' --simulation.mode=temperature   # Stokes-Einstein D(T) sweep
```

</details>

<details><summary>Windows Command Prompt (cmd)</summary>

```bat
REM Physics simulations
wolframscript -file pendulum\main.wl
wolframscript -file lorenz\main.wl

REM Logistic map — period-doubling route to chaos
wolframscript -file dynamical\main.wl
wolframscript -file dynamical\main.wl -- --simulation.mode=iterate
wolframscript -file dynamical\main.wl -- --simulation.dynamical.preset=period3_window

REM Hénon map — 2D invertible chaotic attractor
wolframscript -file henon\main.wl
wolframscript -file henon\main.wl -- --simulation.mode=sweep
wolframscript -file henon\main.wl -- --simulation.mode=reverse

REM Live NASA asteroid data
wolframscript -file asteroids\main.wl
wolframscript -file asteroids\main.wl -- 2026-01-01 2026-12-31
wolframscript -file asteroids\main.wl -- 2026-01-01 2026-06-25 Phrygian
wolframscript -file asteroids\main.wl -- 2026-06-20 2026-06-26 --no-orbital-elements

REM Cellular automata
wolframscript -file cellular\main.wl
wolframscript -file cellular\main.wl -- --simulation.mode=rule110

REM Signal processing
wolframscript -file signal\main.wl
wolframscript -file signal\main.wl -- --simulation.mode=sweep
wolframscript -file signal\main.wl -- --simulation.mode=am

REM Quantum mechanics
wolframscript -file quantum\main.wl
wolframscript -file quantum\main.wl -- --simulation.mode=box
wolframscript -file quantum\main.wl -- --simulation.qho.alpha=3.0

REM Single qubit — Bloch sphere, gates, Rabi oscillation, measurement
wolframscript -file qubit\main.wl
wolframscript -file qubit\main.wl -- --simulation.mode=rabi
wolframscript -file qubit\main.wl -- --simulation.mode=measurement

REM Entanglement — Bell correlations, CHSH inequality, paired measurement
wolframscript -file bell\main.wl
wolframscript -file bell\main.wl -- --simulation.mode=chsh
wolframscript -file bell\main.wl -- --simulation.mode=measurement

REM Grover's search algorithm — optimal stopping, classical vs quantum race, rotation geometry
wolframscript -file grover\main.wl
wolframscript -file grover\main.wl -- --simulation.mode=compare
wolframscript -file grover\main.wl -- --simulation.mode=geometry

REM Prime number patterns
wolframscript -file primes\main.wl
wolframscript -file primes\main.wl -- --simulation.mode=gaps
wolframscript -file primes\main.wl -- --simulation.ulam.size=201
wolframscript -file primes\main.wl -- --simulation.gaps.count=10000

REM Gravitational waves — chirp mode
wolframscript -file relativity\main.wl
wolframscript -file relativity\main.wl -- --simulation.chirp.preset gw170817
wolframscript -file relativity\main.wl -- --simulation.chirp.mass1_solar 50 --simulation.chirp.mass2_solar 50
wolframscript -file relativity\main.wl -- --sonification.chirp.time_stretch 8

REM Gravitational waves — geodesic mode (Schwarzschild black hole)
wolframscript -file relativity\main.wl -- --simulation.mode geodesic
wolframscript -file relativity\main.wl -- --simulation.mode geodesic --simulation.geodesic.orbit_type plunging
wolframscript -file relativity\main.wl -- --simulation.mode geodesic --simulation.geodesic.orbit_type photon

REM CMB power spectrum sonification
wolframscript -file cosmology\main.wl
wolframscript -file cosmology\main.wl -- --simulation.mode=sky
wolframscript -file cosmology\main.wl -- --simulation.cosmology.source=planck

REM 2D wave propagation (FEM)
wolframscript -file waves\main.wl
wolframscript -file waves\main.wl -- --simulation.mode=interference
wolframscript -file waves\main.wl -- --simulation.waves.wave_speed=1.5
wolframscript -file waves\main.wl -- --simulation.waves.source_frequency=3.0

REM Lagrange point orbits (CR3BP)
wolframscript -file lagrange\main.wl
wolframscript -file lagrange\main.wl -- --simulation.mode=l5
wolframscript -file lagrange\main.wl -- --simulation.mode=l1
wolframscript -file lagrange\main.wl -- --simulation.lagrange.preset=earth_moon

REM 2D image sonification
wolframscript -file images\main.wl
wolframscript -file images\main.wl -- --simulation.mode=scan_horizontal
wolframscript -file images\main.wl -- --simulation.mode=colour
wolframscript -file images\main.wl -- --simulation.mode=hsb
wolframscript -file images\main.wl -- --simulation.images.test_image=temperature
wolframscript -file images\main.wl -- --simulation.images.brightness_scale=log

REM Mandelbrot and Julia sets — Hilbert curve traversal, self-similarity
wolframscript -file mandelbrot\main.wl
wolframscript -file mandelbrot\main.wl -- --simulation.mode=julia
wolframscript -file mandelbrot\main.wl -- --simulation.mode=zoom

REM Statistical mechanics — Maxwell-Boltzmann distribution
wolframscript -file thermo\main.wl
wolframscript -file thermo\main.wl -- --simulation.mode=ensemble
wolframscript -file thermo\main.wl -- --simulation.mode=cooling
wolframscript -file thermo\main.wl -- --simulation.mode=equipartition

REM Quantum statistics — Bose-Einstein, Fermi-Dirac, Maxwell-Boltzmann
wolframscript -file quantum_statistics\main.wl
wolframscript -file quantum_statistics\main.wl -- --simulation.mode=temperature
wolframscript -file quantum_statistics\main.wl -- --simulation.mode=fermi_sea

REM Monte Carlo — 2D Ising model
wolframscript -file montecarlo\main.wl
wolframscript -file montecarlo\main.wl -- --simulation.mode=critical
wolframscript -file montecarlo\main.wl -- --simulation.mode=quench

REM Charged particles in a magnetic field
wolframscript -file magnetic\main.wl
wolframscript -file magnetic\main.wl -- --simulation.mode=drift
wolframscript -file magnetic\main.wl -- --simulation.mode=mirror
wolframscript -file magnetic\main.wl -- --simulation.mode=multi

REM Hydrogen atom — wave functions and emission spectrum
wolframscript -file hydrogen\main.wl
wolframscript -file hydrogen\main.wl -- --simulation.mode=spectrum
wolframscript -file hydrogen\main.wl -- --simulation.mode=transitions
wolframscript -file hydrogen\main.wl -- --simulation.hydrogen.orbital=320

REM Bayesian inference
wolframscript -file bayes\main.wl
wolframscript -file bayes\main.wl -- --simulation.mode=gaussian
wolframscript -file bayes\main.wl -- --simulation.mode=model

REM Rutherford scattering
wolframscript -file scattering\main.wl
wolframscript -file scattering\main.wl -- --simulation.scattering.preset=backscatter
wolframscript -file scattering\main.wl -- --simulation.mode=discovery

REM Orbital resonances
wolframscript -file resonance\main.wl
wolframscript -file resonance\main.wl -- --simulation.mode=kirkwood
wolframscript -file resonance\main.wl -- --simulation.mode=saturn

REM Kármán vortex street
wolframscript -file fluid\main.wl
wolframscript -file fluid\main.wl -- --simulation.mode=strouhal
wolframscript -file fluid\main.wl -- --simulation.mode=flag

REM Black body radiation
wolframscript -file blackbody\main.wl
wolframscript -file blackbody\main.wl -- --simulation.mode=temperature
wolframscript -file blackbody\main.wl -- --simulation.mode=star ^
                                          --simulation.blackbody.preset=all

REM Compton scattering
wolframscript -file compton\main.wl
wolframscript -file compton\main.wl -- --simulation.mode=sweep
wolframscript -file compton\main.wl -- --simulation.mode=energy
wolframscript -file compton\main.wl -- --simulation.mode=discovery

REM Quantum tunnelling
wolframscript -file quantum_tunnelling\main.wl
wolframscript -file quantum_tunnelling\main.wl -- --simulation.quantum_tunnelling.preset=stm
wolframscript -file quantum_tunnelling\main.wl -- --simulation.mode=sweep
wolframscript -file quantum_tunnelling\main.wl -- --simulation.mode=energy

REM Central Limit Theorem
wolframscript -file clt\main.wl
wolframscript -file clt\main.wl -- --simulation.clt.source=exponential
wolframscript -file clt\main.wl -- --simulation.mode=compare
wolframscript -file clt\main.wl -- --simulation.mode=dice

REM Brownian motion
wolframscript -file brownian\main.wl
wolframscript -file brownian\main.wl -- --simulation.mode=ensemble
wolframscript -file brownian\main.wl -- --simulation.mode=temperature
```

</details>

Each project writes outputs into its own directory:

| Project | Output dir | File types |
|---------|-----------|------------|
| all thirty-two apps | `output/` | CSV, GIF, WAV (+ PNG for signal, quantum, primes, relativity, images, cosmology, waves, lagrange, hydrogen, blackbody, compton, quantum_tunnelling, clt, henon, brownian, qubit, bell, grover, quantum_statistics, mandelbrot) |

Play audio. `afplay` is built into macOS; on Linux `aplay` comes with
alsa-utils (see Prerequisites); in Windows PowerShell `Media.SoundPlayer`
plays a WAV in the terminal and waits until it ends (the full path, via
`$PWD`, is needed because .NET does not use PowerShell's current folder);
in cmd, `start` opens the WAV in the default player.

<details><summary>macOS</summary>

```sh
afplay signal/output/chord_narrative_full.wav
afplay pendulum/output/double_audio.wav
afplay lorenz/output/lorenz_audio.wav
afplay dynamical/output/sweep_audio.wav
afplay dynamical/output/iterate_audio.wav
afplay henon/output/henon_attractor.wav
afplay henon/output/henon_sweep.wav
afplay henon/output/henon_reverse.wav
afplay asteroids/output/asteroids_*.wav
afplay cellular/output/life_rpentomino_audio.wav
afplay quantum/output/qho_audio.wav
afplay qubit/output/qubit_gates.wav
afplay qubit/output/qubit_rabi.wav
afplay qubit/output/qubit_measurement.wav
afplay bell/output/bell_correlations.wav
afplay bell/output/bell_chsh.wav
afplay bell/output/bell_measurement.wav
afplay grover/output/grover_search.wav
afplay grover/output/grover_compare.wav
afplay grover/output/grover_geometry.wav
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
afplay mandelbrot/output/mandelbrot_mandelbrot.wav
afplay mandelbrot/output/mandelbrot_julia.wav
afplay mandelbrot/output/mandelbrot_zoom.wav
afplay thermo/output/distribution_audio.wav
afplay thermo/output/cooling_audio.wav
afplay quantum_statistics/output/quantum_statistics_spectrum.wav
afplay quantum_statistics/output/quantum_statistics_temperature.wav
afplay quantum_statistics/output/quantum_statistics_fermi_sea.wav
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
afplay compton/output/energy_audio.wav
afplay compton/output/discovery_audio.wav
afplay quantum_tunnelling/output/barrier_audio.wav
afplay quantum_tunnelling/output/sweep_audio.wav
afplay quantum_tunnelling/output/energy_audio.wav
afplay clt/output/sweep_audio.wav
afplay clt/output/compare_audio.wav
afplay clt/output/dice_audio.wav
afplay brownian/output/brownian_walk.wav
afplay brownian/output/brownian_ensemble.wav
afplay brownian/output/brownian_temperature.wav
```

</details>

<details><summary>Linux</summary>

```sh
aplay signal/output/chord_narrative_full.wav
aplay pendulum/output/double_audio.wav
aplay lorenz/output/lorenz_audio.wav
aplay dynamical/output/sweep_audio.wav
aplay dynamical/output/iterate_audio.wav
aplay henon/output/henon_attractor.wav
aplay henon/output/henon_sweep.wav
aplay henon/output/henon_reverse.wav
aplay asteroids/output/asteroids_*.wav
aplay cellular/output/life_rpentomino_audio.wav
aplay quantum/output/qho_audio.wav
aplay qubit/output/qubit_gates.wav
aplay qubit/output/qubit_rabi.wav
aplay qubit/output/qubit_measurement.wav
aplay bell/output/bell_correlations.wav
aplay bell/output/bell_chsh.wav
aplay bell/output/bell_measurement.wav
aplay grover/output/grover_search.wav
aplay grover/output/grover_compare.wav
aplay grover/output/grover_geometry.wav
aplay primes/output/ulam_audio.wav
aplay primes/output/gaps_audio.wav
aplay relativity/output/chirp.wav
aplay relativity/output/gw170817.wav
aplay relativity/output/geodesic.wav
aplay cosmology/output/cmb_spectrum_audio.wav
aplay waves/output/ripple_audio.wav
aplay waves/output/interference_audio.wav
aplay lagrange/output/l4_audio.wav
aplay lagrange/output/l1_audio.wav
aplay images/output/images_brightness_audio.wav
aplay mandelbrot/output/mandelbrot_mandelbrot.wav
aplay mandelbrot/output/mandelbrot_julia.wav
aplay mandelbrot/output/mandelbrot_zoom.wav
aplay thermo/output/distribution_audio.wav
aplay thermo/output/cooling_audio.wav
aplay quantum_statistics/output/quantum_statistics_spectrum.wav
aplay quantum_statistics/output/quantum_statistics_temperature.wav
aplay quantum_statistics/output/quantum_statistics_fermi_sea.wav
aplay montecarlo/output/sweep_audio.wav
aplay montecarlo/output/critical_audio.wav
aplay magnetic/output/mirror_audio.wav
aplay magnetic/output/cyclotron_audio.wav
aplay hydrogen/output/spectrum_audio.wav
aplay hydrogen/output/transitions_audio.wav
aplay bayes/output/coin_audio.wav
aplay bayes/output/model_audio.wav
aplay scattering/output/discovery_audio.wav
aplay resonance/output/galilean_audio.wav
aplay resonance/output/kirkwood_audio.wav
aplay fluid/output/karman_audio.wav
aplay fluid/output/strouhal_audio.wav
aplay blackbody/output/spectrum_audio.wav
aplay blackbody/output/temperature_audio.wav
aplay blackbody/output/star_audio.wav
aplay compton/output/scatter_audio.wav
aplay compton/output/sweep_audio.wav
aplay compton/output/energy_audio.wav
aplay compton/output/discovery_audio.wav
aplay quantum_tunnelling/output/barrier_audio.wav
aplay quantum_tunnelling/output/sweep_audio.wav
aplay quantum_tunnelling/output/energy_audio.wav
aplay clt/output/sweep_audio.wav
aplay clt/output/compare_audio.wav
aplay clt/output/dice_audio.wav
aplay brownian/output/brownian_walk.wav
aplay brownian/output/brownian_ensemble.wav
aplay brownian/output/brownian_temperature.wav
```

</details>

<details><summary>Windows PowerShell</summary>

```powershell
(New-Object Media.SoundPlayer "$PWD\signal\output\chord_narrative_full.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\pendulum\output\double_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\lorenz\output\lorenz_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\dynamical\output\sweep_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\dynamical\output\iterate_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\henon\output\henon_attractor.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\henon\output\henon_sweep.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\henon\output\henon_reverse.wav").PlaySync()
Get-ChildItem asteroids\output\asteroids_*.wav | ForEach-Object { (New-Object Media.SoundPlayer $_.FullName).PlaySync() }
(New-Object Media.SoundPlayer "$PWD\cellular\output\life_rpentomino_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\quantum\output\qho_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\qubit\output\qubit_gates.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\qubit\output\qubit_rabi.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\qubit\output\qubit_measurement.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\bell\output\bell_correlations.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\bell\output\bell_chsh.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\bell\output\bell_measurement.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\grover\output\grover_search.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\grover\output\grover_compare.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\grover\output\grover_geometry.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\primes\output\ulam_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\primes\output\gaps_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\relativity\output\chirp.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\relativity\output\gw170817.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\relativity\output\geodesic.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\cosmology\output\cmb_spectrum_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\waves\output\ripple_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\waves\output\interference_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\lagrange\output\l4_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\lagrange\output\l1_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\images\output\images_brightness_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\mandelbrot\output\mandelbrot_mandelbrot.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\mandelbrot\output\mandelbrot_julia.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\mandelbrot\output\mandelbrot_zoom.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\thermo\output\distribution_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\thermo\output\cooling_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\quantum_statistics\output\quantum_statistics_spectrum.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\quantum_statistics\output\quantum_statistics_temperature.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\quantum_statistics\output\quantum_statistics_fermi_sea.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\montecarlo\output\sweep_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\montecarlo\output\critical_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\magnetic\output\mirror_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\magnetic\output\cyclotron_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\hydrogen\output\spectrum_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\hydrogen\output\transitions_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\bayes\output\coin_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\bayes\output\model_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\scattering\output\discovery_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\resonance\output\galilean_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\resonance\output\kirkwood_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\fluid\output\karman_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\fluid\output\strouhal_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\blackbody\output\spectrum_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\blackbody\output\temperature_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\blackbody\output\star_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\compton\output\scatter_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\compton\output\sweep_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\compton\output\energy_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\compton\output\discovery_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\quantum_tunnelling\output\barrier_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\quantum_tunnelling\output\sweep_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\quantum_tunnelling\output\energy_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\clt\output\sweep_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\clt\output\compare_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\clt\output\dice_audio.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\brownian\output\brownian_walk.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\brownian\output\brownian_ensemble.wav").PlaySync()
(New-Object Media.SoundPlayer "$PWD\brownian\output\brownian_temperature.wav").PlaySync()
```

</details>

<details><summary>Windows Command Prompt (cmd)</summary>

```bat
start "" "signal\output\chord_narrative_full.wav"
start "" "pendulum\output\double_audio.wav"
start "" "lorenz\output\lorenz_audio.wav"
start "" "dynamical\output\sweep_audio.wav"
start "" "dynamical\output\iterate_audio.wav"
start "" "henon\output\henon_attractor.wav"
start "" "henon\output\henon_sweep.wav"
start "" "henon\output\henon_reverse.wav"
for %f in (asteroids\output\asteroids_*.wav) do start "" "%f"
start "" "cellular\output\life_rpentomino_audio.wav"
start "" "quantum\output\qho_audio.wav"
start "" "qubit\output\qubit_gates.wav"
start "" "qubit\output\qubit_rabi.wav"
start "" "qubit\output\qubit_measurement.wav"
start "" "bell\output\bell_correlations.wav"
start "" "bell\output\bell_chsh.wav"
start "" "bell\output\bell_measurement.wav"
start "" "grover\output\grover_search.wav"
start "" "grover\output\grover_compare.wav"
start "" "grover\output\grover_geometry.wav"
start "" "primes\output\ulam_audio.wav"
start "" "primes\output\gaps_audio.wav"
start "" "relativity\output\chirp.wav"
start "" "relativity\output\gw170817.wav"
start "" "relativity\output\geodesic.wav"
start "" "cosmology\output\cmb_spectrum_audio.wav"
start "" "waves\output\ripple_audio.wav"
start "" "waves\output\interference_audio.wav"
start "" "lagrange\output\l4_audio.wav"
start "" "lagrange\output\l1_audio.wav"
start "" "images\output\images_brightness_audio.wav"
start "" "mandelbrot\output\mandelbrot_mandelbrot.wav"
start "" "mandelbrot\output\mandelbrot_julia.wav"
start "" "mandelbrot\output\mandelbrot_zoom.wav"
start "" "thermo\output\distribution_audio.wav"
start "" "thermo\output\cooling_audio.wav"
start "" "quantum_statistics\output\quantum_statistics_spectrum.wav"
start "" "quantum_statistics\output\quantum_statistics_temperature.wav"
start "" "quantum_statistics\output\quantum_statistics_fermi_sea.wav"
start "" "montecarlo\output\sweep_audio.wav"
start "" "montecarlo\output\critical_audio.wav"
start "" "magnetic\output\mirror_audio.wav"
start "" "magnetic\output\cyclotron_audio.wav"
start "" "hydrogen\output\spectrum_audio.wav"
start "" "hydrogen\output\transitions_audio.wav"
start "" "bayes\output\coin_audio.wav"
start "" "bayes\output\model_audio.wav"
start "" "scattering\output\discovery_audio.wav"
start "" "resonance\output\galilean_audio.wav"
start "" "resonance\output\kirkwood_audio.wav"
start "" "fluid\output\karman_audio.wav"
start "" "fluid\output\strouhal_audio.wav"
start "" "blackbody\output\spectrum_audio.wav"
start "" "blackbody\output\temperature_audio.wav"
start "" "blackbody\output\star_audio.wav"
start "" "compton\output\scatter_audio.wav"
start "" "compton\output\sweep_audio.wav"
start "" "compton\output\energy_audio.wav"
start "" "compton\output\discovery_audio.wav"
start "" "quantum_tunnelling\output\barrier_audio.wav"
start "" "quantum_tunnelling\output\sweep_audio.wav"
start "" "quantum_tunnelling\output\energy_audio.wav"
start "" "clt\output\sweep_audio.wav"
start "" "clt\output\compare_audio.wav"
start "" "clt\output\dice_audio.wav"
start "" "brownian\output\brownian_walk.wav"
start "" "brownian\output\brownian_ensemble.wav"
start "" "brownian\output\brownian_temperature.wav"
```

</details>

See [RELEASE_NOTES_v1.6.0.md](RELEASE_NOTES_v1.6.0.md) for what changed in this release, and [docs/archive/RELEASE_NOTES_v1.5.1.md](docs/archive/RELEASE_NOTES_v1.5.1.md) for full app descriptions, physics notes, and listening guides.

---

## Demo

Run all thirty-two apps with their most interesting presets and collect outputs into `demo/`:

```sh
wolframscript -file demo.wl
```

With spoken announcements:
```sh
# macOS / Linux
STEM_SPEAK=1 wolframscript -file demo.wl

# Windows PowerShell
$env:STEM_SPEAK = "1"; wolframscript -file demo.wl

:: Windows Command Prompt (cmd)
set STEM_SPEAK=1
wolframscript -file demo.wl
```

With NASA asteroid data (requires API key):
```sh
# macOS / Linux
NASA_API_KEY=$NASA_API_KEY wolframscript -file demo.wl

# Windows PowerShell
$env:NASA_API_KEY = "your_key_here"; wolframscript -file demo.wl

:: Windows Command Prompt (cmd)
set NASA_API_KEY=your_key_here
wolframscript -file demo.wl
```

Check whether a previous demo run completed successfully, or run a short
version (four apps) to confirm the setup works:
```sh
# macOS / Linux
wolframscript -file demo.wl -- --check-only
wolframscript -file demo.wl -- --quick

# Windows PowerShell
wolframscript -file demo.wl '--' --check-only
wolframscript -file demo.wl '--' --quick

:: Windows Command Prompt (cmd)
wolframscript -file demo.wl -- --check-only
wolframscript -file demo.wl -- --quick
```

Outputs are collected in `demo/` with a written report at `demo/demo-report.md`. A full run takes approximately five to six minutes (33/33 runs — 32 unique apps, `dynamical` runs twice — including live asteroid data).


### Checking an installation

`tools/smoke_test.wl` runs every app's default mode and then `demo.wl`, all
in one kernel, and writes a plain-text report
`smoke_test_<SystemID>_<date>_<HHMM>.txt` in the repository root: an environment
block (Wolfram version, encodings, which speech and network tools work),
then one line per app with its status, timings, WAV loudness and length,
GIF length and pixel size, and any Wolfram messages. It also runs the
pendulum frame-clipping check, so Python is not needed. It exits with code
0 only if every app wrote a WAV and every GIF export succeeded; an app whose
GIF failed is listed as `GIF FAILED` with its WAV measured. `--quick` runs six
apps and `demo.wl --quick` (about five minutes); without it the run takes
about thirty minutes on the Mac. `--demo-timeout-seconds=N` changes the time
limit for `demo.wl` (default 3600 s), for slower machines; if the limit is
reached, the report lists the demo steps that finished and the one running.
Each app's full console output is kept in `smoke_logs_<SystemID>_<date>_<HHMM>/`
next to the report, written line by line so it survives a kernel crash;
`--resume` continues an interrupted run, keeping the apps already in the
report. The environment block records total and available memory, free
space and file system of the output volume and `$TemporaryDirectory`, and on
Linux the kernel's overcommit and core-dump settings. The time in the
report's name (`_<HHMM>`) keeps two runs on one day apart; `--resume` picks
the newest report.

On a machine you are not watching, run the smoke test through the wrapper,
`tools/smoke_test.sh` (macOS, Linux) or `tools\smoke_test.ps1` (Windows; not
yet run there). It passes its options on, writes the console to
`smoke_console_<...>.txt`, rewrites `smoke_heartbeat_<...>.txt` every 10 s
with the time and the app being run, and when wolframscript ends appends one
line to the report, for example "The smoke test process ended at 01:52 with
exit code 139 (SIGSEGV, segmentation fault) after 2103 s." (only the end
time when the report already has its Summary line). A run that stops for
any reason, a kernel crash or a machine that went to sleep, then shows when
and where in the report and the heartbeat file.

If a GIF export fails, the app says so in one `[GIF FAILED]` sentence, still
writes its WAV, and exits with code 2. Setting `STEM_GIF_DIAG=1` prints the
conditions of each export (free disk space, memory, frame-list size, open-file
limit) and retries a failed export once, for diagnosis.

```sh
# macOS / Linux
wolframscript -file tools/smoke_test.wl
wolframscript -file tools/smoke_test.wl -- --quick
tools/smoke_test.sh            # the same, through the wrapper (unattended runs)
tools/smoke_test.sh --quick

# Windows PowerShell
wolframscript -file tools\smoke_test.wl
wolframscript -file tools\smoke_test.wl '--' --quick
powershell -ExecutionPolicy Bypass -File tools\smoke_test.ps1 --quick   # wrapper

:: Windows Command Prompt (cmd)
wolframscript -file tools\smoke_test.wl
wolframscript -file tools\smoke_test.wl -- --quick
```

`pendulum/tests/verify_animation_frames.py` is the original, optional Python
version of the frame-clipping check. It needs Python 3 with numpy and Pillow:

```sh
# macOS
python3 -m pip install numpy pillow
python3 pendulum/tests/verify_animation_frames.py

# Linux (Debian/Ubuntu packages, or pip as on macOS)
sudo apt install python3-numpy python3-pil
python3 pendulum/tests/verify_animation_frames.py

# Windows PowerShell or cmd (the py launcher comes with Python from python.org)
py -m pip install numpy pillow
py pendulum\tests\verify_animation_frames.py
```

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

### henon

Sonifies the Hénon map, a two-dimensional, exactly invertible chaotic
attractor built by Michel Hénon in 1976 as the simplest system that still
captures the essential dynamics of a Poincaré section through the Lorenz
attractor — a genuine, concrete link to `lorenz/` already in this codebase.
`attractor` mode (default) settles onto the canonical strange attractor
(a=1.4, b=0.3) and sonifies it continuously, reusing `lorenz/`'s own
trajectory technique: pan tracks x, pitch tracks y, and accent tones mark
each turning point. `sweep` mode traverses a from 0.2 to 1.4, reusing
`dynamical/`'s discrete note-per-iterate idiom so the period-doubling
route to chaos is directly countable — one note becomes two, then four,
then eight, before dissolving into chaos, with a surprising period-seven
window near a≈1.227. `reverse` mode plays a short forward segment, replays
it exactly reversed, then proves the map's invertibility directly: the
last several points recovered by applying the exact inverse-map formula,
confirmed against the already-known preceding values. Four correctness
checks run on every invocation, including verifying the map's constant
Jacobian determinant (exactly -b, everywhere on the plane) and that the
two Lyapunov exponents sum to log(b) exactly.
See [`henon/README.md`](henon/README.md).

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

### mandelbrot

Sonifies the Mandelbrot set, its Julia-set counterparts, and boundary
self-similarity at increasing magnification, via `images/`'s own
Hilbert-curve traversal and brightness-to-frequency technique — iteration
count standing in for brightness. The escape radius (the "radius 2" every
popular account cites) is derived here, not received wisdom: if `|z|>2`
and `|z|>=|c|` within the standard `|c|<=2` region, the sequence is proven
strictly increasing thereafter, verified directly against six test points.
`mandelbrot` mode (default) renders the classic set over a window verified
to comfortably contain the whole thing. `julia` mode fixes `c` and sweeps
the starting point instead — the deep connection made concrete: `c` inside
the Mandelbrot set gives a connected Julia set, outside gives a
disconnected one. The default Julia `c=-0.123+0.745i` (the "Douady rabbit")
was chosen only after verification revealed the far more commonly-cited
`c=-0.7+0.27015i` is actually *outside* the Mandelbrot set (it escapes at
exactly iteration 96, regardless of iteration budget) — the wrong choice
for a "connected" default example, a genuine correction caught by this
session's own verify-before-using discipline. `zoom` mode renders four
successively deeper magnifications of a verified-rich "seahorse valley"
boundary point, making self-similarity audible as the boundary's chaotic
pitch variation sounding equally rich at every scale. The main cardioid's
exact boundary (`c(theta)=Exp[I theta]/2-Exp[2 I theta]/4`) is also
derived from the fixed-point stability condition, not cited, and verified
by a correctness check quantifying this app's own headline claim: the
boundary's mean pitch-jump between neighbouring pixels is `5.4x` the deep
interior's and `57.7x` the far exterior's — measured, not assumed.
See [`mandelbrot/README.md`](mandelbrot/README.md).

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

### quantum_statistics

Sonifies the three occupation-number distributions of statistical
mechanics — Bose-Einstein, Fermi-Dirac, and Maxwell-Boltzmann — and the
exact sense in which `thermo/`'s classical picture is a special case of
the deeper quantum one: an algebraic identity, not just an asymptote,
shows the fractional deviation of each quantum distribution from the
classical limit equals the occupation number itself. `spectrum` mode
(default) sonifies all three simultaneously at a fixed temperature as
three distinctly-panned, distinctly-registered voices — reusing
`thermo/`'s additive spectral-envelope technique three times over, so
the ear can hear directly where the three pictures agree and where
they part ways. `temperature` mode sweeps temperature at a fixed
energy; direct calculation (not the commonly assumed "cold=quantum"
intuition, verified not to transfer to this app's `mu=0` convention)
shows the three distributions converge at LOW temperature and Bose-
Einstein diverges at HIGH temperature, exactly the reverse of the
naive expectation, documented as a verified correction rather than
silently implemented backwards. `fermi_sea` mode sonifies Fermi-Dirac
alone, sweeping from a sharp T→0 step function to a smoothed, blurred
one, using a genuine positive Fermi energy (not `mu=0`) so the complete
step — both the filled and empty sides — is audible. Four correctness
checks, all exact: the Fermi-Dirac bound (`n_FD<1`, a direct algebraic
consequence of the formula), the T→0 step's transition width scaling
*exactly* linearly with `kT`, and Bose-Einstein's divergence together
with its domain guard both confirmed to actually engage, not merely
assumed present.
See [`quantum_statistics/README.md`](quantum_statistics/README.md).

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

### quantum_tunnelling

Sonifies quantum tunnelling — a particle crossing a potential barrier
it classically has zero chance of crossing, the effect behind alpha
decay (Gamow, 1928), the scanning tunnelling microscope (Binnig &
Rohrer, 1981, Nobel Prize 1986), and the tunnel diode. `barrier` mode
plays a single event as a narrated sequence: an incoming tone, a
marker click, then a reflected tone and a transmitted tone sounding
*simultaneously*, loudness split by probability — both genuinely
happen in the same measurement statistics, not a coin flip on any one
run. Three presets span twelve orders of magnitude in energy, from a
textbook electron (transmission ~2.35%) through a scanning-tunnelling-
microscope gap (~7.5×10⁻⁶) to an illustrative alpha-decay barrier
(~7×10⁻¹⁰) — explicitly not a quantitative half-life calculation, just
a demonstration of why the real effect is so improbable per attempt
and yet still eventually happens. `sweep` mode fades a tone toward
silence as barrier width grows, tunnelling's exponential sensitivity
made audible; `energy` mode sweeps particle energy across the barrier
height and into a genuinely surprising regime: above the barrier,
transmission oscillates, reaching perfect, total transparency at
specific resonant energies — the identical standing-wave condition
that quantizes `quantum/`'s particle-in-a-box. See
[`quantum_tunnelling/README.md`](quantum_tunnelling/README.md).

### clt

Sonifies the Central Limit Theorem — the most accessible statistics
app in this project, no physics background required. `sweep` mode
sweeps N from 1 to 30 for one source distribution (`uniform`,
`exponential`, or a configurable-bias `bernoulli` coin, connecting to
`bayes/`'s own coin theme) and sonifies the raw sample mean as a
spectral envelope — `thermo/`'s and `bayes/`'s additive-synthesis
technique, reused directly — audibly both narrowing (an exact,
non-asymptotic fact: `Var(mean)=sigma^2/N`) and smoothing into a
symmetric bell shape (the actual, asymptotic Central Limit Theorem)
regardless of how lopsided the N=1 starting shape looked. `compare`
mode instead standardizes away each source's own scale and sweeps two
deliberately different distributions — flat `uniform` left, one-sided
`exponential` right — simultaneously in binaural stereo, so a listener
hears two completely different sounds at N=1 converge toward the
identical shape by N=30. `dice` mode sonifies the most recognisable
illustration of them all: the sum (not mean) of up to ten fair
six-sided dice, a flat, jagged six-outcome sound smoothing into an
unmistakable bell shape purely from summing more dice — honestly framed
around shape smoothing rather than narrowing, since a sum's spread
actually grows with N. See [`clt/README.md`](clt/README.md).

### brownian

Sonifies Brownian motion — the random walk a microscopic particle
follows under countless collisions with surrounding fluid molecules,
first observed by Robert Brown (1827) and explained by Einstein (1905)
as direct evidence for the physical reality of atoms, confirmed
quantitatively by Jean Perrin (1908-1909, Nobel Prize 1926). `walk` mode
(default) sonifies a single random walk continuously — the same
trajectory pipeline `lorenz/` and `henon/`'s `attractor` mode use, but
with volume tracking displacement from the origin rather than speed, a
deliberate deviation since local jitter says nothing about diffusion
specifically. `ensemble` mode tracks 150 independent walkers and
sonifies their averaged root-mean-square displacement as a single rising
tone whose climb visibly slows over time — the audible signature that
displacement grows as the square root of time, not linearly, unlike
ballistic motion. `temperature` mode sweeps 275K-350K, computing the
diffusion coefficient via the Stokes-Einstein relation and scaling a
representative walk's jiggle to it — a real, correctly-directioned, but
honestly modest effect within water's actual liquid range. This random
walk is also a direct physical embodiment of `clt/`'s own Central Limit
Theorem setup: a running sum of independent random steps, here in real
2D space rather than an abstract sample mean. See
[`brownian/README.md`](brownian/README.md).

### qubit

Sonifies a single qubit — its Bloch-sphere representation, gate
operations, Rabi oscillation, and measurement — the foundational app of
a small quantum-computing batch. `gates` mode (default) applies a
configurable sequence of gates (Pauli X/Y/Z, Hadamard, phase gates S/T,
and parametrized rotations, every one verified unitary) to an initial
state, sonifying the Bloch vector's path as a genuine continuous
rotation — reusing `lorenz/`'s and `henon/`'s `attractor` trajectory
pipeline directly, since the Bloch vector's own x/y/z coordinates map
onto the trajectory's spatial columns with no invented mapping needed.
`rabi` mode sonifies the closed-form Rabi oscillation `P(1)(t) =
sin(Omega t/2)^2` — derived from the Schrodinger equation and verified
two independent ways — as a continuously bending pitch, directly
connecting to `quantum/`'s own coherent-state sonification. `measurement`
mode simulates thousands of repeated Born-rule measurements and sonifies
the running empirical frequency converging toward the true probability —
the quantum analogue of `bayes/coin`'s flip-by-flip belief update. See
[`qubit/README.md`](qubit/README.md).

### bell

Sonifies two entangled qubits — Bell correlations, the CHSH inequality,
and repeated Bell-state measurement — the second app in this project's
quantum-computing batch, built directly on `qubit/`'s Bloch-sphere and
gate machinery. Tells the EPR (1935) -> Bell's theorem (1964) ->
Aspect's experiments (1980s) -> 2022 Nobel Prize story explicitly.
`correlations` mode (default) sweeps the angle difference and sonifies
the real quantum correlation `E(a,b)=Cos[a-b]` (derived directly from
the Bell state, verified two independent ways) against a genuinely
derived local hidden-variable prediction, binaural — the same
classical-vs-quantum idiom `compton/discovery` and
`scattering/discovery` already establish. `chsh` mode computes the
actual CHSH value at angles found by numerical optimisation (confirmed
symbolically to equal `2*Sqrt[2]`, the Tsirelson bound, not assumed
from memory) and presents it as a build-up-then-verdict gauge, audible
as the gap between a classical-bound reference tone and the real
measured value. `measurement` mode simulates thousands of paired
measurements sampled from the true joint quantum distribution, each
side individually unpredictable 50/50, converging to an unmistakable
correlation. All four correctness checks are exact or constructive —
notably, the classical `|S|<=2` bound is proved by exhaustively
enumerating all 16 possible local deterministic strategies, not merely
asserted. See [`bell/README.md`](bell/README.md).

### grover

Sonifies Grover's search algorithm — the third and final app in this
project's quantum-computing batch, demonstrating the other half of why
quantum computing matters beyond entanglement's weirdness: a genuine,
provable computational speedup. `search` mode (default) runs Grover
iterations, sonifying `P(marked)=Sin[(2k+1)*theta]^2` as a discrete
note per iteration, peaking at a bright accent (the true optimal
iteration, `k=Round[Pi/(4*theta)-1/2]`) and audibly falling again if
iteration continues past it — over-rotating genuinely makes the search
worse, a real, counter-intuitive fact this mode makes directly
audible. `compare` mode is a binaural race: classical average-case
linear search (`N/2` queries) on the left, Grover's optimal count on
the right, both starting together — the literal difference in how long
each channel takes IS the speedup, no formula required, the same
classical-vs-quantum lineage as `compton/discovery` and
`bell/correlations`. `geometry` mode sonifies the algorithm's exact
mechanism directly: each iteration is provably a rotation by exactly
`2*theta` within a 2D subspace (verified via explicit matrix
construction, not merely cited), heard as a continuously rotating
pan/pitch. All four correctness checks are exact, including a
genuinely discovered edge case documented rather than glossed over: at
very small N, a naive search for "the optimal iteration count" can
find a later, numerically-higher peak that is not the intended
answer, since more queries is never actually better even when a
coincidence briefly suggests otherwise. See
[`grover/README.md`](grover/README.md).

---

## Config system

Every project uses a four-layer configuration system:

```
$HardcodedDefaults  →  config/config.json  →  <app>/config.json  →  CLI --key=value
```

Inspect the fully merged config for any project:

```sh
# macOS / Linux
wolframscript -file pendulum/main.wl -- --config-dump
wolframscript -file cellular/main.wl -- --config-dump > cellular_config.json

# Windows PowerShell
wolframscript -file pendulum\main.wl '--' --config-dump

:: Windows Command Prompt (cmd)
wolframscript -file pendulum\main.wl -- --config-dump
```

`--config-dump` already prints indented JSON, so no formatter is needed. If
you want Python to validate it anyway, the command is `python3 -m json.tool`
on macOS and Linux and `py -m json.tool` on Windows.

Override any parameter at runtime using dot-separated key paths:

```sh
# macOS / Linux
wolframscript -file pendulum/main.wl -- --simulation.mode=double
wolframscript -file lorenz/main.wl -- --simulation.mode=rossler
wolframscript -file cellular/main.wl -- --simulation.life.starting_pattern=gliderlgun
wolframscript -file signal/main.wl -- --simulation.chord.noise_level=0.8
wolframscript -file asteroids/main.wl -- --simulation.days_ahead=14
wolframscript -file quantum/main.wl -- --simulation.qho.alpha=3.0
wolframscript -file relativity/main.wl -- --simulation.chirp.mass1_solar 50

# Windows PowerShell
wolframscript -file pendulum\main.wl '--' --simulation.mode=double
wolframscript -file lorenz\main.wl '--' --simulation.mode=rossler
wolframscript -file cellular\main.wl '--' --simulation.life.starting_pattern=gliderlgun
wolframscript -file signal\main.wl '--' --simulation.chord.noise_level=0.8
wolframscript -file asteroids\main.wl '--' --simulation.days_ahead=14
wolframscript -file quantum\main.wl '--' --simulation.qho.alpha=3.0
wolframscript -file relativity\main.wl '--' --simulation.chirp.mass1_solar 50

:: Windows Command Prompt (cmd)
wolframscript -file pendulum\main.wl -- --simulation.mode=double
wolframscript -file lorenz\main.wl -- --simulation.mode=rossler
wolframscript -file cellular\main.wl -- --simulation.life.starting_pattern=gliderlgun
wolframscript -file signal\main.wl -- --simulation.chord.noise_level=0.8
wolframscript -file asteroids\main.wl -- --simulation.days_ahead=14
wolframscript -file quantum\main.wl -- --simulation.qho.alpha=3.0
wolframscript -file relativity\main.wl -- --simulation.chirp.mass1_solar 50
```

See [`docs/APPS.md`](docs/APPS.md) for a full listing of each app's config keys.

---

## stem-core

All thirty-two projects load `stem-core` as a shared library. It provides:

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
$env:STEM_SPEAK = "1"; wolframscript -file pendulum\main.wl

:: Windows Command Prompt (cmd)
set STEM_SPEAK=1
wolframscript -file pendulum\main.wl
```

Platform TTS: macOS uses `say`, Linux uses `espeak-ng` (install with
`sudo apt install espeak-ng`), Windows uses PowerShell with the built-in
System.Speech. If the tool is unavailable the console announcement is only
printed. The narration inside the WAV files needs
the same tool (see Text-to-speech under Installation).

The `signal` app's `{mode}_narrative_full.wav` is the most accessible single
output — it chains spoken text with the clean, noisy, and recovered signals so
the entire Fourier demonstration can be followed by listening alone.

For the complete VoiceOver + wolframscript workflow see
[`docs/voiceover-wolframscript-guide.md`](docs/voiceover-wolframscript-guide.md)
and [`stem-core/ACCESSIBILITY.md`](stem-core/ACCESSIBILITY.md).

---

## About MINT Access

MINT Access is a Swiss organisation promoting accessible STEM education. Website: [mintaccess.ch](https://www.mintaccess.ch/) (German)

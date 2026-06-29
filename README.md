# stem

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](RELEASE_NOTES_v1.0.0.md)
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
  asteroids/        NASA near-Earth asteroid tracker (live API data)
  cellular/         Conway's Game of Life and Wolfram Rule 110
  signal/           Fourier analysis demonstration (chord, sweep, AM)
  quantum/          Quantum mechanics (coherent state QHO, particle-in-a-box)
  primes/           Prime number patterns (Ulam spiral, prime gap rhythm)
  relativity/       General relativity (chirp: PN binary inspiral; geodesic: Schwarzschild orbits)
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
```

Each project writes outputs into its own directory:

| Project | Output dir | File types |
|---------|-----------|------------|
| all eight apps | `output/` | CSV, GIF, WAV (+ PNG for signal, quantum, primes, relativity) |

Play audio:

```sh
# macOS
afplay signal/output/chord_narrative_full.wav
afplay pendulum/output/double_audio.wav
afplay lorenz/output/lorenz_audio.wav
afplay asteroids/output/asteroids_*.wav
afplay cellular/output/life_rpentomino_audio.wav
afplay quantum/output/qho_audio.wav
afplay primes/output/ulam_audio.wav
afplay primes/output/gaps_audio.wav
afplay relativity/output/chirp.wav
afplay relativity/output/gw170817.wav
afplay relativity/output/geodesic.wav

# Linux — replace afplay with aplay
aplay signal/output/chord_narrative_full.wav
aplay pendulum/output/double_audio.wav

# Windows PowerShell — replace afplay with Start-Process wmplayer
Start-Process wmplayer signal\output\chord_narrative_full.wav
Start-Process wmplayer pendulum\output\double_audio.wav
```

See [RELEASE_NOTES_v1.0.0.md](RELEASE_NOTES_v1.0.0.md) for full app descriptions, physics notes, and listening guides.

---

## Demo

Run all eight apps with their most interesting presets and collect outputs into `demo/`:

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

Outputs are collected in `demo/` with a written report at `demo/demo-report.md`.

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

All eight projects load `stem-core` as a shared library. It provides:

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

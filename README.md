# stem

A monorepo of Wolfram Language physics simulations and data sonification projects,
each producing CSV data, an animated GIF, and a musical WAV file — all from the
terminal via `wolframscript`.

---

## Repository layout

```
stem/
  stem-core/        Shared library: pitch mapping, PCM synthesis, file export
  pendulum/         Simple pendulum ODE simulation
  lorenz/           Lorenz strange attractor simulation
  asteroids/        NASA near-Earth asteroid tracker (live API data)
```

---

## Prerequisites

- **Wolfram Engine** (free) or **Mathematica** 13+
- `wolframscript` on your PATH

```sh
wolframscript -version
```

---

## Quick start

Run any project from the `stem/` root:

```sh
wolframscript -file pendulum/main.wl
wolframscript -file lorenz/main.wl
wolframscript -file asteroids/main.wl
```

Each project writes its outputs into its own `data/` directory:

| File | Description |
|---|---|
| `data/*.csv` | Simulation or measurement data |
| `data/*.gif` | Looping animated visualisation |
| `data/*.wav` | Musical sonification |

Play audio on macOS:

```sh
afplay pendulum/data/pendulum_audio.wav
afplay lorenz/data/lorenz_audio.wav
afplay asteroids/data/asteroids_*.wav
```

---

## Projects

### pendulum

Solves the nonlinear pendulum ODE with `NDSolve`. Maps the swing angle to an
A minor pentatonic scale — each half-swing becomes one note, volume set by
angular velocity. See [`pendulum/README.md`](pendulum/README.md).

### lorenz

Simulates the Lorenz strange attractor. Notes are triggered at each local
extremum of x(t); pitch tracks which wing of the butterfly the trajectory is
on. Includes a dual-trajectory animation for visualising the butterfly effect.
See [`lorenz/README.md`](lorenz/README.md).

### asteroids

Fetches live close-approach data from NASA's NeoWs API. Each asteroid becomes
one note — pitch reflects miss distance, timbre distinguishes hazardous from
safe. See [`asteroids/README.md`](asteroids/README.md).

---

## stem-core

All three projects load `stem-core` as a shared library before running. It
provides:

- **`ScaleLookup`** — maps a data value to a musical frequency
- **`StemSynthNote`** — additive-sine PCM synthesis with exponential decay
- **`NormalizeBuffer`** / **`ExportAudioBuffer`** — headless-safe WAV export
- **`ExportCSV`** / **`ExportGIF`** — file export helpers

See [`stem-core/README.md`](stem-core/README.md) for the full API and
[`stem-core/AGENTS.md`](stem-core/AGENTS.md) for parameter details.

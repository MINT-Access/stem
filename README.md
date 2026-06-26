# stem

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

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
  docs/             Workflow guides (VoiceOver, wolframscript usage)
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
wolframscript -file asteroids/main.wl                                    # last 7 days
wolframscript -file asteroids/main.wl -- 2026-01-01 2026-12-31           # full year
wolframscript -file asteroids/main.wl -- 2026-01-01 2026-06-25 Phrygian  # date range + scale
```

The asteroids project accepts an optional date range and scale: `[-- YYYY-MM-DD YYYY-MM-DD [Scale]]`.
Ranges longer than 7 days are split into multiple API requests automatically.
Valid scales: `MinorPentatonic` `MajorPentatonic` `Major` `Minor` `WholeTone` `Phrygian`

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
angular velocity. The GIF shows the bob in side-on view with a colour trail
that shifts from blue (centre) to red-violet (maximum swing).
See [`pendulum/README.md`](pendulum/README.md).

### lorenz

Simulates the Lorenz strange attractor. Notes are triggered at each local
extremum of x(t); pitch tracks which wing of the butterfly the trajectory is
on. The GIF renders the growing trajectory in x-z projection with a
blue→cyan→orange→red colour gradient; `ExportDualAnimation` shows two
near-identical trajectories diverging apart.
See [`lorenz/README.md`](lorenz/README.md).

### asteroids

Fetches live close-approach data from NASA's NeoWs API. Each asteroid becomes
one note — pitch reflects miss distance, timbre distinguishes hazardous from
safe. The GIF shows a top-down solar system view with asteroids revealed
farthest-to-closest, coloured cyan (safe) or red (hazardous).
See [`asteroids/README.md`](asteroids/README.md).

---

## stem-core

All three projects load `stem-core` as a shared library before running. It
provides:

- **`ScaleLookup`** — maps a data value to a musical frequency
- **`StemSynthNote`** — additive-sine PCM synthesis with exponential decay
- **`NormalizeBuffer`** / **`ExportAudioBuffer`** — headless-safe WAV export
- **`ExportCSV`** / **`ExportGIF`** — file export helpers
- **`STEMHeading`** / **`STEMPrintN`** / **`STEMSay`** — screen-reader-friendly console output

See [`stem-core/README.md`](stem-core/README.md) for the full API and
[`stem-core/AGENTS.md`](stem-core/AGENTS.md) for parameter details.

---

## Accessibility

All projects run fully headlessly and write plain WAV files playable with
`afplay`. A built-in accessibility layer formats every console output line as a
self-contained announcement so VoiceOver reads it cleanly without splitting
numbers across lines.

To enable spoken announcements via the macOS `say` command alongside normal
printed output, set `STEM_SPEAK=1` before running:

```sh
STEM_SPEAK=1 wolframscript -file pendulum/main.wl
```

For the complete VoiceOver + wolframscript workflow — Terminal setup, navigation
shortcuts, and the full accessibility API — see
[`docs/voiceover-wolframscript-guide.md`](docs/voiceover-wolframscript-guide.md).

---

## About MINT Access

MINT Access is a Swiss organisation promoting accessible STEM education. Website: [mintaccess.ch](https://www.mintaccess.ch/) (German)

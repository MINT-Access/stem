# Lorenz Attractor

A Wolfram Language simulation of the Lorenz strange attractor, runnable
entirely from the terminal via `wolframscript`. Produces trajectory data,
an animated GIF visualisation, and a musical audio sonification.

## The mathematics

The Lorenz system (Lorenz, 1963) is a set of three coupled ODEs:

    x'(t) = sigma * (y - x)
    y'(t) = x * (rho - z) - y
    z'(t) = x * y - beta * z

With classic parameters sigma=10, rho=28, beta=8/3, the solution never
repeats and never escapes — it forms a strange attractor shaped like a
butterfly. Two trajectories starting arbitrarily close will eventually
diverge completely: this is the "butterfly effect".

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`

## Usage

```bash
# Full run: CSV + GIF + WAV
wolframscript -file main.wl

# Experiment with presets
wolframscript -file experiment.wl

# Tests
wolframscript -file tests/test_model.wl

# Play sonification (macOS)
afplay data/lorenz_audio.wav
```

## Outputs

| File                              | Description                          |
|-----------------------------------|--------------------------------------|
| data/lorenz_trajectory.csv        | t, x, y, z, speed at each step      |
| data/lorenz_animation.gif         | Animated butterfly attractor (x-z)   |
| data/lorenz_audio.wav             | Musical sonification of x(t)         |

## Sonification

| Parameter | Design |
|---|---|
| Trigger | Each local extremum of x(t) — one note per peak or trough |
| Pitch | x-value → minor pentatonic, root middle C (261.63 Hz) |
| Volume | Proportional to \|x\| at each extremum |
| Timbre | Additive sine (3 harmonics: 1.0, 0.35, 0.12), exponential decay |

The two-wing structure of the attractor maps naturally to pitch space: the
positive wing tends toward higher notes, the negative wing toward lower ones,
and the chaotic switching between wings produces the characteristic unpredictable
melody.

To change scale, edit the `"Scale"` option in `main.wl`:

```wolfram
ExportSonification[solution, outWAV, "Scale" -> "WholeTone"]
```

Available scales: `MinorPentatonic`, `MajorPentatonic`, `Major`, `Minor`,
`WholeTone`, `Phrygian`. To transpose, edit the `rootHz` argument to
`ScaleLookup` in `src/sonify.wl`.

## Experiment presets (experiment.wl)

| Label      | What it shows                                    |
|------------|--------------------------------------------------|
| classic    | Standard attractor, 40 s                         |
| butterfly  | Two near-identical trajectories diverging apart  |
| stable     | rho=24, below chaos — spirals to fixed point     |
| wild       | rho=99.96, different chaotic regime              |
| slow       | sigma=4, slower mixing dynamics                  |

## Project structure

    lorenz/
    ├── main.wl              Entry point
    ├── experiment.wl        Named parameter presets
    ├── src/
    │   ├── model.wl         Lorenz ODE, pair solver, divergence
    │   ├── output.wl        CSV export and console summary
    │   ├── animate.wl       GIF animation (single + dual)
    │   └── sonify.wl        Musical WAV sonification
    ├── tests/
    │   └── test_model.wl    Unit tests
    ├── data/                Output directory (not committed)
    ├── AGENTS.md            Guidance for Claude Code
    └── README.md

## Console output

`main.wl` prints one complete line per event so VoiceOver reads each chunk
as a self-contained announcement. Headings use `STEMHeading`; the step count
in `PrintSummary` uses `STEMPrintN`; the x/y/z range lines carry two values
each and remain as bare `Print`; export confirmations use `STEMDescribeCSV`
(1 row per step, 5 columns), `STEMDescribeGIF` (150 frames at 30 fps), and
`STEMDescribeWAV` (duration from `params["TimeEnd"]`); the final line uses
`STEMSay`.

To also hear a spoken announcement when the run finishes:

```sh
wolframscript -e '$STEMSpeakEnabled = True' -file main.wl
```

See [`docs/voiceover-wolframscript-guide.md`](../docs/voiceover-wolframscript-guide.md)
for the full VoiceOver + wolframscript workflow.

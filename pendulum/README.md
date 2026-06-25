# Pendulum

A pendulum physics simulation written in Wolfram Language, runnable entirely
from the terminal via `wolframscript`. Produces CSV data, an animated GIF,
and a musical WAV sonification.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`

## Quick start

```bash
# Full run: CSV + GIF + WAV
wolframscript -file main.wl

# Parameter experiments (baseline, long/short pendulum, large angle, moon gravity, pushed)
wolframscript -file experiments.wl

# Tests
wolframscript -file tests/test_model.wl
```

## Outputs

| File | Description |
|------|-------------|
| `data/results.csv` | Time, angle, velocity, energy per time step |
| `data/pendulum_animation.gif` | Looping animated GIF of the pendulum |
| `data/pendulum_audio.wav` | Musical sonification (A minor pentatonic, WAV) |

## Sonification

| Parameter | Design |
|---|---|
| Pitch | Swing angle → A minor pentatonic, root A3 (220 Hz) |
| Duration | One half-swing (zero crossing to zero crossing) |
| Volume | Proportional to angular velocity at each zero crossing |
| Timbre | Pure sine (`harmonics = {1.0}`), exponential decay (τ = dur/3) |

The pendulum literally plays itself: wider, faster swings produce louder,
higher notes, and the rhythm slows naturally as the pendulum loses energy.

To change scale, edit the `ScaleLookup` call in `src/sonify.wl` and pass
any key from `$StemScales`:

```wolfram
ScaleLookup[angle, -maxAngle, maxAngle, $StemScales["Major"], 220.0]
```

Available scales: `MinorPentatonic`, `MajorPentatonic`, `Major`, `Minor`,
`WholeTone`, `Phrygian`.

## Animation

| Parameter | Design |
|---|---|
| View | Side-on pendulum, pivot at top centre |
| Frame rate | 25 fps (default), configurable |
| Colour | Bob shifts from blue (at centre) to red-violet (at maximum swing) |
| Trail | Motion trail shows the recent path of the bob (~0.3 s of frames) |
| Speedup | `speedup` sub-samples the solution; 1.0 = real time, 2.0 = double speed |

To render at half speed:

```wolfram
ExportAnimation[solution, params, outGIF, 25, 0.5]
```

## Project structure

```
main.wl          — Entry point
experiments.wl   — Batch runs across parameter variations
src/model.wl     — ODE solver and energy calculation
src/output.wl    — CSV export and console summary
src/animate.wl   — Animated GIF export
src/sonify.wl    — WAV audio export
tests/           — Unit tests
data/            — Output directory (not committed)
```

## Console output

`main.wl` prints one complete line per event so VoiceOver reads each chunk
as a self-contained announcement. Headings use `STEMHeading`; the six
`PrintSummary` values (steps, max/min angle, initial/final/drift energy) use
`STEMPrintN`; export confirmations use `STEMDescribeCSV`, `STEMDescribeGIF`,
and `STEMDescribeWAV`; the final line uses `STEMSay`.

To also hear a spoken announcement when the run finishes, set `STEM_SPEAK=1`
before running:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

See [`docs/voiceover-wolframscript-guide.md`](../docs/voiceover-wolframscript-guide.md)
for the full VoiceOver + wolframscript workflow.

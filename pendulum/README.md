# Pendulum

A pendulum physics simulation written in Wolfram Language, runnable entirely
from the terminal via `wolframscript`. Produces CSV data, an animated GIF,
and a WAV sonification.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`

## Quick start

```bash
# Full run: CSV + GIF + WAV
wolframscript -file main.wl

# Both --key=value and --key value (space form) are accepted
wolframscript -file main.wl -- --simulation.mode=double
wolframscript -file main.wl -- --simulation.mode double

# Parameter experiments (baseline, long/short pendulum, large angle, moon gravity, pushed)
wolframscript -file experiments.wl

# Tests
wolframscript -file tests/test_model.wl
```

## Outputs

**Simple mode** (`--simulation.mode=simple`):

| File | Description |
|------|-------------|
| `output/simple_results.csv` | Time, angle, velocity, energy per time step |
| `output/simple_animation.gif` | Looping animated GIF of the pendulum |
| `output/simple_audio.wav` | Sonification (A minor pentatonic scale, WAV) |

**Double mode** (`--simulation.mode=double`, default):

| File | Description |
|------|-------------|
| `output/double_results.csv` | Time, angles and velocities for both rods |
| `output/double_animation.gif` | Looping animated GIF, both bobs |
| `output/double_audio.wav` | Binaural sonification, left/right bob in separate channels |

## Correctness checks

Each mode prints its own two checks (`[PASS]`/`[FAIL]`, diagnostic-only,
never abort) — simple and double pendulum are different systems, so each
gets the checks that are actually meaningful for it, the same
per-mode-not-forced-four reasoning `magnetic/AGENTS.md` documents for its
own four modes.

**Simple mode:**

1. **Exact period, any amplitude** — the true period of a simple pendulum
   is `T = 4*Sqrt[L/g]*EllipticK[Sin[theta0/2]^2]` (WL's `EllipticK[m]`
   takes the parameter `m=k^2`, not the modulus `k` — verified against the
   small-angle limit, `EllipticK[0]=Pi/2`, before use). Checked against a
   real NDSolve-measured period at 10/45/90/150 degrees — a strict upgrade
   over checking only the small-angle *approximation*, since the exact
   formula holds everywhere, including large amplitudes where the
   approximation clearly fails. Exact relation, tight tolerance.
2. **Energy conservation** — total mechanical energy checked at 10 points
   spread across the full integration (not just start/end). Exact
   relation, tight tolerance.

**Double mode:**

3. **Energy conservation** — same multi-point check, using the
   independently re-derived `DoublePendulumEnergy`. Exact relation, tight
   tolerance (energy conserved to ~1e-8 to 1e-10 relative in practice).
4. **Chaos sensitivity** — two trajectories started a tiny distance apart
   in `theta1` diverge by at least 100x within the default 20 s window,
   using a fixed, independent 130-degree test amplitude (not whatever
   `angle1_deg` the current run happens to be configured with).
   **Important finding**: the app's own default `angle1_deg=120` does
   *not* reliably clear this 100x threshold within 20 s — the transition
   is sharp, from ~6x at 120 degrees to ~85,000x at 125 degrees. Chaos
   genuinely exists above roughly 60 degrees in the qualitative sense
   (Lyapunov-positive dynamics), but visible >=100x divergence within a
   moderate window needs a substantially larger amplitude. Qualitative
   check, generous tolerance.

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
output/            — Output directory (not committed)
```

## Console output

`main.wl` prints one complete line per event so VoiceOver reads each chunk
as a self-contained announcement. Headings use `STEMHeading`; the six
`PrintSummary` values (steps, max/min angle, initial/final/drift energy) use
`STEMPrintN`; export confirmations use `STEMDescribeCSV`, `STEMDescribeGIF`,
and `STEMDescribeWAV`. `STEMSay` is called at each pipeline phase (ODE solve,
animation, sonification) and as the final completion message with the
platform-appropriate play command (`afplay` on macOS, `aplay` on Linux,
`Start-Process wmplayer` on Windows).

To also hear a spoken announcement when the run finishes, set `STEM_SPEAK=1`
before running:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

See [`docs/voiceover-wolframscript-guide.md`](../docs/voiceover-wolframscript-guide.md)
for the full VoiceOver + wolframscript workflow.

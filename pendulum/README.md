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
| `output/simple_audio.wav` | Sonification (continuous pitch/pan/volume carrier, 220-660 Hz, WAV) |

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

**Simple mode** (`ExportSonification`) maps the solved `{t, angle, velocity}`
trajectory to stem-core's generic `SonifyTrajectory` pipeline — a continuous
carrier tone for the whole run, not discrete per-swing notes:

| Trajectory column | Quantity | Audio dimension |
|---|---|---|
| x | Bob x-position, `L*Sin[theta]` | Stereo pan |
| y | Swing angle `theta` | Pitch, linearly mapped to `sonification.pitch.min_hz`/`max_hz` (220-660 Hz by default) |
| speed | Bob speed, `L*\|omega\|` | Volume |

A phase-accumulated sine carrier plays continuously; the motion layer adds
periodicity-linked tremolo and chaos-linked roughness on top. Two short
accent bursts mark discrete events: an 880 Hz "apex" burst at each maximum
swing angle, and a 440 Hz "crossing" burst each time the bob passes centre.
Because this app's pendulum is undamped (energy is conserved to the tight
tolerance checked by correctness check 2, not dissipated), the tone neither
fades nor slows down over the run.

**Double mode** (`SonifyDoublePendulum`) builds the same three-layer
trajectory sonification independently for each rod, then biases rod 1's pan
−0.4 (left) and rod 2's pan +0.4 (right) before summing both stereo pairs —
the binaural effect described above.

To change the pitch range, edit `sonification.pitch.min_hz`/`max_hz` in
`config.json`, or override on the CLI, e.g.
`--sonification.pitch.min_hz=110 --sonification.pitch.max_hz=440`.

## Animation

Both modes share the same trajectory-derived plot bounds (see "Animation
framing" in `AGENTS.md`), but only simple mode exposes frame rate/speedup
as function parameters — double mode's `AnimateDoublePendulum` hardcodes
its own frame rate internally.

| Parameter | Simple mode (`ExportAnimation`) | Double mode (`AnimateDoublePendulum`) |
|---|---|---|
| View | Side-on pendulum, pivot at top centre | Side-on double pendulum, pivot at top centre |
| Frame rate | 25 fps (default), configurable via the `frameRate` parameter | 25 fps, fixed (not a parameter) |
| Colour | Bob shifts from blue (at centre) to red-violet (at maximum swing) | Rod 1 blue, rod 2 orange (colour-blind-safe palette) |
| Trail | Motion trail shows the recent path of the bob (~0.3 s of frames) | Motion trail via `animation.trail_length` config, converted to frames |
| Speedup | `speedup` sub-samples the solution; 1.0 = real time, 2.0 = double speed | Not available |

To render simple mode at half speed:

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

# Lorenz Attractor

A Wolfram Language simulation of the Lorenz strange attractor, runnable
entirely from the terminal via `wolframscript`. Produces trajectory data,
an animated GIF visualisation, and an audio sonification.

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
# Full run: CSV + GIF + WAV (Lorenz mode, default)
wolframscript -file main.wl

# Rössler attractor — both forms accepted
wolframscript -file main.wl -- --simulation.mode=rossler
wolframscript -file main.wl -- --simulation.mode rossler

# Named presets (classic, butterfly, stable, wild, slow, rho9996)
wolframscript -file main.wl -- --simulation.lorenz.preset=stable
wolframscript -file experiment.wl          # the preset on its ACTIVE PRESET line

# Hear the start-up transient too (default: the first 5 s are discarded)
wolframscript -file main.wl -- --simulation.lorenz.transient_seconds=0

# Tests
wolframscript -file tests/test_model.wl

# Play sonification
# macOS
afplay output/lorenz_audio.wav
afplay output/rossler_audio.wav

# Linux
aplay output/lorenz_audio.wav
aplay output/rossler_audio.wav

# Windows PowerShell
Start-Process wmplayer output\lorenz_audio.wav
Start-Process wmplayer output\rossler_audio.wav
```

## Outputs

| File                              | Description                          |
|-----------------------------------|--------------------------------------|
| output/lorenz_trajectory.csv        | t, x, y, z, speed at each step      |
| output/lorenz_animation.gif         | Animated butterfly attractor (x-z)   |
| output/lorenz_audio.wav             | Sonification of x(t)                 |
| output/rossler_trajectory.csv       | t, x, y, z, speed at each step (`--simulation.mode=rossler`) |
| output/rossler_animation.gif        | Animated Rössler attractor (x-z)     |
| output/rossler_audio.wav            | Sonification of x(t) (Rössler)       |

## Correctness checks

Four checks run every invocation, printed as `[PASS]`/`[FAIL]`, diagnostic-only
(never abort). Lorenz and Rössler have genuinely different mathematical
structure, so check 1 tests a different (but always exact) claim per system
rather than assuming one transfers to the other:

1. **Phase-space divergence** — for Lorenz, `nabla.f` is exactly constant
   (`-(sigma+1+beta)`) at every point in space, verified at several arbitrary
   points via independent symbolic differentiation. For Rössler, `nabla.f`
   is genuinely position-dependent (`a+x-c`) — the check instead verifies
   *that* formula holds pointwise, and explicitly confirms the values are
   **not** all equal (unlike Lorenz). Exact relation, tight tolerance.
2. **Known equilibria satisfy f=0** — Lorenz's origin plus the nonzero pair
   `C+/C- = (+-sqrt(beta(rho-1)), +-sqrt(beta(rho-1)), rho-1)`; Rössler's
   two equilibria, derived from the quadratic that falls out of setting all
   three equations of motion to zero. Exact relation, tight tolerance.
3. **Largest Lyapunov exponent** — computed via Benettin's renormalization
   method (perturb, integrate a short interval, measure growth, renormalize,
   repeat, average) and compared against the commonly-cited literature value
   for each system's classic parameters (Lorenz ≈0.905, Rössler ≈0.07).
   Empirical benchmark comparison, generous tolerance.
4. **Trajectory boundedness** — the actual solved trajectory contains no
   `Overflow[]`/`Underflow[]`/`Indeterminate`/`ComplexInfinity` and stays
   within a generous magnitude bound. Sanity check.

## Sonification

`ExportSonification` (`src/sonify.wl`) is a thin wrapper around stem-core's
generic `SonifyTrajectory` pipeline (`SpatialLayer` + `MotionLayer` +
`EventLayer` + `MixLayers`) — a continuous carrier, not discrete
per-extremum notes on a fixed musical scale. The `{t,x,y,z}` solution is
augmented with a finite-difference speed column before being handed off:

| Parameter | Design |
|---|---|
| Pitch | y-value, mapped to `sonification.pitch.min_hz`/`max_hz` (config default 80-1200 Hz; `pitch.axis` itself defaults to `"y"` in stem-core) |
| Pan | x-value → stereo pan (`sonification.spatial.pan_axis = "x"`) |
| Event accents | `"apex"` events — local maxima of \|y\|, correlating with the trajectory crossing between the two wings (Lorenz) or completing a spiral cycle (Rössler) |
| Volume/texture | stem-core's `MotionLayer` (tremolo/roughness driven by trajectory periodicity and a chaos proxy) — not a fixed per-note envelope |

The two-wing structure of the attractor maps naturally to pitch space: the
positive-y wing tends toward higher pitch, the negative-y wing toward lower,
and the chaotic switching between wings produces the characteristic
unpredictable melodic contour. There is no scale/root-note option in the
current implementation (an earlier pentatonic-scale note synthesizer was
replaced by the shared stem-core `SonifyTrajectory` pipeline); the pitch
range is tunable via `sonification.pitch.min_hz`/`max_hz` in `config.json`.

## Animation

| Parameter | Design |
|---|---|
| View | 3D trajectory projected onto the x-z plane (classic butterfly view) |
| Colour gradient | Blue (early) → cyan → orange → red (recent) |
| Background | Dark for contrast |
| Frame count | 150 (render budget, default), fourth argument to `ExportAnimation` |
| Frame rate | Derived, not fixed: `Clip[frameCount / targetDuration, {2, 30}]` fps, where `targetDuration` is the matching WAV's duration, so GIF playback length tracks audio length |

`ExportDualAnimation` in `src/animate.wl` renders two near-identical
trajectories side-by-side, used by the `butterfly` experiment preset to
visualise how quickly they diverge.

## Presets (`simulation.lorenz.preset`, or experiment.wl)

Selected with `--simulation.lorenz.preset=<name>` on main.wl, or by the
ACTIVE PRESET line of experiment.wl, which runs main.wl with it. Every
preset starts from (1, 1, 1), discards the first
`simulation.lorenz.transient_seconds` (5 s), and writes
`lorenz_audio_<name>.wav`, `lorenz_animation_<name>.gif` and
`lorenz_trajectory_<name>.csv`.

| Label      | What it shows                                    |
|------------|--------------------------------------------------|
| classic    | Standard attractor, 40 s                         |
| butterfly  | Two trajectories 0.001 apart side by side in the GIF, 30 s (the WAV follows the first) |
| stable     | rho=20, 30 s — a spiral settling onto a fixed point (ends within 0.04 of it) |
| wild       | rho=99.96, different chaotic regime, 20 s        |
| slow       | sigma=4, slower mixing dynamics, 60 s            |
| rho9996    | rho=99.96 for 120 s, the GIF frame-rate stress test |

The stable preset was rho = 24 until it was measured: 24 lies in the
range 24.06-24.74 where a chaotic set coexists with the stable fixed
points, and the whole 30 s was chaotic transient.

## Transient

`simulation.lorenz.transient_seconds` (default 5) and
`simulation.rossler.transient_seconds` (default 50) are integrated and
then dropped before the CSV, GIF and WAV; the time column restarts at 0
and `simulation.duration` is the length of what remains. Without it the
lorenz start from (0.1, 0, 0) produced a loud transient at the top of the
pitch range in the first 0.6 s, the loudness normalisation hit its peak
ceiling, and the WAV came out near -25 LUFS instead of -17. With the
transient discarded lorenz mode still measured about -21.5 LUFS, because
fast passages at the top of the pitch range kept hitting the peak ceiling.
Lorenz mode and its presets therefore use stem-core's look-ahead peak
limiter (`audio.limiter` in config.json: ceiling -1 dBFS, 5 ms attack,
50 ms release, lorenz mode only); every lorenz run now measures -17.0 LUFS
and prints the limiter's maximum gain reduction. Rossler is unchanged. See
AGENTS.md "Transient and presets".

## Project structure

    lorenz/
    ├── main.wl              Entry point
    ├── experiment.wl        Named parameter presets
    ├── src/
    │   ├── model.wl         Lorenz/Rossler ODEs, pair solver, divergence,
    │   │                    four correctness checks (per system where they differ)
    │   ├── output.wl        CSV export, console summary, PrintCorrectnessChecks
    │   ├── animate.wl       GIF animation (single + dual)
    │   └── sonify.wl        WAV sonification
    ├── tests/
    │   └── test_model.wl    Unit tests
    ├── output/                Output directory (not committed)
    ├── AGENTS.md            Guidance for Claude Code
    └── README.md

## Console output

`main.wl` prints one complete line per event so VoiceOver reads each chunk
as a self-contained announcement. Headings use `STEMHeading`; the step count
in `PrintSummary` uses `STEMPrintN`; the x/y/z range lines carry two values
each and remain as bare `Print`; the four correctness checks print as a
`Checks: 1[PASS] 2[PASS] 3[PASS] 4[PASS]` line via `PrintCorrectnessChecks`,
followed by one detail line per check; export confirmations use
`STEMDescribeCSV` (1 row per step, 5 columns), `STEMDescribeGIF` (frame
count and fps as actually rendered — see "Animation" above), and
`STEMDescribeWAV` (duration from `params["TimeEnd"]`). After the GIF/WAV sync
sentence each run prints the loudness line (`STEMLoudnessLine`: target,
measured integrated LUFS and peak) and the Timing line (`STEMTimingLine`:
intro, pause, notes, pause, outro and total; lorenz has no narration, so
only the notes are non-zero).
`STEMSay` is called at each pipeline phase (ODE solve, correctness checks,
animation, sonification) and as the final completion message with the
platform-appropriate play command.

To also hear a spoken announcement when the run finishes, set `STEM_SPEAK=1`
before running:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

See [`docs/voiceover-wolframscript-guide.md`](../docs/voiceover-wolframscript-guide.md)
for the full VoiceOver + wolframscript workflow.

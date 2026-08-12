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

# Experiment with presets
wolframscript -file experiment.wl

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
`STEMDescribeWAV` (duration from `params["TimeEnd"]`).
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

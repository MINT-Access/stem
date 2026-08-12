# 2D Wave Propagation — Agent Guide

## Project overview

Simulates and sonifies 2D wave propagation using the finite element method
(NDSolveValue on a spatial Region).  Two modes make wave physics audible
through listening-point displacement time series:

| Mode | Geometry | Key phenomenon |
|------|----------|----------------|
| `ripple` | Circular membrane | Sequential wavefront arrival at radially spaced LPs |
| `interference` | Rectangular tank | Moving LP sweeps constructive/destructive fringe bands |

## Project structure

```
waves/
  main.wl            — thin orchestrator: loads stem-core + src/, parses config, calls functions
  config.json        — default simulation parameters
  experiments.wl     — 8 curated preset invocations (RunExperiment)
  AGENTS.md          — this file
  src/
    model.wl         — RippleModel, InterferenceModel (FEM solvers + sanity checks)
    sonify.wl        — WavesMono, PanStereo, MakeLPTraj, AudioCfg,
                       SonifyRipple, SonifyInterference
    animate.wl       — DispColor, AnimateRipple (GIF+PNG), AnimateInterference (GIF+PNG)
    output.wl        — ExportRippleData, ExportInterferenceData (CSV)
  tests/
    test_model.wl    — unit tests for model.wl (both modes, key Association fields)
  output/            — generated files (gitignored)
```

## How to run

```sh
# Default: ripple mode
wolframscript -file waves/main.wl

# Interference mode
wolframscript -file waves/main.wl -- --simulation.mode=interference

# Different wave speed
wolframscript -file waves/main.wl -- --simulation.waves.wave_speed=1.5

# Higher source frequency (interference)
wolframscript -file waves/main.wl -- --simulation.mode=interference \
  --simulation.waves.source_frequency=4.0

# More listening points (ripple)
wolframscript -file waves/main.wl -- --simulation.waves.listening_points=6

# Unit tests
wolframscript -file waves/tests/test_model.wl

# All experiments
wolframscript -file waves/experiments.wl
```

## Output files

| File | Description |
|------|-------------|
| `ripple_audio.wav` | Stereo WAV: listening-point displacements, panned L-R |
| `ripple.gif` | False-colour animation with LP yellow dots, played back over the WAV's duration (see "GIF/WAV timing sync" below) |
| `ripple.png` | Plot3D surface at final time (TemperatureMap colour) |
| `ripple_data.csv` | Table: t_s, disp_lp1_units, disp_lp2_units, ... |
| `interference_audio.wav` | Mono WAV via SonifyTrajectory (pan follows x-position) |
| `interference.gif` | Animation: moving LP (yellow), sources (green), played back over the WAV's duration (see "GIF/WAV timing sync" below) |
| `interference.png` | Final frame showing settled fringe pattern |
| `interference_data.csv` | Table: t_s, lp_x_units, displacement_units, disp_fixed_units |

## Data flow

```
config.json + CLI args
        |
   LoadConfig (stem-core)
        |
        +-- ripple mode:
        |   RippleModel[cfg]         NDSolveValue + checks; returns rippleModel
        |   SonifyRipple             -> WAV (stereo mix of nLP panned mono signals)
        |   AnimateRipple            -> GIF + PNG
        |   ExportRippleData         -> CSV
        |
        +-- interference mode:
            InterferenceModel[cfg]   NDSolveValue + checks; returns interferenceModel
            SonifyInterference       -> WAV (SonifyTrajectory with pan_axis=x)
            AnimateInterference      -> GIF + PNG
            ExportInterferenceData   -> CSV
```

## Model Association shapes

### Ripple model (from RippleModel)

| Key | Type | Description |
|-----|------|-------------|
| `"solR"` | InterpolatingFunction | PDE solution `u(x,y,t)` |
| `"lpDisp"` | {{disp_t},...} | Displacement at each LP over time (nLP x nT) |
| `"lpX"` | List[Real] | x-position of each LP (at y=0) |
| `"lpPans"` | List[Real] | Stereo pan for each LP in [-0.8, 0.8] |
| `"tVals"` | List[Real] | Time sample array (length nT=300) |
| `"nLP"` | Integer | Number of listening points |
| `"nT"` | Integer | Number of time steps (300) |
| `"dt"` | Real | Time step size |
| `"c"`, `"r"`, `"tEnd"` | Real | Wave speed, radius, duration |
| `"maxR"` | Real | Maximum absolute displacement |

### Interference model (from InterferenceModel)

| Key | Type | Description |
|-----|------|-------------|
| `"solI"` | InterpolatingFunction | PDE solution `u(x,y,t)` |
| `"dispMoving"` | List[Real] | Displacement at moving LP (length nT) |
| `"dispFixed"` | List[Real] | Displacement at fixed LP (0, yLP) |
| `"xMoving"` | List[Real] | x-position of moving LP (0 then sweeps) |
| `"tVals"` | List[Real] | Time sample array |
| `"nTStat"` | Integer | Number of stationary time steps (nT/2) |
| `"xLPMin"`, `"xLPMax"` | Real | Sweep range of moving LP |
| `"yLP"` | Real | y-position of LP (35% of half-height) |
| `"x1s"`, `"x2s"` | Real | Source x-positions (symmetric) |
| `"tankW"`, `"tankH"` | Real | Tank dimensions |
| `"maxI"` | Real | Maximum absolute displacement |

## Sonification design

### Ripple mode
- Each listening point `k` at `x = lpX[k]` (spaced 20%-80% of radius)
- Displacement time series → mono signal via `WavesMono` (SpatialLayer + MotionLayer + EventLayer)
- Each mono signal panned at `lpPans[k]` (linear from -0.8 to 0.8)
- All panned signals averaged and written as stereo WAV via `RenderAudio`
- Time-stretched 5x relative to simulation time

### Interference mode
- Moving LP trajectory: stationary at origin for first half, sweeps across tank in second half
- x-position maps to stereo pan via SonifyTrajectory `pan_axis="x"`
- Displacement maps to pitch (y-axis, 80–1200 Hz)
- Speed of displacement change maps to volume
- Time-stretched 4x relative to simulation time

## Physical correctness checks

### Ripple checks (1-4)
1. **Amplitude bounded**: `0 < max|u| < 500`
2. **Wavefront arrival times** match `r/c` within `max(0.6, 0.35*tEnd)` seconds
3. **Causality**: outer LPs receive wavefront later than inner LPs
4. **Dirichlet BC**: `max|u|` at 97% of radius < 0.12

### Interference checks (1-4)
1. **Amplitude bounded**: `0 < max|u| < 500`
2. **Pattern develops**: late-time amplitude > 0.5% of peak
3. **Constructive LP amplitude**: fixed-LP amplitude >= 30% of sweep-LP max
4. **Dirichlet BC**: max|u| near walls < 15% of peak

## Common pitfalls

1. **`NDSolveValue` FEM warnings**: `InterpolatingFunction::femdmval` can occur when
   evaluating slightly outside the mesh boundary (e.g., `0.97*r` samples).
   These are suppressed with `Quiet[..., InterpolatingFunction::femdmval]`.

2. **`WavesMono` requires stem-core 3-layer pipeline**: `SpatialLayer`,
   `MotionLayer`, `EventLayer` must all be loaded from init.wl.  The function
   is NOT a wrapper around `SonifyTrajectory` — it calls the layers directly
   to bypass `MixLayers` and gain per-LP stereo control.

3. **`RenderAudio` vs `ExportAudioBuffer`**: Ripple mode uses `RenderAudio`
   (stereo capable) because it outputs a mixed stereo matrix.  Interference
   mode uses `SonifyTrajectory` (mono + pan_axis).  Do not swap them.

4. **GIF frame construction**: `DispColor` maps displacement/maxAmp to RGB.
   The clamp to [-1,1] is applied before colour mapping; values outside the
   clamp range produce saturated red or blue without errors.

5. **Interference sweep timing**: the LP is stationary at x=0 for exactly
   `Floor[nT/2]` steps, then sweeps from xLPMin to xLPMax over the remaining
   steps.  The audio crossover at `tEnd/2` in the GIF matches this.

## GIF/WAV timing sync (fixed post-v1.5.0)

**The bug.** `AnimateRipple`/`AnimateInterference` built a fixed 32-frame
GIF at a hardcoded 10 fps (`"DisplayDurations" -> ConstantArray[0.1, 32]`)
— always exactly 3.2s — while `SonifyRipple`/`SonifyInterference` size the
WAV from the simulated `tEnd` stretched by a fixed factor (5x for ripple,
4x for interference; e.g. default `tEnd=4.0` -> 20s ripple WAV, 16s
interference WAV). The two durations were computed independently and had
no relationship. Measured before the fix: `ripple.gif` 3.2s vs
`ripple_audio.wav` 20.0s (6.25x); `interference.gif` 3.2s vs
`interference_audio.wav` 16.0s (5.0x).

**Root cause.** Same shape as the decoupled-duration bug fixed in
`lorenz/src/animate.wl` (`ExportAnimation`) — a literal frame count and
frame rate baked into the GIF export with no reference to the audio
duration actually being produced elsewhere in the same run.

**The fix.** `SonifyRipple`/`SonifyInterference` (`src/sonify.wl`) now
return the audio duration (`audioDurR`/`audioDurI`) they computed, instead
of discarding it after the `STEMDescribeWAV` call. `AnimateRipple`/
`AnimateInterference` (`src/animate.wl`) take a new `targetDuration_?NumericQ`
parameter plus an `nFrames_:150` **render budget** (not a literal frame
count): `frameRate = Clip[nFrames/targetDuration, {$MinAnimationFps,
$MaxAnimationFps}]` (2-30 fps), then `actualNFrames =
Max[2, Round[frameRate*targetDuration]]` — the frame count is what flexes
at the clamp boundary so playback duration equals `targetDuration` exactly
even for very short or very long simulations. `main.wl` and
`experiments.wl` now capture the sonify functions' return value and pass
it straight into the matching animate call, so the GIF always plays back
over the same duration as its WAV.

**Verification.** Regenerated both pairs (`wolframscript -file main.wl`
default and `-- --simulation.mode=interference`) and re-measured with
Python (`PIL.ImageSequence` summed frame durations vs `wave` module frame
count / rate):

| Pair | Before (GIF vs WAV) | After (GIF vs WAV) |
|------|---------------------|---------------------|
| ripple | 3.2s vs 20.0s (6.25x) | 19.5s vs 20.0s |
| interference | 3.2s vs 16.0s (5.0x) | 16.5s vs 16.0s |

The residual ~0.5s gap after the fix is GIF-format centisecond delay
quantization (frame delays are stored in 1/100s units, so a frame rate
like 7.5 fps -> 133.3ms/frame rounds to 130ms and drifts over 150 frames)
— the same residual seen in `lorenz`'s post-fix GIFs (e.g.
`lorenz_animation.gif` 40.5s vs `lorenz_audio.wav` 40.0s). It is a format
limitation, not a duration-calculation bug; the math (`targetDuration`,
`frameRate`, `actualNFrames`) is exact.

All 8 `experiments.wl` presets were also re-run to confirm the fps clamp
holds across the config space actually exercised (7.5-9.375 fps for
default-length runs, down to 3.75 fps for `ripple_large_membrane`
(`tEnd=8`, audioDur=40s) and 4.6875 fps for `interference_slow_wave`
(`tEnd=8`, audioDur=32s) — both comfortably inside `[$MinAnimationFps,
$MaxAnimationFps] = [2, 30]`).

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSay`, `STEMSection`, `STEMDescribeWAV`,
  `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`, `STEMPlayCmd`,
  `SpatialLayer`, `MotionLayer`, `EventLayer`, `RenderAudio`,
  `SonifyTrajectory`, `ExportGIF`
- **Mathematica/WL**: `NDSolveValue`, `Inactive[Laplacian]`,
  `DirichletCondition`, `Disk`, `Rectangle`, `Image`, `Plot3D`,
  `Rescale`, `Differences`, `Export`

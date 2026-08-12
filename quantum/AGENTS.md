# AGENTS.md — Guidance for Claude Code

## Project overview

Quantum mechanics simulation in Wolfram Language. Two modes — `qho`
(coherent state in a quantum harmonic oscillator) and `box` (equal
superposition of ground and first excited state in a particle-in-a-box) —
each compute exact analytical time evolution using a truncated energy-eigenstate
basis, export an animated probability-density GIF, a 3×3 snapshot PNG, and
a time-series CSV. Sonification uses stem-core's `SonifyTrajectory` pipeline
via a density-to-trajectory adapter.

**Natural units throughout: ħ = m = 1.** Never introduce conversion factors.

## Project structure

- `main.wl`              — Entry point; mode branching; 4-step pipeline
- `config.json`          — App defaults (mode, qho sub-config, box sub-config)
- `src/model.wl`         — `QHOModel[cfg]`, `BoxModel[cfg]`
                           Each returns:
                           `<| "density", "x", "t", "dx",
                              "mean_energy", "mode", "norm_ok" |>`
- `src/animate.wl`       — `AnimateQuantum[solution, cfg, outDir]`
                           Exports 1 GIF + 1 PNG per run; returns frame count
- `src/sonify.wl`        — `DensityToTrajectory[solution]`,
                           `SonifyQuantum[solution, cfg, outDir]`
- `output/`              — All output files (not committed)

## How to run

```bash
wolframscript -file main.wl                                 # qho (default)
wolframscript -file main.wl -- --simulation.mode=box
wolframscript -file main.wl -- --simulation.qho.alpha=3.0
wolframscript -file main.wl -- --config-dump
afplay output/qho_audio.wav
```

CLI override format: `--key=value` (with `=`). Space-separated `--key value`
is also accepted — main.wl pre-processes args before passing to `LoadConfig`.

## Data flow

```
config → QHOModel / BoxModel
           ↓
         solution {density[nt×nx], x[nx], t[nt], dx,
                   mean_energy, mode, norm_ok}
           ↙              ↘
  AnimateQuantum       DensityToTrajectory
  (GIF, PNG)               ↓
                         trajectory[nt×5]
                           ↓
                         SonifyTrajectory  →  {mode}_audio.wav
           ↓
         CSV (time series: t, mean_x, variance_x, speed)
```

## Solution Association shape

Both model functions return an Association with the same keys:

| Key | Type | Description |
|-----|------|-------------|
| `"density"` | `{nt, nx}` Real matrix | `\|ψ(x,t)\|²` — probability density |
| `"x"` | length-`nx` vector | Spatial grid points |
| `"t"` | length-`nt` vector | Time grid points |
| `"dx"` | Real | Spatial grid spacing (`(xMax−xMin)/(nx−1)`) |
| `"mean_energy"` | Real | `⟨E⟩` in natural units |
| `"mode"` | String | `"qho"` or `"box"` |
| `"norm_ok"` | Boolean | True if all sampled ∫\|ψ\|²dx are within 1% of 1 |

## Physics notes

### QHO coherent state

- Eigenfunctions: φₙ(x) = (2ⁿ n! √π)^(−1/2) Hₙ(x) exp(−x²/2)
  WL: `HermiteH[n, x]` gives the physicists' polynomial Hₙ (Listable).
- Coefficients: cₙ = exp(−|α|²/2) · αⁿ / √(n!)
- Time evolution: ψ(x,t) = Σₙ cₙ φₙ(x) exp(−i ω (n+½) t)
- Mean energy: ⟨E⟩ = ω(|α|² + ½)
- Key property: position variance Var(x) ≈ 1/(2ω) is **constant** for a
  coherent state. `DensityToTrajectory` has a guard that adds a tiny
  sinusoidal modulation when the variance range is < 10⁻⁴ of the mean, so
  `SonifyTrajectory`'s pitch `Rescale` is never degenerate.

### Particle in a box

- Eigenfunctions: φₙ(x) = √(2/L) sin(nπx/L), n = 1, 2, …
- Energy levels: Eₙ = n²π²/(2L²)
- Initial state: (φ₁ + φ₂)/√2 → c₁ = c₂ = 1/√2, all others 0
- Mean energy: ⟨E⟩ = (E₁ + E₂)/2

### Normalisation check

Evaluated at every 10th timestep: `Abs[Total[density_row] * dx − 1] < 0.01`.
Result stored in `solution["norm_ok"]`. Reported in console; does not abort.

## DensityToTrajectory adapter

Converts the `{nt, nx}` density field to the `{t, x, y, z, speed}` matrix
expected by `SonifyTrajectory`:

| Column | Source | Mapping |
|--------|--------|---------|
| `x` | ⟨x⟩(t) = `density . xVals * dx` | stereo pan |
| `y` | Var(x)(t) = ⟨x²⟩ − ⟨x⟩² | pitch (apex detection) |
| `z` | 0 | unused |
| `speed` | `\|d⟨x⟩/dt\|` via central differences | volume |

Sonification duration is overridden to `Last[t]` (simulation time span)
via `DeepMerge` before calling `SonifyTrajectory`.

## Animation framing: GIF/WAV duration sync (fixed post-v1.5.0)

**The bug.** `AnimateQuantum` built the GIF from a fixed `animation.frameRate`
config value (default 10 fps) applied to a stride-capped frame count
(`nt` subsampled down to ≤100 frames), with no reference to how long the
accompanying WAV actually plays. `SonifyQuantum`, meanwhile, sonifies at
`duration -> Last[t]` (the real simulated time span). These two durations
have no reason to agree, and for `box` they didn't: measured before the
fix, `box_density.gif` played **10.1 s** against `box_audio.wav`'s
**20.0 s** — a 0.5x ratio, the GIF finishing its loop while the audio was
only half done. `qho` happened to land close (GIF 12.6 s vs. WAV 12.55 s,
ratio ~1.0) purely because its config's `nt=252` and `timestep=0.05` made
the old stride/frameRate arithmetic coincidentally line up — not because
the code accounted for duration at all.

**Root cause.** Same pattern as `lorenz/src/animate.wl`'s original bug:
GIF playback length was a function of a hardcoded frame rate and a
frame-count cap, not of the simulation's actual duration. `box`'s default
`duration=20.0` with `timestep=0.05` gives `nt=401`; the old
`stride = Floor[401/100] = 4` capped the GIF to 101 frames, and at the
fixed 10 fps that is 10.1 s of playback regardless of `Last[t]`.

**The fix.** `AnimateQuantum` (`src/animate.wl`) now derives frame rate
from `nt` and `targetDuration = Last[tVals]` — the same value
`SonifyQuantum` already uses for the WAV — instead of reading
`animation.frameRate` from config: `frameRate = Clip[nt / targetDuration,
{$MinAnimationFps, $MaxAnimationFps}]` (2–30 fps), then `nFrames =
Max[2, Round[frameRate * targetDuration]]` and `frameIndices =
Round[Subdivide[1, nt, nFrames - 1]]`. The frame *count* is what flexes
at the fps clamp so playback lands on `targetDuration` exactly even at
the extremes (very short or very long runs), matching the approach in
`lorenz/src/animate.wl` and `cellular/src/animate.wl`. `animation.frameRate`
in `config.json` is no longer read; it's left in place unused, same as
`cellular`'s `animation.fps`.

**Verified after the fix** (measured with Pillow + `wave`, same method as
before): `box` GIF 20.05 s vs. WAV 20.0 s (ratio 1.0025); `qho` GIF 12.6 s
vs. WAV 12.55 s (ratio 1.004). Both regenerated via
`wolframscript -file main.wl -- --simulation.mode=qho` /
`--simulation.mode=box`. `tests/test_model.wl` still passes 14/14
(unaffected — it covers `model.wl`/sonify math, not animation timing).

## Performance

Time evolution uses a single matrix multiply instead of explicit timestep loops:

```wolfram
timeCoeffs = Table[cn[[n+1]] * Exp[-I*omega*(n+0.5)*tVals], {n, 0, nModes-1}];
psiMatrix  = Transpose[timeCoeffs] . phi;   (* {nt×nModes} . {nModes×nx} *)
density    = Abs[psiMatrix]^2;
```

For default parameters (20 modes, 200 points, 252 timesteps) this runs in a
few seconds. Increase `n_modes` for higher coherent amplitudes (|α|² ≫ 1).

## Output naming convention

All output files are prefixed with `mode` (`"qho"` or `"box"`) so both modes
can coexist in `output/` without overwriting each other.

## Common pitfalls

- **Do not change the natural units.** All formulas assume ħ = m = 1. Introducing
  factors of ħ or m will silently break the energy and eigenfunction normalisation.
- **`HermiteH` is Listable** — `HermiteH[n, xVals]` where `xVals` is a list
  returns a list. No `Map` needed.
- **Coherent state variance is constant.** Don't remove the flat-variance guard in
  `DensityToTrajectory` — without it, `Rescale` produces `Indeterminate` pitch
  values when `Min[varX] ≈ Max[varX]`.
- **Box modes are 1-indexed.** φ₁ is the ground state (n=1), stored at `phi[[1]]`
  and `cn[[1]]`. There is no n=0 mode.
- **`SonifyTrajectory` requires a non-empty `eventTypes` list.** Passing `{}`
  gives silence from the event layer but still works; `{"apex","crossing"}` is
  the standard default.
## Dependencies

- Mathematica or Wolfram Engine (any recent version with `HermiteH`)
- `stem-core` (sibling `../stem-core`) — `SonifyTrajectory`, `ExportGIF`,
  `ExportCSV`, `ExportAudioBuffer`, `NormalizeBuffer`, `EnsureDir`,
  `STEMHeading`, `STEMSection`, `STEMPrintN`, `STEMDescribe*`, `STEMSay`,
  `FmtN`, `GetCfg`, `DeepMerge`, `LoadConfig`
- No external paclets required

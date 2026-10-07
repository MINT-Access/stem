# AGENTS.md — Guidance for Claude Code

## Project overview

Lorenz attractor simulation in Wolfram Language, runnable from the terminal
via `wolframscript`. Produces a trajectory CSV, an animated GIF of the
butterfly-shaped attractor, and a WAV sonification.

## Project structure

- `main.wl`               — Full pipeline: solve → correctness checks → CSV → GIF → WAV
- `experiment.wl`         — Runs one named preset through main.wl (set its ACTIVE PRESET line)
- `src/model.wl`          — Lorenz ODE (`SolveLorenz`), Rossler ODE (`SolveRossler`),
                            `DiscardTransient`, presets (`$lorenzPresets`,
                            `LorenzPresetParams`), pair solver (`SolveLorenzPair`), divergence
                            (`LorenzDivergence`), four correctness checks (see
                            "Correctness checks" below)
- `src/output.wl`         — CSV export (`ExportResults`, `ExportDivergence`,
                            `PrintSummary`, `PrintCorrectnessChecks`)
- `src/animate.wl`        — GIF export (`ExportAnimation`, `ExportDualAnimation`)
- `src/sonify.wl`         — WAV export (`ExportSonification`)
- `tests/test_model.wl`   — Unit tests
- `output/`                 — All output files (not committed)

## How to run

```bash
wolframscript -file main.wl          # full run
wolframscript -file main.wl -- --simulation.lorenz.preset=stable   # a named preset
wolframscript -file experiment.wl    # the preset on its ACTIVE PRESET line
wolframscript -file tests/test_model.wl
afplay output/lorenz_audio.wav         # play audio on macOS
```

## Parameters (passed as Association)

| Key       | Meaning                        | Classic value  |
|-----------|-------------------------------|----------------|
| Sigma     | Prandtl number                | 10.0           |
| Rho       | Rayleigh number               | 28.0           |
| Beta      | Geometric factor              | 8/3            |
| InitX/Y/Z | Initial conditions            | 1.0, 1.0, 1.0* |
| TimeEnd   | Simulation duration (seconds) | 40.0           |
| TimeStep  | Max ODE step size             | 0.005          |

Sigma/Rho/Beta/TimeEnd/TimeStep's classic values are also this app's actual
shipped `config.json` defaults. *`InitX/Y/Z` is the exception: `(1,1,1)` is
the commonly-cited textbook starting point (and what `experiment.wl`'s
presets and `tests/test_model.wl`'s fixture both use), but `config.json`'s
actual shipped default is `(0.1, 0.0, 0.0)` — a deliberately different,
near-origin starting point, not a stale table entry.

## Chaos regimes

- rho < 1:        fixed point at origin
- 1 < rho < 24.74: stable fixed points (two symmetric spirals)
- 24.06 < rho < 24.74: the stable fixed points coexist with a chaotic set,
  so a run can wander chaotically for a long time before settling (the old
  "stable" preset at rho = 24 was all transient over its 30 s)
- rho > 24.74:    chaotic strange attractor

## Transient and presets (config keys)

- `simulation.lorenz.transient_seconds` (default 5) and
  `simulation.rossler.transient_seconds` (default 50): main.wl integrates
  for transient + `simulation.duration`, then `DiscardTransient` drops the
  transient and restarts the time column at 0 before the CSV, the GIF and
  the WAV, the same way the Lyapunov checks discard their own transient.
  Why: from the config start (0.1, 0, 0) lorenz's first ~0.6 s is a
  transient at the top of the 80-1200 Hz pitch range that set the WAV's
  peak, so the -17 LUFS normalisation hit its 0.97 peak ceiling and lorenz
  mode measured -25 LUFS (presets -24.9 to -32.5). Discarding it raised
  lorenz mode to -21.6 LUFS, but most runs stay peak-limited: the
  sonification's own dynamic range (volume from speed over -24..0 dB, pitch
  up to 1200 Hz; 1 s RMS spans 30-50 dB, crest factor 25-30 dB) puts fast
  passages at the ceiling. Measured after the change (stem-core meter):
  lorenz -21.58, classic -23.61, butterfly -19.70, wild -21.71, slow
  -18.89, rho9996 -26.41; rossler -17.00 and stable -16.95 reach the
  target. Rossler's 50 s matches
  its slow spiral-out from near the origin (growth rate about a/2 = 0.1
  per time unit, about 46 time units from 0.1 to the attractor's size).
  Set either to 0 to hear the start again.
- `simulation.lorenz.preset` (default ""): one of `$lorenzPresets`
  (src/model.wl): classic, butterfly, stable, wild, slow, rho9996. A preset
  sets sigma, rho, beta and duration, starts from (1, 1, 1), and writes
  `lorenz_audio_<preset>.wav`, `lorenz_animation_<preset>.gif` and
  `lorenz_trajectory_<preset>.csv`; butterfly also solves the pair and
  renders the dual animation (the WAV sonifies the first trajectory). With
  a preset, checks 1-3 run at the canonical sigma = 10, rho = 28,
  beta = 8/3 (check 3's benchmark is the rho = 28 exponent, and the stable
  preset has a negative one); check 4 uses the run's trajectory.
- The `stable` preset is rho = 20 (was 24): after the 5 s transient the
  state is within 0.5 of C+ or C- for the second half of its 30 s and ends
  0.04 away at speed 0.4 (tested). rho = 15 or 13 settle faster but sit
  still for most of the 30 s.
- experiment.wl no longer holds parameter blocks: it sets `label` and runs
  main.wl with `--simulation.lorenz.preset=<label>`, so its output is
  identical to the main.wl preset run.
- **Peak limiter (lorenz mode and its presets only).** `config.json` has
  `audio.limiter` enabled with `modes: ["lorenz"]`, ceiling -1 dBFS, attack
  5 ms, release 50 ms; stem-core `RenderAudio` then uses
  `LimitedNormalizeToLoudness`, and main.wl prints one sentence with the
  ceiling, attack, release, maximum gain reduction and resulting loudness.
  Measured (stem-core meter): lorenz mode -21.51 -> -17.02 LUFS (10.22 dB
  maximum reduction), classic -23.57 -> -17.02 (10.85), butterfly -19.65 ->
  -17.02 (5.04), stable -17.64 -> -17.01 (1.45), wild -21.54 -> -17.02
  (11.11), slow -20.95 -> -17.01 (15.64), rho9996 -26.41 -> -17.02 (15.92);
  every peak at -1 dBFS. Rossler is not limited (-17.00, byte-identical to
  before with a fixed seed). The loudest 880 Hz apex events sit on the
  limited peaks: their absolute level changed by -0.5 to +1.3 dB and their
  level against the sound around them by under 0.4 dB, but relative to the
  rest of the file (raised 9.5 dB) they are 8-10 dB less prominent. Set
  `--audio.limiter.enabled=false` to hear the unlimited version.
- Console: every mode ends with the stem-core loudness line
  (`STEMLoudnessLine`) and Timing line (`STEMTimingLine`; lorenz has no
  narration, so intro, pauses and outro are 0 s).

## Sonification design (src/sonify.wl)

`ExportSonification[solution, params, cfg, filePath]` is a thin wrapper
around stem-core's `SonifyTrajectory[trajectory, cfg, filePath, {"apex"}]`
(`SpatialLayer`+`MotionLayer`+`EventLayer`+`MixLayers`) — not a bespoke
per-note synthesizer. The `{t,x,y,z}` solution is augmented with a
finite-difference speed column (`{t,x,y,z,speed}`) before being passed in.

- Pitch axis: `y` (stem-core's `pitch.axis` default), mapped to
  `sonification.pitch.min_hz`/`max_hz` (config.json: 80/1200 Hz)
- Pan axis: `x` (`sonification.spatial.pan_axis = "x"` in config.json)
- Event type: `"apex"` — local maxima of `|y|`, correlating with wing
  crossings (Lorenz) or spiral-cycle completion (Rössler)
- Volume/texture comes from stem-core's `MotionLayer` (tremolo/roughness
  driven by trajectory periodicity and a chaos proxy), not a fixed
  per-extremum envelope
- No scale/root-note option exists in the current implementation — there
  is no `ScaleLookup`/`BuildWaveform` call anywhere in `src/sonify.wl`;
  an earlier pentatonic-scale note synthesizer was replaced by the shared
  stem-core `SonifyTrajectory` pipeline.

## Animation design (src/animate.wl)

- Projects 3D trajectory onto x-z plane (classic butterfly view)
- Colour gradient: blue → cyan → orange → red (early to recent)
- Dark background for contrast
- `ExportDualAnimation` shows two trajectories side-by-side

## Correctness checks (added during the v1.5.0 correctness audit)

Four checks, diagnostic-only (`[PASS]`/`[FAIL]`, never `Exit[1]`), matching
`blackbody/AGENTS.md` §3's convention — this app predated that convention
and had none at all before this audit.

### 1. Check 1 tests a DIFFERENT claim per system — not the same check reused

Lorenz's phase-space divergence `nabla.f = d(fx)/dx+d(fy)/dy+d(fz)/dz` is
exactly `-(sigma+1+beta)` **everywhere in space** — verified by hand first
(`D[sigma*(y-x),x] + D[x*(rho-z)-y,y] + D[x*y-beta*z,z]` simplifies to
`-1-beta-sigma` symbolically, confirmed via WL's own `Simplify` before
writing `LorenzDivergenceCheck`), then checked at several ARBITRARY
`(x,y,z)` points (not points on the attractor — the claim says nothing
about the attractor specifically).

Rössler's divergence is `a+x-c` — genuinely position-dependent (also
verified symbolically first: `D[-y-z,x]+D[x+a*y,y]+D[b+z*(x-c),z]`
simplifies to `a-c+x`). **A "constant divergence" check would be
mathematically wrong for Rössler** — do not write one. `RosslerDivergenceCheck`
instead verifies the position-dependent formula holds pointwise, and the
test suite additionally confirms the computed values are NOT all equal
(a regression guard against someone "fixing" this check to assert
constancy by mistake, which would make it pass for the wrong reason on a
single test point).

Both checks redefine their system's `fx,fy,fz` symbolically (the same
functional form `SolveLorenz`/`SolveRossler`'s `NDSolve` equations use)
and take partial derivatives via `D[]`, rather than hardcoding either
closed form as the computation itself — this is what makes them
independent calculus checks of the claimed formula, not restatements of
it (the standing lesson from `cosmology/AGENTS.md`: a check that shares
its formula with the generator can agree with a wrong generator).

### 2. Equilibrium check: Rössler's equilibria are derived, not assumed

Lorenz's nonzero equilibria `C+/C- = (+-sqrt(beta(rho-1)), +-sqrt(beta(rho-1)),
rho-1)` are the standard textbook result. Rössler's equilibria are NOT
commonly memorized the same way, so `RosslerEquilibria` derives them from
scratch: setting all three RHS components to zero gives `z=-y` (from
`-y-z=0`), `y=-x/a` (from `x+a*y=0`, so `z=x/a`), and substituting into
`b+z(x-c)=0` gives the quadratic `a*x^2-c*x+a*b==0`, roots
`x=(c+-sqrt(c^2-4ab))/2`. Cross-checked against WL's own `Solve` on the
full three-equation system before writing the closed form (both agree).
Both Lorenz's and Rössler's equilibria are then verified by plugging back
into their own RHS function and confirming the result is (numerically)
zero — this is the same "does the claimed exact fact actually hold"
verification pattern as check 1, applied to a different exact fact.

### 3. Lyapunov exponent: renormalization method required, naive growth-rate fit is NOT reliable

A single-perturbation growth-rate fit (integrate once, measure the final
separation, divide by elapsed time) was tried first and rejected: it is
sensitive to the initial transient before the perturbation direction
aligns with the dominant Lyapunov eigendirection, and underestimates
`lambda1` substantially unless the integration window is very long.
`BenettinLyapunov` instead uses the standard renormalization method:
integrate a short fixed interval, measure the growth factor, renormalize
the perturbation back to its original tiny size (keeping its NEW
direction), repeat many times, average the log-growth rate. This
converges quickly because renormalization forces the perturbation to
track the dominant direction after only a few steps, regardless of where
it started.

**A fixed (not random) initial perturbation direction (`{1,0,0}`) works
just as reliably as a random one** — verified across multiple random
seeds and the fixed direction while calibrating `dtRenorm`/`nSteps` below;
using a fixed direction makes the check fully deterministic (no
`SeedRandom` needed, unlike most Monte-Carlo-style checks elsewhere in
this codebase).

**`dtRenorm`/`nSteps` are tuned per system, not shared** — Lorenz
(`dtRenorm=0.2`, `nSteps=400`, 20-time-unit transient) converges
consistently to within ~3% of the commonly-cited `lambda1~0.905`
(`sigma=10,rho=28,beta=8/3`). Rössler's slower spiral-and-fold dynamics
need a longer renormalization interval: `dtRenorm=1.0` gave noisy,
seed-dependent estimates (~0.065-0.094 spread across trials);
`dtRenorm=2.0` (with a 100-time-unit transient, since Rössler's
transient decay is slower) converged consistently to ~0.065-0.069,
matching the commonly-cited `lambda1~0.07` (`a=b=0.2,c=5.7`). Both
figures were computed by this app's own `BenettinLyapunov`, not assumed
from the literature blindly — see the actual computed values in
`README.md`'s correctness-checks section and this task's own report.
Generous tolerance (30% relative) throughout, since this is an empirical
literature comparison, not an exact relation — contrast with checks 1-2's
tight tolerances.

### 4. Boundedness check: the `Overflow[]` gotcha

`Overflow[]` (WL's tag for floating-point overflow) passes BOTH `NumericQ`
and `NumberQ` as `True` — a naive `Max[Abs[...]] < limit` comparison would
silently fail to catch a diverged trajectory (the comparison itself stays
unevaluated rather than returning `True`/`False`). `TrajectoryBoundedCheck`
uses `FreeQ[coords, Overflow[]|Underflow[]|Indeterminate|ComplexInfinity|
DirectedInfinity[___]]` first, THEN checks magnitude — the same pattern
`henon/src/model.wl`'s `TrajectoryIsBounded` discovered and documented.
Not expected to ever fail for this app's own classic-parameter presets
(Lorenz/Rössler are well-behaved at their standard parameter ranges), but
cheap and worth having regardless, the same "removes the failure mode
entirely rather than trusting every future config to stay safe" reasoning
as `henon/AGENTS.md`'s own version of this check.

## GIF/WAV duration sync — `rho9996` stress-test preset (post-audit follow-up)

The cross-app duration-sync fix (`ExportAnimation`/`ExportDualAnimation` now
take `targetDuration = solution[[-1,1]]` instead of a hardcoded `30`) landed
correctly in `experiment.wl` and was verified against the `butterfly` preset.
An external review later caught that `output/lorenz_rho9996_animation.gif`
(`lorenz_rho9996_audio.wav` at its side) still showed the original bug:
GIF=4.50s vs WAV=119.925s, a ~26.6x mismatch, unchanged from the original bug
report.

**Root cause: not a code bug at all — a stale, undocumented output artifact.**
`lorenz_rho9996_*` was never a named preset in `experiment.wl`; grepping the
full git history of this file for "rho9996" finds nothing. The files' mtimes
(2026-06-25) predate both the duration-sync fix (2026-08-12, `bfde133`) and
even the file-naming convention currently in use (`lorenz_<type>_<label>.*`
vs. the old files' `lorenz_<label>_<type>.*` ordering). They were produced by
a one-off local edit of the ACTIVE PRESET block — Sigma=10, Rho=99.96,
Beta=8/3, InitXYZ=(1,1,1), TimeEnd=120, TimeStep=0.005 (recovered from the
stale CSV's own header/last row, since the params were never committed) —
run against the *pre-fix* pipeline, then never regenerated after the fix
landed. Because `output/` is gitignored, `git status` gave no signal that
this file was out of date relative to the code that (correctly) produced it.

**Fix:** added `rho9996` as a proper, documented preset (block F in
`experiment.wl`, alongside the others) instead of leaving it as an
un-reproducible local edit, then ran it through the current (already-correct)
pipeline. Old `lorenz_rho9996_{animation,audio,trajectory}.*` (old naming
scheme) deleted; new `lorenz_{animation,audio,trajectory}_rho9996.*` (current
naming scheme) generated in their place.

Result: GIF=120.000s, WAV=120.000s (240 frames @ 2fps, clamped at
`$MinAnimationFps`) — exact match.

All six `experiment.wl` presets (`classic`, `butterfly`, `stable`, `wild`,
`slow`, `rho9996`) plus `main.wl`'s default `lorenz` and `rossler` runs were
regenerated and measured directly (GIF: frame count x per-frame delay from
the file's own header; WAV: sample count / sample rate from the file's own
header) — not assumed:

| Output          | GIF frames | GIF s   | WAV s   | diff  |
|------------------|-----------:|--------:|--------:|------:|
| lorenz (default) |        150 |  40.500 |  40.000 | 1.25% |
| butterfly        |        150 |  30.000 |  30.000 | 0.00% |
| classic          |        150 |  40.500 |  40.000 | 1.25% |
| rho9996          |        240 | 120.000 | 120.000 | 0.00% |
| slow             |        150 |  60.000 |  60.000 | 0.00% |
| stable           |        150 |  30.000 |  30.000 | 0.00% |
| wild             |        150 |  19.500 |  20.000 | 2.50% |
| rossler          |        150 |  40.500 |  40.000 | 1.25% |

All within the ~3% GIF-format centisecond frame-delay quantization floor
(the same tolerance established across the rest of the 31-app duration-sync
fix); nothing regressed.

## Conventions

- Functions scoped with `Module`
- Parameters always in an `Association`; never global
- SI units throughout
- Tests use `Exit[1]` on failure
- `PrintSummary` uses `STEMPrintN` (stem-core) for the step count line. The
  x/y/z range lines each carry two values (`[min, max]`) and remain as bare
  `Print`. Follow the same rule for any additions: `STEMPrintN` for one value,
  bare `Print` for two.

## Dependencies

- Mathematica or Wolfram Engine (any recent version)
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`
- No external paclets required

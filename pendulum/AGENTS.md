# AGENTS.md — Guidance for Claude Code

This file tells AI coding assistants how to work effectively in this project.

## Project overview

A simple pendulum simulation written in Wolfram Language, runnable entirely
from the terminal via `wolframscript`. Designed as a reusable template for
physics simulation projects. Produces CSV data, an animated GIF, and a
WAV sonification.

## Project structure

- `main.wl`          — Entry point. Runs simulation, correctness checks, exports CSV, GIF, WAV.
- `src/model.wl`     — ODE definitions (`SolvePendulum`, `DoublePendulumModel`),
                       `PendulumEnergy`, `DoublePendulumEnergy`, four correctness
                       checks (see "Correctness checks" below).
- `src/output.wl`    — CSV export (`ExportResults`) and `PrintSummary`, `PrintCorrectnessChecks`.
- `src/animate.wl`   — Animated GIF export (`ExportAnimation`, `PendulumFrame`).
- `src/sonify.wl`    — WAV sonification export (`FindZeroCrossings`, `ExportSonification`).
- `tests/test_model.wl` — Unit tests for the physics and solver.
- `output/`            — Output directory. Do not commit this directory.

## How to run

```bash
# Full run: CSV + GIF + WAV
wolframscript -file main.wl

# Parameter experiments (produces named files in output/)
wolframscript -file experiments.wl

# Tests only
wolframscript -file tests/test_model.wl
```

## Outputs

| File                          | Description                            |
|-------------------------------|----------------------------------------|
| output/results.csv              | Time, angle, velocity, energy per step |
| output/pendulum_animation.gif   | Looping animated GIF of the pendulum   |
| output/pendulum_audio.wav       | Sonification as WAV audio              |

## Conventions

- All source files use `.wl` extension.
- Functions use `Module` for proper variable scoping.
- Parameters are always passed as an `Association` (never as globals).
- Physical quantities use SI units. Variable names include units where helpful.
- Tests use `Exit[1]` on failure so CI tools can detect failures.
- `PrintSummary` uses `STEMPrintN` (stem-core) for every numeric summary line —
  steps computed, max/min angle, initial/final/drift energy. Use `STEMPrintN`
  for any new single-value numeric line; bare `Print` for multi-value lines.

## Important: WAV synthesis

`sonify.wl` uses stem-core's `StemSynthNote` + `ExportAudioBuffer` for all
audio synthesis — not `SoundNote`, `Audio[]`, or MIDI. `ExportAudioBuffer`
wraps samples in `SampledSoundList` (not `Audio[]`), which exports a valid WAV
in headless `wolframscript` sessions. Do not switch to `Audio[]` or `SoundNote`;
both fail silently in terminal contexts on macOS.

## Sonification design (src/sonify.wl)

- Pitch: pendulum angle mapped to `$StemScales["MinorPentatonic"]`, root A3 (220 Hz).
- Duration: each note lasts one half-swing (zero crossing to zero crossing).
- Volume: proportional to angular velocity at each zero crossing.
- Timbre: pure sine (`harmonics = {1.0}`) with decay fraction 1/3 via `StemSynthNote`.
- To change scale: pass a different key from `$StemScales` to `ScaleLookup` in `sonify.wl`.

## Animation design (src/animate.wl)

- Exports an animated GIF at 25 fps by default.
- Bob colour shifts from blue (centre) to red-violet (maximum swing).
- A motion trail shows the recent path of the bob.
- `ExportAnimation[solution, params, file, frameRate, speedup]`
  accepts optional frameRate (default 25) and speedup (default 1.0).

## Correctness checks (added during the v1.5.0 correctness audit)

This app predated `blackbody/AGENTS.md` §3's checks convention and had NO
printed checks at all before this audit — only ad hoc assertions buried in
`tests/test_model.wl`. Four checks now exist, split 2-and-2 between the
two modes (simple and double pendulum are different systems — like
`magnetic/AGENTS.md`'s four modes, each mode prints only the checks that
are actually meaningful for it, not a mechanically-forced four every run).

### 1. Check 1's exact formula is a strict upgrade, not a duplicate, of the old test

`tests/test_model.wl`'s pre-existing test 6 only checked the small-angle
*approximation* (`T=2*Pi*Sqrt[L/g]`) at ONE small amplitude — it could
never have caught a bug that only manifests at large amplitude, because
the approximation itself is only valid there. `ExactPeriodCheck` uses the
TRUE closed-form period, `T=4*Sqrt[L/g]*EllipticK[Sin[theta0/2]^2]`, and
tests it at 10, 45, 90, AND 150 degrees — deliberately spanning well past
where the small-angle approximation would itself start failing, since the
whole point of using the exact formula is that it works everywhere.

**`EllipticK`'s argument convention matters and was verified before use**:
WL's `EllipticK[m]` takes the PARAMETER `m = k^2`, not the modulus `k` —
easy to get backwards. Verified via the small-angle limit before writing
the check: as `theta0->0`, `Sin[theta0/2]^2->0`, and `EllipticK[0]` is
EXACTLY `Pi/2`, giving `T -> 4*Sqrt[L/g]*(Pi/2) = 2*Pi*Sqrt[L/g]`, the
familiar formula — confirmed numerically to match at `theta0=0.001` to
6 decimal places before trusting the formula at large angles where there
is no independent closed-form to cross-check against directly. Then
cross-checked the LARGE-angle case a different way: the exact formula was
verified against a genuine NDSolve-measured period (zero-crossing timing)
at 170 degrees, agreeing to ~1.5e-10 relative error — this is what
actually gives confidence the formula (and its `EllipticK` convention) is
right, not just the small-angle limit.

### 2/3. Energy checks sample MULTIPLE points along the trajectory, not just start/end

A check that only compares `energy[0]` to `energy[tEnd]` could miss a
numerical issue that happens to cancel out by the final sample (e.g. an
error that grows then shrinks back). Both `SimpleEnergyConservationCheck`
and `DoubleEnergyConservationCheck` sample 10 points spread across the
full integration and check the full range, not just the two endpoints.

`DoublePendulumEnergy` is independently re-derived (standard Lagrangian
mechanics: `KE = (1/2)(m1+m2)L1^2*omega1^2 + (1/2)m2*L2^2*omega2^2 +
m2*L1*L2*omega1*omega2*Cos[theta1-theta2]`, `PE = -(m1+m2)*g*L1*Cos[theta1]
- m2*g*L2*Cos[theta2]`) and verified numerically against the app's own
`DoublePendulumModel` trajectory BEFORE writing the check that depends on
it — at the app's own actual NDSolve settings (`Method->"StiffnessSwitching"`,
no explicit `PrecisionGoal`/`AccuracyGoal` override, `dt=0.01`), energy is
conserved to ~2.5e-10 relative over a 20 s integration at the default
120/90-degree initial angles. (An earlier attempt to reproduce this with
`WorkingPrecision->20` on machine-precision inputs failed outright —
`NDSolve::precw` — since the equation coefficients themselves are only
machine precision; the app's own actual default settings, without a
manual precision bump, are what actually matter and are what the check
uses.)

### 4. The chaos-sensitivity threshold is NOT where you'd assume, and the check does not use the run's own configured angle

**Actual measured threshold** (epsilon=1e-4 rad in `theta1`, 20 s
integration, `theta2_0 = 0.75*theta1_0`, the app's own default duration):
divergence ratio stays in the single-to-low-double digits for
`theta1_0` up to 120 degrees — INCLUDING the app's own default
`angle1_deg=120` config value, which does NOT reliably clear a 100x
divergence within 20 s. The transition is sharp, not gradual:

| theta1_0 (deg) | divergence ratio at t=20s |
|---|---|
| 120 (app default) | ~6x |
| 121 | ~3x |
| 122 | ~17x |
| 123 | ~72x |
| 124 | ~284x |
| 125 | ~85,000x |
| 130 | ~90,000x to ~5,700,000x (across a 100x range of perturbation sizes) |

This does NOT mean the double pendulum "isn't chaotic" at 120 degrees in
the formal sense (positive Lyapunov exponent) — it means a tiny (1e-4 rad)
perturbation genuinely takes longer than 20 simulated seconds to grow
100x at that specific amplitude/energy. `ChaosSensitivityCheck` therefore
uses its OWN fixed, independent test amplitude (130 degrees by default,
comfortably past the transition) rather than whatever `angle1_deg` the
active run happens to be configured with — verified robust across a
100x range of perturbation sizes (`epsilon` from 1e-5 to 1e-3 all gave
ratios from ~89,000x to ~5,700,000x at 130 degrees, so the check is not
sensitive to the exact `epsilon` chosen, unlike the knife-edge behaviour
right at the ~123-124 degree transition). `main.wl`'s own printed
"(chaotic above ~60 deg)" line was adjusted to point at this distinction
explicitly rather than sit next to the check's very different 130-degree
figure looking like a contradiction — both claims are true, they are
just different claims (qualitative chaos onset vs. a specific >=100x-in-
20s divergence threshold).

## When modifying the physics (src/model.wl)

- If you change the ODE, update `PendulumEnergy` to match.
- Always run the tests after changes to `src/model.wl`.
- The sonification and animation read from the `solution` list directly,
  so they adapt automatically to any new simulation.

## Dependencies

- Mathematica or Wolfram Engine (any recent version)
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`
- No external paclets required

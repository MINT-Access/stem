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
- Plot bounds (`TrajectoryPlotRange`), image dimensions (`FrameImageSize`),
  and marker sizes are all computed from the actual simulated trajectory,
  not hardcoded — see "Animation framing" below for why, and for a
  verification pattern worth reusing before adding any new animation.

## Animation framing: the double-pendulum clipping bug (fixed post-v1.5.0)

**The bug.** `double_animation.gif`'s default preset (angle1=120°,
angle2=170°) clipped visible content — a rod, its joint, or the whole
second bob — on 383/501 frames (76%). A sighted reviewer caught this
before publication; nothing in the app's own tests or correctness
checks would have, because those check physics (energy conservation,
period, chaos sensitivity), not rendering.

**Root cause.** `DoublePendulumFrame`/`PendulumFrame` used a hardcoded
`PlotRange` sized by eyeballing one configuration, not derived from
what the simulation actually produces. The double pendulum's default
angles are energetic enough to make `theta1`/`theta2` accumulate past
±360° (multiple full rotations, confirmed via `MinMax` on the solved
trajectory) — legitimate, not a bug (see `DoubleEnergyConservationCheck`
passing to ~1e-8 on the same run) — so the bob's actual swept region
is close to the full physical disk of radius `L1+L2`, while the old
fixed range (`{-2.3,2.3} x {-2.5,0.4}`) assumed a much smaller, mostly
downward arc.

**The fix — three parts, not one:**
1. `TrajectoryPlotRange[xs, ys, maxReach]` computes bounds from *every*
   (x,y) point of *both* bobs across the *entire* simulated trajectory
   (not the frame-subsampled solution), adds a margin that's the larger
   of 18% of the observed extent or 12% of `maxReach` (the fixed floor
   keeps low-amplitude runs from looking cropped-tight), then clamps to
   `maxReach*(1+renderPadFrac)` — `maxReach` (`L` for the simple
   pendulum, `L1+L2` for the double) is the exact, trajectory-independent
   kinematic limit, so this clamp can never itself be the source of a
   clipping bug. Same logic drives both axes and both pendulum modes.
2. `FrameImageSize` matches the raster's pixel aspect ratio to the
   `PlotRange`'s data aspect ratio. This is *not* cosmetic: Graphics's
   default `AspectRatio` (1/GoldenRatio) has nothing to do with the
   `PlotRange`'s own aspect ratio, so a mismatched fixed `ImageSize` (as
   the code had before) makes Mathematica **letterbox the plot inside
   the raster using the same Background colour for the padding as for
   the in-plot background** — invisibly. Confirmed empirically: a marker
   placed exactly at the *old* `PlotRange`'s edge rendered ~147px away
   from the actual image edge in a 900px-tall raster. Any bounding-box
   check comparing content to the raw image edge would have reported a
   huge, false margin on a badly-clipped frame. Matching the aspect
   ratio removes the letterboxing, which is what makes part 3 below
   meaningful. (Side benefit: bob/pivot disks had been rendering as
   ellipses, not circles, under the old mismatched aspect — ~11px x 4px
   for a nominally-round marker — now fixed too.)
3. Bob/pivot marker radii, previously fixed data-unit constants (0.07,
   0.04/0.055), now scale with `L` (simple) / `(L1+L2)/2` (double).
   Framing is tight around the real trajectory now instead of a
   one-size-fits-all oversized box, so a fixed-size marker would
   otherwise look absurd for a short preset (`short_pendulum`, L=0.25m)
   — a giant bob dwarfing its own rod — that the old oversized frame
   used to mask by making everything look small.

   **This introduced a real regression in its own first draft**, caught
   only by re-running the Step-4 verification script below: making the
   bob radius scale with `L` while leaving `TrajectoryPlotRange`'s
   safety-clamp pad as a flat constant (0.12, sized for the L≈1 default)
   meant `long_pendulum` (L=2, bob radius 0.07×2=0.14) had a bob bigger
   than its own clamp pad — clipped at the bottom on 100/376 frames
   (26.6%). Fixed by making the pad scale with `maxReach` too
   (`renderPadFrac*maxReach`, 0.12× — comfortably above both the 0.07×
   simple-pendulum and 0.035× double-pendulum bob-radius-to-maxReach
   ratios). Left as a cautionary note: a margin/clamp constant that
   silently assumes something about the *renderer* (marker size) as
   well as the *trajectory* will break the moment either side changes
   independently — rescale by the same physical quantity on both sides,
   or better, verify pixels rather than trust the arithmetic.

**Which animations were actually affected:** every animation this app
produces uses the same two frame-rendering functions, so all of them
were exposed to the same bug class, not just `double_animation.gif`.
Two were confirmed to actually clip on real frames before the fix:
`double_animation.gif` (383/501 frames, ~76%, the one that got caught)
and, once marker scaling was added, transiently `long_pendulum_animation.gif`
(100/376 frames, 26.6%, self-inflicted and caught by re-running
verification — see above). The rest of the simple-pendulum presets
(`baseline`, `simple`, `large_angle`, `moon_gravity`, `pushed`,
`short_pendulum`) never actually clipped under the *old* fixed range —
their amplitudes (≤69°, or the ~47° pushed reaches) keep the bob well
inside `{-1.4,1.4} x {-1.4,0.25}` — but they still benefited from the
fix: the old fixed frame left most presets looking small and
under-framed (e.g. `short_pendulum`'s bob occupying a few percent of a
huge empty box), which the new trajectory-fit bounds correct as a side
effect of computing bounds the right way, not as a separate change.

**Verification pattern (`tests/verify_animation_frames.py`) — reuse
this for any future animation, here or elsewhere in this project:**

Trusting the bounds arithmetic is not enough — the letterboxing
discovery above only came from actually rendering pixels and measuring
them, and the marker-scaling regression only came from re-running that
same measurement after a code change that looked correct on paper. The
script: loads every frame of a GIF, classifies each pixel as
"background/support-line" (near-achromatic AND light — a single rule
that captures both the pale background and the grey support line,
including antialiased blends between them, without misclassifying the
darker pure-grey rod/pivot colours or any chromatic rod/bob/trail
colour) or "content", takes the content bounding box per frame, and
requires a genuine (≥3px) margin from every image edge on *every*
frame, not a sample — reporting exact violating frames and margins,
not just pass/fail, the same way this app's `main.wl` correctness
checks report measured numbers rather than bare assertions. Run it
against every GIF in `output/` with no arguments, or against specific
paths. It caught both real bugs in this fix (the original 76% clipping
and the self-inflicted 26.6% long_pendulum regression) and confirmed
two deliberately extreme stress-test configs (both rods started at
179°/179°, and an asymmetric-length 150°/-160° config — both driven
into many full rotations) stayed correctly bounded, clamped to exactly
`maxReach*(1+renderPadFrac)` as designed.

**A general lesson, not specific to this bug:** the raw pixel edges of
an exported raster are not reliably the same rectangle as the plot's
mathematical range unless the image's aspect ratio is explicitly made
to match the data's aspect ratio. A "does content touch the image
edge" check is not meaningful — and can silently pass on a badly
clipped animation — until that's confirmed true for the specific
rendering pipeline being checked, not assumed.

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

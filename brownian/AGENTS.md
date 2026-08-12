# Brownian — Agent Guide

## Project overview

Sonifies Brownian motion: the random walk a microscopic particle follows
under countless collisions with surrounding fluid molecules, first
observed by Robert Brown (1827) and explained by Einstein (1905) as
direct evidence for the physical reality of atoms — confirmed
quantitatively by Jean Perrin (1908-1909, Nobel Prize 1926). Three modes:

| Mode | Physics | Output |
|------|---------|--------|
| `walk` (default) | A single 2D random walk | Narrated continuous-trajectory WAV; growing-path GIF; static PNG |
| `ensemble` | Many independent walkers, averaged | Rising-glissando WAV whose slope visibly decays; RMS(t)-vs-theory PNG |
| `temperature` | D(T) via Stokes-Einstein, representative walks | Per-temperature-frame WAV; small-multiples PNG |

Closest sibling apps: `lorenz/` and `henon/attractor` (the continuous-
trajectory sonification technique `walk` mode reuses, with one
deliberate deviation — see design decision 1), `compton/sweep` and
`relativity/`'s chirp (the phase-accumulation glissando technique
`ensemble` mode reuses), `thermo/distribution` (the per-temperature-
step-frame concatenation idiom `temperature` mode reuses), and `clt/`
(this app's random walk IS a running sum of iid random variables —
literally the Central Limit Theorem setup applied to spatial
displacement instead of an abstract sample mean; see design decision 4
for the direct comparison between the two apps' kurtosis checks).

## Key design decisions (read before modifying sonify.wl or model.wl)

### 1. `walk` mode's volume comes from r (displacement from origin), NOT speed — a deliberate deviation from this codebase's usual convention

Every other continuous-trajectory app in this codebase (`lorenz/`,
`henon/attractor`) drives volume from kinematic speed via stem-core's
`MotionLayer`/`SpatialLayer`. This app instead feeds `r = sqrt(x^2+y^2)`
— the particle's distance from where it started — into the
trajectory's own "speed" column (column 5 of the `{t,x,y,z,speed}`
matrix `SpatialLayer`/`MotionLayer` read), so volume tracks displacement
instead of local jitter.

This is deliberate, not an oversight: local jitter (kinematic speed) is
present at EVERY temperature and EVERY diffusion coefficient — it says
nothing about diffusion specifically, since a fast-jittering particle
that never wanders anywhere and a fast-jittering particle actively
diffusing away from its start would sound identical under a speed-
driven volume. `r`'s slow, noisy, net growth over time IS the
phenomenon this app exists to make audible — "how far has it wandered
from where it started" is the physically meaningful quantity for a
diffusing particle.

**Side effect worth knowing about**: stem-core's `MotionLayer` ALSO
reads the same "speed" column for its roughness/envelope/tremolo
modulation (`lyapunovProxy = Variance[Differences[speed]]/Variance
[speed]`, `envelopeArr = Rescale[speedInterp,...]`). Feeding `r` into
that column means these secondary effects now respond to `r`'s own
fluctuation properties too, not true kinematic speed — in practice this
means the audio's envelope rises gently over the walk's duration
(tracking the particle's growing average distance from origin), which
if anything REINFORCES the "diffusing away from start" framing rather
than fighting it, but it is a consequence of the substitution worth
knowing about if you touch this code, not just the intended pan/pitch/
volume mapping.

### 2. `walk` mode calls the three sonification layers directly, not the one-shot `SonifyTrajectory[..., filePath]`

Same reasoning and same pattern as `henon/src/sonify.wl`'s
`AttractorStereoBuffer` and `montecarlo/src/sonify.wl`: `SonifyTrajectory`
writes straight to disk via `RenderAudio` and returns only a file path,
with no way to prepend a spoken intro afterwards. `WalkStereoBuffer`
instead calls `SpatialLayer`/`MotionLayer`/`EventLayer` -> `MixLayers`
directly and returns the `{left,right}` arrays; `main.wl` prepends the
intro buffer, then exports once. `temperature` mode's per-frame calls to
`WalkStereoBuffer` reuse this same function for each short snippet.

### 3. `ensemble` mode interpolates a computed Monte Carlo curve, unlike compton/relativity's closed-form recompute

`compton/sweep` and `relativity/`'s chirp both recompute their governing
formula at FULL AUDIO-SAMPLE resolution for the phase-accumulation
glissando, because Compton's formula and the PN inspiral frequency are
cheap closed-form expressions, evaluable at any instant. An ensemble
average has no such closed form — it is intrinsically a statistic over
many simulated walkers, computed once at the model's own `nSteps`
resolution (not re-simulated at 44100 samples/second, which would be
both enormously wasteful and would reintroduce raw single-sample noise
that only averages out with a fixed, finite step count). `ensemble`
mode therefore computes `EnsembleModel`'s real RMS(t) curve once, then
`Interpolation[...]`s it up to audio-sample resolution before handing
the resulting frequency array to the same `Accumulate`-based phase
technique. The frequency mapping itself is linear-in-RMS -> log-in-Hz
(`freqMin*(freqMax/freqMin)^normRms`), which preserves the sqrt(t)
concavity of the underlying physics in the audible pitch-vs-time curve,
rather than compressing it the way a log-RMS mapping would.

### 4. Check 3 is a genuinely different (and stronger) claim than clt/'s own kurtosis check — not a copy

`clt/`'s `KurtosisDecayCheck` verifies that a general source
distribution's standardized sample mean's excess kurtosis decays
ASYMPTOTICALLY as `(source excess kurtosis)/N` — at `clt/`'s own test
point (`N=30`, uniform source), this predicts (and finds) excess
kurtosis around `-1.2/30 ~= -0.04`, clearly nonzero. This app's random
walk is a sum of iid GAUSSIAN steps, and a sum of Gaussians is EXACTLY
Gaussian at every `N >= 1` — the prediction here is exactly 0, tested at
a much SMALLER `N=8`, not merely "closer to 0 than at N=1" the way a
weaker version of this check might read. Both facts are true
simultaneously and are not in tension: `clt/`'s check is about a general
asymptotic law; this app's check is about an exact algebraic identity
that happens to be a special case where the asymptotic law's numerator
(the source's own excess kurtosis) is already zero. State this contrast
explicitly if you touch either check — it's a genuinely illuminating
side-by-side with a sibling app, not a redundant re-test.

### 5. All four correctness checks exercise the real Monte Carlo step-generation code, not a restatement of the formulas

`NetDisplacementSample` actually accumulates `nSteps` individual
Gaussian draws per walker (`Total[dx,{2}]`) rather than shortcutting
through the mathematically-equivalent single-draw
`Normal(0, sigma*Sqrt[nSteps])` — the latter would always give an exact
Gaussian by construction regardless of any bug in the real step-by-step
simulator, making checks 1, 3, and 4 vacuous tests of arithmetic rather
than genuine validations of the code `walk`/`ensemble`/`temperature`
modes actually run. This mirrors the same discipline `clt/AGENTS.md`
documents for its own Monte Carlo checks (verify the actual generator,
not a re-derivation of what it's supposed to produce).

### 6. Two numeric claims from the original build brief were corrected after verification — the standing "verify, don't trust" lesson

Per `compton/AGENTS.md` design decision 8 and `fluid/AGENTS.md`'s three
documented build-spec corrections, every specific numeric claim in this
app's own build brief was checked before use, not assumed:

- **"Water's viscosity roughly halving from 0C to 40C"** — checked
  against standard reference values (1.792 mPa·s at 0C, 0.6527 mPa·s at
  40C): the actual ratio is **~2.75x, not ~2x**. "Halving" undersells
  the real temperature dependence by a significant margin (it's closer
  to a two-thirds drop than a one-half drop). `StokesEinsteinD`'s
  docstring and `README.md` state the corrected ~2.7x figure with its
  source values, not the original "roughly halving" claim.
- **"Sweep T over ~250K-350K, comfortably spanning water's liquid range
  near room temperature"** — 250K is **-23.15C, well below water's
  freezing point (273.15K)**; water is not liquid there, so Stokes-
  Einstein's fixed-viscosity assumption (already a simplification for
  LIQUID water) wouldn't even apply to the phase actually present.
  `temp_min`/`temp_max` default to **275K-350K** instead (2C to 77C),
  safely on the liquid side at both ends.

Two claims WERE independently verified and used as-is: `$kB =
1.380649e-23 J/K` (the exact 2019 SI redefinition value, not measured or
rounded), and the Stokes-Einstein realistic-scale range (a 1-micron-
radius particle in room-temperature water gives `D ~ 2.15e-13 m^2/s`,
comfortably inside the claimed ~1e-13 to 1e-12 m^2/s range — see check 2).

### 7. `temperature` mode's audible "hotter = more agitated" effect is real but modest, and this app says so plainly rather than exaggerating it

Because `D` scales LINEARLY with `T` (Stokes-Einstein, viscosity held
fixed), and water's own realistic liquid-range temperature span is
capped at a ratio of about `373/273 ~= 1.37` (freezing to boiling, less
in practice since both endpoints need a safety margin), the diffusion
coefficient — and therefore the per-step jiggle amplitude, which scales
as `sqrt(D)` — can only vary by roughly `sqrt(1.3) ~= 1.14`, i.e. about a
14% amplitude difference between this app's coldest and hottest default
steps. This is a REAL, correctly-directioned effect (hotter genuinely is
more agitated), but it is NOT dramatic, and `temperature` mode does not
try to make it sound more dramatic than it physically is — the same
honesty-over-drama precedent `compton/AGENTS.md` design decision 5
documents for `scatter` mode's historically-accurate-but-modest pitch
drop. If you want a more pronounced illustrative effect, holding
viscosity fixed while additionally exaggerating the temperature range
beyond real liquid water would misrepresent the physics; don't do that
without saying so explicitly and separating it from the physically
accurate default.

### 8. `BuildTemperatureAudio` overrides cfg's shared `sonification.duration` per frame — a required override, not a stylistic choice

`walk` mode's audio duration is controlled by the shared
`sonification.duration` config key (default 10s), read once by
`SpatialLayer` when `WalkStereoBuffer` is called on the FULL walk. But
`temperature` mode calls `WalkStereoBuffer` once per short per-
temperature snippet (`nStepsPerFrame`, default 40 steps) — without an
override, each of these short snippets would ALSO try to stretch across
the full shared duration (6 temperature steps x 10s each = 60s of audio
from a handful of 40-step walks), which is both wasteful and pointless.
`BuildTemperatureAudio` therefore `DeepMerge`s a dedicated
`frame_duration` (default 3.0s) into a per-call copy of `cfg` before
each `WalkStereoBuffer` call — the same "explicit dedicated duration
parameter, not the shared app-wide one" pattern `thermo/distribution`
and `blackbody/star` use for their own per-step frames.

### 9. GIF/WAV duration sync (fixed post-v1.5.0)

**The bug.** `ExportWalkAnimation` (the only GIF this app produces —
`ensemble` and `temperature` modes are PNG-only, unaffected) sampled a
fixed `nFrames` (default 100) at a fixed 12fps, entirely decoupled from
the WAV's actual length, which includes a spoken-TTS intro on top of the
walk sonification proper. Measured before the fix: `brownian_walk.gif`
(and both `experiments.wl` presets, `walk_default`/`walk_larger_particle`,
which share the same default `nSteps`/`sonification.duration`) were all
8.0s against a 38.07s WAV (4.76x).

**The fix.** `ExportWalkAnimation` now takes `targetDuration` plus
`nFrames` as a RENDER BUDGET (default 150), with `frameRate =
Clip[nFrames/targetDuration, {2,30}]` and `actualNFrames` recomputed from
the clamped rate so playback equals `targetDuration` exactly — same
pattern as `lorenz/src/animate.wl`. Getting `targetDuration` right
required reordering `main.wl`'s `walk`-mode pipeline: the WAV's true
length is only known *after* `Export` writes it (TTS intro length isn't
predictable from the text), so audio synthesis now runs BEFORE animation
rendering (was the reverse), and the animation call uses `wavDuration =
N[Length[finalLeft]] / sr` captured right after export.
`experiments.wl` already computed `totalDurSec` before its
`ExportWalkAnimation` call (audio was already synthesised first there),
so only the call itself needed the new argument.

**Verification.** Default `walk` run: 8.0s → 38.0s GIF (audio 38.07s,
4.76x → 1.00x).

## Project structure

```
brownian/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json            — default simulation parameters
  experiments.wl          — 6 curated preset invocations (walk, ensemble, temperature,
                          larger particle, larger ensemble, wider temperature sweep)
  LISTENING_GUIDE.md       — user-facing recommended listening sequence
  AGENTS.md                 — this file
  src/
    model.wl                 — StokesEinsteinD, WalkTrajectory, NetDisplacementSample,
                          EnsembleModel, four correctness checks
    sonify.wl                  — WalkStereoBuffer (lorenz/henon-style, via
                          SpatialLayer/MotionLayer/EventLayer/MixLayers directly —
                          see decisions 1-2), EnsembleGlissandoBuffer (compton/
                          relativity-style phase accumulation on an interpolated
                          Monte Carlo curve — see decision 3), BuildTemperatureAudio
                          (thermo-style per-step-frame concatenation — see decision 8)
    speech.wl                   — Spoken intro synthesis (SpeechSynthesize -> platform
                          TTS -> text-only fallback), BuildXIntroText per mode
    animate.wl                    — walk growing-path GIF/PNG, ensemble RMS(t)-vs-
                          individuals-vs-theory PNG, temperature small-multiples PNG
    output.wl                      — Export*CSV per mode, Print*Summary per mode
  tests/
    test_model.wl                 — unit tests (Stokes-Einstein scaling, walk/ensemble
                          shapes, all four checks, clt/ kurtosis contrast, liquid-
                          range sanity)
  output/                          — generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                            # walk, 1 micron, water, room temp
wolframscript -file main.wl -- --simulation.mode=ensemble               # 150-walker ensemble, sqrt(t) glissando
wolframscript -file main.wl -- --simulation.mode=temperature            # D(T) sweep, 275K-350K
wolframscript -file main.wl -- --simulation.brownian.particle_radius_um=5.0  # a larger, less agitated particle
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks

All four run unconditionally, every invocation, regardless of mode,
always at canonical parameters (1 micron particle radius, water
viscosity, room temperature, dt=0.01s — see design decision 5 for why
all four exercise the actual Monte Carlo code, not a formula restatement):

1. **MSD scaling** — empirical `<r^2(t)>` from a real ensemble matches
   `4Dt` within 5% (calibrated: typical error under 1% across 5 seeds).
2. **Stokes-Einstein realistic scale** — `D` at 1-micron/water/room-temp
   parameters lands in the well-known ~1e-13 to 1e-12 m^2/s range.
3. **Exact-zero excess kurtosis at N=8** — see design decision 4 for the
   direct contrast with `clt/`'s own (nonzero, asymptotic) kurtosis check.
4. **sqrt(t) growth shape** — RMS ratio between two step counts (a
   factor of 4 apart) matches the predicted `sqrt(4)=2` within 5%,
   explicitly ruling out linear-in-t (ballistic) growth.

## Common pitfalls

1. **`tolerance_?NumericQ:0.05` in a function signature parses WRONG**
   — binds as `tolerance_ ? (NumericQ:0.05)`, not
   `Optional[tolerance_?NumericQ, 0.05]` as intended; the DownValue
   exists but silently never matches any call. Same pitfall documented
   in `henon/AGENTS.md` pitfall 1 and every prior v1.5.0 app's
   `AGENTS.md`; fixed here by dropping the `?NumericQ` test on optional
   parameters (`tolerance_:0.05`).
2. **`D` is a Protected built-in symbol (the differentiation operator)**
   — `D = StokesEinsteinD[...]` fails with `Set::wrsym: Symbol D is
   Protected` and silently leaves `D` unassigned (later uses then print
   the literal unevaluated expression `FmtN[D, 4]` instead of a number).
   `main.wl`/`experiments.wl` use `Dcoeff` throughout instead of `D` for
   the diffusion coefficient variable. `model.wl`'s own functions are
   unaffected since they use `D` only as a formal PARAMETER name inside
   `Module`/function definitions, which shadows the global symbol
   locally and doesn't trigger the protection — the issue is specific to
   top-level `main.wl`/`experiments.wl` assignment.
3. **A short random-walk snippet inherits `walk` mode's own
   sonification technique inside `temperature` mode** — `WalkStereoBuffer`
   is called once per temperature step in `BuildTemperatureAudio`, always
   with a per-frame duration override (design decision 8); forgetting
   that override is the one way to silently regress this mode's runtime
   from seconds to minutes.
4. **The temperature range in this app's own build brief (250K-350K)
   included an unphysical value** — see design decision 6's correction.
   If you widen `temp_min`/`temp_max` beyond the corrected defaults,
   re-verify both bounds stay strictly between 273.15K and 373.15K.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `SpatialLayer`, `MotionLayer`, `EventLayer`, `MixLayers` (`walk`/
  `temperature` modes, called directly rather than via
  `SonifyTrajectory` — see decision 2), `STEMHeading`, `STEMSection`,
  `STEMSay`, `STEMPrintN`, `STEMDescribeWAV`, `STEMDescribeGIF`,
  `STEMDescribeCSV`, `FmtN`, `STEMPlayCmd`, `NormalizeBuffer`,
  `ExportGIF`, `ExportCSV`, `EnsureDir`.
- **Mathematica/WL**: `RandomVariate`/`NormalDistribution` (step
  generation), `Accumulate` (both random-walk path integration and the
  `ensemble` glissando's phase accumulation), `Interpolation` (ensemble
  RMS(t) curve, upsampled to audio-sample resolution), `Kurtosis` (check
  3), `Sound`, `SampledSoundList`, `Graphics`, `GraphicsGrid`, `Export`,
  `SpeechSynthesize`, `AudioQ`, `AudioData`, `AudioSampleRate`,
  `RunProcess` (platform TTS fallback), `Import` (reading TTS-generated
  WAV files).

## Speech synthesis note

`speech.wl`'s three-tier fallback (`SpeechSynthesize[]` -> platform TTS
-> text-only `STEMSay`) duplicates the pattern already used in
`henon/src/speech.wl`, `dynamical/src/speech.wl`, and several other
apps' `speech.wl` files — still out of scope for stem-core consolidation
per every prior app's own build spec.

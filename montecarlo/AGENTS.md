# Montecarlo — Agent Guide

## Project overview

Sonifies the 2D ferromagnetic Ising model via the Metropolis Monte
Carlo algorithm: a square lattice of ±1 spins with an exact analytic
critical temperature (Onsager 1944, T_c = 2J/k / ln(1+√2) ≈ 2.2692 in
J=k=1 units).

| Mode | Physics | Output |
|------|---------|--------|
| `sweep` (default) | Descend T through T_c, 50 steps | Stereo WAV; two-panel (grid + M(T)) GIF |
| `critical` | Fixed at T_c (or any T via `T_fixed`) | Stereo WAV; single-panel grid GIF |
| `quench` | Instantaneous T_hot -> T_cold drop | Stereo WAV; domain-coarsening grid GIF |

## Animation framing: GIF/WAV duration sync (fixed post-v1.5.0)

**The bug.** Every GIF this app produces played for a fixed 6.00s
(60 frames at a hardcoded 10 fps in `ExportGIF`), regardless of how
long its matching WAV actually ran. Measured before the fix: `sweep.gif`
6.00s vs. `sweep_audio.wav` 81.41s (13.6x); `critical.gif` 6.00s vs.
`critical_audio.wav` 260.42s (43.4x, the worst case — a 64x64
`critical` run); `quench_large_animation.gif` 6.00s vs.
`quench_large_audio.wav` 245.76s (41.0x). Every one of the ten GIF/WAV
pairs in `output/` was affected, with ratios ranging 10.2x-43.4x — the
GIF always finished almost instantly while the audio kept playing for
a minute or several minutes.

**Root cause.** `AnimateSweep`/`AnimateCritical`/`AnimateQuench` in
`src/animate.wl` took a fixed `nFrames_:60` and called
`ExportGIF[frames, outGIF, 10]` with a literal 10 fps — both constants
completely decoupled from `SonifyIsingRun`'s actual audio length. This
app is sweep/iteration-indexed, not time-ODE, but the underlying bug is
the same class documented in `lorenz/AGENTS.md`/`dynamical/AGENTS.md`:
a hardcoded frame budget and frame rate with no relationship to how
long the corresponding WAV plays. Montecarlo's WAV duration is not a
solved trajectory time value — it comes from `sonify.wl`'s
`$maxSpatialSnapshots` (60 evenly-spaced sweep snapshots) times the
per-snapshot Hilbert-scan length (`nPixels * pixel_duration`, itself
`lattice_size^2 * pixel_duration`), stored as `totalDuration` in
`SonifyIsingRun`'s return Association, plus (in `main.wl`'s modes only)
a prepended spoken intro + pause.

**The fix.** `AnimateSweep`/`AnimateCritical`/`AnimateQuench` now take
a required `targetDuration` argument and an `nFrames` *render budget*
(default 150, was previously the literal frame count). Frame rate is
solved as `nFrames/targetDuration` and clamped to `[$MinAnimationFps,
$MaxAnimationFps] = [2, 30]` fps so a short run (e.g. the 61.44s
`*_default` presets) doesn't demand a strobing rate and a long one
(e.g. the 260s 64x64 `critical` run) doesn't demand an implausibly slow
one; the frame *count* is recomputed as `Round[frameRate *
targetDuration]` at the clamp boundary so playback duration always
equals `targetDuration` exactly, not just approximately (same
`ExportAnimation`/`AnimateSweepBifurcation` pattern as `lorenz/` and
`dynamical/`, adapted to montecarlo's grid-snapshot indexing instead of
a solved-trajectory time axis). Each function returns
`{actualNFrames, frameRate}`. Call sites were updated to supply the
right duration for each context: `main.wl` captures
`totalDur = ExportWithIntro[...]` (the full exported WAV length,
intro included) and passes that; `experiments.wl` (which exports
without a spoken intro via `RunToFile`) passes
`sonifyResult["totalDuration"]` directly. Both now capture the
returned `{frames, fps}` and report it via `STEMDescribeGIF[outGIF,
frames, fps]` instead of the previous hardcoded `STEMDescribeGIF[outGIF,
nFramesRendered, 10]`.

**Verification.** Numeric before/after duration measurements (Python,
`PIL.ImageSequence` for GIF frame-duration sums, `wave` for WAV sample
counts) were taken for all ten GIF/WAV pairs in `output/` before
editing any code, confirming the 10.2x-43.4x mismatch above. All ten
were then regenerated after the fix — `wolframscript -file main.wl`
(default `sweep`, plus `--simulation.mode=critical
--simulation.montecarlo.lattice_size=64` and `--simulation.mode=quench`
to reproduce the bare `critical.gif`/`quench.gif` cases) and
`wolframscript -file experiments.wl` (all 7 presets) — and re-measured
with the identical Python method:

| GIF | before (gif / wav / ratio) | after (gif / wav / ratio) |
|---|---|---|
| `critical.gif` | 6.00s / 260.42s / 43.4x | 260.50s / 260.42s / 1.000x |
| `quench_large_animation.gif` | 6.00s / 245.76s / 41.0x | 246.00s / 245.76s / 0.999x |
| `sweep.gif` | 6.00s / 81.41s / 13.6x | 81.50s / 81.41s / 0.999x |
| `quench.gif` | 6.00s / 77.63s / 12.9x | 77.50s / 77.63s / 1.002x |
| `sweep_default_animation.gif` | 6.00s / 61.44s / 10.2x | 61.50s / 61.44s / 0.999x |
| `sweep_fine_animation.gif` | 6.00s / 61.44s / 10.2x | 61.50s / 61.44s / 0.999x |
| `critical_default_animation.gif` | 6.00s / 61.44s / 10.2x | 61.50s / 61.44s / 0.999x |
| `critical_above_animation.gif` | 6.00s / 61.44s / 10.2x | 61.50s / 61.44s / 0.999x |
| `critical_below_animation.gif` | 6.00s / 61.44s / 10.2x | 61.50s / 61.44s / 0.999x |
| `quench_default_animation.gif` | 6.00s / 61.44s / 10.2x | 61.50s / 61.44s / 0.999x |

All ten pairs now land within one frame period (≤0.15s) of their WAV's
actual duration — the 260.42s `critical` case (64x64 lattice, the
worst pre-fix mismatch) clamps to the 2 fps floor, rendering
`Round[2 * 260.42] = 521` frames for exactly 260.5s, matching the
hand-computed prediction made before this run. `wolframscript -file
tests/test_model.wl` (the app's only test file) was also re-run
post-fix: **19 passed, 0 failed** — no regressions in the physics
model, as expected since this fix touches only animation export.

## Key design decisions (read before modifying sonify.wl)

### 1. SpatialLayer/MotionLayer directly, not SonifyTrajectory's generic EventLayer

The build spec calls for "the stem-core SonifyTrajectory pipeline" for
the global-observable layer. `SonifyTrajectory` itself is
`SpatialLayer + MotionLayer + EventLayer + MixLayers + RenderAudio` in
one call — but `EventLayer` only supports two hardcoded event types
("apex": local maxima of |y| at 880 Hz; "crossing": sign changes of x
at 440 Hz), and this app needs three custom events with specific
frequencies/durations that don't match those (T_c crossing at 440 Hz/
150ms, magnetisation sign flip at 220 Hz/50ms, susceptibility peak at
660 Hz/100ms) detected on non-standard columns (T_c crossing needs the
*temperature* series, which isn't even one of the trajectory's four
columns). So `sonify.wl` calls `SpatialLayer`/`MotionLayer` directly
(genuine stem-core continuous-carrier machinery — satisfying the
spec's intent) and mixes in a custom event buffer via `MixLayers`,
exactly the pattern `cellular/`'s original (pre-run-length-refactor)
sonify.wl used, and the same reasoning `dynamical/AGENTS.md` documents
for its own EventLayer deviation.

**Trajectory column assignment** (`BuildObservableTrajectory`):
`x = e(t)` (pan, SpatialLayer's default `panAxis`), `y = |M(t)|`
(pitch, default `pitchAxis`), `z = 0` (unused), `speed = |dM/dt|`
(volume). This was chosen so pan and pitch land on SpatialLayer's
*default* axis assignments with no config override needed.

### 2. `sonification.duration` must be injected via DeepMerge before SpatialLayer/MotionLayer

`$HardcodedDefaults` in stem-core always supplies
`sonification.duration` (10.0) once `LoadConfig` merges it in —
`SpatialLayer`/`MotionLayer` will silently use that stale 10.0 instead
of this run's actual computed duration unless it's overridden via
`DeepMerge` first. This bit `sonify.wl` during development: omitting
the `DeepMerge` produced a `Thread::tdlen` "objects of unequal length"
error when mixing the resulting (wrongly-sized) carrier buffer against
the correctly-sized spatial layer — the same pitfall documented in
`cellular/AGENTS.md` and `dynamical/AGENTS.md`. `SonifyIsingRun`'s
`cfgDur = DeepMerge[cfg, <|"sonification"->"duration"->totalDuration|>]`
exists specifically for this.

### 3. Layer 2 (Hilbert scan) uses cellular/'s run-length technique, not one tone per pixel

The spec's default `pixel_duration` (0.001 s) is shorter than one wave
cycle even at the *low* end of the two-tone mapping (C3 = 130.8 Hz has
a ~7.6 ms period) — a literal one-`StemSynthNote`-per-pixel synthesis
would be an inaudible click train regardless of the underlying spin
pattern, defeating the entire point ("long runs of the same pitch mean
large aligned domains"). Instead, `HilbertRunLengthTones` groups
consecutive equal-spin pixels (in Hilbert order) into a single held
tone of duration `runLength * pixelDuration` — exactly `cellular/`'s
run-length note articulation, reused because the same fix applies for
the same underlying reason (a per-cell "note" is too short to carry
pitch information; grouping runs is the only way "long runs = audible
sustain" actually works). A 50-pixel aligned domain becomes one 50 ms
tone; a disordered region becomes rapid ~1 ms alternation.

### 4. Both layers are capped at $maxSpatialSnapshots (60), same reasoning as dynamical/'s $sweepNotesPerStep

Sweep mode records up to 5000 measurement sweeps by default. A literal
one-Hilbert-snapshot-per-sweep mapping at the spec's default
`pixel_duration` (1.024 s/snapshot for a 32x32 lattice) would produce
a multi-hour file. `$maxSpatialSnapshots = 60` in `sonify.wl` bounds
this (evenly-spaced snapshots across the recorded run), and the
*same* bounded duration (`nSnapshots * nPixels * pixelDuration`) is
reused as **Layer 1's** total duration too, so both layers always span
exactly the same buffer without separate time-alignment logic. This
constant is intentionally not exposed via config, matching
`dynamical/AGENTS.md`'s identical rationale for `$sweepNotesPerStep`.

**Consequence worth knowing:** because snapshot *count* is fixed
(60) while snapshot *duration* scales with `nPixels = lattice_size^2`,
total audio duration scales with lattice size too — a 32x32 run is
~80s (default sweep mode) but a 64x64 run is ~260s (4x the pixels, 4x
the snapshot duration). This is not a bug; if you want larger-lattice
runs to stay a similar length, lower `pixel_duration` roughly in
proportion (e.g. quarter it for a doubled lattice_size).

### 5. Energy-bounds check uses an asymmetric tolerance

Check 2 (`EnergyBoundsCheck`) verifies `e ∈ [-2J, 0]`. The lower bound
is an exact physical floor (checked tightly, `1e-6`). The upper bound
is only an *approximate* expectation for a fully random configuration
— per-spin energy is itself an average over ~2n² bond terms with
O(1/n) statistical width, so real measurement samples (especially at
high-but-finite T, or smaller lattices) routinely fluctuate a little
above 0. The default `upperTolerance` is a generous `0.3` to absorb
genuine statistical noise while still catching a real implementation
bug (which would show energies wildly outside this range, not a
few-hundredths overshoot). Discovered when a naive `1e-9` tolerance
failed on an honestly-correct fully-random 20x20 test configuration
whose measured e was +0.06 — well within expected fluctuation for that
lattice size, not a bug.

### 6. Critical mode's simulated temperature vs. the announced T_c are computed separately

`Tc = $OnsagerTc[jCoupling]` is always the exact formula value, used
for correctness checks, the spoken intro, and the GIF's dashed
reference line. `critical` mode's *simulated* temperature is
`T_fixed` from config (default `2.2692`, a deliberately close
approximation — same kind of judgment call as `dynamical/`'s
`period3_window` preset using `r=3.830` instead of the textbook exact
value), independently overridable via `--simulation.montecarlo.T_fixed`
to explore off-critical fixed temperatures (see the `T_fixed=3.0`/
`1.5` CLI examples) using the same mode/pipeline. These two values are
deliberately decoupled: don't try to make `T_fixed`'s default exactly
equal `$OnsagerTc[]` via some sentinel-detection trick — 2.2692 vs.
2.269185314213022 differ by ~1.5e-5, far below any physically
meaningful threshold at these lattice sizes.

### 7. `$IsingSweepCompiled` needed no batching/vectorisation despite the spec's performance warning

Benchmarked at ~25 ms for 300 sweeps (one full temperature step) on a
32x32 lattice using WL's *default* Compile bytecode target (no C
compiler configured) — the full default sweep-mode workload
(50 steps x 300 sweeps = 15,000 sweep calls) runs in ~1.2 s total, and
a 64x64 lattice at 500 sweeps (critical/quench mode scale) in ~0.16 s.
No `CompilationTarget->"C"`, batching, or reduced defaults were needed;
the spec's suggested fallback (reduce `n_measurement`/`n_equilibration`
if runtime exceeds 60s) was not triggered. `RunNSweepsBatched` (used
for the equilibration phase, which is discarded anyway) exists purely
to avoid needless intermediate-snapshot allocation, not because
per-call dispatch overhead was actually a bottleneck.

## Project structure

```
montecarlo/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json          — default simulation parameters
  experiments.wl        — 7 curated preset invocations
  LISTENING_GUIDE.md     — user-facing recommended listening sequence
  AGENTS.md               — this file
  src/
    model.wl              — EnergyPerSpin, Magnetisation, SusceptibilityEstimate,
                            $OnsagerTc, $IsingSweepCompiled, RunOneSweep/RunNSweepsBatched,
                            RunSweepMode/RunCriticalMode/RunQuenchMode, correctness checks 1-4
    sonify.wl               — SynthesizeAdditiveFrame-adjacent Layer 1 (SpatialLayer/
                            MotionLayer + custom event overlay), Layer 2
                            (HilbertRunLengthTones/BuildSpatialLayerAudio), SonifyIsingRun
    speech.wl                 — Spoken intro synthesis, BuildXIntroText per mode
    animate.wl                  — AnimateSweep (two-panel), AnimateCritical, AnimateQuench
                            (each returns its actual rendered frame count)
    output.wl                    — Correctness-check printers, ExportSweepCSV/ExportFixedTCSV,
                            PrintXSummary per mode
  tests/
    test_model.wl              — unit tests (Onsager formula, energy calculations,
                            Metropolis acceptance, magnetisation convergence, plus coverage)
  output/                      — generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                          # sweep, 32x32, T 4.0->0.5
wolframscript -file main.wl -- --simulation.mode=critical             # at T_c
wolframscript -file main.wl -- --simulation.mode=quench                # instantaneous quench
wolframscript -file main.wl -- --simulation.montecarlo.lattice_size=64
wolframscript -file main.wl -- --simulation.montecarlo.N_T_steps=100
wolframscript -file main.wl -- --simulation.montecarlo.T_fixed=3.0     # above T_c
wolframscript -file main.wl -- --simulation.montecarlo.T_fixed=1.5     # below T_c
wolframscript -file main.wl -- --simulation.montecarlo.random_seed=123
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks

Every run prints checks 1-3; `sweep` mode additionally prints check 4:

1. **Onsager T_c** — `2/Log[1+Sqrt[2]]` matches the known numeric value to 5+ decimal places.
2. **Energy bounds** — `e = E/N^2` within `[-2J, ~0]` for every recorded configuration (see design decision 5 for the asymmetric tolerance).
3. **Detailed balance** — forward/reverse Metropolis acceptance ratio for a real local spin flip equals `Exp[-dE/T]` exactly.
4. **Magnetisation convergence** (`sweep` only) — `|M| > 0.8` for every recorded T < 1.0 sample.

## Common pitfalls

1. **`gamma_?NumericQ : 1.0` in function signatures is broken syntax**
   — parses as `gamma_?(NumericQ : 1.0)`, a pattern that never
   matches, so the function silently fails to evaluate (no error).
   `$OnsagerTc` was originally written this way during development and
   silently returned unevaluated on every call — cascading into three
   other broken-looking test results before the root cause was found.
   Always use `Optional[gamma_?NumericQ, 1.0]` instead (same pitfall
   documented in `dynamical/AGENTS.md` and `thermo/AGENTS.md`).
2. **`HilbertTraversalOrder[n]` requires an exact `2^n x 2^n` grid** —
   `lattice_size` is coerced to the nearest power of 2 via
   `NearestPowerOfTwo` (same pattern `cosmology/`'s sky-map resolution
   uses) so the simulated lattice and the Hilbert spatial layer always
   agree on size. A non-power-of-2 `lattice_size` prints a `[NOTE]` and
   silently uses the coerced size for the whole run, not just the
   spatial layer.
3. **`Animate*` functions return their actual rendered frame count**,
   not the requested `nFrames` — same lesson as `thermo/AGENTS.md`
   pitfall 2. `main.wl` captures this return value for
   `STEMDescribeGIF`.
4. **`SonifyIsingRun` returns buffers, does not export** — mirrors
   `thermo`/`dynamical`'s pattern so `main.wl` can prepend the spoken
   intro via `ExportWithIntro` before a single final export. If you
   add a fourth mode, don't call `RenderAudio`/`ExportAudioBuffer`
   inside `sonify.wl` directly — the spoken intro would silently be
   dropped from the WAV (this happened once during development: the
   intro text was computed and printed to the console but never
   actually synthesised into the exported audio, since `SonifyIsingRun`
   originally exported the file itself before `BuildIntroBuffer` ever
   ran).

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSection`, `STEMSay`, `STEMPrintN`,
  `STEMDescribeWAV`, `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`,
  `STEMPlayCmd`, `SpatialLayer`, `MotionLayer`, `MixLayers`,
  `RenderAudio`, `HilbertTraversalOrder`, `StemSynthNote`,
  `NormalizeBuffer`, `ExportAudioBuffer`, `ExportGIF`, `ExportCSV`,
  `EnsureDir`. Deliberately **not** used: `SonifyTrajectory`,
  `EventLayer`, `ScaleLookup` — see design decision 1.
- **Mathematica/WL**: `Compile` (with `RandomInteger`/`RandomReal`
  called from inside the compiled function), `RandomChoice`,
  `ArrayPlot`, `GraphicsColumn`, `Graphics`, `Sound`,
  `SampledSoundList`, `SpeechSynthesize`, `AudioQ`, `AudioData`,
  `AudioSampleRate`, `RunProcess` (platform TTS fallback), `Import`
  (reading TTS-generated WAV files).

## Speech synthesis note

`speech.wl`'s three-tier fallback (`SpeechSynthesize[]` -> platform TTS
-> text-only `STEMSay`) duplicates the pattern in `dynamical/`,
`images/`, and `thermo/`'s `src/speech.wl`. This is one of many
independent copies of this pattern scattered across the codebase — a
strong candidate for stem-core consolidation in a future pass
(explicitly out of scope here per this app's build spec, which
excludes stem-core changes).

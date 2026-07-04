# Thermo — Agent Guide

## Project overview

Sonifies classical statistical mechanics: the Maxwell-Boltzmann speed
distribution, particle ensembles under elastic collisions, thermal
relaxation (Newton's law of cooling), and the equipartition theorem.
Purely classical — no quantum statistics (Fermi-Dirac/Bose-Einstein)
anywhere in this app.

| Mode | Physics | Output |
|------|---------|--------|
| `distribution` (default) | f(v) swept over T | Stereo WAV; animated MB-curve GIF |
| `ensemble` | N particles, MB-sampled, elastic-collision reshuffling | Stereo WAV (chord); animated speed histogram GIF |
| `cooling` | Newton's law of cooling, T(t) = T_cold + (T_hot-T_cold)e^(-t/tau) | Stereo WAV; two-panel T(t)/spectrum GIF |
| `equipartition` | Translational (L) vs rotational (R) energy partition | Binaural WAV; side-by-side pie-chart GIF |

## Key design decisions (read before modifying sonify.wl)

### 1. Additive synthesis, not stem-core's continuous SonifyTrajectory or discrete per-point notes

Unlike `dynamical`/`primes` (discrete `StemSynthNote` bursts) or
`lorenz`/`pendulum` (stem-core's `SonifyTrajectory` continuous
carrier), this app's `distribution`/`cooling`/`equipartition` modes
synthesise **many simultaneous sine partials per frame** — the whole
point is that the frame's spectral envelope literally *is* the
Maxwell-Boltzmann curve, which requires actual simultaneous frequency
content, not a single note's pitch encoding one value. `ensemble` mode
reuses the same additive-synthesis primitive (`SynthesizeAdditiveFrame`
in `sonify.wl`) with one partial per particle instead of one per MB
bin — this is what makes the "chord" texture the ensemble spec calls
for.

Each frame gets a short (5 ms) linear fade in/out (`FrameWindow`) —
frames are independently synthesised with phase reset to zero at
`t=0`, so without a fade, concatenating them produces audible clicks
at every frame boundary. This is the single most important thing to
preserve if you touch `SynthesizeAdditiveFrame`.

### 2. RandomVariate[MaxwellDistribution[...]], not hand-rolled rejection sampling

`f(v) = 4*pi*(m/2*pi*k*T)^1.5 * v^2 * exp(-m*v^2/2*k*T)` is *exactly*
the PDF of WL's built-in `MaxwellDistribution[sigma]` with
`sigma = Sqrt[k*T/m]` (verified algebraically in `model.wl`'s header
comment: `4*pi*(m/2*pi*k*T)^1.5 = Sqrt[2/pi]/sigma^3` when
`sigma^2 = k*T/m`). `SampleMBSpeeds` uses `RandomVariate` on this exact
match rather than a custom rejection sampler — same distribution,
more robust numerics, less code. If you are asked to "implement
rejection sampling from scratch," that request is redundant with what
`SampleMBSpeeds` already does correctly; flag it rather than adding a
second, worse sampler.

### 3. Elastic collisions are an exact speed swap, not a general redistribution

`ElasticCollision1D[v1, v2] := {v2, v1}`. This is not a simplification
— for **equal masses** in a 1D elastic collision, conserving both
momentum and kinetic energy simultaneously forces a complete velocity
exchange; there is no other solution. Because a swap only permutes
which particle holds which speed value — it never changes the
underlying multiset of speeds — `SimulateEnsemble`'s ensemble speed
distribution is *exactly* conserved at every timestep, not just
approximately. This is deliberate: it is precisely the "ensemble
paradox" the app is built to demonstrate (see `LISTENING_GUIDE.md`) —
the macroscopic distribution is fixed while the microscopic assignment
shuffles continuously. If you change this to a partial-energy-transfer
model, `EnsembleEquilibrationCheck` will still pass (mean speed is
conserved regardless), but `Sort[initialSpeeds] === Sort[finalSpeeds]`
(tested in `tests/test_model.wl`) will no longer hold — that test
exists specifically to catch an accidental change to this design
decision.

### 4. Equipartition mode's mass comes from `molecule`, not `preset`/`mass_amu`

`preset`/`mass_amu` (default `helium`/`4`) drive `distribution`,
`ensemble`, and `cooling`. `equipartition` mode ignores them entirely
and instead derives its translational mass from
`RepresentativeGasForMoleculeType[moleculeType]` (helium for
monatomic, nitrogen for diatomic) — because `--simulation.thermo.molecule`
is specified as selecting *among* a specific gas set ("monatomic
(helium, argon) or diatomic (hydrogen, nitrogen, oxygen)"), not simply
toggling a DOF-count flag independent of mass. If a user reports that
`--simulation.thermo.preset=argon --simulation.mode=equipartition`
"doesn't do anything," this is why — that combination is intentionally
inert for this mode.

### 5. Rotational drone frequency is an arbitrary audio-range remapping of sqrt(kT)

The spec's formula "freq proportional to sqrt(rotational energy) =
sqrt(kT)" is dimensionally *not* a frequency — `sqrt(kT)` at room
temperature is of order 1e-11, nowhere near audible. `RotationalDroneFreq`
preserves the `~ Sqrt[T]` *shape* while linearly remapping it onto a
40-150 Hz "warm low drone" band spanning the configured T range. This
is a deliberate audio-design choice, not a physics result — do not
read literal Hz values out of this function as a real frequency scale.

### 6. Vibrational-mode onset at high T is not implemented

The equipartition GIF requirements list "vibrational modes activating
at high T" as an explicit "bonus"; the core spec's physics section
only covers 3 translational + 2 rotational DOF at room temperature.
`RotationalFraction`/`RenderEquipartitionFrame`'s 60/40 split is
constant across the whole T sweep (evaluated once at T=300K) — it does
not model vibrational heat capacity onset. Out of scope for this pass;
flag rather than silently add it if asked to extend this.

### 7. `frame_duration` is one shared config key across all four modes

The build spec's `ensemble` mode prose states a default of 0.05 s/frame,
but the literal `config.json` block it also specifies has a single
shared `simulation.thermo.frame_duration: 0.1` used by every mode —
there is no per-mode override. This is an internal inconsistency in
the original spec; the shipped default (0.1 s, matching the explicit
JSON) makes `ensemble`'s default 200-timestep audio 20 s long rather
than 10 s. Not a bug — a resolved ambiguity, documented here so it
isn't "fixed" back to a value the JSON block doesn't actually specify.

## Project structure

```
thermo/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json          — default simulation parameters
  experiments.wl        — 8 curated preset invocations (3 gases x distribution,
                          2 x ensemble, cooling, 2 x equipartition)
  LISTENING_GUIDE.md     — user-facing recommended listening sequence
  AGENTS.md               — this file
  src/
    model.wl              — MBDensity, characteristic speeds, correctness checks 1-4,
                            equipartition energetics, SampleMBSpeeds, ElasticCollision1D,
                            SimulateEnsemble, CoolingTemperature/DefaultCoolingTau
    sonify.wl                — SynthesizeAdditiveFrame/FrameWindow (core primitive),
                            MBSpectrumBins, AddTripleTap/AddEquilibriumAccent,
                            BuildDistributionAudio, BuildEnsembleAudio, BuildCoolingAudio,
                            BuildEquipartitionAudio, RotationalDroneFreq
    speech.wl                 — Spoken intro synthesis (SpeechSynthesize -> platform TTS ->
                            text-only fallback), BuildXIntroText per mode
    animate.wl                 — AnimateDistribution, AnimateEnsemble, AnimateCooling,
                            AnimateEquipartition (each returns its actual rendered
                            frame count, for accurate STEMDescribeGIF reporting)
    output.wl                   — PrintCoreChecks/PrintEnsembleCheck/PrintEquipartitionChecks,
                            ExportXCSV per mode, PrintXSummary per mode
  tests/
    test_model.wl             — unit tests (normalisation, speed ratios, sampling,
                            collision conservation, cooling curve, presets, energetics)
  output/                     — generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                              # distribution, helium, 100K->1000K
wolframscript -file main.wl -- --simulation.mode=ensemble                # 20 particles at 300K
wolframscript -file main.wl -- --simulation.mode=cooling                 # helium cooling 1000K->50K
wolframscript -file main.wl -- --simulation.mode=equipartition           # monatomic vs diatomic
wolframscript -file main.wl -- --simulation.thermo.preset=nitrogen
wolframscript -file main.wl -- --simulation.thermo.preset=hydrogen
wolframscript -file main.wl -- --simulation.thermo.T_fixed=600
wolframscript -file main.wl -- --simulation.thermo.n_particles=50
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks

Every run prints checks 1-2 (properties of the MB distribution
itself); `ensemble` additionally prints check 3, `equipartition`
additionally prints check 4:

1. **Normalisation** — `NIntegrate[f(v), {v, 0, v_max}]` within 0.001 of 1.0.
2. **Characteristic speed ratios** — `v_mean/v_p = Sqrt[4/pi]`,
   `v_rms/v_p = Sqrt[3/2]`, both exact algebraic identities independent
   of T and mass.
3. **Ensemble equilibration** (`ensemble` only) — mean speed of the
   final ensemble within 10% of the analytic `v_mean`. Given the exact
   speed-swap collision model (design decision 3), this is actually
   guaranteed exactly, not approximately — the check exists as a
   sanity net against a future implementation change, not because the
   result is genuinely in doubt today.
4. **Equipartition** (`equipartition` only) — mean translational KE
   equals `(3/2)kT` within 1%, verified for both a monatomic- and
   diatomic-representative mass (helium, nitrogen), since the result
   must hold regardless of species.

## Common pitfalls

1. **`gamma_?NumericQ : 1.0` in function signatures is broken syntax**
   — parses as `gamma_?(NumericQ : 1.0)`, a pattern that never
   matches, so the function silently fails to evaluate (no error).
   Always use `Optional[gamma_?NumericQ, 1.0]` instead (same pitfall
   documented in `dynamical/AGENTS.md`; all optional-argument functions
   here use the explicit `Optional[]` form for this reason).
2. **`Animate*` functions return their actual rendered frame count**,
   not the requested `nFrames` — `Min[nFrames, nStepsAvailable]` can
   cap it lower (e.g. `cooling` mode's default 50 available frames
   caps a requested 60 down to 50). `main.wl` captures this return
   value and passes it to `STEMDescribeGIF` — do not hardcode the
   requested count there, or the printed summary will say "60 frames"
   for a GIF that actually has 50.
3. **`MBSpectrumBins`'s amplitude normalisation is peak-relative, not
   area-relative** — `amps = densities / Max[densities]`, so the
   loudest bin in every frame is always amplitude 1.0 before the
   `1/Sqrt[nBins]` additive-synthesis scaling. This means frames at
   very different T are not perceptually equal-loudness by design
   (`cooling` mode explicitly wants quieter-as-it-cools; `distribution`
   mode's loudness is incidental, smoothed out by the final
   `NormalizeBuffer` pass at export).
4. **Stereo export uses `ExportAudioBuffer[{left, right}, ...]`
   directly, not `Transpose[{left,right}]`** — unlike stem-core's
   `RenderAudio` (which expects an N x 2 matrix and transposes it
   internally), `ExportAudioBuffer` passes its `buffer` argument
   straight to `SampledSoundList`, which wants channel-major (2 x N)
   for stereo. Passing a transposed N x 2 matrix here would silently
   produce a garbled/interleaved-sounding export.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSection`, `STEMSay`, `STEMPrintN`,
  `STEMDescribeWAV`, `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`,
  `STEMPlayCmd`, `NormalizeBuffer`, `ExportAudioBuffer`, `ExportGIF`,
  `ExportCSV`, `EnsureDir`. Deliberately **not** used: `SonifyTrajectory`,
  `SpatialLayer`, `MotionLayer`, `EventLayer`, `MixLayers`,
  `RenderAudio`, `ScaleLookup`, `StemSynthNote` — see design decision 1.
- **Mathematica/WL**: `MaxwellDistribution`, `RandomVariate`, `NIntegrate`,
  `Sound`, `SampledSoundList`, `Graphics`, `ListLinePlot`, `Histogram`,
  `PieChart`, `GraphicsColumn`/`GraphicsRow`, `Export`, `SpeechSynthesize`,
  `AudioQ`, `AudioData`, `AudioSampleRate`, `RunProcess` (platform TTS
  fallback), `Import` (reading TTS-generated WAV files).

## Speech synthesis note

`speech.wl`'s three-tier fallback (`SpeechSynthesize[]` -> platform TTS
-> text-only `STEMSay`) duplicates the pattern in `dynamical/src/speech.wl`,
`images/src/speech.wl`, and `signal/src/sonify.wl`'s `SpeakToBuffer`.
This is now the fourth independent copy of this pattern across the
codebase — a strong candidate for stem-core consolidation in a future
pass (explicitly out of scope here per this app's build spec, which
excludes stem-core changes).

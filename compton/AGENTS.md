# Compton — Agent Guide

## Project overview

Sonifies Compton scattering: a photon losing energy to a recoiling
electron, the 1923 measurement that decided the wave/particle debate in
favour of the photon picture. Four modes:

| Mode | Physics | Output |
|------|---------|--------|
| `scatter` (default) | Single event at a configured wavelength/angle | Narrated stereo WAV; animated collision diagram GIF; static PNG |
| `sweep` | Continuous angle sweep, fixed wavelength | Glissando WAV; animated curve-with-marker GIF; static PNG |
| `energy` | Incident-energy sweep, fixed angle, crosses 511 keV | Dyad-chord WAV; animated curve-with-marker GIF; static PNG |
| `discovery` | Binaural Thomson (flat) vs Compton (drops) | Binaural WAV; static overlay PNG (no GIF) |

Closest sibling apps: `scattering/` (architectural reuse of the binaural
classical-vs-quantum `discovery` structure — **not** its physics; see
design decision 1) and `hydrogen/` (the same photon-energy ↔ pitch
domain, and the "energy in, pitch out" sonification convention).

## Key design decisions (read before modifying sonify.wl or model.wl)

### 1. Compton scattering has NO impact-parameter trajectory — do not reintroduce one

`V1.5.0_APP_IDEAS.md`'s original note connecting this app to
`scattering/` describes it as "same geometry: impact parameter → angle"
— **this is not physically accurate, and this app does not implement
it.** Rutherford scattering (`scattering/`) is a classical continuous
process: a charged particle follows a hyperbolic trajectory whose final
deflection angle is *determined by* integrating the equations of motion
from an impact parameter `b`. Compton scattering is a **discrete quantum
event**: a single photon-electron collision with no trajectory to
integrate at all — the scattering angle `theta` is an independent input
to Compton's formula, not an output that emerges from some other
geometric parameter. There is no `b`-to-`theta` relationship here to
mirror `scattering/`'s `ArcCot[b]`, and `model.wl` contains no `NDSolve`
call anywhere.

The actual, useful connection to `scattering/` is **architectural**: its
`discovery` mode's binaural classical-vs-quantum comparison structure
(one theory per stereo channel, letting a listener hear the historical
disagreement directly) is worth reusing as a *pattern*. This app's
`discovery` mode does that — but note design decision 2 below on how
even that reuse is structural, not a port of `scattering/`'s actual
code.

### 2. `discovery` mode is a continuous binaural sweep, not a statistical distribution comparison

`scattering/`'s own `discovery` mode compares Thomson and Rutherford by
sampling **two random angle distributions** (Thomson: tiny angles only;
Rutherford: `1/sin^4(theta/2)`-weighted) and rendering each as a stream
of discrete particle events — appropriate there because Rutherford
scattering IS inherently statistical (a real beam scatters at a
*distribution* of angles). Compton scattering, by contrast, has a single
deterministic outgoing energy for any given `(E, theta)` pair — there is
no distribution to sample. This app's `discovery` mode instead sweeps
the SAME angle continuously in both channels simultaneously: left
channel constant (Thomson: no angle dependence at all), right channel
following Compton's actual formula. This is a smooth, deterministic
sweep — closer in construction to this app's own `sweep` mode (reusing
its continuous-phase-accumulation technique, see design decision 3) than
to `scattering/discovery`'s per-particle event stream. Do not
"correct" this by reintroducing random sampling; there is nothing here
that should be sampled.

### 3. `sweep`/`discovery` use continuous phase accumulation; `energy` uses discrete per-step frames — and this is not arbitrary

A glissando needs a continuous instantaneous frequency with no phase
discontinuities between samples, which requires computing the
frequency array at full audio-sample resolution and integrating it via
`Accumulate` (`phaseArr = 2*Pi*Accumulate[fAudio]*dt`) — exactly
`relativity/src/sonify.wl`'s chirp technique, reused here because this
app's own "the equation IS the pitch bend" framing is the same
relationship `relativity/`'s chirp has to its own governing frequency
formula. `sweep` and `discovery`'s Compton channel both use this.

`energy` mode instead plays a **dyad** (incoming AND outgoing pitch
together) at each step — a single continuous phase accumulator cannot
represent two simultaneous, independently-evolving frequencies without
becoming two accumulators anyway, and blackbody/thermo's proven
per-step-frame concatenation pattern already handles "two things
changing together, one frame at a time" cleanly. Do not try to force
`energy` mode into a single continuous glissando; the "two notes
together, gap widening" experience the build spec asks for is a
discrete-frame idea, not a continuous one.

### 4. `PhotonPitchHz` uses log-log mapping, not hydrogen's linear-log `AudioFreqFromRange`

`hydrogen/src/sonify.wl`'s `AudioFreqFromRange` rescales its physical
axis (photon frequency) **linearly** before exponentiating onto a log
audio range — appropriate there because hydrogen's spectral lines span
at most ~2 orders of magnitude. This app's `energy` mode sweeps 1 keV to
5 MeV, 3.7 decades — treating raw keV linearly would crush the entire
X-ray regime into an imperceptible sliver near the low end of that
range. `PhotonPitchHz` instead maps `Log[E]` onto the log audio range
(`audioFreqMin*(audioFreqMax/audioFreqMin)^Clip[Log[E/EMin]/Log[EMax/EMin],{0,1}]`),
matching `blackbody/`'s `BlackbodySpectrumBins` convention rather than
`hydrogen/`'s. If you add a mode whose physical energy range is narrow
(within an order of magnitude or so), hydrogen's linear-log form would
also work there — but every mode in *this* app shares the same wide
`[energy_min_kev, energy_max_kev]` domain (see design decision 5), so
there was no reason to implement both forms.

### 5. All four modes share ONE photon-energy-to-pitch domain, not a per-mode-local one

An earlier design considered mapping `scatter` mode's single incident/
outgoing energy pair onto a LOCAL domain (`[E', E]` for that specific
event, so the pitch always sweeps the full audio range regardless of
how large the actual physical shift is). This was rejected: it would
make a tiny 3% shift (Compton's own historical X-ray case) and a
dramatic 90% shift (a gamma-ray case) sound *identical* — both a full
sweep from `audioFreqMax` to `audioFreqMin` — which actively hides the
one thing worth hearing (how big the shift actually is). All four modes
instead share the SAME `[energy_min_kev, energy_max_kev]` domain
(default 1-5000 keV, also `energy` mode's own sweep bounds) for
`PhotonPitchHz`. Consequence: `scatter` mode's pitch drop at the
historical default (71 pm, 90 degrees, ~3% loss) is genuinely modest,
not dramatic — this is intentional and physically honest (that really
is a small shift), not a bug; the click, panning, and recoil thud carry
the demonstrative weight there, and `energy`/`sweep` modes with a
higher `wavelength_pm`/lower `wavelength_pm` are where a dramatically
larger shift is actually audible.

### 6. Correctness checks are diagnostic-only, and here is precisely why (not a blanket codebase rule)

All four checks (forward-scattering limit, backscatter limit, Thomson
limit, energy-momentum conservation) are closed-form verifications of a
fixed formula, evaluated at hand-picked test points — none of them
depend on a numerically-integrated trajectory whose runtime health an
abort could usefully gate. They print `[PASS]`/`[FAIL]` and the run
continues regardless, identical to `blackbody/`'s four checks (see
`blackbody/AGENTS.md` design decision 3 for the fuller version of this
argument, which applies here without modification).

This is **not** a universal codebase convention — `relativity/`'s chirp
mode genuinely calls `Exit[1]` when its NUMERICALLY-SOLVED frequency/
amplitude arrays fail a monotonicity check (`relativity/src/model.wl`'s
`fMono`/`aMono` gate): that check is testing whether a specific run's
integration actually behaved correctly, which is exactly the kind of
thing worth aborting on. The distinction is what is being checked, not
which app it's in: a closed-form mathematical limit of a fixed formula
(this app, blackbody) either always passes or always fails from a code
bug, so a hard gate adds little; a numerically-integrated trajectory's
health (relativity) can genuinely vary run to run in a way an abort
usefully catches.

### 7. `ComptonWavelengthShiftPm` uses `2*Sin[theta/2]^2`, not a literal `1-Cos[theta]`

Exact trig identity (`1-cos(theta) = 2*sin^2(theta/2)`), not an
approximation — but numerically stable at `theta->0` where the literal
`1-Cos[theta]` form loses precision to catastrophic cancellation
(computing `1+tiny` then subtracting `1`), the same failure mode
`blackbody/AGENTS.md` design decision 4 documents for its own
Rayleigh-Jeans check. The fix there was picking a "not too small" test
value (`x=1e-6`); the fix here is better — an exact identity means
`ForwardScatteringLimitCheck` can test `theta` genuinely close to zero
(`1e-8` rad) with no precision concern at all, rather than needing to
tune a compromise test angle.

### 8. `RecoilElectronAngleDeg` returns the electron's own (already-signed) angle

`py = -EPrime*Sin[theta]` — the minus sign matters: `p_e = p_in -
p_out_photon`, and the incident photon has zero transverse momentum, so
the electron's transverse momentum is the *negative* of the scattered
photon's, not the same value reused. The function returns a negative
angle for any forward-scattering `theta` (0 to 180 degrees maps to 0 to
-90 degrees), i.e. it is already on the correct, opposite transverse
side — this matches the function's own docstring and needs no
compensating sign flip anywhere downstream.

An earlier draft omitted the minus sign, returning the scattered
*photon's* transverse momentum angle instead of the electron's. That
version's own docstring already claimed "opposite transverse side," so
the bug was a mismatch between the docstring and the implementation, not
absent documentation. `animate.wl`'s diagram happened to look correct
anyway, because `ScatterDiagramGraphics` applied its own independent
minus sign when placing the electron arrow — but `output.wl`'s CSV/
console export used the raw (wrong-signed) value directly, so the
exported `recoil_angle_deg` silently disagreed with the diagram's own
picture. Fixing the sign at the source (here) instead of patching every
downstream consumer removes that class of bug entirely: there is now
exactly one place that decides which side the electron is on, and every
consumer — `animate.wl`, `output.wl`, and any future one — reads it
correctly for free. If you touch this function, keep it that way: a
shared geometric quantity like a signed angle should carry its own
correct sign, not rely on each caller separately remembering which way
to flip it.

## Project structure

```
compton/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json          — default simulation parameters
  experiments.wl        — 6 curated preset invocations (3 x scatter at different
                          wavelength/angle, sweep, energy, discovery)
  LISTENING_GUIDE.md     — user-facing recommended listening sequence
  AGENTS.md               — this file
  src/
    model.wl              — PhotonEnergyKeV/PhotonWavelengthPm, ComptonWavelengthShiftPm,
                            ComptonOutgoingEnergyKeV, RecoilElectronAngleDeg, PhotonPitchHz,
                            ComptonPan, correctness checks 1-4, ScatterModel/SweepModel/
                            EnergyModel/DiscoveryModel
    sonify.wl                — BuildScatterAudio (discrete events), BuildSweepAudio/
                            BuildDiscoveryAudio (continuous phase accumulation),
                            BuildEnergyAudio (per-step dyad frames)
    speech.wl                 — Spoken intro/outro synthesis (SpeechSynthesize -> platform
                            TTS -> text-only fallback), BuildXIntroText per mode
    animate.wl                  — ScatterDiagramGraphics (shared GIF/PNG), per-mode
                            Render*/Animate* functions
    output.wl                    — Export*CSV per mode, Print*Summary per mode
  tests/
    test_model.wl              — unit tests (limits, conservation, unit conversions,
                            recoil angle, pitch/pan mapping)
  output/                     — generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                           # scatter, Compton's 1923 values
wolframscript -file main.wl -- --simulation.compton.angle_deg=180     # backscatter
wolframscript -file main.wl -- --simulation.mode=sweep                # angle glissando
wolframscript -file main.wl -- --simulation.mode=energy               # energy sweep, 1keV-5MeV
wolframscript -file main.wl -- --simulation.mode=discovery            # Thomson vs Compton
wolframscript -file main.wl -- --simulation.compton.wavelength_pm=10
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks

All four run unconditionally, every invocation, regardless of mode (see
design decision 6 for why none of them abort):

1. **Forward-scattering limit** — `Delta_lambda < 1e-15` pm at
   `theta = 1e-8` rad (using the `2*Sin[theta/2]^2` identity, so no
   precision floor forces a looser test angle — see design decision 7).
2. **Backscatter limit** — `Delta_lambda` at `theta=pi` matches
   `2*lambda_C` within 0.01%.
3. **Thomson limit** — `E'/E` at `E=0.001 keV`, `theta=pi` (the most
   demanding angle) matches 1.0 within 0.01%.
4. **Energy-momentum conservation** — at Compton's own 1923 values
   (17.5 keV, 90 degrees), the recoil electron's momentum computed via
   `T=E-E'` and via direct 2D vector conservation agree within 0.01%.

## Common pitfalls

1. **`gamma_?NumericQ : 1.0` in function signatures is broken syntax**
   — parses as `gamma_?(NumericQ : 1.0)`, a pattern that never matches.
   Always use `Optional[gamma_?NumericQ, 1.0]` instead (same pitfall
   documented in `blackbody/AGENTS.md` and `thermo/AGENTS.md`).
2. **A stray `*)` inside a prose comment silently truncates it** — see
   `blackbody/AGENTS.md`'s pitfall 2 for the full mechanism (a variable
   name ending in an implied multiplication, immediately followed by a
   closing paren in prose, reads as the comment's own `*)`). Checked
   for and avoided throughout this app's comments; watch for it if you
   add more.
3. **`Animate*` functions return their actual rendered frame count**,
   not the requested `nFrames` — `main.wl` passes this return value to
   `STEMDescribeGIF` directly (same convention as every other app's
   `AGENTS.md`).
4. **Bare `Graphics[...]` with an extreme x:y data-range aspect ratio
   renders squished unless `AspectRatio` is set explicitly.** `sweep`/
   `energy`/`discovery`'s curve plots have data ranges like `{0,180}` x
   `{0,~5}` (a ~34:1 aspect) — without an explicit `AspectRatio -> 0.5`,
   the frame/labels compress into an unreadable sliver near the centre
   of the image (caught by actually rendering and viewing the PNGs
   during development, not by inspecting the code). Any new curve plot
   in this app should set `AspectRatio` explicitly rather than relying
   on the default.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSection`, `STEMSay`, `STEMPrintN`,
  `STEMDescribeWAV`, `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`,
  `STEMPlayCmd`, `NormalizeBuffer`, `ExportAudioBuffer`, `ExportGIF`,
  `ExportCSV`, `EnsureDir`, `StemSynthNote` (all discrete-note
  synthesis: `scatter`'s events, `energy`'s dyad frames). Deliberately
  **not** used: `SonifyTrajectory`, `SpatialLayer`, `MotionLayer`,
  `EventLayer`, `MixLayers`, `RenderAudio`, `ScaleLookup` — there is no
  trajectory in this app to feed them (see design decision 1).
- **Mathematica/WL**: `Accumulate` (continuous phase for `sweep`/
  `discovery`), `Sound`, `SampledSoundList`, `Graphics`, `Export`,
  `SpeechSynthesize`, `AudioQ`, `AudioData`, `AudioSampleRate`,
  `RunProcess` (platform TTS fallback), `Import` (reading
  TTS-generated WAV files).

## Speech synthesis note

`speech.wl`'s three-tier fallback (`SpeechSynthesize[]` -> platform TTS
-> text-only `STEMSay`) duplicates the pattern in `blackbody/src/speech.wl`,
`thermo/src/speech.wl`, and `scattering/src/sonify.wl`'s identical
pattern — now a sixth independent copy, still out of scope for
stem-core consolidation per every prior app's own build spec.

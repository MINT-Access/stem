# Quantum Statistics — Agent Guide

## Project overview

Sonifies the three occupation-number distributions of statistical
mechanics: Bose-Einstein, Fermi-Dirac, and Maxwell-Boltzmann — and the
exact sense (an algebraic identity, not just an asymptote) in which
Maxwell-Boltzmann is the classical limit of both quantum distributions.
Completes the "quantum/thermo bridge" `docs/V1.5.0_APP_IDEAS.md`
originally proposed this app for. Three modes:

| Mode | Physics | Output |
|------|---------|--------|
| `spectrum` (default) | All three distributions vs energy, fixed T, mu=0 | Three simultaneous voices, distinct pan+register; curve GIF/PNG |
| `temperature` | All three distributions' values vs T, fixed eps, mu=0 | Same three voices, continuously swept over T; curve GIF/PNG |
| `fermi_sea` | Fermi-Dirac step vs energy, several T, mu=reference Fermi energy | One spectral frame per T; step-animation GIF/PNG |

Closest sibling apps: `thermo/` (the classical limit this app's `n_MB`
literally reduces to, and the additive spectral-envelope sonification
technique `spectrum`/`fermi_sea` modes reuse directly), `blackbody/`
(the log-compressed-loudness technique `temperature` mode reuses,
essential for Bose-Einstein's huge dynamic range), and `quantum/`
(`quantum/box`'s discrete energy levels are exactly the kind of state
these occupation numbers describe filling).

## Key design decisions (read before modifying sonify.wl or model.wl)

### 1. mu=0 for spectrum/temperature; mu=reference_energy for fermi_sea — two different conventions, each verified necessary

The build brief specified `mu=0` as "a clean, standard reference...
matches how this is often posed for a photon/phonon gas." Taken
literally and uniformly, this creates a real problem for `fermi_sea`
mode specifically: with the sweep restricted to `eps>=0` (a restriction
Bose-Einstein's own domain forces elsewhere in this app), `mu=0` means
every swept `eps` satisfies `eps>=mu`, so `n_FD(eps)` only ever covers
the FALLING half of the sigmoid (from `0.5` down to `0`) — the
near-`1` plateau below the Fermi energy, half of what "the Fermi sea"
even means, would simply never appear in the sweep.

Resolution, verified before implementing: `fermi_sea` mode uses
`mu = referenceEnergy` (a genuine positive Fermi energy, physically
standard — real metals have Fermi energies of several eV, not zero).
Fermi-Dirac has NO domain restriction (unlike Bose-Einstein), so this
is not a workaround, it's simply the physically correct setup for a
FD-only mode. `spectrum` and `temperature` modes keep `mu=0` — the
brief's own stated justification (photon/phonon gas) applies cleanly
to THEM specifically, since they compare all three distributions
together and Bose-Einstein's `eps>0` requirement is the binding
constraint, not Fermi-Dirac's (nonexistent) one.

### 2. energy_min/energy_max deliberately kept positive everywhere, including fermi_sea — reusing one config-key pair for both mu conventions

Rather than adding fermi_sea-specific sweep-bound keys, `energy_min`/
`energy_max` stay shared and always non-negative (default `0.001` to
`2.0` eV) across all three modes. `fermi_sea`'s `reference_energy`
default (`1.0` eV) was chosen specifically to sit comfortably INSIDE
that shared positive range, so both `eps<mu` (near-`1` plateau) and
`eps>mu` (near-`0` tail) are visible within the same non-negative
domain Bose-Einstein needs elsewhere — verified by inspection of the
rendered PNG (see `output/quantum_statistics_fermi_sea.png`; the step
sits roughly in the middle of the energy axis, both sides visible).

### 3. temperature mode's actual verified direction — corrected from the build brief's stated framing

The build brief asked for "quantum statistics deviate from classical
at low T, converge at high T." Before implementing, this was checked
directly against the `mu=0`, fixed-`eps` formula this mode actually
uses — and found to run the OPPOSITE direction:

```
T(K)    kT(eV)   x=eps/kT   n_BE        n_FD       n_MB
100     0.0086   116.0      4.0e-51     4.0e-51    4.0e-51
300     0.0259   38.7       1.6e-17     1.6e-17    1.6e-17
1000    0.0862   11.6       9.1e-6      9.1e-6      9.1e-6
10000   0.8617   1.16       0.456       0.239      0.313
30000   2.5852   0.387      2.117       0.404      0.679
100000  8.6173   0.116      8.127       0.471      0.890
```

(eps0=1.0 eV, mu=0.) At LOW T, all three collapse together (and toward
zero) — CONVERGED. At HIGH T, Bose-Einstein diverges outright while
Fermi-Dirac saturates at 0.5 and Maxwell-Boltzmann at 1 — maximally
DIFFERENT. This is the reverse of the brief's stated direction.

Why the familiar "cold=quantum" intuition doesn't transfer here: that
story implicitly assumes a large, POSITIVE, T-INDEPENDENT chemical
potential (a real metal's Fermi energy, exactly `fermi_sea` mode's own
setup, where the intuition holds and is verified correctly — see the
10-90 width scaling in design decision 4 below). For a system with
`mu=0` fixed (this mode's own convention, justified by the
photon/phonon-gas framing the brief itself invoked), the classical
limit is controlled by `x=(eps-mu)/kT` being LARGE, which for FIXED
`eps` and `mu=0` means LOW `kT`, i.e. LOW `T` — not high. Reframed
physically: a cold photon-gas cavity holds few, sparse photons per
mode (dilute, classical-looking, matching MB's own exponential form
even though photons aren't MB-distributed particles); a hot cavity is
thick with photons per mode (strongly bunched, quantum-degenerate) —
a real, standard statement about photon statistics, not an invented
exception. `temperature` mode's implementation, its README section,
and its spoken intro text all state the VERIFIED direction, not the
brief's original phrasing — the same kind of "checked, found the brief
wrong, documented why" correction `bayes/AGENTS.md` records for its
own build spec's arithmetic error.

### 4. The classical-limit check uses an EXACT identity, not an asymptotic numerical observation

`(n_BE-n_MB)/n_MB` and `(n_FD-n_MB)/n_MB` were not merely observed
numerically to shrink for large `x` — they were derived algebraically
and confirmed exactly equal to `n_BE` and `-n_FD` respectively, for
EVERY `x`, not just asymptotically:

```
n_MB = Exp[-x]
n_BE = 1/(Exp[x]-1) = n_MB/(1-n_MB)   =>   n_BE/n_MB - 1 = n_MB/(1-n_MB) = n_BE
n_FD = 1/(Exp[x]+1) = n_MB/(1+n_MB)   =>   n_FD/n_MB - 1 = -n_MB/(1+n_MB) = -n_FD
```

Both directions confirmed via `Simplify` in the derivation session
(not just spot-checked numerically), and separately confirmed by
`tests/test_model.wl`'s own dedicated identity tests at four different
`x` values. This means "the fractional deviation from classical" and
"the occupation number itself" are the SAME quantity — a genuinely
elegant fact worth stating explicitly in the README rather than
leaving as an implementation detail, since it turns "pick a threshold
for the classical-limit check" into "just look at how small `n_BE`/
`n_FD` themselves already are."

### 5. Fermi-Dirac's T->0 step width: an exact linear scaling, not merely observed to hold at one T

The 10-90 transition width (energy range where `n_FD` falls from `0.9`
to `0.1`) has the closed form `width = kT * (Log[1/0.1-1] -
Log[1/0.9-1]) = 2*Log[9]*kT` — an immediate consequence of inverting
`n_FD(eps)=p` for `eps`, since the formula is linear in `kT*Log[...]`
for any fixed pair of probability levels. Verified numerically at
`T={100,1000,10000}` K: `width/kT` is constant to 10 significant
figures across two full decades of `T` (`4.394449154672...`, matching
`2*Log[9]` symbolically). `FermiDiracStepLimitCheck` tests this
scaling directly (three `T` values, not one) rather than merely
confirming the step looks sharp at a single small `T`.

### 6. spectrum mode's three-voice design: simultaneous, not sequential — and why

The build brief offered a choice: "three voices in different
registers, or a sequential tour through all three at the same T." This
app uses simultaneous voices (BE hard-left/low-register, FD
centre/mid-register, MB hard-right/high-register — see
`$qsVoiceRanges`/`$qsVoicePans` in `sonify.wl`) because the mode's own
question — "at this T, do the three distributions sound similar or
very different" — can only be answered by DIRECT, SIMULTANEOUS
comparison. A sequential tour would force comparing against short-term
auditory memory rather than hearing the (dis)agreement directly, the
same reasoning `bell/correlations` applies for its own classical-vs-
quantum binaural (not sequential) design. `temperature` mode reuses
the identical three-voice/three-register scheme, continuously swept,
for consistency and for the same direct-comparison reason.

### 7. Per-voice amplitude normalisation: each distribution normalised to its OWN peak, not a shared peak

`NormalizeSpectrumAmps` divides each distribution's array by ITS OWN
max (matching `thermo/`'s `MBSpectrumBins` convention exactly), not a
peak shared across all three voices. Bose-Einstein's occupation can
span many more orders of magnitude than Fermi-Dirac's (which is capped
at 1) or Maxwell-Boltzmann's, so a shared-peak normalisation would
make BE's voice silent everywhere except its single largest bin. Per-
voice normalisation keeps every voice audible as its own spectral
shape — the STEEPNESS/shape of each voice's envelope (not their
relative absolute loudness) is what carries the "similar vs different"
information this mode is built to convey.

### 8. Joint stereo normalisation applied once, after mixing all voices — a bug caught during smoke-testing

An early version of `temperature` and `fermi_sea` modes' audio
exceeded +-1.0 peak amplitude (`1.003` and `1.38` respectively,
measured directly) because summing multiple already-normalised voices
(or a full-width spectral frame) can exceed unity even when each
individual voice/bin was itself bounded. `QsNormalizeStereoPair` scales
BOTH channels by the SAME factor (preserving pan balance — normalising
each channel independently would shift the stereo image) to a `0.9`
ceiling, applied once at the end of every `Build*Audio` function, after
mixing. Caught by directly checking `Max[Abs[...]]` on the returned
buffers during development, not assumed safe from the per-voice
normalisation alone.

## Animation framing: GIF/WAV duration desync (fixed post-v1.5.0)

**The bug.** All three modes' GIFs played for a fixed, hardcoded
duration entirely decoupled from their paired WAV's real length.
`spectrum` and `temperature` rendered `Min[40,nSteps]` frames at a
hardcoded 12fps (~3.2-3.3s of playback) regardless of the
`sonification.duration` config value (8.0s by default) driving the
audio. `fermi_sea` rendered `nTSteps+4` frames (extra holds on the
coldest/warmest step) at a hardcoded 2fps. Measured directly on the
committed `output/` files before this fix:

| Pair | GIF | WAV | ratio |
|------|-----|-----|-------|
| `fermi_sea` | 5.00s | 22.97s | 0.22x |
| `spectrum` | 3.20s | 30.62s | 0.10x |
| `temperature` | 3.20s | 29.69s | 0.11x |

The WAV side runs long chiefly because every mode prepends a spoken
intro (`BuildIntroBuffer`) plus a 0.4s pause ahead of the main
sonification — the GIF frame budget never accounted for that, or for
the config-driven `duration`/`nTSteps` values either.

**Root cause.** Same class of bug as `lorenz/`'s reference fix and
`compton/`'s prior fix (see those apps' own `animate.wl`/`AGENTS.md`):
`AnimateSpectrum`/`AnimateTemperature`/`AnimateFermiSea` built a frame
count and frame rate independent of the length of the audio the GIF
would actually play alongside.

**The fix.** Each `AnimateX` function in `src/animate.wl` now takes a
`targetDuration_?NumericQ` parameter — the accompanying WAV's real,
final length (spoken intro + pause + main audio, the same value
`STEMDescribeWAV` reports) — plus `nFrames` reinterpreted as a RENDER
BUDGET rather than a literal count: `frameRate =
Clip[nFrames/targetDuration, {$MinAnimationFps, $MaxAnimationFps}]`
(2-30fps), and `actualNFrames = Max[2, Round[frameRate *
targetDuration]]` is what flexes at the clamp boundary so playback
lands on `targetDuration` exactly, not approximately. `DeleteDuplicates`
was dropped from `spectrum`/`temperature`'s frame-index sampling (a
repeated index just holds a frame slightly longer, which is fine — the
prior `DeleteDuplicates` would have shrunk the frame count below
`actualNFrames` and pulled playback back out of sync, the same reason
`compton/src/animate.wl` dropped it). `fermi_sea`'s original
coldest/warmest hold pacing is preserved by building a `baseIndices`
sequence (`{1,1}, Range[1,nT], {nT,nT}`) and resampling THAT to
`actualNFrames` slots, rather than a fixed 2 extra frames.

Because every mode's WAV includes a spoken intro built AFTER the
original code path called `AnimateX` in `main.wl`, the mode blocks in
both `main.wl` and `experiments.wl` were reordered so audio (intro +
pause + main sonification, exported to disk) is built and its total
`wavDuration`/`totalDurSec` computed BEFORE `AnimateX` runs — the same
"audio first, GIF targets the real WAV length" ordering
`compton/main.wl` already uses.

**Verification status.** Confirmed. All three modes were regenerated
(`wolframscript -file main.wl -- --simulation.mode={spectrum,temperature,fermi_sea}`)
and re-measured with the same GIF/WAV duration method:

| Pair | GIF (after) | WAV (after) | ratio |
|------|-------------|-------------|-------|
| `fermi_sea` | 23.00s | 22.97s | 1.001x |
| `spectrum` | 30.50s | 30.62s | 0.996x |
| `temperature` | 29.50s | 29.69s | 0.994x |

`wolframscript -file tests/test_model.wl` — 26 passed, 0 failed (test
suite covers `model.wl` only; unaffected by the `animate.wl` change,
confirms no regressions elsewhere).

## Numeric findings from this build session (new results, not assumed in advance)

- **Classical-limit threshold**: at `(eps-mu)=10*kT` (T=300K,
  `eps=0.2585` eV), `relErr_BE = relErr_FD = 4.540e-5` — comfortably
  under the `1e-4` tolerance `ClassicalLimitCheck` actually uses.
- **T->0 step width scaling**: `width/kT = 4.394449154672...` (exactly
  `2*Log[9]`), constant to 10 significant figures across
  `T={100,1000,10000}` K.
- **Bose-Einstein divergence** (T=50000K, mu=0): `n_BE` grows from
  `42.6` at `eps-mu=0.1` eV to `430866.2` at `eps-mu=0.00001` eV —
  confirmed still growing (not plateauing) at the smallest tested gap.
- **kB in eV/K**: `8.617333262e-5`, derived from SI `kB` (J/K) and the
  exact eV-to-J conversion — reproduces the standard "kT~0.0259 eV at
  300K" fact to the precision shown.

## Project structure

```
quantum_statistics/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json            — default simulation parameters
  experiments.wl          — 7 curated preset invocations
  LISTENING_GUIDE.md       — user-facing recommended listening sequence
  AGENTS.md                 — this file
  src/
    model.wl                 — BE/FD/MB occupation numbers (guarded), four
                          correctness checks, three per-mode model builders
    sonify.wl                  — SynthesizeAdditiveFrame (duplicated from
                          thermo/src/sonify.wl), three-voice spectrum/
                          temperature technique, fermi_sea's per-T-frame
                          concatenation, joint stereo normalisation
    speech.wl                    — Spoken intro synthesis and per-mode intro text
    animate.wl                     — log10(n) curve plots (spectrum,
                          temperature), Fermi-Dirac step animation (fermi_sea)
    output.wl                       — CSV export and console summaries
  tests/
    test_model.wl                  — Unit tests (occupation numbers, exact
                          classical-limit identity, step-width scaling, all
                          four correctness checks, model builders)
  output/                           — generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                      # spectrum, T=300K
wolframscript -file main.wl -- --simulation.mode=temperature       # sweep T, fixed eps
wolframscript -file main.wl -- --simulation.mode=fermi_sea          # FD step, cold to warm
wolframscript -file main.wl -- --simulation.quantum_statistics.temperature=30000
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks

All four run unconditionally, every invocation, regardless of mode,
always at fixed canonical parameters (independent of the active
mode's own configured T/energy):

1. **Classical limit, exact identity** — see design decision 4. Tested
   at `x=10`, tolerance `1e-4`.
2. **Fermi-Dirac bound** — `n_FD<1` for a wide `(eps,T)` sweep. Exact,
   tight tolerance.
3. **T->0 Fermi-Dirac step** — see design decision 5. Scaling verified
   at three `T` values.
4. **Bose-Einstein divergence** — grows without bound; domain guard
   confirmed to engage. See design decision in model.wl's own header
   comment for check 4.

## Common pitfalls

1. **Print with `ScientificForm[...]` directly does not render in
   headless wolframscript** — same class of issue `FmtN`'s own
   docstring warns about for `NumberForm`/`OutputForm`: it prints the
   literal unevaluated `ScientificForm[x,n]` expression, not formatted
   text. Use `FmtN[x, spec]` (which produces inline `*^` notation)
   instead — caught during this app's own smoke-testing (see `main.wl`
   git history) after a first version's check-3 print line came out
   showing `ScientificForm[0.00669...,4]` literally.
2. **`FmtN[x, N]` with a small integer `N` breaks on multi-digit
   values** — the same `NumberForm::reqsigz` pitfall `bell/AGENTS.md`
   and `pendulum/AGENTS.md` document. Occupation-number magnitudes
   here range from single digits to hundreds of thousands (Bose-
   Einstein near its divergence), so fixed-decimal specs (e.g.
   `{9,1}`) are used wherever a printed value's magnitude isn't
   tightly bounded in advance.
3. **Summing multiple independently-normalised audio voices, or a
   full-width spectral frame, can exceed +-1.0 even when each
   component was individually bounded** — see design decision 8.
   Always check `Max[Abs[...]]` on a `Build*Audio` function's actual
   returned buffers, don't assume per-voice normalisation alone is
   sufficient.
4. **The familiar "cold = quantum-degenerate" intuition does not
   transfer to a mu=0 system** — see design decision 3. Verify the
   actual direction of any "quantum vs classical" claim against the
   specific chemical-potential convention in use before stating it.
5. **`tolerance_?NumericQ:0.05`-style optional-argument patterns parse
   WRONG** in WL — binds as `tolerance_ ? (NumericQ:0.05)`, not
   `Optional[tolerance_?NumericQ, 0.05]`. Same pitfall documented in
   every prior v1.5.0 app's `AGENTS.md`; avoided throughout via
   explicit `Optional[x_?NumericQ, default]`.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSection`, `STEMSay`, `STEMPrintN`,
  `STEMDescribeWAV`, `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`,
  `STEMPlayCmd`, `NormalizeBuffer`, `ExportGIF`, `ExportCSV`,
  `EnsureDir`.
- **Mathematica/WL**: `Accumulate` (phase-accumulation glissando in
  `temperature` mode), `Clip`/`Log`/`Log10` (log-compression),
  `Graphics`, `Sound`, `SampledSoundList`, `Export`,
  `SpeechSynthesize`, `AudioQ`, `AudioData`, `AudioSampleRate`,
  `RunProcess` (platform TTS fallback), `Import` (reading
  TTS-generated WAV files).

## Speech synthesis note

`speech.wl`'s three-tier fallback (`SpeechSynthesize[]` -> platform TTS
-> text-only `STEMSay`) duplicates the pattern already used in
`bell/src/speech.wl`, `grover/src/speech.wl`, and every other app's
`speech.wl` file — still out of scope for stem-core consolidation per
every prior app's own build spec.

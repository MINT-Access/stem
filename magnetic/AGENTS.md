# magnetic — AGENTS.md

## What this app does

Simulates a charged particle's motion under the Lorentz force,
`F = q(E + v x B)`, across four distinct field configurations:

| Mode | Physics | Output |
|------|---------|--------|
| `cyclotron` (default) | Uniform B, no E — circular/helical orbit at a constant frequency | Steady tone at omega_c; panning marks the orbit |
| `drift` | Uniform B and E — cycloidal E x B drift | Oscillating pitch, monotonically drifting pan |
| `mirror` | Non-uniform B(z) — magnetic bottle | Rising/falling pitch, accents at each reflection |
| `multi` | Uniform B, three particles simultaneously | A chord: proton, alpha particle, electron |

Units are dimensionless and SI-inspired: `charge_mass_ratio` (q/m) is
supplied directly, so `omega_c = charge_mass_ratio * B_z` with no
separate mass parameter (equivalent to setting m=1).

## Key design decisions (read before modifying sonify.wl or model.wl)

### 1. Manual carrier synthesis, not stem-core's `SonifyTrajectory`

Every mode's pitch must literally equal (a scaled version of) a
specific physical rate — cyclotron mode's tone must sit at exactly
`omega_c`, a *constant*, not a value that oscillates within a range.
Stem-core's `SpatialLayer` produces pitch by `Rescale[val,
MinMax[val], pitchRange]` — for a genuinely constant source this is
degenerate (`MinMax` collapses to a point, `Rescale` divides by zero
range), and for the cases where the source does vary (drift's x, or
mirror's |z|), what we actually want is still a hand-built frequency
array so accent times can align with **physically detected** events
(orbit completions, cycloid minima, mirror reflections) rather than
`EventLayer`'s built-in apex/crossing detectors, which don't match any
of those. This is exactly the situation `relativity/src/sonify.wl`'s
`SonifyGeodesic` already solved the same way (manual frequency array +
phase-accumulated carrier) — this app follows that established
precedent rather than stem-core's three-layer pipeline. See
`sonify.wl`'s module header for the per-function breakdown.

The trajectory data itself is still produced in the generic
`{t, x, y, z, speed}`-shaped form (used for CSV export and the
correctness checks) — only the audio synthesis bypasses the pipeline.

### 2. Mirror mode needs a radial field component the spec's formula omits

`Bz(z) = B0(1 + alpha z^2)` alone cannot produce a mirroring force: the
Lorentz force from a purely-z field never has a z-component
(`(v x B)_z = vx*By - vy*Bx = 0` when `Bx=By=0`), so `dvz/dt` would be
identically zero and the particle would never turn around. A real
axisymmetric mirror field must also satisfy `div B = 0`; expanding
near the axis gives a small radial component:

```
Br(r,z) ~ -(r/2) dBz/dz   =>   Bx = -alpha*B0*x*z,  By = -alpha*B0*y*z
```

This is the textbook near-axis expansion used in magnetic-bottle / PIC
mirror simulations (Chen, *Introduction to Plasma Physics*;
Birdsall & Langdon). `IntegrateMirror` uses the full 3-component field;
without it, check 3 (trapping) would fail for every configuration.

### 3. E x B drift direction: `-Ex/Bz`, not `+Ex/Bz`

The build notes state `v_drift = (E x B)/|B|^2 = (Ex/Bz) yhat`. Carried
through with the standard Lorentz force and `B = Bz zhat`, `E = Ex
xhat`, the correct cross product is `E x B = Ex*Bz*(xhat x zhat) =
-Ex*Bz*yhat`, giving `v_drift = -Ex/Bz yhat` — a sign flip from the
build notes, not a bug. Only the *direction* (an arbitrary
right-hand-rule/axis convention) differs; the *magnitude* `|Ex/Bz|` is
exactly what correctness check 2 verifies. `IntegrateDrift`'s
`vDrift` field is signed (`-Ex/Bz`); `tests/test_model.wl` checks
`Abs[vDrift] == Ex/Bz` rather than assuming a particular sign.

### 4. Mirror's `B_max` comes from a derived length scale, not a config key

The trapping formula `sin^2(theta_0) > B0/Bmax` needs a finite `Bmax`,
but `B0(1+alpha z^2)` is unbounded as `z -> infinity` — every particle
with any nonzero pitch angle would eventually mirror given enough
field. Real mirror machines are finite between two coils, so
`IntegrateMirror` treats `zScale = 3/Sqrt[alpha]` as the axial extent
of the modelled region (a particle that outruns this without
reflecting is called "escaping"). This choice is deliberate: it makes
`Bmax = B0(1 + alpha*zScale^2) = 10*B0` for **any** `alpha`, so the
trapping threshold `sin^2(theta_0) > 0.1` is a universal constant of
this app, independent of the `alpha` config value. This is not exposed
as a separate config key — it is derived internally from `alpha` so
the config surface matches the build spec exactly.

### 5. `multi` mode uses the closed-form solution, not NDSolve

`cyclotron`, `drift`, and `mirror` all call `NDSolve` per the general
instruction to integrate numerically. `multi` mode is the one
exception: the electron's `charge_mass_ratio` is 1836x the proton's,
so resolving its gyration numerically over the *same* time window as
the proton would need ~1836x finer steps for a physically trivial
result — the uniform-field cyclotron solution is exact and cheap to
evaluate in closed form (`MultiParticleOrbit`) for all three particles
via `x(t) = r*Sin[omega*t]`, etc. Energy conservation for `multi` is
therefore exact by construction (checked only to numerical precision).

### 6. `base_freq_hz` is a single audio-frequency scale used by all four modes

The build notes only mention `base_freq_hz` in the context of `multi`
mode's proton reference tone. This app reuses the same constant across
`cyclotron`, `drift`, and `mirror` too: `base_freq_hz` is "the Hz value
that `omega_c = 1` (i.e. `B_z=1`, `charge_mass_ratio=1`, the proton-like
default) maps to." This gives one consistent, documented audio scale
app-wide instead of introducing a second, redundant
`sonification.magnetic.pitch_scale_hz` key.

### 7. Energy-conservation check (4) differs for `drift` mode

The magnetic force does no work, so `|v|^2` is exactly conserved for
`cyclotron`, `mirror`, and `multi` (checked as "range < 0.1% of mean").
`drift` mode's electric field *does* do work instantaneously — `|v|^2`
oscillates periodically through the cycloid — so constancy is the
wrong check there. Instead, `IntegrateDrift` checks that `KE(0)` and
`KE(t_max)` agree within 0.1%, since `t_max` is always an exact integer
number of cyclotron periods (`n_periods * Tc`) and the E x B motion is
exactly periodic in that frame: the net work over any whole number of
periods is zero.

### 8. `mirror` mode gets its own `v_perp`/`v_parallel` defaults, applied in `main.wl`

`config.json`'s `v_perp`/`v_parallel` (1.0/0.0) are shared across all
four modes to match the spec's single JSON config block exactly, but
that pair describes cyclotron/drift's "pure circular orbit" default —
mirror mode's own prose wants `v_perp=1.5`, `v_parallel=0.8` (a
trapped-particle pitch angle) as *its* default. Both can't live in the
same shared JSON keys without one winning over the other, and once
`config.json`'s values are merged into `cfg` there is no way to tell
"came from config.json" apart from "explicit CLI override." `main.wl`
resolves this the same way `relativity/main.wl` resolves its chirp
presets: a conditional `DeepMerge` applied after `LoadConfig` but
before dispatch, checking `$cliArgs` directly for
`--simulation.magnetic.v_perp=`/`v_parallel=` and only substituting
mirror's own defaults when the user didn't pass them explicitly. This
does not affect `--config-dump`, which exits inside `LoadConfig`
before this resolution runs — it still reports the literal
`config.json` values (1.0/0.0), exactly matching the given config
block.

### 9. The trapping formula assumes adiabaticity — shallow-pitch escape demos need a gentle gradient

`sin^2(theta_0) > B0/Bmax` is a guiding-center result: it assumes the
magnetic moment `mu = v_perp^2/B` is an adiabatic invariant, which only
holds when the field varies slowly compared to one gyro-period (many
gyro-orbits per unit distance travelled along `z`). A shallow pitch
angle (small `v_perp`, large `v_parallel`) — exactly the "escaping"
case — crosses the mirror region *fast*, and pairing that with a steep
gradient (large `alpha`) can badly violate adiabaticity: check 3 can
then legitimately fail (the full Lorentz-force simulation, which makes
no adiabatic assumption, shows different behaviour than the simple
formula predicts). This is real physics, not a bug — `experiments.wl`'s
escaping-particle preset uses a gentler gradient (`alpha=0.08` instead
of the 0.5 default) specifically to stay in the regime where the
simple criterion is reliable; a shallow-pitch preset with the default
`alpha` can flip check 3 to `[FAIL]` for this reason.

### 10. Checks are organized per-mode, not as a mechanically forced four — a deliberate choice, verified during the v1.5.0 correctness audit

Most apps in this codebase print four correctness checks unconditionally
on every run. This app deliberately does NOT: `{cyclotron period, E x B
drift velocity, mirror trapping}` are each meaningful ONLY in their own
mode — a drift-velocity check makes no sense during `mirror` mode (there
is no `E` field), and a trapping-condition check makes no sense during
`cyclotron` mode (there is no field gradient to trap against). Forcing
all four to print regardless of mode would mean printing checks that test
nothing meaningful for the active configuration — worse than the current
design, not better.

**Energy conservation is checked in all four modes** (see design decision
7 for why `drift` mode's version differs), so a single run always prints
exactly two checks: one universal (energy), one mode-specific — except
`multi` mode, which as of this audit prints two mode-specific checks
(energy plus the new frequency-ratio check below), for three total
distinct checks across its own two lines.

This structure was correct all along but was previously only observable
by reading the code — nowhere did it say "this is deliberate," which is
what let it look inconsistent with newer apps' four-checks convention at
a glance during the audit. This section exists to close that gap:
if you are comparing this app's checks against another app's AGENTS.md
and wondering why the counts differ, this is why, and it is not a bug
or a gap to fix.

### 11. `multi` mode's frequency-ratio check (added during the audit) verifies the SOLUTION against the ODE, not the formula against itself

`multi` mode previously checked only energy conservation. A second check
was added: that each particle's cyclotron frequency ratio matches its
`charge_mass_ratio` exactly, since `omega = kRatio*Bz` (and hence
`omega_electron/omega_proton = kElectron/kProton` identically, `Bz`
cancelling) is otherwise not tested by anything.

**A numerical (sampled) frequency measurement was considered and
rejected.** The electron's period is `1836x` shorter than the proton's;
on the SAME time grid `BuildMultiModel` uses to render all three
particles (~300 points per PROTON period, sized for the proton's own
resolution), the electron gets under 1 sample per its own period — far
below Nyquist, making any zero-crossing-based period measurement
meaningless for it without a separate, dedicated fine grid per particle.

**`MultiFrequencyRatioCheck` instead verifies the closed-form solution
itself satisfies the Lorentz-force ODE symbolically** —
`MultiParticleOrbit`'s `x(t)=r*Sin[omega*t]`, `y(t)=r*(Cos[omega*t]-1)`
is checked against `x''=k*y'*Bz`, `y''=-k*x'*Bz` via `D[]` and
`Simplify[]`, for each particle's own `(kRatio,Bz)` pair, evaluated at a
couple of arbitrary `t` values to get a numeric residual. This is exact
(no numerical trajectory involved at all, so no sampling/aliasing concern
for any particle regardless of frequency), and is a genuinely independent
check: it tests the SOLVED FORM against the DIFFERENTIAL EQUATION it
claims to solve, not `omega=kRatio*Bz` restated against itself (which
would be tautological — `Bz` cancels trivially from a frequency-ratio
comparison built the same way the generator computes it). Residuals in
practice: exactly `0.` for proton and alpha, `~2e-13` for the electron
(floating-point noise from `Simplify` on the larger `kRatio=1836`
coefficient, still 4 orders of magnitude below the check's `1e-6`
tolerance).

## Project structure

```
magnetic/
  main.wl              — thin orchestrator: config, mode dispatch
  config.json          — default simulation parameters
  experiments.wl       — 10 curated preset invocations
  LISTENING_GUIDE.md   — user-facing recommended listening sequence
  AGENTS.md            — this file
  src/
    model.wl           — EOM + NDSolve integration (cyclotron/drift/mirror),
                         closed-form multi-particle model, correctness checks 1-4
    sonify.wl          — manual carrier synthesis, event bursts, spoken intro
                         (SpeechSynthesize -> platform TTS -> text fallback)
    animate.wl         — GIF rendering for all four modes
    output.wl          — CSV export (one row per sample; multi mode uses
                         long format with a "particle" label column)
  tests/
    test_model.wl      — 5 unit tests (period, drift, trapping, energy, radius)
  output/              — generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                          # cyclotron, default
wolframscript -file main.wl -- --simulation.mode=drift                # E x B drift cycloid
wolframscript -file main.wl -- --simulation.mode=mirror               # magnetic mirror
wolframscript -file main.wl -- --simulation.mode=multi                # proton+alpha+electron
wolframscript -file main.wl -- --simulation.magnetic.v_parallel=0.5   # helix orbit
wolframscript -file main.wl -- --simulation.magnetic.E_x=1.0          # faster drift
wolframscript -file main.wl -- --simulation.magnetic.alpha=1.0        # stronger mirror
wolframscript -file main.wl -- --simulation.magnetic.B_z=2.0          # stronger field
wolframscript -file main.wl -- --simulation.magnetic.base_freq_hz=220 # higher pitch base
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks (printed on every run)

1. **Cyclotron period** (`cyclotron`) — measured from positive-going
   zero-crossings of `x(t)`, compared to `2*Pi/omega_c` within 1%.
2. **E x B drift velocity** (`drift`) — mean `vy` compared to the
   analytic `-Ex/Bz` within 2%.
3. **Mirror trapping** (`mirror`) — analytic `sin^2(theta_0) > B0/Bmax`
   compared against the simulated outcome: `>= 2` sign changes of
   `v_parallel` within the observation window counts as trapped (proof
   of genuine back-and-forth bouncing, not just a one-off reflection);
   fewer counts as escaping. `zScale` (decision 4) is used only to
   derive the analytic `Bmax` prediction, not to judge the simulated
   outcome — the true dynamics aren't bound to stay under it.
4. **Energy conservation** (all modes, see design decision 7) — `|v|^2`
   constant to 0.1% for `cyclotron`/`mirror`/`multi`; periodic return
   to 0.1% for `drift`.
5. **Cyclotron frequency ratios** (`multi` only, added during the v1.5.0
   correctness audit — see design decision 11) — each particle's
   closed-form orbit exactly solves the Lorentz-force ODE at its own
   `charge_mass_ratio`, verified symbolically (not a sampled measurement
   — the electron's period is too short relative to the shared time grid
   for that to be meaningful). Exact relation, tight tolerance.

Each mode prints exactly the checks meaningful for it (see design
decision 10): `cyclotron` prints 1+4, `drift` prints 2+4, `mirror` prints
3+4, `multi` prints 4+5 — never a mechanically forced four regardless of
mode.

## Common pitfalls

1. **`SafeRescale`, not `Rescale`, for anything derived from `speed`
   in cyclotron mode** — speed is exactly constant there, so a plain
   `Rescale[speed, MinMax[speed], range]` divides by a zero-width
   range and returns `Indeterminate`. `SafeRescale` returns the range
   midpoint instead.
2. **`multi` mode's frequencies are independent of `B_z`** — proton is
   always remapped to exactly `base_freq_hz` (alpha to half, electron
   to 8x) regardless of the configured field strength, by design (see
   decision 6): only `cyclotron`/`drift`/`mirror` audio frequencies
   scale with the actual `omega_c`.
3. **Mirror mode's `zScale` is derived, not configurable** — see
   design decision 4. Changing `alpha` changes both the physical
   gradient and the modelled machine length together.
4. **Load order in `main.wl` matters**: `sonify.wl` defines
   `SafeRescale`, which `animate.wl`'s drift-trail colouring also
   calls — `sonify.wl` must load before `animate.wl`.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `STEMHeading`,
  `STEMSay`, `STEMPrintN`, `STEMDescribeWAV`, `STEMDescribeGIF`,
  `STEMDescribeCSV`, `FmtN`, `STEMPlayCmd`, `NormalizeBuffer`,
  `ExportAudioBuffer`, `ExportGIF`, `ExportCSV`, `EnsureDir`.
  Deliberately **not** used: `SonifyTrajectory`, `SpatialLayer`,
  `MotionLayer`, `EventLayer`, `MixLayers`, `RenderAudio` — see design
  decision 1.
- **Mathematica/WL**: `NDSolve`, `WhenEvent` (implicitly via sign-change
  post-processing rather than event-based stopping), `Graphics`,
  `Graphics3D`, `ColorData`, `Blend`, `Export`, `SpeechSynthesize`,
  `AudioQ`, `AudioData`, `AudioSampleRate`, `RunProcess` (platform TTS
  fallback), `Import` (reading TTS-generated WAV files).

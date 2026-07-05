# scattering — AGENTS.md

## What this app does

Simulates and sonifies Rutherford alpha-particle scattering — the
1909-1911 Geiger-Marsden experiment that discovered the atomic
nucleus — across three modes:

| Mode | Physics | Output |
|------|---------|--------|
| `scatter` (default) | Single alpha particle, NDSolve trajectory in polar coordinates | Rising/peaking/falling pitch and volume, accent at closest approach |
| `distribution` | Beam of particles, realistic impact-parameter sampling | Dense quiet stream, rare loud backscatter accents |
| `discovery` | Thomson vs Rutherford, same beam geometry, different nuclear model | Binaural: quiet-only Thomson left, Rutherford (with outliers) right |

Units are scaled and dimensionless (see `src/model.wl`'s header): the
head-on distance of closest approach `d = k*q1*q2/(2E)` and the
asymptotic speed `v_inf` are both set to 1, m=1 (same convention as
`magnetic/` and `lagrange/`). This makes the specific energy exactly
`1/2` and the specific angular momentum exactly `b` (the impact
parameter itself) — both conserved quantities, and both used directly
as correctness checks 2 and 3.

## Key design decisions (read before modifying sonify.wl or model.wl)

### 1. `scatter` mode uses stem-core's layer functions directly, not `SonifyTrajectory` — and not manual synthesis either

Unlike `magnetic/` and `relativity/`, which bypass stem-core's
three-layer pipeline entirely (their tone must sit at an exact
constant physical rate, which `SpatialLayer`'s auto-rescaling cannot
express), `scatter` mode's trajectory maps onto the pipeline cleanly:

- **Pitch** needs `Log[1/r]`, not real `y` — so the trajectory's `y`
  slot holds `Log[1/r]` instead of the real Cartesian `y` position.
  This is the same idiom `lagrange/src/sonify.wl`'s `SonifyLibration`
  already uses (its `y` slot holds angular velocity, not real `y`) and
  `asteroids/src/sonify.wl` uses for its `z` slot (asteroid diameter,
  not a spatial coordinate) — put whatever physically-meaningful
  quantity you want sonified into the unused slot, and set the pitch
  axis (default `"y"`) to read it.
- Because `Log[1/r]` peaks exactly at periapsis, stem-core's built-in
  `EventLayer` `"apex"` detector (a local maximum of the `y` column)
  fires exactly at closest approach — no bespoke event-timing code
  needed for the periapsis accent.
- **What is NOT used**: the `SonifyTrajectory` convenience wrapper
  itself, only because it exports the WAV directly with no hook for a
  prepended spoken intro. `SpatialLayer`, `MotionLayer`, `EventLayer`,
  and `MixLayers` (all public stem-core symbols) are called directly
  instead, and the resulting stereo buffer is prepended with speech
  audio before export — the same thing every app with a spoken intro
  in this codebase has to do by hand (see decision 2).

The one accepted deviation from the build spec's literal text: the
periapsis accent comes out at 880 Hz / 40 ms (stem-core's fixed
`"apex"` event constants) rather than the spec's suggested 880 Hz /
80 ms. The frequency already matches exactly; only the burst duration,
a shared stem-core constant not exposed per-call, differs.

### 2. `distribution` and `discovery` modes are bespoke discrete-note synthesis, not `SonifyTrajectory`

A 200-particle beam (or a 100-per-model Thomson/Rutherford comparison)
is a stream of discrete one-shot events, not one continuously-varying
trajectory. Feeding it to `SonifyTrajectory` would spline-interpolate
pitch/pan *between* particles into one continuous glide — exactly
wrong for "a dense stream of individual events punctuated by rare loud
ones." This is the same reasoning `bayes/src/sonify.wl` gives for its
own discrete pentatonic summary layer (`StemSynthNote` + manual
placement, not `SonifyTrajectory`).

`discovery` mode additionally needs two genuinely *independent* stereo
channels — Thomson content only in the left channel, Rutherford
content only in the right — not a single shared pan value one
trajectory's `x` column could produce. This is closer to
`magnetic/src/sonify.wl`'s `SonifyMulti` (separate carriers built and
placed into `leftCh`/`rightCh` independently) than to any single-pan
trajectory sonification.

The backscatter accent (theta > 90 deg, 660 Hz) is a small locally-
defined `ScatteringAccentBurst` helper, the same short-decaying-sine
construction stem-core's own `EventLayer` and `magnetic`'s
`BuildEventBurstArray` use, duplicated here (as `bayes/AGENTS.md` and
`magnetic/AGENTS.md` both do for their own event bursts) because
`EventLayer`'s built-in detectors are hardcoded to the raw `x`
(crossing) and `y` (apex) columns and to fixed 440/880 Hz frequencies —
none of which can express "660 Hz exactly when theta > 90 deg" for a
per-particle event list.

### 3. Spoken intro/outro: `SpeechSynthesize[]` -> platform TTS -> text fallback, duplicated per app

`ResampleLinear`, `ScatteringSpeakToBufferPlatform`, `BuildIntroBuffer`,
and `PrependIntroAndExport` in `src/sonify.wl` are the same three-tier
pattern (and largely the same code) as `magnetic/src/sonify.wl`'s
equivalents. Apps do not import each other's `src/` files (only
stem-core is shared), so this is duplicated rather than factored out —
consistent with the rest of the codebase. `discovery` mode additionally
appends a spoken *outro* after the main audio (the historical
conclusion) — no other app in this codebase currently does this, so
that half of `SonifyDiscovery` (building and joining `outroBuf`) is
new, not copied from a precedent.

### 4. `r_initial` gets a safety margin the spec's config default doesn't guarantee

The polar-coordinate initial conditions require
`1 - 2/r_initial - (b/r_initial)^2 > 0` (so the initial radial speed
is real). For the default `r_initial=20.0`, this fails once `b`
approaches ~19-20 — plausible with `--simulation.scattering.b_max=12.0`
(a listed CLI example) if `r_initial` were left untouched for a
distribution-like large `b`. `ScatterModel` uses
`rInitEff = Max[r_initial, 3*b + 5]` and prints a `[note]` when it
raises the configured value, rather than letting `Sqrt` of a negative
number silently produce `Indeterminate`.

### 5. Test 3 keeps the spec's `< 6 deg` bound but corrects `b`

The build spec's own test asks: "verify b=10 gives theta < 6 deg."
Using the very formula the spec derives (`theta = 2*ArcCot[b]`, `d=1`),
`theta(10) = 2*ArcCot[10] ~ 11.42 deg` — it does not satisfy that
bound; `theta(20) ~ 5.72 deg` does. `tests/test_model.wl` keeps the
`< 6 deg` threshold (the actual small-angle-limit intent) and uses
`b=20`, the value the formula actually places under it, rather than
silently keeping `b=10` and a threshold the physics cannot satisfy.

### 6. Cross-section check (4) uses a statistical tolerance, not a flat 20%

`theta(b) = 2*ArcCot[b]` is a monotonic bijection with `d=1`, so
`theta > 90 deg` iff `b < b_90 = 1.0` exactly (`cot(45 deg) = 1`) — a
universal constant of this app, independent of `b_max`. With
`b ~ sqrt(Uniform[0, b_max^2])`, `P(b < 1) = 1/b_max^2`. At the
defaults (`n=200`, `b_max=8`) the expected backscatter count is only
`200/64 ~ 3.1` particles — Poisson noise alone is ~57% relative at
that count, so a flat "within 20%" relative tolerance (as the build
spec's own check 4 text asks for) would fail on pure statistical noise
more often than not. `DistributionModel`'s check instead compares the
observed count against a `>= 3-sigma` binomial band around the
expectation (floored at 20% of the expectation and at 1 particle, so
the tolerance never collapses to zero for tiny expected counts).

### 7. The radial equation of motion: `+1/r^2`, not the build spec's `-1/r^2`

The build spec's own text gives the scaled radial equation as
`r'' - r*phi'^2 = -1/r^2`. That is the standard **attractive** (Kepler)
radial equation sign — correct for gravity or an attractive Coulomb
force, wrong for the repulsive alpha-nucleus interaction this app
simulates. For a repulsive potential `V(r) = +1/r` (the same
convention the spec's own energy equation and `r_min = 1+Sqrt[1+b^2]`
formula both assume), the Euler-Lagrange radial equation is
`r'' = r*phi'^2 + 1/r^2` — a sign flip. Using the spec's literal
`-1/r^2` was verified (not assumed) to be wrong during development: it
produced a ~6 deg error between the measured and analytic scattering
angle for `b=1` (96.2 deg measured vs 90.0 deg analytic) and failed
correctness check 3 by a wide margin (energy deviating by ~0.58 from
the conserved `0.5`, nowhere near the 0.1% tolerance). `ScatterModel`
uses `+1/r^2`; both checks pass cleanly with this correction (see
`src/model.wl`'s module header for the same note in code).

## Project structure

```
scattering/
  main.wl              — thin orchestrator: config, preset resolution, mode dispatch
  config.json          — default simulation parameters
  experiments.wl       — 10 curated preset invocations
  LISTENING_GUIDE.md   — user-facing recommended listening sequence
  AGENTS.md            — this file
  src/
    model.wl           — polar-coordinate NDSolve trajectory (scatter),
                         beam sampling (distribution), Thomson/Rutherford
                         comparison (discovery), correctness checks 1-4
    sonify.wl          — stem-core layer functions (scatter) + bespoke
                         discrete-note synthesis (distribution/discovery),
                         spoken intro/outro
    animate.wl         — GIF rendering for all three modes
    output.wl          — CSV export (one row per sample/particle)
  tests/
    test_model.wl      — 5 unit tests (90 deg, 180 deg, small-angle,
                         angular momentum, energy)
  output/              — generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                          # scatter, b=1.0 (90 deg)
wolframscript -file main.wl -- --simulation.scattering.preset=headon
wolframscript -file main.wl -- --simulation.scattering.preset=backscatter
wolframscript -file main.wl -- --simulation.scattering.preset=glancing
wolframscript -file main.wl -- --simulation.scattering.b=2.0
wolframscript -file main.wl -- --simulation.mode=distribution
wolframscript -file main.wl -- --simulation.mode=discovery
wolframscript -file main.wl -- --simulation.scattering.n_particles=500
wolframscript -file main.wl -- --simulation.scattering.b_max=12.0
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks (printed on every run)

1. **Rutherford formula** (all modes) — fixed `b=1.0` gives
   `theta=90.000 deg` within `0.01 deg`.
2. **Angular momentum conservation** (`scatter`) — `r^2*dphi/dt`
   constant at `b` within 0.1% (absolute tolerance scaled to
   `Max[|b|,1]`, so `b=0`'s identically-zero angular momentum is
   handled without dividing by zero).
3. **Energy conservation** (`scatter`) — `(1/2)(rDot^2+(r*phiDot)^2)+1/r`
   constant at `0.5` within 0.1%.
4. **Cross-section check** (`distribution`) — observed backscatter
   fraction (`theta>90 deg`) within a `>=3-sigma` statistical band of
   the analytic `1/b_max^2` prediction (see design decision 6).

## Common pitfalls

1. **`b=0` (backscatter preset) is purely radial motion** —
   `phi'[t] = b/r[t]^2` is identically zero, so `phi(t) = Pi` for the
   whole trajectory. The particle does not "turn around in angle"; it
   reverses radial direction while the position angle stays fixed.
   The 180 deg scattering angle is the angle between the *initial and
   final velocity vectors* (which do reverse), not a swept position
   angle — see `ScatterModel`'s `thetaMeasuredDeg` computation.
2. **`r_initial` may get silently raised** — see design decision 4.
   `--config-dump` still reports the literal configured value (the
   resolution happens in `ScatterModel`, after `LoadConfig` exits).
3. **`discovery` mode's `n=100` is fixed, not `n_particles`** — this
   mode recreates one specific historical comparison, not a tunable
   beam size; `--simulation.scattering.n_particles` has no effect on
   it (only `distribution` mode reads that key).
4. **Load order in `main.wl` matters**: `sonify.wl` defines
   `ScatteringAccentBurst`/`BuildIntroBuffer`, used by nothing in
   `animate.wl`, so load order between those two is not load-bearing
   here (unlike `magnetic/`'s `SafeRescale` dependency) — but
   `model.wl` must still load before both.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSection`, `STEMSay`, `STEMPrintN`,
  `STEMDescribeWAV`, `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`,
  `STEMPlayCmd`, `NormalizeBuffer`, `ExportAudioBuffer`, `ExportGIF`,
  `ExportCSV`, `EnsureDir`, `StemSynthNote`, `SpatialLayer`,
  `MotionLayer`, `EventLayer`, `MixLayers`. Deliberately **not**
  used: the `SonifyTrajectory` wrapper itself (see design decisions 1
  and 2).
- **Mathematica/WL**: `NDSolve`, `WhenEvent`, `ArcCot`, `VectorAngle`,
  `Graphics`, `GraphicsRow`, `Histogram`, `Blend`, `Export`,
  `SpeechSynthesize`, `AudioQ`, `AudioData`, `AudioSampleRate`,
  `RunProcess` (platform TTS fallback), `Import` (reading
  TTS-generated WAV files).

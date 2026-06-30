# lagrange — AGENTS.md

## What this app does

Simulates test-particle motion in the **circular restricted three-body problem (CR3BP)** in the co-rotating reference frame. The two massive primaries (e.g., Sun and Jupiter) orbit their common barycentre; the app places a massless test particle near one of the five Lagrange points and integrates its equations of motion.

**Three modes:**
- `l4` — stable tadpole or horseshoe libration near the L4 triangular point
- `l5` — same at the L5 triangular point (mirror of L4 by y-symmetry)
- `l1` — unstable saddle-point dynamics at L1 (escape on the unstable manifold)

**Three presets:** `sun_jupiter` (μ = 0.000954, default), `earth_moon` (μ = 0.01215), `sun_earth` (μ = 3.003×10⁻⁶).

**Outputs per run:** WAV audio, PNG trajectory, GIF animation, CSV time-series.

---

## Physics

### Units

| Quantity | Unit |
|---|---|
| Mass | m₁ + m₂ = 1 |
| Length | primary separation = 1 |
| Time | 1/(angular velocity ω₀) so one orbit = 2π |

The mass parameter **μ = m₂/(m₁+m₂)** is the fraction carried by the smaller primary. The two primaries are fixed at (−μ, 0) and (1−μ, 0) in the co-rotating frame.

### Equations of motion

```
x'' = 2y' + x − (1−μ)(x+μ)/r₁³ − μ(x−1+μ)/r₂³
y'' = −2x' + y − (1−μ)y/r₁³ − μy/r₂³
```

Terms from left to right: Coriolis, centrifugal (effective potential), primary gravity, secondary gravity.

### Jacobi constant (conserved)

```
C = x² + y² + 2(1−μ)/r₁ + 2μ/r₂ − (ẋ² + ẏ²)
```

This is the only integral of motion in the CR3BP. It is monitored as a sanity check: relative drift < 0.5% is required.

### Lagrange point locations

- **L1, L2, L3**: collinear points on the x-axis found via `FindRoot` applied to the derivative of the effective potential.
- **L4, L5**: triangular points at (1/2−μ, ±√3/2), forming equilateral triangles with both primaries (r₁ = r₂ = 1 exactly).

### Stability

- **L4 and L5** are stable for μ < μ_crit ≈ 0.0385 (Routh criterion). Jupiter (μ = 0.000954) and Earth-Moon (μ = 0.01215) are both stable. Jupiter's Trojans (Hildas, Greeks) are real examples.
- **L1, L2, L3** are saddle points — unstable along one direction. A small perturbation drives exponential growth along the unstable manifold.

---

## Code structure

```
lagrange/
  main.wl              — thin orchestrator; sets $mu, calls model/sonify/animate/output
  experiments.wl       — 8 curated preset runs
  src/
    model.wl           — EOM helpers, FindLagrangePoints, GeometryCheck,
                         LibrationModel, EscapeModel
    sonify.wl          — SonifyLibration, SonifyEscape
    animate.wl         — MakeLagrangeFrame, AnimateLibration, AnimateEscape
    output.wl          — ExportLibrationTrajectory, ExportEscapeTrajectory
  tests/
    test_model.wl      — unit tests (EOM helpers, L-point positions, model shapes)
  output/              — WAV, PNG, GIF, CSV (git-ignored)
```

### Global: `$mu`

All EOM functions (`$r1`, `$r2`, `$fx`, `$fy`, `$jacobiC`, `$omegaX`) are defined in `src/model.wl` as delayed rules that read `$mu` at call time. `main.wl` sets `$mu` from config **before** calling any model function. Tests must also set `$mu` before calling these functions.

---

## Data flow

```
main.wl
  sets $mu, $pert, $durP from config/CLI
  ↓
  FindLagrangePoints[]  →  $lpts Association {L1..L5 -> {x,y}}
  GeometryCheck[$lpts]  →  $c2Pass (bool)
  ↓
  [l4/l5 mode]  LibrationModel[mode, $lpts, $c2Pass, cfg]
  [l1 mode]     EscapeModel[$lpts, $c2Pass, cfg]
  ↓  model Association
  ├─ ExportLibrationTrajectory / ExportEscapeTrajectory  →  CSV
  ├─ AnimateLibration / AnimateEscape                    →  PNG + GIF
  └─ SonifyLibration / SonifyEscape                      →  WAV
```

---

## Model Association shape

### LibrationModel returns:

| Key | Type | Description |
|---|---|---|
| `xFn`, `yFn` | InterpolatingFunction | NDSolve solution objects |
| `tSamp` | List[Real] | 600 uniformly spaced time samples over [0, tEnd] |
| `xV`, `yV` | List[Real] | x(t), y(t) sampled at tSamp |
| `vxV`, `vyV` | List[Real] | ẋ(t), ẏ(t) |
| `r1V`, `r2V` | List[Real] | Distance to each primary |
| `omV` | List[Real] | Angular velocity around barycentre |
| `invDV` | List[Real] | 1/min(r1,r2)+0.01 — proximity to closer primary |
| `dLP` | List[Real] | Distance to the L4 or L5 Lagrange point |
| `nPts` | Integer | 600 |
| `tEnd` | Real | durP × 2π |
| `lPos` | {x,y} | Lagrange point coordinates |
| `lLabel` | String | "L4" or "L5" |
| `maxDist` | Real | max(dLP) — largest excursion from L-point |
| `maxOriginDist` | Real | max(√(x²+y²)) — furthest from barycentre |
| `jacRel` | Real | Relative Jacobi drift |
| `c1Pass`..`c4Pass` | Bool | Four sanity check results |

### EscapeModel returns:

Same kinematic fields but with `dL1` (distance to L1) and `L1x` (L1 x-coordinate) instead of `dLP`/`lPos`/`lLabel`. Also adds `tActual` (actual integration end time), `tEndL1` (limit), `distGrowth` (dL1[-1]/dL1[0]), and `tExit`.

---

## Sonification design

### l4 / l5 (SonifyLibration)

| Audio parameter | Mapped from |
|---|---|
| Pitch | Angular velocity around barycentre (omV) — oscillates quasi-periodically |
| Pan | x-coordinate in co-rotating frame — left/right asymmetry of the orbit |
| Volume | Inverse of closest-primary distance (invDV) — louder near primaries |
| Duration | max(15 s, 0.5 × tEnd) |
| Pitch range | 110–880 Hz (A2–A5, one octave either side of A3) |

The quasi-periodic pitch modulation mirrors the libration frequency, which is much slower than the orbital period.

### l1 (SonifyEscape)

Same mapping but wider pitch range (55–1760 Hz) to make the escape trajectory's diverging dynamics audible over a larger register. The Coriolis deflections near escape create rapid pitch sweeps.

---

## Sanity checks

Four checks run for every mode; failure prints `[FAIL]` and the final summary still completes so output files are still useful for diagnosis.

| # | Description | Threshold |
|---|---|---|
| 1 | Jacobi constant drift (relative) | < 0.5% |
| 2 | L4/L5 equilateral geometry (computed once at startup) | r₁=r₂=1 to 10⁻⁵ |
| 3 | Libration: max distance from L-point < 1.5 units; Escape: distance grew > 3× | As stated |
| 4 | Libration: all points within 2.5 units of barycentre; Escape: integration stopped early | As stated |

Check 4 for the l1 escape mode prints `[WARN]` (not `[FAIL]`) because a very large perturbation might cause immediate escape in a single step with no early-stop event.

---

## CLI reference

```
wolframscript -file main.wl -- [options]

--simulation.mode=<l4|l5|l1>               (default: l4)
--simulation.lagrange.preset=<name>         sun_jupiter | earth_moon | sun_earth
--simulation.lagrange.mass_ratio=<float>    mu directly (overridden by preset)
--simulation.lagrange.perturbation=<float>  initial displacement (default: 0.02)
--simulation.lagrange.duration_periods=<n>  orbital periods for l4/l5 (default: 6)
--config-dump                               print merged config and exit
```

---

## Running tests

```bash
wolframscript -file lagrange/tests/test_model.wl
```

Expected output: `Passed: 34  Failed: 0` (exits 0).

---

## Output files

| File | Description |
|---|---|
| `output/l4_trajectory.csv` | 600 rows × 9 columns: t, x, y, vx, vy, omega, r1, r2, dist_L4 |
| `output/l4.png` | Static trajectory plot, black background |
| `output/l4.gif` | 32-frame animated traversal at 10 fps |
| `output/l4_audio.wav` | Stereo WAV, 44.1 kHz |
| `output/l5_*` | Same structure for L5 mode |
| `output/l1_*` | L1 escape: 500 rows, dL1 instead of dLP |

---

## Common pitfalls

- **`$mu` must be set before `Get[src/model.wl]` is called**: The EOM functions use `$mu` via delayed evaluation. If `$mu` is undefined the functions will return symbolic expressions and NDSolve will fail. In tests, set `$mu` immediately after loading `stem-core`.
- **Large perturbation → check 3 fails**: The libration region shrinks as μ increases. With `earth_moon` preset and `perturbation=0.15`, the particle may escape L4. This is physically correct, not a bug.
- **L1 integration may not stop early for very small perturbation**: With `perturbation=0.001`, the unstable manifold growth is slow; the WhenEvent threshold (dist > 0.4) may not be reached in 3 orbital periods. Check 4 prints `[WARN]` in that case.
- **GIF frame count**: Always 32 frames, regardless of duration. For very long runs (`duration_periods=12`), each frame covers ~2.4% of the trajectory.

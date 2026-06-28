# AGENTS.md — Guidance for Claude Code

## Project overview

General relativity simulation in Wolfram Language. Two modes:

- **chirp** — gravitational wave strain from a binary inspiral (post-Newtonian
  approximation). Exports chirp.gif, chirp.png, chirp_timeseries.csv, and four
  WAV files. The strain h(t) IS the audio — no indirect sonification mapping.
- **geodesic** — Schwarzschild test-particle and photon trajectories solved
  numerically by NDSolve. Three orbit types: bound (elliptical; GR periapsis
  precession), plunging (falls past horizon), photon (gravitational lensing).
  Exports geodesic.gif, geodesic.png, geodesic_trajectory.csv, geodesic.wav.

**Units discipline:**
- `chirp` mode: SI throughout (G, c, M☉ defined numerically). Never use
  natural units here — the amplitude formula requires metric distance in metres.
- `geodesic` mode: dimensionless units (G = c = M = 1) for the integration.
  All r in units of M; convert to r_s = 2M for display. Physical quantities
  (Schwarzschild radius in km) computed from SI constants at the end.

## Project structure

- `main.wl`          — Mode dispatch (`Which[mode === "chirp", ..., mode === "geodesic", ...]`);
                       preset resolution (chirp only); 4-step pipeline per mode
- `config.json`      — All defaults: `simulation.{chirp, geodesic}`,
                       `animation`, `sonification.{chirp, geodesic}`
- `src/model.wl`     — `ChirpModel[cfg]`, `GeodesicModel[cfg]`
- `src/animate.wl`   — `AnimateRelativity[model, cfg, outDir]`
                       → dispatches to `AnimateGeodesic` when mode = "geodesic"
- `src/sonify.wl`    — `SonifyRelativity[model, cfg, outDir]`
                       → dispatches to `SonifyGeodesic` when mode = "geodesic"
- `output/`          — All output files (not committed)

## How to run

```bash
# Chirp (default)
wolframscript -file main.wl
wolframscript -file main.wl -- --simulation.mode chirp
wolframscript -file main.wl -- --simulation.chirp.preset gw170817
wolframscript -file main.wl -- --simulation.chirp.mass1_solar 50
wolframscript -file main.wl -- --sonification.chirp.time_stretch 8

# Geodesic
wolframscript -file main.wl -- --simulation.mode geodesic
wolframscript -file main.wl -- --simulation.mode geodesic --simulation.geodesic.orbit_type plunging
wolframscript -file main.wl -- --simulation.mode geodesic --simulation.geodesic.orbit_type photon
wolframscript -file main.wl -- --simulation.geodesic.bound.angular_momentum_factor 0.70
wolframscript -file main.wl -- --simulation.geodesic.photon.impact_parameter_factor 1.05

# Both
wolframscript -file main.wl -- --config-dump
afplay output/chirp.wav
afplay output/geodesic.wav
```

CLI override format: `--key=value` or space-separated `--key value` (both
work — main.wl pre-processes args before passing to `LoadConfig`).

## Data flow

### Chirp
```
config → ChirpModel
           ↓
         model {time[], strain[], frequency[], amplitude[],
                merger_index, chirp_mass_solar, coalescence_time,
                peak_frequency, sample_rate, mode="chirp"}
           ↙              ↓              ↘
  AnimateRelativity     CSV           SonifyRelativity
  (chirp.gif,        (10th rows)     → ChirpToAudio × 4
   chirp.png)                          (chirp.wav + 3 presets)
```

### Geodesic
```
config → GeodesicModel (NDSolve)
           ↓
         model {tau[], r[], phi[], x[], y[], redshift[],
                dphi_dtau[], omega_mean, merger_index,
                r_min, r_max, r_start, L_tilde, E,
                orbit_type, mass_solar, r_s_km,
                tau_max, n_revolutions, mode="geodesic"}
           ↙              ↓              ↘
  AnimateGeodesic       CSV           SonifyGeodesic
  (geodesic.gif,    (5000 rows)       (geodesic.wav)
   geodesic.png)
```

## Model Association shape — ChirpModel

| Key | Type | Description |
|-----|------|-------------|
| `"time"` | vector | Full time array (inspiral + ringdown), seconds |
| `"strain"` | vector | h(t) — raw gravitational wave strain (~10⁻²¹) |
| `"frequency"` | vector | f(t) — instantaneous GW frequency, Hz |
| `"amplitude"` | vector | A(t) — strain amplitude envelope |
| `"merger_index"` | Integer | Index of first ringdown sample |
| `"chirp_mass_solar"` | Real | Chirp mass ℳ in solar masses |
| `"coalescence_time"` | Real | t_c in seconds |
| `"peak_frequency"` | Real | Maximum frequency reached before clipping |
| `"sample_rate"` | Integer | Model sample rate (4096 Hz by default) |
| `"mode"` | String | `"chirp"` |

## Model Association shape — GeodesicModel

All spatial coordinates in units of M (dimensionless). Convert to r_s by
dividing by 2.

| Key | Type | Description |
|-----|------|-------------|
| `"tau"` | vector | Proper-time (or affine parameter) array, units of M |
| `"r"` | vector | Radial coordinate r/M |
| `"phi"` | vector | Azimuthal angle, radians |
| `"x"`, `"y"` | vectors | Cartesian equivalents: r·cos φ, r·sin φ (units of M) |
| `"redshift"` | vector | √(1 − 2/r̃) — gravitational redshift factor |
| `"dphi_dtau"` | vector | \|dφ/dτ\| — angular velocity, rad/M |
| `"omega_mean"` | Real | Mean angular velocity (used to normalise audio pitch) |
| `"merger_index"` | Integer | First index with r ≤ 2, or Length[r] if no crossing |
| `"r_min"`, `"r_max"` | Real | Trajectory extrema, units of M |
| `"r_start"` | Real | Initial r̃ = r_start_rs × 2 |
| `"L_tilde"` | Real | Dimensionless angular momentum L/M (or impact parameter b) |
| `"E"` | Real | Dimensionless energy (1 for photon) |
| `"orbit_type"` | String | `"bound"` \| `"plunging"` \| `"photon"` |
| `"mass_solar"` | Real | Black hole mass in solar masses |
| `"r_s_km"` | Real | Schwarzschild radius in km |
| `"tau_max"` | Real | Actual integration end, units of M |
| `"n_revolutions"` | Real | Total φ / 2π |
| `"mode"` | String | `"geodesic"` |

## Physics notes — chirp mode

### Post-Newtonian frequency evolution

    f(t) = (1/π) · (5/256)^(3/8) · ℳ_sec^(−5/8) · (t_c − t)^(−3/8)

    ℳ_sec = G · ℳ · M☉ / c³,  ℳ = μ^(3/5) · M^(2/5),  μ = m₁m₂/(m₁+m₂)

    t_c = (5/256) · ℳ_sec^(−5/3) · (π f_min)^(−8/3)

### Strain amplitude

    A(t) = (4/D) · (ℳ_sec · c) · (π · ℳ_sec · f(t))^(2/3)

### Ringdown (Echeverria 1989, a = 0)

    f_qnm = c³ / (2π G M_final) · (1 − 0.63),  M_final = 0.95 M
    τ_rd  = 10 G M_final / c³

### Physical correctness checks (abort on FAIL)

1. f(0) ≈ f_min within 25%
2. f(t) monotonically non-decreasing to clipping point
3. A(t) monotonically non-decreasing to clipping point
4. Mean(h) ≈ 0 (no DC drift)

## Physics notes — geodesic mode

### Schwarzschild geodesic equations (M = 1, dimensionless)

Massive particle (proper time τ):

    r''(τ) = −1/r² + L̃²/r³ − 3L̃²/r⁴
    φ'(τ)  = L̃/r²

Massless photon (affine parameter λ, E = 1, b = L):

    r''(λ) = b²/r³ − 3b²/r⁴
    φ'(λ)  = b/r²

### Orbit types and initial conditions

**bound** — start at apoapsis r̃₀ = r_start_rs × 2 with dr/dτ = 0.
Angular momentum: L̃ = f · √(r̃₀²/(r̃₀ − 3)), where f = angular_momentum_factor.
Energy: E = √((1 − 2/r̃₀)(1 + L̃²/r̃₀²)).
Orbit is bound iff L̃² > 12 (ISCO threshold). Default f = 0.85 satisfies this
for r_start_rs = 10 (L̃² ≈ 17).

**plunging** — same equations. Default f = 0.30 gives L̃² ≈ 2.1 < 12 → no
potential barrier → particle falls through the horizon. Integration stops at
r < 2.01 via WhenEvent.

**photon** — start at r̃₀ with dr/dλ = −√(1 − (1 − 2/r̃₀)b²/r̃₀²).
Critical impact parameter: b_crit = 3√3 ≈ 5.196 M (photon sphere at r = 3M).
b > b_crit → deflected (escapes); b < b_crit → captured.

### Key radii (in units of M; divide by 2 for r_s)

| Radius | r/M | r/r_s | Significance |
|--------|-----|-------|--------------|
| Event horizon | 2 | 1 | Schwarzschild radius |
| Photon sphere | 3 | 1.5 | Unstable circular photon orbit |
| ISCO | 6 | 3 | Innermost stable circular orbit (massive particles) |

### Sonification mapping

| Orbit type | Pitch | Amplitude |
|------------|-------|-----------|
| bound | ∝ dφ/dτ (orbital angular velocity) | redshift factor √(1−2/r̃) |
| plunging | ∝ 1/√(1−2/r̃) (gravitational blueshift) | redshift factor (fades at horizon) |
| photon | ∝ 1/√(1−2/r̃) | redshift factor |

Mean pitch normalised to `pitch_base_hz` (default 220 Hz, A3) via `omega_mean`.

## Chirp preset system

Defined in `config.json` under `simulation.chirp.presets`. Activated via
`--simulation.chirp.preset <name>`. `main.wl` merges the preset masses and
distance into `cfg` before calling `ChirpModel`.

## Animation reference circles (geodesic mode)

All coordinates plotted in r_s units (r_s = 2M). Reference circles:

- **Black filled disk** — event horizon at r = 1 r_s
- **Dashed orange circle** — photon sphere at r = 1.5 r_s
- **Dashed grey circle** — ISCO at r = 3 r_s (massive-particle modes only)

## Common pitfalls

- **Underscores in Module variable names.** `Module[{M_m, rS_m, ...}]` fails:
  WL parses `M_m` as `Pattern[M, Blank[m]]`, not a symbol. Use camelCase or
  no underscores: `Mm`, `rSm`. This was found during geodesic implementation.

- **`\[Subscript]` in strings.** `"r\[Subscript]s"` is not a valid Wolfram
  named character — it raises `Syntax::sntufn`. Use plain text `"r_s"` in
  frame labels instead.

- **Optional argument syntax with `?test`.** `f[x_?NumericQ : 0.0]` is
  misparsed in some WL versions. Define two DownValues instead.

- **JSON integers vs. Wolfram reals.** `GetCfg` may return `4096` as Integer.
  Always `Round @ GetCfg[...]` on sample rates before passing to audio exports.

- **`FirstPosition` returns a list.** `FirstPosition[list, pat]` = `{k}`.
  Extract the index with `pos[[1]]`, not `First[First[pos]]`.

- **`Min[Differences[arr]]` beats `And @@ Thread[...]` for large arrays.**
  For GW170817 with 769k samples, `Thread` floods output. Use `Min[Differences[arr[[;;k]]]] >= -eps`.

- **`SonifyTrajectory` is NOT used in chirp mode.** Do not apply the
  three-layer spatial/motion/event pipeline to gravitational wave data.

- **NDSolve for geodesic: use `Quiet @`** to suppress harmless step-size
  messages. The integration stops early via WhenEvent (plunging/photon), so
  always read the actual domain back with `rFunc["Domain"][[1,2]]` rather
  than assuming it reached `tau_max_m`.

## Output files

### Chirp mode

| File | Description |
|------|-------------|
| `chirp.gif` | 60-frame animation, waveform revealed + frequency dot |
| `chirp.png` | Static two-panel: full strain waveform + frequency sweep |
| `chirp.wav` | Main audio: time-stretched + normalised h(t) |
| `chirp_timeseries.csv` | Every 10th sample: time_s, strain_h, frequency_hz, amplitude |
| `gw150914.wav` | GW150914 preset |
| `gw170817.wav` | GW170817 preset, last 10 s of inspiral |
| `stellar.wav` | 10+8 M☉ preset |

### Geodesic mode

| File | Description |
|------|-------------|
| `geodesic.gif` | 60-frame animation: particle/photon moving along orbit |
| `geodesic.png` | Static full-trajectory polar plot |
| `geodesic.wav` | Sonified orbit (pitch = orbital ω or blueshift, amplitude = redshift) |
| `geodesic_trajectory.csv` | Subsampled: tau_M, r_rs, phi_rad, x_rs, y_rs |

## Dependencies

- Mathematica or Wolfram Engine (any recent version)
- `stem-core` (sibling `../stem-core`) — `ExportAudioBuffer`, `NormalizeBuffer`,
  `ExportGIF`, `ExportCSV`, `EnsureDir`, `STEMHeading`, `STEMSection`,
  `STEMPrintN`, `STEMDescribeCSV`, `STEMDescribeWAV`, `STEMDescribeGIF`,
  `STEMSay`, `FmtN`, `GetCfg`, `DeepMerge`, `LoadConfig`
- No external paclets required

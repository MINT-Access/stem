# STEM Apps — Quick Reference

All sixteen apps share the same invocation pattern and config system. This
document covers CLI options, modes, config keys, and output files for each.

---

## Quick comparison

| App | Domain | Modes | Output dir | Has live data? |
|-----|--------|-------|-----------|---------------|
| `pendulum` | Physics ODE | `simple`, `double` | `output/` | No |
| `lorenz` | Strange attractor | `lorenz`, `rossler` | `output/` | No |
| `dynamical` | Logistic map / route to chaos | `sweep`, `iterate` | `output/` | No |
| `asteroids` | NASA NeoWs API | — | `output/` | Yes |
| `cellular` | Cellular automata | `life`, `rule110` | `output/` | No |
| `signal` | Fourier analysis | `chord`, `sweep`, `am` | `output/` | No |
| `quantum` | Quantum mechanics | `qho`, `box` | `output/` | No |
| `primes` | Prime number patterns | `ulam`, `gaps` | `output/` | No |
| `relativity` | General relativity | `chirp`, `geodesic` | `output/` | No |
| `images` | 2D image sonification | `brightness`, `scan_horizontal`, `colour`, `hsb` | `output/` | No |
| `cosmology` | CMB power spectrum | `spectrum`, `sky` | `output/` | Optional (Planck) |
| `waves` | 2D wave propagation | `ripple`, `interference` | `output/` | No |
| `lagrange` | CR3BP Lagrange points | `l4`, `l5`, `l1` | `output/` | No |
| `thermo` | Classical statistical mechanics | `distribution`, `ensemble`, `cooling`, `equipartition` | `output/` | No |
| `montecarlo` | 2D Ising model (Metropolis MCMC) | `sweep`, `critical`, `quench` | `output/` | No |
| `magnetic` | Charged particle motion (Lorentz force) | `cyclotron`, `drift`, `mirror`, `multi` | `output/` | No |

---

## Config system

Every app uses a four-layer config:

```
$HardcodedDefaults → config/config.json → <app>/config.json → CLI --key=value
```

Keys use dot notation for nesting. CLI overrides accept both
`--key.subkey=value` and `--key.subkey value` (space form) — all 16 apps
support both conventions.
Dump the active config without running the simulation:

```sh
wolframscript -file <app>/main.wl -- --config-dump | python3 -m json.tool
```

---

## pendulum

Solves the nonlinear pendulum ODE with `NDSolve`. Simple mode produces one
WAV + GIF; double mode produces a binaural WAV + GIF with chaotic trajectories.

**Run:**
```sh
wolframscript -file pendulum/main.wl
wolframscript -file pendulum/main.wl -- --simulation.mode=simple
wolframscript -file pendulum/main.wl -- --simulation.duration=30
```

**Key config keys (`pendulum/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"double"` | `"simple"` or `"double"` |
| `simulation.duration` | `20.0` | Simulation time in seconds |
| `simulation.timestep` | `0.01` | ODE integration step size |
| `simulation.simple.angle_deg` | `45.0` | Initial angle for simple pendulum |
| `simulation.simple.damping` | `0.0` | Damping coefficient |
| `simulation.double.angle1_deg` | `120.0` | Initial angle, rod 1 |
| `simulation.double.angle2_deg` | `170.0` | Initial angle, rod 2 |
| `sonification.pitch.min_hz` | `220` | Lowest note frequency |
| `sonification.pitch.max_hz` | `660` | Highest note frequency |

**Output files:**

| File | Description |
|------|-------------|
| `output/simple_audio.wav` | Simple mode sonification |
| `output/simple_animation.gif` | Simple pendulum animation |
| `output/simple_results.csv` | Angle and velocity time series |
| `output/double_audio.wav` | Double mode sonification |
| `output/double_animation.gif` | Double pendulum animation |
| `output/double_results.csv` | Angles and velocities, both rods |

---

## lorenz

Simulates strange attractors. Notes are triggered at local extrema of x(t);
spatial position sets the stereo pan. The GIF grows the trajectory frame by
frame.

**Run:**
```sh
wolframscript -file lorenz/main.wl
wolframscript -file lorenz/main.wl -- --simulation.mode=rossler
wolframscript -file lorenz/main.wl -- --simulation.lorenz.rho=35
```

**Key config keys (`lorenz/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"lorenz"` | `"lorenz"` or `"rossler"` |
| `simulation.duration` | `40.0` | Integration time |
| `simulation.timestep` | `0.005` | ODE step size |
| `simulation.lorenz.sigma` | `10.0` | Lorenz σ parameter |
| `simulation.lorenz.rho` | `28.0` | Lorenz ρ parameter |
| `simulation.lorenz.beta` | `2.6667` | Lorenz β parameter |
| `simulation.rossler.a` | `0.2` | Rössler a parameter |
| `simulation.rossler.b` | `0.2` | Rössler b parameter |
| `simulation.rossler.c` | `5.7` | Rössler c parameter |
| `sonification.pitch.min_hz` | `80` | Lowest note frequency |
| `sonification.pitch.max_hz` | `1200` | Highest note frequency |

**Output files:**

| File | Description |
|------|-------------|
| `output/lorenz_audio.wav` | Sonification of x(t) extrema events |
| `output/lorenz_animation.gif` | Growing trajectory animation |
| `output/lorenz_trajectory.csv` | x, y, z time series |

---

## dynamical

Sonifies the logistic map (x_{n+1} = r·x_n·(1-x_n)) and its period-doubling
route to chaos. `sweep` mode traverses r from `r_start` to `r_end`, sonifying
the long-term attractor recorded at each step. `iterate` mode fixes r (or a
named preset) and sonifies the map's actual time evolution over
`n_iterations` steps, transient included. Discrete per-point note synthesis
(not the continuous `SonifyTrajectory` pipeline used by `lorenz`/`pendulum`)
makes period-doubling audible as a directly countable rhythm — period-4
genuinely sounds like a four-note cycle.

**Run:**
```sh
wolframscript -file dynamical/main.wl                                       # sweep mode, r 2.5→4.0
wolframscript -file dynamical/main.wl -- --simulation.mode=iterate          # iterate at r=3.8
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=fixed_point
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=period2
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=period4
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=period3_window
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=chaos
wolframscript -file dynamical/main.wl -- --simulation.dynamical.r=3.83
wolframscript -file dynamical/main.wl -- --simulation.dynamical.r_steps=1000
```

Named presets (`iterate` mode): `fixed_point` (r=2.8), `period2` (r=3.2),
`period4` (r=3.5), `period3_window` (r=3.830), `chaos` (r=4.0). The
`period3_window` preset uses r=3.830 rather than the textbook-cited 3.8284 —
that value is the window's exact tangent-bifurcation opening edge, where
convergence to the 3-cycle is pathologically slow; 3.830 converges cleanly
within the default `n_iterations`.

**Key config keys (`dynamical/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"sweep"` | `"sweep"` or `"iterate"` |
| `simulation.dynamical.r_start` | `2.5` | Sweep start r (sweep mode) |
| `simulation.dynamical.r_end` | `4.0` | Sweep end r (sweep mode) |
| `simulation.dynamical.r_steps` | `500` | Number of r values sampled (sweep mode) |
| `simulation.dynamical.r` | `3.8` | Fixed r value (iterate mode, used when `preset` is empty) |
| `simulation.dynamical.preset` | `""` | Named preset (iterate mode) — see above |
| `simulation.dynamical.n_transient` | `200` | Transient iterations discarded before recording the attractor (sweep mode) |
| `simulation.dynamical.n_attractor` | `100` | Attractor iterations recorded per r-step (sweep mode) |
| `simulation.dynamical.n_iterations` | `300` | Total iterations (iterate mode) |
| `simulation.dynamical.note_duration` | `0.08` | Seconds per note, both modes |
| `simulation.dynamical.x0` | `0.5` | Initial population fraction |

**Output files:**

| File | Description |
|------|-------------|
| `output/sweep_audio.wav` | Spoken intro + sweep sonification (stereo) |
| `output/sweep.gif` | Progressive bifurcation diagram animation with r cursor |
| `output/sweep_data.csv` | r, iteration_index, x_n, pitch_hz, pan, volume, event_label |
| `output/iterate_audio.wav` | Spoken intro + iteration sonification (stereo) |
| `output/iterate.gif` | x_n vs. n time-series animation |
| `output/iterate_data.csv` | n, x_n, pitch_hz, pan, volume |

**Notes:**
- Sonification mapping: pitch = x_n on a 3-octave minor pentatonic scale
  (root C3); pan = x_n rescaled to [-1,1]; volume = |x_n − x_{n-1}| — the
  chaotic region's larger jumps sound louder and more active than the
  steady periodic region.
- Sweep mode marks three named events with accent tones, announced in the
  console and via speech as the sweep reaches them: the first
  period-doubling bifurcation (660 Hz, r≈3.0, located numerically), the
  onset of chaos (440 Hz, r≈3.57), and the period-3 window (528 Hz, r≈3.83).
- Four correctness checks run on every invocation, printed as
  `Checks: 1[PASS] 2[PASS] 3[PASS] 4[PASS]`: the Feigenbaum constant
  (bifurcation points located via `FindRoot` on the map's stability
  conditions, not hardcoded — ratio verified within 5% of δ≈4.669), the
  analytic fixed point x*=1−1/r at r=2.8, the period-2 sum formula
  (r+1)/r at r=3.2, and the Lyapunov exponent at r=4.0 (verified within
  5% of log 2 ≈ 0.693).
- Sweep mode audio duration scales as `r_steps × 8 × note_duration` — only
  8 of each r-step's recorded attractor points become audible notes (all
  are equally valid post-transient points; 8 is enough to make any
  periodicity up to period-8 clearly audible while keeping the default
  500-step sweep to ~5.3 minutes rather than the ~66 minutes a
  one-note-per-attractor-point mapping would produce).
- See [`dynamical/LISTENING_GUIDE.md`](../dynamical/LISTENING_GUIDE.md) for
  the recommended five-preset listening sequence.

---

## asteroids

Fetches live close-approach data from NASA's NeoWs API. Each asteroid becomes
one note. Date ranges longer than 7 days are split into multiple API calls
automatically.

**Run:**
```sh
wolframscript -file asteroids/main.wl                          # last 7 days
wolframscript -file asteroids/main.wl -- 2026-01-01 2026-12-31 # explicit range
wolframscript -file asteroids/main.wl -- 2026-01-01 2026-06-25 Phrygian
wolframscript -file asteroids/main.wl -- 2026-06-20 2026-06-26 --no-orbital-elements
```

Positional arguments: `[-- YYYY-MM-DD YYYY-MM-DD [Scale]]`

Valid scales: `MinorPentatonic` `MajorPentatonic` `Major` `Minor` `WholeTone` `Phrygian`

**Key config keys (`asteroids/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.days_ahead` | `7` | Days from today when no dates given |
| `simulation.max_objects` | `10` | Max asteroids to sonify |
| `simulation.use_orbital_elements` | `true` | Fetch Keplerian elements from JPL SBDB for real angles |
| `sonification.pitch.min_hz` | `150` | Miss-distance → pitch low bound |
| `sonification.pitch.max_hz` | `900` | Miss-distance → pitch high bound |

**Output files:**

Output filenames include the date range, e.g. `asteroids_2026-06-21_2026-06-27.wav`.

| File | Description |
|------|-------------|
| `output/asteroids_{start}_{end}.wav` | Sonification (one note per asteroid) |
| `output/asteroids_{start}_{end}.gif` | Top-down solar system animation with computed directions |
| `output/asteroids_{start}_{end}.csv` | 17 columns: distance, velocity, size, orbital elements, geocentric angle |

**API key:** The DEMO_KEY allows ~30 requests/hour. For unrestricted access
set `NASA_API_KEY` in your environment before running.

**Notes:**
- Asteroid directions are computed from Keplerian elements fetched from the JPL Small Body
  Database (SBDB) API — no key required. Each asteroid's heliocentric ecliptic position is
  solved at closest-approach date using Newton-Raphson Kepler equation solving, then
  converted to a geocentric angle. Pass `--no-orbital-elements` to skip this step and use
  seeded random angles instead (faster, offline-safe).
- The SBDB fetch rate-limits itself to 1 request per 0.5 s. A 7-day run (~40 asteroids)
  takes ~20 s for the orbital elements step.

---

## cellular

Two cellular automata. Both produce a population statistics CSV, an animated
GIF, and a sonification of population dynamics over time.

**Run:**
```sh
wolframscript -file cellular/main.wl                           # Game of Life, R-pentomino
wolframscript -file cellular/main.wl -- --simulation.mode=rule110
wolframscript -file cellular/main.wl -- --simulation.life.starting_pattern=gliderlgun
wolframscript -file cellular/main.wl -- --simulation.life.starting_pattern=random
wolframscript -file cellular/main.wl -- --simulation.life.generations=500
```

**Key config keys (`cellular/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"life"` | `"life"` or `"rule110"` |
| `simulation.life.rows` | `80` | Grid rows |
| `simulation.life.cols` | `80` | Grid columns |
| `simulation.life.generations` | `300` | Number of generations to run |
| `simulation.life.starting_pattern` | `"rpentomino"` | `"rpentomino"`, `"gliderlgun"`, or `"random"` |
| `simulation.life.wrap` | `true` | Toroidal (wrap-around) boundary |
| `simulation.rule110.width` | `120` | Row width for 1D automaton |
| `simulation.rule110.generations` | `200` | Number of generations |
| `simulation.rule110.initial` | `"single_cell"` | Initial condition |
| `sonification.pitch.min_hz` | `150` | Pitch at minimum population |
| `sonification.pitch.max_hz` | `900` | Pitch at maximum population |
| `sonification.events.extinction` | `true` | Low burst on >40% population drop |
| `sonification.events.explosion` | `true` | High burst on >40% population rise |
| `simulation.cellular.articulation_mode` | `"relative"` | `"relative"` or `"absolute"` — how population-change is measured to decide when to articulate a new note |
| `simulation.cellular.articulation_threshold` | `0.15` | Relative change (fraction) that triggers a new note, when `articulation_mode="relative"` |
| `simulation.cellular.articulation_threshold_abs` | `5` | Absolute population change that triggers a new note, when `articulation_mode="absolute"` |
| `simulation.cellular.base_note_duration` | `0.06` | Seconds per note during a held (unarticulated) run; overridable per mode, e.g. `simulation.cellular.rule110.base_note_duration` (default `0.10`) |

**Output files:**

| File | Description |
|------|-------------|
| `output/life_rpentomino_audio.wav` | Game of Life sonification |
| `output/life_rpentomino_animation.gif` | Game of Life animation |
| `output/life_rpentomino_stats.csv` | Population per generation |
| `output/life_rpentomino_data.csv` | Per-generation articulation record: generation, population, articulated, run_length |
| `output/rule110_audio.wav` | Rule 110 sonification |
| `output/rule110_animation.gif` | Rule 110 animated space-time diagram |
| `output/rule110_animation_spacetime.png` | Rule 110 static space-time image |
| `output/rule110_stats.csv` | Row density per generation |
| `output/rule110_data.csv` | Per-generation articulation record: generation, population, articulated, run_length |

**Notes:**
- Run-length articulation (note-holding): a new note is only triggered when
  population changes by more than `articulation_threshold` (relative mode)
  or `articulation_threshold_abs` (absolute mode) since the last articulated
  note; otherwise the current pitch holds. Stable periods sound sustained;
  population changes are clearly marked. Applies to both Game of Life and
  Rule 110. EventLayer extinction/explosion accents are unaffected.

---

## signal

Demonstrates the discrete Fourier transform. The output WAV files **are** the
phenomenon — the user hears what filtering does directly.

**Run:**
```sh
wolframscript -file signal/main.wl                             # chord (C major)
wolframscript -file signal/main.wl -- --simulation.mode=sweep
wolframscript -file signal/main.wl -- --simulation.mode=am
wolframscript -file signal/main.wl -- --simulation.chord.noise_level=0.8
```

**Key config keys (`signal/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"chord"` | `"chord"`, `"sweep"`, or `"am"` |
| `simulation.chord.frequencies` | `[261.63, 329.63, 392.00]` | C major chord (Hz) |
| `simulation.chord.amplitudes` | `[1.0, 0.8, 0.6]` | Per-frequency amplitudes |
| `simulation.chord.duration` | `3.0` | Signal duration in seconds |
| `simulation.chord.noise_level` | `0.4` | Gaussian noise amplitude |
| `simulation.sweep.start_hz` | `100.0` | Chirp start frequency |
| `simulation.sweep.end_hz` | `2000.0` | Chirp end frequency |
| `simulation.sweep.duration` | `4.0` | Sweep duration in seconds |
| `simulation.sweep.noise_level` | `0.3` | Gaussian noise amplitude |
| `simulation.am.carrier_hz` | `440.0` | AM carrier frequency |
| `simulation.am.modulator_hz` | `4.0` | AM modulation frequency |
| `simulation.am.modulation_depth` | `0.8` | AM modulation depth (0–1) |
| `simulation.am.noise_level` | `0.35` | Gaussian noise amplitude |

**Output files (mode-prefixed, e.g. `chord_`):**

| File | Description |
|------|-------------|
| `output/{mode}_clean.wav` | Signal without noise |
| `output/{mode}_noisy.wav` | Signal after noise is added |
| `output/{mode}_recovered.wav` | Signal after Fourier filtering |
| `output/{mode}_narrative_full.wav` | Spoken narrative + all three stages |
| `output/{mode}_animation.gif` | Animated waveform/spectrum visualisation |
| `output/{mode}_waveform.png` | Waveform comparison (clean vs noisy vs recovered) |
| `output/{mode}_spectrum.png` | Frequency spectrum plot |
| `output/{mode}_recovery.png` | SNR improvement visualisation |
| `output/{mode}_spectrum.csv` | Frequency axis and power values |

The `{mode}_narrative_full.wav` file is the most accessible output — it chains
spoken introductions with audio playback of each stage so the demonstration
can be followed by listening alone.

---

## quantum

Simulates quantum mechanical wave-packet evolution in two exactly-solvable
systems using a truncated energy-eigenstate basis (ħ=m=1 throughout).

**Run:**
```sh
wolframscript -file quantum/main.wl
wolframscript -file quantum/main.wl -- --simulation.mode=qho
wolframscript -file quantum/main.wl -- --simulation.mode=box
wolframscript -file quantum/main.wl -- --simulation.qho.alpha=3.0
```

**Key config keys (`quantum/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"qho"` | `"qho"` or `"box"` |
| `simulation.qho.alpha` | `2.0` | Coherent state amplitude α |
| `simulation.qho.omega` | `1.0` | Oscillator frequency ω |
| `simulation.qho.n_modes` | `20` | Number of Hermite-Gauss basis functions |
| `simulation.qho.x_range` | `[-8.0, 8.0]` | Spatial grid extent |
| `simulation.qho.n_points` | `200` | Spatial grid points |
| `simulation.qho.duration` | `12.56637` | Simulation time (≈ 2π/ω, one period) |
| `simulation.qho.timestep` | `0.05` | Time step |
| `simulation.box.L` | `10.0` | Box length |
| `simulation.box.n_modes` | `10` | Number of energy eigenstates in basis |
| `simulation.box.n_points` | `200` | Spatial grid points |
| `simulation.box.duration` | `20.0` | Simulation time |
| `simulation.box.timestep` | `0.05` | Time step |
| `sonification.pitch.min_hz` | `110` | Pitch at minimum variance |
| `sonification.pitch.max_hz` | `880` | Pitch at maximum variance |

**Output files (mode-prefixed, e.g. `qho_`):**

| File | Description |
|------|-------------|
| `output/{mode}_density.gif` | Animated \|ψ(x,t)\|² (≤100 frames) |
| `output/{mode}_density.png` | 3×3 snapshot grid at equal time intervals |
| `output/{mode}_timeseries.csv` | Time series of ⟨x⟩, Var(x), and speed |
| `output/{mode}_audio.wav` | Sonification: pan=⟨x⟩, pitch=Var(x), vol=\|d⟨x⟩/dt\| |

**Physics notes:**
- QHO coherent state: ⟨E⟩ = ω(\|α\|² + ½). For α=2, ω=1: ⟨E⟩ = 4.5.
- Box superposition: ⟨E⟩ = (E₁ + E₂)/2, where Eₙ = n²π²/(2L²).
  For L=10: ⟨E⟩ ≈ 0.1234.
- Normalisation ∫\|ψ\|²dx is verified at every 10th timestep; a warning
  is printed if any sample deviates from 1 by more than 1%.

---

## primes

Visualises prime number structure in two modes. Both share the four-layer config
system and write all output to `output/`.

**Run:**
```sh
wolframscript -file primes/main.wl
wolframscript -file primes/main.wl -- --simulation.mode=gaps
wolframscript -file primes/main.wl -- --simulation.ulam.size=201
wolframscript -file primes/main.wl -- --simulation.gaps.count=10000
```

**Key config keys (`primes/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"ulam"` | `"ulam"` or `"gaps"` |
| `simulation.ulam.size` | `101` | Grid side length (odd; even values incremented by 1) |
| `simulation.ulam.color_primes` | `"white"` | Prime cell colour: `"white"` or `"black"` |
| `simulation.ulam.color_composite` | `"black"` | Composite cell colour |
| `simulation.gaps.count` | `5000` | Number of primes to analyse |
| `simulation.gaps.max_gap_display` | `72` | Y-axis cap for the gap chart |
| `sonification.pitch.min_hz` | `120` | Pitch for the smallest prime (p₁ = 2) |
| `sonification.pitch.max_hz` | `1000` | Pitch for the largest prime |
| `sonification.gaps.tempo_bpm` | `120` | Base tempo; controls normalised audio duration |
| `sonification.gaps.tone_duration_ms` | `80` | Duration of each prime's sine burst in ms |

**Output files — `ulam` mode:**

| File | Description |
|------|-------------|
| `output/ulam_spiral.png` | Full-resolution prime/composite grid |
| `output/ulam_spiral.gif` | Single-frame GIF (pipeline consistency) |
| `output/ulam_centre_zoom.png` | 31×31 centre crop with cell borders visible |
| `output/ulam_spiral.csv` | integer, row, col, is_prime for each prime in the grid |
| `output/ulam_audio.wav` | Row-scan sonification (pan=asymmetry, pitch=density) |

**Output files — `gaps` mode:**

| File | Description |
|------|-------------|
| `output/gaps_animation.gif` | Animated gap chart with progressive reveal (50 frames) |
| `output/gaps_stats.csv` | n, prime, next_prime, gap, cumulative_gap, is_twin_prime |
| `output/gaps_audio.wav` | Percussive sonification at base tempo (≈30 s at 120 bpm) |
| `output/gaps_slow.wav` | Same sonification at quarter tempo (≈120 s); gaps easier to count |

**Notes:**
- Ulam audio: rows scanned top-to-bottom; pan = right-minus-left prime density,
  pitch = row density, volume = |row-to-row density change|.
- Gaps audio: attack time for prime pₙ = (pₙ − p₁)/(p\_count − p₁) × baseDuration.
  All relative gap ratios are preserved exactly.
- baseDuration = 30 × 120 / tempo\_bpm seconds. At tempo=120: base ≈ 30 s, slow ≈ 120 s.
- For 5000 primes: mean gap ≈ 9.72, largest gap = 72, twin prime pairs = 680.

---

## relativity

Two modes of general relativity simulation. `chirp` models gravitational wave
emission from a binary inspiral (post-Newtonian approximation). `geodesic`
integrates test-particle and photon orbits in the Schwarzschild metric via
NDSolve.

**Run — chirp mode:**
```sh
wolframscript -file relativity/main.wl                                      # GW150914 (default)
wolframscript -file relativity/main.wl -- --simulation.mode chirp
wolframscript -file relativity/main.wl -- --simulation.chirp.preset gw170817
wolframscript -file relativity/main.wl -- --simulation.chirp.preset stellar
wolframscript -file relativity/main.wl -- --simulation.chirp.mass1_solar 50
wolframscript -file relativity/main.wl -- --simulation.chirp.mass2_solar 50
wolframscript -file relativity/main.wl -- --simulation.chirp.distance_mpc 200
wolframscript -file relativity/main.wl -- --sonification.chirp.time_stretch 8
```

**Run — geodesic mode:**
```sh
wolframscript -file relativity/main.wl -- --simulation.mode geodesic          # bound orbit (default)
wolframscript -file relativity/main.wl -- --simulation.mode geodesic --simulation.geodesic.orbit_type plunging
wolframscript -file relativity/main.wl -- --simulation.mode geodesic --simulation.geodesic.orbit_type photon
wolframscript -file relativity/main.wl -- --simulation.geodesic.mass_solar 30
wolframscript -file relativity/main.wl -- --simulation.geodesic.bound.r_start_rs 15
wolframscript -file relativity/main.wl -- --simulation.geodesic.bound.angular_momentum_factor 0.70
wolframscript -file relativity/main.wl -- --simulation.geodesic.photon.impact_parameter_factor 1.05
```

**Key config keys — chirp (`relativity/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"chirp"` | `"chirp"` or `"geodesic"` |
| `simulation.chirp.mass1_solar` | `36.0` | Primary mass (M☉) |
| `simulation.chirp.mass2_solar` | `29.0` | Secondary mass (M☉) |
| `simulation.chirp.distance_mpc` | `410.0` | Luminosity distance (Mpc) |
| `simulation.chirp.sample_rate` | `4096` | Model sample rate (Hz) |
| `simulation.chirp.frequency_min_hz` | `20.0` | Starting GW frequency |
| `simulation.chirp.frequency_max_hz` | `500.0` | Clip frequency (PN breaks down near merger) |
| `simulation.chirp.ringdown_duration` | `0.05` | Ringdown duration in seconds |
| `simulation.chirp.preset` | `""` | `"gw150914"`, `"gw170817"`, or `"stellar"` |
| `sonification.chirp.time_stretch` | `4.0` | Slow-down factor for audio |
| `sonification.chirp.frequency_shift` | `1.0` | Pitch shift multiplier |

**Key config keys — geodesic (`relativity/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.geodesic.mass_solar` | `10.0` | Black hole mass (M☉) |
| `simulation.geodesic.orbit_type` | `"bound"` | `"bound"`, `"plunging"`, or `"photon"` |
| `simulation.geodesic.tau_max_m` | `3000.0` | Max proper time / affine param (units of M) |
| `simulation.geodesic.n_steps` | `50000` | Sample points in output arrays |
| `simulation.geodesic.bound.r_start_rs` | `10.0` | Starting radius (Schwarzschild radii) |
| `simulation.geodesic.bound.angular_momentum_factor` | `0.85` | L / L_circ at r_start; < 1 makes orbit elliptical |
| `simulation.geodesic.plunging.r_start_rs` | `10.0` | Starting radius (Schwarzschild radii) |
| `simulation.geodesic.plunging.angular_momentum_factor` | `0.30` | Low L ensures L² < 12 (no potential barrier) |
| `simulation.geodesic.photon.r_start_rs` | `50.0` | Starting radius (Schwarzschild radii) |
| `simulation.geodesic.photon.impact_parameter_factor` | `1.5` | b / b_crit; > 1 deflects, < 1 captures |
| `sonification.geodesic.pitch_base_hz` | `220.0` | Mean pitch mapped to this frequency (Hz) |
| `sonification.geodesic.duration_s` | `10.0` | Audio output duration in seconds |

**Output files — chirp mode:**

| File | Description |
|------|-------------|
| `output/chirp.gif` | 60-frame animation revealing waveform + frequency dot |
| `output/chirp.png` | Static two-panel: full strain waveform + frequency sweep |
| `output/chirp.wav` | Main audio: h(t) time-stretched and normalised to 0.9 peak |
| `output/chirp_timeseries.csv` | Every 10th sample: time_s, strain_h, frequency_hz, amplitude |
| `output/gw150914.wav` | GW150914 preset (36+29 M☉, 410 Mpc) |
| `output/gw170817.wav` | GW170817 preset — last 10 s of neutron-star inspiral |
| `output/stellar.wav` | Stellar preset (10+8 M☉, 100 Mpc) |

**Output files — geodesic mode:**

| File | Description |
|------|-------------|
| `output/geodesic.gif` | 60-frame animation of particle/photon moving along orbit |
| `output/geodesic.png` | Static full-trajectory polar plot with reference circles |
| `output/geodesic.wav` | Sonified orbit (10 s); pitch = orbital ω or blueshift, amplitude = redshift |
| `output/geodesic_trajectory.csv` | Subsampled trajectory: tau_M, r_rs, phi_rad, x_rs, y_rs |

**Notes:**
- Chirp audio: the strain h(t) is literally the WAV data — no indirect
  sonification. Three preset WAVs are always produced alongside the main output.
- Geodesic audio pitch mapping by orbit type:
  - `bound` — pitch ∝ dφ/dτ (orbital angular velocity); wobbles fast at periapsis, slow at apoapsis
  - `plunging` — pitch ∝ 1/√(1 − 2M/r) (gravitational blueshift); rises as particle falls
  - `photon` — same blueshift formula; brief frequency blip as photon passes closest approach
- Amplitude for all geodesic modes is modulated by √(1 − 2M/r) (gravitational redshift);
  most dramatic for plunging, where it fades to silence at the event horizon.
- Key radii (1 r_s = 2M): event horizon at 1 r_s, photon sphere at 1.5 r_s, ISCO at 3 r_s.
- Bound orbit requires angular_momentum_factor giving L̃² > 12; the app warns if this is violated.
- Four physical correctness checks run on every chirp invocation and abort the run on failure.

---

## images

Converts 2D images into audio via Hilbert curve traversal. Four modes encode
pixel data as pitch, with the Hilbert locality property ensuring spatial
gradients become smooth temporal sweeps. `scan_horizontal` is a pedagogical
raster-scan counterpart to `brightness`, included so a listener can hear the
Hilbert-curve locality benefit directly by comparing the two.

**Run:**
```sh
wolframscript -file images/main.wl                                       # brightness mode (default, log scale)
wolframscript -file images/main.wl -- --simulation.mode=scan_horizontal  # pedagogical raster scan
wolframscript -file images/main.wl -- --simulation.mode=colour
wolframscript -file images/main.wl -- --simulation.mode=hsb
wolframscript -file images/main.wl -- --simulation.images.test_image=temperature
wolframscript -file images/main.wl -- --simulation.images.test_image=quantum
wolframscript -file images/main.wl -- --simulation.images.input_file=myimage.png
wolframscript -file images/main.wl -- --simulation.images.size=128
wolframscript -file images/main.wl -- --simulation.images.brightness_scale=linear
wolframscript -file images/main.wl -- --simulation.images.brightness_gamma=2.0
wolframscript -file images/main.wl -- --simulation.images.note_duration_base=0.05
```

**Key config keys (`images/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"brightness"` | `"brightness"`, `"scan_horizontal"`, `"colour"`, or `"hsb"` |
| `simulation.images.size` | `64` | Grid side length (image resized to size×size; must be a power of 2) |
| `simulation.images.input_file` | `""` | Path to a user image file (empty = use built-in test image) |
| `simulation.images.test_image` | `"gaussian"` | Built-in test image: `"gaussian"`, `"temperature"`, or `"quantum"` |
| `simulation.images.freq_min` | `200` | Lowest frequency in Hz (brightness/scan_horizontal modes) |
| `simulation.images.freq_max` | `2000` | Highest frequency in Hz (brightness/scan_horizontal modes) |
| `simulation.images.brightness_scale` | `"log"` | `"log"` (default) or `"linear"` brightness-to-frequency mapping |
| `simulation.images.brightness_gamma` | `1.0` | Log-scale exponent; >1 compresses highlights, <1 compresses shadows |
| `simulation.images.note_duration_base` | `0.02` | Seconds per pixel (brightness/scan_horizontal/hsb); seconds-per-pixel run-length factor (colour) |
| `simulation.images.scan_direction` | `"hilbert"` | `"hilbert"` (default) or `"raster"`; `scan_horizontal` always uses raster regardless of this key |

**Output files (mode-prefixed):**

| File | Description |
|------|-------------|
| `output/images_{mode}_audio.wav` | Spoken intro + sonification audio |
| `output/images_{mode}.gif` | 32-frame traversal animation (Hilbert path, or sweep line for scan_horizontal) |
| `output/images_{mode}_data.csv` | Per-pixel table: hilbert_index, col, row, brightness, hue, saturation, frequency_assigned |
| `output/images_{mode}.png` | The processed (resized) source image |

**Notes:**
- In `colour` mode, pixels are matched to the nearest of 9 colours ordered by
  position in the visible light spectrum (violet = lowest pitch, C3, through
  red = highest pitch, D4, plus white and black) using colour distance in
  the perceptually uniform Lab colour space. Consecutive pixels of the same
  colour merge into a single held note, duration proportional to run length.
- In `hsb` mode, hue sets a shared pitch on both channels (100–3900 Hz); the
  left channel is a pure reference tone, and the right channel's timbre
  grows richer with brightness (pure sine → +2nd harmonic → +2nd and 3rd
  harmonics) — pitch encodes colour, timbre encodes brightness.
  Saturation controls the amplitude of both channels.
- `brightness`/`scan_horizontal` default to logarithmic brightness-to-pitch
  scaling (matches how human hearing perceives frequency); `linear` is also
  available via `brightness_scale`.
- For images larger than 32×32, `brightness` and `hsb` modes mix in three
  brief 880 Hz orientation clicks at the 25%/50%/75% points of the traversal.
- Audio duration = size² × note_duration_base seconds (e.g. 64×64 at the
  default 20 ms/pixel = ~82 s). Reduce `note_duration_base` or `size` for
  faster exploration.
- See [`images/LISTENING_GUIDE.md`](../images/LISTENING_GUIDE.md) for the
  recommended listening sequence (scan_horizontal → brightness → colour →
  hsb) and the full colour-to-pitch reference table.

---

## cosmology

Sonifies the CMB angular power spectrum. Spectrum mode traverses ℓ values as
notes; sky mode traverses a simulated 2D temperature map via Hilbert curve.
Optionally fetches real Planck 2018 data.

**Run:**
```sh
wolframscript -file cosmology/main.wl                                    # spectrum mode, simulated
wolframscript -file cosmology/main.wl -- --simulation.mode=sky
wolframscript -file cosmology/main.wl -- --simulation.cosmology.source=planck   # real Planck data
wolframscript -file cosmology/main.wl -- --simulation.cosmology.l_max=1000
wolframscript -file cosmology/main.wl -- --simulation.cosmology.sky_resolution=128
```

**Key config keys (`cosmology/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"spectrum"` | `"spectrum"` or `"sky"` |
| `simulation.cosmology.source` | `"simulated"` | `"simulated"` or `"planck"` (fetches from Planck Legacy Archive) |
| `simulation.cosmology.l_max` | `2000` | Maximum multipole ℓ |
| `simulation.cosmology.sky_resolution` | `64` | Sky patch grid side length (power of 2); affects sky mode only |
| `simulation.cosmology.time_stretch` | `1.0` | Audio duration multiplier |

**Output files — spectrum mode:**

| File | Description |
|------|-------------|
| `output/cmb_spectrum_audio.wav` | Spectrum sonification: each multipole ℓ mapped to a note |
| `output/cmb_spectrum.png` | D_ℓ vs log ℓ power spectrum plot with peak markers |
| `output/cmb_spectrum_data.csv` | ℓ, C_ℓ, D_ℓ, is_peak per row |

**Output files — sky mode:**

| File | Description |
|------|-------------|
| `output/cmb_sky_audio.wav` | Sky map sonification via Hilbert traversal |
| `output/cmb_sky.gif` | 32-frame animated Hilbert traversal of the sky patch |
| `output/cmb_sky.png` | Static false-colour temperature map |
| `output/cmb_sky_data.csv` | Per-pixel temperature and assigned frequency |

**Notes:**
- Simulated source: analytic approximation (5 Gaussian peaks + Sachs-Wolfe plateau) matching
  Planck 2018 peak positions and approximate amplitudes. Not a Boltzmann code output.
- Planck source: fetches the official Planck 2018 best-fit TT spectrum (D_ℓ, ℓ=2 to 2508)
  from the Planck Legacy Archive. Falls back to simulated if the fetch fails.
- Four sanity checks run in spectrum mode: spectrum non-negative, at least three peaks found,
  first peak in expected ℓ range, peak amplitudes decreasing as expected.

---

## waves

Solves the 2D wave equation via FEM (Wolfram's `NDSolveValue` on a spatial
`Region`) and sonifies displacement at listening points.

**Run:**
```sh
wolframscript -file waves/main.wl                                        # ripple mode (default)
wolframscript -file waves/main.wl -- --simulation.mode=interference
wolframscript -file waves/main.wl -- --simulation.waves.wave_speed=1.5
wolframscript -file waves/main.wl -- --simulation.waves.source_frequency=3.0
wolframscript -file waves/main.wl -- --simulation.waves.listening_points=8
```

**Key config keys (`waves/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"ripple"` | `"ripple"` or `"interference"` |
| `simulation.waves.wave_speed` | `1.0` | Wave speed c (larger → faster propagation, wider fringe spacing) |
| `simulation.waves.membrane_radius` | `1.0` | Radius of circular membrane (ripple mode) |
| `simulation.waves.tank_width` | `2.0` | Width of rectangular tank (interference mode) |
| `simulation.waves.tank_height` | `1.0` | Height of rectangular tank (interference mode) |
| `simulation.waves.source_frequency` | `2.0` | Driving frequency of point sources in Hz (interference mode) |
| `simulation.waves.duration` | `4.0` | Simulation time in seconds |
| `simulation.waves.listening_points` | `6` | Number of radial listening points (ripple mode) |

**Output files:**

| File | Description |
|------|-------------|
| `output/ripple_audio.wav` | Sonified wavefront arrivals at each listening point |
| `output/ripple.gif` | Animated displacement field — expanding circular wavefront |
| `output/ripple.png` | 3D surface plot of displacement at the final time step |
| `output/ripple_data.csv` | Displacement time series at all listening points |
| `output/interference_audio.wav` | LP sweeping through constructive/destructive fringe bands |
| `output/interference.gif` | Animated interference pattern (yellow dot = moving LP, green = sources) |
| `output/interference.png` | Final-frame fringe pattern |
| `output/interference_data.csv` | LP position, displacement, and fixed-LP reference over time |

**Notes:**
- Ripple mode: stereo pan places the closest listening point hard left, most distant hard right;
  the sequence of wavefront arrivals sweeps left to right across the stereo field.
- Interference mode: a moving listening point sweeps perpendicular to the source axis; stereo
  pan tracks its physical x-position.
- Four sanity checks run on every execution: amplitude bounded, wavefront arrival time matches
  distance/speed, causality (inner point receives wavefront first), Dirichlet boundary near zero.

---

## lagrange

Integrates test-particle motion in the circular restricted three-body problem
(CR3BP) via NDSolve with WhenEvent for early-stop escape detection.

**Run:**
```sh
wolframscript -file lagrange/main.wl                                     # L4 libration, Sun-Jupiter
wolframscript -file lagrange/main.wl -- --simulation.mode=l5
wolframscript -file lagrange/main.wl -- --simulation.mode=l1             # L1 saddle escape
wolframscript -file lagrange/main.wl -- --simulation.lagrange.preset=earth_moon
wolframscript -file lagrange/main.wl -- --simulation.lagrange.perturbation=0.05
wolframscript -file lagrange/main.wl -- --simulation.lagrange.duration_periods=12
```

Named presets: `sun_jupiter` (μ = 0.000954, default), `earth_moon` (μ = 0.012151),
`sun_earth` (μ = 3.003×10⁻⁶).

**Key config keys (`lagrange/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"l4"` | `"l4"`, `"l5"`, or `"l1"` |
| `simulation.lagrange.preset` | `"sun_jupiter"` | Named mass-ratio preset (overrides `mass_ratio`) |
| `simulation.lagrange.mass_ratio` | `0.000954` | μ = m₂/(m₁+m₂); set directly or via preset |
| `simulation.lagrange.perturbation` | `0.02` | Initial displacement from the Lagrange point (co-rotating units) |
| `simulation.lagrange.duration_periods` | `6` | Integration duration in orbital periods (l4/l5 modes) |

**Output files — l4 and l5 modes:**

| File | Description |
|------|-------------|
| `output/l4_audio.wav` | Sonified libration — pitch from angular velocity, pan from x-position |
| `output/l4.gif` | 32-frame animated trajectory in the co-rotating frame |
| `output/l4.png` | Full static trajectory with primaries and all 5 Lagrange points |
| `output/l4_trajectory.csv` | 600 rows × 9 columns: t, x, y, vx, vy, omega, r1, r2, dist_to_L4 |
| `output/l5_audio.wav` | Same for L5 mode |
| `output/l5.gif` | Animated L5 trajectory |
| `output/l5.png` | L5 static plot |
| `output/l5_trajectory.csv` | L5 trajectory data |

**Output files — l1 mode:**

| File | Description |
|------|-------------|
| `output/l1_audio.wav` | Sonified escape — wider pitch range (55–1760 Hz) for dramatic dynamics |
| `output/l1.gif` | Animated escape trajectory |
| `output/l1.png` | Full escape trajectory static plot |
| `output/l1_trajectory.csv` | 500 rows × 9 columns: t, x, y, vx, vy, omega, r1, r2, dist_to_L1 |

**Notes:**
- Sonification: pitch ∝ angular velocity ω = (xẏ−yẋ)/(x²+y²); pan ∝ x-position;
  volume ∝ 1/min(r₁,r₂)+0.01 (proximity to nearest primary). l4/l5: 110–880 Hz; l1: 55–1760 Hz.
- Four sanity checks run on every execution: Jacobi constant drift < 0.5%, L4/L5 equilateral
  geometry (r₁=r₂=1 to 10⁻⁵), bounded motion (max dist from L-point < 1.5 units) or escape
  confirmed (distance grew > 3×), no escape from barycentre (max dist < 2.5 units) or early stop.
- The `$mu` global is set in `main.wl` before any src/ functions are called; EOM helpers in
  `src/model.wl` use `$mu` via delayed evaluation.

---

## thermo

Sonifies classical statistical mechanics: the Maxwell-Boltzmann speed
distribution, particle ensembles under elastic collisions, thermal
relaxation, and the equipartition theorem. Purely classical — no quantum
statistics anywhere in this app.

**Run:**
```sh
wolframscript -file thermo/main.wl                                    # distribution (default), helium, 100K->1000K
wolframscript -file thermo/main.wl -- --simulation.mode=ensemble       # 20-particle chord, 300K
wolframscript -file thermo/main.wl -- --simulation.mode=cooling        # thermal relaxation, 1000K->50K
wolframscript -file thermo/main.wl -- --simulation.mode=equipartition  # monatomic vs. diatomic
wolframscript -file thermo/main.wl -- --simulation.thermo.preset=nitrogen
wolframscript -file thermo/main.wl -- --simulation.thermo.T_fixed=600
```

**Key config keys (`thermo/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"distribution"` | `"distribution"`, `"ensemble"`, `"cooling"`, or `"equipartition"` |
| `simulation.thermo.preset` | `"helium"` | Named gas: `hydrogen`, `helium`, `nitrogen`, `oxygen`, `argon` |
| `simulation.thermo.mass_amu` | `4` | Fallback mass (amu) used only if `preset` is unrecognised |
| `simulation.thermo.T_start` / `T_end` | `100` / `1000` | Temperature sweep range, K (distribution, equipartition) |
| `simulation.thermo.T_hot` / `T_cold` | `1000` / `50` | Cooling curve endpoints, K (cooling) |
| `simulation.thermo.T_fixed` | `300` | Fixed temperature, K (ensemble) |
| `simulation.thermo.n_particles` | `20` | Ensemble size, max 50 (ensemble) |
| `simulation.thermo.n_steps` | `100` | Number of temperature steps (distribution, equipartition) |
| `simulation.thermo.n_timesteps` | `200` | Elastic-collision steps (ensemble) |
| `simulation.thermo.n_bins` | `64` | Spectral bins per frame (distribution, cooling, equipartition) |
| `simulation.thermo.frame_duration` | `0.1` | Seconds per frame/timestep (all modes) |
| `simulation.thermo.freq_min` / `freq_max` | `80` / `4000` | Audio frequency range, Hz (all modes) |
| `simulation.thermo.molecule` | `"diatomic"` | `"monatomic"` or `"diatomic"` (equipartition; drives mass via `RepresentativeGasForMoleculeType`, independent of `preset`) |

**Output files (mode-prefixed):**

| File | Description |
|------|-------------|
| `output/distribution_audio.wav` | Spoken intro + Maxwell-Boltzmann temperature sweep (additive synthesis) |
| `output/distribution.gif` | Animated MB curve, colour shifting blue→red as T rises |
| `output/distribution_data.csv` | Per-step: T, v_p, v_mean, v_rms |
| `output/ensemble_audio.wav` | Spoken intro + particle-ensemble chord |
| `output/ensemble.gif` | Animated speed histogram vs. the analytic MB curve |
| `output/ensemble_data.csv` | Per-(timestep, particle): speed, collided flag |
| `output/cooling_audio.wav` | Spoken intro + thermal relaxation sonification |
| `output/cooling.gif` | Two-panel: T(t) curve + current MB distribution |
| `output/cooling_data.csv` | Per-frame: time, T, amplitude scale, equilibrium flag |
| `output/equipartition_audio.wav` | Spoken intro + binaural translational/rotational comparison |
| `output/equipartition.gif` | Side-by-side monatomic vs. diatomic energy-partition pie charts |
| `output/equipartition_data.csv` | Per-step: T, translational/rotational/total energy, rotational fraction |

**Notes:**
- Additive synthesis, not stem-core's `SonifyTrajectory` pipeline: each frame
  synthesises many simultaneous sine partials (one per MB bin, or one per
  ensemble particle) so the frame's spectral envelope literally *is* the
  Maxwell-Boltzmann curve — a third sonification paradigm alongside
  trajectory-based and Hilbert-field-based (see root `AGENTS.md`).
- Two correctness checks run on every invocation (normalisation, characteristic
  speed ratios `v_mean/v_p = Sqrt[4/pi]` and `v_rms/v_p = Sqrt[3/2]`); `ensemble`
  and `equipartition` each add one more (equilibration within 10%, translational
  KE = (3/2)kT within 1%).
- `equipartition` mode's mass comes from `molecule`, not `preset`/`mass_amu` —
  those two drive `distribution`/`ensemble`/`cooling` only.
- See [`thermo/LISTENING_GUIDE.md`](../thermo/LISTENING_GUIDE.md) for the
  recommended five-step listening sequence.

---

## montecarlo

Sonifies the 2D ferromagnetic Ising model via Metropolis Monte Carlo — one of
the few exactly-solved phase transitions in statistical physics (Onsager
1944), critical temperature `T_c = 2J/k / ln(1+sqrt(2)) ≈ 2.269 J/k`.

**Run:**
```sh
wolframscript -file montecarlo/main.wl                                        # sweep (default), 32x32, T 4.0->0.5
wolframscript -file montecarlo/main.wl -- --simulation.mode=critical          # fixed at T_c
wolframscript -file montecarlo/main.wl -- --simulation.mode=quench            # instantaneous T_hot->T_cold
wolframscript -file montecarlo/main.wl -- --simulation.montecarlo.lattice_size=64
wolframscript -file montecarlo/main.wl -- --simulation.montecarlo.N_T_steps=100
wolframscript -file montecarlo/main.wl -- --simulation.montecarlo.T_fixed=3.0  # above T_c
wolframscript -file montecarlo/main.wl -- --simulation.montecarlo.T_fixed=1.5  # below T_c
```

**Key config keys (`montecarlo/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"sweep"` | `"sweep"`, `"critical"`, or `"quench"` |
| `simulation.montecarlo.lattice_size` | `32` | Grid side length (coerced to the nearest power of 2 for the Hilbert spatial layer) |
| `simulation.montecarlo.T_start` / `T_end` | `4.0` / `0.5` | Sweep endpoints (sweep) |
| `simulation.montecarlo.N_T_steps` | `50` | Number of temperature steps (sweep) |
| `simulation.montecarlo.n_equilibration` | `200` | Discarded sweeps per temperature step (sweep) |
| `simulation.montecarlo.n_measurement` | `100` | Recorded sweeps per temperature step (sweep) |
| `simulation.montecarlo.T_fixed` | `2.2692` | Fixed temperature (critical) |
| `simulation.montecarlo.T_hot` / `T_cold` | `4.0` / `0.5` | Quench endpoints (quench) |
| `simulation.montecarlo.n_sweeps` | `500` | Sweep count (critical; `main.wl` defaults quench's own count to 400) |
| `simulation.montecarlo.random_seed` | `42` | RNG seed (quench) |
| `simulation.montecarlo.J` | `1.0` | Coupling constant |
| `simulation.montecarlo.pixel_duration` | `0.001` | Seconds per spin before run-length grouping (spatial layer) |
| `sonification.montecarlo.spatial_layer_gain` | `-12` | Spatial (Hilbert) layer level relative to the observable layer, dB |

**Output files (mode-prefixed):**

| File | Description |
|------|-------------|
| `output/sweep_audio.wav` | Spoken intro + two-layer temperature-sweep sonification |
| `output/sweep.gif` | Two-panel: spin grid + M(T) curve with a T_c marker |
| `output/sweep_data.csv` | Per-sweep: T, M, E_per_spin, \|dM\|, chi_estimate, articulated |
| `output/critical_audio.wav` | Spoken intro + fixed-T_c sonification |
| `output/critical.gif` | Spin grid at T_c, fractal-like domain structure |
| `output/critical_data.csv` | Per-sweep data at fixed T |
| `output/quench_audio.wav` | Spoken intro + quench sonification |
| `output/quench.gif` | Spin grid coarsening from noise to large domains |
| `output/quench_data.csv` | Per-sweep data during the quench |

**Notes:**
- Two simultaneous sonification layers, mixed together: global observables
  (|M|, energy, susceptibility) via stem-core's continuous
  `SpatialLayer`/`MotionLayer` carrier, plus a quieter Hilbert-curve spatial
  scan of the spin grid itself (run-length held notes, reusing `cellular/`'s
  note-holding technique) — the first app in the project to combine the
  trajectory-based and Hilbert-field-based paradigms in one output.
- Three correctness checks run on every invocation (Onsager T_c, energy
  bounds, detailed balance); `sweep` adds a fourth (magnetisation convergence,
  |M| > 0.8 below T=1.0).
- See [`montecarlo/LISTENING_GUIDE.md`](../montecarlo/LISTENING_GUIDE.md) for
  the recommended three-mode listening sequence.

---

## magnetic

Simulates and sonifies charged-particle motion under the Lorentz force,
`F = q(E + v x B)`, across four field configurations: cyclotron orbits, E×B
drift, magnetic mirror trapping, and a multi-particle cyclotron chord.

**Run:**
```sh
wolframscript -file magnetic/main.wl                                          # cyclotron (default)
wolframscript -file magnetic/main.wl -- --simulation.mode=drift               # E x B drift cycloid
wolframscript -file magnetic/main.wl -- --simulation.mode=mirror              # magnetic mirror
wolframscript -file magnetic/main.wl -- --simulation.mode=multi               # proton+alpha+electron chord
wolframscript -file magnetic/main.wl -- --simulation.magnetic.v_parallel=0.5  # helix orbit (cyclotron mode)
wolframscript -file magnetic/main.wl -- --simulation.magnetic.B_z=2.0         # stronger field
```

**Key config keys (`magnetic/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"cyclotron"` | `"cyclotron"`, `"drift"`, `"mirror"`, or `"multi"` |
| `simulation.magnetic.B_z` | `1.0` | Uniform field strength (cyclotron, drift, multi) |
| `simulation.magnetic.E_x` | `0.5` | Electric field strength (drift only) |
| `simulation.magnetic.B_0` | `1.0` | Minimum field strength at the mirror midplane |
| `simulation.magnetic.alpha` | `0.5` | Mirror field gradient (larger = stronger, shorter mirror) |
| `simulation.magnetic.charge_mass_ratio` | `1.0` | q/m for the single-particle modes |
| `simulation.magnetic.v_perp` | `1.0` | Initial speed perpendicular to B |
| `simulation.magnetic.v_parallel` | `0.0` | Initial speed along B (cyclotron helix / mirror pitch angle); `main.wl` substitutes `0.8` for mirror mode unless overridden on the CLI |
| `simulation.magnetic.n_periods` | `5` | Cyclotron periods to simulate (cyclotron, drift, multi) |
| `simulation.magnetic.mirror_duration` | `30.0` | Total integration time, mirror mode |
| `simulation.magnetic.base_freq_hz` | `110.0` | Hz mapped to `omega_c = 1` (app-wide audio scale, all four modes) |

Note: `v_perp` also defaults differently per mode in practice — `main.wl`
substitutes `1.5` for mirror mode unless the CLI overrides it — for the same
reason `v_parallel` does (mirror mode's own default pitch angle differs from
cyclotron/drift's pure-circular-orbit default).

**Output files (mode-prefixed):**

| File | Description |
|------|-------------|
| `output/cyclotron_audio.wav` | Steady tone at the cyclotron frequency, panning with the orbit |
| `output/cyclotron.gif` | 2D circle or 3D helix trajectory |
| `output/cyclotron_data.csv` | Time series: t, x, y, z, vx, vy, vz, speed, kinetic_energy |
| `output/drift_audio.wav` | Oscillating pitch, steadily drifting pan |
| `output/drift.gif` | 2D cycloid trajectory, coloured by speed |
| `output/drift_data.csv` | Drift trajectory time series |
| `output/mirror_audio.wav` | Rising/falling pitch, accent at each reflection |
| `output/mirror.gif` | 3D spiral trajectory with a field-strength gradient |
| `output/mirror_data.csv` | Mirror trajectory time series |
| `output/multi_audio.wav` | Three-particle cyclotron chord (proton/alpha/electron) |
| `output/multi.gif` | Three simultaneous orbits |
| `output/multi_data.csv` | Long format: one row per particle per timestep, with a `particle` label column |

**Notes:**
- Orbit integration via `NDSolve`, the same pattern used by `lagrange/` and
  `relativity/`'s `geodesic` mode. Mirror mode additionally includes the
  small radial field component required by `div B = 0` — a purely axial
  `Bz(z)` field cannot physically produce a mirroring force on its own.
- `multi` mode uses a closed-form solution rather than `NDSolve`: the
  electron's charge-to-mass ratio is 1836x the proton's, so resolving its
  gyration numerically over the same time window as the proton would need
  ~1836x finer steps for a physically trivial (exact) result.
- Four correctness checks run on every invocation: cyclotron period
  (cyclotron), E×B drift velocity (drift), mirror trapping (mirror), energy
  conservation (all modes — constant for cyclotron/mirror/multi, periodic
  return for drift since the electric field does instantaneous but not net
  work).
- See [`magnetic/LISTENING_GUIDE.md`](../magnetic/LISTENING_GUIDE.md) for the
  recommended listening sequence.

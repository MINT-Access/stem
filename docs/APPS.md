# STEM Apps — Quick Reference

All eight apps share the same invocation pattern and config system. This
document covers CLI options, modes, config keys, and output files for each.

---

## Quick comparison

| App | Domain | Modes | Output dir | Has live data? |
|-----|--------|-------|-----------|---------------|
| `pendulum` | Physics ODE | `simple`, `double` | `data/` | No |
| `lorenz` | Strange attractor | `lorenz`, `rossler`, `chen` | `data/` | No |
| `asteroids` | NASA NeoWs API | — | `data/` | Yes |
| `cellular` | Cellular automata | `life`, `rule110` | `output/` | No |
| `signal` | Fourier analysis | `chord`, `sweep`, `am` | `output/` | No |
| `quantum` | Quantum mechanics | `qho`, `box` | `output/` | No |
| `primes` | Prime number patterns | `ulam`, `gaps` | `output/` | No |
| `relativity` | General relativity | `chirp`, `geodesic` | `output/` | No |

---

## Config system

Every app uses a four-layer config:

```
$HardcodedDefaults → config/config.json → <app>/config.json → CLI --key=value
```

Keys use dot notation for nesting. CLI overrides are `--key.subkey=value`.
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
| `data/simple_audio.wav` | Simple mode sonification |
| `data/simple_animation.gif` | Simple pendulum animation |
| `data/simple_results.csv` | Angle and velocity time series |
| `data/double_audio.wav` | Double mode sonification |
| `data/double_animation.gif` | Double pendulum animation |
| `data/double_results.csv` | Angles and velocities, both rods |

---

## lorenz

Simulates strange attractors. Notes are triggered at local extrema of x(t);
spatial position sets the stereo pan. The GIF grows the trajectory frame by
frame.

**Run:**
```sh
wolframscript -file lorenz/main.wl
wolframscript -file lorenz/main.wl -- --simulation.mode=rossler
wolframscript -file lorenz/main.wl -- --simulation.mode=chen
wolframscript -file lorenz/main.wl -- --simulation.lorenz.rho=35
```

**Key config keys (`lorenz/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.mode` | `"lorenz"` | `"lorenz"`, `"rossler"`, or `"chen"` |
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
| `data/lorenz_audio.wav` | Sonification of x(t) extrema events |
| `data/lorenz_animation.gif` | Growing trajectory animation |
| `data/lorenz_trajectory.csv` | x, y, z time series |

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
```

Positional arguments: `[-- YYYY-MM-DD YYYY-MM-DD [Scale]]`

Valid scales: `MinorPentatonic` `MajorPentatonic` `Major` `Minor` `WholeTone` `Phrygian`

**Key config keys (`asteroids/config.json`):**

| Key | Default | Description |
|-----|---------|-------------|
| `simulation.days_ahead` | `7` | Days from today when no dates given |
| `simulation.max_objects` | `10` | Max asteroids to sonify |
| `sonification.pitch.min_hz` | `150` | Miss-distance → pitch low bound |
| `sonification.pitch.max_hz` | `900` | Miss-distance → pitch high bound |

**Output files:**

Output filenames include the date range, e.g. `asteroids_2026-06-21_2026-06-27.wav`.

| File | Description |
|------|-------------|
| `data/asteroids_{start}_{end}.wav` | Sonification (one note per asteroid) |
| `data/asteroids_{start}_{end}.gif` | Top-down solar system animation |
| `data/asteroids_{start}_{end}.csv` | Per-asteroid data (distance, velocity, size) |

**API key:** The DEMO_KEY allows ~30 requests/hour. For unrestricted access
set `NASA_API_KEY` in your environment before running.

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

**Output files:**

| File | Description |
|------|-------------|
| `output/life_rpentomino_audio.wav` | Game of Life sonification |
| `output/life_rpentomino_animation.gif` | Game of Life animation |
| `output/life_rpentomino_stats.csv` | Population per generation |
| `output/rule110_audio.wav` | Rule 110 sonification |
| `output/rule110_animation.gif` | Rule 110 animated space-time diagram |
| `output/rule110_animation_spacetime.png` | Rule 110 static space-time image |
| `output/rule110_stats.csv` | Row density per generation |

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

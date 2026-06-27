# STEM Apps — Quick Reference

All five apps share the same invocation pattern and config system. This
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
| `data/simple_pendulum.gif` | Simple pendulum animation |
| `data/simple_pendulum.csv` | Angle and velocity time series |
| `data/double_audio.wav` | Double mode sonification |
| `data/double_pendulum.gif` | Double pendulum animation |
| `data/double_pendulum.csv` | Angles and velocities, both rods |

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
| `data/lorenz_trajectory.gif` | Growing trajectory animation |
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

| File | Description |
|------|-------------|
| `data/asteroids_audio.wav` | Sonification (one note per asteroid) |
| `data/asteroids_approach.gif` | Top-down solar system animation |
| `data/asteroids_data.csv` | Per-asteroid data (distance, velocity, size) |

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
| `output/life_rpentomino.gif` | Game of Life animation |
| `output/life_rpentomino.csv` | Population per generation |
| `output/rule110_audio.wav` | Rule 110 sonification |
| `output/rule110.gif` | Rule 110 space-time diagram |
| `output/rule110.csv` | Row density per generation |

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
| `output/{mode}_spectrum.png` | Frequency spectrum plot |
| `output/{mode}_signal.csv` | Clean, noisy, and recovered sample arrays |

The `{mode}_narrative_full.wav` file is the most accessible output — it chains
spoken introductions with audio playback of each stage so the demonstration
can be followed by listening alone.

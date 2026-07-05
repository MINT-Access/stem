# Resonance

Sonifies orbital resonance — the phenomenon where orbiting bodies'
periods lock into simple integer ratios — across three settings: the
exact 4:2:1 resonance locking Jupiter's Galilean moons together, the
Kirkwood gaps that same resonance mechanism clears in the asteroid
belt, and the Cassini Division Saturn's moon Mimas clears in Saturn's
rings. This is the app where planetary mechanics and music theory meet
most precisely: a 2:1 orbital resonance *is* a musical octave.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`

## What orbital resonance is

Two orbiting bodies are in a p:q resonance when their periods satisfy
`p*T_1 = q*T_2` for small integers p and q. By Kepler's third law
(period-squared proportional to semi-major-axis-cubed), a p:q period
resonance corresponds to a semi-major-axis ratio
`a_1/a_2 = (p/q)^(2/3)`. Integer period ratios are special because they
mean two bodies return to the same relative configuration over and
over — every close encounter happens at the same orbital phase, so
gravitational perturbations accumulate instead of averaging out. That
accumulation can either *stabilise* a configuration (the Galilean
moons, locked together for the age of the solar system) or *destroy*
one (the Kirkwood gaps and Cassini Division, both regions swept clear
by repeated resonant kicks).

## The Galilean moon Laplace resonance

Io, Europa, and Ganymede orbit Jupiter with periods in almost exactly
4:2:1 ratio (1.769, 3.551, and 7.155 days). The three-body Laplace
resonance angle `phi = lambda_Io - 3*lambda_Europa + 2*lambda_Ganymede`
(where lambda are mean longitudes) librates around 180 degrees rather
than drifting freely — a genuine three-body lock, not just three
independent 2-body resonances. One consequence: conjunctions of
Io-Europa and Europa-Ganymede never coincide, so all three moons never
approach each other simultaneously, even though Io and Ganymede's
individual periods are locked to Europa's.

The resonance is not merely decorative — it is the reason Io is the
most volcanically active body in the solar system. The Laplace
resonance forces Io's orbit to remain measurably eccentric (rather than
circularising, as an isolated moon's orbit would over time), and that
eccentricity means Jupiter's tidal pull on Io varies significantly
around each orbit. The resulting tidal flexing dumps enormous heat into
Io's interior — over 100 active volcanoes, more than every other body
in the solar system combined, all powered by the same 4:2:1 lock this
app sonifies as a two-octave chord.

## Kirkwood gaps

Daniel Kirkwood noticed in 1866 that the distribution of asteroids in
the main belt is not smooth — there are sharp, near-empty gaps at
semi-major axes corresponding to simple period-ratio resonances with
Jupiter (4:1, 3:1, 5:2, 7:3, 2:1). An asteroid sitting in one of these
gaps would pass close to Jupiter's gravitational influence at the same
orbital phase, orbit after orbit; those repeated kicks pump up its
orbital eccentricity until it either collides with something or gets
ejected onto a different orbit entirely. Over the age of the solar
system, this has swept the gap locations almost completely clear —
resonance here acts as an eviction notice, not a lock.

## Saturn's rings and the Cassini Division

The dark gap visible in Saturn's rings through even a small backyard
telescope — the Cassini Division, discovered by Giovanni Cassini in
1675 — is the same phenomenon on a much smaller scale: ring particles
orbiting at that radius are in a 2:1 resonance with the moon Mimas, and
the resulting repeated gravitational kicks have cleared the gap of
almost all material. The Encke gap, a narrower notch within the outer A
ring, is the same mechanism driven by the small moon Pan (3:2
resonance).

## The musical connection: 2:1 resonance is an octave

A frequency ratio of 2:1 is, by definition, a musical octave — the most
consonant interval in Western (and most other) music theories. When the
Galilean moons' 4:2:1 period ratio is mapped directly onto pitch
(Ganymede : Europa : Io as C3 : C4 : C5), the result is not an
arbitrary sonification choice dressed up as music — it is the same
integer-ratio relationship in both domains simultaneously. The
mathematical property that makes small integer frequency ratios sound
stable and consonant to the human ear is the same property that makes
small integer period ratios dynamically stable in a gravitational
system.

## Kepler's Harmonices Mundi

Johannes Kepler spent much of his career searching for musical harmony
in the motion of the planets, culminating in *Harmonices Mundi* (1619).
Most of his specific claims — matching planetary angular velocities to
musical intervals and chords — do not hold up under modern orbital
mechanics; he was reaching for a pattern using incomplete and partly
incorrect data. But the Galilean moons, which Galileo had discovered
just nine years earlier in 1610, genuinely do lock into exact musical
ratios, for reasons Kepler had no way of deriving (the physics of
resonant tidal locking would not be understood for centuries). Kepler
was right about the existence of a harmony-of-the-spheres-like
phenomenon in the solar system; he was simply looking at the wrong
bodies.

## Modes

### `galilean` (default)

Simulates Io, Europa, and Ganymede as circular orbits with exact
4:2:1 period ratios and sonifies the result as a three-voice rhythmic
canon: every Ganymede orbit completion triggers a sustained C3 note,
every Europa completion a C4 note, every Io completion a C5 note — in
an exact 1:2:4 ratio of note counts, because that is exactly the
period ratio. A quiet constant-frequency drone (same 4:2:1 ratio, one
octave lower) runs underneath for texture. See `LISTENING_GUIDE.md`.

### `kirkwood`

Sonifies asteroid belt density vs semi-major axis as a spectral chord
(all radii simultaneously), then a sweep from the inner to outer belt.
The five Kirkwood gaps (4:1, 3:1, 5:2, 7:3, 2:1 Jupiter resonances) are
audible as brief silences in the sweep, each marked with a soft accent
tone and a console/spoken announcement of which resonance is being
crossed.

### `saturn`

Same chord+sweep structure applied to Saturn's ring density vs orbital
radius, from the C ring (74,000 km) to the outer A ring (137,000 km).
The dense B ring is the loudest section; the Cassini Division (117,580
km, the 2:1 Mimas resonance) is a long, clearly audible silence; the
narrower Encke gap (133,589 km, the 3:2 Pan resonance) is a briefer one
within the A ring.

## Config keys (`config.json`)

| Key | Default | Meaning |
|---|---|---|
| `simulation.mode` | `"galilean"` | `galilean` \| `kirkwood` \| `saturn` |
| `simulation.resonance.n_periods` | `8` | Ganymede periods simulated (`galilean`) |
| `simulation.resonance.n_steps` | `200` | Sample/bin resolution (all modes; `saturn` defaults effectively to 300 internally if unset) |
| `simulation.resonance.a_min_AU` | `2.0` | Asteroid belt inner edge (`kirkwood`) |
| `simulation.resonance.a_max_AU` | `3.5` | Asteroid belt outer edge (`kirkwood`) |
| `simulation.resonance.gap_width_AU` | `0.05` | Kirkwood gap width (`kirkwood`) |
| `simulation.resonance.r_min_km` | `74000` | Ring inner edge (`saturn`) |
| `simulation.resonance.r_max_km` | `137000` | Ring outer edge (`saturn`) |
| `simulation.resonance.freq_min` | `150` | Sweep/chord frequency floor, Hz (`saturn` only — see `AGENTS.md`) |
| `simulation.resonance.freq_max` | `3000` | Sweep/chord frequency ceiling, Hz (`saturn` only) |
| `simulation.resonance.duration_per_step` | `0.05` | Seconds per sweep step (`kirkwood`/`saturn`) |
| `simulation.resonance.chord_duration` | `4.0` | Seconds for the simultaneous chord (`kirkwood`/`saturn`) |
| `sonification.resonance.trajectory_layer_gain` | `-12` | dB gain of the continuous drone layer (`galilean`) |

See `LISTENING_GUIDE.md` for a guided listening sequence and
`AGENTS.md` for the physics and engineering decisions behind the
implementation.

## Connection to `lagrange/` and `scattering/`

`lagrange/` covers a different flavour of orbital resonance: Jupiter's
Trojan asteroids sit at the L4/L5 Lagrange points in an exact 1:1
resonance with Jupiter itself (same period, offset by 60 degrees) —
the simplest possible integer ratio, and, like the Galilean moons,
a *stabilising* resonance. This app's `kirkwood` mode is the other
side of the same coin: Jupiter's gravity, acting through resonance,
stabilises some orbits (1:1 at L4/L5, 4:2:1 for the Galilean moons)
while clearing others (the Kirkwood gaps) — same mechanism, opposite
outcome, depending on the geometry. `scattering/` is connected more
loosely: it is Jupiter's gravity (via a very different, unbound
hyperbolic-orbit mechanism) that also scatters asteroids out of the
solar system entirely once a Kirkwood resonance has pumped up their
eccentricity enough — the same repulsive-force mathematics `scattering/`
uses for Rutherford scattering describes the close encounters that
finish the ejection this app's `kirkwood` mode only shows the setup for.

## Running

```sh
# Default: galilean, 8 Ganymede periods
wolframscript -file resonance/main.wl

# Shorter / longer galilean runs
wolframscript -file resonance/main.wl -- --simulation.resonance.n_periods=4
wolframscript -file resonance/main.wl -- --simulation.resonance.n_periods=16

# Asteroid belt Kirkwood gaps
wolframscript -file resonance/main.wl -- --simulation.mode=kirkwood
wolframscript -file resonance/main.wl -- --simulation.resonance.gap_width_AU=0.02

# Saturn's rings
wolframscript -file resonance/main.wl -- --simulation.mode=saturn

# Play the output (macOS)
afplay resonance/output/galilean_audio.wav
afplay resonance/output/kirkwood_audio.wav
afplay resonance/output/saturn_audio.wav
```

## Correctness checks

Printed on every run, regardless of mode:

1. **Period ratio** (`galilean`) — Io completes exactly 4x as many
   orbits as Ganymede, Europa exactly 2x, within 0.01 orbits.
2. **Kepler's third law** (`kirkwood`) — all five Kirkwood resonance
   radii match their commonly-cited reference values within 0.5%.
3. **Cassini Division location** — the idealised 2:1 Mimas resonance
   prediction is within 1000 km of the real observed value (see
   `AGENTS.md` for why 100 km, as originally specified, is not
   physically achievable).
4. **Musical interval** (`galilean`) — the C3/C4/C5 pitches have
   frequency ratios 1:2:4 within 0.01%.

## Output files

| File | Description |
|------|-------------|
| `output/galilean_audio.wav` | Rhythmic canon (event layer) + 4:2:1 drone (trajectory layer) |
| `output/galilean.gif` | Top-down orbital animation, Io/Europa/Ganymede with fading trails |
| `output/galilean_data.csv` | Time series: angles, positions, and orbit-completion event flags |
| `output/kirkwood_audio.wav` | Chord, then sweep with Kirkwood gaps audible as silences |
| `output/kirkwood.gif` | Animated sweep across the asteroid belt density curve |
| `output/kirkwood_data.csv` | One row per sample: semi-major axis, density, pitch, amplitude |
| `output/saturn_audio.wav` | Chord, then sweep with the Cassini Division audible as a gap |
| `output/saturn.gif` | Animated sweep across Saturn's ring density, false-coloured by region |
| `output/saturn_data.csv` | One row per sample: orbital radius, ring region, density, pitch |

## Project structure

```
resonance/
  main.wl           — Entry point (thin orchestrator)
  experiments.wl    — Curated preset runs
  config.json       — App defaults
  src/
    model.wl        — Galilean/Kirkwood/Saturn models, correctness checks
    sonify.wl       — Event canon + drone (galilean), spectral chord + sweep (kirkwood/saturn)
    animate.wl      — GIF rendering (all three modes)
    output.wl       — CSV export
  tests/
    test_model.wl   — Unit tests (period ratios, Kepler gap, Cassini, octaves, event counts)
  output/           — Output files (not committed)
  README.md
  AGENTS.md
  LISTENING_GUIDE.md
```

## Console output

Step numbers `[1/4]` through `[4/4]` mark each pipeline stage.
Correctness-check results print `[PASS]` or `[FAIL]` with the measured
value. Export confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`,
and `STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage
announcements and resonance-crossing callouts:

```sh
STEM_SPEAK=1 wolframscript -file resonance/main.wl
```

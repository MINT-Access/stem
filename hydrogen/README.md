# Hydrogen Atom

A Wolfram Language sonification of the quantum mechanics of the hydrogen
atom — its wave functions, emission spectrum, and electron transitions —
runnable entirely from the terminal via `wolframscript`. Hydrogen is the
only atom whose Schrödinger equation can be solved exactly in closed
form, which makes it the foundation of everything else in atomic
physics: every other element's spectrum, every molecule's chemical
bond, and the periodic table itself are built from approximations to
what hydrogen gives you exactly.

## The mathematics

### Energy levels and the Rydberg formula

The electron's allowed energies are quantised:

    E_n = -13.6057 / n^2  eV,   n = 1, 2, 3, ...

A transition from an excited state n_upper down to n_lower releases a
photon whose energy is the difference:

    delta E = 13.6057 * (1/n_lower^2 - 1/n_upper^2)  eV
    nu      = delta E / h                              (h = 4.13567e-15 eV s)
    lambda  = c / nu

This is the Rydberg formula, and it is one of the most precisely
verified equations in physics — the n=3->2 line (H-alpha) sits at
656.279 nm, measured to better than one part in a million in modern
spectroscopy labs.

### The three spectral series

| Series | n_lower | Region | Historical note |
|--------|---------|--------|------------------|
| Lyman | 1 | Ultraviolet, 91-122 nm | Discovered 1906, explains why hydrogen's ground-state transitions are invisible to the eye |
| Balmer | 2 | Visible, 365-656 nm | Discovered empirically in 1885 — this is the light you actually see from a hydrogen lamp |
| Paschen | 3 | Near-infrared, 820-1875 nm | Discovered 1908 |

The four Balmer lines have names: H-alpha (656.3 nm, red), H-beta
(486.1 nm, blue-green), H-gamma (434.0 nm, violet), H-delta (410.2 nm,
violet). These same four wavelengths appear as dark absorption lines in
the spectrum of every star, including the Sun, and as the emission
signature of hydrogen nebulae across the universe.

### Wave functions: quantum numbers and nodes

Each electron state is described by three quantum numbers,
psi_{n,l,m}(r,theta,phi) = R_{n,l}(r) * Y_l^m(theta,phi):

- **n** (principal): sets the energy and roughly the orbital's size
- **l** (angular momentum, 0 <= l <= n-1): sets the orbital's shape
  (l=0 is "s", spherically symmetric; l=1 is "p", two lobes; l=2 is
  "d", four-lobe patterns)
- **m** (magnetic, -l <= m <= l): sets the orientation of the shape

A **node** is a surface where the wave function is exactly zero — the
electron has zero probability of being found there. Higher n and l
produce more nodes (radial shells for higher n, angular planes/cones
for higher l).

### Einstein A coefficients

Not every allowed transition is equally likely. The Einstein A
coefficient is the transition's rate (in s^-1) — bigger A means a
brighter, faster, more probable decay. H-alpha (A = 4.41e7 s^-1) is the
brightest Balmer line; H-delta (A = 9.73e5 s^-1) is roughly 45 times
dimmer, which is why real hydrogen discharge tubes and nebulae glow
predominantly red (H-alpha) rather than violet.

### Selection rules

Not every energy-conserving transition actually happens. Electric-
dipole radiation requires the electron's orbital angular momentum to
change by exactly one unit: **Delta l = +-1**. A transition with
Delta l = 0 (e.g. 2s -> 1s) or |Delta l| > 1 is forbidden and does not
occur via ordinary photon emission — see `transitions` mode below and
`LISTENING_GUIDE.md` for what this means for the 2s state specifically.

## Modes

### `orbitals` (default)

Sonifies \|psi_nlm\|^2 on a 2D cross-section through the xz-plane, using
the same Hilbert-curve traversal as `images/`'s brightness mode:
spatially nearby points in the orbital become temporally nearby notes,
so the orbital's lobes and nodes become audible sweeps and silences.

Six orbitals available via `--simulation.hydrogen.orbital=`:
`100` (1s), `200` (2s), `210` (2p, default), `300` (3s), `320` (3d,
m=0), `321` (3d, four-lobe clover).

### `spectrum`

Sonifies the complete n=2..n_max emission spectrum two ways: first as a
chord (every line simultaneously), then as a sweep from ultraviolet
through visible to infrared, with the four Balmer lines marked by a
soft bell accent.

### `transitions`

Simulates an electron cascading from an excited state down to the
ground state via a sequence of random, selection-rule-respecting
quantum jumps. Runs `n_realizations` independent cascades so you can
hear the range of possible decay paths — different every time, but
always ending on the same final (ground-state) note.

See **`LISTENING_GUIDE.md`** for the recommended listening order and
more on what to listen for in each mode.

## Usage

```bash
# Default (2p orbital)
wolframscript -file main.wl

# Other orbitals
wolframscript -file main.wl -- --simulation.hydrogen.orbital=100
wolframscript -file main.wl -- --simulation.hydrogen.orbital=320
wolframscript -file main.wl -- --simulation.hydrogen.orbital=321

# Spectrum and transitions modes
wolframscript -file main.wl -- --simulation.mode=spectrum
wolframscript -file main.wl -- --simulation.mode=transitions
wolframscript -file main.wl -- --simulation.hydrogen.n_start=7
wolframscript -file main.wl -- --simulation.hydrogen.n_realizations=5

# Inspect merged config
wolframscript -file main.wl -- --config-dump

# Unit tests / curated experiments
wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl

# Play sonification (macOS)
afplay output/orbitals_audio.wav
afplay output/spectrum_audio.wav
afplay output/transitions_audio.wav
```

Linux: replace `afplay` with `aplay`. Windows PowerShell:
`Start-Process wmplayer output\orbitals_audio.wav`

## Config keys (`config.json`)

| Key | Default | Meaning |
|-----|---------|---------|
| `simulation.mode` | `"orbitals"` | `orbitals` / `spectrum` / `transitions` |
| `simulation.hydrogen.orbital` | `"210"` | Which orbital (orbitals mode): `100`/`200`/`210`/`300`/`320`/`321` |
| `simulation.hydrogen.grid_size` | `64` | Orbital cross-section grid side length (rounded to a power of 2) |
| `simulation.hydrogen.n_max` | `8` | Highest n_upper included in the spectrum (spectrum mode) |
| `simulation.hydrogen.n_start` | `5` | Cascade starting principal quantum number (transitions mode) |
| `simulation.hydrogen.l_start` | `2` | Cascade starting angular momentum quantum number |
| `simulation.hydrogen.n_realizations` | `20` | Number of independent cascades to simulate |
| `simulation.hydrogen.max_steps` | `50` | Safety cap on cascade length |
| `simulation.hydrogen.freq_min` | `100` | Audio frequency floor, Hz |
| `simulation.hydrogen.freq_max` | `4000` | Audio frequency ceiling, Hz |
| `simulation.hydrogen.chord_duration` | `3.0` | Spectrum chord duration, seconds |
| `simulation.hydrogen.note_duration` | `0.3` | Spectrum sweep per-line duration, seconds |

## Outputs

| File | Mode | Description |
|------|------|--------------|
| `orbitals_audio.wav` / `.gif` / `.png` / `_data.csv` | orbitals | Spoken intro + Hilbert-traversal sonification; sweep animation; static cross-section plot; per-pixel data table |
| `spectrum_audio.wav` | spectrum | Full narrated file: intro, chord, sweep, outro |
| `spectrum_chord.wav` / `spectrum_sweep.wav` | spectrum | Raw chord / sweep, no narration |
| `spectrum.gif` / `spectrum_data.csv` | spectrum | Growing stem plot with sweeping cursor; per-line data table |
| `transitions_audio.wav` / `.gif` / `_data.csv` | transitions | Spoken intro + stereo cascade audio; Grotrian diagram animation; per-transition data table |

## Correctness checks

Printed as `[PASS]`/`[FAIL]` on every run:

1. **Energy levels** — E_n = -13.6057/n^2 for n=1..4
2. **Rydberg check** — H-alpha wavelength = 656.279 nm within 0.1%
3. **Wave function normalisation** (orbitals mode) — the 3D integral of
   \|psi\|^2 equals 1; the grid discretisation matches its own continuum
   integral
4. **Selection rule** (transitions mode) — every simulated transition
   satisfies \|Delta l\| = 1

See `AGENTS.md` for the reasoning behind the 0.1% (not 0.01%) wavelength
tolerance and the two-cutoff design of the normalisation check.

## Project structure

    hydrogen/
    ├── main.wl              Entry point
    ├── config.json          App-level defaults
    ├── src/
    │   ├── model.wl         Physics: energy levels, wave functions,
    │   │                    Einstein A, spectral lines, cascades, checks
    │   ├── sonify.wl        Audio synthesis, all three modes
    │   ├── speech.wl        Spoken intro/outro synthesis
    │   ├── animate.wl       GIF/PNG rendering, all three modes
    │   └── output.wl        CSV export + correctness-check printing
    ├── tests/
    │   └── test_model.wl    Unit tests
    ├── experiments.wl        Curated preset invocations
    ├── output/               Output files (not committed)
    ├── AGENTS.md             Guidance for Claude Code
    ├── LISTENING_GUIDE.md    Recommended listening order
    └── README.md

## Connection to other apps

- **`quantum/`** — the other quantum-mechanics app in this project,
  covering time-dependent wave-packet dynamics (a particle in a box,
  a coherent state in a harmonic oscillator) in one spatial dimension.
  `hydrogen/` instead covers a static, exactly-solvable three-
  dimensional system and its spectroscopy — no time evolution.
- **`images/`** — the Hilbert-curve traversal that `orbitals` mode uses
  to sonify a 2D density grid was first built there for photographic
  and scientific images; here it sonifies a quantum probability density
  instead.
- **`thermo/`** — statistical mechanics of *many* atoms (a gas), versus
  hydrogen's exact treatment of a *single* atom's internal structure.
- **`relativity/`** — a natural future extension of this app would be
  hydrogen's *fine structure*: the small relativistic and spin-orbit
  corrections to the energy levels computed here, which `relativity/`'s
  machinery is well-suited to eventually model. Not implemented in this
  pass.

# Quantum Statistics — Bose-Einstein, Fermi-Dirac, Maxwell-Boltzmann

Sonifies the three occupation-number distributions of statistical
mechanics — Bose-Einstein, Fermi-Dirac, and Maxwell-Boltzmann — and
the exact sense in which the familiar classical picture is a special
case of the deeper quantum one. This is the app that completes the
quantum/thermo bridge: [`thermo/`](../thermo/README.md)'s classical
Maxwell-Boltzmann speed distribution is not a separate, unrelated
model from the quantum statistics here — it is precisely what both
quantum distributions reduce to in the dilute limit.

**New to this app?** Start with
[`quantum_statistics/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — the
recommended listening sequence across all three modes.

## The physics

### Three occupation numbers

The average number of particles occupying a single-particle state of
energy `epsilon`, at temperature `T` and chemical potential `mu`:

    Bose-Einstein:     n_BE(eps) = 1 / (Exp[(eps-mu)/kT] - 1)     -- bosons
    Fermi-Dirac:       n_FD(eps) = 1 / (Exp[(eps-mu)/kT] + 1)     -- fermions
    Maxwell-Boltzmann: n_MB(eps) = Exp[-(eps-mu)/kT]              -- classical limit

`kT` uses `kB = 8.617333262e-5 eV/K`, derived here from SI `kB` (J/K)
and the exact SI eV-to-J conversion rather than looked up as an
independent value — verified to reproduce the commonly-quoted "kT is
about 0.026 eV at room temperature" fact before being trusted.

### Fermions never exceed one per state — a short, exact argument

`Exp[x] > 0` for every real `x`, so `Exp[x] + 1 > 1` always, so
`n_FD = 1/(Exp[x]+1) < 1` strictly — Pauli exclusion, falling directly
out of the formula's own structure, not imposed separately. `n_FD`
equals exactly `0.5` at `eps=mu`, approaches `1` as `eps` drops well
below `mu`, and approaches (but never reaches) `0` as `eps` rises well
above it.

### The classical limit — an exact identity, not just an asymptote

Both quantum distributions reduce to Maxwell-Boltzmann when
`(eps-mu)/kT` is large (the dilute-gas / high-energy-tail regime).
This app verifies something sharper than the usual asymptotic
hand-wave: with `x=(eps-mu)/kT` and `n_MB=Exp[-x]`, algebra gives
`n_BE = n_MB/(1-n_MB)` and `n_FD = n_MB/(1+n_MB)` exactly, which means

    (n_BE - n_MB) / n_MB  =  n_BE      (exactly, for every x)
    (n_FD - n_MB) / n_MB  =  -n_FD     (exactly, for every x)

The **fractional deviation from the classical limit equals the
occupation number itself** — so "far enough into the dilute regime"
simply means "wherever `n_BE`/`n_FD` are already small." At
`(eps-mu)=10*kT`, `n_MB=Exp[-10]~4.5e-5` and both quantum
distributions sit within that same tiny fraction of the classical
value — comfortably under a `1e-4` tolerance, the threshold this app's
correctness check actually uses (see Correctness checks below).

### Bose-Einstein condensation, made audible not avoided

As `eps -> mu+`, `n_BE` grows without bound — the mathematical
signature of Bose-Einstein condensation (macroscopic occupation of the
lowest available state). This app treats that divergence as a feature
to demonstrate, not an edge case to dodge: `BoseEinsteinOccupation`
requires `eps > mu` strictly (guarded — `eps<=mu` returns
`Missing["BelowChemicalPotential"]` rather than silently producing a
negative or infinite number), and `spectrum`/`temperature` modes both
sweep right up against that boundary.

### mu=0 for spectrum/temperature; a genuine positive Fermi energy for fermi_sea

`spectrum` and `temperature` modes use `mu=0` — the standard reference
for a photon/phonon gas, where particle number is not conserved so
`mu` is exactly zero regardless of `T`. `fermi_sea` mode instead uses a
genuine positive reference energy as `mu` (a real metal's Fermi
energy) — necessary because, with the sweep restricted to `eps>=0`
(which `mu=0` requires for Bose-Einstein's own domain elsewhere in
this app), `mu=0` would only ever show the falling half of the Fermi
step, never the near-1 plateau below it. Fermi-Dirac itself has no
domain restriction, so a positive `mu` is both physically standard and
necessary for `fermi_sea` mode to show the complete step. See
`AGENTS.md` design decisions 1-2 for the full reasoning.

### A verified correction to the usual "cold = quantum" intuition

The familiar "a cold gas is quantum-degenerate, a hot gas is
classical" story is real, but it specifically assumes a large,
*positive*, temperature-independent chemical potential (a real metal's
Fermi energy) — exactly `fermi_sea` mode's setup, where it holds
correctly (verified: the Fermi step's 10-90 transition width scales
*exactly* linearly with `kT`, shrinking to a sharp step as `T->0`). For
`temperature` mode's `mu=0` convention, direct calculation shows the
*opposite*: at fixed `eps` and `mu=0`, low `T` drives `x=(eps-mu)/kT`
large (the dilute/classical regime — all three curves collapse toward
each other, and toward zero), while high `T` drives `x` toward zero
(Bose-Einstein diverging, Fermi-Dirac saturating at `0.5`, all three
curves at their most different). This matches real photon-gas physics
once reframed: a cold cavity holds few, sparse photons per mode
(dilute, classical-looking); a hot cavity is thick with photons per
mode (strongly quantum-bunched). See `AGENTS.md` design decision 3 for
the full verification.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically
- Optional for the spoken intro: macOS `say` (built in), Linux
  `espeak-ng`/`espeak`, or Windows PowerShell (built in) — falls back
  to text-only output if none is available

## Quick start

```sh
# Spectrum mode (default): all three distributions vs energy, T=300K
wolframscript -file main.wl

# Temperature mode: all three distributions vs T, fixed reference energy
wolframscript -file main.wl -- --simulation.mode=temperature

# Fermi sea mode: the Fermi-Dirac step sharpening/blurring with T
wolframscript -file main.wl -- --simulation.mode=fermi_sea

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Modes

### spectrum (default)

All three distributions plotted (and sonified) simultaneously against
energy, at a fixed temperature — reusing
[`thermo/`](../thermo/README.md)'s additive spectral-envelope
technique (`SynthesizeAdditiveFrame`), but as THREE simultaneous
voices rather than one: Bose-Einstein low-register/hard-left,
Fermi-Dirac mid-register/centre, Maxwell-Boltzmann high-register/hard-
right. Hearing all three AT ONCE, not in sequence, is what actually
answers the question this mode poses — do they sound similar (dilute
regime) or very different (degenerate regime)?

**Best for:** hearing where, within a single fixed-temperature sweep,
the three pictures agree and where they visibly (and audibly) part
ways.

### temperature

The same three-voice idea, now swept continuously over temperature at
one fixed energy — reusing
[`blackbody/temperature`](../blackbody/README.md)'s log-compressed-
loudness technique, essential here since Bose-Einstein's occupation
spans roughly 50 orders of magnitude across the default temperature
range. Demonstrates the verified (and, for this `mu=0` convention,
counter-intuitive) direction: convergence at low T, divergence at high
T — see the physics section above.

**Best for:** hearing quantum statistics visibly deviate from the
classical limit, and understanding precisely which direction that
deviation runs for a `mu=0` system.

### fermi_sea

Fermi-Dirac only, swept from very cold (a sharp step function — the
textbook "Fermi sea") to warm (a smoothed exponential tail) — one
additive spectral-envelope frame per temperature step
([`thermo/distribution`](../thermo/README.md)'s own per-T-frame
concatenation idiom, reused directly), audibly a bright,
sharply-differentiated chord at the coldest step, softening into a
duller, more even texture as temperature rises.

**Best for:** hearing (and seeing, via the GIF) the exact `T->0` step
function every solid-state-physics course draws, sharpening and
blurring in real time.

## Correctness checks

All four run unconditionally, every invocation, regardless of mode,
always at fixed canonical parameters (diagnostic-only: print
`[PASS]`/`[FAIL]`, never abort):

1. **Classical limit, exact identity** — verified at `(eps-mu)=10*kT`,
   where `n_MB~4.5e-5` and both quantum distributions' fractional
   deviation from it (which, per the identity above, equals the
   occupation number itself) sits comfortably under `1e-4`.
2. **Fermi-Dirac bound** — `n_FD < 1` for a wide `(eps,T)` sweep
   including values very close to `mu` (where it is largest). Exact,
   structural.
3. **T->0 Fermi-Dirac step** — close to 1 well below `mu`, close to 0
   well above it, at a small `T`; separately, the 10-90 transition
   width is confirmed to scale *exactly* linearly with `kT` by testing
   at three `T` values spanning two decades (not asserted at one `T`).
4. **Bose-Einstein divergence** — grows without bound as `eps->mu+`
   (confirmed to keep growing, not plateau, down to `eps-mu=1e-5`),
   and the `eps<=mu` domain guard is confirmed to actually engage
   (returns `Missing`, checked directly), not merely assumed present.

## Outputs

| File | Description |
|------|-------------|
| `output/quantum_statistics_spectrum.wav` | Three simultaneous voices (BE/FD/MB), distinct pan+register |
| `output/quantum_statistics_spectrum.gif` | Three curves (log10 n) building up vs energy |
| `output/quantum_statistics_spectrum.png` | Static version of the same three-curve overlay |
| `output/quantum_statistics_spectrum.csv` | Per-step: energy, n_BE, n_FD, n_MB |
| `output/quantum_statistics_temperature.wav` | Three voices swept continuously over T, log-compressed |
| `output/quantum_statistics_temperature.gif` | Three curves (log10 n) building up vs log10(T) |
| `output/quantum_statistics_temperature.png` | Static version, converge-at-low-T/diverge-at-high-T labelled |
| `output/quantum_statistics_temperature.csv` | Per-step: T, n_BE, n_FD, n_MB at the reference energy |
| `output/quantum_statistics_fermi_sea.wav` | One spectral frame per T, sharp to blurred |
| `output/quantum_statistics_fermi_sea.gif` | FD(eps) step, animated across T steps |
| `output/quantum_statistics_fermi_sea.png` | All T steps' curves overlaid |
| `output/quantum_statistics_fermi_sea.csv` | Energy, then one n_FD column per T |

## Configuration parameters (`quantum_statistics/config.json`)

| Key | Default | Used by |
|-----|---------|---------|
| `simulation.mode` | `"spectrum"` | all |
| `simulation.quantum_statistics.temperature` | `300.0` (K) | spectrum |
| `simulation.quantum_statistics.temp_min` / `temp_max` | `100.0` / `50000.0` (K) | temperature, fermi_sea |
| `simulation.quantum_statistics.energy_min` / `energy_max` | `0.001` / `2.0` (eV) | spectrum, fermi_sea |
| `simulation.quantum_statistics.reference_energy` | `1.0` (eV) | temperature (fixed eps); fermi_sea (Fermi energy mu) |
| `simulation.quantum_statistics.n_steps` | `150` | all (energy or temperature resolution) |
| `simulation.quantum_statistics.n_temp_steps` | `6` | fermi_sea (number of T frames) |

## Project structure

```
quantum_statistics/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl         — 7 curated preset invocations
  config.json              — App defaults
  LISTENING_GUIDE.md         — Recommended listening sequence
  src/
    model.wl                  — BE/FD/MB occupation numbers (with domain
                            guards), four correctness checks, three
                            per-mode model builders
    sonify.wl                   — spectrum/temperature's three-voice
                            additive-spectral technique (thermo/'s
                            SynthesizeAdditiveFrame, reused), fermi_sea's
                            per-T-frame concatenation (thermo/distribution's
                            idiom, reused)
    speech.wl                     — Spoken intro synthesis and per-mode intro text
    animate.wl                      — log10(n) vs energy/temperature curves,
                            Fermi-Dirac step animation
    output.wl                       — CSV export and console summaries
  tests/
    test_model.wl                  — Unit tests
  output/                            — Output files (not committed)
  README.md
  AGENTS.md
```

## Connection to `thermo/` and `quantum/`

`thermo/`'s Maxwell-Boltzmann speed distribution `f(v)` and this app's
`n_MB(eps)` are not the same formula by accident — they describe the
same classical Boltzmann-factor physics from two different angles
(speed-space density vs. per-state occupation number), and `n_MB` is
literally what both `n_BE` and `n_FD` reduce to in the dilute limit,
the exact sense in which this app completes `thermo/`'s classical
picture rather than replacing it. The connection to
[`quantum/`](../quantum/README.md) is structural: `quantum/box`'s
discrete energy levels are exactly the kind of single-particle states
these occupation numbers describe filling — this app asks "how many
particles sit in a state of energy `eps`," a question `quantum/`'s own
discrete spectrum makes concrete.

## Console output

Step numbers `[1/5]` through `[5/5]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements in
addition to the intro:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

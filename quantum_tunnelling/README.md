# Quantum Tunnelling

Sonifies quantum tunnelling: a particle crossing a potential barrier it
classically has zero chance of crossing. Real-world consequences: alpha
decay (Gamow, 1928 — the first application of quantum mechanics to
nuclear physics), the scanning tunnelling microscope (Binnig & Rohrer,
1981, Nobel Prize 1986), and the tunnel diode.

**New to this app?** Start with
[`quantum_tunnelling/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — the
recommended four-step listening sequence across all three modes.

## The physics

### Exact transmission coefficient

A particle of energy `E` approaches a rectangular barrier of height
`V0` and width `L`. Both regimes below are derivable from the same
underlying formula — the tunnelling case is the analytic continuation
of the above-barrier case under `kappa <-> i*k`:

| Regime | Formula |
|---|---|
| `E < V0` (tunnelling) | `T = 1 / (1 + V0^2*Sinh[kappa*L]^2 / (4*E*(V0-E)))`, `kappa = Sqrt[2*mc2*(V0-E)]/hbarc` |
| `E > V0` (above-barrier) | `T = 1 / (1 + V0^2*Sin[k*L]^2 / (4*E*(E-V0)))`, `k = Sqrt[2*mc2*(E-V0)]/hbarc` |

`R = 1 - T` always (probability conservation). Units: energy in eV,
length in nm, `hbarc = 197.3269804 eV*nm`.

### The classically forbidden case

Classically, a particle with `E < V0` is reflected with certainty —
it simply cannot be found on the far side. Quantum mechanically, `T`
is always strictly positive: there is always some chance of finding
the particle beyond the barrier. `T` falls off *exponentially* with
barrier width (`sweep` mode), which is why tunnelling is either
completely negligible or dramatically important depending on scale —
there is very little in between.

### The classically allowed case, and a genuinely surprising resonance

For `E > V0`, classical mechanics says the particle always crosses.
Quantum mechanics predicts partial reflection *and* something classical
intuition does not anticipate at all: **perfect-transmission
resonances**. Whenever `k*L = n*Pi` for integer `n`, `T = 1` exactly —
the barrier is completely transparent despite being taller than the
particle's energy would classically require crossing at all. This is
the *same* standing-wave condition that quantizes a particle-in-a-box
(`quantum/`'s `BoxModel`: `E_n = n^2*Pi^2/(2*L^2)` in that app's natural
units) — a wave fitting a whole number of half-wavelengths across a
fixed length interferes constructively with itself either way. See
`energy` mode below, and the `LISTENING_GUIDE.md` for the fuller
cross-reference.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically
- Optional for the spoken intro: macOS `say` (built in), Linux
  `espeak-ng`/`espeak`, or Windows PowerShell (built in) — falls back
  to text-only output if none is available

## Quick start

```sh
# Barrier mode (default): round textbook numbers, T comfortably audible
wolframscript -file main.wl

# Scanning tunnelling microscope scale — small but clearly nonzero T
wolframscript -file main.wl -- --simulation.quantum_tunnelling.preset=stm

# Alpha decay scale — illustrative only, extremely small but nonzero T
wolframscript -file main.wl -- --simulation.quantum_tunnelling.preset=alpha_decay

# Manual configuration (bypasses the named presets)
wolframscript -file main.wl -- --simulation.quantum_tunnelling.preset=manual \
                                --simulation.quantum_tunnelling.energy_ev=1.5

# Barrier-width sweep (tunnelling regime only)
wolframscript -file main.wl -- --simulation.mode=sweep

# Incident-energy sweep, crossing V0 into the resonance regime
wolframscript -file main.wl -- --simulation.mode=energy

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Modes

### barrier (default)

A single tunnelling event, narrated as a short sequence: an incoming
tone, a marker click at the barrier, then a reflected tone (panned
hard left, "bounced back") and a transmitted tone (panned hard right,
"passed through") sounding *simultaneously* — both genuinely happen in
the same measurement statistics, not a coin flip on any one run. Each
tone's loudness follows `Sqrt[R]`/`Sqrt[T]` (amplitude, not raw
probability, governs perceived loudness), at the *same* pitch as the
incoming tone, since reflection and transmission do not change the
particle's energy.

Three named presets (`--simulation.quantum_tunnelling.preset`):

| Preset | E | V0 | L | Mass | T |
|---|---|---|---|---|---|
| `default` | 1 eV | 2 eV | 0.5 nm | electron | ~2.35% |
| `stm` | 0.1 eV | 4.5 eV | 0.5 nm | electron | ~7.5×10⁻⁶ |
| `alpha_decay` | 5 MeV | 30 MeV | 5×10⁻⁶ nm | alpha particle | ~7×10⁻¹⁰ |

Setting `preset=manual` (or any unrecognised value) uses
`energy_ev`/`barrier_height_ev`/`barrier_width_nm`/`mass_ev` directly
instead of a named preset.

**A caveat on `alpha_decay`:** this preset is **illustrative, not
quantitative**. This app's rectangular barrier is a simplification of
the real Coulomb barrier Gamow actually solved (which falls off with
distance — not rectangular at all). The preset does not reproduce any
real nucleus's half-life; its only honest claim is *why* alpha decay
is so improbable per attempt — a genuinely tiny but nonzero
probability, repeated an astronomical number of times per second (see
`LISTENING_GUIDE.md`).

**Best for:** the clearest single demonstration that a classically
impossible crossing has a real, nonzero, audible probability.

### sweep

Sweeps barrier width `L` continuously (fixed `E < V0`, tunnelling
regime only) and sonifies `T(L)` as a single tone whose volume fades
toward silence as `L` grows. `T` falls off doubly-exponentially in
effect (`T ~ Exp[-2*kappa*L]` for thick barriers), so loudness is
log-compressed — the same technique `blackbody/`'s `temperature` mode
uses for its Stefan-Boltzmann loudness, for the identical reason: an
exponentially collapsing quantity needs log compression to stay
audible (not just quiet, but *gradually* fading) across a whole sweep.

**Best for:** hearing tunnelling's exponential sensitivity to barrier
thickness directly — the same sensitivity that lets a scanning
tunnelling microscope resolve individual atoms.

### energy

Sweeps particle energy `E` continuously across `V0` (fixed barrier) and
sonifies `T(E)`. Below `V0`: rising volume as tunnelling becomes easier
approaching the barrier top. `E = V0` is marked with a distinct accent
tone — the one physically meaningful threshold in this sweep, playing
the same structural role `blackbody/`'s visible-band taps and
`compton/`'s 511 keV marker each play. Above `V0`: transmission
genuinely **oscillates** — this is not smoothed away, it is the whole
point — with perfect-transmission resonances (`T=1` exactly) the
loudest moments in that region.

**Best for:** hearing the resonance phenomenon itself — a physically
real, often underappreciated fact that a barrier can be perfectly
transparent at specific energies despite classically requiring more
energy to cross at all.

## Sonification mapping

| Quantity | Encoding |
|---|---|
| Particle energy `E` | `barrier` mode: log-log mapped onto `[audio_freq_min, audio_freq_max]` across a fixed wide eV-to-MeV reference domain (spans every preset's scale); `sweep`/`energy` modes: linearly mapped onto the same audio range across that mode's own configured sweep bounds |
| Transmission `T` | Loudness. `barrier`: `Sqrt[T]`/`Sqrt[R]` per outcome. `sweep`: `Log[T]` normalised between the sweep's own endpoints (log-compressed, since `T` decays exponentially). `energy`: plain `Sqrt[T]` (stays order-1 through the resonance region, no extra compression needed) |
| `E = V0` (barrier threshold) | Accent tone (`energy` mode only) |
| Reflected vs. transmitted | Stereo pan: reflected hard left, transmitted hard right (`barrier` mode) |

## Correctness checks

All four checks are properties of the transmission formula itself, so
all four run on every invocation, diagnostic-only (print
`[PASS]`/`[FAIL]`, never abort — see `AGENTS.md` for the precise
reasoning, not a blanket "no app aborts" claim):

1. **L → 0 limit** — `T → 1` for both regimes at a very small nonzero `L`.
2. **Deep-tunnelling asymptotic** — exact `T` matches the standard
   approximation `16*(E/V0)*(1-E/V0)*Exp[-2*kappa*L]` for `kappa*L >> 1`.
3. **Resonance condition** — the single most important check: solves
   for the barrier width satisfying `k*L = Pi` at a test `E > V0`, then
   verifies `T = 1` there exactly. The one check that specifically
   exercises the `E > V0` branch.
4. **Probability conservation** — `T + R = 1` to machine precision, at
   several `(E, V0, L)` points spanning both regimes.

## Outputs

| File | Description |
|------|-------------|
| `output/barrier_audio.wav` | Narrated single-event sequence |
| `output/barrier.gif` | Animated diagram: incoming particle, barrier, reflected + transmitted outcomes |
| `output/barrier.png` | Static version of the same diagram |
| `output/barrier_data.csv` | Preset, E, V0, L, mass, T, R, regime |
| `output/sweep_audio.wav` | Continuous barrier-width-sweep fade |
| `output/sweep.gif` | Animated `T` vs `L` curve (log-y), moving marker |
| `output/sweep.png` | Static version of the same curve |
| `output/sweep_data.csv` | Per-step: width, T, R |
| `output/energy_audio.wav` | Continuous energy sweep, `E=V0` accent, resonance wobble |
| `output/energy.gif` | Animated `T` vs `E` curve spanning both regimes, `E=V0` marked |
| `output/energy.png` | Static version of the same curve |
| `output/energy_data.csv` | Per-step: energy, T, R, regime |

## Configuration parameters (`quantum_tunnelling/config.json`)

| Key | Default | Used by |
|-----|---------|---------|
| `simulation.mode` | `"barrier"` | all |
| `simulation.quantum_tunnelling.preset` | `"default"` | barrier (`default`, `stm`, `alpha_decay`, or `manual`) |
| `simulation.quantum_tunnelling.energy_ev` | `1.0` | barrier (`preset=manual`), sweep, energy (fixed V0's companion E for sweep) |
| `simulation.quantum_tunnelling.barrier_height_ev` | `2.0` | barrier (`preset=manual`), sweep, energy |
| `simulation.quantum_tunnelling.barrier_width_nm` | `0.5` | barrier (`preset=manual`), energy |
| `simulation.quantum_tunnelling.mass_ev` | `510998.95` (electron) | barrier (`preset=manual`), sweep, energy |
| `simulation.quantum_tunnelling.width_min_nm` / `width_max_nm` | `0.1` / `3.0` | sweep |
| `simulation.quantum_tunnelling.energy_min_ev` / `energy_max_ev` | `0.1` / `6.0` | energy |
| `simulation.quantum_tunnelling.n_steps` | `100` | sweep, energy |
| `simulation.quantum_tunnelling.audio_freq_min` / `audio_freq_max` | `150` / `2500` | all (Hz) |
| `simulation.quantum_tunnelling.sweep_duration` | `6.0` | sweep (seconds) |
| `simulation.quantum_tunnelling.energy_duration` | `8.0` | energy (seconds) |

## Project structure

```
quantum_tunnelling/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl        — 7 curated preset invocations
  config.json            — App defaults
  LISTENING_GUIDE.md      — Recommended listening sequence
  src/
    model.wl              — TransmissionCoefficient (both regimes + E=V0 limit),
                            KOrKappaPerNm, correctness checks 1-4, named presets,
                            per-mode model builders, TunnellingPitchHz
    sonify.wl               — Discrete-event synthesis (barrier), continuous
                            phase-accumulation glissando (sweep/energy)
    speech.wl                — Spoken intro/outro synthesis and per-mode intro text
    animate.wl                 — Per-mode GIF/PNG renderers
    output.wl                    — CSV export and console summaries
  tests/
    test_model.wl              — Unit tests
  output/                       — Output files (not committed)
  README.md
  AGENTS.md
```

## Connection to `quantum/` and `hydrogen/`

`quantum/`'s `BoxModel` and this app's `energy`-mode resonance condition
are the *same physics* — see "The physics" above. `hydrogen/` shares
this app's general "exactly-solvable, closed-form quantum mechanics"
domain, though its wave functions are 3D and orbital rather than a 1D
scattering problem. `compton/` shares this app's discrete-narrated-event
sonification idiom (`barrier` mode directly reuses `compton/scatter`'s
structure) and its diagnostic-only correctness-check convention.

## Console output

Step numbers `[1/4]` through `[4/4]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements in
addition to the intro:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

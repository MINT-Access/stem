# Compton — Compton Scattering

Sonifies Compton scattering: a photon scattering off a free electron,
losing energy and shifting to a longer wavelength — the 1923
measurement (Arthur Compton, Nobel Prize 1927) that settled the
wave/particle debate in favour of the photon picture. Only a particle
carrying discrete momentum can lose energy to a recoiling electron the
way Compton's data showed; a wave alone cannot.

**New to this app?** Start with
[`compton/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — the recommended
five-step listening sequence across all four modes.

## The physics

### Compton's formula

    Delta_lambda = lambda' - lambda = lambda_C * (1 - cos theta)

where `lambda` is the incident photon wavelength, `lambda'` the
scattered photon wavelength, `theta` the scattering angle, and
`lambda_C = h/(m_e c) ≈ 2.42631 pm` the **Compton wavelength** of the
electron. In energy form (`E = hc/lambda`):

    E' = E / (1 + (E / m_e c^2)(1 - cos theta))

with `m_e c^2 ≈ 510.999 keV` the electron rest energy. The recoiling
electron's kinetic energy is exactly `T = E - E'` (energy conservation).

### Two limits

| Regime | Result | Meaning |
|---|---|---|
| `theta -> 0` (forward) | `Delta_lambda -> 0` | Undeflected photon: no shift at all |
| `theta -> pi` (backscatter) | `Delta_lambda -> 2*lambda_C` | The maximum possible shift, for any wavelength |
| `E << m_e c^2` (Thomson limit) | `E'/E -> 1` | Classical, elastic, wavelength-independent scattering |

The Thomson limit is why Compton scattering is invisible for visible
light (a few eV, five orders of magnitude below `m_e c^2`) and only
becomes dramatic for X-rays and gamma rays. It is also, historically, a
second appearance of **J.J. Thomson** in this codebase — the same
physicist whose "plum pudding" atomic model `scattering/` shows to be
wrong about where an atom's charge lives, appearing here instead as the
*correct* classical limit of the theory that helped supersede his own.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically
- Optional for the spoken intro: macOS `say` (built in), Linux
  `espeak-ng`/`espeak`, or Windows PowerShell (built in) — falls back
  to text-only output if none is available

## Quick start

```sh
# Scatter mode (default): Compton's own 1923 values, 71pm at 90 degrees
wolframscript -file main.wl

# A different angle or wavelength
wolframscript -file main.wl -- --simulation.compton.angle_deg=180
wolframscript -file main.wl -- --simulation.compton.wavelength_pm=10

# Sweep mode: continuous angle glissando, 0-180 degrees
wolframscript -file main.wl -- --simulation.mode=sweep

# Energy mode: incident-energy sweep, 1 keV to 5 MeV
wolframscript -file main.wl -- --simulation.mode=energy

# Discovery mode: Thomson vs Compton, binaural
wolframscript -file main.wl -- --simulation.mode=discovery

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Modes

### scatter (default)

A single scattering event at a configured incident wavelength and
angle (default: **Compton's actual 1923 values** — 71.0 pm molybdenum
X-rays, 90 degrees — the same historical-parameter convention
`relativity/`'s GW150914 preset and `scattering/`'s Geiger-Marsden
angles follow). Plays as a short narrated sequence: incoming photon,
collision click, outgoing photon (panned by scattering angle) together
with a soft low thud for the recoil electron (panned to the *opposite*
side, by momentum conservation).

**Best for:** the clearest single demonstration that a scattered photon
measurably loses energy.

### sweep

Sweeps scattering angle continuously from `angle_min` to `angle_max`
(default 0-180 degrees) at a fixed incident wavelength, rendered as a
genuine glissando (continuous phase accumulation, the same technique
`relativity/`'s chirp uses for its own frequency sweep) rather than
discrete steps. Since `d(1-cos theta)/d theta = sin theta` peaks at
`theta=90 deg`, the pitch descends *fastest* through the middle of the
sweep and *slowest* near the two ends — audible directly, the same way
`relativity/`'s chirp *is* its own governing formula rather than a
representation of it.

**Best for:** hearing Compton's formula as a single continuous sound.

### energy

Sweeps incident photon energy logarithmically (default 1 keV to 5 MeV,
spanning both sides of `m_e c^2 ≈ 511 keV`) at a fixed angle (default 90
degrees). At each step, the incoming and outgoing pitches play together
— near-unison at low energy (the Thomson limit), clearly split at high
energy (deep Compton regime). An accent tone marks the step nearest 511
keV, the one physically meaningful reference scale in this sweep.

**Best for:** hearing *why* Compton scattering is a quantum-relativistic
effect — invisible at optical-photon energies, unmissable at gamma-ray
energies.

### discovery

Binaural historical comparison, mirroring `scattering/`'s `discovery`
mode structure (though not its literal implementation — see
`AGENTS.md`). **Left channel**: the classical Thomson prediction —
outgoing pitch equals incoming pitch at every angle, flat, because
classical electromagnetism predicts purely elastic scattering. **Right
channel**: the real Compton prediction — outgoing pitch measurably
drops as angle increases. The two channels are identical at `theta=0`
and diverge increasingly toward `theta=180`, the same gap Compton's
1923 measurement revealed.

**Best for:** outreach — the same "here is the actual historical
disagreement, made audible" structure that makes `scattering/discovery`
compelling, applied to a second decisive experiment.

## Sonification mapping

| Quantity | Encoding |
|---|---|
| Photon energy (incident or scattered) | Mapped log-log onto `[audio_freq_min, audio_freq_max]` (default 200-3000 Hz), using the SAME `[energy_min_kev, energy_max_kev]` domain in all four modes |
| Scattering angle | Stereo pan, linear: `theta=0` hard left, `theta=180` hard right (`scatter`/`sweep`); constant vs swept pitch (`discovery`) |
| Recoil electron kinetic energy | Low "thud" pitch/amplitude (`scatter` only), panned opposite the scattered photon |
| 511 keV (electron rest energy) | Accent tone (`energy` mode), the same structural role blackbody's visible-band taps play |

## Correctness checks

All four checks are properties of the Compton formula itself, so all
four run on every invocation, diagnostic-only (print `[PASS]`/`[FAIL]`,
never abort — see `AGENTS.md` for why):

1. **Forward-scattering limit** — `Delta_lambda -> 0` as `theta -> 0`.
2. **Backscatter limit** — `Delta_lambda -> 2*lambda_C` at `theta=180 deg`.
3. **Thomson (low-energy) limit** — `E'/E -> 1` as `E/(m_e c^2) -> 0`.
4. **Energy-momentum conservation** — the recoil electron's momentum,
   computed two independent ways (via `T=E-E'` and via direct 2D vector
   conservation), agree within 0.01%.

## Outputs

| File | Description |
|------|-------------|
| `output/scatter_audio.wav` | Narrated single-event sequence |
| `output/scatter.gif` | Animated collision diagram (incoming/outgoing photon + recoil electron) |
| `output/scatter.png` | Static version of the same diagram |
| `output/scatter_data.csv` | Incident/scattered wavelength & energy, angle, recoil energy |
| `output/sweep_audio.wav` | Continuous angle-sweep glissando |
| `output/sweep.gif` | Animated `Delta_lambda` vs `theta` curve with a moving marker |
| `output/sweep.png` | Static version of the same curve |
| `output/sweep_data.csv` | Per-step: angle, `Delta_lambda`, outgoing energy, pan |
| `output/energy_audio.wav` | Incident-energy sweep, dyad chords, 511 keV accent |
| `output/energy.gif` | Animated fractional-energy-loss vs incident-energy curve |
| `output/energy.png` | Static version of the same curve |
| `output/energy_data.csv` | Per-step: incident/outgoing energy, fractional shift |
| `output/discovery_audio.wav` | Binaural Thomson (left) vs Compton (right) |
| `output/discovery.png` | Overlaid classical-flat and Compton-curved predictions vs angle |
| `output/discovery_data.csv` | Per-step: angle, Thomson wavelength, Compton wavelength |

## Configuration parameters (`compton/config.json`)

| Key | Default | Used by |
|-----|---------|---------|
| `simulation.mode` | `"scatter"` | all |
| `simulation.compton.wavelength_pm` | `71.0` | scatter, sweep, discovery |
| `simulation.compton.angle_deg` | `90` | scatter, energy |
| `simulation.compton.angle_min` / `angle_max` | `0` / `180` | sweep, discovery |
| `simulation.compton.energy_min_kev` / `energy_max_kev` | `1` / `5000` | energy (also the shared pitch-mapping domain for all modes) |
| `simulation.compton.n_steps` | `100` | sweep, energy, discovery |
| `simulation.compton.audio_freq_min` / `audio_freq_max` | `200` / `3000` | all (Hz) |
| `simulation.compton.frame_duration` | `0.1` | energy (seconds per dyad frame) |
| `simulation.compton.sweep_duration` | `6.0` | sweep (seconds) |
| `simulation.compton.discovery_duration` | `8.0` | discovery (seconds) |

## Project structure

```
compton/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl        — 6 curated preset invocations
  config.json            — App defaults
  LISTENING_GUIDE.md      — Recommended listening sequence
  src/
    model.wl              — Compton's formula (energy/wavelength forms), correctness
                            checks 1-4, per-mode model builders, PhotonPitchHz/ComptonPan
    sonify.wl               — Discrete-event synthesis (scatter), continuous
                            phase-accumulation glissando (sweep/discovery), per-step
                            dyad frames (energy)
    speech.wl                — Spoken intro/outro synthesis and per-mode intro text
    animate.wl                 — Per-mode GIF/PNG renderers
    output.wl                   — CSV export and console summaries
  tests/
    test_model.wl              — Unit tests
  output/                       — Output files (not committed)
  README.md
  AGENTS.md
```

## Connection to `scattering/` and `hydrogen/`

`compton/` reuses `scattering/`'s **architectural** idea of a binaural
classical-vs-quantum comparison mode (`discovery`), not its physics:
Compton scattering is a discrete quantum event with an independent
scattering angle, not a trajectory integrated from an impact parameter
the way Rutherford scattering is — see `AGENTS.md` design decision 1 for
why the two apps' "same geometry" connection, as sometimes described, is
not quite physically accurate. `hydrogen/` shares this app's photon
energy ↔ pitch domain directly; both apps work in the regime where a
photon's energy is the primary physical quantity being sonified.

## Console output

Step numbers `[1/4]` through `[4/4]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements in
addition to the intro:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

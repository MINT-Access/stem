# Relativity

A Wolfram Language simulation of gravitational wave emission from a binary
inspiral, runnable entirely from the terminal via `wolframscript`. The strain
h(t) predicted by the post-Newtonian approximation is literally an audio
waveform — time-stretched to make it clearly audible, then exported as a WAV
file you can play with `afplay`. Three preset comparison WAVs (GW150914,
GW170817, stellar-mass) are produced automatically on every run.

## The physics

When two massive bodies orbit each other they lose energy by radiating
gravitational waves. As energy is lost the orbit shrinks, the orbital
frequency rises, and the wave amplitude grows. This continues until the bodies
merge — the resulting signal is a *chirp*: a rising frequency sweep that ends
abruptly at merger. This is what LIGO detected on 14 September 2015.

The simulation uses the **post-Newtonian (PN) approximation**, which gives an
analytic closed-form expression valid during the long inspiral phase. The key
quantity is the *chirp mass*:

    ℳ = (m₁ m₂)^(3/5) / (m₁ + m₂)^(1/5)

which is the single combination of the two masses that dominates the waveform.
The gravitational wave frequency evolves as:

    f(t) = (1/π) · (5/256)^(3/8) · ℳ_sec^(−5/8) · (t_c − t)^(−3/8)

where t_c is the coalescence (merger) time and ℳ_sec = G ℳ M☉ / c³ is the
chirp mass converted to seconds. The strain (what LIGO measures) is:

    h(t) = A(t) · cos(2π φ(t))

with φ(t) = ∫ f(t) dt accumulated by cumulative summation, and the amplitude:

    A(t) = (4/D) · (ℳ_sec · c) · (π ℳ_sec f(t))^(2/3)

where D is the luminosity distance to the source. After merger the remnant
black hole rings at its quasi-normal mode frequency (Echeverria 1989) and
damps exponentially — this is the ringdown.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`

## Usage

```bash
# Default — GW150914 parameters (36+29 M☉ at 410 Mpc)
wolframscript -file main.wl

# Use a named preset
wolframscript -file main.wl -- --simulation.chirp.preset gw170817
wolframscript -file main.wl -- --simulation.chirp.preset stellar

# Override individual parameters
wolframscript -file main.wl -- --simulation.chirp.mass1_solar 50
wolframscript -file main.wl -- --simulation.chirp.mass2_solar 50
wolframscript -file main.wl -- --simulation.chirp.distance_mpc 200

# Change audio time stretching
wolframscript -file main.wl -- --sonification.chirp.time_stretch 8

# Inspect merged configuration
wolframscript -file main.wl -- --config-dump

# Play the result (macOS)
afplay output/chirp.wav
afplay output/gw170817.wav
```

## Presets

| Preset | Masses | Distance | Event |
|--------|--------|----------|-------|
| `gw150914` | 36 + 29 M☉ | 410 Mpc | First LIGO detection, Sep 2015 |
| `gw170817` | 1.17 + 1.36 M☉ | 40 Mpc | Neutron star merger, Aug 2017 |
| `stellar` | 10 + 8 M☉ | 100 Mpc | Typical stellar-mass binary |

GW150914 sweeps 20 → 412 Hz over ~0.85 s of inspiral. GW170817 takes ~188 s
to sweep 20 → 500 Hz — a much longer chirp, because neutron star masses are far
smaller. For the comparison WAV, only the final 10 s before merger are used,
where the frequency sweep through the audio band is most dramatic.

## Outputs

| File | Description |
|------|-------------|
| `chirp.gif` | 60-frame animation revealing the waveform left-to-right; frequency dot tracks merger approach |
| `chirp.png` | Static two-panel: full strain waveform with merger marker + frequency evolution curve |
| `chirp.wav` | Main audio: h(t) time-stretched to be clearly audible, normalised to 0.9 peak |
| `chirp_timeseries.csv` | Every 10th sample: time_s, strain_h, frequency_hz, amplitude |
| `gw150914.wav` | GW150914 parameters at current time_stretch |
| `gw170817.wav` | GW170817 — final 10 s of neutron-star inspiral |
| `stellar.wav` | 10+8 M☉ stellar-mass binary |

## Listening guide

The audio is time-stretched (default 4×) so the chirp lasts long enough to
follow. Listen for:

- **Rising pitch** — frequency climbing from ~20 Hz as the orbit tightens
- **Growing volume** — amplitude increasing as the bodies spiral closer
- **Abrupt cutoff** — the merger: orbit collapses in an instant
- **Fading ringdown** — the merged remnant ringing at its QNM frequency
  (~194 Hz for GW150914), damping away in a few milliseconds

The three preset WAVs make the mass dependence audible. Higher mass → shorter
chirp duration at the same starting frequency, lower peak frequency. GW170817
(neutron stars, ~1.1 M☉ chirp mass) sweeps very slowly through the full audio
band; GW150914 (~28 M☉ chirp mass) is brief and punchy.

## Physical correctness checks

Four checks run automatically on every invocation and are printed to the console:

1. **Frequency at t = 0 ≈ f_min** — verifies the coalescence-time formula
2. **Frequency monotonically increasing** — verifies the PN frequency formula
3. **Amplitude monotonically increasing** — verifies the strain formula
4. **Strain DC offset ≈ 0** — verifies clean phase accumulation

If check 2 or 3 fails the run aborts rather than producing incorrect output.

## Project structure

    relativity/
    ├── main.wl              Entry point (preset resolution, 4-step pipeline)
    ├── config.json          App-level defaults (chirp sub-config, presets)
    ├── src/
    │   ├── model.wl         ChirpModel — PN waveform + ringdown
    │   ├── animate.wl       GIF + PNG visualisation (AnimateRelativity)
    │   └── sonify.wl        Audio export (ChirpToAudio, SonifyRelativity)
    ├── output/              Output files (not committed)
    ├── AGENTS.md            Guidance for Claude Code
    └── README.md

## Console output

Step numbers `[1/4]` through `[4/4]` mark each pipeline stage. Physical
correctness checks print `[PASS]` or `[FAIL]` with actual values. Export
confirmations use `STEMDescribeCSV`, `STEMDescribeWAV`, and `STEMDescribeGIF`.

To enable speech at each stage, set `STEM_SPEAK=1`:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

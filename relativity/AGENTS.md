# AGENTS.md — Guidance for Claude Code

## Project overview

General relativity simulation in Wolfram Language. Currently one mode — `chirp`
— which computes the gravitational wave strain from a binary inspiral using the
post-Newtonian (PN) approximation, exports an animated GIF revealing the waveform
left-to-right, a static two-panel PNG, a time-series CSV, and four WAV files.

**Key distinction from all other apps:** the WAV output IS the gravitational wave.
The strain h(t) is literally an audio waveform. There is no indirect sonification
mapping — `SonifyTrajectory` is not used here.

**SI units throughout the physics.** Constants G, c, M☉ are defined numerically.
Never work in natural units (G = c = 1) for this app — the amplitude formula
requires metric distance in metres.

## Project structure

- `main.wl`              — Entry point; preset resolution; 4-step pipeline
- `config.json`          — App defaults (chirp sub-config, presets, animation,
                           sonification)
- `src/model.wl`         — `ChirpModel[cfg]`
                           Returns:
                           `<| "time", "strain", "frequency", "amplitude",
                              "merger_index", "chirp_mass_solar",
                              "coalescence_time", "peak_frequency",
                              "sample_rate", "mode" |>`
- `src/animate.wl`       — `AnimateRelativity[model, cfg, outDir]`
                           Exports `chirp.gif` (60 frames) + `chirp.png`
- `src/sonify.wl`        — `ChirpToAudio[strain, srModel, srOut, timeStretch, freqShift]`,
                           `SonifyPreset[pm1, pm2, pDistMpc, cfg, wavPath]`,
                           `SonifyPreset[pm1, pm2, pDistMpc, cfg, wavPath, maxInspiral]`,
                           `SonifyRelativity[model, cfg, outDir]`
- `output/`              — All output files (not committed)

## How to run

```bash
wolframscript -file main.wl                                        # GW150914 defaults
wolframscript -file main.wl -- --simulation.mode chirp
wolframscript -file main.wl -- --simulation.chirp.preset gw170817
wolframscript -file main.wl -- --simulation.chirp.mass1_solar 50
wolframscript -file main.wl -- --sonification.chirp.time_stretch 8
wolframscript -file main.wl -- --config-dump
afplay output/chirp.wav
```

CLI override format: `--key=value` (with `=`). Space-separated `--key value`
is also accepted — main.wl pre-processes args before passing to `LoadConfig`.

## Data flow

```
config → ChirpModel
           ↓
         model {time[], strain[], frequency[], amplitude[],
                merger_index, chirp_mass_solar, coalescence_time,
                peak_frequency, sample_rate, mode}
           ↙              ↓              ↘
  AnimateRelativity     CSV           SonifyRelativity
  (chirp.gif,        (subsampled         ↓
   chirp.png)        10th rows)    ChirpToAudio × 4
                                  (chirp.wav + 3 preset WAVs)
```

## Model Association shape

| Key | Type | Description |
|-----|------|-------------|
| `"time"` | vector | Full time array (inspiral + ringdown), seconds |
| `"strain"` | vector | h(t) — raw gravitational wave strain (~10⁻²¹) |
| `"frequency"` | vector | f(t) — instantaneous GW frequency, Hz |
| `"amplitude"` | vector | A(t) — strain amplitude envelope |
| `"merger_index"` | Integer | Index of first ringdown sample in all arrays |
| `"chirp_mass_solar"` | Real | Chirp mass ℳ in solar masses |
| `"coalescence_time"` | Real | t_c in seconds (duration of inspiral) |
| `"peak_frequency"` | Real | Maximum frequency reached before clipping |
| `"sample_rate"` | Integer | Model sample rate (4096 Hz by default) |
| `"mode"` | String | `"chirp"` |

## Physics notes

### Post-Newtonian frequency evolution

The orbital frequency evolves as (Peters 1964):

    f(t) = (1/π) · (5/256)^(3/8) · ℳ_sec^(−5/8) · (t_c − t)^(−3/8)

where τ = t_c − t is time remaining to merger and:

    ℳ_sec = G · ℳ · M☉ / c³   (chirp mass in seconds)
    ℳ = μ^(3/5) · M^(2/5)     (chirp mass in solar masses)
    μ = m₁m₂/(m₁+m₂)

Coalescence time from starting frequency f_min:

    t_c = (5/256) · ℳ_sec^(−5/3) · (π f_min)^(−8/3)

Self-consistency check: substituting t_c back gives f(0) = f_min exactly.
The `[PASS] Frequency at t=0` check verifies this within 25%.

### Strain amplitude

    A(t) = (4/D) · (ℳ_sec · c) · (π · ℳ_sec · f(t))^(2/3)

where D is the luminosity distance in metres. Raw peak amplitude for GW150914
is ~10⁻²¹; normalised to 0.9 peak for audio.

### Ringdown

After merger the remnant black hole rings at its quasi-normal mode frequency
(Echeverria 1989; non-spinning a = 0 approximation):

    f_qnm = c³ / (2π G M_final) · (1 − 0.63)     (a = 0)
    M_final = 0.95 M   (5% of total mass radiated)

Damped with timescale τ_rd = 10 G M_final / c³.
For GW150914 (M = 65 M☉): f_qnm ≈ 194 Hz, τ_rd ≈ 3 ms.

### Physical correctness checks

Four checks printed at each run (abort on FAIL):
1. f(0) ≈ f_min within 25%  — verifies coalescence-time formula
2. f(t) monotonically non-decreasing to clipping point  — verifies PN formula sign
3. A(t) monotonically non-decreasing to clipping point  — verifies amplitude formula
4. Mean(h) ≈ 0  — verifies phase accumulation has no DC drift

Clipping point: index where f(t) first reaches `frequency_max_hz`. Monotonicity
is only checked up to this index because clipped f saturates (plateau is fine).

## Preset system

Defined in `config.json` under `simulation.chirp.presets`:
- `gw150914` — 36+29 M☉ at 410 Mpc (LIGO first detection)
- `gw170817` — 1.17+1.36 M☉ at 40 Mpc (neutron star merger)
- `stellar`  — 10+8 M☉ at 100 Mpc

Activated via `--simulation.chirp.preset <name>`. `main.wl` resolves the preset
by merging `presets[name].{mass1, mass2, distance_mpc}` into `cfg` under
`simulation.chirp.{mass1_solar, mass2_solar, distance_mpc}` before calling
`ChirpModel`. The preset does not override other parameters (time_stretch, etc.).

## Audio processing — `ChirpToAudio`

Converts strain array at `srModel` Hz to audio at `srOut` Hz with optional
time stretching and frequency shifting. Uses linear `Interpolation`.

- `timeStretch > 1` → longer duration (same pitch)
- `freqShift > 1` → higher pitch, shorter duration
- Net output duration = T_original × timeStretch / freqShift
- For output sample k: t_phys = k / srOut × freqShift / timeStretch

Normalises to peak 0.9 regardless of raw strain magnitude.

## GW170817 handling

Coalescence time from 20 Hz is ~188 s → 769,807 inspiral samples. The model
computes the full waveform. `SonifyPreset` for GW170817 passes `maxInspiral=10.0`
to truncate to the final 10 s before merger for the WAV output (where the
frequency sweep through the audio band is most dramatic: ~64 Hz → 500 Hz).

All four physical correctness checks still pass for GW170817's full model.

## Common pitfalls

- **Underscore in Module variable names.** `Module[{Mchirp_sec, ...}]` fails:
  WL parses `Mchirp_sec` as `Pattern[Mchirp, _sec]`, not a symbol. Use
  camelCase: `MchirpSec`. This was a bug in an earlier revision; keep it fixed.

- **Optional argument syntax with `?test`.** `f[x_?NumericQ : 0.0]` misparsed
  in some WL versions: the `:` binds to `NumericQ` (becomes `NumericQ:0.0` = a
  `RuleDelayed`), not to the argument slot. Define two DownValues instead —
  one without the optional arg (delegating to the other with the default value).

- **JSON integers vs. Wolfram reals.** `GetCfg` may return `4096` as Integer
  or `4096.` as Real depending on JSON parser. `ExportAudioBuffer` from
  synth.wl requires `sr_Integer`. Always `Round @ GetCfg[...]` on sample rates.

- **`FirstPosition` returns a list.** `FirstPosition[list, pat]` = `{k}` for a
  1D list. To extract the index use `pos[[1]]`, NOT `First[First[pos]]` (the
  inner `First[integer]` fails with `First::normal`).

- **`Min[Differences[arr]]` beats `And @@ Thread[arr >= val]` for large arrays.**
  For GW170817 with 769k samples, `Thread` over differences prints a flood of
  output. Use `Min[Differences[arr[[;;k]]]] >= -eps` directly.

- **`SonifyTrajectory` is NOT used here.** Do not apply the three-layer
  spatial/motion/event pipeline from sonification.wl to gravitational wave data.

## Output files

All chirp-mode outputs share the prefix `chirp`:

| File | Description |
|------|-------------|
| `chirp.gif` | 60-frame animation, waveform revealed + frequency dot |
| `chirp.png` | Static two-panel: full strain waveform + frequency sweep |
| `chirp.wav` | Main audio: time-stretched + normalised h(t) |
| `chirp_timeseries.csv` | Every 10th sample: time_s, strain_h, frequency_hz, amplitude |
| `gw150914.wav` | GW150914 preset at current time_stretch |
| `gw170817.wav` | GW170817 preset, last 10 s of inspiral |
| `stellar.wav` | Stellar preset (10+8 M☉) |

## Dependencies

- Mathematica or Wolfram Engine (any recent version)
- `stem-core` (sibling `../stem-core`) — `ExportAudioBuffer`, `NormalizeBuffer`,
  `ExportGIF`, `ExportCSV`, `EnsureDir`, `STEMHeading`, `STEMSection`,
  `STEMPrintN`, `STEMDescribeCSV`, `STEMDescribeWAV`, `STEMDescribeGIF`,
  `STEMSay`, `FmtN`, `GetCfg`, `DeepMerge`, `LoadConfig`
- No external paclets required

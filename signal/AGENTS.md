# AGENTS.md — Guidance for Claude Code

## Project overview

Signal processing demonstration in Wolfram Language. Three modes — chord,
sweep, AM — each generate a signal, corrupt it with Gaussian noise, recover it
via Fourier filtering, and export audio, visualisations, and a spoken narrative.

**Key distinction from all other apps:** the WAV files are not sonifications
of a simulation — they ARE the signal. Do not apply stem-core's
`SonifyTrajectory` / `SpatialLayer` / `MotionLayer` pipeline here.

## Project structure

- `main.wl`              — Entry point; mode branching; 5-step pipeline
- `config.json`          — App defaults (mode, all three mode sub-configs)
- `src/model.wl`         — `ChordModel`, `SweepModel`, `AMModel`
                           Each returns `<| "clean", "noisy", "sample_rate",
                           "duration", "frequencies", "amplitudes",
                           "noise_level", "mode" |>`
- `src/analyze.wl`       — `FourierAnalysis[signalAssoc, cfg]`,
                           `ComputeSNR[signal, reference]`,
                           `BuildFilterMask`, `FindSpectrumPeaks`
- `src/animate.wl`       — `AnimateSignal[analysis, cfg, outDir]`
                           Exports 3 PNGs + 1 GIF per run
- `src/sonify.wl`        — `SonifySignal[analysis, cfg, outDir]`,
                           `ExportMonoWAV`, `SpeakToBuffer`,
                           `CountCorrectPeaks`, `NarrativeText`
- `output/`              — All output files (not committed)

## How to run

```bash
wolframscript -file main.wl                              # chord (default)
wolframscript -file main.wl -- --simulation.mode=sweep
wolframscript -file main.wl -- --simulation.mode=am
wolframscript -file main.wl -- --config-dump
afplay output/chord_narrative_full.wav
```

CLI override format: `--key=value` (with `=`). Space-separated `--key value`
is also accepted — main.wl pre-processes args before passing to `LoadConfig`.

## Data flow

```
config → ChordModel/SweepModel/AMModel
           ↓
         signalAssoc {clean, noisy, ...}
           ↓
         FourierAnalysis → analysis {recovered, spectra, SNR, peaks, ...}
           ↙              ↘
  AnimateSignal        SonifySignal
  (PNG, GIF)           (WAV × 3, narrative_full.wav)
           ↓
         CSV (per-bin spectrum)
```

## Signal model return shape

All three model functions return an Association:
- `"clean"` / `"noisy"` — `List` of reals, length `Round[sr * duration]`
- `"frequencies"` — list of Hz values used for filter design
- `"mode"` — string tag propagated through the pipeline for output naming

## Fourier analysis notes

- WL `Fourier` convention: `(1/√N) Σ x[n] e^{−2πi k n/N}`.
  `InverseFourier[Fourier[x]] == x` exactly.
- One-sided spectrum uses bins `1..Floor[N/2]+1`, frequency step `sr/N` Hz.
- `BuildFilterMask` returns a length-`N` real mask (0.0/1.0), symmetric in
  positive/negative frequency so `Re[InverseFourier[spec * mask]]` is real.
- Filter modes:
  - `"chord"` — comb: ±10 Hz around each known frequency
  - `"sweep"` — bandpass: `start_hz` to `end_hz`
  - `"am"`    — bandpass: each sideband ±30 Hz

## Output naming convention

All output files are prefixed with `mode` (`"chord"`, `"sweep"`, `"am"`) so
multiple mode runs coexist in `output/` without overwriting each other.

## Common pitfalls

- Do NOT use `f |-> expr &` — this creates a double-nested function.
  Use `expr &` with `#` (Slot), or `Function[f, expr]`.
- `analysis["amplitudes"]` does NOT exist — amplitudes are in `signalAssoc`,
  not in the `FourierAnalysis` result. Access via `cfg` or `signalAssoc`.
- `SonifySignal` takes `outDir` (directory), not a file path.
  Filenames are constructed internally using `analysis["mode"]`.
- `SpeakToBuffer` calls macOS `say` and returns a PCM list. It degrades
  gracefully to 0.5 s of silence if `say` fails or AIFF import fails.

## Dependencies

- Mathematica or Wolfram Engine (any recent version)
- `stem-core` (sibling `../stem-core`) — `NormalizeBuffer`, `ExportAudioBuffer`,
  `EnsureDir`, `ExportGIF`, `ExportCSV`, `STEMSay`, `STEMDescribe*`, `GetCfg`,
  `DeepMerge`, `LoadConfig`
- No external paclets required

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
                           `SpeakToBufferPlatform`, `ResampleLinear`,
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
- `SpeakToBuffer` tries `SpeechSynthesize[]` first, then falls back to
  platform-native TTS (`SpeakToBufferPlatform`: macOS `say`, Linux
  `espeak-ng`/`espeak`, Windows PowerShell `SpeechSynthesizer`), then
  degrades to 0.5 s of silence if both tiers fail — the same three-tier
  pattern used by `images/`, `thermo/`, `montecarlo/`, `dynamical/`, and
  `magnetic/`. Prior to the v1.3.0 speech-consolidation pass this app
  called platform TTS directly with no `SpeechSynthesize[]` attempt;
  that was the one remaining inconsistency across the project's speech
  mechanisms. `ResampleLinear` (arbitrary-ratio linear interpolation)
  replaced an old hack that only handled exactly a 2x sample-rate ratio
  — `SpeechSynthesize[]` and the TTS engines can return audio at rates
  that aren't a clean fraction of the target (e.g. 22050 Hz vs 44100 Hz
  is fine, but not every engine uses that rate). A single
  `$SignalSpeechFailed` flag (reset per `SonifySignal` call) triggers
  one `[WARNING]` print if *any* narrative segment had to fall back to
  silence, rather than one warning per segment.

## Animation/audio sync: the GIF-duration bug (fixed post-v1.5.0)

**Special case for this app.** Unlike most apps in the suite (one WAV
paired with one GIF), `signal` exports FOUR WAVs per mode:
`{mode}_clean.wav`, `{mode}_noisy.wav`, `{mode}_recovered.wav` — all
three normalised stages of the raw signal, all exported at the same
duration (`analysis["duration"]`, i.e. `dur` from `config.json`) — plus
`{mode}_narrative_full.wav`, a completely different timeline: spoken
intro/transitions/summary interleaved with full replays of clean,
noisy, and recovered, measured at 36-39s vs. `dur`'s 3-4s (10-13x
longer). `main.wl`'s closing line even points the user at
`narrative_full.wav` as "the" audio to play. It would be easy to assume
that's the GIF's sync partner — it is not.

**Sync target: `dur` (== the clean/noisy/recovered WAV duration), not
narrative_full.wav.** `AnimateSignal`'s GIF is built from
`TimeDomainPanels` windows that slice `clean`/`noisy`/`recovered`
(length `sr*dur` each) into `nFrames` consecutive, non-overlapping
segments and sweep across them once, in order. That sweep is a direct
visualisation of the `dur`-second raw-signal timeline — it has no
correspondence to `narrative_full.wav`'s structure (speech segments,
pauses, three separate full-length replays). So `dur` — shared exactly
by `{mode}_clean/noisy/recovered.wav` — is the only timeline the GIF's
content actually depicts.

**The bug.** `AnimateSignal` (`src/animate.wl`) had `nFrames = 10`
hardcoded and read `animation.fps` from config (default 10) — giving a
GIF that always played for exactly 10/10 = 1.0s, regardless of `dur`.
Measured before the fix: `am`/`chord_animation.gif` at 1.0s vs. their
3.0s `_clean.wav` (0.33x — GIF finishes 3x too fast); `sweep` at 1.0s
vs. 4.0s (0.25x).

**The fix.** `animation.fps` is now clamped to `[$MinAnimationFps,
$MaxAnimationFps]` = `[2, 30]`, and the frame count is what scales with
duration to hit it exactly: `nFrames = Max[2, Round[fps * dur]]`. The
clamp exists so an extreme custom `duration` override can't demand a
strobing or glacial frame rate — the frame *count* absorbs the
scaling, not the rate. `windowSize = Floor[nSamples / nFrames]` and the
frame-building `Table` already looped generically over `nFrames`, so no
other changes were needed inside `AnimateSignal`; `main.wl`/
`experiments.wl` call sites are unchanged since duration is read
internally from `analysis["duration"]`, not passed in.

**Verified after regenerating all three presets** (`wolframscript
-file main.wl -- --simulation.mode={chord,am,sweep}`):

| mode  | GIF before | `_clean.wav` | ratio before | GIF after | ratio after |
|-------|-----------|--------------|---------------|-----------|--------------|
| chord | 1.0s (10f)| 3.0s         | 0.33x         | 3.0s (30f)| 1.00x        |
| am    | 1.0s (10f)| 3.0s         | 0.33x         | 3.0s (30f)| 1.00x        |
| sweep | 1.0s (10f)| 4.0s         | 0.25x         | 4.0s (40f)| 1.00x        |

`tests/test_model.wl` (13 assertions, model/analysis correctness only —
does not cover animation timing) still passes 13/0 after the fix.

## Dependencies

- Mathematica or Wolfram Engine (any recent version)
- `stem-core` (sibling `../stem-core`) — `NormalizeBuffer`, `ExportAudioBuffer`,
  `EnsureDir`, `ExportGIF`, `ExportCSV`, `STEMSay`, `STEMDescribe*`, `GetCfg`,
  `DeepMerge`, `LoadConfig`
- `SpeechSynthesize`, `AudioQ`, `AudioData`, `AudioSampleRate` (primary TTS
  tier), `RunProcess` (platform TTS fallback), `Import` (reading
  TTS-generated WAV files)
- No external paclets required

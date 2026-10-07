# stem-core — Agent & API Reference

stem-core is a shared Wolfram Language library for all thirty-two STEM
sonification projects in this repository (see the root `README.md` for the
full list). It consolidates shared helpers into eight modules loaded through a
single entry point.

---

## Loading conventions

Every project loads stem-core once, at the top of its `main.wl`, before `Get`-ing
any of its own source files:

```wolfram
$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
```

`init.wl` resolves its own location from `$InputFileName`, sets `$stemCoreRoot`,
sets `$CharacterEncoding = "UTF8"`, and loads the nine modules in dependency order:

```
utils.wl  →  scales.wl  →  synth.wl  →  export.wl  →  accessibility.wl
  →  speech.wl  →  hilbert.wl  →  config.wl  →  sonification.wl
```

`synth.wl` and `export.wl` both call `EnsureDir` from `utils.wl`;
`accessibility.wl` calls `FmtN`/`FmtDec` from `utils.wl`; `speech.wl` calls `STEMSay`
from `accessibility.wl` and `FmtDec`. `config.wl` calls `DeepMerge`
internally. Nothing requires a later module, so the order is fixed and must not
be changed.

---

## Module API

### utils.wl — Filesystem utilities

#### `EnsureDir[filePath_String]`
Creates the parent directory of `filePath` if it does not already exist.
Safe to call repeatedly. Called internally by `ExportCSV`, `ExportGIF`,
`ExportAudioBuffer`, and `LogError`.

```wolfram
EnsureDir["output/results.csv"]   (* creates "output/" if absent *)
```

#### `FmtN[x_?NumericQ, spec_:4]`
Formats `x` as a single-line string for use in `Print` statements.
`spec` is passed directly to `NumberForm`: use an integer for significant
figures or `{total, decimals}` for fixed decimal places.

Use this instead of `ToString[NumberForm[x, spec], OutputForm]` — in headless
`wolframscript`, `OutputForm` renders scientific notation as multi-line
superscripts; `FmtN` produces inline `*^` notation instead (e.g. `3.498*^-7`).

```wolfram
Print["Period: ", FmtN[2.0060666, 4], " s"]    (* → "Period: 2.006 s" *)
Print["Drift:  ", FmtN[3.498*^-7, 4], " J"]    (* → "Drift:  3.498*^-7 J" *)
Print["Dist:   ", FmtN[1.234567, {5,2}], " LD"] (* → "Dist:   1.23 LD" *)
```

#### `FmtDec[x_?NumericQ, maxDecimals_Integer:3]`
Formats `x` with at most `maxDecimals` decimal places and no trailing zeros
(`4.6078` → `"4.608"`, `0.22` → `"0.22"`, `2.` → `"2"`). Used for frame
rates, frame delays and durations in console lines.

#### `LogError[message_String, logPath_String]`
Appends a timestamped `[ERROR] YYYY-MM-DD HH:MM:SS <message>` line to `logPath`.
Creates the log directory if it does not exist. Opens the file in append mode so
existing entries are preserved.

```wolfram
LogError["API request failed", "output/errors.log"]
```

---

### accessibility.wl — Screen-reader-friendly output

All functions in this module print exactly one complete line to stdout so
VoiceOver reads each chunk as a self-contained announcement.

#### Numeric formatting

##### `STEMPrintN[label_String, x_?NumericQ]`
##### `STEMPrintN[label_String, x_?NumericQ, unit_String]`
##### `STEMPrintN[label_String, x_?NumericQ, unit_String, spec_]`
Prints `  label: value unit` as one line. `spec` is passed to `FmtN` (integer
for significant figures, `{total, decimals}` for fixed decimal places). The
two-argument form uses the `FmtN` default of 4 significant figures.

Use this in `PrintSummary` functions for any line that carries exactly one
numeric value with a label and optional unit. Leave bare `Print` for lines that
mix two values on one line (e.g. `[min, max]` ranges) or that use
`IntegerString` formatting rather than `FmtN`.

**pendulum/src/output.wl** — all six `PrintSummary` lines converted:

```wolfram
STEMPrintN["Steps computed",  Length[solution]]
STEMPrintN["Max angle",       maxAngle,                              "deg", 4]
STEMPrintN["Min angle",       minAngle,                              "deg", 4]
STEMPrintN["Initial energy",  First[energies],                       "J",   4]
STEMPrintN["Final energy",    Last[energies],                        "J",   4]
STEMPrintN["Energy drift",    Abs[Last[energies] - First[energies]], "J",   4]
```

**lorenz/src/output.wl** — step count only; x/y/z range lines carry two values
each and remain as bare `Print`:

```wolfram
STEMPrintN["Steps", Length[solution]]
(* ranges kept: Print["  x range: [", FmtN[Min[xs],4], ", ", FmtN[Max[xs],4], "]"] *)
```

**asteroids/src/output.wl** — count lines and velocity block converted; miss
distance lines mix km and LD on one line and remain as bare `Print`:

```wolfram
STEMPrintN["Total asteroids tracked", distStats["count"]]
STEMPrintN["Potentially hazardous",  Length[hazardous]]
STEMPrintN["Min velocity",  velStats["minKmS"],  "km/s", 4]
STEMPrintN["Max velocity",  velStats["maxKmS"],  "km/s", 4]
STEMPrintN["Mean velocity", velStats["meanKmS"], "km/s", 4]
```

#### Structured announcements

##### `STEMHeading[text_String]`
Prints `=== text ===`. Used for major section titles; matches the heading style
already present in each project's `main.wl`.

##### `STEMSection[title_String]`
Prints `-- title --`. Used for sub-section markers within a heading block.

##### `STEMBullet[text_String]`
Prints `  * text`. Uses ASCII `*` rather than a Unicode bullet because some
terminal configurations cause VoiceOver to skip non-ASCII punctuation.

#### Export metadata descriptions

##### `STEMDescribeCSV[filePath_String]`
##### `STEMDescribeCSV[filePath_String, nRows_Integer, nCols_Integer]`
Prints a single line confirming a CSV export. `nRows` excludes the header row.

```wolfram
STEMDescribeCSV["output/results.csv", 1001, 5]
(* →  "  CSV: 1001 rows, 5 columns — output/results.csv" *)
```

##### `STEMDescribeWAV[filePath_String]`
##### `STEMDescribeWAV[filePath_String, durationSec_?NumericQ]`
Prints a single line confirming a WAV export. Pass `durationSec` when the
simulation duration is known at the call site.

```wolfram
STEMDescribeWAV["output/audio.wav", 10.0]   (* →  "  Audio: 10.0 s — output/audio.wav" *)
```

##### `STEMDescribeGIF[filePath_String]`
##### `STEMDescribeGIF[filePath_String, nFrames_Integer, fps_?NumericQ]`
Prints a single line confirming a GIF export. `fps` is printed with at most
three decimals (`FmtDec`).

```wolfram
STEMDescribeGIF["output/anim.gif", 148, 4.5454545]
(* →  "  Animation: 148 frames at 4.545 fps — output/anim.gif" *)
```

##### `STEMLoudnessLine[wavPath_String, targetLUFS_?NumericQ]`
Measures the written WAV (`MeasureIntegratedLoudness`, EBU R128, and the
sample peak) and prints one sentence, the wording dynamical/ uses.
Returns `<|"lufs", "peakDB"|>`. Call it after the WAV is exported.

```wolfram
STEMLoudnessLine["output/lorenz_audio.wav", -17.0]
(* →  "  Loudness: the WAV was normalised to -17 LUFS and measures -17.02 LUFS
       integrated, with a peak of -3.1 dBFS." *)
```

##### `STEMTimingLine[t_Association]`
Prints the structure of a WAV in one sentence: spoken intro, pause, notes,
pause, spoken outro and total, every part stated even when it is zero.
Keys `"intro"`, `"introPause"`, `"notes"`, `"outroPause"`, `"outro"`
(seconds; missing keys count as 0). Returns the total.

```wolfram
STEMTimingLine[<|"notes" -> 20.0|>]
(* →  "  Timing: the WAV holds 0 s of spoken intro and a 0 s pause, then 20 s of
       notes from 0 s, then a 0 s pause and 0 s of spoken outro, 20 s in total." *)
```

#### Speech integration

##### `$STEMSpeakEnabled`
Boolean flag. Set by reading the `STEM_SPEAK` environment variable at load time:
`True` when `STEM_SPEAK=1`, `False` otherwise. The flag is always defined after
`init.wl` loads; it must not be set before or after loading — use the env var instead.

##### `STEMSay[text_String]`
Always prints `text`. When `$STEMSpeakEnabled` is `True`, also invokes
`say "text"` via `Run`. Double-quote characters in `text` are escaped before
shell hand-off.

```sh
STEM_SPEAK=1 wolframscript -file main.wl   # printed + spoken
```

---

### speech.wl — Narration rendered into audio

The one tiered text-to-speech path for every narrated app (it replaced 22
per-app copies). Apps never shell out to `say`/`espeak-ng`/PowerShell
themselves.

#### `STEMSpeakToBuffer[text_String, sampleRate_Integer]`
Returns mono PCM samples (a list of reals, not normalised) of `text` spoken at
`sampleRate`, or `{}` when no tier produced audio. Tiers:

1. `SpeechSynthesize[text]` (all platforms).
2. The platform tool, given the text through a temporary UTF-8 file (never a
   command-line argument, so non-ASCII text survives every console code page):
   macOS `say -f <txt> -o <aiff>` then `afconvert -d LEI16 -f WAVE`; Linux
   `espeak-ng -b 1 -f <txt> -w <wav>`, then `espeak` with the same flags;
   Windows `powershell` with `System.Speech`, the text read by
   `Get-Content -Raw -Encoding UTF8`.
3. Nothing: prints one warning sentence naming the app (`$projectRoot`'s
   directory), the tiers tried and why each failed, and the narration lost
   (words, and seconds at 175 words per minute); then `STEMSay[text]`; returns
   `{}`. Callers must build their WAV without the segment (most skip the
   intro and its pause; `signal` substitutes 0.5 s of silence).

The platform tier draws exactly one `RandomInteger[999999]` (temporary file
names), as the per-app copies did, so seeded runs keep their random streams.
Callers normalise the buffer (usually `NormalizeBuffer[buf, 0.95]`).

#### `STEMSpeechAvailable[]`
`True` when a tier can speak: the platform tool is on `PATH` (macOS also needs
`afconvert`), or else a cached one-word `SpeechSynthesize[]` probe returns audio.
`False` when `STEM_SPEECH_OFF=1`. Starts no process and draws no random numbers
when the tool is found.

#### `STEMResampleLinear[data_List, rawSr_, targetSr_]`
Linear-interpolation resampler, any ratio; returns `data` unchanged when the
rates differ by less than 1 Hz.

#### Test hooks
`$STEMSpeechUseSynthesize = False` skips tier 1; `$STEMSpeechTools` maps each
tool name (`"say"`, `"afconvert"`, `"espeak-ng"`, `"espeak"`, `"powershell"`)
to its executable, so pointing one at a missing path forces it unavailable
(`Block` both). `STEM_SPEECH_OFF=1` in the environment skips every tier, for an
end-to-end run of the no-speech path. See `tests/test_speech.wl`.

---

### scales.wl — Musical pitch mapping

#### `$StemSampleRate`
Integer constant `44100`. Standard CD sample rate used as the default throughout
the library. Pass explicitly to `StemSynthNote` / `ExportAudioBuffer` only when
you need a different rate.

#### `$StemScales`
Association mapping scale names to two-octave semitone-offset lists:

| Key | Intervals |
|---|---|
| `"MinorPentatonic"` | 0 3 5 7 10 12 15 17 19 22 |
| `"MajorPentatonic"` | 0 2 4 7 9 12 14 16 19 21 |
| `"Major"` | 0 2 4 5 7 9 11 12 14 16 |
| `"Minor"` | 0 2 3 5 7 8 10 12 14 15 |
| `"WholeTone"` | 0 2 4 6 8 10 12 14 16 18 |
| `"Phrygian"` | 0 1 3 5 7 8 10 12 13 15 |

Access with `$StemScales["Minor"]`. Pass the resulting list to `ScaleLookup`.

#### `SemitoneToHz[semitones_?NumericQ, rootHz_?NumericQ]`
Converts a semitone offset above `rootHz` to a frequency using equal temperament.

```wolfram
SemitoneToHz[12, 261.63]   (* one octave above middle C → 523.26 Hz *)
```

#### `ScaleLookup[value, lo, hi, scale, rootHz]`
Maps a scalar data value in `[lo, hi]` to a frequency from `scale`.

| Argument | Type | Description |
|---|---|---|
| `value` | `NumericQ` | Data value to sonify |
| `lo` | `NumericQ` | Minimum expected value → scale degree 1 |
| `hi` | `NumericQ` | Maximum expected value → scale degree n |
| `scale` | `List` | Semitone-offset list, e.g. `$StemScales["Minor"]` |
| `rootHz` | `NumericQ` | Frequency of scale degree 1 in Hz |

Uses `Rescale → Round → Clip` internally; values outside `[lo, hi]` clamp to the
nearest endpoint rather than erroring.

```wolfram
ScaleLookup[0.3, -1.0, 1.0, $StemScales["MinorPentatonic"], 220.0]
```

---

### synth.wl — PCM waveform synthesis

#### `StemSynthNote[freq, dur, vol, harmonics, decayFrac, sr]`

| Argument | Default | Description |
|---|---|---|
| `freq` | — | Frequency in Hz |
| `dur` | — | Duration in seconds |
| `vol` | — | Peak amplitude 0.0–1.0 |
| `harmonics` | `{1.0}` | Relative amplitudes of partials 1, 2, 3, … |
| `decayFrac` | `0.5` | Envelope time constant as fraction of `dur` |
| `sr` | `44100` | Sample rate in Hz |

Generates exponential-decay additive-sine PCM. Returns a `List` of real samples
in roughly `[-vol, vol]`. Partial amplitudes are normalised so the sum of
`Abs[harmonics]` never exceeds `vol`.

Common `harmonics` presets used by the projects:

```wolfram
{1.0}                           (* pure sine — pendulum *)
{1.0, 0.35, 0.12}               (* warm bell — lorenz *)
{1.0, 0.35, 0.10}               (* warm bell — safe asteroids *)
{1.0, 0.30, 0.20, 0.25, 0.15}  (* bright/harsh — hazardous asteroids *)
```

#### `NormalizeBuffer[buffer_List, ceiling_:0.95]`
Scales `buffer` so its peak absolute value does not exceed `ceiling`. Returns
the buffer unchanged if it is already within range. Apply after mixing multiple
notes before passing to `ExportAudioBuffer`.

```wolfram
audio = NormalizeBuffer[Total[notes]];
```

#### `MeasureIntegratedLoudness[channels_List, sr_]` / `MeasureIntegratedLoudness[audio_Audio]`
Integrated loudness in LUFS per ITU-R BS.1770-4, written out step by step
(it does not use `AudioLoudness`): K-weighting re-derived for the sample
rate (`KWeightingCoefficients`, reproduces the published 48 kHz coefficients
to 1e-12; `KWeight` applies the two biquads), complete 400 ms blocks every
100 ms from the first sample (`BlockMeanSquares`), channel weight 1 for L/R,
absolute gate -70 LUFS, relative gate -10 LU below the mean power of the
absolute-gated blocks. `channels` is `{left, right}` or one sample list.
Returns `-Infinity` for silence or audio shorter than 400 ms.

Verified against analytic signals in `tests/test_loudness.wl` (full-scale
997 Hz stereo = +0.0028 LUFS at 44.1 kHz, 0.0000 at 48 kHz; gated on/off and
two-level signals to 1e-4). The previous version used
`AudioLoudness["EBUMomentary"]`, which adds zero-padded partial blocks at
both ends and was unstable on sparse files (0.6-2.1 LU off on several);
see `VERIFICATION_loudness_limiter.md`. pyloudnorm reads about 0.045 LU
lower than this meter on everything (its K-weighting uses rounded
parameters: at 48 kHz it reads -0.041 for the 0.000 calibration sine), and
up to 1.2 LU higher on short files whose loudest part is in the last
400 ms, because it counts one extra, incomplete block.

#### `NormalizeToLoudness[buffer, targetLUFS_:-17.0, peakCeiling_:0.97, sr_:44100]`
Scales `buffer` (`{left, right}` or one list) to `targetLUFS` by the meter
above, then scales down if the peak would exceed `peakCeiling` (a backstop:
a signal with a large crest factor ends up below the target). Used at every
app's final export.

#### Peak limiter (opt-in): `audio.limiter`
An app enables it in its `config.json`; `RenderAudio` (the
`SonifyTrajectory` path) reads it, and apps that call `NormalizeToLoudness`
themselves can call `LimitedNormalizeToLoudness` with
`LimiterSettings[cfg]`.

```json
"audio": { "limiter": { "enabled": true, "modes": ["lorenz"],
                         "ceiling_dbfs": -1.0, "attack_ms": 5, "release_ms": 50 } }
```

- `enabled` (default `false`): off means the exact previous code path,
  so output is byte-identical (verified with a fixed random seed).
- `ceiling_dbfs` (-1.0), `attack_ms` (5), `release_ms` (50).
- `modes` (optional): the `simulation.mode` values it applies to; without it,
  every mode.

`LimiterSettings[cfg]` returns the settings or `None`.
`PeakLimit[channels, sr, ceilingDB, attackMs, releaseMs]` is a linked
stereo look-ahead limiter: required gain = min(1, ceiling / peak), held at
its minimum over the next attack window, averaged over the attack window
(so the gain is fully reduced when the peak arrives and the output never
exceeds the ceiling), then a one-pole release. Returns `<|"data", "gain",
"maxReductionDB"|>`. `LimitedNormalizeToLoudness[buffer, target, peakCeiling,
sr, settings]` scales to the target, limits, re-measures and corrects the
gain until the limited result is within 0.02 LU of the target (at most 12
passes), and records `$StemLastLimiter` (`ceilingDB`, `attackMs`,
`releaseMs`, `maxReductionDB`, `passes`, `lufs`, `gain`) for the app to
report. Limiting reduces the prominence of whatever sits on the loudest
peaks relative to the rest of the file (lorenz's loudest 880 Hz apex events:
8-10 dB), while their level relative to the sound around them is kept
(linked gain).

#### `ExportAudioBuffer[buffer_List, filePath_String, sr_Integer:44100]`
Wraps `buffer` in `Sound[SampledSoundList[buffer, sr]]` and writes a WAV file.
Returns `filePath`. Creates the output directory if necessary.

`SampledSoundList` is used deliberately instead of `Audio[]` because it works
correctly in headless `wolframscript` sessions on all supported platforms — see
the **VoiceOver / terminal context** section below.

```wolfram
ExportAudioBuffer[audio, "output/audio.wav"]
```

---

### export.wl — CSV and GIF export

#### `ExportCSV[rows_List, filePath_String]`
Writes a list of lists (first element is the header row) to a CSV file.
Creates the output directory if needed. Returns `filePath`.

```wolfram
ExportCSV[
  {{"time", "angle"}, {0.0, 0.4}, {0.01, 0.39}},
  "output/results.csv"
]
```

#### GIF/WAV timing — why there is a plan

GIF frame delays are stored as **whole centiseconds**. A requested rate such as
4.6078 fps (0.217 s) is written as 0.22 s, so a frame count derived from the
requested rate plays for longer or shorter than the audio: before this helper
existed the drift was 0.4–1.4 % (dynamical iterate: GIF 33.000 s vs WAV
32.553 s; lorenz: GIF 40.5 s vs WAV 40.0 s). Every app therefore chooses its
frame delay and frame count through `GIFFramePlan` and exports with
`ExportGIF[frames, path, plan]`, and its `main.wl` calls `SyncWAVToGIF` once
both files exist.

#### `GIFFramePlan[audioDuration, desiredFps, opts]`
Clamps `desiredFps` (`"MinFps"`/`"MaxFps"`, default 2–30), rounds the frame
delay to whole centiseconds, then derives the frame count as
`Round[audioDuration / delay]`, so the GIF plays within half a frame delay of
the audio. `"MinFrames"`/`"MaxFrames"` (default 2 / ∞) bound the count; when a
bound applies the delay is recomputed from the bounded count instead.
`"FrameCount" -> n` fixes the count (for frames set by the data at a fixed rate,
e.g. pendulum's 25 fps sampling). Returns
`<|"FrameCount", "DelayCentiseconds", "FrameDelay", "FrameRate", "GIFDuration",
"AudioDuration", "Difference"|>`. Round rates (2 fps, 10 fps, 25 fps) give the
same count and delay as `Round[fps * duration]` always did.

```wolfram
plan = GIFFramePlan[32.5533, 150 / 32.5533];
(* <|"FrameCount" -> 148, "DelayCentiseconds" -> 22, "GIFDuration" -> 32.56, ...|> *)
```

#### `ExportGIF[frames_List, filePath_String, plan_Association]`
#### `ExportGIF[frames_List, filePath_String, frameRate_:25]`
Exports a list of `Graphics` (or `GraphicsGrid`, or `Image`) objects as a
looping animated GIF. Creates the output directory if needed. Returns
`filePath`. `AnimationRepetitions -> Infinity` is always set.

The plan form writes every frame with the plan's whole-centisecond delay and
prints a warning line if the frame list's length differs from the plan's count.
The legacy numeric form rounds `1/frameRate` to whole centiseconds explicitly;
no app uses it any more.

#### `GIFFrameDelays[gifPath_String]`
The frame delays (seconds) stored in a GIF file, read from its Graphic Control
Extension blocks. Same values as `Import[gifPath, "DisplayDurations"]`, in
milliseconds rather than seconds for long GIFs.

#### `WAVDuration[wavPath_String]`
Duration of a PCM WAV file in seconds, read from its header.

#### `PadWAVWithSilence[wavPath_String, targetSeconds_?NumericQ]`
Appends silence so the file lasts `targetSeconds`; never trims. Returns the
seconds added.

#### `SyncWAVToGIF[gifPath, wavPath, opts]`
Call once both files are written. Measures both files; if the GIF plays longer
than the audio by more than one frame delay, pads the WAV with silence to the
GIF's duration (this project pads audio, never trims it); then prints one
sentence with the values actually written:

```
  GIF/WAV sync: the GIF has 148 frames of 0.22 s each and plays for 32.56 s, the WAV plays for 32.553 s, and the GIF is 0.007 s longer than the WAV.
```

`"IntroSeconds"`/`"OutroSeconds"` (default 0) are for the apps whose GIF is
deliberately timed to the sonified section between a spoken intro and outro
(`clt`, `quantum_tunnelling`, `resonance`, `scattering`); the comparison then
uses that section, and padding is skipped (with a warning line) when there is an
outro. Returns an Association of the measured values.

---

### hilbert.wl — Hilbert curve spatial traversal

#### `HilbertTraversalOrder[n_Integer]`
Returns the list of `{col, row}` pixel coordinates (1-based) visited by the
Hilbert curve for a `2^n × 2^n` grid, in traversal order — the standard
`d2xy` bijection, the same one `HilbertCurve[n, 2]` represents geometrically.
Result has `4^n` pairs, each component in `1..2^n`, covering every cell
exactly once.

Used to turn a 2D field (an image, a lattice snapshot, a sky map) into a
1D sequence for sonification while preserving spatial locality — nearby
cells in the grid end up nearby in the traversal, so nearby cells sound
close together in time. Used by `images/`, `mandelbrot/`, `montecarlo/`,
`cosmology/`, and `hydrogen/`.

```wolfram
order = HilbertTraversalOrder[6];   (* 64x64 grid, 4096 cells *)
values = grid[[#[[2]], #[[1]]]] & /@ order   (* sample the grid in traversal order *)
```

---

### config.wl — 4-layer configuration merge

All projects call `LoadConfig` at startup to produce a single merged
`Association` that subsequent code reads via `GetCfg`.

Merge order (each layer wins over the previous):

```
$HardcodedDefaults
  → config/config.json      (root-level shared overrides)
  → <app>/config.json       (app-specific defaults)
  → CLI --key=value args    (runtime overrides)
```

#### `$HardcodedDefaults`
Base Association with safe values for every known key. Apps that want a key
to exist regardless of whether their config.json is present rely on this layer.

#### `LoadConfig[appName_String, cliArgs_List]`
Performs the four-layer merge. `appName` is used to resolve
`<app>/config.json`. `cliArgs` is typically `Rest[$ScriptCommandLine]` (drop
the script path). If `"--config-dump"` is in `cliArgs`, prints the merged
config as a JSON string and exits.

```wolfram
cfg = LoadConfig["pendulum", Rest[$ScriptCommandLine]];
```

#### `DeepMerge[base_Association, override_Association]`
Recursively merges two Associations. Nested keys in `override` replace the
corresponding keys in `base`; keys absent from `override` are kept from
`base`. Use this in experiments.wl to apply a preset config on top of the
default config.

```wolfram
cfg = DeepMerge[cfg, <|"simulation" -> <|"mode" -> "double"|>|>];
```

#### `GetCfg[cfg_Association, keyPath_List, default_]`
Safe nested lookup. `keyPath` is a list of string keys. Returns `default` if
any key in the path is absent.

```wolfram
nSteps = GetCfg[cfg, {"simulation", "simple", "steps"}, 1000];
scale  = GetCfg[cfg, {"sonification", "scale"}, "MinorPentatonic"];
```

#### `ParseCliOverrides[args_List]`
Converts `--key=value` and `--section.key=value` strings into a nested
Association ready for `DeepMerge`. Value coercion:
- `"true"` / `"false"` → `True` / `False`
- numeric strings (including negative, e.g. `"-30"`) → number via `ToExpression`
- a JSON array, e.g. `["H","X"]` or `[1,0.0,0.0]` → a real WL `List`, via
  `ImportString[..., "RawJSON"]` (same syntax `config.json`'s own
  array-valued keys use, so a value overriding a list-valued key round-trips
  through the same syntax whether it's set in the file or on the CLI).
  Anything between `[` and `]` that isn't valid JSON falls back to a plain
  string rather than erroring.
- everything else → string

Bare flags without `=` (other than `--config-dump`) print a `[WARNING]` line
but are otherwise ignored; apps that recognise bare flags should strip them
from `cliArgs` before calling `LoadConfig`.

Shell quoting note: `[` and `]` are glob characters in most shells, so a
list-valued override needs quoting, e.g.
`--simulation.qubit.gate_sequence='["H","X"]'` (single quotes prevent the
shell from expanding or eating the brackets before Wolfram ever sees them).

```wolfram
(* --simulation.simple.angle_deg=-30  →  <|"simulation"→<|"simple"→<|"angle_deg"→-30|>|>|> *)
overrides = ParseCliOverrides[Rest[$ScriptCommandLine]];
```

---

### sonification.wl — Three-layer audio pipeline

Converts any numeric trajectory into a stereo WAV file through three
independent mixing layers. Apps that need standard behavior call
`SonifyTrajectory`; apps that need custom mixing (e.g. pendulum, which mixes
two bobs) call the individual layer functions directly.

**Trajectory format**: `n × 5` real matrix with columns
`{t, x, y, z, speed}`. `t` is time, `x` controls pan, `speed` controls pitch.
`y` and `z` are available to event detectors.

#### `SonifyTrajectory[traj, cfg, outPath, eventTypes]`
Single entry point. Runs `SpatialLayer`, `MotionLayer`, `EventLayer`, and
`MixLayers`, then calls `RenderAudio` to write the WAV.

| Argument | Type | Description |
|---|---|---|
| `traj` | `MatrixQ` | `n × 5` trajectory matrix |
| `cfg` | `Association` | Merged config (must contain `"sonification"` key) |
| `outPath` | `String` | Output file path, e.g. `"output/audio.wav"` |
| `eventTypes` | `List` | Which events to accent, e.g. `{"apex", "crossing"}` |

```wolfram
SonifyTrajectory[traj, cfg, FileNameJoin[{$outDir, "audio.wav"}], {"apex"}];
```

#### `SpatialLayer[traj, cfg]`
Maps the `x` column of `traj` to stereo pan. Returns
`<|"left" → buffer, "right" → buffer|>`.

#### `MotionLayer[traj, cfg]`
Maps the `speed` column to musical pitch via `ScaleLookup`. Returns
`<|"buffer" → samples|>`.

#### `EventLayer[traj, cfg, eventTypes]`
Detects labelled events in the trajectory (apex, zero-crossing, etc.) and
inserts brief accent tones. Returns `<|"buffer" → samples|>`. Recognised
event type strings: `"apex"`, `"crossing"`.

#### `MixLayers[spatial, motion, event, cfg]`
Combines the three layer outputs into a stereo matrix. Returns a
`2 × n_samples` matrix.

#### `RenderAudio[stereoData, cfg, outPath]`
Normalises `stereoData` and writes it as a WAV file via `ExportAudioBuffer`.
Returns `outPath`.

---

## VoiceOver / terminal context

All output is file-based (CSV, GIF, WAV). The library contains no calls to
`CreateDialog`, `NotebookOpen`, `SystemOpen`, `AudioPlay`, `Dynamic`, or any
other GUI primitive, so it runs correctly in fully headless environments.

**Audio**: `ExportAudioBuffer` uses `SampledSoundList` rather than `Audio[]`.
On macOS builds of `wolframscript`, `Audio[]` requires a display context and
silently produces a broken WAV in `--script` / non-interactive mode.
`SampledSoundList` inside a `Sound` object exports to WAV correctly regardless
of whether a display server is present.

**Accessibility**: the generated WAV files are plain PCM stereo/mono and play
correctly through VoiceOver-routed audio on macOS. No special AIFF or CoreAudio
metadata is embedded.

**Screen-reader output**: `accessibility.wl` provides `STEMHeading`, `STEMSection`,
`STEMBullet`, `STEMPrintN`, `STEMDescribeCSV`, `STEMDescribeWAV`, `STEMDescribeGIF`,
`STEMLoudnessLine`, `STEMTimingLine` and `STEMSay` — all guaranteed to emit exactly one complete stdout line, so
VoiceOver reads each item as a discrete unit. Set `STEM_SPEAK=1` in the shell
environment before running any project to also invoke `say` for `STEMSay` calls.
See `docs/voiceover-wolframscript-guide.md` for a full workflow walkthrough.

**Paths**: `EnsureDir` uses `CreateDirectory` (creates one level). If a project
nests outputs more than one directory deep below an existing root, each level
must exist or the project's `main.wl` must call `CreateDirectory` for the
intermediate levels before the first `Export*` call.

---

## Dependency graph

```
init.wl
 ├── utils.wl          (no deps)
 ├── scales.wl         (no deps)
 ├── synth.wl          ← utils.wl  (EnsureDir)
 ├── export.wl         ← utils.wl  (EnsureDir)
 ├── accessibility.wl  ← utils.wl  (FmtN)
 ├── speech.wl         ← accessibility.wl (STEMSay), utils.wl (FmtDec)
 ├── config.wl         ← (self-contained; calls DeepMerge internally)
 └── sonification.wl   ← scales.wl (ScaleLookup), synth.wl (ExportAudioBuffer)
```

Projects may call any public symbol after loading `init.wl`. They must not
`Get` individual `src/` files directly, as load order is not guaranteed.

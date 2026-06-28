# stem-core — Agent & API Reference

stem-core is a shared Wolfram Language library for all eight STEM sonification
projects: pendulum, lorenz, asteroids, cellular, signal, quantum, primes, and
relativity. It consolidates shared helpers into seven modules loaded through a
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
and loads the four modules in dependency order:

```
utils.wl  →  scales.wl  →  synth.wl  →  export.wl  →  accessibility.wl
  →  config.wl  →  sonification.wl
```

`synth.wl` and `export.wl` both call `EnsureDir` from `utils.wl`;
`accessibility.wl` calls `FmtN` from `utils.wl`. `config.wl` calls `DeepMerge`
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
Prints a single line confirming a GIF export.

```wolfram
STEMDescribeGIF["output/anim.gif", 150, 30]
(* →  "  Animation: 150 frames at 30 fps — output/anim.gif" *)
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

#### `ExportGIF[frames_List, filePath_String, frameRate_:25]`
Exports a list of `Graphics` (or `GraphicsGrid`) objects as a looping animated
GIF. Creates the output directory if needed. Returns `filePath`.

`AnimationRepetitions -> Infinity` is always set. `DisplayDurations` is derived
as `1.0 / frameRate`.

```wolfram
ExportGIF[frames, "output/animation.gif", 30]   (* 30 fps *)
ExportGIF[frames, "output/animation.gif"]        (* default 25 fps *)
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
- everything else → string

Bare flags without `=` (other than `--config-dump`) print a `[WARNING]` line
but are otherwise ignored; apps that recognise bare flags should strip them
from `cliArgs` before calling `LoadConfig`.

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
and `STEMSay` — all guaranteed to emit exactly one complete stdout line, so
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
 ├── config.wl         ← (self-contained; calls DeepMerge internally)
 └── sonification.wl   ← scales.wl (ScaleLookup), synth.wl (ExportAudioBuffer)
```

Projects may call any public symbol after loading `init.wl`. They must not
`Get` individual `src/` files directly, as load order is not guaranteed.

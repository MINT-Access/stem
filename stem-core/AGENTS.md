# stem-core — Agent & API Reference

stem-core is a shared Wolfram Language library for the STEM sonification projects
(pendulum, lorenz, asteroids). It consolidates duplicated helpers into four modules
loaded through a single entry point.

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
utils.wl  →  scales.wl  →  synth.wl  →  export.wl
```

`synth.wl` and `export.wl` both call `EnsureDir` from `utils.wl`; nothing else
requires a later module, so the order is fixed and must not be changed.

---

## Module API

### utils.wl — Filesystem utilities

#### `EnsureDir[filePath_String]`
Creates the parent directory of `filePath` if it does not already exist.
Safe to call repeatedly. Called internally by `ExportCSV`, `ExportGIF`,
`ExportAudioBuffer`, and `LogError`.

```wolfram
EnsureDir["data/results.csv"]   (* creates "data/" if absent *)
```

#### `FmtN[x_?NumericQ, n_:4]`
Formats `x` to `n` significant figures as a single-line string. Use in `Print`
calls instead of bare `NumberForm` — in headless `wolframscript`, `OutputForm`
renders scientific notation as multi-line superscripts; `FmtN` produces inline
`*^` notation instead (e.g. `3.498*^-7`).

```wolfram
Print["Period: ", FmtN[2.0060666, 4], " s"]   (* → "Period: 2.006 s" *)
Print["Drift:  ", FmtN[3.498*^-7, 4], " J"]   (* → "Drift:  3.498*^-7 J" *)
```

#### `LogError[message_String, logPath_String]`
Appends a timestamped `[ERROR] YYYY-MM-DD HH:MM:SS <message>` line to `logPath`.
Creates the log directory if it does not exist. Opens the file in append mode so
existing entries are preserved.

```wolfram
LogError["API request failed", "data/errors.log"]
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
ExportAudioBuffer[audio, "data/output.wav"]
```

---

### export.wl — CSV and GIF export

#### `ExportCSV[rows_List, filePath_String]`
Writes a list of lists (first element is the header row) to a CSV file.
Creates the output directory if needed. Returns `filePath`.

```wolfram
ExportCSV[
  {{"time", "angle"}, {0.0, 0.4}, {0.01, 0.39}},
  "data/results.csv"
]
```

#### `ExportGIF[frames_List, filePath_String, frameRate_:25]`
Exports a list of `Graphics` (or `GraphicsGrid`) objects as a looping animated
GIF. Creates the output directory if needed. Returns `filePath`.

`AnimationRepetitions -> Infinity` is always set. `DisplayDurations` is derived
as `1.0 / frameRate`.

```wolfram
ExportGIF[frames, "data/animation.gif", 30]   (* 30 fps *)
ExportGIF[frames, "data/animation.gif"]        (* default 25 fps *)
```

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
 └── export.wl         ← utils.wl  (EnsureDir)
```

Projects may call any public symbol after loading `init.wl`. They must not
`Get` individual `src/` files directly, as load order is not guaranteed.

# stem-core

Shared Wolfram Language library for the STEM sonification projects.
Provides configuration loading, musical pitch mapping, PCM synthesis,
sonification pipeline, file export helpers, and screen-reader-friendly
console output used by all eight apps: pendulum, lorenz, asteroids,
cellular, signal, quantum, primes, and relativity.

---

## Prerequisites

- **Wolfram Engine** (free) or **Mathematica** 13+
- `wolframscript` on your `PATH`

Verify your installation:

```sh
wolframscript -version
```

---

## Repository layout

```
stem-core/
  init.wl          ← single entry point; load this from your project
  src/
    utils.wl       ← EnsureDir, LogError, FmtN
    scales.wl      ← $StemSampleRate, $StemScales, SemitoneToHz, ScaleLookup
    synth.wl       ← StemSynthNote, NormalizeBuffer, ExportAudioBuffer
    export.wl      ← ExportCSV, ExportGIF
    accessibility.wl ← STEMHeading, STEMSection, STEMBullet, STEMPrintN,
                       STEMDescribeCSV, STEMDescribeWAV, STEMDescribeGIF,
                       $STEMSpeakEnabled, STEMSay,
                       STEMPlayCmd, STEMPlay
  README.md
  AGENTS.md        ← full API reference
```

The projects that consume stem-core live as siblings:

```
stem/
  stem-core/
  pendulum/
  lorenz/
  asteroids/
  cellular/
  signal/
  quantum/
  primes/
  relativity/
  docs/
```

---

## Using stem-core in a project

Add these three lines at the top of your project's `main.wl`, before any
project-specific `Get` calls:

```wolfram
$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
```

`init.wl` sets `$stemCoreRoot` from its own location and loads the five
modules in dependency order. After this, all public symbols are available
in the global context.

---

## Running a project

```sh
wolframscript -file pendulum/main.wl
wolframscript -file lorenz/main.wl
wolframscript -file asteroids/main.wl
wolframscript -file cellular/main.wl
wolframscript -file signal/main.wl
wolframscript -file quantum/main.wl
wolframscript -file primes/main.wl
wolframscript -file relativity/main.wl
```

Each project writes its outputs into its own `output/` directory (created
automatically if absent). Typical outputs:

| File | Description |
|---|---|
| `output/*.csv` | Trajectory / measurement data |
| `output/*.gif` | Looping animation |
| `output/*.wav` | Sonification audio |

Preview audio:

```sh
# macOS
afplay pendulum/output/double_audio.wav

# Linux
aplay pendulum/output/double_audio.wav

# Windows PowerShell
Start-Process wmplayer pendulum\output\double_audio.wav
```

---

## Writing a new project

Minimal `main.wl` skeleton:

```wolfram
(* --- load stem-core --- *)
$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

(* --- your simulation --- *)
STEMHeading["My Simulation"];
data = Table[{t, Sin[t]}, {t, 0, 2 Pi, 0.01}];

(* --- export --- *)
outCSV = "output/results.csv";
ExportCSV[Prepend[data, {"t", "y"}], outCSV];
STEMDescribeCSV[outCSV, Length[data], 2];

frames = (* list of Graphics objects, one per frame *);
outGIF = "output/animation.gif";
ExportGIF[frames, outGIF, 25];
STEMDescribeGIF[outGIF, Length[frames], 25];

notes = StemSynthNote[
  ScaleLookup[#[[2]], -1, 1, $StemScales["Minor"], 220.0],
  0.3, 0.7
] & /@ data;

outWAV = "output/audio.wav";
ExportAudioBuffer[NormalizeBuffer[Total[notes]], outWAV];
STEMDescribeWAV[outWAV];

STEMSay["Done"]
```

See `AGENTS.md` for the complete API reference, parameter descriptions,
and headless / VoiceOver compatibility notes.

---

## Accessibility

stem-core includes a screen-reader output layer (`accessibility.wl`) that
guarantees every console line is a self-contained announcement — no partial
lines, no numbers split across multiple Print arguments — so VoiceOver reads
each item cleanly.

Key functions:

| Function | Output |
|---|---|
| `STEMHeading["text"]` | `=== text ===` |
| `STEMSection["title"]` | `-- title --` |
| `STEMBullet["text"]` | `  • text` |
| `STEMPrintN["label", x, "unit", spec]` | `  label: value unit` |
| `STEMDescribeCSV["path", nRows, nCols]` | `  CSV: nRows rows, nCols columns — path` |
| `STEMDescribeGIF["path", nFrames, fps]` | `  Animation: nFrames frames at fps fps — path` |
| `STEMDescribeWAV["path", dur]` | `  Audio: D.D s — path` |
| `STEMSay["text"]` | prints text; speaks it when `$STEMSpeakEnabled` is `True` |

To enable spoken output via the macOS `say` command:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

For the full VoiceOver + wolframscript workflow, see
[`docs/voiceover-wolframscript-guide.md`](../docs/voiceover-wolframscript-guide.md).

---

## Scales reference

| Name | Character |
|---|---|
| `"MinorPentatonic"` | Dark, bluesy — good default for chaotic data |
| `"MajorPentatonic"` | Bright, open — suits periodic / oscillating data |
| `"Major"` | Classical, resolved |
| `"Minor"` | Melancholic |
| `"WholeTone"` | Ambiguous, dreamlike — suits fractal data |
| `"Phrygian"` | Tense, modal |

```wolfram
$StemScales["WholeTone"]   (* {0, 2, 4, 6, 8, 10, 12, 14, 16, 18} *)
```

---

## Configuration API

stem-core manages a 4-layer config merge for all apps. See `AGENTS.md` for
the full parameter reference.

| Symbol | Description |
|---|---|
| `$HardcodedDefaults` | Base Association of all default values |
| `LoadConfig[appName, cliArgs]` | Merges defaults → `config/config.json` → `<app>/config.json` → CLI overrides |
| `DeepMerge[base, override]` | Recursively merges two Associations (override wins) |
| `GetCfg[cfg, {key, path}, default]` | Safe nested key lookup with fallback |
| `ParseCliOverrides[args]` | Converts `--key=value` strings into nested Associations; supports negative numbers |

```wolfram
cfg = LoadConfig["pendulum", $ScriptCommandLine];
sr  = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
```

Print the merged config and exit (useful for debugging):

```sh
wolframscript -file pendulum/main.wl -- --config-dump
```

---

## Sonification API

`sonification.wl` provides a three-layer pipeline that converts any numeric
trajectory into a stereo WAV file. Most apps call `SonifyTrajectory` directly;
pendulum calls the individual layers to mix two pendulum bobs.

| Function | Description |
|---|---|
| `SonifyTrajectory[traj, cfg, path, eventTypes]` | Single entry point: runs all three layers and writes the WAV |
| `SpatialLayer[traj, cfg]` | Maps x-position to stereo pan; returns `<\|"left"→…, "right"→…\|>` |
| `MotionLayer[traj, cfg]` | Maps speed to pitch via scale lookup; returns `<\|"buffer"→…\|>` |
| `EventLayer[traj, cfg, eventTypes]` | Inserts accent tones at labelled events (e.g. `"apex"`, `"crossing"`); returns `<\|"buffer"→…\|>` |
| `MixLayers[spatial, motion, event, cfg]` | Combines layers into a stereo matrix |
| `RenderAudio[stereoData, cfg, path]` | Normalises and writes the WAV file |

Trajectory format: `n × 5` matrix with columns `{t, x, y, z, speed}`.

```wolfram
traj   = (* n × 5 matrix *)
outWAV = FileNameJoin[{$outDir, "audio.wav"}];
SonifyTrajectory[traj, cfg, outWAV, {"apex", "crossing"}];
```

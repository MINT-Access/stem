# stem-core

Shared Wolfram Language library for the STEM sonification projects.
Provides musical pitch mapping, PCM synthesis, file export helpers,
and screen-reader-friendly console output used by the pendulum, lorenz,
and asteroids simulations.

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
                       $STEMSpeakEnabled, STEMSay
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
```

Each project writes its outputs into its own `data/` directory (created
automatically if absent). Typical outputs:

| File | Description |
|---|---|
| `data/*.csv` | Trajectory / measurement data |
| `data/*.gif` | Looping animation |
| `data/*.wav` | Sonification audio |

Preview audio on macOS:

```sh
afplay pendulum/data/pendulum_audio.wav
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
outCSV = "data/results.csv";
ExportCSV[Prepend[data, {"t", "y"}], outCSV];
STEMDescribeCSV[outCSV, Length[data], 2];

frames = (* list of Graphics objects, one per frame *);
outGIF = "data/animation.gif";
ExportGIF[frames, outGIF, 25];
STEMDescribeGIF[outGIF, Length[frames], 25];

notes = StemSynthNote[
  ScaleLookup[#[[2]], -1, 1, $StemScales["Minor"], 220.0],
  0.3, 0.7
] & /@ data;

outWAV = "data/output.wav";
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
| `STEMPrintN["label", x, "unit", spec]` | `  label: value unit` |
| `STEMDescribeCSV["path", nRows, nCols]` | `  CSV: nRows rows, nCols columns — path` |
| `STEMDescribeGIF["path", nFrames, fps]` | `  Animation: nFrames frames at fps fps — path` |
| `STEMDescribeWAV["path", dur]` | `  Audio: D.D s — path` |
| `STEMSay["text"]` | prints text; speaks it when `$STEMSpeakEnabled` is `True` |

To enable spoken output via the macOS `say` command:

```sh
wolframscript -e '$STEMSpeakEnabled = True' -file main.wl
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

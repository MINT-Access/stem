# stem-core

Shared Wolfram Language library for the STEM sonification projects.
Provides musical pitch mapping, PCM synthesis, and file export helpers
used by the pendulum, lorenz, and asteroids simulations.

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
    utils.wl       ← EnsureDir, LogError
    scales.wl      ← $StemSampleRate, $StemScales, SemitoneToHz, ScaleLookup
    synth.wl       ← StemSynthNote, NormalizeBuffer, ExportAudioBuffer
    export.wl      ← ExportCSV, ExportGIF
  README.md
  AGENTS.md        ← full API reference
```

The projects that consume stem-core live as siblings:

```
Projects/
  stem-core/
  pendulum/
  lorenz/
  asteroids/
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

`init.wl` sets `$stemCoreRoot` from its own location and loads the four
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
data = Table[{t, Sin[t]}, {t, 0, 2 Pi, 0.01}];

(* --- export --- *)
ExportCSV[Prepend[data, {"t", "y"}], "data/results.csv"];

notes = StemSynthNote[
  ScaleLookup[#[[2]], -1, 1, $StemScales["Minor"], 220.0],
  0.3, 0.7
] & /@ data;

ExportAudioBuffer[
  NormalizeBuffer[Total[notes]],
  "data/output.wav"
];

Print["Done."]
```

See `AGENTS.md` for the complete API reference, parameter descriptions,
and headless / VoiceOver compatibility notes.

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

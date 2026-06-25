# VoiceOver + wolframscript Guide

This guide explains how to run the STEM sonification projects with macOS VoiceOver
active in Terminal, what to expect from each project's stdout output, and how to
enable spoken announcements through the accessibility layer built into stem-core.

---

## Prerequisites

| Requirement | Version |
|---|---|
| macOS | 12 Monterey or later |
| Wolfram Engine / Mathematica | 13.x or later (for `wolframscript`) |
| VoiceOver | Built-in to macOS |

Verify `wolframscript` is on your PATH:

```
which wolframscript
wolframscript --version
```

---

## Starting VoiceOver in Terminal

1. Press **Command-F5** to toggle VoiceOver on or off.
2. Open **Terminal** (or iTerm2). VoiceOver reads each new stdout line as it arrives.
3. In Terminal preferences, set **Scrollback lines** to at least 10 000 so you can
   navigate back through long output with VoiceOver's cursor (VO-Arrow).

**Tip**: use a profile with a light background and high-contrast text so sighted
collaborators can also read the output; VoiceOver is unaffected by colour scheme.

---

## Running a project

All three STEM projects are run the same way:

```
cd /path/to/stem/<project>
wolframscript -file main.wl
```

Substitute `<project>` with `pendulum`, `lorenz`, or `asteroids`.

The script writes output files to `<project>/data/` as it runs. It does **not**
open any GUI windows, play audio through the speakers, or require a display server,
so it is safe to run in a standard VoiceOver terminal session.

### Expected output structure

Each project follows a four-stage pattern:

```
=== Project Name ===
  parameter: value unit
  ...

[1/4] Stage description...
  result line
  ...

[2/4] Stage description...
  CSV: N rows, C columns — data/output.csv

[3/4] Stage description...
  Animation: N frames at F fps — data/output.gif

[4/4] Stage description...
  Audio: D.D s — data/output.wav

=== Done ===
```

VoiceOver reads each line as a self-contained announcement. Lines beginning with
`===` are major headings; lines beginning with `--` are sub-section headers; lines
beginning with `  *` are list items.

---

## Listening to output audio

After the script finishes, play the generated WAV file:

```
afplay data/<output>.wav
```

`afplay` routes through VoiceOver's audio channel on macOS, so you hear the
sonification through whatever output device VoiceOver is using (speakers,
AirPods, or a Braille display's audio jack).

To adjust volume without leaving the terminal:

```
afplay -v 0.5 data/<output>.wav    # 50 % volume
```

---

## Enabling spoken announcements

stem-core includes an optional `say` integration controlled by the `STEM_SPEAK`
environment variable. Set it to `1` before running any project:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

When `STEM_SPEAK=1`, calls to `STEMSay` inside `main.wl` speak the text
through the macOS `say` command in addition to printing it. This is useful when
you want a spoken "done" announcement without monitoring the terminal actively.

The variable defaults to unset so normal script runs are silent.

---

## stem-core accessibility API

The following functions are available in all projects after `init.wl` is loaded.

### Numeric formatting

```wolfram
STEMPrintN["label", value]
STEMPrintN["label", value, "unit"]
STEMPrintN["label", value, "unit", spec]
```

Prints `  label: value unit` as a single line. `spec` is passed to `FmtN`:
an integer for significant figures, or `{total, decimals}` for fixed decimal places.

### Structured announcements

```wolfram
STEMHeading["Major Title"]    (* → "=== Major Title ===" *)
STEMSection["Sub-section"]    (* → "-- Sub-section --"   *)
STEMBullet["list item"]       (* → "  * list item"       *)
```

Use `STEMHeading` for top-level stage titles, `STEMSection` for data blocks
within a stage, and `STEMBullet` for individual result items.

### Export metadata

```wolfram
STEMDescribeCSV["path/to/file.csv"]
STEMDescribeCSV["path/to/file.csv", nRows, nCols]

STEMDescribeWAV["path/to/file.wav"]
STEMDescribeWAV["path/to/file.wav", durationSeconds]

STEMDescribeGIF["path/to/file.gif"]
STEMDescribeGIF["path/to/file.gif", nFrames, fps]
```

Each prints a single descriptive line confirming an export completed and where
the file was written. Pass optional arguments when the values are known at call
site; omit them to print only the path.

### Speech integration

```wolfram
$STEMSpeakEnabled   (* Boolean flag — True when STEM_SPEAK=1 in the environment *)
STEMSay["text"]     (* Print + optional say *)
```

`STEMSay` always prints its argument. When `$STEMSpeakEnabled` is `True` it also
invokes the macOS `say` command. The function is safe to call unconditionally —
enabling or disabling speech only requires setting or unsetting `STEM_SPEAK`.

---

## VoiceOver navigation shortcuts in Terminal

| Key | Action |
|---|---|
| VO-A | Read all from current position |
| VO-Shift-Home | Jump to top of scroll buffer |
| VO-Shift-End | Jump to bottom (latest output) |
| VO-Up / VO-Down | Move by line |
| VO-F | Find text in VoiceOver cursor |
| Command-K | Clear Terminal scroll buffer |

VO = Control-Option (the VoiceOver modifier key).

---

## Troubleshooting

**Script exits immediately with no output**
Run `wolframscript -version` to confirm the engine is installed and licensed.

**No audio file produced**
Check `data/errors.log` in the project directory. The asteroids project requires
a NASA API key in `$NASAAPIKEY`; the pendulum and lorenz projects have no external
dependencies.

**`say` does not speak**
Confirm `STEM_SPEAK=1` is set in the shell environment and that the `say` binary
is present (`which say`). On non-macOS systems, leave `STEM_SPEAK` unset.

**VoiceOver reads numbers as individual digits**
This happens when scientific notation like `3.498e-07` is split across multiple
`Print` arguments. stem-core uses `FmtN` internally, which produces inline `*^`
notation (e.g. `3.498*^-7`) and avoids multi-line rendering in headless sessions.

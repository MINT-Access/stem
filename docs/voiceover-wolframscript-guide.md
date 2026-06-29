# Screen Reader + wolframscript Guide

This guide explains how to run the STEM sonification projects with a screen reader
active in a terminal, what to expect from each project's stdout output, and how to
enable spoken announcements through the accessibility layer built into stem-core.

> **Platform note:** This guide was originally written for macOS VoiceOver. The
> same projects work on Linux (with Orca) and Windows (with Narrator). See the
> platform-specific sections at the end of each topic for Linux and Windows
> equivalents.

---

## Prerequisites

| Requirement | macOS | Linux | Windows |
|---|---|---|---|
| Wolfram Engine | 13.x+ | 13.x+ | 13.x+ |
| Screen reader | VoiceOver (built-in) | Orca (`sudo apt install orca`) | Narrator (built-in) |
| Audio player | `afplay` (built-in) | `aplay` (`sudo apt install alsa-utils`) | Windows Media Player (built-in) |
| TTS for STEM_SPEAK | `say` (built-in) | `espeak-ng` (`sudo apt install espeak-ng`) | System.Speech (built-in) |

Verify `wolframscript` is on your PATH:

```
which wolframscript
wolframscript --version
```

---

## Starting your screen reader in Terminal

### macOS — VoiceOver

1. Press **Command-F5** to toggle VoiceOver on or off.
2. Open **Terminal** (or iTerm2). VoiceOver reads each new stdout line as it arrives.
3. In Terminal preferences, set **Scrollback lines** to at least 10 000 so you can
   navigate back through long output with VoiceOver's cursor (VO-Arrow).

**Tip**: use a profile with a light background and high-contrast text so sighted
collaborators can also read the output; VoiceOver is unaffected by colour scheme.

### Linux — Orca

Orca reads terminal output in GNOME Terminal and other VTE-based terminals. Start
Orca with `orca &` or enable it via Accessibility settings. Orca reads each new
stdout line as it arrives, the same way VoiceOver does on macOS.

### Windows — Narrator

Narrator is built into Windows 10/11. Press **Windows+Ctrl+Enter** to toggle it.
Open **Command Prompt** or **Windows Terminal** — Narrator reads each new line of
output. For best results use Windows Terminal with a high-contrast theme.

---

## Running a project

All three STEM projects are run the same way:

```
cd /path/to/stem/<project>
wolframscript -file main.wl
```

Substitute `<project>` with `pendulum`, `lorenz`, or `asteroids`.

The script writes output files to `<project>/output/` as it runs. It does **not**
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
  CSV: N rows, C columns — output/output.csv

[3/4] Stage description...
  Animation: N frames at F fps — output/output.gif

[4/4] Stage description...
  Audio: D.D s — output/output.wav

=== Done ===
```

VoiceOver reads each line as a self-contained announcement. Lines beginning with
`===` are major headings; lines beginning with `--` are sub-section headers; lines
beginning with `  *` are list items.

---

## Listening to output audio

After the script finishes, play the generated WAV file:

```sh
# macOS — afplay routes through VoiceOver's audio channel, so you hear it
# through whichever device VoiceOver is using (speakers, AirPods, etc.)
afplay output/<output>.wav

# Adjust volume without leaving the terminal (macOS only)
afplay -v 0.5 output/<output>.wav    # 50 % volume

# Linux — aplay uses ALSA; paplay uses PulseAudio (alternative)
aplay output/<output>.wav

# Windows PowerShell — blocks until playback completes
(New-Object Media.SoundPlayer 'output\<output>.wav').PlaySync()
# Or: Start-Process wmplayer output\<output>.wav
```

---

## Enabling spoken announcements

stem-core includes optional TTS integration controlled by the `STEM_SPEAK`
environment variable. Set it to `1` before running any project:

```sh
# macOS / Linux
STEM_SPEAK=1 wolframscript -file main.wl

# Windows PowerShell
$env:STEM_SPEAK = "1"; wolframscript -file main.wl
```

When `STEM_SPEAK=1`, calls to `STEMSay` speak the text through the platform TTS
engine in addition to printing it. This is useful when you want a spoken "done"
announcement without monitoring the terminal actively.

| Platform | TTS engine | Prerequisite |
|---|---|---|
| macOS | `say` | Built in |
| Linux | `espeak-ng` (preferred) or `espeak` | `sudo apt install espeak-ng` |
| Windows | System.Speech (PowerShell) | Built into Windows 10/11 |

If the TTS tool is not found on Linux, a one-time warning is printed and the
app continues silently. The variable defaults to unset so normal runs are silent.

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
speaks through the platform TTS engine (`say` on macOS, `espeak-ng`/`espeak` on
Linux, System.Speech on Windows). The function is safe to call unconditionally —
enabling or disabling speech only requires setting or unsetting `STEM_SPEAK`.

---

## Screen reader navigation shortcuts in Terminal

### macOS — VoiceOver

| Key | Action |
|---|---|
| VO-A | Read all from current position |
| VO-Shift-Home | Jump to top of scroll buffer |
| VO-Shift-End | Jump to bottom (latest output) |
| VO-Up / VO-Down | Move by line |
| VO-F | Find text in VoiceOver cursor |
| Command-K | Clear Terminal scroll buffer |

VO = Control-Option (the VoiceOver modifier key).

### Linux — Orca

| Key | Action |
|---|---|
| Insert-A | Read all from current position |
| Insert-Home | Jump to top |
| Insert-End | Jump to bottom |
| Insert-Up / Insert-Down | Move by line |

### Windows — Narrator

| Key | Action |
|---|---|
| Narrator+M | Start reading from here |
| Ctrl | Stop reading |
| Narrator+Up / Narrator+Down | Move by line |
| Narrator+F | Find text |

Narrator key = Caps Lock or Insert (configurable).

---

## Troubleshooting

**Script exits immediately with no output**
Run `wolframscript -version` to confirm the engine is installed and licensed.

**No audio file produced**
Check `output/errors.log` in the project directory. The asteroids project requires
a NASA API key in `$NASAAPIKEY`; the pendulum and lorenz projects have no external
dependencies.

**TTS does not speak**
Confirm `STEM_SPEAK=1` is set. On macOS, check that `say` is present (`which say`).
On Linux, install `espeak-ng` (`sudo apt install espeak-ng`) — without it the app
prints a warning and continues silently. On Windows, System.Speech is built into
Windows 10/11; if unavailable, leave `STEM_SPEAK` unset.

**VoiceOver reads numbers as individual digits**
This happens when scientific notation like `3.498e-07` is split across multiple
`Print` arguments. stem-core uses `FmtN` internally, which produces inline `*^`
notation (e.g. `3.498*^-7`) and avoids multi-line rendering in headless sessions.

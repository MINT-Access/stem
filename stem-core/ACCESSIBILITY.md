# stem-core Accessibility Guide

All STEM projects in this repo are designed to run fully headlessly and to
produce output that VoiceOver reads cleanly. This guide explains the
accessibility layer and the patterns that make it work.

---

## Enabling spoken announcements

Set `STEM_SPEAK=1` before running any app to enable the macOS `say` command
alongside normal printed output:

```sh
STEM_SPEAK=1 wolframscript -file pendulum/main.wl
STEM_SPEAK=1 wolframscript -file signal/main.wl
```

Without `STEM_SPEAK=1` all output is still printed in VoiceOver-friendly format
— each measurement appears on its own complete line so VoiceOver reads it without
splitting numbers. `STEM_SPEAK=1` adds voiced speech on top of that.

---

## What VoiceOver hears

Each app follows the same structure:

| Output call | Example text | VoiceOver reads |
|---|---|---|
| `STEMHeading["..."]` | `=== Near-Earth Asteroid Report: ... ===` | Major section title |
| `STEMSection["..."]` | `-- Miss Distance --` | Sub-section marker |
| `STEMBullet["..."]` | `  * 2026-06-20: 3 asteroids` | List item |
| `STEMPrintN["label", x, "unit", spec]` | `  mean: 42.3 km` | One numeric value per line |
| `STEMDescribeCSV[path, rows, cols]` | `  Exported CSV: data/out.csv — 12 rows, 5 cols` | Export confirmation |
| `STEMDescribeWAV[path, dur]` | `  Exported WAV: data/out.wav — 3.5 s` | Export confirmation |
| `STEMDescribeGIF[path, nFrames, fps]` | `  Exported GIF: data/out.gif — 300 frames @ 10 fps` | Export confirmation |
| `STEMSay["..."]` | `Complete. Play audio: afplay data/out.wav` | Final announcement |

Every line is a self-contained statement — no multi-line spans, no raw
`NumberForm` superscripts. VoiceOver can navigate forward/backward one
output line at a time.

---

## Playing audio

Each app prints an `afplay` command in its final `STEMSay` line. Copy it
directly from the terminal:

```sh
afplay pendulum/data/simple_audio.wav
afplay lorenz/data/lorenz_audio.wav
afplay asteroids/data/asteroids_audio.wav
afplay cellular/output/life_rpentomino_audio.wav
afplay signal/output/chord_clean.wav
```

The `signal` app produces the most accessible single file:
**`{mode}_narrative_full.wav`** — a self-contained spoken narrative that
chains text descriptions with the clean, noisy, and recovered signals so the
entire Fourier demonstration can be followed by listening alone:

```sh
afplay signal/output/chord_narrative_full.wav
afplay signal/output/sweep_narrative_full.wav
afplay signal/output/am_narrative_full.wav
```

---

## Inspecting the active configuration

Any app can print its fully merged configuration as JSON and exit immediately
without running the simulation. Pipe to `python3 -m json.tool` for indented
output:

```sh
wolframscript -file pendulum/main.wl -- --config-dump | python3 -m json.tool
wolframscript -file cellular/main.wl -- --config-dump | python3 -m json.tool
```

This lets you verify that `STEM_SPEAK`, voice, rate, and all other settings
are set as expected before committing to a long run.

---

## Accessibility API reference

These functions are defined in `stem-core/src/accessibility.wl`.

### `STEMHeading[text]`
Prints `=== text ===` — signals a major named section. Use once per logical
block (e.g. once per asteroid report, once per simulation summary).

### `STEMSection[title]`
Prints `-- title --` — signals a sub-section within a heading block.

### `STEMBullet[text]`
Prints `  * text` — a list item. Use for enumerated data (dates, object names).

### `STEMPrintN[label, x, unit, spec]`
Prints `  label: value unit` with `FmtN` formatting. Use for every single
numeric value. Guarantees one complete stdout line per measurement.

| Parameter | Type | Description |
|---|---|---|
| `label` | String | Descriptive name, e.g. `"mean miss distance"` |
| `x` | Number | The value |
| `unit` | String | Unit string, e.g. `"km"` or `""` |
| `spec` | Integer or {total, decimals} | Passed to `FmtN` for formatting |

### `STEMDescribeCSV[path, nRows, nCols]`
Prints a one-line CSV export confirmation.

### `STEMDescribeWAV[path, durationSec]`
Prints a one-line WAV export confirmation with duration in seconds.

### `STEMDescribeGIF[path, nFrames, fps]`
Prints a one-line GIF export confirmation with frame count and frame rate.

### `STEMSay[text]`
Prints `text` and, if `$STEMSpeakEnabled` is `True`, calls `say text` via the
macOS speech synthesiser. Used for the final completion message.

### `$STEMSpeakEnabled`
`True` when the environment variable `STEM_SPEAK=1` was set at load time.
Set automatically by `stem-core/init.wl` — do not set manually.

---

## VoiceOver + Terminal workflow

For a full guide covering Terminal setup, VoiceOver navigation shortcuts,
and how to follow a running wolframscript session by sound, see
[`docs/voiceover-wolframscript-guide.md`](../docs/voiceover-wolframscript-guide.md).

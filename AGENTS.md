# AGENTS.md — Guidance for Claude Code

This file covers the monorepo as a whole. For per-project detail, see the
`AGENTS.md` in each project directory. For the stem-core API, see
`stem-core/AGENTS.md`.

Per-project AGENTS files:
- [`pendulum/AGENTS.md`](pendulum/AGENTS.md)
- [`lorenz/AGENTS.md`](lorenz/AGENTS.md)
- [`asteroids/AGENTS.md`](asteroids/AGENTS.md)
- [`cellular/AGENTS.md`](cellular/AGENTS.md)
- [`signal/AGENTS.md`](signal/AGENTS.md)
- [`quantum/AGENTS.md`](quantum/AGENTS.md)
- [`primes/AGENTS.md`](primes/AGENTS.md)

---

## Repo structure

```
stem/
  stem-core/        Shared library — loaded by every project
  pendulum/         Physics simulation (pendulum ODE)
  lorenz/           Physics simulation (Lorenz attractor)
  asteroids/        Data project (NASA NeoWs API)
  cellular/         Cellular automata (Game of Life, Rule 110)
  signal/           Signal processing (Fourier analysis, direct audio output)
  quantum/          Quantum mechanics (coherent state QHO, particle-in-a-box)
  primes/           Prime number patterns (Ulam spiral, prime gap rhythm)
  config/           Global config defaults (config.json)
  docs/             Workflow guides
```

All app directories are siblings. Projects load stem-core with a
relative path that stays correct wherever the monorepo lives:

```wolfram
$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
```

---

## How to run

```sh
wolframscript -file pendulum/main.wl
wolframscript -file lorenz/main.wl
wolframscript -file asteroids/main.wl                                    # last 7 days, MinorPentatonic
wolframscript -file asteroids/main.wl -- 2026-01-01 2026-12-31           # full year
wolframscript -file asteroids/main.wl -- 2026-01-01 2026-06-25 Phrygian  # date range + scale
wolframscript -file cellular/main.wl                                     # Game of Life, R-pentomino
wolframscript -file cellular/main.wl -- --simulation.mode=rule110
wolframscript -file signal/main.wl                                       # chord (default)
wolframscript -file signal/main.wl -- --simulation.mode=sweep
wolframscript -file quantum/main.wl                                      # QHO coherent state
wolframscript -file quantum/main.wl -- --simulation.mode=box             # particle-in-a-box
wolframscript -file quantum/main.wl -- --simulation.qho.alpha=3.0
wolframscript -file primes/main.wl                                       # Ulam spiral (default)
wolframscript -file primes/main.wl -- --simulation.mode=gaps             # prime gap rhythm
wolframscript -file primes/main.wl -- --simulation.ulam.size=201
```

`asteroids/main.wl` and `asteroids/experiment.wl` accept `[-- YYYY-MM-DD YYYY-MM-DD [Scale]]`.
Ranges longer than 7 days are split into ≤7-day API requests automatically.
Valid scales: `MinorPentatonic` `MajorPentatonic` `Major` `Minor` `WholeTone` `Phrygian`

Inspect any app's active config without running the simulation:

```sh
wolframscript -file <app>/main.wl -- --config-dump | python3 -m json.tool
```

Override any config key at runtime:

```sh
wolframscript -file pendulum/main.wl -- --simulation.mode=simple --simulation.duration=30
wolframscript -file cellular/main.wl -- --simulation.life.starting_pattern=gliderlgun
wolframscript -file signal/main.wl -- --simulation.chord.noise_level=0.8
```

Tests (run from the `stem/` root or from within the project directory):

```sh
wolframscript -file pendulum/tests/test_model.wl
wolframscript -file lorenz/tests/test_model.wl
wolframscript -file asteroids/tests/test_analyse.wl
```

`cellular`, `signal`, and `quantum` do not have test files. All existing test files exit 0 on
success, 1 on failure.

---

## stem-core API (quick reference)

After `Get[".../stem-core/init.wl"]` all of the following are available:

| Symbol | Module | Purpose |
|---|---|---|
| `$StemSampleRate` | scales | `44100` Hz constant |
| `$StemScales` | scales | Association of scale name → semitone list |
| `SemitoneToHz[semitones, rootHz]` | scales | Equal-temperament conversion |
| `ScaleLookup[value, lo, hi, scale, rootHz]` | scales | Map a data value to a frequency |
| `StemSynthNote[freq, dur, vol, harmonics, decayFrac, sr]` | synth | Generate PCM samples for one note |
| `NormalizeBuffer[buffer, ceiling]` | synth | Scale buffer peak to ≤ ceiling |
| `ExportAudioBuffer[buffer, filePath, sr]` | synth | Write WAV (headless-safe) |
| `ExportCSV[rows, filePath]` | export | Write CSV, create directory if needed |
| `ExportGIF[frames, filePath, frameRate]` | export | Write looping animated GIF |
| `EnsureDir[filePath]` | utils | Create parent directory if absent |
| `LogError[message, logPath]` | utils | Append timestamped error to log file |
| `FmtN[x, spec]` | utils | Format number (sig figs or {total,decimals}), single-line (use in Print) |
| `STEMHeading[text]` | accessibility | Print `=== text ===` — major section title |
| `STEMSection[title]` | accessibility | Print `-- title --` — sub-section marker |
| `STEMBullet[text]` | accessibility | Print `  * text` — list item |
| `STEMPrintN[label, x, unit, spec]` | accessibility | Print `  label: value unit` — one numeric value per line |
| `STEMDescribeCSV[path, nRows, nCols]` | accessibility | Print CSV export summary line |
| `STEMDescribeWAV[path, durationSec]` | accessibility | Print WAV export summary line |
| `STEMDescribeGIF[path, nFrames, fps]` | accessibility | Print GIF export summary line |
| `$STEMSpeakEnabled` | accessibility | Boolean flag; `True` when `STEM_SPEAK=1` env var is set at load time |
| `STEMSay[text]` | accessibility | Print text + optionally speak via `say` |

See `stem-core/AGENTS.md` for full parameter descriptions and constraints.

---

## Critical: headless wolframscript environment

All code must run correctly via `wolframscript -file` with no display server.

**Never use:**
- `Audio[]` — requires a display context on macOS builds; produces a silent or
  broken WAV in headless mode
- `SoundNote` / `Sound[SoundNote[...]]` — requires the notebook front end to
  render MIDI; silent under `wolframscript`
- `NotebookOpen`, `CreateDialog`, `Dynamic`, `AudioPlay`, `SystemOpen` — all
  require a GUI

**Always use:**
- `StemSynthNote` + `ExportAudioBuffer` for audio output (uses `SampledSoundList`
  internally, which exports WAV correctly in headless sessions on all platforms)

---

## Conventions (all projects)

- **Variable scoping**: always use `Module[{locals}, ...]`. Never introduce
  free variables that leak into the global context.
- **Parameters**: always passed as an `Association`. Never use global variables
  for simulation parameters.
- **File paths**: always build with `FileNameJoin[{...}]`. Never concatenate
  path strings manually.
- **Output directories**: rely on `EnsureDir` (via the `ExportCSV`, `ExportGIF`,
  `ExportAudioBuffer` helpers) — do not call `CreateDirectory` directly.
- **Units**: SI throughout. Variable names include units where helpful
  (e.g. `velocityKmS`, `distanceKm`).
- **NumberForm in CSV**: always use `ToString[NumberForm[x, spec], OutputForm]`
  — omitting `OutputForm` causes `×10^n` notation with embedded newlines that
  breaks CSV parsing in headless mode.
- **NumberForm in Print**: always use `FmtN[x, spec]` — `ToString[NumberForm[x,
  spec], OutputForm]` renders scientific notation as multi-line superscripts in
  headless mode; `FmtN` produces inline `*^` notation instead.
- **Single-value numeric console lines**: use `STEMPrintN[label, x, unit, spec]`
  rather than a bare `Print` with `FmtN` — it guarantees one complete stdout line
  and consistent `  label: value unit` formatting for VoiceOver. Keep bare `Print`
  only for lines that carry two values (e.g. `[min, max]` ranges) or that use
  `IntegerString` formatting.
- **Tests**: `Exit[1]` on any failure so CI tools detect broken runs.

---

## Where new code belongs

| If you are adding… | Put it in… |
|---|---|
| A new musical scale | `stem-core/src/scales.wl` — `$StemScales` Association |
| A new synthesis shape (harmonics preset) | `stem-core/src/synth.wl` comment; use it as a `harmonics` argument |
| A shared file-export pattern | `stem-core/src/export.wl` |
| A new simulation or data source | A new sibling directory, loaded like the existing projects |
| Physics or domain logic specific to one project | That project's `src/` |
| A new screen-reader output helper | `stem-core/src/accessibility.wl` |
| A workflow or usage guide | `docs/` |

If a helper appears in more than one project's `src/`, it belongs in stem-core.

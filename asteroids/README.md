# Near-Earth Asteroid Tracker

A Wolfram Language data analysis project that fetches live asteroid
close-approach data from NASA's public NeoWs API and produces a
statistical report, an animated solar system visualisation, and a
musical sonification — all from the terminal via `wolframscript`.

## What it does

Every day, dozens of asteroids pass near Earth. This project fetches
the last 7 days of close-approach data, analyses the distances,
velocities, and sizes, and turns the data into:

- A **CSV report** with one row per asteroid
- A **solar system animation** (GIF) showing each asteroid as a dot
  around Earth, coloured by hazard status
- A **musical sonification** (WAV) where each asteroid is one note —
  pitch reflects miss distance, timbre distinguishes hazardous from safe

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- Internet connection (to fetch from NASA)
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`

Optional: a free NASA API key from https://api.nasa.gov (the default
DEMO_KEY works at 30 requests/hour).

## Usage

```bash
# Full run — last 7 days
wolframscript -file main.wl

# Experiments (date ranges, filters, scales)
wolframscript -file experiment.wl

# Offline tests (no API call)
wolframscript -file tests/test_analyse.wl

# Play the sonification (macOS)
afplay data/asteroids_<start>_<end>.wav
```

## Experiment presets (experiment.wl)

| Label             | What it shows                                        |
|-------------------|------------------------------------------------------|
| recent            | Last 7 days, all asteroids, minor pentatonic         |
| hazardous_only    | Last 7 days, hazardous only, eerie Phrygian scale    |
| large_only        | Last 7 days, diameter ≥ 140 m                        |
| chelyabinsk_week  | Feb 11–17 2013 — week of the Chelyabinsk meteor      |
| major_mood        | Same data, brighter major pentatonic scale           |

## Sonification

| Parameter | Design |
|---|---|
| Order | Farthest → closest (dramatic build toward Earth) |
| Pitch | Miss distance → minor pentatonic, root C3 (130.81 Hz) |
| Duration | Inversely proportional to velocity — fast asteroids = shorter notes |
| Volume | Proportional to mean diameter |
| Timbre | Safe: warm bell (3 harmonics: 1.0, 0.35, 0.10); hazardous: bright/harsh (5 harmonics) |

The ordering and timbre together tell the story: you hear a sparse, gentle
opening as distant safe rocks drift past, then the texture thickens and harshens
as hazardous asteroids approach Earth.

To change scale, edit the `"Scale"` option in `main.wl`:

```wolfram
ExportSonification[asteroids, outWAV, "Scale" -> "Phrygian"]
```

Available scales: `MinorPentatonic`, `MajorPentatonic`, `Major`, `Minor`,
`WholeTone`, `Phrygian`.

## Animation

| Parameter | Design |
|---|---|
| View | Top-down solar system, Earth at centre |
| Distance scale | Square root (so close and far objects are both visible) |
| Reference rings | 1 LD, 5 LD, 20 LD (1 LD ≈ 384 400 km) |
| Dot colour | Cyan = safe, red = hazardous |
| Dot size | Proportional to log(mean diameter) |
| Reveal order | Farthest → closest; final frame held 3 s |

Only miss distance is known from the API — asteroid directions are not — so
each dot is placed at the correct radial distance but at a fixed random angle
(seeded at 42 for repeatability across runs).

## Project structure

    asteroids/
    ├── main.wl                  Entry point
    ├── experiment.wl            Named presets
    ├── src/
    │   ├── fetch.wl             NASA API fetch + JSON parse
    │   ├── analyse.wl           Filters and statistics
    │   ├── output.wl            CSV export and console report
    │   ├── animate.wl           Solar system GIF
    │   └── sonify.wl            Musical WAV sonification
    ├── tests/
    │   └── test_analyse.wl      Offline unit tests
    ├── data/                    Output files (not committed)
    ├── AGENTS.md                Guidance for Claude Code
    └── README.md

## Console output

`main.wl` prints one complete line per event so VoiceOver reads each chunk
as a self-contained announcement. Headings use `STEMHeading`; the asteroid
count and hazardous count in `PrintSummary` use `STEMPrintN`, as do the
Min/Max/Mean velocity lines; miss distance lines mix km and LD on one line
and remain as bare `Print`; export confirmations use `STEMDescribeCSV`
(1 row per asteroid, 12 columns), `STEMDescribeGIF`, and `STEMDescribeWAV`;
the final line uses `STEMSay`.

To also hear a spoken announcement when the run finishes:

```sh
wolframscript -e '$STEMSpeakEnabled = True' -file main.wl
```

See [`docs/voiceover-wolframscript-guide.md`](../docs/voiceover-wolframscript-guide.md)
for the full VoiceOver + wolframscript workflow.

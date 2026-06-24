# AGENTS.md — Guidance for Claude Code

## Project overview

Near-Earth Asteroid Tracker in Wolfram Language. Fetches live data from
NASA's NeoWs API, analyses close approaches, exports CSV, an animated
solar system GIF, and a musical WAV sonification. Runs entirely from the
terminal via `wolframscript`.

## Project structure

- `main.wl`              — Full pipeline for the last 7 days
- `experiment.wl`        — Named presets (date ranges, filters, scales)
- `src/fetch.wl`         — NASA NeoWs API fetch and JSON parsing
                           (`FetchAsteroids`, `FetchRawJson`, `ParseAsteroid`)
- `src/analyse.wl`       — Filters and statistics
                           (`HazardousAsteroids`, `SafeAsteroids`,
                            `MissDistanceStats`, `VelocityStats`,
                            `SizeDistribution`, `ClosestApproachSummary`)
- `src/output.wl`        — CSV export and console report
                           (`ExportResults`, `PrintSummary`)
- `src/animate.wl`       — Solar system GIF (`ExportAnimation`)
- `src/sonify.wl`        — Musical WAV (`ExportSonification`)
- `tests/test_analyse.wl`— Offline unit tests (no API call)
- `data/`                — All outputs (not committed)

## How to run

```bash
wolframscript -file main.wl               # last 7 days, full pipeline
wolframscript -file experiment.wl         # named preset
wolframscript -file tests/test_analyse.wl # offline tests
afplay data/asteroids_<dates>.wav         # play audio on macOS
```

## API key

The project uses NASA's DEMO_KEY by default (30 req/hour).
For heavier use, get a free key at https://api.nasa.gov and set
`$NasaApiKey` in `src/fetch.wl`.

## Data model

Each asteroid is a Wolfram Association with keys:
  id, name, approachDate, missDistanceKm, velocityKmS,
  diamMinKm, diamMaxKm, diamMeanKm, isHazardous, absoluteMag

All lists are sorted by missDistanceKm ascending (closest first).

## Sonification design

- Order: farthest → closest (dramatic build)
- Pitch: miss distance → MinorPentatonic (default), root C3
- Duration: inversely proportional to velocity (fast = short)
- Volume: proportional to diameter
- Timbre: hazardous asteroids have extra high harmonics (brighter, harsher)
- Available scales: MinorPentatonic, MajorPentatonic, Minor, Phrygian

## Animation design

- Top-down solar system view, Earth at centre
- Distance scaled by square root (so close + far objects both visible)
- Reference rings at 1 LD, 5 LD, 20 LD
- Cyan dots = safe, red dots = hazardous
- Dot size proportional to log(diameter)
- Asteroids revealed farthest → closest, final frame held 3 s

## Constants (src/analyse.wl)

- `$LunarDistance` = 384 400 km (mean Earth-Moon distance)
- `$EarthRadius`   = 6 371 km

## Conventions

- `Module` for all function scoping
- Parameters in Associations, never globals
- Tests are fully offline (synthetic data) — no network needed
- `Exit[1]` on test failure for CI compatibility

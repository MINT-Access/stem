# AGENTS.md — Guidance for Claude Code

## Project overview

Near-Earth Asteroid Tracker in Wolfram Language. Fetches live data from
NASA's NeoWs API, analyses close approaches, exports CSV, an animated
solar system GIF, and a WAV sonification. Runs entirely from the
terminal via `wolframscript`.

## Project structure

- `main.wl`              — Full pipeline for the last 7 days
- `experiment.wl`        — Named presets (date ranges, filters, scales)
- `src/fetch.wl`         — NASA NeoWs API fetch and JPL SBDB orbital elements
                           (`FetchAsteroidsMulti`, `FetchAsteroids`,
                            `ChunkDateRange`, `FetchRawJson`, `ParseAsteroid`,
                            `FetchOrbitalElements`, `FetchAllOrbitalElements`,
                            `ParseSBDBValue`, `$OrbitalElementsCache`)
- `src/analyse.wl`       — Filters and statistics
                           (`HazardousAsteroids`, `SafeAsteroids`,
                            `ClosestAsteroids`, `MissDistanceStats`,
                            `VelocityStats`, `SizeClass`, `SizeDistribution`,
                            `ToLunarDistances`, `ToEarthRadii`,
                            `ClosestApproachSummary`)
- `src/output.wl`        — CSV export and console report — 17 columns
                           (`ExportResults`, `PrintSummary`)
- `src/animate.wl`       — Orbital mechanics helpers + solar system GIF
                           (`DateToJulianDate`, `SolveKepler`,
                            `OrbitalToEcliptic2D`, `KeplerPosition`,
                            `ComputeGeocentricAngle`, `AugmentAsteroidsWithAngles`,
                            `ExportAnimation`, `$EarthOrbitalElements`)
- `src/sonify.wl`        — WAV sonification (`ExportSonification`)
- `tests/test_analyse.wl`— Offline unit tests incl. orbital mechanics (no API call)
- `output/`                — All outputs (not committed)

## How to run

```bash
wolframscript -file main.wl                                    # last 7 days, MinorPentatonic
wolframscript -file main.wl -- 2026-01-01 2026-12-31           # full year, MinorPentatonic
wolframscript -file main.wl -- 2026-01-01 2026-06-25 Phrygian  # date range + scale
wolframscript -file main.wl -- 2026-06-20 2026-06-26 --no-orbital-elements  # skip SBDB fetch
wolframscript -file experiment.wl                              # named preset
wolframscript -file experiment.wl -- 2026-01-01 2026-06-25 WholeTone  # override dates + scale
wolframscript -file tests/test_analyse.wl                      # offline tests (incl. orbital mechanics)
afplay output/asteroids_<dates>.wav                              # play audio on macOS
```

CLI args for `main.wl` and `experiment.wl`: `[-- YYYY-MM-DD YYYY-MM-DD [Scale]]`
- 0 args: last 7 days, preset scale (MinorPentatonic for `main.wl`)
- 2 args: given date range, preset scale
- 3 args: given date range, given scale

Ranges longer than 7 days are split into ≤7-day chunks automatically.
Valid scales: `MinorPentatonic` `MajorPentatonic` `Major` `Minor` `WholeTone` `Phrygian`

## API key

The project uses NASA's DEMO_KEY by default (30 req/hour).
For heavier use, get a free key at https://api.nasa.gov.

**Never hardcode the key in source files.** Always pass it via the
environment variable:

```bash
export NASA_API_KEY=your_key_here
```

`src/fetch.wl` reads it at runtime via `Environment["NASA_API_KEY"]`.

## Data model

Each asteroid is a Wolfram Association. Keys after the full pipeline:

| Key | Source | Description |
|-----|--------|-------------|
| `id` | NeoWs | SPK-ID string (used as SBDB `des` parameter) |
| `name` | NeoWs | Display name |
| `approachDate` | NeoWs | "YYYY-MM-DD" |
| `missDistanceKm` | NeoWs | Closest-approach distance in km |
| `velocityKmS` | NeoWs | Relative velocity in km/s |
| `diamMinKm`, `diamMaxKm`, `diamMeanKm` | NeoWs | Estimated diameter in km |
| `isHazardous` | NeoWs | Boolean |
| `absoluteMag` | NeoWs | H magnitude |
| `orbital_elements` | SBDB | Association with e, a, i, om, w, ma, per, epoch_jd [, tp] — or $Failed |
| `geocentricAngle` | animate.wl | Computed ecliptic angle (radians) in (-π, π]; seeded-random fallback |

All lists are sorted by missDistanceKm ascending (closest first).
`orbital_elements` and `geocentricAngle` are absent when `--no-orbital-elements` is passed
(for backward compatibility, `ExportAnimation` falls back to seeded-random angles in that case).

## Sonification design

- Order: farthest → closest (dramatic build)
- Pitch: miss distance → MinorPentatonic (default), root C3
- Duration: inversely proportional to velocity (fast = short)
- Volume: proportional to diameter
- Timbre: hazardous asteroids have extra high harmonics (brighter, harsher)
- Available scales: MinorPentatonic, MajorPentatonic, Major, Minor, WholeTone, Phrygian

## Animation design

- Top-down solar system view, Earth at centre
- Distance scaled by square root (so close + far objects both visible)
- Reference rings at 1 LD, 5 LD, 20 LD
- Cyan dots = safe, red dots = hazardous
- Dot size proportional to log(diameter)
- Asteroids revealed farthest → closest, final frame held (duration-proportional, see below)
- Angle from Keplerian orbital elements (JPL SBDB) via `AugmentAsteroidsWithAngles`;
  seeded-random fallback (SeedRandom[42]) if elements unavailable

## GIF/WAV duration sync (fixed post-v1.5.0)

**The bug.** `ExportAnimation` rendered exactly one frame per asteroid plus
a fixed 3s hold, at a fixed 10fps, so GIF playback length tracked asteroid
*count*, not the WAV's actual length (which is `n * (noteDuration +
gapDuration)`, unrelated to frame count/rate). Measured before the fix: the
default weekly run was 6.0s GIF vs 20.2s WAV (3.4x); the full-year preset
was 186.9s GIF vs 1232.3s WAV (6.6x); `asteroids_hazardous_only` (n=1) was
the reverse case, 3.1s GIF vs 0.79s WAV (0.25x, GIF *longer* than audio) —
the same decoupled-frame-budget bug the lorenz/pendulum audit found
throughout this app suite, confirmed here by ratios spanning both
directions of mismatch.

**The fix.** `ExportAnimation` now takes `targetDuration` (the same
`n * stepDur` value `ExportSonification` sizes the WAV with — computed by
the new `SonificationDuration[n, cfg]` in `sonify.wl`, factored out so
`main.wl`/`experiment.wl` can compute it before rendering audio) plus
`nFrames` as a RENDER BUDGET (default 150). `frameRate =
Clip[nFrames/targetDuration, {2,30}]`; `actualNFrames` is recomputed from
the clamped rate so playback duration equals `targetDuration` exactly, the
same pattern as `lorenz/src/animate.wl`. Of `actualNFrames`, a `holdFrac`
share (default 15%) holds the fully-revealed final frame; the rest is
spent revealing asteroids, sampled evenly across `1..n` via `Subdivide`
(not `DeleteDuplicates`d — for small `n` this naturally repeats a reveal
count across consecutive frames, acting as an implicit hold, rather than
shrinking the frame budget below what the clamp computed).

**Verification.** Default weekly run: 6.0s → 24.0s GIF (audio 24.12s,
ratio 3.67x → 1.00x). A 2013 Chelyabinsk-week preset (67 asteroids): audio
44.89s, GIF 45.0s. `experiment.wl`'s `ExportAnimation` call site was
updated the same way; its `ExportSonification` call was found to already
be broken independently (stale 3-argument signature that doesn't match
`sonify.wl`'s actual `[asteroids, cfg, filePath]` — confirmed it silently
no-ops, producing no WAV) — a **pre-existing, unrelated bug**, left
unfixed and flagged here rather than folded into this change.

## Orbital mechanics (src/animate.wl)

Geocentric angle computation pipeline:

1. `DateToJulianDate[dateStr]` — ISO date → Julian Date (noon UTC, proleptic Gregorian formula)
2. `SolveKepler[M, e]` — Newton-Raphson, 50 iterations max, converges to 1e-10
3. `OrbitalToEcliptic2D[x, y, i, om, w]` — perifocal → heliocentric ecliptic {X, Y} in AU
   using the standard 3-angle rotation matrix (Ω, i, ω; all degrees)
4. `KeplerPosition[elements, jd]` — heliocentric ecliptic {X, Y} for any elements Association;
   uses `tp` (perihelion JD) if present, else propagates from `ma + epoch_jd`
5. `ComputeGeocentricAngle[elements, dateStr]` — subtracts Earth's position (from
   `$EarthOrbitalElements`, J2000 values) to give geocentric angle in (-π, π]
6. `AugmentAsteroidsWithAngles[asteroids]` — generates seeded baseline first, then replaces
   with computed angles where valid elements exist; always returns a full List

SBDB field mapping (SBDB label → internal key stored in `orbital_elements`):
- `node` → `om` (longitude of ascending node, degrees)
- `peri` → `w` (argument of perihelion, degrees)
- `M` → `ma` (mean anomaly at epoch, degrees)
- `period` → `per` (orbital period, days)
- `e`, `a`, `i`, `tp` → unchanged

## Constants (src/analyse.wl)

- `$LunarDistance` = 384 400 km (mean Earth-Moon distance)
- `$EarthRadius`   = 6 371 km

## Conventions

- `Module` for all function scoping
- Parameters in Associations, never globals
- Tests are fully offline (synthetic data) — no network needed
- `Exit[1]` on test failure for CI compatibility
- `PrintSummary` uses `STEMPrintN` (stem-core) for the count lines (total
  asteroids tracked, potentially hazardous) and the velocity block (Min/Max/Mean
  velocity). Miss distance lines mix km and LD on one line and remain as bare
  `Print`. Follow the same rule for additions: `STEMPrintN` for one value per
  line, bare `Print` when two quantities appear together.

## Dependencies

- Mathematica or Wolfram Engine (any recent version)
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`
- No external paclets required

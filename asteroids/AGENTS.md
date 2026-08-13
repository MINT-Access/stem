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
- `src/sonify.wl`        — WAV sonification (`ExportSonification`,
                           `SonificationDuration`, `SonificationStepDuration`)
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
updated the same way; its `ExportSonification` call site's stale
3-argument signature (which didn't match `sonify.wl`'s actual
`[asteroids, cfg, filePath]` and silently no-op'd, producing no WAV) has
since been fixed in a separate commit (see git history) — no longer an
open issue.

**This "fixed" state was itself incomplete — caught by an external review
that checked every preset instead of a sample.** Two further problems
surfaced, documented in the sections below: (1) the fix above makes GIF
duration follow the WAV's, but the WAV's own duration is
`n*(noteDuration+gapDuration)` — completely unbounded in asteroid count,
so a busy date range still produced an impractically long GIF+WAV pair
(fixed by the bounded-duration design below); (2) even where duration was
correctly bounded, small-n presets landing at high, unclamped frame rates
hit a GIF-format quantization error far past the ~3% floor (fixed by the
quantized-frame-rate change further below).

## Bounded sonification/GIF duration (design decision, post-audit)

**The problem.** `SonificationDuration[n,cfg] = n*(noteDuration+gapDuration)`
(0.67s/asteroid at the shipped defaults) is architecturally sound — GIF and
WAV both derive their length from this one function, so they can never
desync by construction, the same pattern `lorenz/src/animate.wl` uses. But
an external review that checked every preset in `output/` (not a sample)
found 28 of 32 badly desynced anyway, 70-85% off, worsening as asteroid
count grew: a 7-day/36-asteroid preset was 72.8% off, a 365-day/1839-asteroid
preset was 84.8% off — numbers that turned out to reproduce *exactly* what
the pre-fix, hardcoded-frame-budget bug (documented above: "one frame per
asteroid, fixed 3s hold, fixed 10fps") would have produced for those same
`n`. Root cause: those 32 output files were stale, generated before the fix
landed, and simply never regenerated — not a code defect (see the fully
re-verified table below). But investigating this surfaced a real, separate
design question the original fix ducked: is unbounded
`n*(noteDuration+gapDuration)` actually a reasonable duration formula at
all? A full-year query returns ~1800 asteroids; at 0.67s each that is
1232s (~20.5 minutes) of audio, and — once GIF correctly follows WAV — a
1232-second GIF file to match. That is not a reasonable demo artifact or
listening experience regardless of whether GIF and WAV agree with each
other.

**Two options considered:**
- **Option A — let GIF duration follow WAV's, however long that gets.**
  Architecturally the simplest (already fully implemented, just needed
  stale files regenerated) but produces a ~20-minute GIF/WAV pair for the
  busiest realistic query. Rejected: not a reasonable UX for a demo app,
  regardless of internal consistency.
- **Option B — cap total duration, compress per-asteroid spacing for busy
  ranges.** Chosen. `SonificationStepDuration[n,cfg]` (`src/sonify.wl`)
  replaces the fixed `noteDuration+gapDuration` step with
  `Clip[maxTotalDuration/n, {minStepDuration, noteDuration+gapDuration}]`
  — for typical presets (`n` <= ~134 at the shipped defaults, i.e. up to
  about a month of data) this clips to the full, unscaled step and nothing
  changes from before; above that, spacing shrinks toward
  `minStepDuration` so total duration (`n*step`) stays close to
  `maxTotalDuration` however large `n` gets, short of the floor being hit.
  `noteDuration`/`gapDuration` scale together (same ratio preserved) so
  the note/gap character doesn't change, only its timescale.
  `SonificationDuration` and `ExportSonification` both call this one
  function (never recompute the formula independently) for the same
  can't-drift-apart reason `SonificationDuration` itself was originally
  factored out.

  Config (`config.json` `sonification.motion`): `maxTotalDuration: 90.0`,
  `minStepDuration: 0.03` (seconds), alongside the existing
  `noteDuration: 0.55`, `gapDuration: 0.12`. At these defaults the
  break-even is `n ~= 90/0.67 ~= 134` asteroids (about a month of typical
  NEO traffic); the busiest realistic case — a full year, ~1800-1850
  asteroids — lands at `step = 90/1827 ~= 0.049s`, comfortably above the
  0.03s floor, giving almost exactly 90.0s total, not the floor's
  worst case.

  **This is a real, audible tradeoff, not a free lunch:** compressing
  ~1800 asteroids into 90s means ~49ms of trajectory per asteroid, heard
  as continuous pitch/pan glissando rather than as anything resembling
  discrete per-asteroid tones (the underlying `SonifyTrajectory` engine
  cubic-spline-interpolates pitch/pan/volume across the full audio buffer
  from these `n` control points — see `stem-core/sonification.wl`
  `SpatialLayer` — so this degrades gracefully into a fast continuous
  sweep rather than clicks or dropouts; there is no risk of inaudible or
  broken output at the floor, only "more events blurred together," an
  honest sonic proxy for "very many asteroids," the same
  more-events-denser-texture tradeoff `grover/src/sonify.wl`'s
  `BuildCompareAudio` documents for its own bounded-tick-interval design).
  A typical week or month of data (the overwhelmingly common case) is
  completely unaffected — this only bites the deliberately-busy
  multi-month/full-year queries the README explicitly calls out as
  possible.

**A second, independent bug surfaced during verification: GIF centisecond
quantization.** `Export[...,"GIF",...]` only stores frame delays in
integer centiseconds. The nominal `frameRate = nFrames/targetDuration`
computed in `ExportAnimation` (`src/animate.wl`) is not, in general, an
exact multiple of 1/100s — at the LOW frame rates most presets land at
(2-10fps, i.e. 10-50cs/frame) the resulting rounding error is small
relative to the frame duration and stays under the ~3% floor, but at
higher, unclamped rates (up to the 30fps ceiling) it does not: 22.4fps
(a real `asteroids_hazardous_only` value, n=10) quantizes to a stored
delay of 4cs = 25fps actual, an 11.6% frame-rate error that measured as a
10.45% GIF/WAV duration mismatch — freshly generated, not a stale-file
artifact, and clearly above the ~3% floor the fix's own methodology says
must be explained or fixed. Fixed by quantizing `frameRate` to
`1/(Round[100/nominalFrameRate]/100)` **before** solving `actualNFrames`
(rather than after, which is what let the error through previously) —
`actualNFrames` now flexes against the frame rate that will actually be
stored in the file, not the ideal pre-quantization one. Residual error
after this fix is <=0.30% across every preset re-measured (see table
below), consistent with the ~3% floor being real headroom rather than a
number that happened to work for the presets originally sampled.

**Verification — every preset regenerated and directly measured (GIF:
frame count x per-frame delay from the file's own header; WAV: sample
count / sample rate from the file's own header), not assumed.** The 32
files previously in `output/` were mostly redundant day-by-day dev
snapshots of the same "last 7 days" code path (n in the low 30s-40s every
time, testing nothing the default run doesn't already cover) generated
while iterating on the app well before this fix existed; rather than
re-fetch 20+ near-duplicate weekly snapshots from the live NASA API,
`output/` was cleared and regenerated with a set that spans the full
design space this fix actually changes behaviour over — every named
`experiment.wl` preset (all 4, full coverage, not a subset) plus the
`main.wl` date-range examples the README documents (1 week, 1 month, 6
months, 1 year, plus a scale-override sanity check), crossing the ~134
asteroid compression threshold multiple times and reaching the practical
n~1800 ceiling:

| Preset (n asteroids)                          |   n | GIF frames | GIF s  | WAV s  | diff  |
|------------------------------------------------|----:|-----------:|-------:|-------:|------:|
| `main.wl` default, 2026-08-07..08-13            |  36 |        151 |  24.16 |  24.12 | 0.17% |
| `main.wl` 2026-01-01..01-07 (README "one week") |  36 |        151 |  24.16 |  24.12 | 0.17% |
| `main.wl` 2026-01-01..01-31 (README "one month")| 140 |        180 |  90.00 |  90.00 | 0.00% |
| `main.wl` 2026-01-01..06-30 (README "six months")| 850 |        180 |  90.00 |  90.00 | 0.00% |
| `main.wl` 2026-01-01..12-31 (README "full year")|1827 |        180 |  90.00 |  90.00 | 0.00% |
| `main.wl` 2026-06-01..06-25, Phrygian scale     | 113 |        151 |  75.50 |  75.71 | 0.28% |
| `experiment.wl` A `recent`                      |  36 |        151 |  24.16 |  24.12 | 0.17% |
| `experiment.wl` B `hazardous_only`              |  10 |        168 |   6.72 |   6.70 | 0.30% |
| `experiment.wl` C `large_only`                  |  15 |        144 |  10.08 |  10.05 | 0.30% |
| `experiment.wl` D `chelyabinsk_week`            |  67 |        150 |  45.00 |  44.89 | 0.25% |

All 10 within 0.30% (well inside the ~3% floor), including both the
compression regime (`n`=140,850,1827, all landing at the 90s cap) and the
regime below it (`n`<=113, all unaffected, matching pre-cap behaviour
exactly). `--no-orbital-elements` was used for the three largest ranges
purely to keep JPL SBDB fetch time practical (~2.5s/asteroid serially
would be ~75 minutes for the full-year case); orbital elements only affect
the GIF's asteroid *angles*, never duration, so this has no bearing on
what's being verified here.

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

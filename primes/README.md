# Prime Number Patterns

A Wolfram Language exploration of prime number structure, runnable entirely from
the terminal via `wolframscript`. Two modes reveal complementary aspects of prime
distribution: a visual spiral grid and a percussive audio rhythm driven by the
gap sequence.

## The mathematics

### Ulam spiral

The integers are arranged on a square grid by winding outward from the centre:
place 1 at the centre, step right 1, up 1, left 2, down 2, right 3, up 3, and
so on — each direction segment length used twice before incrementing. Prime cells
are marked white, composites black. The diagonal stripes that emerge visually
reflect the fact that certain quadratic polynomials (e.g. 4n² − 2n + 41, Euler's
prime-generating polynomial) hit primes far more frequently than others, producing
lines of white cells along those diagonals.

### Prime gaps and the prime number theorem

The n-th prime gap is gₙ = p_{n+1} − pₙ. By the prime number theorem, pₙ ≈ n ln n,
so the mean gap near pₙ is approximately ln pₙ. For the first 5000 primes
(p₅₀₀₀ = 48611): mean gap ≈ ln(48611) ≈ 10.8. The actual sample mean is ≈ 9.72
because the asymptotic approximation is not yet tight at this scale.

Twin primes (gₙ = 2) are the densest possible prime pair. The twin prime conjecture
— that infinitely many exist — remains unproven. The first 5000 primes contain 680
twin prime pairs.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`

## Usage

```bash
# Default (Ulam spiral, 101×101)
wolframscript -file main.wl

# Explicit modes
wolframscript -file main.wl -- --simulation.mode=ulam
wolframscript -file main.wl -- --simulation.mode=gaps

# Override parameters
wolframscript -file main.wl -- --simulation.ulam.size=201
wolframscript -file main.wl -- --simulation.gaps.count=10000

# Inspect merged config
wolframscript -file main.wl -- --config-dump

# Play sonification
# macOS
afplay output/ulam_audio.wav
afplay output/gaps_audio.wav
afplay output/gaps_slow.wav

# Linux
aplay output/ulam_audio.wav
aplay output/gaps_audio.wav
aplay output/gaps_slow.wav

# Windows PowerShell
Start-Process wmplayer output\ulam_audio.wav
Start-Process wmplayer output\gaps_audio.wav
Start-Process wmplayer output\gaps_slow.wav
```

## Modes

### `ulam` — Ulam spiral

Generates a size×size prime/composite grid using the Ulam spiral winding. The
default 101×101 grid contains 1252 primes (density ≈ 12.3 %). A 201×201 grid
contains 4236 primes (density ≈ 10.5 %, closer to the PNT prediction of 1/ln(201²)
≈ 9.4 %).

The app also exports a 31×31 centre zoom with cell borders visible — useful for
verifying the spiral layout and spotting the density variation near the origin.

Grid size must be odd (so the centre cell is unambiguous). Even values are
automatically incremented by 1 with a warning.

### `gaps` — Prime gap rhythm

Analyses the first `count` prime gaps and maps them to two audio outputs.

**Base WAV** (`gaps_audio.wav`): each prime pₙ triggers a short sine burst. The
attack time is:

    t_n = (p_n − p_1) / (p_count − p_1) × baseDuration

All relative gap ratios are preserved exactly. The pitch of each burst is mapped
linearly from [min_hz, max_hz] as the prime value increases from p₁ to p_count.
At the default 120 bpm, baseDuration = 30 s.

Twin primes produce near-simultaneous attacks separated by only 2/total_span of
the full duration — perceptually a rapid double-strike distinct from isolated
primes.

**Slow WAV** (`gaps_slow.wav`): identical but at quarter tempo (baseDuration × 4 =
120 s at 120 bpm). The stretched timeline makes individual gap lengths easier to
count by ear. Large gaps become clearly audible pauses; twin primes remain
perceptually paired.

The animated GIF progressively reveals the gap sequence as a line chart in steps
of `ceil(count/50)` gaps per frame (≤ 50 frames total). The final frame adds an
inset frequency histogram showing how often each gap value occurs.

## Outputs

### `ulam` mode

| File | Description |
|------|-------------|
| `output/ulam_spiral.png` | Full-resolution prime/composite grid |
| `output/ulam_spiral.gif` | Single-frame GIF (pipeline consistency) |
| `output/ulam_centre_zoom.png` | 31×31 centre crop with cell borders |
| `output/ulam_spiral.csv` | integer, row, col, is_prime for each prime found |
| `output/ulam_audio.wav` | 10 s row-scan sonification |

### `gaps` mode

| File | Description |
|------|-------------|
| `output/gaps_animation.gif` | Animated gap chart, progressive reveal (≤ 50 frames) |
| `output/gaps_stats.csv` | n, prime, next_prime, gap, cumulative_gap, is_twin_prime |
| `output/gaps_audio.wav` | Percussive sonification at base tempo (≈ 30 s) |
| `output/gaps_slow.wav` | Same sonification at quarter tempo (≈ 120 s) |

## Sonification

### Ulam row scan

The grid is scanned row by row (top to bottom). Each row produces one trajectory
point fed to the stem-core `SonifyTrajectory` pipeline:

| Trajectory column | Quantity | Audio dimension |
|-------------------|----------|----------------|
| x | right − left prime density asymmetry | stereo pan |
| y | row prime density | pitch |
| speed | \|row-to-row density change\| | volume |

The scan runs over 10 seconds regardless of grid size.

### Gaps percussive WAV

The gaps sonification bypasses `SonifyTrajectory` and builds the PCM buffer
directly. Each of the `count` primes contributes:

    sample[t] += 0.3 · sin(2π · freq · t / sr) · exp(−5t / toneSamples)

where `freq` is the prime's mapped pitch and `toneSamples` = tone_duration_ms × sr.
Tones overlap heavily at the default settings — the listener hears continuous
harmonic texture whose density and pitch contour reflect prime distribution, with
audible rhythmic pauses at large gaps. The buffer is peak-normalised to 0.95 before
export.

## Project structure

    primes/
    ├── main.wl              Entry point
    ├── config.json          App-level defaults
    ├── src/
    │   ├── model.wl         UlamModel, GapsModel, UlamCoords
    │   ├── animate.wl       Grid PNG/GIF and gap animation (AnimatePrimes)
    │   └── sonify.wl        Row-scan and percussive WAV export (SonifyPrimes)
    ├── output/              Output files (not committed)
    └── README.md

## Console output

Step numbers `[1/4]` through `[4/4]` mark each pipeline stage. Key statistics
(prime count, density, mean gap, twin prime count) are printed after the model
step. Export confirmations use `STEMDescribeCSV`, `STEMDescribeWAV`, and
`STEMDescribeGIF`.

To enable speech at each stage, set `STEM_SPEAK=1`:

```sh
STEM_SPEAK=1 wolframscript -file main.wl -- --simulation.mode=gaps
```

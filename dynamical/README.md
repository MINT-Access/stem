# Dynamical Systems

Sonifies the logistic map and its period-doubling route to chaos — one
of the most studied models in nonlinear dynamics, and one of the most
striking demonstrations that simple deterministic rules can produce
behaviour indistinguishable from randomness. First mode of a
`dynamical/` app that may receive additional modes (Hénon map, circle
map, etc.) in future sessions.

**New to this app?** Start with
[`dynamical/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — the recommended
five-preset listening sequence that walks from a single stable note to
full chaos.

## The logistic map

    x_{n+1} = r * x_n * (1 - x_n)

`x` is a population fraction in [0,1] (0 = extinct, 1 = the environment's
maximum carrying capacity); `r` is a growth rate parameter in [0,4].
Despite its simplicity — one line, one parameter — the long-term
behaviour of this equation as `r` increases undergoes one of the most
famous sequences of transitions in mathematics:

| r range | Behaviour |
|---|---|
| r < 1 | Population collapses to zero |
| 1 < r < 3 | Single stable fixed point — the population settles to one value |
| r ~ 3.0 | First period-doubling bifurcation — the population alternates between two values |
| r ~ 3.449 | Period 4 (two doublings) |
| r ~ 3.544 | Period 8 |
| r ~ 3.5644 | Feigenbaum accumulation point — onset of chaos |
| r > 3.57 | Mostly chaotic, with periodic windows |
| r ~ 3.83 | The period-3 window — a sudden return to order inside the chaos |
| r = 4 | Fully chaotic, ergodic on [0,1] |

## Why this sonifies exceptionally well

Period-doubling is a temporal, rhythmic phenomenon. Period-1 sounds
like a single repeating note. Period-2 sounds like two notes
alternating. Period-4 is a four-note cycle. The listener hears the
rhythm double, then double again, then dissolve into arrhythmic chaos —
an experience audio conveys more directly than any static plot. The
period-3 window produces a sudden return to a clean three-note rhythm
in the middle of chaos, audible as a striking moment of unexpected
order.

## The Feigenbaum constant

The ratio of successive period-doubling intervals converges to the
Feigenbaum constant, δ ≈ 4.66920160910299. This is not a peculiarity of
the logistic map specifically — it is a **universal constant** that
appears in the period-doubling route to chaos of *any* smooth
one-dimensional map with a single hump (a unimodal map), regardless of
the map's other details. Discovering this universality (Feigenbaum,
1975-1978) was one of the founding results of chaos theory: wildly
different systems (fluid convection, population models, electronic
oscillators) all approach chaos via period-doubling at the same
universal rate. This app locates the first three bifurcation points
numerically (via root-finding on the map's stability conditions, not by
hardcoding known values) and verifies the ratio directly — see
"Correctness checks" below.

## The period-3 window and Li-Yorke's theorem

Around r ≈ 3.83, deep inside the chaotic region, the map suddenly
settles into a stable period-3 cycle — three notes repeating cleanly —
before returning to chaos as r increases further. This is not a fluke:
a landmark 1975 theorem by Li and Yorke, titled simply "Period Three
Implies Chaos," proved that if a continuous one-dimensional map has
*any* point of period 3, it must also have points of every other
period, and chaotic behaviour is mathematically guaranteed nearby. The
period-3 window's existence is not an accident of this particular
equation — it is a necessary consequence of the map having a period-3
orbit at all.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically
- Optional for the spoken intro: macOS `say` (built in), Linux
  `espeak-ng`/`espeak`, or Windows PowerShell (built in) — falls back
  to text-only output if none is available

## Quick start

```sh
# Sweep mode (default): traverse r 2.5 -> 4.0, hearing the whole route to chaos
wolframscript -file main.wl

# Iterate mode: fix r and hear the map's actual time evolution
wolframscript -file main.wl -- --simulation.mode=iterate

# Named presets (the recommended listening sequence — see LISTENING_GUIDE.md)
wolframscript -file main.wl -- --simulation.dynamical.preset=fixed_point
wolframscript -file main.wl -- --simulation.dynamical.preset=period2
wolframscript -file main.wl -- --simulation.dynamical.preset=period4
wolframscript -file main.wl -- --simulation.dynamical.preset=period3_window
wolframscript -file main.wl -- --simulation.dynamical.preset=chaos

# Manual r value
wolframscript -file main.wl -- --simulation.dynamical.r=3.83

# Finer sweep resolution / faster rhythm
wolframscript -file main.wl -- --simulation.dynamical.r_steps=1000
wolframscript -file main.wl -- --simulation.dynamical.note_duration=0.04

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Modes

### sweep (default)

Sweeps r slowly from `r_start` to `r_end` (default 2.5 to 4.0). At each
of `r_steps` (default 500) values of r, the map runs `n_transient`
iterations to let transients die out, then records the next
`n_attractor` iterations as the long-term attractor. A bounded number
of those attractor points per r-step become audible notes (see
"Performance notes" below), so the sweep's total duration stays
predictable regardless of how large `n_attractor` is configured.

Three named events are marked with accent tones as the sweep passes
through them, announced both in the console and via speech:

| Event | Frequency | Duration | Approximate r |
|---|---|---|---|
| First period-doubling bifurcation | 660 Hz | 80 ms | ~3.0 (located numerically) |
| Onset of chaos | 440 Hz | 120 ms | ~3.57 |
| Period-3 window | 528 Hz | 100 ms | ~3.83 |

**Best for:** hearing the entire route to chaos in one continuous
listening experience — the rhythm audibly doubling, doubling again,
and dissolving into chaos, with a distinct return to order at the
period-3 window.

```sh
wolframscript -file main.wl
# macOS:   afplay output/sweep_audio.wav
# Linux:   aplay  output/sweep_audio.wav
# Windows: Start-Process wmplayer output\sweep_audio.wav
```

### iterate

Fixes r at a single value (or a named preset) and iterates the map for
`n_iterations` steps (default 300), sonifying each x_n as the map
actually evolves in time from `x0`. This includes the transient
approach to the eventual attractor — you literally hear the system
settle from an arbitrary starting point into its long-term behaviour.

**Best for:** building a clear, isolated sense of what one specific r
value sounds like, especially via the five presets (see
LISTENING_GUIDE.md for the full recommended sequence).

```sh
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=chaos
# macOS:   afplay output/iterate_audio.wav
# Linux:   aplay  output/iterate_audio.wav
# Windows: Start-Process wmplayer output\iterate_audio.wav
```

## Sonification mapping (both modes)

| Quantity | Encoding |
|---|---|
| Pitch | x_n mapped onto a 3-octave minor pentatonic scale, root C3 — higher x = higher pitch |
| Duration | Fixed, short (`note_duration`, default 80 ms) — this is what makes period-doubling audible as a countable rhythm |
| Volume | \|x_n - x_{n-1}\| — the chaotic region's larger jumps sound louder and more active than the steady periodic region |
| Stereo pan | x_n rescaled to [-1, 1] — low x pans left, high x pans right |

## Correctness checks

Every run prints four physical/mathematical correctness checks:

1. **Feigenbaum constant**: the first three period-doubling bifurcation
   points are located numerically (via `FindRoot` on the map's
   stability conditions — not hardcoded), and the ratio of successive
   intervals is verified to be within 5% of δ ≈ 4.669.
2. **Fixed point** (r=2.8): the long-term iterate is verified to match
   the analytic fixed point x* = 1 - 1/r.
3. **Period-2** (r=3.2): the long-term attractor is verified to have
   exactly 2 distinct values summing to (r+1)/r.
4. **Lyapunov exponent** (r=4.0): computed as the mean of
   log|r(1-2x_n)| over a long trajectory, verified positive and within
   5% of the analytic value log(2) ≈ 0.693.

## Outputs

| File | Description |
|------|-------------|
| `output/sweep_audio.wav` | Spoken intro + sweep sonification (16-bit PCM, 44100 Hz, stereo) |
| `output/sweep.gif` | Progressive bifurcation diagram animation |
| `output/sweep_data.csv` | Per-note table: r, iteration_index, x_n, pitch_hz, pan, volume, event_label |
| `output/iterate_audio.wav` | Spoken intro + iteration sonification (16-bit PCM, 44100 Hz, stereo) |
| `output/iterate.gif` | x_n vs. n time-series animation |
| `output/iterate_data.csv` | Per-iteration table: n, x_n, pitch_hz, pan, volume |

## Configuration parameters (`dynamical/config.json`)

| Key | Default | Description |
|-----|---------|--------------|
| `simulation.mode` | `"sweep"` | `sweep` or `iterate` |
| `simulation.dynamical.r_start` | `2.5` | Sweep start r (sweep mode) |
| `simulation.dynamical.r_end` | `4.0` | Sweep end r (sweep mode) |
| `simulation.dynamical.r_steps` | `500` | Number of r values sampled (sweep mode) |
| `simulation.dynamical.r` | `3.8` | Fixed r value (iterate mode, used when `preset` is empty) |
| `simulation.dynamical.preset` | `""` | Named preset: `fixed_point`, `period2`, `period4`, `period3_window`, `chaos` (iterate mode) |
| `simulation.dynamical.n_transient` | `200` | Transient iterations discarded before recording the attractor (sweep mode) |
| `simulation.dynamical.n_attractor` | `100` | Attractor iterations recorded per r-step (sweep mode) |
| `simulation.dynamical.n_iterations` | `300` | Total iterations (iterate mode) |
| `simulation.dynamical.note_duration` | `0.08` | Seconds per note, both modes |
| `simulation.dynamical.x0` | `0.5` | Initial population fraction |

## Performance notes

Sweep mode audio duration scales as `r_steps * 8 * note_duration` — only
the first 8 of each r-step's recorded attractor points become audible
notes (all recorded attractor points are equally valid once transients
are discarded; 8 is enough to make any periodicity up to period-8
clearly audible as a repeating cycle, while keeping the default
500-step sweep to a manageable ~5.3 minutes rather than the ~66 minutes
a literal one-note-per-attractor-point mapping would produce). Iterate
mode audio duration is simply `n_iterations * note_duration` (~24s at
the defaults).

## Project structure

```
dynamical/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl        — 9 curated preset invocations
  config.json           — App defaults
  LISTENING_GUIDE.md     — Recommended listening sequence and pitch/event reference
  src/
    model.wl            — LogisticMap, SafeX0, presets, AttractorPoints,
                          BifurcationPoint (Feigenbaum root-finder),
                          correctness checks, SweepModel, IterateModelData
    sonify.wl            — Discrete event-driven note synthesis (SynthesizeDiscreteNotes,
                          OverlayEvent), SonifySweep, SonifyIterate
    speech.wl             — Spoken intro synthesis (SpeechSynthesize -> platform TTS ->
                          text-only fallback), BuildSweepIntroText, BuildIterateIntroText
    animate.wl             — AnimateSweepBifurcation, AnimateIterateTimeSeries
    output.wl              — ExportSweepCSV, ExportIterateCSV, correctness-check printing
  tests/
    test_model.wl         — Unit tests (fixed point, period-2, Feigenbaum, Lyapunov)
  output/                 — Output files (not committed)
  README.md
  AGENTS.md
```

## Console output

Step numbers `[1/5]` through `[5/5]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements in
addition to the intro and event narration:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

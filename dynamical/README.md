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
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=extinction
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=growth
wolframscript -file main.wl -- --simulation.dynamical.preset=fixed_point
wolframscript -file main.wl -- --simulation.dynamical.preset=period2
wolframscript -file main.wl -- --simulation.dynamical.preset=period4
wolframscript -file main.wl -- --simulation.dynamical.preset=period3_window
wolframscript -file main.wl -- --simulation.dynamical.preset=chaos

# Manual r value
wolframscript -file main.wl -- --simulation.dynamical.r=3.83

# Lyapunov mode: hear the Lyapunov exponent lambda(r) against a lambda = 0 reference tone
wolframscript -file main.wl -- --simulation.mode=lyapunov
wolframscript -file main.wl -- --simulation.mode=lyapunov --simulation.dynamical.preset=lyapunov_window

# Divergence mode: two orbits delta apart (left/right) and their separation (centre)
wolframscript -file main.wl -- --simulation.mode=divergence
wolframscript -file main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_stable

# Finer sweep resolution / faster rhythm
wolframscript -file main.wl -- --simulation.dynamical.r_steps=1000
wolframscript -file main.wl -- --simulation.dynamical.note_duration=0.04

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Modes

Every mode's WAV is a spoken intro, the sonification, and a short spoken
outro that marks the end. For a talk the logistic map is a
bug-population model: the sweep and iterate intros say that the map gives
next year's population from this year's, that x is the population as a
fraction of the maximum, and that r is the growth rate. Every narration
sentence starts with a capital letter and ends with a full stop (checked
by the tests), and each distinct sentence is synthesised once per run.

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
value sounds like, especially via the seven presets (see
LISTENING_GUIDE.md for the full recommended sequence): `extinction`
(r = 0.8, the population dies out), `growth` (r = 2.0 from x0 = 0.1, it
grows and settles), `fixed_point` (2.8), `period2` (3.2), `period4` (3.5),
`period3_window` (3.830) and `chaos` (4.0). The spoken outro states the
fixed point x* = 1 − 1/r and whether it attracts or repels, from
|f′(x*)| = |2 − r| below or above one, computed for the r being played
(for r < 1 it adds that zero attracts, with slope r).

```sh
wolframscript -file main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=chaos
# macOS:   afplay output/iterate_audio.wav
# Linux:   aplay  output/iterate_audio.wav
# Windows: Start-Process wmplayer output\iterate_audio.wav
```

### lyapunov

Sweeps r from `r_min` to `r_max` (default 2.5 to 4.0) in `steps` equal
steps (default 750) spread over `duration_seconds` (default 120 s) and
sonifies the Lyapunov exponent λ(r) — the average rate at which nearby
starting points separate (λ > 0, chaos) or converge (λ < 0, a periodic
attractor). At each r the map discards `transient` iterations (1000),
then λ is the mean of log|r(1 − 2x)| over the next `average_iterations`
(10000), clipped at `floor` (−0.5).

Two tones sound together, centred:

| Voice | Encoding |
|---|---|
| λ tone | fundamental `reference_hz` × 2^(λ × `octaves_per_unit`) (220 Hz × 2^λ by default, 156–356 Hz), plus 2nd and 3rd harmonics at 0.25 and 0.12 of the fundamental; glides continuously between steps (phase-accumulated, no clicks) |
| reference tone | pure sine at `reference_hz`, the pitch of λ = 0, for the whole sweep |

Above the reference the orbit is chaotic; below it, orderly. Near a
zero crossing the two tones beat. The λ tone is equal-loudness
compensated with **A-weighting** (IEC 61672-1): its gain keeps its
A-weighted level equal to the level it has at the reference pitch, so
it does not seem to fade as it falls (+3.3 dB at the floor, −3.9 dB at
λ = log 2). The floor keeps every harmonic of the λ tone clear of the
reference: at λ = −1 the 2nd harmonic would sit exactly on 220 Hz and
beat like a real crossing. A unit test reads `floor` and
`octaves_per_unit` from `config.json` and fails if any harmonic can
come within a semitone of the reference.

Marker tones (the sweep mode's accents, plus one) sound at the points
inside the range:

| Marker | Frequency | Duration | r |
|---|---|---|---|
| First period-doubling bifurcation | 660 Hz | 80 ms | 3.0 (located numerically) |
| Period-4 bifurcation | 880 Hz | 80 ms | 3.449 |
| Onset of chaos | 440 Hz | 120 ms | 3.5699 |
| Period-3 window | 528 Hz | 100 ms | 3.8284 |

440, 528, 660 and 880 Hz form a just-intoned A minor triad with its
octave, so the new period-4 marker belongs to the same chord.

A spoken intro says what the two tones mean, that the λ tone comes up to
the reference and falls away again at each period doubling inside the
range (r = 3, 3.449 and 3.544, where λ is exactly zero), and that each
later dip below the reference is a window of order. The spoken outro
names the r where λ first rose above zero and the three widest windows
in the range with their period, all computed from the run. The console
prints the onset of chaos (the first upward crossing), then one sentence
per window of order (a downward crossing followed by an upward one): its
two r values, its width in r and in audio seconds, and its period when it
opens within 0.005 of a known window (period 3 at 3.828, 5 at 3.739 and
3.906, 6 at 3.626), otherwise that the period was not identified. Every
crossing is in the CSV (`crossing`, `crossing_r`).

The preset `lyapunov_window` (r 3.40 to 3.90, 500 steps, 40 s) matches
`prototype_lyapunov.wl`, the listening prototype this mode was built
from (its variant B), so the two can be compared directly.

**Best for:** hearing *where* chaos is, quantitatively — the onset near
r ≈ 3.57 and every periodic window inside the chaotic region, where λ
dips below zero.

```sh
wolframscript -file main.wl -- --simulation.mode=lyapunov
# macOS:   afplay output/lyapunov_audio.wav
```

### divergence

Sensitive dependence on initial conditions: two orbits at the same r
(default 4.0), started at `x0` (0.3) and `x0 + delta` (1e-6), iterated
`iterations` (119) times at `iterations_per_second` (3), so the 120 notes
x_0 … x_119 play for exactly 40 s. The first orbit plays hard left, the second hard right, each
with iterate mode's note mapping (volume shared-normalised and quantised
to 16 levels so identical notes give identical samples); a centred,
sustained odd-harmonic tone tracks Log10 of their separation, from 220 Hz
at delta to 880 Hz at 1, so exponential growth is a steady rise whose
slope is the Lyapunov exponent. A 1320 Hz marker (3 × 440 Hz, used by no
other event) sounds once when the separation first exceeds `saturation`
(0.1). The spoken intro is at most 12 s: one shared sentence and one
sentence for the case. The console compares the
saturation iteration with the prediction Log[saturation/delta]/λ and the
fitted slope with λ from `LyapunovExponent`. Presets for a talk sequence,
all rendered to the same length: `divergence_chaotic` (r 4.0),
`divergence_edge` (3.57), `divergence_periodic` (3.2, starting on the
2-cycle at x0 = 0.513, where the fitted slope matches λ), `divergence_stable`
(2.8). `separation_voice: false` gives a stereo-only rendering.

## Sonification mapping (sweep and iterate modes)

| Quantity | Encoding |
|---|---|
| Pitch | x_n mapped onto a 3-octave minor pentatonic scale, root C3 — higher x = higher pitch |
| Duration | Fixed, short (`note_duration`, default 80 ms) — this is what makes period-doubling audible as a countable rhythm |
| Volume | \|x_n - x_{n-1}\| — the chaotic region's larger jumps sound louder and more active than the steady periodic region |
| Stereo pan | x_n rescaled to [-1, 1] — low x pans left, high x pans right |

## Correctness checks

Every run prints six physical/mathematical correctness checks:

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
5. **Lyapunov curve** (the λ(r) the lyapunov mode sonifies, 1000
   transient + 10000 averaged iterations, no floor): λ(2.8) = log 0.8,
   λ(3.2) = the closed-form period-2 value ½ log|f′(x₁) f′(x₂)| (−0.916),
   each within 0.01; λ(3.835), inside the period-3 window, negative;
   λ(4.0) = log 2 within 0.01. Each is printed as a sentence with the
   computed and expected values.
6. **Divergence** (δ = 1e-6, saturation 0.1, x0 = 0.3): the fitted growth
   rate of the separation of two orbits matches `LyapunovExponent` within
   25 percent at r = 4.0 (Log 2) and r = 2.8 (Log 0.8, shrinking). 25
   percent because one pair of orbits gives a finite-time exponent.

## Outputs

| File | Description |
|------|-------------|
| `output/sweep_audio.wav` | Spoken intro + sweep sonification + spoken outro (16-bit PCM, 44100 Hz, stereo) |
| `output/sweep.gif` | Progressive bifurcation diagram animation |
| `output/sweep_data.csv` | Per-note table: r, iteration_index, x_n, pitch_hz, pan, volume, event_label |
| `output/iterate_audio.wav` | Spoken intro + iteration sonification + spoken outro (16-bit PCM, 44100 Hz, stereo) |
| `output/iterate.gif` | x_n vs. n time-series animation |
| `output/iterate_data.csv` | Per-iteration table: n, x_n, pitch_hz, pan, volume |
| `output/lyapunov_audio.wav` | Spoken intro + λ tone, reference tone and markers + spoken outro (stereo) |
| `output/lyapunov.gif` | Bifurcation diagram over λ(r), shared r axis, moving cursor with r and λ printed |
| `output/lyapunov_data.csv` | Per-step table: r, lambda, at_floor, sweep_time_s, audio_time_s, lambda_tone_hz, crossing, crossing_r (a zero crossing, on the row of the step before it) |
| `output/lyapunov_window_*` | The same three files for the `lyapunov_window` preset |
| `output/divergence_audio.wav` | Spoken intro + two orbits (L/R) and separation tone (centre) + spoken outro |
| `output/divergence.gif` | Two orbits above log10 separation with fit, λ prediction and saturation line; cursor |
| `output/divergence_data.csv` | n, x_n, y_n, separation, log10_separation, in_fit, note_start_s, pitch and volume of both voices |
| `output/divergence_<case>_*` | The same three files for each divergence preset |

## Configuration parameters (`dynamical/config.json`)

| Key | Default | Description |
|-----|---------|--------------|
| `simulation.mode` | `"sweep"` | `sweep`, `iterate`, `lyapunov` or `divergence` |
| `simulation.dynamical.r_start` | `2.5` | Sweep start r (sweep mode) |
| `simulation.dynamical.r_end` | `4.0` | Sweep end r (sweep mode) |
| `simulation.dynamical.r_steps` | `500` | Number of r values sampled (sweep mode) |
| `simulation.dynamical.r` | `3.8` | Fixed r value (iterate mode, used when `preset` is empty) |
| `simulation.dynamical.preset` | `""` | Named preset: `extinction`, `growth`, `fixed_point`, `period2`, `period4`, `period3_window`, `chaos` (iterate mode); `lyapunov_window` (lyapunov mode); `divergence_chaotic`, `divergence_edge`, `divergence_periodic`, `divergence_stable` (divergence mode) |
| `simulation.dynamical.n_transient` | `200` | Transient iterations discarded before recording the attractor (sweep mode) |
| `simulation.dynamical.n_attractor` | `100` | Attractor iterations recorded per r-step (sweep mode) |
| `simulation.dynamical.n_iterations` | `300` | Total iterations (iterate mode) |
| `simulation.dynamical.note_duration` | `0.08` | Seconds per note, sweep and iterate modes |
| `simulation.dynamical.x0` | `0.5` | Initial population fraction |
| `simulation.dynamical.lyapunov.r_min` | `2.5` | Sweep start r (lyapunov mode) |
| `simulation.dynamical.lyapunov.r_max` | `4.0` | Sweep end r |
| `simulation.dynamical.lyapunov.steps` | `750` | Number of r values |
| `simulation.dynamical.lyapunov.duration_seconds` | `120` | Length of the sonified sweep (intro and outro come on top) |
| `simulation.dynamical.lyapunov.reference_hz` | `220` | Reference tone, the pitch of λ = 0 |
| `simulation.dynamical.lyapunov.octaves_per_unit` | `1.0` | Octaves the λ tone moves per unit of λ |
| `simulation.dynamical.lyapunov.floor` | `-0.5` | λ is clipped here; keeps the λ tone's harmonics off the reference |
| `simulation.dynamical.lyapunov.transient` | `1000` | Iterations discarded at each r |
| `simulation.dynamical.lyapunov.average_iterations` | `10000` | Iterations averaged at each r |
| `simulation.dynamical.divergence.r` | `4.0` | r for both orbits (divergence mode) |
| `simulation.dynamical.divergence.x0` | `0.3` | Start of the first orbit |
| `simulation.dynamical.divergence.delta` | `1.0e-6` | Offset of the second orbit's start |
| `simulation.dynamical.divergence.iterations` | `119` | Iterations of each orbit |
| `simulation.dynamical.divergence.iterations_per_second` | `3` | Tempo: notes per second (each note lasts 1 / this) |
| `simulation.dynamical.divergence.saturation` | `0.1` | Separation that counts as saturated (fit range end, marker) |
| `simulation.dynamical.divergence.separation_voice` | `true` | Centre separation tone on/off |

## Performance notes

Sweep mode audio duration scales as `r_steps * 8 * note_duration` — only
the first 8 of each r-step's recorded attractor points become audible
notes (all recorded attractor points are equally valid once transients
are discarded; 8 is enough to make any periodicity up to period-8
clearly audible as a repeating cycle, while keeping the default
500-step sweep to a manageable ~5.3 minutes rather than the ~66 minutes
a literal one-note-per-attractor-point mapping would produce). Iterate
mode's notes last `(n_iterations + 1) * note_duration` (24.08 s at the
defaults), plus the spoken intro and outro. Divergence mode's notes last
`(iterations + 1) / iterations_per_second` (40 s at the defaults). Lyapunov mode's sweep lasts exactly `duration_seconds`;
at the defaults the WAV is about 154 s with the intro and outro, and a
run takes under a minute.

## Project structure

```
dynamical/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl        — 11 curated preset invocations
  prototype_lyapunov.wl — Listening prototype for lyapunov mode (variants A/B/C; B was chosen), kept as a record
  config.json           — App defaults
  LISTENING_GUIDE.md     — Recommended listening sequence and pitch/event reference
  src/
    model.wl            — LogisticMap, SafeX0, presets, AttractorPoints,
                          BifurcationPoint (Feigenbaum root-finder),
                          correctness checks, SweepModel, IterateModelData,
                          LyapunovExponent, LyapunovSweep, LyapunovZeroCrossings
    sonify.wl            — Discrete event-driven note synthesis (SynthesizeDiscreteNotes,
                          OverlayEvent), SonifySweep, SonifyIterate, SonifyLyapunov
                          (continuous λ and reference tones, A-weighting compensation)
    speech.wl             — Spoken intro/outro synthesis (SpeechSynthesize -> platform TTS ->
                          text-only fallback), per-sentence cache (SpeakNarration),
                          narration text for all four modes, NarrationConventionIssues
    animate.wl             — AnimateSweepBifurcation, AnimateIterateTimeSeries, AnimateLyapunov
    output.wl              — ExportSweepCSV, ExportIterateCSV, ExportLyapunovCSV,
                          correctness-check printing, PrintLyapunovSummary, PrintLoudnessLine
  tests/
    test_model.wl         — Unit tests (fixed point, period-2, Feigenbaum, Lyapunov,
                          lyapunov mode incl. the false-unison guard)
  output/                 — Output files (not committed)
  README.md
  AGENTS.md
```

## Console output

Step numbers `[1/5]` through `[5/5]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements in
addition to the intro and outro narration. Every console sentence stands
on its own (it names the r or mode it is about), so a screen reader can
jump between lines:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

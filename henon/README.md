# Hénon — The Hénon Map

Sonifies the Hénon map (Michel Hénon, 1976): a two-dimensional, exactly
invertible chaotic map, built as the simplest system that still captures
the essential dynamics of a Poincaré section through the Lorenz
attractor — the same 3D flow sonified in `lorenz/`. Unlike `dynamical/`'s
logistic map (many values fold onto one, no way back), the Hénon map can
always be run backwards exactly, which is what makes this app's `reverse`
mode possible at all.

**New to this app?** Start with
[`henon/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — the recommended
listening sequence across all three modes.

## The physics

### The map

    x_{n+1} = 1 - a x_n^2 + y_n
    y_{n+1} = b x_n

Canonical parameters `a=1.4`, `b=0.3` produce the classic strange
attractor: a fractal curve with box-counting dimension commonly cited
around 1.25-1.28 (this app estimates it directly from the generated
attractor points — see Correctness checks below).

### A concrete link to `lorenz/`

Hénon built this map by studying a Poincaré section — a 2D cross-section
taken through a continuously-flowing 3D trajectory each time it passes
through a chosen plane — of the Lorenz attractor, then simplified the
resulting return map down to the minimal quadratic form above that still
reproduced its essential folding-and-stretching structure. `attractor`
mode's continuous-trajectory sonification reuses `lorenz/`'s own
technique directly (see `AGENTS.md`), which is not a coincidence: both
apps are, in a real sense, sonifying the same underlying dynamical
phenomenon from two different angles.

### Exact invertibility — the key difference from `dynamical/`

The forward map above can be solved for `(x_n, y_n)` in terms of
`(x_{n+1}, y_{n+1})` exactly:

    x_n = y_{n+1} / b
    y_n = x_{n+1} - 1 + a x_n^2

This works for ANY point, not just points on the attractor — the Hénon
map is a genuine bijection of the plane. `dynamical/`'s logistic map has
no equivalent: `F(x)=4x(1-x)` maps two different `x` values to the same
output, so there is no way to recover a unique predecessor. `reverse`
mode demonstrates this exact invertibility directly (see Modes below and
the important caveat in the next section).

### The forward map contracts area; the inverse map expands it

The Jacobian determinant of the forward map is `-b` EVERYWHERE on the
plane (not just on the attractor, not just on average — see Correctness
check 1). Since `|b|=0.3<1`, the forward map shrinks area by a factor of
0.3 on every single step, which is *why* a strange attractor with
essentially zero area can exist at all. The inverse map, by the same
token, must EXPAND area by a factor of `1/b ≈ 3.33` per step — meaning
any floating-point error in a recovered point grows by that same factor
every time the inverse formula is applied again. This is why `reverse`
mode's exact-inverse demonstration is deliberately short (10 steps by
default): the round-trip error stays comfortably near machine precision
at 10 steps (~2e-11 in practice) but would swamp the signal entirely
within a few dozen more (see `AGENTS.md` design decision 8 for the exact
numbers).

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically
- Optional for the spoken intro: macOS `say` (built in), Linux
  `espeak-ng`/`espeak`, or Windows PowerShell (built in) — falls back
  to text-only output if none is available

## Quick start

```sh
# Attractor mode (default): canonical a=1.4, b=0.3
wolframscript -file main.wl

# Sweep mode: the full period-doubling route to chaos, a from 0.2 to 1.4
wolframscript -file main.wl -- --simulation.mode=sweep

# Reverse mode: forward segment, reversed replay, exact-inverse proof
wolframscript -file main.wl -- --simulation.mode=reverse

# A different (a,b) pair for attractor/reverse — see the boundedness
# warning below before changing b without also adjusting a
wolframscript -file main.wl -- --simulation.henon.a=1.2

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

**A note on parameters:** the Hénon map's bounded region depends on `a`
and `b` TOGETHER, not on either alone. Increasing `b` toward 1 while
leaving `a` at its canonical 1.4 causes the trajectory to diverge
(this app checks for this and reports a clear error rather than a wall of
overflow messages) — a smaller `a` is needed at larger `b` to stay
bounded — and even a bounded pair may only settle to a small periodic
cycle rather than a genuine chaotic attractor. `experiments.wl`'s
`attractor_weakly_dissipative` run demonstrates a verified-bounded AND
verified-chaotic pair (`a=1.05, b=0.5`).

## Modes

### attractor (default)

Settles onto the canonical attractor (`a=1.4, b=0.3` by default) after a
transient, then sonifies the resulting trajectory continuously — the
same `SpatialLayer`/`MotionLayer`/`EventLayer` pipeline `lorenz/` uses for
its own attractor, with Hénon's `x_n` driving stereo pan and `y_n`
driving pitch (and the built-in "apex" event detector, which fires on
local turning points). The GIF renders the point cloud growing on the
map's native `(x,y)` plane, lorenz's progressive-reveal convention
adapted from a continuous curve to discrete scattered points — this is
the mode where the attractor's fractal, banded cross-section is most
visually apparent.

**Best for:** hearing and seeing the strange attractor itself, and its
direct kinship with `lorenz/`.

### sweep

Sweeps parameter `a` from 0.2 to 1.4 (default; `b=0.3` fixed) through the
map's own period-doubling route to chaos — a direct 2D analogue of
`dynamical/sweep`'s logistic-map cascade, reusing that app's discrete
note-per-iterate idiom so that period doublings are audibly countable (one
note becomes two, becomes four, becomes eight) rather than a smoothly
interpolated pitch curve. Three accent events mark: the first
period-doubling bifurcation (`a≈0.3675`, an EXACT closed-form value, not
just an empirically-located one), the onset of chaos (`a≈1.0508`), and a
period-7 window discovered inside the chaotic region (`a≈1.227`) — this
app's own analogue of `dynamical/`'s period-3 window, an unexpected
"island of order" located empirically rather than assumed.

**Best for:** hearing the same universal period-doubling route to chaos
`dynamical/` demonstrates in 1D, here in a genuinely 2D, invertible map.

### reverse

Plays a short forward segment on the attractor, then a marker tone, then
the SAME segment replayed in reverse point-order (a simple array
reversal — exact, no arithmetic re-derivation), then another marker, then
a short, explicit demonstration of the map's actual invertibility: the
last several forward points, recovered by applying the exact inverse-map
formula backwards and confirmed against the already-known preceding
points. Kept deliberately short (10 steps by default) — see "The forward
map contracts area..." above for why a much longer version would stop
meaning what it claims to mean.

**Best for:** hearing (and seeing, in the static PNG) direct proof that
this map — unlike `dynamical/`'s logistic map — can be run backwards
exactly.

## Sonification mapping

| Mode | Pitch | Pan | Volume |
|---|---|---|---|
| `attractor` | `y_n` (stem-core's default pitch axis) | `x_n` (stem-core's default pan axis) | 2D finite-difference speed |
| `sweep` | `x_n` (rescaled per-run over the actual sweep's x range) | `y_n` (rescaled per-run over the actual sweep's y range) | Step-to-step distance |
| `reverse` | `x_n` (same convention as sweep) | `y_n` (same convention as sweep) | Step-to-step distance |

`attractor`'s pitch/pan assignment is the OPPOSITE of `sweep`/`reverse`'s
— not an inconsistency; see `AGENTS.md` design decisions 3-4 for why each
mode's mapping was chosen independently for its own sonification
technique.

## Correctness checks

All four run unconditionally, every invocation, regardless of mode,
always at canonical `(a,b)=(1.4,0.3)` (diagnostic-only: print
`[PASS]`/`[FAIL]`, never abort):

1. **Constant Jacobian determinant** — `det = -b` identically, verified
   at several arbitrary (off-attractor) points. An exact algebraic
   identity, tight tolerance.
2. **Lyapunov exponent sum** — `lambda1 + lambda2 = log(b)` exactly, a
   direct consequence of check 1, computed via the standard QR-based
   method for 2D maps. Tight tolerance.
3. **Largest Lyapunov exponent vs. literature benchmark** — positive
   (the chaos signature), within 30% of the commonly-cited `≈0.42`.
   Generous tolerance deliberately: this is an empirical comparison, not
   an exact relation (see `AGENTS.md` design decision 7).
4. **Inverse map exactness** — forward-then-inverse round trip on random
   test points recovers the original to near machine precision. Tight
   tolerance; this is what `reverse` mode's core claim depends on.

The box-counting fractal dimension estimate (`attractor` mode's summary)
is printed as an informational figure only, never gated — dimension
estimates from a finite point set carry real methodological uncertainty.
The sweep's Feigenbaum-like ratio (`≈4.75` vs. the universal `4.6692`) is
similarly informational.

## Outputs

| File | Description |
|------|-------------|
| `output/henon_attractor.wav` | Narrated continuous-trajectory sonification |
| `output/henon_attractor.gif` | Growing point-cloud animation on the native (x,y) plane |
| `output/henon_attractor.png` | Full static attractor, fractal structure visible |
| `output/henon_attractor.csv` | Per-iterate: n, x, y, pitch (Hz), pan, volume (dB) |
| `output/henon_sweep.wav` | Discrete-note sweep audio with 3 landmark events |
| `output/henon_sweep.gif` | Animated bifurcation diagram with moving cursor |
| `output/henon_sweep.png` | Static full bifurcation diagram |
| `output/henon_sweep.csv` | Per-note: a, iteration index, x_n, y_n, pitch, pan, volume, event label |
| `output/henon_reverse.wav` | Forward / reversed / inverse-demo three-phase audio |
| `output/henon_reverse.png` | Overlay: full forward path, highlighted subsequence, recovered inverse points |
| `output/henon_reverse.csv` | Per-point: n, x, y, direction (forward/reversed/inverse_demo) |

## Configuration parameters (`henon/config.json`)

| Key | Default | Used by |
|-----|---------|---------|
| `simulation.mode` | `"attractor"` | all |
| `simulation.henon.a` / `b` | `1.4` / `0.3` | attractor, reverse (and the fixed `b` for sweep) |
| `simulation.henon.x0` / `y0` | `0.1` / `0.1` | all (initial condition before the transient) |
| `simulation.henon.n_transient` | `500` | all |
| `simulation.henon.n_points` | `2000` | attractor |
| `simulation.henon.a_min` / `a_max` | `0.2` / `1.4` | sweep |
| `simulation.henon.a_steps` | `250` | sweep |
| `simulation.henon.n_attractor` | `40` | sweep (settled points recorded per step) |
| `simulation.henon.n_forward` | `40` | reverse |
| `simulation.henon.reverse_steps` | `10` | reverse (see the area-expansion caveat above) |
| `simulation.henon.note_duration` | `0.08` | sweep, reverse |

## Project structure

```
henon/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl         — 7 curated preset invocations
  config.json             — App defaults
  LISTENING_GUIDE.md       — Recommended listening sequence
  src/
    model.wl               — HenonMap/HenonMapInverse, Jacobian, Lyapunov exponents
                            (QR method), bifurcation landmarks, box-counting dimension,
                            four correctness checks, per-mode model builders
    sonify.wl                — lorenz-style continuous trajectory (attractor),
                            dynamical-style discrete notes (sweep, reverse)
    speech.wl                 — Spoken intro synthesis and per-mode intro text
    animate.wl                  — Per-mode GIF/PNG renderers
    output.wl                     — CSV export and console summaries
  tests/
    test_model.wl                — Unit tests
  output/                          — Output files (not committed)
  README.md
  AGENTS.md
```

## Connection to `lorenz/` and `dynamical/`

`henon/` sits directly between these two apps. Its `attractor` mode
reuses `lorenz/`'s continuous-trajectory sonification technique because
the Hénon map is literally derived from a Poincaré section of the Lorenz
system (see "A concrete link to `lorenz/`" above). Its `sweep` mode reuses
`dynamical/`'s discrete note-per-iterate idiom because the map's own
period-doubling route to chaos deserves the same audibly-countable
rhythm treatment `dynamical/sweep` gives the logistic map — see
`AGENTS.md` design decision 1 for why these two choices, on their
surface a contradiction, are each the right tool for their own mode.

## Console output

Step numbers `[1/5]` through `[5/5]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements in
addition to the intro:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

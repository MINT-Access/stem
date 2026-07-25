# Mandelbrot — The Mandelbrot and Julia Sets

Sonifies the Mandelbrot set, its Julia-set counterparts, and the
self-similar structure of its boundary at successively deeper
magnifications — via the same Hilbert-curve spatial traversal
[`images/`](../images/README.md) and [`cosmology/sky`](../cosmology/README.md)
use to turn 2D fields into audio without destroying spatial locality.

**New to this app?** Start with
[`mandelbrot/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — the recommended
listening sequence across all three modes.

## The mathematics

### The set

For a complex parameter `c`, iterate `z_{n+1} = z_n^2 + c` starting
from `z_0 = 0`. The point `c` belongs to the Mandelbrot set if this
sequence stays bounded forever; otherwise it escapes to infinity, and
the number of iterations before escape (capped at `max_iterations`) is
the field this app sonifies and renders.

### The escape radius — derived, not received wisdom

Every popular account cites "radius 2" as the escape threshold. This
app derives it: if `|z_n| > 2` and `|z_n| >= |c|` (which holds
automatically within the standard `|c| <= 2` viewing region, once
`|z_n|>2`), then

    |z_{n+1}| = |z_n^2 + c| >= |z_n|^2 - |c| >= |z_n|^2 - |z_n| = |z_n|(|z_n|-1)

and since `|z_n| > 2` means `|z_n| - 1 > 1`, this gives
`|z_{n+1}| > |z_n|` — strictly increasing, hence diverging. Verified
directly (not just algebraically): six `(c,z)` pairs satisfying the
hypothesis all show `|z_{n+1}| > |z_n|` exactly as predicted (see
Correctness checks below). The whole Mandelbrot set consequently lies
within `|c| <= 2` — at `n=1`, `z_1 = c` already satisfies the escape
hypothesis if `|c| > 2` — which is why the standard viewing window
(real `[-2, 0.5]`, imaginary `[-1.25, 1.25]`) comfortably contains the
entire set: every corner of that window satisfies `|c| <= 2`.

### Julia sets — what one point of the Mandelbrot set actually means

For a *fixed* `c`, the Julia set is the boundary between starting
points `z_0` that escape under the same iteration and those that
don't. The deep connection to the Mandelbrot set: **`c` inside the
Mandelbrot set gives a connected Julia set; `c` outside gives a
disconnected one** ("Fatou dust"). `julia` mode's whole purpose is
making this concrete — a single point of the Mandelbrot set, expanded
into its own fractal.

### The main cardioid's exact boundary — derived

Worth deriving rather than citing: fixed points of `z -> z^2+c`
satisfy `z = z^2+c`, i.e. `c = z - z^2`. Stability of that fixed point
requires `|f'(z)| = |2z| < 1`; the boundary of stability is `|2z|=1`,
i.e. `z = Exp[I*theta]/2`. Substituting back gives the exact
parametric boundary of the main cardioid:

    c(theta) = Exp[I*theta]/2 - Exp[2*I*theta]/4

confirmed symbolically (`Simplify[(z-z^2) - c(theta)] === 0` at
`z=Exp[I theta]/2`) before being trusted anywhere in this app.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically
- Optional for the spoken intro: macOS `say` (built in), Linux
  `espeak-ng`/`espeak`, or Windows PowerShell (built in) — falls back
  to text-only output if none is available

## Quick start

```sh
# Mandelbrot mode (default): the classic set
wolframscript -file main.wl

# Julia mode: fixed c, sweep z0 — what one point of the set means
wolframscript -file main.wl -- --simulation.mode=julia

# Zoom mode: four successively deeper levels, same boundary point
wolframscript -file main.wl -- --simulation.mode=zoom

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Modes

### mandelbrot (default)

The classic set over the standard viewing window, computed on a grid,
traversed via `HilbertTraversalOrder` (from `stem-core`, shared with
`images/` and `cosmology/sky`), sonified using `images/`'s own
brightness-to-frequency log-mapping technique — iteration count
standing in for "brightness." Slow-escaping/non-escaping points map to
the high end of the frequency range, fast-escaping points to the low
end (a deliberate sonification choice, not a physical fact — see
`AGENTS.md`).

**Best for:** the flagship view — hear the boundary's complexity
directly, quantified by correctness check 4 below.

### julia

A fixed `c` (default `-0.123+0.745i`, the "Douady rabbit" —
**verified**, not assumed, to be genuinely inside the Mandelbrot set
and to produce a rich, connected structure; see `AGENTS.md` design
decision 2 for why the more commonly-cited `-0.7+0.27015i` was
rejected after verification showed it is actually *outside* the set),
sweeping `z_0` over the grid instead of `c`. The spoken intro states
the connectivity fact directly for whatever `c` is configured.

**Best for:** understanding what a single point of the Mandelbrot set
actually represents — its own, differently-shaped fractal.

### zoom

Renders the Mandelbrot boundary at four successively deeper
magnification levels (1x, 4x, 16x, 64x by default), all centred on the
same point — a well-documented "seahorse valley" coordinate
(`-0.743643887037151+0.131825904205330i`) on the boundary near the
main-cardioid/period-2-bulb junction, **verified** to show sustained
genuine fine structure across every level (55-141 distinct
iteration-count values per level on a test grid, not a flat or
featureless region at any level — see `AGENTS.md` design decision 4).

**Best for:** hearing self-similarity directly — the boundary's
chaotic, rapid pitch variation sounds similarly rich at every zoom
level, not smoother or simpler as you go deeper.

## Correctness checks

All four run unconditionally, every invocation, regardless of mode,
always at fixed canonical parameters (diagnostic-only: print
`[PASS]`/`[FAIL]`, never abort):

1. **Escape radius, derived and directly verified** — six `(c,z)`
   pairs satisfying `|z|>2, |z|>=|c|, |c|<=2` all confirmed to give
   `|z_{n+1}|>|z_n|` by direct computation, not a restatement of the
   "radius=2" convention.
2. **Known membership facts, exact** — `c=0` stays exactly `0` forever;
   `c=-1` enters an exact period-2 cycle (`0,-1,0,-1,...`), verified
   never to escape; `c=1` escapes (`0,1,2,5,26,677,...`), verified to
   exceed the escape radius.
3. **Main cardioid boundary, exact** — three points straddling the
   derived boundary (on it, 10% further out, 10% further in, at a
   verified-clear angle away from bulb-attachment cusps): the boundary
   and inside points both stay non-escaping within a 300-iteration
   budget; the outside point escapes in 10 iterations — dramatically
   faster.
4. **"The boundary has the highest local complexity," quantified** —
   the mean `|delta(iteration count)|` between Hilbert-adjacent pixels,
   measured separately in deep interior, boundary, and far exterior
   regions of the default `mandelbrot`-mode field: interior `18.5`,
   boundary `99.1`, exterior `1.7` — the boundary is **5.4x** the
   interior and **57.7x** the exterior, turning this app's own headline
   claim into a verified, quantified fact about the actual field it
   generates.

## Outputs

| File | Description |
|------|-------------|
| `output/mandelbrot_mandelbrot.wav` | Per-pixel notes, Hilbert order, orientation clicks |
| `output/mandelbrot_mandelbrot.gif` | Animated Hilbert traversal path across the rendered set |
| `output/mandelbrot_mandelbrot.png` | The full rendered Mandelbrot set |
| `output/mandelbrot_mandelbrot.csv` | Hilbert index, c_real, c_imag, iteration count |
| `output/mandelbrot_julia.wav` | Same per-pixel technique, swept over z0 instead of c |
| `output/mandelbrot_julia.gif` | Animated Hilbert traversal across the rendered Julia set |
| `output/mandelbrot_julia.png` | The full rendered Julia set |
| `output/mandelbrot_julia.csv` | Hilbert index, z0_real, z0_imag, iteration count |
| `output/mandelbrot_zoom.wav` | One combined WAV, a chime marks each new zoom level |
| `output/mandelbrot_zoom.gif` | Cycles through all zoom levels |
| `output/mandelbrot_zoom.png` | All levels shown side by side |
| `output/mandelbrot_zoom.csv` | Level, magnification, Hilbert index, iteration count |

## Configuration parameters (`mandelbrot/config.json`)

| Key | Default | Used by |
|-----|---------|---------|
| `simulation.mode` | `"mandelbrot"` | all |
| `simulation.mandelbrot.max_iterations` | `300` | all |
| `simulation.mandelbrot.grid_size` | `64` (must be a power of 2) | all |
| `simulation.mandelbrot.julia_c_real` / `julia_c_imag` | `-0.123` / `0.745` | julia |
| `simulation.mandelbrot.zoom_center_real` / `zoom_center_imag` | `-0.743643887037151` / `0.131825904205330` | zoom |
| `simulation.mandelbrot.zoom_levels` | `4` | zoom |

## Project structure

```
mandelbrot/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl         — 7 curated preset invocations
  config.json              — App defaults
  LISTENING_GUIDE.md         — Recommended listening sequence
  src/
    model.wl                  — Escape iteration, main-cardioid derivation,
                            four correctness checks, three per-mode model
                            builders
    sonify.wl                   — images/'s brightness-to-frequency log
                            mapping and orientation-click pattern, reused
                            directly for iteration-count fields
    speech.wl                     — Spoken intro synthesis and per-mode intro text
    animate.wl                      — Hilbert-traversal path animation
                            (images/animate.wl's own pattern, reused),
                            iteration-count-to-colour field rendering
    output.wl                       — CSV export and console summaries
  tests/
    test_model.wl                  — Unit tests
  output/                            — Output files (not committed)
  README.md
  AGENTS.md
```

## Connection to `images/` and `cosmology/sky`

`mandelbrot/` is the third consumer of `stem-core`'s
`HilbertTraversalOrder` — the same locality-preserving traversal
`images/` uses to sonify photographs and `cosmology/sky` uses to
sonify simulated CMB temperature maps. All three apps share the same
underlying idea: a 2D field (grayscale brightness, temperature
anisotropy, or here, escape-iteration count) becomes a 1D audio stream
without destroying spatial structure, because Hilbert-adjacent pixels
in the traversal are also spatially adjacent in the field. `mandelbrot`
mode reuses `images/`'s exact brightness-to-frequency log-mapping
formula and its orientation-click convention; only the underlying
field differs.

## Console output

Step numbers `[1/5]` through `[5/5]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements in
addition to the intro:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

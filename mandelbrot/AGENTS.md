# Mandelbrot — Agent Guide

## Project overview

Sonifies the Mandelbrot set, its Julia-set counterparts, and boundary
self-similarity at successive zoom levels, via the same Hilbert-curve
traversal `images/` and `cosmology/sky` already use. Realizes the
`mandelbrot/` idea from `docs/V1.5.0_APP_IDEAS.md`. Three modes:

| Mode | Field | Output |
|------|-------|--------|
| `mandelbrot` (default) | Escape-iteration count vs c, over the classic viewing window | Per-pixel Hilbert-order notes; traversal GIF; full-set PNG |
| `julia` | Escape-iteration count vs starting z0, fixed c | Same technique; Julia-set PNG |
| `zoom` | Same field, 4 successively deeper magnifications, one centre | Combined WAV with level chimes; multi-level GIF/PNG |

Closest sibling apps: `images/` (the brightness-to-frequency log
mapping and orientation-click pattern, reused directly — this app's
`sonify.wl` and `animate.wl` are both close derivatives of `images/`'s
own) and `cosmology/sky` (the other existing `HilbertTraversalOrder`
consumer, confirming the traversal generalizes cleanly beyond
photographs to any 2D scalar field).

## Key design decisions (read before modifying sonify.wl or model.wl)

### 1. The escape-radius argument — verified directly, not just algebraically plausible

The standard "escape radius 2" is usually stated as received wisdom.
This app derives it (`|z_n|>2` and `|z_n|>=|c|`, within `|c|<=2`,
implies `|z_{n+1}|>|z_n|` strictly — see README for the full algebra)
and then VERIFIES the conclusion directly: six `(c,z)` test pairs
satisfying the hypothesis, confirmed by direct computation to give
`|z_{n+1}|>|z_n|` in every case (`EscapeRadiusCheck`, correctness check
1). This also gives, for free, why the standard viewing window
(`[-2,0.5] x [-1.25,1.25]`) comfortably contains the whole set: at
`n=1`, `z_1=c`, so `|c|>2` alone already satisfies the escape
hypothesis trivially (`|z_1|=|c|>2` and `|z_1|>=|c|` automatically) —
the entire set lies within `|c|<=2`, and every corner of the standard
window satisfies that bound.

### 2. Julia default c: -0.123+0.745i (Douady rabbit), NOT the commonly-cited -0.7+0.27015i — a genuine correction, verified before use

The build brief suggested `-0.7+0.27015i` as "a reasonable default,"
explicitly asking for verification before committing to it. That
verification found a real problem:

```
MandelbrotEscapeIterations[-0.7+0.27015 I, 100] = 96   (escapes!)
MandelbrotEscapeIterations[-0.7+0.27015 I, 1000] = 96
MandelbrotEscapeIterations[-0.7+0.27015 I, 10000] = 96
MandelbrotEscapeIterations[-0.7+0.27015 I, 100000] = 96
```

Escaping at EXACTLY iteration 96, independent of the iteration budget
— this point is genuinely OUTSIDE the Mandelbrot set, not merely slow
to resolve. Per the Mandelbrot-Julia connectivity theorem this app's
own `julia` mode exists to illustrate, that means its Julia set is
technically DISCONNECTED ("Fatou dust"), the opposite of what a
"connected Julia set" default example needs to be. (It is still a
famous, widely-circulated value — likely because Cantor-dust Julia
sets for c just outside the Mandelbrot set can still look
visually rich at finite rendering resolution — but it does not
demonstrate the connectivity story this app's build brief itself
wanted featured.)

Replacement, found by testing several classic candidates and checking
each one's actual boundedness at high iteration budgets:
`c=-0.123+0.745i`, the "Douady rabbit," confirmed:
- Bounded through 100,000 iterations (genuinely inside the set).
- Safely interior, not a knife-edge point: perturbing by `+-0.001` in
  every direction (real, imaginary, both) remains bounded through
  5,000 iterations.
- Rich structure: 31 distinct escape-iteration values over a 64x64
  test grid at `maxIter=300` (not degenerate/near-uniform).

### 3. The main cardioid boundary check needed the RIGHT perturbation direction, and a bulb-cusp-aware choice of test angle — both discovered during derivation

Naively perturbing a boundary point `c(theta)` by SCALING it toward or
away from the complex-plane origin (`c(theta)*1.02`, etc.) gave
wildly inconsistent, non-monotonic results across different `theta` —
some angles showed a clean transition, others showed the "further
out" point STILL failing to escape (see the derivation transcript:
`theta=1.0` gave 10-25 iterations for a 2-5% outward scale, but
`theta=0.5` and `theta=2.0` stayed at max iterations even at a 5%
scale). Root cause: the cardioid is not centred at the origin, so
radial scaling from the COMPLEX-PLANE origin does not correspond to
moving in a consistent direction relative to the cardioid's own local
boundary — and near `theta=0` and `theta=Pi` (where the period-2 bulb
and other bulbs attach to the cardioid), a point pushed "outward" from
the plane origin can land INSIDE a neighbouring bulb instead of truly
outside the whole set.

Fix: use the derivation's OWN natural parametrization instead —
`z = r*Exp[I*theta]`, `c = z - z^2`, boundary at `r=0.5`
(`MainCardioidPointFromR`). Perturbing `r` (not scaling `c` from the
plane origin) by `+-10%` at a verified-clear `theta=1.0` (away from
the `0`/`Pi` cusps) gives a clean, robust result: on-boundary and
10%-inside both stay at `maxIter=300`; 10%-outside escapes in `10`
iterations. This is `MainCardioidBoundaryCheck`'s actual implementation.

### 4. Zoom centre: a verified "seahorse valley" coordinate, chosen by directly measuring sustained complexity across levels

Rather than assuming any boundary point shows rich structure at every
zoom depth, several candidate centres were tested by computing the
iteration-count field at 4 successive 4x-magnification levels and
measuring the number of distinct values per level (a proxy for visual/
audible richness):

```
seahorse valley (-0.743643887037151, 0.131825904205330):
  level 0 (halfWidth=1.5):      56 distinct values
  level 1 (halfWidth=0.375):    83 distinct values
  level 2 (halfWidth=0.09375): 109 distinct values
  level 3 (halfWidth=0.0234):  141 distinct values
```

Genuine, SUSTAINED (in fact growing) richness across every level —
confirming self-similarity is actually present at this specific
coordinate and magnification range for this app's grid resolution, not
merely assumed from the coordinate's general reputation. `zoom_levels`
defaults to 4 (within the build brief's suggested 2-4 range);
`$zoomBaseHalfWidth=1.5` at level 1, shrinking by exactly 4x per level.

### 5. Iteration-count-to-frequency direction is a documented sonification CHOICE, not a physical fact

Unlike `images/`'s brightness (a real photometric quantity with an
obvious "dark to light" direction), iteration count has no inherent
"low to high" meaning as a frequency mapping — this app's own
convention (slow-escaping/non-escaping points map HIGH, fast-escaping
points map LOW) is stated explicitly as a choice in the README and
here, not implied to be somehow physically motivated. The choice made
mirrors `images/`'s own "dark=low pitch, bright=high pitch" convention
by treating higher iteration counts as "brighter" (closer to the set),
consistent with how most Mandelbrot renderers colour long-escaping
points as visually distinct/bright too.

### 6. PNG export bugs caught by actually viewing the rendered files, not just checking for runtime errors

Two real bugs were caught only by reading the actual output images
during development, not by the code running without error:
- An early `AnimateAndExportField` exported the raw `Image` object
  directly (`Export[outPNG, img, "PNG"]`), which writes it at its
  native `size x size` pixel dimensions (e.g. 64x64) — technically
  correct but far too small to view comfortably. Fixed by wrapping in
  a `Graphics`/`Raster` call with `ImageSize->512` before export,
  matching the GIF frames' own already-upscaled rendering.
- An early `AnimateZoom`'s combined PNG used `ImageAssemble` +
  `ImageCompose[img, Text[...]]` to label each level — this produced
  visibly GARBLED, overlapping text fragments when actually viewed (not
  a runtime error, the code ran fine). Fixed by switching to
  `GraphicsGrid` built from the same `Graphics`/`Raster`+`Text` frame
  construction the (already correctly labelled) GIF frames use — a
  single, consistent, verified-working rendering path for both GIF and
  combined PNG.

Neither bug would have been caught by running the correctness checks
or unit tests alone — both are exactly the kind of thing this
project's "actually view the rendered PNGs/GIFs, don't just trust the
code" discipline exists to catch.

## Numeric findings from this build session (new results, not assumed in advance)

- **Boundary complexity, quantified** (default 64x64 grid,
  `maxIter=300`): mean `|delta(iteration count)|` between
  Hilbert-adjacent pixels — interior `18.48`, boundary `99.14`,
  exterior `1.72`. Boundary is `5.4x` the interior and `57.7x` the
  exterior.
- **Main cardioid boundary check** (`theta=1.0`, `maxIter=300`):
  on-boundary and 10%-inside both non-escaping (300/300); 10%-outside
  escapes in `10` iterations.
- **Julia default** verified genuinely interior (bounded to 100,000
  iterations) and safely so (small perturbations in all directions
  remain bounded to 5,000 iterations); the commonly-cited alternative
  verified genuinely exterior (escapes at iteration 96, independent of
  budget).
- **Zoom centre**: sustained complexity across 4 levels, `56` to `141`
  distinct iteration-count values per level (growing, not shrinking,
  with depth).

## Project structure

```
mandelbrot/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json            — default simulation parameters
  experiments.wl          — 7 curated preset invocations
  LISTENING_GUIDE.md       — user-facing recommended listening sequence
  AGENTS.md                 — this file
  src/
    model.wl                 — Escape iteration (Mandelbrot + Julia), main-
                          cardioid derivation, GridToComplex, four
                          correctness checks, three per-mode model builders
    sonify.wl                  — IterationToFreq (images/'s BrightnessToFreq,
                          duplicated), AddQuadrantClicks (duplicated),
                          shared per-pixel note-stream builder
    speech.wl                    — Spoken intro synthesis and per-mode intro text
    animate.wl                     — IterationToColor, FieldToImage,
                          Hilbert-traversal path animation (images/'s own
                          pattern, reused), zoom-level GraphicsGrid
    output.wl                       — CSV export and console summaries
  tests/
    test_model.wl                  — Unit tests (escape iteration, cardioid
                          derivation, GridToComplex, all four correctness
                          checks, Julia/zoom centre verification, model
                          builders)
  output/                           — generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                     # mandelbrot, standard window
wolframscript -file main.wl -- --simulation.mode=julia            # fixed c, sweep z0
wolframscript -file main.wl -- --simulation.mode=zoom              # 4 levels, seahorse valley
wolframscript -file main.wl -- --simulation.mandelbrot.grid_size=128
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks

All four run unconditionally, every invocation, regardless of mode,
always at fixed canonical parameters (independent of the active
mode's own configured c/centre/window):

1. **Escape radius** — see design decision 1. Direct verification, six
   test pairs.
2. **Membership facts** — `c=0`, `c=-1`, `c=1`, all exact.
3. **Main cardioid boundary** — see design decision 3. Three points,
   verified-clear test angle.
4. **Boundary complexity, quantified** — see design decision 4's
   sibling numeric findings above.

## Common pitfalls

1. **Radially scaling a boundary point from the complex-plane origin
   does not reliably move "outward" relative to a non-circular curve
   like the cardioid** — see design decision 3. Use the derivation's
   own natural parametrization (here, `r` in `z=r*Exp[I theta]`) for
   any "just inside/outside the boundary" perturbation test.
2. **Radial perturbations near bulb-attachment cusps (theta near 0 or
   Pi for the main cardioid) can land inside a DIFFERENT component of
   the Mandelbrot set** — see design decision 3. Pick a test angle
   verified clear of such cusps.
3. **Exporting a raw small `Image` object writes it at native
   resolution, not the display size a GIF/Graphics wrapper implies** —
   see design decision 6. Always wrap in `Graphics`/`Raster` with an
   explicit `ImageSize` before `Export`-ing a PNG meant to be viewed
   directly.
4. **`ImageAssemble`/`ImageCompose` with `Text[...]` labels can produce
   garbled, overlapping output that only shows up by actually viewing
   the file** — see design decision 6. Prefer `GraphicsGrid` built from
   the same `Graphics`/`Raster`+`Text` construction already verified to
   work for GIF frames.
5. **A famous, widely-cited constant is not automatically verified for
   YOUR specific use case** — see design decision 2. The commonly-cited
   Julia `c` value turned out to be the wrong choice for a "connected
   Julia set" default specifically, despite being a completely
   legitimate and popular value in general.
6. **`tolerance_?NumericQ:0.05`-style optional-argument patterns parse
   WRONG** in WL — binds as `tolerance_ ? (NumericQ:0.05)`, not
   `Optional[tolerance_?NumericQ, 0.05]`. Same pitfall documented in
   every prior v1.5.0/v1.6.0 app's `AGENTS.md`; avoided throughout via
   explicit `Optional[x_?NumericQ, default]`.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `HilbertTraversalOrder`, `StemSynthNote`, `STEMHeading`,
  `STEMSection`, `STEMSay`, `STEMPrintN`, `STEMDescribeWAV`,
  `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`, `STEMPlayCmd`,
  `NormalizeBuffer`, `ExportGIF`, `ExportCSV`, `EnsureDir`.
- **Mathematica/WL**: `Hue` (field-to-colour rendering), `Graphics`,
  `Raster`, `GraphicsGrid` (rendering and export), `Sound`,
  `SampledSoundList`, `Export`, `SpeechSynthesize`, `AudioQ`,
  `AudioData`, `AudioSampleRate`, `RunProcess` (platform TTS
  fallback), `Import` (reading TTS-generated WAV files).

## Speech synthesis note

`speech.wl`'s three-tier fallback (`SpeechSynthesize[]` -> platform TTS
-> text-only `STEMSay`) duplicates the pattern already used in
`quantum_statistics/src/speech.wl` and every other app's `speech.wl`
file — still out of scope for stem-core consolidation per every prior
app's own build spec.

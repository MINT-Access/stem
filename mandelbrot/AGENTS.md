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

### 7. Native grid resolution, not just export ImageSize, drives visible pixelation at presentation scale — measured, not assumed

For LinkedIn/workshop use, `mandelbrot`/`julia` PNGs (native `size x
size`, e.g. 64x64 by default) are exported via `Graphics`/`Raster` at a
FIXED `ImageSize->512` (`AnimateAndExportField`) regardless of native
grid resolution, then often scaled further (e.g. to 1080x1080) for
video. Both upscaling steps are nearest-neighbour on the native grid's
cells, so blockiness at final display size is a function of native
`grid_size`, not of `ImageSize`. Measured directly (rendering the same
window at `grid_size in {64,128,256,512}`, exported to a 1080x1080
canvas): 64 shows clearly blocky cell edges at that scale; 128 is
meaningfully smoother; 256 is smooth with only fine-boundary blockiness
remaining; the *compute+export* cost for the field/PNG alone is trivial
at every size tested (2-5 seconds, even at 256).

The real cost that scales with `grid_size` is NOT rendering — it's
`sonify.wl`'s one-note-per-pixel audio, since `nPixels = grid_size^2`
drives `BuildFieldAudio`'s total note count directly. Measured via the
full `main.wl` pipeline (audio+GIF+PNG together): `grid_size=64`
(default) gives an 80s WAV; `128` gives ~265s (4.4 min); `256` gives
~1003s (16.7 min); `512` gives ~3954s (65.9 min) AND the GIF-rendering
step (a 7900+-frame animation with a 262144-point growing traversal
line) crashed the Wolfram kernel outright during testing ("The product
exited for an unknown reason").

**Conclusion, not a code change**: `grid_size` is a genuine visual/
audio-length trade-off, not a "just raise the default" fix, because one
field drives both outputs. Recommended: `grid_size=128` as a per-render
override (via CLI flag or an `experiments.wl`-style preset, as
`julia_fine_grid` already does) for presentation-focused renders —
meaningfully sharper, audio still a reasonable ~4.4 minutes, compute
trivial. `256` is viable specifically when only the PNG matters (the
audio/GIF from that same run would be impractically long to actually
use). `512` should be avoided outright — both the audio length and the
GIF-rendering crash make it impractical with the current per-pixel
audio/GIF-traversal-line approach. The global default of `64` is left
unchanged, since it is tuned for a reasonable *default* listening
experience, not presentation video specifically.

### 8. Escape-gradient color mode: smooth iteration count, picked by rendering candidates and viewing them, not by assertion

`color_scheme="escape_gradient"` (config key
`simulation.mandelbrot.color_scheme`, alongside the default
`"high_contrast"`) is a second, purely additive rendering option for
`mandelbrot`, `julia`, and `zoom` — the flat black-interior/light-blue-
exterior default described in `README.md` stays pixel-identical
(directly verified: `ImageData[img1] === ImageData[img2]` after
regenerating the default `mandelbrot_mandelbrot.png` before and after
this feature was added — checksums differed only because Wolfram's PNG
`Export` embeds a timestamp chunk; actual pixel data was `True` for
equality, max abs diff `0`).

**Why smooth iteration count, not raw integer count.** A naive
integer-`n`-to-color mapping produces hard bands — every pixel that
escapes at the same integer iteration gets the exact same color,
visible as concentric rings with sharp edges. The standard fix,
implemented here (`model.wl`'s `SmoothIterationCount`), renormalizes
using how far *past* the bailout radius the point actually landed at
escape:

```
nu = n + 1 - Log[Log[Abs[z_n]]] / Log[2]
```

This requires the iteration loop to return the escape magnitude
`Abs[z_n]`, which the sonification-only `MandelbrotEscapeIterations`/
`JuliaEscapeIterations` discard. Rather than modify those two
functions (and risk the sonification pipeline, which depends only on
the integer count), two SEPARATE functions were added —
`MandelbrotEscapeSmooth`/`JuliaEscapeSmooth`, returning `{n, absZ}` —
duplicating the same iteration loop verbatim. The original two
functions are untouched, byte-for-byte, so the sonification/CSV output
is provably unaffected (also verified directly, not just by
construction: `sha256` of `mandelbrot_mandelbrot.wav`/`.csv`,
`mandelbrot_julia.wav`/`.csv`, and `mandelbrot_zoom.wav`/`.csv` are
identical whether `color_scheme` is `"high_contrast"` or
`"escape_gradient"`, for all three modes).

**Palette choice — three candidates rendered and compared, not picked
arbitrarily.** All three were rendered at the SAME test window before
choosing:
1. A cyclic HSV rainbow hue sweep (`Hue[Mod[nu,cyc]/cyc, 0.8, 0.95]`) —
   rejected: at this field's actual nu distribution (most exterior
   pixels escape within a handful of iterations, so most of the canvas
   sits in a narrow nu range), the result looked almost as flat as the
   high_contrast default, with only a thin multicolor fringe right at
   the boundary — none of the "rich, continuous" look the feature
   exists to add.
2. A discrete color LUT (6 anchor colors, linearly interpolated) —
   visually fine at the boundary but the background stayed dominated by
   a single LUT segment (mostly navy blue) across most of the open
   exterior, since low-nu pixels never reach the LUT's later anchors.
3. **Chosen**: a continuous cosine palette (Inigo Quilez's
   `color(t) = a + b*Cos[2 Pi (c t + d)]` technique, per-RGB-channel),
   evaluated on `nu` with a 18-iteration cycle length
   (`$EscapeGradientCycleLength` in `animate.wl`) — gives a genuinely
   smooth blue -> deep-orange/gold -> yellow -> green -> blue sweep
   across BOTH the open exterior (where it evokes the classic warm
   Mandelbrot-render backdrop) and the boundary fringe (fine multicolor
   detail directly on the fractal edge). Verified banding-free by
   rendering a zoomed crop directly on a boundary spiral (`-0.85` to
   `-0.65` real, `0.05` to `0.25` imag, `grid_size=256`) and confirming
   the color transition is fully continuous — no hard edges — by
   direct visual inspection of the actual exported PNG, consistent with
   this project's "view the rendered file, don't just trust the
   formula" discipline (see design decision 6).

Interior (non-escaping) points are always solid black under
`escape_gradient` too — there is no escape magnitude for them to
renormalize from, and black stays visually distinct from every
gradient color (the palette's darkest tone is a deep blue, never
black).

**Where it's wired in.** `MandelbrotModel`/`JuliaModel`/`ZoomModel`
(`model.wl`) read `color_scheme` from config and populate a
`"smoothField"` key (via `MandelbrotSmoothField`/`JuliaSmoothField`)
ONLY when `color_scheme="escape_gradient"` — the default path never
computes it, so it costs nothing when unused. `animate.wl`'s
`FieldToImage` takes `colorScheme`/`smoothField` as trailing `Optional`
arguments defaulting to `"high_contrast"`/`{}`, so every pre-existing
call site with the original 4-argument signature is unaffected;
`AnimateFieldTraversal`/`AnimateAndExportField`/`AnimateZoom` thread
the same two values through from the model association. `main.wl`/
`experiments.wl` needed NO changes at all — they already just pass the
model association through to these functions.

### 9. Animation pacing: an explicit, independent duration cap (decoupling resolution from playback duration)

A real problem surfaced producing a LinkedIn video from a `grid_size=128`
escape-gradient render (`max_iterations=1000`, the `high_iter` preset):
`nPixels=16384` at the standard `0.015`s/note (`sonify.wl`, unchanged,
out of scope) gives a `264.7`s WAV — and since `AnimateFieldTraversal`'s
whole *purpose* (see "GIF/WAV duration sync" below) is pacing the GIF to
match `targetDuration` EXACTLY, the resulting GIF was also `264.5`s
(529 frames), a 500MB+ GIF and a video far outside the 20s-2min range
these clips are supposed to land in. Resolution (`grid_size`, hence
`nPixels`) and playback duration were coupled through the WAV, with no
way to raise one without the other.

**Why this couldn't be "just fix the formula" inside the existing
duration-sync contract.** `AnimateFieldTraversal`'s duration = exactly
`targetDuration` design is not a bug — it's the actual point of the
post-v1.5.0 fix below (a listener watching the GIF while playing the
WAV needs them to finish together). Simply capping `targetDuration`
unconditionally for every caller would SILENTLY BREAK that sync for
every already-shipped preset whose natural duration exceeds the cap —
`zoom_default` alone sits at `115.5`s, already close to a "keep it
under 2 minutes" ceiling; capping there would reintroduce the exact
class of bug the sync fix eliminated. The fix therefore could not be a
new unconditional default.

**The fix.** `AnimateFieldTraversal`/`AnimateAndExportField`/
`AnimateZoom` (`animate.wl`) gained a new trailing `Optional`
parameter, `maxDurationSec` (default `$DefaultMaxAnimationDurationSec`,
a large FINITE sentinel — see the pitfall below for why not
`Infinity`). Internally, pacing is computed against
`Min[targetDuration, maxDurationSec]`, not `targetDuration` directly.
With the default, `Min[...]` is always `targetDuration` — EVERY
existing caller (`main.wl`, `experiments.wl`) is completely unaffected,
verified directly: regenerated the default `mandelbrot`/`julia`/`zoom`
presets after this change and confirmed `sha256`-identical WAV and
pixel-identical PNG output versus pre-change baselines. A caller that
DOES want a capped, presentation-length GIF (independent of how large
`grid_size` made the matching WAV) passes an explicit `maxDurationSec`,
e.g. `AnimateAndExportField[model, outGIF, outPNG, trueWavDuration,
150, 80.0]` — the traversal still reveals EVERY pixel (no resolution
lost, `frameUpTo` still spans the full `nPixels`), just within a
shorter window at a correspondingly higher frame rate. This is a
genuinely independent, reusable knob — usable by ANY future preset at
ANY `grid_size`, not a one-off tweak for this render.

**A capped GIF then needs a matching-duration audio track for
`tools/make_presentation_video.wl`'s own mux (which hard-refuses a
GIF/WAV mismatch beyond tolerance — see that tool's own docs).**
Rather than time-stretch the canonical WAV (`tools/`'s existing
`--stretch` mechanism is explicitly documented as "NOT... verified
against... narrated audio," and this app's WAVs always open with a
spoken TTS intro), the video-specific audio is a FRESH synthesis via
the same unmodified `BuildMandelbrotAudio` — same pitches, same
traversal order, same formula — just a shorter per-note duration
solved to land near the capped GIF's duration, keeping the intro
buffer itself untouched. This is exported to a clearly-separate file
(`..._video_audio.wav`, never overwriting the canonical `..._audio.wav`
deliverable), so "sonification is unaffected by this change" remains
literally, checksum-verifiably true for the real deliverable WAV.

**Result for the `mandelbrot_high_iter_gradient` preset specifically**:
capped GIF at `maxDurationSec=80.0` → 160 frames @ 2fps, exactly 80.0s
(vs. 529 frames/264.5s uncapped) — GIF file size dropped from 93.4MB to
28.3MB; final muxed video: 80.021s, 1080x1080, **8.46MB** (vs. an
earlier >500MB result), GIF/WAV duration match 0.027% (well within the
tool's 3% tolerance).

**Pitfall discovered while implementing this**: `NumericQ[Infinity]` is
`False` in this WL version. An `Optional[maxDurationSec_?NumericQ,
Infinity]` default works fine when the argument is OMITTED, but the
moment one function explicitly threads its own (defaulted) value
onward to another (e.g. `AnimateAndExportField` passing `maxDurationSec`
to `AnimateFieldTraversal`), `Infinity` is no longer "omitted" — it's
an explicitly-passed argument that must itself satisfy `?NumericQ`, and
fails, silently leaving the whole call unevaluated (`Set::shape` at the
`{$gifFrames,$gifFps} = ...` call site, not an obviously-related error
at the actual failure point). Caught by actually running the pipeline,
not just reading the code — see design decision 6's "view the actual
output" discipline, extended here to "run the actual pipeline, not just
the pattern-match logic in your head." Fixed by using a large finite
sentinel (`10^9`) instead of `Infinity`.

## Animation framing: the GIF/WAV duration-sync bug (fixed post-v1.5.0)

**The bug.** All three GIFs played back at a small, fixed duration
completely unrelated to their matching WAV's actual length.
`AnimateFieldTraversal` (mandelbrot/julia) hardcoded `nGIFFrames=32` at
a fixed 10fps, always 3.2s. `AnimateZoom` hardcoded `framesPerLevel=8`
at a fixed 6fps, always `8*nLevels/6`s. Measured before the fix:
`mandelbrot_mandelbrot.gif` 3.20s vs its WAV 80.23s (25.1x mismatch),
`mandelbrot_julia.gif` 3.20s vs 76.89s (24.0x), `mandelbrot_zoom.gif`
5.44s vs 115.31s (21.2x). A listener watching and listening together
would see the GIF finish and loop roughly 20-25 times before the audio
even ended.

**Root cause.** Frame count and frame rate were both compile-time
constants, chosen for a *reasonable-looking* animation in isolation,
with no relationship to `nPixels` (the Hilbert-traversal length driving
`BuildFieldAudio`'s one-note-per-pixel duration) or to `nLevels`/the
per-level note stream length driving `BuildZoomAudio`. Since this app
is iteration-indexed rather than time-ODE (no `solution[[-1,1]]`-style
continuous time value to read off), the actual WAV duration is fixed by
`nPixels * noteDurationBase` (plus per-level chimes/gaps for zoom) plus
a spoken intro of unpredictable length (real TTS synthesis, not a fixed
constant) — nothing in the old animate.wl ever looked at any of that.

**The fix.** `AnimateFieldTraversal`/`AnimateAndExportField`/`AnimateZoom`
(`src/animate.wl`) now take a `targetDuration` argument and treat
`nFrames` (default 150) as a RENDER BUDGET, not a literal frame count,
following the same pattern already used by lorenz/, montecarlo/, and
several other v1.5.0 apps: `frameRate = Clip[nFrames/targetDuration,
{$MinAnimationFps, $MaxAnimationFps}]` (2-30 fps), then
`actualNFrames = Round[frameRate * targetDuration]` so playback duration
matches `targetDuration` almost exactly (frame count is what flexes at
the clamp). `AnimateZoom` additionally distributes `actualNFrames`
across levels via cumulative rounding (`Differences[Round[Range[0,
nLevels]*actualNFrames/nLevels]]`) so every level gets at least one
frame and the per-level counts still sum to exactly `actualNFrames`.
Both functions return `{actualNFrames, frameRate}` for `STEMDescribeGIF`.

Since `targetDuration` needs to be the WAV's *actual* total duration
(spoken intro + 0.4s pause + sonification — the intro's length isn't
knowable in advance, it comes from real TTS synthesis), `main.wl` and
`experiments.wl` were reordered so audio is synthesised and exported
*before* the animation is rendered (steps `[4/5]`/`[5/5]` swapped from
"render then synthesise" to "synthesise then render"), and the
resulting `Length[finalBuffer]/sr` is threaded into
`AnimateAndExportField`/`AnimateZoom` as `targetDuration`.

**Verification.** Re-measured all three default outputs plus all 7
`experiments.wl` presets after regenerating (`wolframscript -file
main.wl` x3 modes, `wolframscript -file experiments.wl`):

| file | GIF (before) | WAV | GIF (after) | ratio (after) |
|---|---|---|---|---|
| mandelbrot_mandelbrot | 3.20s | 80.23s | 80.00s (160f @ 2fps) | 1.0029x |
| mandelbrot_julia | 3.20s | 76.89s | 77.00s (154f @ 2fps) | 0.9986x |
| mandelbrot_zoom | 5.44s | 115.31s | 115.50s (231f @ 2fps) | 0.9984x |

All 7 `experiments.wl` presets (including `julia_fine_grid`'s 261s WAV
and `zoom_period3_bulb`'s 3-level split) land within 0.1-0.4% of their
WAV's duration — every case clamps to the 2fps floor since these
sonifications are all long relative to the 150-frame render budget.
`tests/test_model.wl` (unaffected by this change — it only tests
model.wl) still passes 27/27 after the fix.

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
wolframscript -file main.wl -- --simulation.mandelbrot.color_scheme=escape_gradient  # opt-in smooth color gradient
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
   every prior v1.5.0 app's `AGENTS.md`; avoided throughout via
   explicit `Optional[x_?NumericQ, default]`.
7. **`grid_size` drives BOTH visual resolution and audio duration** —
   see design decision 7. Raising it for a sharper presentation PNG
   silently makes the matching WAV proportionally longer (and, at 512,
   crashes the GIF-rendering step outright). There is no way to get a
   higher-resolution PNG from this pipeline without also affecting the
   other outputs, since all three share one `iterField`.
8. **A naive integer-iteration-count color mapping bands visibly** —
   see design decision 8. Always renormalize via the smooth-iteration-
   count formula (`SmoothIterationCount`) before mapping to color, and
   verify by rendering a zoomed crop directly on the boundary, not by
   inspecting the full-window render alone (banding can be subtle at
   full-window scale and only obvious zoomed in).
9. **`NumericQ[Infinity]` is `False`** in this WL version — see design
   decision 9. An `Optional[x_?NumericQ, Infinity]` default only works
   while `x` is omitted; the moment a caller explicitly threads that
   same defaulted value on to another function, it must itself satisfy
   `?NumericQ` and fails, leaving the call silently unevaluated. Use a
   large finite sentinel instead of `Infinity` for any "effectively
   unbounded" numeric default that might get re-passed explicitly.
10. **GIF playback duration is deliberately forced to equal its
   matching WAV's duration, always** (see "GIF/WAV duration sync"
   below) — capping it for presentation purposes needs an explicit,
   opt-in parameter (`maxDurationSec`, design decision 9), never a
   silent unconditional change to the default pacing formula, or every
   already-shipped preset whose natural duration exceeds the cap
   (e.g. `zoom_default` at 115.5s) would silently desync too.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `HilbertTraversalOrder`, `StemSynthNote`, `STEMHeading`,
  `STEMSection`, `STEMSay`, `STEMPrintN`, `STEMDescribeWAV`,
  `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`, `STEMPlayCmd`,
  `NormalizeBuffer`, `ExportGIF`, `ExportCSV`, `EnsureDir`.
- **Mathematica/WL**: `Hue` (high_contrast field-to-colour rendering;
  `Cos`-based palette formula, no extra WL functions, for
  escape_gradient), `Graphics`,
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

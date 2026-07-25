# Listening Guide — The Mandelbrot and Julia Sets

## Recommended listening sequence

Follow this order to hear the Mandelbrot set, what one of its points
actually means as a Julia set, and its boundary's self-similar
complexity at increasing magnification.

1. **`mandelbrot`** (default): a stream of notes, one per pixel, in
   Hilbert-curve order. Listen for calm, low-variation stretches (deep
   inside the set, or far outside it) versus a noticeably chaotic,
   rapidly-varying stretch (the boundary) — three orientation clicks
   mark the 25%/50%/75% points of the traversal.
2. **`julia`**: the same technique, now sweeping the *starting point*
   instead of the parameter — this is what a single point of the
   Mandelbrot set (the default is inside the set) looks and sounds
   like when expanded into its own fractal.
3. **`zoom`**: four levels, each announced by a short rising chime,
   all centred on the same boundary point. Listen for the chaotic,
   rapid pitch variation sounding *just as rich* at the deepest level
   as at the shallowest — that persistence is self-similarity, made
   audible.

```sh
wolframscript -file main.wl
wolframscript -file main.wl -- --simulation.mode=julia
wolframscript -file main.wl -- --simulation.mode=zoom
```

## Why the boundary sounds so different from the interior and exterior

Deep inside the set, every nearby point also never escapes — the
iteration count barely changes from one pixel to the next, so the
pitch barely changes either, a steady tone. Far outside the set, every
nearby point escapes almost immediately — same story, a different
steady tone. Right at the boundary, a tiny nudge in position can be
the difference between "escapes in 5 steps" and "never escapes" —
neighbouring pixels can have wildly different iteration counts, so the
pitch jumps around unpredictably. This app actually measured that
jumpiness directly: the average pitch-to-pitch jump at the boundary is
over 5 times larger than deep inside the set, and nearly 58 times
larger than far outside it.

## Why `julia` mode's spoken intro mentions "connected" or "disconnected"

Whether a Julia set is one connected piece or scattered dust
("Fatou dust") depends entirely on whether its defining `c` value is
inside or outside the Mandelbrot set — the two fractals are two views
of the same underlying question. The default `c` here was specifically
verified to sit safely inside the Mandelbrot set, so the default Julia
set is genuinely connected; try `--simulation.mandelbrot.julia_c_real=-0.7
--simulation.mandelbrot.julia_c_imag=0.27015` for a verified *outside*
point and hear/see the disconnected counterpart.

## Why `zoom` mode's four levels don't get simpler as they get deeper

That's the entire point. A boundary this fine and detailed at 1x
magnification looks (and sounds) just as fine and detailed at 64x
magnification, because the boundary is a fractal — it has structure at
every scale, not just the scale you first looked at. If the deepest
level sounded noticeably calmer or simpler than the shallowest, that
would mean the zoom centre wasn't actually on a genuinely
self-similar part of the boundary (this app's chosen centre was
specifically checked to avoid that).

## Tips for listening

- Use headphones or good speakers — the boundary's rapid pitch
  variation is easiest to distinguish from the calmer interior/exterior
  regions with clear stereo imaging.
- Try `--simulation.mandelbrot.grid_size=128` for a much more detailed
  (and longer) render of any mode.
- Try `--simulation.mandelbrot.max_iterations=1000` in mandelbrot mode
  — some points that looked "safely inside the set" at the default
  300-iteration budget turn out to escape, just very slowly; the
  boundary zone narrows and sharpens.
- `output/mandelbrot_mandelbrot.png` and `output/mandelbrot_julia.png`
  are worth viewing alongside listening — the black region is "in the
  set," and the point where black meets colour is the boundary the
  audio highlights.
- `output/mandelbrot_zoom.png` shows all four levels side by side —
  look for the same jagged structure repeating at every scale.

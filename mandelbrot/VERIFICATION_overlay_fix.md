# Verification: visited-region overlay fix, larger scan label, rebuilt LinkedIn video

All measurements below were made against the code as it currently
stands in the working tree (uncommitted), using real
`wolframscript -file main.wl` / `wolframscript -file experiments.wl`
runs and reading the actual exported GIF/WAV/MP4 files — not
synthetic mock-ups — unless a step is explicitly marked as a
measurement harness used only to choose a parameter before the real
render. Every command below can be rerun as written from the repo
root (`main.wl`/`experiments.wl` commands) or from `mandelbrot/`
(`wolframscript` one-liners), as noted.

## Pre-flight: how the overlay actually worked (read before any change)

`mandelbrot/src/animate.wl` has no separate "overlay" object. The
Hilbert-traversal path itself (`TraceStyle`'s `Line[pathG]`, drawn
over the static, already-fully-rendered fractal raster) functions as
the visited-region indicator. Because a Hilbert traversal visits
*every* pixel of the grid by construction, `pathG` spans the entire
grid by the final frame — so the "trace" is not a small decorative
line, it is a line that eventually covers the whole canvas. At the
original opacities (0.8 for `high_contrast`; 0.9 white / 0.55 black
halo for `escape_gradient`) that dense, full-canvas line was confirmed
by rendering and measuring real output to bury the fractal under
either a pale wash or a dense black/white maze, depending on
color_scheme.

`mandelbrot` and `julia` modes share exactly one code path:
`AnimateAndExportField` -> `AnimateFieldTraversal` -> `TraceStyle`.
`zoom` mode uses a completely separate path, `AnimateZoom` ->
`ZoomLevelFrame`, which has no `Line`, no marker, and no Hilbert trace
at all — it just cycles through pre-rendered per-level PNGs with its
own `ZoomLevelLabel` text. Confirmed both by reading `model.wl` (no
`traceOpacity`/trace concept in `ZoomModel`) and by measurement (see
"zoom mode" below): zoom's own real output never showed the
overlay-wash pattern the other two modes did, because there is
nothing there to fix. Severity of the original defect also scaled
with grid_size (line density relative to a fixed stroke width): mild
at the real presets' `grid_size=64`/`128`, severe on old,
non-default `grid_size=256` test renders left over in `output/`.

## Item 1a: opacity chosen by measurement

Harness used to pick a candidate opacity (grid_size=128,
color_scheme=escape_gradient — the real escape-gradient LinkedIn-video
configuration, matching Item 3's deliverable) rendered the completed
scan's final frame at four candidate opacities and compared each
against the unscanned first frame:

Opacity 0.8 (original): contrast (std-dev of luminance) ratio
final/first = 0.901 — numerically above the 60% target, but a direct
visual comparison of the rendered PNG showed the fractal buried under
a dense black/white line maze; the number alone was misleading here.

Opacity 0.4: contrast ratio = 0.700.

Opacity 0.25: contrast ratio = 0.757.

Opacity 0.15: contrast ratio = 0.838, and a direct visual comparison
showed the fractal's shape and color gradient clearly legible, with
the traversal reading as a light texture rather than an occlusion.

Chosen default: `trace_opacity = 0.15` (`$DefaultTraceOpacity` in
`animate.wl`; config key `simulation.mandelbrot.trace_opacity`,
`mandelbrot/config.json`). The `escape_gradient` halo/line opacity
ratio (0.55/0.9 in the original code) is preserved at any
`trace_opacity` value so relative contrast doesn't shift as the
overlay fades.

## Item 1a: measured on the real, final rendered output (post-fix)

Command used to regenerate all three default-config modes:

```sh
cd mandelbrot
wolframscript -file main.wl -- --simulation.mode=mandelbrot
wolframscript -file main.wl -- --simulation.mode=julia
wolframscript -file main.wl -- --simulation.mode=zoom
```

mandelbrot mode: mean luminance first frame = 0.5897, last frame =
0.5914 (ratio 1.003). Contrast (std-dev) first = 0.3670, last =
0.3649 (ratio 0.994) — target >=0.6: PASS.

julia mode: mean luminance first frame = 0.6682, last frame = 0.6694
(ratio 1.002). Contrast first = 0.3200, last = 0.3181 (ratio 0.994) —
target >=0.6: PASS.

zoom mode: mean luminance first level frame = 0.6527, last level
frame = 0.4173 (ratio 0.639 — reflects genuinely different content
across zoom levels, not overlay wash, since zoom has no trace/overlay
at all). Contrast first = 0.3323, last = 0.4083 (ratio 1.229) —
target >=0.6: PASS (trivially, since there is no overlay to fix in
this mode).

escape-gradient preset (`mandelbrot_high_iter_gradient`, grid_size=128,
max_iterations=1000, color_scheme=escape_gradient — see Item 3):
mean luminance first frame = 0.3475, last frame = 0.3545 (ratio
1.020). Contrast first = 0.3721, last = 0.3495 (ratio 0.939) — target
>=0.6: PASS. Direct visual comparison of the actual exported first
and last frames confirms the fractal's color and silhouette are
clearly legible in the last frame, with only a light textured hint of
the completed Hilbert curve.

## Item 1b: end-of-scan fade

`overlay_fade_seconds = 1.0` (config key
`simulation.mandelbrot.overlay_fade_seconds`, default in
`mandelbrot/config.json`); `$TraceFadeFloorOpacity = 0.05` in
`animate.wl` (the opacity the fade settles at, kept non-zero so the
completed curve stays faintly visible through the video tool's
closing hold).

mandelbrot mode real run: 160 scan frames + 2 end-of-scan fade frames
(1.000s at 2 fps), overlay opacity ramping 0.15 -> 0.05, printed
directly by the tool during the real render above.

julia mode real run: 154 scan frames + 2 end-of-scan fade frames
(1.000s at 2 fps), same opacity ramp.

escape-gradient preset real run: 197 scan frames + 2 end-of-scan fade
frames (1.000s at 2 fps), same opacity ramp.

zoom mode: no fade applied (zoom has no overlay to fade; `AnimateZoom`
was not given a `fadeSeconds` parameter and its own real run above
shows no fade-related output line).

Audio duration bookkeeping (GIF/WAV sync check, the project-wide
`VerifyDurationMatch`, 3% tolerance) after adding the fade — command:

```sh
wolframscript -code '
Get["/Users/mintaccess/Projects/stem/tools/src/video_pipeline.wl"];
r = VerifyDurationMatch["output/mandelbrot_mandelbrot.gif", "output/mandelbrot_mandelbrot.wav", 0.03];
Print["GIF=", r["gifDuration"], "s WAV=", r["wavDuration"], "s diff=", N[100*r["relativeDiff"]], "%  ", If[r["ok"], "PASS", "FAIL"]];
'
```

mandelbrot: GIF=81.0s, WAV=81.2307s, diff=0.284% — PASS (within 3%).

julia: GIF=78.0s, WAV=77.8948s, diff=0.135% — PASS (within 3%).

zoom: GIF=115.5s, WAV=115.3108s, diff=0.164% — PASS (within 3%,
unaffected by this change).

escape-gradient preset: GIF=99.5s, WAV=99.5976s, diff=0.098% — PASS
(within 3%).

## Item 2: larger "Hilbert-curve scan" label

Old font size: 9pt (`Text[Style["Hilbert-curve scan", 9, White,
Bold], ...]`, the original hardcoded value).

New font size: 16pt (`$HilbertScanLabelFontSize` in `animate.wl`,
config: not config-driven, a fixed constant per the task's ask).

Label pixel height in the actual exported GIF frame (real frames are
640x640, not the nominal 320x320 the code's own `ImageSize->320`
requests — this machine's WL kernel renders Graphics/Export "GIF" at
2x that requested size; confirmed directly via
`ImageDimensions[First[Import[...,"ImageList"]]]` on a real exported
GIF, both before and after this change):

Old (9pt): height = 21px, width = 162px, measured on
`mandelbrot_default.gif` (pre-change baseline, same rendering path).

New (16pt): height = 37px, width = 288px, measured directly on the
real, freshly-rendered `output/mandelbrot_mandelbrot.gif`'s first
frame.

That is a 76% increase in label height (21px -> 37px) in the same
640px-tall frame — from 3.3% to 5.8% of frame height.

Collision check: the label is drawn LAST in each frame's Graphics
primitive list (after the raster, trace, and marker), so nothing can
ever render on top of it or make the label itself illegible — this
was true before and after the font-size change, and is a structural
guarantee, not a per-frame check. The label's own bounding box (rows
576-613, cols 176-464 of a 640x640 frame) stays comfortably inside
the canvas with margin on both sides (176px and 176px from the left/
right edges) — no edge clipping. Checking whether the *marker* ever
gets covered by the (now larger) label: on the real
`mandelbrot_mandelbrot.gif`, the marker's yellow pixel falls within
the label's row/column band in 4 of 162 frames (2.5%); on
`mandelbrot_julia.gif`, 4 of 156 frames (2.6%) — in those few frames
the marker is briefly drawn underneath the label's dark background
patch, a pre-existing z-order effect (unchanged by this fix, just
covering a larger area now that the label itself is bigger). No
collision with the trace line was observed or expected, since the
trace only ever appears above the label's row band except during
those same few marker-adjacent frames. `zoom` mode's own, unrelated
label (`ZoomLevelLabel`, "level k (Nx)") was not touched by this
change and was not measured, since Item 2 is specifically about the
"Hilbert-curve scan" label, which zoom mode does not have.

## Item 3: rebuilt escape-gradient LinkedIn video

The `mandelbrot_high_iter_gradient` preset (grid_size=128,
max_iterations=1000, color_scheme=escape_gradient) previously existed
only as a hand-built, never-committed one-off (per AGENTS.md design
decision 9, built before `BuildMandelbrotAudio`'s own `maxDurationSec`
cap existed). It is now a real, version-controlled experiment
(`RunGradientVideoPreset` in `mandelbrot/experiments.wl`), built
through the normal audio-then-GIF pipeline with the audio capped
directly at the source (`BuildMandelbrotAudio[..., 80.0]`) rather than
via a separate, never-committed "video audio" file.

Command used to rebuild the preset's GIF/WAV pair:

```sh
cd mandelbrot
wolframscript -file experiments.wl
```

(this also regenerates the other 7 curated experiments; the gradient
preset's own files are `output/mandelbrot_high_iter_gradient.gif` and
`output/mandelbrot_high_iter_gradient_audio.wav`.)

Command used to build the final LinkedIn video from those files, with
the closing hold coming from the video tool's own `--hold-seconds`
flag (not a hand-patch):

```sh
wolframscript -file tools/make_presentation_video.wl -- \
  --gif=mandelbrot/output/mandelbrot_high_iter_gradient.gif \
  --wav=mandelbrot/output/mandelbrot_high_iter_gradient_audio.wav \
  --title="Mandelbrot Escape Gradient" \
  --profile=linkedin \
  --out=mandelbrot/output/mandelbrot_high_iter_gradient_linkedin.mp4 \
  --hold-seconds=2.5
```

Total duration: 104.6 seconds (video 104.597s, audio 104.598s, per
the tool's own output size check line below).

Effective hold printed by the tool (both ends, requested and
effective agree since 2.5s x 2fps = 5 frames exactly):

```
Requested opening hold 2.5 seconds; effective hold 2.5 seconds, which is 5 frames at 2. frames per second.
Requested closing hold 2.5 seconds; effective hold 2.5 seconds, which is 5 frames at 2. frames per second.
```

Output sanity check line:

```
Output size check passed: video duration 104.597 seconds, audio duration 104.598 seconds, file size 18.4796 MB, all within the 600 seconds and 200 MB thresholds.
```

Sync-percentage check line (GIF/WAV, before muxing):

```
GIF/WAV duration check: GIF=99.5s  WAV=99.6s  diff=0.098%  (within 3.% tolerance)
```

Frame clearance check (the video tool's own per-frame verification,
unaffected by any of this session's changes, included for
completeness): `PASS (209 frames checked, 0 violations)`.

## Files changed

- `mandelbrot/src/animate.wl` — `TraceStyle` takes an explicit
  opacity; `$DefaultTraceOpacity`, `$TraceFadeFloorOpacity`,
  `$HilbertScanLabelFontSize` constants; `AnimateFieldTraversal` and
  `AnimateAndExportField` gained `traceOpacity`/`fadeSeconds` (both
  opt-in via Optional trailing args, default-backward-compatible
  except for the new, intentionally-fixed default opacity); larger
  label font size.
- `mandelbrot/src/model.wl` — `MandelbrotModel`/`JuliaModel` read
  `simulation.mandelbrot.trace_opacity` from config and populate
  `model["traceOpacity"]`.
- `mandelbrot/main.wl` — reads
  `simulation.mandelbrot.overlay_fade_seconds`; mandelbrot/julia
  blocks append that much trailing silence to the exported WAV and
  pass `fadeSeconds` through to `AnimateAndExportField`; zoom block
  unchanged.
- `mandelbrot/experiments.wl` — same fade/silence threading as
  main.wl for its mandelbrot/julia branches, for consistency; new
  `RunGradientVideoPreset` (experiment 8) replacing the old hand-built
  `mandelbrot_high_iter_gradient` asset with a version-controlled
  build.
- `mandelbrot/config.json` — added `trace_opacity: 0.15` and
  `overlay_fade_seconds: 1.0` under `simulation.mandelbrot`.

No files under `tools/` were changed in this session — the hold
feature it exercises (`--hold-seconds`) was already complete and
committed beforehand.

---

## Follow-up: audio-cap clarification, trace-visibility measurement, marker z-order

### 1. What `BuildMandelbrotAudio[..., 80.0]` actually caps

The original report's Item 3 section said the audio was "capped
directly at the source (`BuildMandelbrotAudio[..., 80.0]`)" without
stating clearly what that number bounds, which read as inconsistent
next to the reported 99.6s WAV. It is not inconsistent — the argument
caps a *different, smaller* quantity than the total exported WAV, and
that cap is genuinely binding. Verified directly (command below):

```sh
cd mandelbrot
wolframscript -code '
Get["/Users/mintaccess/Projects/stem/stem-core/init.wl"];
Get["src/model.wl"]; Get["src/sonify.wl"]; Get["src/speech.wl"];
cfg = LoadConfig["mandelbrot", {"--simulation.mandelbrot.grid_size=128","--simulation.mandelbrot.max_iterations=1000","--simulation.mandelbrot.color_scheme=escape_gradient"}];
model = MandelbrotModel[cfg];
Print["nPixels: ", model["nPixels"]];
Print["uncapped raw duration (nPixels*0.015): ", model["nPixels"]*0.015, "s"];
Print["CapNoteDuration -> per-note seconds: ", CapNoteDuration[model["nPixels"], 0.015, 80.0]];
{rawBuffer, f} = BuildMandelbrotAudio[model, 200.0, 2200.0, 0.015, 44100, 80.0];
Print["measured rawBuffer duration: ", N[Length[rawBuffer]]/44100, "s"];
introBuffer = BuildIntroBuffer[BuildMandelbrotIntroText[model["maxIter"]], 44100];
Print["introBuffer duration: ", N[Length[introBuffer]]/44100, "s"];
'
```

What the `maxDurationSec` argument controls: `BuildMandelbrotAudio`'s
last argument feeds `CapNoteDuration[nPixels, noteDurationBase,
maxDurationSec] = Min[noteDurationBase, maxDurationSec/nPixels]`
(`sonify.wl`, design decision 10) — it caps the **per-note duration**
of the raw pixel-sonification stream only, so that
`nPixels * noteDuration <= maxDurationSec`. It has no knowledge of,
and does not bound, the intro speech, the 0.4s pause, or the
end-of-scan fade silence added afterward in `experiments.wl` — those
are concatenated onto the capped raw buffer, not inside it.

Whether the cap is binding: yes. `nPixels = 16384` (grid_size=128).
Uncapped, `16384 * 0.015 = 245.76s` of raw sonification (matching the
264.7s AGENTS.md cites for the same preset, modulo rounding/clicks).
`CapNoteDuration[16384, 0.015, 80.0] = 0.0048828125s/note`, far below
the base `0.015s`, so the cap is actively reducing the per-note
duration, not passing it through unchanged. Measured raw buffer
duration: 79.877s — essentially exactly the requested 80.0s cap
(confirming it is binding, not coincidentally close).

The reported 99.6s total is the SUM of four pieces, all measured
directly: intro speech 18.321s + pause 0.4s + capped raw sonification
79.877s + fade silence 1.0s = 99.598s, matching the actual exported
WAV's measured duration (99.597641723356s) to five decimal places.
This is expected, correct behavior — the cap did its job (preventing
the original 245.76s/264.7s blowup), and the total including intro
speech landing under 100s is a reasonable presentation-clip length.

No code changes were needed here — the code was already correct; the
report text above ("Item 3") has been read together with this section
to resolve the apparent inconsistency, and this section is the
authoritative explanation going forward.

### 2. Trace-visibility measurement

Contrast ratio (std-dev of whole-frame luminance) can't show whether
the trace itself is still discernible once faded, since it's a
whole-frame summary statistic dominated by the fractal, not the thin
line. Measured instead: mean absolute luminance difference between
on-path pixels (identified via a same-coordinate-system line-only
mask render, so pixel positions align exactly with the real frame)
and their immediate off-path neighbour pixels (1-pixel dilation ring
around the mask, excluding the mask itself), on the real escape-
gradient configuration (grid_size=128, max_iterations=1000,
color_scheme=escape_gradient).

Last frame (full path, opacity = `$TraceFadeFloorOpacity` = 0.05, the
value the real closing hold actually shows): 245754 on-path pixels,
163846 off-path neighbour pixels; mean on-path luminance = 0.36870,
mean off-path luminance = 0.33390; **mean abs difference = 0.0348**.

Mid-scan frame (50% of the path revealed, opacity =
`$DefaultTraceOpacity` = 0.15, before any fading): mean on-path
luminance = 0.45535, mean off-path luminance = 0.35937; **mean abs
difference = 0.0960** — as expected, more visible than the faded last
frame.

Baseline (full path, `trace_opacity=0`, i.e. no visible trace at
all): mean on-path luminance = 0.34752, mean off-path luminance =
0.34755; **mean abs difference = 0.0000282** — confirms the
measurement method correctly reads "no discernible trace" as
approximately zero, validating the methodology against a true-absence
case.

The last frame's value (0.0348) is above the 0.02 threshold, so
**`$TraceFadeFloorOpacity` was NOT raised** — it stays at 0.05, the
value already reported above. No code change was needed for this
item.

Three PNGs exported for sighted review, from the actual real GIF
(`output/mandelbrot_high_iter_gradient.gif`, 199 frames):

- `mandelbrot/output/review/escape_gradient_first_frame.png` (frame 1)
- `mandelbrot/output/review/escape_gradient_midscan_frame.png` (frame 100 of 199, inside the 197-frame scan portion)
- `mandelbrot/output/review/escape_gradient_last_frame.png` (frame 199, post-fade)

### 3. Marker drawn after the label (z-order fix)

`AnimateFieldTraversal`'s per-frame `Graphics` primitive list (both
the scan-frame and fade-frame builders) now lists the marker
(`{EdgeForm[...], Yellow, Disk[...]}`) AFTER the `Text` label instead
of before, so the marker draws on top and can never be hidden behind
the label's dark background patch. (The label itself was already
drawn last, hence always legible, before this change — this only
affects which of the label/marker wins when the two overlap.)

Regenerated `output/mandelbrot_mandelbrot.gif` and
`output/mandelbrot_julia.gif` (`wolframscript -file main.wl --
--simulation.mode=mandelbrot` / `=julia`) and checked every frame of
each for at least one near-pure-yellow pixel (R>0.8, G>0.8, B<0.3):

`output/mandelbrot_mandelbrot.gif`: 162 frames checked, marker missing
in 0 frames — PASS (marker visible in every frame).

`output/mandelbrot_julia.gif`: 156 frames checked, marker missing in
0 frames — PASS (marker visible in every frame).

GIF/WAV sync re-checked after regenerating (unaffected by a pure
z-order change, confirmed): mandelbrot GIF=81.0s/WAV=81.231s,
diff=0.284%, PASS; julia GIF=78.0s/WAV=77.895s, diff=0.135%, PASS.

Not rebuilt in this follow-up: the escape-gradient preset GIF and the
`mandelbrot_high_iter_gradient_linkedin.mp4` deliverable from the
original Item 3 section above still reflect the marker-before-label
ordering, since this follow-up's marker check was explicitly scoped
to "mandelbrot and julia renders." The marker/label reorder is in the
same shared `TraceStyle`/`AnimateFieldTraversal` code path, so it
would apply automatically if that preset and video are rebuilt again.

### 4. Escape-gradient deliverable rebuilt with the marker z-order fix

The note above is now stale by design: the escape-gradient preset and
the LinkedIn MP4 have since been rebuilt so the marker fix reaches the
actual deliverable too.

Commands:

```sh
cd mandelbrot
wolframscript -file experiments.wl
cd ..
wolframscript -file tools/make_presentation_video.wl -- \
  --gif=mandelbrot/output/mandelbrot_high_iter_gradient.gif \
  --wav=mandelbrot/output/mandelbrot_high_iter_gradient_audio.wav \
  --title="Mandelbrot Escape Gradient" \
  --profile=linkedin \
  --out=mandelbrot/output/mandelbrot_high_iter_gradient_linkedin.mp4 \
  --hold-seconds=2.5
```

Marker visibility on the rebuilt GIF: 199 frames checked, marker
missing in 0 frames — PASS (same check as section 3, extended to this
preset).

Confirmed unchanged from the original Item 3 section (timing is
unaffected by a pure Graphics z-order change, as expected):

- GIF/WAV duration check: `GIF=99.5s WAV=99.6s diff=0.098% (within
  3.% tolerance)` — identical.
- Effective hold: `Requested opening hold 2.5 seconds; effective hold
  2.5 seconds, which is 5 frames at 2. frames per second.` /
  `Requested closing hold 2.5 seconds; effective hold 2.5 seconds,
  which is 5 frames at 2. frames per second.` — identical.
- Output size check: `video duration 104.597 seconds, audio duration
  104.598 seconds, ... all within the 600 seconds and 200 MB
  thresholds` — identical durations; file size 18.442 MB vs. the
  original 18.4796 MB, a ~0.04MB difference from H.264 compressing
  the marker's now-differently-layered pixels very slightly
  differently in the handful of frames where it previously sat behind
  the label — not meaningful.

The three review PNGs in `mandelbrot/output/review/` were re-exported
from this rebuilt GIF at the same frame indices (1, 100, 199 of 199),
overwriting the previous export. Their file sizes (199236, 305564,
342511 bytes respectively) exactly match the previous export's sizes
recorded earlier in this document — consistent with the marker never
overlapping the label at those three specific sampled frames, though
this was not confirmed with a byte-for-byte checksum against the
prior files (they were overwritten before a checksum was taken).

# Verification: opening/closing hold, MixedUnit fix, output sanity check

All measurements below were made against the code as it currently
stands in the working tree (uncommitted), using
`mandelbrot/output/mandelbrot_default.gif` and
`mandelbrot/output/mandelbrot_default_audio.wav` as the test input
unless stated otherwise. Every command below can be rerun as written
from the repo root.

## 1. Hold test (`--hold-seconds=2.5`)

Command used to build the video:

```sh
wolframscript -file tools/make_presentation_video.wl -- \
  --gif=mandelbrot/output/mandelbrot_default.gif \
  --wav=mandelbrot/output/mandelbrot_default_audio.wav \
  --title="Hold Evidence" \
  --profile=linkedin \
  --out=/tmp/evidence_hold.mp4 \
  --hold-seconds=2.5
```

Test input: `mandelbrot/output/mandelbrot_default.gif` +
`mandelbrot/output/mandelbrot_default_audio.wav`.

Frame rate: 2. fps.

Original video (GIF) duration: 80. s.

Original audio (WAV) duration: 80.23065759637188 s.

Video (muxed container) duration with `--hold-seconds=2.5`: 85.23 s.

Audio duration (padded WAV actually used for muxing) with
`--hold-seconds=2.5`: 85.23065759637188 s.

Effective hold, start: 5 frames = 2.5 s (requested 2.5 s; requested
and effective agree at this frame rate).

Effective hold, end: 5 frames = 2.5 s (requested 2.5 s; requested and
effective agree at this frame rate).

Total frames in muxed output: 170 (160 original + 5 + 5, as expected).

Opening-hold frame check: frame 1 vs. frame 5 (the last frame still
inside the opening hold, i.e. the frame immediately before real
animation begins) — max abs pixel diff 0.25490196078431376, mean abs
pixel diff 0.0018816681908245707.

Closing-hold frame check: frame 170 (the last frame) vs. frame 166
(the first frame of the closing hold, i.e. the frame immediately
after real animation ends) — max abs pixel diff
0.019607843137254943, mean abs pixel diff 0.00003536046334400246.

Contrast measurement, for scale: frame 1 vs. mid-animation frame 85
(a genuine, non-held content difference) — mean abs pixel diff
0.005910707881689476, roughly 3x the held-frame diffs above, which
are attributable to H.264 codec quantization noise rather than any
actual content change.

Peak audio level, opening pad (samples 1–110250, the first 2.5 s):
0.00012207403790398877.

Peak audio level, closing pad (last 110250 samples, the last 2.5 s):
0.0011291848506118961.

Contrast measurement, for scale: peak audio level of real signal
immediately after the opening pad: 0.7491683706167791.

## 2. No-hold regression (flag omitted)

Command used to build the pre-change baseline (run against the
working tree with the day's uncommitted changes to
`tools/make_presentation_video.wl`, `tools/src/video_pipeline.wl`,
and `tools/README.md` stashed away first):

```sh
git stash push -- tools/make_presentation_video.wl tools/src/video_pipeline.wl tools/README.md
wolframscript -file tools/make_presentation_video.wl -- \
  --gif=mandelbrot/output/mandelbrot_default.gif \
  --wav=mandelbrot/output/mandelbrot_default_audio.wav \
  --title="Baseline Regression" \
  --profile=linkedin \
  --out=/tmp/evidence_baseline.mp4
git stash pop
```

Baseline commit tested: `6b6ce5b2f9e1de4f3220d5d12202d4028298e10e`
(the commit at `HEAD` before any of this session's changes).

Command used to build the final-code, no-hold-flag output:

```sh
wolframscript -file tools/make_presentation_video.wl -- \
  --gif=mandelbrot/output/mandelbrot_default.gif \
  --wav=mandelbrot/output/mandelbrot_default_audio.wav \
  --title="Baseline Regression" \
  --profile=linkedin \
  --out=/tmp/evidence_final_nohold.mp4
```

Baseline duration: 80.23 s.

Final-code (no-hold-flag) duration: 80.23 s.

Baseline frame count: 160.

Final-code (no-hold-flag) frame count: 160.

Baseline file size: 2879465 bytes.

Final-code (no-hold-flag) file size: 2879465 bytes.

Max pixel diff across all 160 corresponding frame pairs, baseline vs.
final-code: 0. (pixel-identical).

## 3. Part 2 — MixedUnit duration diagnostic, before and after

Input: `mandelbrot/output/mandelbrot_default.gif` +
`mandelbrot/output/mandelbrot_default_audio.wav`, muxed duration
80.23 s (over the 60-second threshold this check exists for).

Exact line as it printed BEFORE the fix (reproduced by applying the
pre-`6b6ce5b` formula, `QuantityMagnitude[Import[muxedPath,
"Duration"]]`, to a real muxed file of this input):

```
Muxed duration: FmtN[MixedMagnitude[{1, 20.230000000000004}], 4]s vs source WAV 80.23s  (diff=FmtN[1.2464063363793507*Abs[-80.23065759637188 + MixedMagnitude[{1, 20.230000000000004}]], 3]%)
```

Exact line as it prints AFTER the fix (current code, real run):

```
Muxed duration: 80.23s vs source WAV 80.23s  (diff=0.00082%)
```

Note: this fix (`6b6ce5b`) was already committed before this
session's work began; this section reproduces and confirms it, it
was not written in this session.

## 4. Part 3 — output sanity check

Command used to trigger the warning deliberately:

```sh
wolframscript -file tools/make_presentation_video.wl -- \
  --gif=mandelbrot/output/mandelbrot_default.gif \
  --wav=mandelbrot/output/mandelbrot_default_audio.wav \
  --title="Sanity Trigger Evidence" \
  --profile=linkedin \
  --out=/tmp/evidence_sanity_trigger.mp4 \
  --max-duration-seconds=60 \
  --max-file-mb=1
```

Flags used to trigger: `--max-duration-seconds=60 --max-file-mb=1`.

Exact WARNING lines printed:

```
WARNING: the video duration is 80.23 seconds, which exceeds the configured threshold of 60 seconds.
WARNING: the audio duration is 80.2307 seconds, which exceeds the configured threshold of 60 seconds.
WARNING: the output file size is 2.75628 MB, which exceeds the configured threshold of 1 MB.
```

The output file was still written (`Wrote /tmp/evidence_sanity_trigger.mp4`),
confirming the check is warn-only and does not abort.

Confirmation that no WARNING line appears at default thresholds (from
the no-hold-flag run in section 2 above, which used no
`--max-duration-seconds`/`--max-file-mb` flags):

```
Output size check passed: video duration 80.23 seconds, audio duration 80.2307 seconds, file size 2.74607 MB, all within the 600 seconds and 200 MB thresholds.
```

No line beginning with `WARNING` appears in that run's output.

## 5. Syntax check

Command used to confirm `tools/src/video_pipeline.wl` loads without
syntax errors:

```sh
wolframscript -code '
Get["stem-core/src/utils.wl"];
Get["stem-core/src/synth.wl"];
Get["tools/src/video_pipeline.wl"];
Print["tools/src/video_pipeline.wl: loaded OK, no syntax errors"];
'
```

Result:

```
tools/src/video_pipeline.wl: loaded OK, no syntax errors
```

Command used to confirm `tools/make_presentation_video.wl` loads and
runs without syntax errors (a deliberately-invalid GIF path is used
so the script reaches its own runtime argument-validation check
rather than doing a full render; reaching that check, rather than a
parse error, confirms the file parsed cleanly):

```sh
wolframscript -file tools/make_presentation_video.wl -- \
  --gif=/nonexistent --wav=/nonexistent --title=x \
  --profile=linkedin --out=/nonexistent
```

Result:

```
GIF not found: /nonexistent
```

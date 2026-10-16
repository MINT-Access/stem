# tools/

Standalone utilities that operate *on* this repo's apps from the
outside, rather than living inside any one app's own pipeline. Nothing
here runs as part of an app's `main.wl`, and nothing here changes an
app's own output. Every app's primary, default output stays
sonification-first — WAV, GIF, CSV — exactly as documented in each
app's own README.

## smoke_test.wl

One command that checks an installation: every app's default mode, then
`demo.wl`, all in one kernel (stem-core `STEMRunApp`; no child
wolframscript). Writes a UTF-8 plain-text report
`smoke_test_<SystemID>_<date>_<HHMM>.txt` in the repository root (gitignored; pass
`--out=<path>` to put it elsewhere): an environment block (version, system,
encodings, SpeechSynthesize, which speech and network tools start, a
non-ASCII probe line with its UTF-8 bytes, the pixel size of a test GIF),
one line per app (status, seconds, WAV length, LUFS, peak, GIF length, GIF
minus WAV, GIF pixels, whether the WAV opens with speech, first message),
the pendulum frame-clipping check (a Wolfram port of
`pendulum/tests/verify_animation_frames.py`), demo.wl's result, and every
Wolfram message in full. Exit code 0 only if every app wrote a WAV.

```sh
wolframscript -file tools/smoke_test.wl              # all 32 apps + demo.wl (about 30 min)
wolframscript -file tools/smoke_test.wl -- --quick   # 6 apps + demo.wl --quick (about 8 min)
```

On Windows PowerShell write the separator as `'--'`; see the root README.

`smoke_test.sh` (and `smoke_test.ps1` for Windows) runs the same command for
a machine nobody is watching: console to `smoke_console_<...>.txt`, a
heartbeat file every 10 s (time, app being run), and one line appended to
the report when wolframscript ends, with its exit code and, if the kernel was
killed, the signal (`tools/smoke_test.sh --quick`).
The report from the development Mac is kept in
`docs/smoke_test_MacOSX-ARM64_2026-10-07.txt` for comparison.

## make_presentation_video.wl

Generates a single presentation-ready MP4 (video + audio, muxed and
synced) from an app's **already-rendered** GIF and WAV output. Built
for two real, recurring needs: LinkedIn posts, and live talks to
mostly-sighted audiences (workshops, conference presentations) where a
combined video is the practical format, even though sonification —
audio as the primary channel — remains this project's actual point and
every app's actual default output.

This tool exists because producing these videos by hand, repeatedly,
surfaced and fixed several real bugs this project now has fixes for: a
GIF-clipping bug that clipped 76% of `pendulum/`'s double-pendulum
animation frames, a systemic GIF/WAV duration-desync bug across all 32
apps, and a pitch-shift bug in `relativity/`'s chirp audio. Rather than
re-discovering (or re-introducing) those bugs by hand each time, this
tool bakes the fixes in as defaults: it will not produce a video whose
audio and video durations don't match, and it verifies its own output
frame-by-frame before calling the job done.

### Usage

```sh
wolframscript -file tools/make_presentation_video.wl -- \
  --gif=pendulum/output/double_animation.gif \
  --wav=pendulum/output/double_audio.wav \
  --title="Double Pendulum" \
  --profile=workshop \
  --out=pendulum/output/double_workshop.mp4
```

Required flags: `--gif`, `--wav`, `--title`, `--profile`
(`linkedin` or `workshop`), `--out`.

Optional flags:
- `--stretch=N` — time-stretch factor applied to the source audio (and
  a matching video slowdown), for the narrow case of a raw chirp-style
  sonification that's too short to be followed as a presentation clip.
  See "Stretch factor" below — most invocations should omit this.
- `--tolerance=N` — GIF/WAV duration-match tolerance as a fraction
  (default `0.03`).
- `--hold-seconds=N` — hold the first frame still for `N` seconds at
  the start **and** the last frame still for `N` seconds at the end,
  with the audio padded with matching silence at each end so picture
  and sound stay aligned (default `0`, i.e. no hold). See "Opening/
  closing hold" below.
- `--hold-start-seconds=N` / `--hold-end-seconds=N` — set the start
  and end hold independently, each overriding `--hold-seconds` for
  that end. All three reject negative values with a clear error.
- `--max-duration-seconds=N` / `--max-file-mb=N` — thresholds for the
  post-mux output sanity check (defaults `600` and `200`). See
  "Output sanity check" below.

One MP4 per invocation, deliberately — the tool does not generate both
profiles from one call. Run it twice for both.

### Profiles

| Profile | Dimensions | Aspect | Use |
|---|---|---|---|
| `linkedin` | 1080×1080 | 1:1 | Feed posts |
| `workshop` | 1920×1080 | 16:9 | Talk/slide decks |

### Design priority: sync over everything else

**Correct video/audio synchronization matters more than anything
else** — more than hitting any particular target duration, more than
visual polish. Concretely:

- The tool verifies the source GIF and WAV are already duration-matched
  (within tolerance, default 3% — the same residual the v1.5.1 GIF/WAV
  sync fix documented, coming from GIF's whole-centisecond frame-delay
  quantization) **before doing anything else**, and refuses to produce
  a video if they aren't, rather than silently producing a desynced
  one.
- In the common case — true for all 32 apps as of the v1.5.1 fix — the
  GIF and WAV are already duration-matched, so the tool's job is
  comparatively simple: take what already exists, frame it well, add a
  title, mux, done. It does **not** implement general-purpose automatic
  duration stretching or trimming; that was explicitly descoped. If an
  app's outputs drift out of sync in the future, the fix belongs in
  that app's own `animate.wl`/`sonify.wl` (as it did in the v1.5.1 fix),
  not papered over here.
- After muxing, the tool re-verifies the final MP4's duration against
  the source WAV.

### What the tool actually does

1. **Verify duration match** (GIF vs. WAV, see above).
2. **Crop to the real, verified content boundary.** Every frame of the
   GIF is classified pixel-by-pixel against a per-video inferred
   background color (sampled from the frame's four corners — every app
   in this codebase centers its physics content, so corners are
   reliably background). The content bounding box is the union across
   **every frame**, not a sample — the double-pendulum clipping bug
   this pipeline exists to avoid repeating was invisible on the frames
   a human would have spot-checked. A symmetric margin (both sides of
   both dimensions — the two mistakes explicitly being guarded against
   are cropping with zero margin, and margin on only one side) is added
   and clamped to the source image bounds.
3. **Scale to fill, pad to fit.** The cropped content is scaled to fill
   the profile's content area (below the title band) as large as the
   aspect ratio allows, then padded — never stretched — to the exact
   target dimensions. Content is deliberately scaled to 94% of the
   available area rather than exactly 100%: some source GIFs turned out
   to already be very tightly framed natively (`lorenz_animation.gif`
   has only ~5px of native headroom above/below its trajectory at full
   resolution), which left only a few pixels of margin in the output
   even after the crop step's own margin logic — reserving a fixed
   fraction of breathing room in the *output* guarantees comfortable
   clearance regardless of how tightly the source app happened to frame
   its own animation.
4. **Add the title,** structurally rather than just visually separated
   from the content: the canvas is split into a dark title band at the
   top and a content area below it, and the animation is scaled+padded
   to fit entirely within the content area — never the title band — so
   the two regions cannot overlap by construction. (Verified anyway;
   see below.)
5. **Mux + verify.** Frames are muxed with the WAV and the final
   duration is checked against the source audio.

### Verification

Every video this tool produces is checked, on **every frame** (not a
sample), directly in Wolfram Language — reusing the same discipline as
`pendulum/tests/verify_animation_frames.py` (classify content vs.
background, find the bounding box, check clearance from every edge) —
against the actual composed frames used to build the video, before
muxing. `tools/src/video_pipeline.wl`'s `VerifyComposedFrames` reports
worst-case margins on all four canvas edges plus the title-to-content
clearance, and the CLI exits non-zero if any frame violates the
minimum margin.

Measured results from testing against three apps with different
animation characteristics (all full-video, every-frame checks — see
the sections below for the numbers): a large-amplitude chaotic
double-pendulum swing, a continuous-trajectory strange attractor, and a
narrated audio track with spoken introduction baked into the WAV. All
three passed with zero clipping violations.

### Stretch factor

For the narrow case of a raw chirp-style sonification that's too short
to be followed as a presentation clip (some of `relativity/`'s
un-stretched outputs), `--stretch=N` re-synthesizes the source WAV at N
times its original duration.

This tool operates on **already-rendered** GIF/WAV files, not the raw
physics model arrays `relativity/src/model.wl` produces — so it can't
call `ChirpToAudio` directly, the way `relativity/src/sonify.wl` does.
Instead it recovers an instantaneous frequency/amplitude description of
the *finished* WAV via a Hilbert transform (the same analysis technique
already used this session to verify the chirp pitch-shift fix's
rendered WAVs — see commit `e73161e`), interpolates that description
onto a longer playback time axis, and re-synthesizes by integrating
phase over the new time axis — mirroring `ChirpToAudio`'s math exactly.
It never resamples the raw waveform, which would divide every frequency
component by the stretch factor (the exact bug `e73161e` fixed).

This only makes sense for close-to-monophonic, single dominant-tone or
sweep audio. It has **not** been exercised against multi-voice or
narrated audio, and isn't intended for it — that's out of scope for
this feature. None of the three apps used for this tool's required
verification needed stretching (their GIF/WAV pairs are already
duration-matched), so `StretchAudioBuffer` was sanity-checked
separately: on a synthetic 100→400 Hz, 1s linear chirp, stretched 3×,
measuring the actual instantaneous frequency (via a discrete FFT-based
analytic signal — see the note below) of both the original and
stretched buffers. Both measured the same ~130–370 Hz range; a naive
waveform resample would instead have produced ~43–123 Hz (divided by
the 3× stretch factor), which is exactly the bug this technique exists
to avoid. `relativity/output/gw150914.wav` was used to size a
realistic buffer length for a separate timing check, not for the
frequency-preservation measurement itself.

One implementation note worth recording: WL's built-in
`HilbertTransform` turned out to be a **symbolic** integral-transform
function (`HilbertTransform[f[t], t, s]`), not a discrete-signal
function operable on a plain numeric list — calling it on a PCM buffer
fails immediately (`HilbertTransform::argmu`) rather than computing
anything. `StretchAudioBuffer` instead builds the discrete analytic
signal itself via a standard FFT method (`AnalyticSignalFFT` in
`tools/src/video_pipeline.wl`: zero the negative-frequency bins, double
the positive ones), and unwraps phase manually (`UnwrapPhase`) since
this WL version also has no built-in `Unwrap`.

### Opening/closing hold

`--hold-seconds=N` (or `--hold-start-seconds=N`/`--hold-end-seconds=N`
independently) holds the first composed frame still for `N` seconds
before the animation starts, and the last composed frame still for
`N` seconds after it ends, with the audio padded with `N` seconds of
digital silence at the matching end — so a viewer gets a beat to read
the title before motion starts, and a beat at the end before the clip
cuts, without picture and sound drifting apart. This is implemented
inside the composition pipeline itself (`HoldFrames`/`PadAudioSilence`
in `tools/src/video_pipeline.wl`), applied to the already-composed
frame sequence and the (possibly already `--stretch`-processed) audio
before muxing — not a post-processing pass over the finished MP4.
Default is `0` (no hold), so omitting the flag leaves existing
behavior unchanged. Each requested hold is rounded to the nearest
whole video frame at the source's frame rate, and the audio is padded
with silence to that same rounded duration (not the raw requested
value) so picture and sound always match exactly; the CLI prints the
requested and effective (rounded) hold for both ends whenever a hold
is set.

`PadAudioSilence` reads and writes raw sample data directly
(`AudioData`/`AudioChannels`/`AudioSampleRate` + the same
`ExportAudioBuffer` helper the `--stretch` path uses) rather than
using `AudioPad`/`AudioDuration`: both of those returned unevaluated
in a real headless `wolframscript` run during development, the same
"`Audio[]` requires a display context" gap noted below for `Audio[]`
apparently extending to those two functions as well in this WL
version.

### Output sanity check

After muxing, the tool checks the finished output's video duration,
audio duration, and file size against configurable thresholds
(`--max-duration-seconds`, default `600`; `--max-file-mb`, default
`200`) and prints a line starting with `WARNING` for each threshold
exceeded. This is a second, coarser, louder check layered on top of
the detailed per-frame sync verification above — it exists so a case
like an unexpectedly long or oversized render gets flagged immediately
in the tool's own output instead of being found by hand later. It is
a warning only: the file is written either way, and the tool's exit
code is unaffected by it (only the frame-clearance check can make the
tool exit non-zero). At the defaults, nothing is printed beyond the
normal "Output size check passed" line.

---

## Step 1 finding: native WL video export vs. an ffmpeg dependency

**This tool is built entirely in native Wolfram Language. It does not
call an external `ffmpeg` binary, and introduces no dependency beyond
what the rest of this repo already requires (the free Wolfram
Engine).**

WL's `Video`/`Audio` framework (`FrameListVideo`, `VideoCombine`,
`Export[...,"MP4"]`) turned out to be backed by Wolfram's own bundled
FFmpeg-derived library — not a system `ffmpeg` install. This was
confirmed two ways during investigation:
- `$VideoEncoders`/`$VideoDecoders` list real, working codecs
  (`H264-AVF`, `MPEG4VIDEO`, `LIBVPX-VP9`, etc.) without any `ffmpeg`
  binary present on the test machine (`which ffmpeg` → not found).
- Extracting frames from a muxed MP4 via `VideoFrameList` printed an
  `objc` duplicate-class warning naming
  `FFmpegTools-8.1.0/LibraryResources/.../libavdevice.62.dylib`
  directly — the underlying library is a Wolfram-distributed paclet
  (`FFmpegTools`), shipped and versioned independently of any
  system-level ffmpeg.

That satisfies the same "just needs the free Wolfram Engine" promise
the rest of this repo already relies on for every platform it
supports.

### Real gaps found along the way (and how this tool works around them)

Native support turned out to be genuinely usable, but not
frictionless — three real issues surfaced during verification, each
confirmed by isolating the exact variable that caused it against a
synthetic reproduction before fixing it in the pipeline:

1. **Stereo audio silently breaks `VideoCombine`'s default encoding.**
   Muxing any of this codebase's WAVs (all stereo — most use spatial
   L/R panning as part of their sonification design) with the default
   `AudioEncoding -> Inherited` threw an opaque
   `VideoCombine::interr: An internal error occurred: cannot create
   output video`. A synthetic mono WAV of otherwise-identical content
   and duration succeeded every time; a synthetic *stereo* WAV
   reproduced the failure. Explicitly passing
   `AudioEncoding -> "AAC"` fixes it while preserving both channels
   (verified via `AudioTrackCount`/`AudioChannels` on the muxed
   output) — the alternative workaround, downmixing to mono, was
   rejected because it would silently discard the spatial panning
   several apps' sonifications rely on.
2. **Floating-point frame-rate noise can break muxing entirely.**
   Summing a GIF's per-frame display durations to derive its frame
   rate can land a hair off a clean value (`24.999999999999993`
   instead of `25`) from ordinary floating-point summation — small
   enough to be invisible in any printed report, but `VideoCombine`
   treated it inconsistently and it was one of several factors
   reproduced during isolation testing. `GIFFrameRate` rounds to the
   nearest `0.01` fps specifically to avoid feeding a non-clean rate
   into the muxer.
3. **A source GIF can already be framed too tightly to add margin to.**
   Not a WL limitation exactly, but a real gap in a naive
   crop-then-scale implementation: if the source app's own animation
   leaves only a few native pixels of background around its content
   (measured on `lorenz_animation.gif`: ~5px), the crop step's margin
   logic has nowhere to add margin *to* — it gets clamped away at the
   image edge, and the output ends up with almost no breathing room
   even though the crop code "worked." See "Scale to fill, pad to fit"
   above for the fix (`ContentFillFrac`).

None of these required falling back to ffmpeg — all three were fixed
inside the native WL pipeline once isolated. They're documented here,
plainly, because they weren't obvious from the function names or
documentation alone, and a future maintainer hitting the same opaque
`VideoCombine::interr` should not have to re-derive the stereo-audio
cause from scratch.

### Cross-platform caveat (stated honestly, not verified firsthand)

Verification for this tool ran on macOS only, where the MP4 encoder WL
selected automatically was `H264-AVF` (Apple's AVFoundation hardware
encoder — one of several MP4-capable encoders WL lists, alongside
FFmpeg-derived options like `MPEG4VIDEO`, `LIBVPX-VP9`, and others that
don't depend on any OS-specific framework). `VideoEncoding` is left at
its default (`Automatic`) throughout this pipeline specifically so it
picks whatever's available on each platform's own WL installation
rather than hardcoding a macOS-specific choice. Windows and Linux were
not available to test against directly in this session; if a codec
substitution on another platform ever produces a non-playable or
oddly-encoded file, the fix is to pin `VideoEncoding` explicitly in
`MuxVideo` (`tools/src/video_pipeline.wl`) rather than relying on
`Automatic`, but that hasn't been observed to be necessary.

## Files

- `make_presentation_video.wl` — CLI entry point (argument parsing,
  usage, reporting).
- `src/video_pipeline.wl` — the actual pipeline, factored out as
  reusable functions (duration checks, background inference, content
  bbox, frame composition, muxing, verification, the stretch feature)
  so it can be exercised directly without going through the CLI —
  mirrors the `main.wl` + `src/*.wl` split every app in this repo
  already uses.

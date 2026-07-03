# Image Sonification — Agent Guide

## Project overview

Converts 2D scientific images into audio using a Hilbert curve traversal
(or, in `scan_horizontal` mode, a simple raster scan), making spatial image
structure audible. Nearby pixels in the traversal correspond to nearby
pixels in 2D space (Hilbert only), so gradients and edges in the image
become temporal sweeps and transitions in the audio.

Every run is preceded by a short spoken introduction (image, dimensions,
mode, key mapping) synthesised and prepended to the WAV, so the exported
file begins with orientation and flows directly into the sonification.
See `LISTENING_GUIDE.md` for the user-facing rationale and recommended
listening order — this file covers implementation.

Four modes expose increasing levels of colour information:

| Mode | Data used | Traversal | Output |
|------|-----------|-----------|--------|
| `brightness` | Grayscale value | Hilbert | Mono WAV; linear or log pitch |
| `scan_horizontal` | Grayscale value | Raster (row-major) | Mono WAV; same mapping as brightness, pedagogical contrast |
| `colour` | Nearest spectral-palette colour (Lab distance) | Hilbert | Mono WAV; discrete musical pitches, held notes |
| `hsb` | Hue (pitch, shared), saturation (amplitude), brightness (timbre) | Hilbert | Stereo WAV |

## Project structure

```
images/
  main.wl              — thin orchestrator: loads stem-core + src/, parses config,
                          calls functions, prepends spoken intro, exports final WAV
  config.json           — default simulation parameters
  experiments.wl         — 13 curated preset invocations (RunExperiment)
  LISTENING_GUIDE.md     — user-facing listening order and pitch reference
  AGENTS.md              — this file
  src/
    model.wl            — LoadSourceImage, ComputeImageTraversal, $imgPalette,
                           PaletteLabColors, NearestPaletteIndexLab/NearestPaletteIndex,
                           BrightnessToFreq, RasterTraversalOrder, ColourRunsFromIndices
    sonify.wl            — SonifyImageMode (dispatches brightness/scan_horizontal/colour/hsb),
                           TimbreHarmonics, AddQuadrantClicks, OverlayAt
    speech.wl            — BuildIntroText, BuildIntroBuffer (SpeechSynthesize[] ->
                           platform TTS -> text-only fallback), ResampleLinear
    animate.wl            — AnimateImageTraversal (Hilbert, 32-frame GIF),
                           AnimateRasterScan (raster sweep line, 32-frame GIF)
    output.wl             — ExportImageData (CSV), ExportImagePNG (PNG)
  tests/
    test_model.wl        — unit tests for model.wl (palette, Lab lookup,
                           brightness scaling, run-length encoding, traversal correctness)
  output/                — generated files (gitignored)
```

## How to run

```sh
# Default: brightness mode, 64x64 Gaussian image, log brightness scale
wolframscript -file images/main.wl

# Pedagogical raster scan — compare against brightness on the same image
wolframscript -file images/main.wl -- --simulation.mode=scan_horizontal

# Colour mode (spectral palette)
wolframscript -file images/main.wl -- --simulation.mode=colour

# HSB stereo mode (pitch + timbre)
wolframscript -file images/main.wl -- --simulation.mode=hsb

# Different test images
wolframscript -file images/main.wl -- --simulation.images.test_image=temperature
wolframscript -file images/main.wl -- --simulation.images.test_image=quantum

# Custom image file
wolframscript -file images/main.wl -- --simulation.images.input_file=myimage.png

# Larger image (128x128; audio grows as 128^2 pixels * note_duration_base)
wolframscript -file images/main.wl -- --simulation.images.size=128

# Brightness scaling overrides
wolframscript -file images/main.wl -- --simulation.images.brightness_scale=linear
wolframscript -file images/main.wl -- --simulation.images.brightness_gamma=2.5

# Slower colour scan (held notes easier to count by ear)
wolframscript -file images/main.wl -- --simulation.images.note_duration_base=0.05

# Unit tests
wolframscript -file images/tests/test_model.wl

# All experiments
wolframscript -file images/experiments.wl
```

## Output files

| File | Description |
|------|-------------|
| `images_brightness_audio.wav` | Mono WAV: spoken intro + pixel brightness → pitch |
| `images_brightness.gif` | Hilbert traversal animation (brightness mode) |
| `images_brightness_data.csv` | Per-pixel table: index, col, row, brightness, hue, sat, freq |
| `images_brightness.png` | Processed source image |
| `images_scan_horizontal_*` | Same shape as brightness, but raster traversal + sweep-line GIF |
| `images_colour_audio.wav` | Mono WAV: nearest spectral-palette colour → fixed pitch, held notes |
| `images_colour.gif` | Hilbert traversal animation (colour mode) |
| `images_colour_data.csv` | Per-pixel data (frequency_assigned = palette pitch) |
| `images_colour.png` | Processed source image |
| `images_hsb_audio.wav` | Stereo WAV: hue → shared pitch, brightness → right-channel timbre |
| `images_hsb.gif` | Hilbert traversal animation (HSB mode) |
| `images_hsb_data.csv` | Per-pixel data (frequency_assigned = hue-derived pitch) |
| `images_hsb.png` | Processed source image |

## Data flow

```
config.json + CLI args
        |
   LoadConfig (stem-core)
        |
   LoadSourceImage           → {processedImg, description}
        |
   ComputeImageTraversal      → model Association
        |                      {img, imgN, imgSize, scanDirection, traversal,
        |                       nPixels, pixBright, pixHue, pixSat, rgbData}
        |
   SonifyImageMode            → <|"channels"->{...}, "freqAssigned"->{...},
        |                        "colourStats"->assoc or Missing[]|>
        |
   BuildIntroText/BuildIntroBuffer (speech.wl) → intro PCM buffer (or {})
        |
   Join[intro, pause, channel] per channel, export WAV (main.wl)
        |
   AnimateImageTraversal / AnimateRasterScan → GIF
        |
   ExportImageData            → CSV
   ExportImagePNG              → PNG
```

`SonifyImageMode` no longer exports audio itself — it returns raw PCM
buffers so main.wl (and experiments.wl) can prepend the spoken intro
before a single final WAV export. This is why the reported `STEMDescribeWAV`
duration includes the intro, while the "Audio duration" line printed at
startup is the sonification alone (before the intro).

## Model Association shape

`ComputeImageTraversal` returns:

| Key | Type | Description |
|-----|------|-------------|
| `"img"` | Image | Processed source image (imgSize × imgSize) |
| `"imgN"` | Integer | Curve order (imgSize = 2^imgN) |
| `"imgSize"` | Integer | Image side length in pixels |
| `"scanDirection"` | String | `"hilbert"` or `"raster"` |
| `"traversal"` | {{col,row},...} | 1-based pixel coordinates in traversal order |
| `"nPixels"` | Integer | Total pixels = imgSize^2 |
| `"pixBright"` | List[Real] | Grayscale brightness per traversal pixel, [0,1] |
| `"pixHue"` | List[Real] | HSB hue per traversal pixel, [0,1] |
| `"pixSat"` | List[Real] | HSB saturation per traversal pixel, [0,1] |
| `"rgbData"` | 3D Array | Full RGB image data, indexed [row, col, channel] |

## Sonification design

### Brightness / scan_horizontal modes
- `freqAssigned[i] = BrightnessToFreq[pixBright[i], freqMin, freqMax, brightnessScale, brightnessGamma]`
- `log` scale (default): `freqMin * (freqMax/freqMin)^(brightness^gamma)` — matches
  logarithmic pitch perception; boundary values are exact (`b=0 -> freqMin`, `b=1 -> freqMax`)
- `linear` scale: `freqMin + brightness*(freqMax - freqMin)` (original behaviour)
- Each pixel produces one note of `note_duration_base` seconds (default 20 ms)
- `scan_horizontal` uses `RasterTraversalOrder` instead of `HilbertTraversalOrder`
  for `model["traversal"]`, but is otherwise identical to `brightness`
- Mono output; amplitude fixed at 0.8 with a mild attack/decay envelope
- For images with `imgSize > 32`, `AddQuadrantClicks` mixes in three brief
  880 Hz clicks at the 25%/50%/75% traversal points (brightness mode only,
  not scan_horizontal — see "Quadrant click markers" below)

### Colour mode
- Each pixel is assigned to the nearest of 9 spectral-palette colours
  (`$imgPalette` in `model.wl`) by **Lab colour distance** (`ColorDistance`
  after `ColorConvert[..., "LAB"]`), not RGB Euclidean distance — this
  tracks human colour perception more closely and is why
  `NearestPaletteIndexLab` precomputes the palette's Lab conversion once
  (`PaletteLabColors`) rather than reconverting on every pixel
- Palette order follows the visible spectrum: violet (C3, 130.81 Hz) through
  red (D4, 293.66 Hz), then white (G4, 392.00 Hz, broadband) and black
  (0 Hz, silence — freq 0 produces an all-zero waveform automatically via
  `Sin[2 Pi * 0 * t] = 0`, no special-casing needed in the synth)
- Consecutive pixels with the same colour are merged into a single longer
  note via `ColourRunsFromIndices` (a thin, testable wrapper around `Split`)
  with a tremolo-like envelope (harmonics `{1.0, 0.30}`); duration =
  `runLength * noteDurationBase`
- Mono output

### HSB mode
- Shared fundamental: `freqHue = 100 + pixHue * 3800` Hz, used by **both** channels
- Left channel: pure sine at `freqHue` (harmonics `{1.0}`) — a clean reference pitch
- Right channel: same `freqHue`, but with harmonics from `TimbreHarmonics[pixBright]`:
  `b < 0.333 -> {1.0}` (pure), `b < 0.667 -> {1.0, 0.5}` (+2nd harmonic),
  `b >= 0.667 -> {1.0, 0.5, 0.33}` (+2nd and 3rd harmonics)
- This replaces the earlier design (hue → left freq, brightness → right freq,
  i.e. two independent pitches). The new design gives two *simultaneous*
  scientific channels without requiring the listener to track two pitches:
  **pitch** (shared, both ears) encodes hue/colour; **timbre** (right ear
  only, compared against the left ear's pure reference) encodes brightness.
  This mirrors how the `asteroids` app uses timbre (warm bell vs. bright/harsh)
  to distinguish hazardous from safe objects, rather than a second pitch axis.
- Amplitude: `max(0.10, pixSat)` on both channels — fully desaturated pixels
  still audible
- Both channels normalised separately to 0.92 peak; quadrant clicks applied
  to both

### Quadrant click markers (brightness and hsb only)
`AddQuadrantClicks[buffer, sr, nPixels, noteDurationBase, imgSize]` mixes
(adds, does not concatenate) three 50 ms, 880 Hz clicks into the buffer at
the 25%/50%/75% time offsets, at -20/-15/-20 dB respectively, only when
`imgSize > 32`. Applied *after* `NormalizeBuffer`, so the dB levels are
calibrated relative to full scale; the result is `Clip`-ped to `[-1,1]` as
a defensive measure against the rare sample where a click coincides with a
note peak. Not applied to `colour` mode (the run-length note boundaries
already provide implicit orientation, and a click mid-note would be more
disruptive than helpful) or `scan_horizontal` (the raster traversal is the
pedagogical *contrast* to Hilbert orientation aids, not a candidate for them).

## Spoken orientation guidance (speech.wl)

`BuildIntroText[mode, srcDesc, imgW, imgH, brightnessScale, sonificationDurSec, colourStats]`
assembles one sentence-per-topic intro: image description, dimensions, mode,
the mode's key mapping (different text per mode), colour-mode statistics
(distinct colour count + most common colour) when applicable, and the
sonification duration to follow.

`BuildIntroBuffer[text, sr]` is a three-tier fallback, most to least capable:

1. **`SpeechSynthesize[]`** — Wolfram's built-in TTS, tried first. Not
   reliably available on every Wolfram Engine install (observed to return
   `$Failed` in this environment) — this is why tier 2 exists and is the
   one that actually produces audio in practice.
2. **Platform-native TTS** — macOS `say` + `afconvert`, Linux
   espeak-ng/espeak, Windows PowerShell `SpeechSynthesizer`. Adapted from
   the equivalent (and independently duplicated) helper in
   `signal/src/sonify.wl`. Uses `ResampleLinear` (a general linear
   resampler, any ratio) rather than signal's ratio-2-only upsampler,
   since `SpeechSynthesize[]`/various TTS engines may return arbitrary
   sample rates.
3. **Text-only** — if both audio tiers fail, print the intro via `STEMSay`
   and return `{}`. Callers must check for an empty buffer and skip the
   prepend rather than assume audio is always present.

`main.wl` and `experiments.wl` both: build the intro buffer, normalise it
once (0.95) if non-empty, prepend a 0.4 s pause, then `Join` it in front of
each channel's buffer before the single final WAV export. For `hsb`
(stereo), the *same* intro buffer is duplicated into both channels so the
spoken introduction is centred rather than panned.

**TODO:** `speech.wl`'s TTS helpers duplicate logic already in
`signal/src/sonify.wl`. Once this feature is verified, consolidate into
`stem-core` (explicitly out of scope for this pass — see the images/
enhancement spec).

## The Hilbert curve

The Hilbert curve is a space-filling curve with the property that nearby
points in 1D (traversal order) are nearby in 2D (image space). This
makes it ideal for sonification: temporal proximity in the audio maps to
spatial proximity in the image. `scan_horizontal` mode deliberately uses a
plain raster order instead, as a pedagogical contrast — it lacks this
locality property (the traversal jumps from the end of one row to the
start of the next, which are far apart in the image).

`HilbertTraversalOrder[n]` (from stem-core) returns a list of `4^n` pixel
coordinates covering a `2^n × 2^n` grid in Hilbert order. `RasterTraversalOrder[n]`
(in `model.wl`) returns the same shape of list in simple row-major order.
Order 6 covers 64×64; order 7 covers 128×128.

## Common pitfalls

1. **Image size must be a power of 2**: the code rounds `imgSizeCfg` to the
   nearest power of 2 (capped at 256 = order 8). A 100×100 image becomes 128×128.

2. **`rgbData` indexing**: `rgbData[[ row, col, channel ]]` — row is the
   vertical index (1 = top), col is horizontal (1 = left). The traversal
   stores `{col, row}` pairs. Always index `rgbData[[ traversal[[i,2]],
   traversal[[i,1]] ]]`.

3. **GIF orientation**: `ImageData` returns rows top-to-bottom (row 1 = top),
   but `Raster` in `Graphics` has its origin at bottom-left. `Reverse`ing the
   `displayData` array corrects this before calling `Raster` — both
   `AnimateImageTraversal` and `AnimateRasterScan` do this identically.

4. **HSB export bypasses ExportAudioBuffer**: the stereo WAV uses WL's built-in
   `Sound[SampledSoundList[{leftBuf, rightBuf}, sr]]` and `Export[..., "WAV"]`
   directly, since `ExportAudioBuffer` only handles mono. This is intentional,
   and is why the intro-prepend logic in main.wl branches on
   `Length[channels] === 1` rather than checking `mode === "hsb"` directly
   (keeps the branch generic if a future mode returns multiple channels).

5. **Colour mode note merging**: `ColourRunsFromIndices` (== `Split`) groups
   consecutive equal elements. For images with smooth gradients nearly all
   colour runs are length 1, so the run-length encoding provides little
   compression but keeps the phrasing structure intact.

6. **Black = silence, not a special case**: the black palette entry has
   `freq -> 0.0`. `StemSynthNote` naturally produces an all-zero buffer
   for any harmonics list when freq is 0 (`Sin[2 Pi * 0 * k * t] = 0` for
   every k), so no conditional logic is needed anywhere in the synthesis
   path to make black silent.

7. **`BrightnessToFreq`'s optional-argument syntax**: `scaleType_String : "log"`
   is fine, but `gamma_?NumericQ : 1.0` is **not** — Wolfram parses
   `_?test : default` as `_?(test : default)`, silently producing a pattern
   that never matches (the whole function then fails to evaluate on every
   call, with no error, just an unevaluated expression). The fix is
   `Optional[gamma_?NumericQ, 1.0]` as an explicit function call instead of
   the infix `:` operator. This is a genuine Wolfram Language gotcha, not
   specific to this file — worth remembering anywhere a test-constrained
   pattern needs a default value.

## Physics / image modification guidance

Built-in test images are generated analytically from formulas — no file loading.
To add a new test image, add a case to the `Switch` in `LoadSourceImage` and
update `config.json` to document the new name.

To change the palette, edit `$imgPalette` in `src/model.wl`. The CSV column
`frequency_assigned` stores whatever frequency `SonifyImageMode` assigns,
so palette changes propagate automatically to all outputs. Keep entries
ordered by `spectral_position` if you want the pitch-rises-with-wavelength
property to remain intuitive; `NearestPaletteIndexLab` doesn't care about
list order, but listeners build a mental model from it.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSay`, `STEMDescribeWAV`, `STEMDescribeGIF`,
  `STEMDescribeCSV`, `FmtN`, `STEMPlayCmd`, `HilbertTraversalOrder`,
  `StemSynthNote`, `NormalizeBuffer`, `ExportAudioBuffer`,
  `ExportGIF`, `ExportCSV`, `EnsureDir`
- **Mathematica/WL**: `Image`, `ImageData`, `ColorConvert`, `ColorDistance`,
  `RGBColor`, `ImageResize`, `ImageDimensions`, `Sound`, `SampledSoundList`,
  `Graphics`, `Raster`, `Rectangle`, `Disk`, `Line`, `Export`,
  `SpeechSynthesize`, `AudioQ`, `AudioData`, `AudioSampleRate`, `RunProcess`
  (platform TTS fallback), `Import` (reading TTS-generated WAV files)

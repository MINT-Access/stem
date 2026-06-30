# Image Sonification — Agent Guide

## Project overview

Converts 2D scientific images into audio using a Hilbert curve traversal,
making spatial image structure audible. Nearby pixels in the traversal
correspond to nearby pixels in 2D space, so gradients and edges in the
image become temporal sweeps and transitions in the audio.

Three modes expose increasing levels of colour information:

| Mode | Data used | Output |
|------|-----------|--------|
| `brightness` | Grayscale value | Mono WAV; linear pitch |
| `colour` | Nearest named colour | Mono WAV; discrete musical pitches |
| `hsb` | Hue, saturation, brightness | Stereo WAV; two independent pitch channels |

## Project structure

```
images/
  main.wl            — thin orchestrator: loads stem-core + src/, parses config, calls functions
  config.json        — default simulation parameters
  experiments.wl     — 8 curated preset invocations (RunExperiment)
  AGENTS.md          — this file
  src/
    model.wl         — LoadSourceImage, ComputeImageTraversal, $imgPalette
    sonify.wl        — SonifyImageMode (dispatches brightness/colour/hsb)
    animate.wl       — AnimateImageTraversal (32-frame GIF)
    output.wl        — ExportImageData (CSV), ExportImagePNG (PNG)
  tests/
    test_model.wl    — unit tests for model.wl (palette, image loading, traversal)
  output/            — generated files (gitignored)
```

## How to run

```sh
# Default: brightness mode, 64x64 Gaussian image
wolframscript -file images/main.wl

# Colour mode
wolframscript -file images/main.wl -- --simulation.mode=colour

# HSB stereo mode
wolframscript -file images/main.wl -- --simulation.mode=hsb

# Different test images
wolframscript -file images/main.wl -- --simulation.images.test_image=temperature
wolframscript -file images/main.wl -- --simulation.images.test_image=quantum

# Custom image file
wolframscript -file images/main.wl -- --simulation.images.input_file=myimage.png

# Larger image (128x128; note: audio grows as 128^2 pixels * 0.05 s = 819 s)
wolframscript -file images/main.wl -- --simulation.images.size=128

# Unit tests
wolframscript -file images/tests/test_model.wl

# All experiments
wolframscript -file images/experiments.wl
```

## Output files

| File | Description |
|------|-------------|
| `images_brightness_audio.wav` | Mono WAV: pixel brightness → pitch |
| `images_brightness.gif` | Hilbert traversal animation (brightness mode) |
| `images_brightness_data.csv` | Per-pixel table: index, col, row, brightness, hue, sat, freq |
| `images_brightness.png` | Processed source image |
| `images_colour_audio.wav` | Mono WAV: nearest palette colour → fixed pitch |
| `images_colour.gif` | Hilbert traversal animation (colour mode) |
| `images_colour_data.csv` | Per-pixel data (frequency_assigned = palette pitch) |
| `images_colour.png` | Processed source image |
| `images_hsb_audio.wav` | Stereo WAV: hue → left freq, brightness → right freq |
| `images_hsb.gif` | Hilbert traversal animation (HSB mode) |
| `images_hsb_data.csv` | Per-pixel data (frequency_assigned = hue-derived left freq) |
| `images_hsb.png` | Processed source image |

## Data flow

```
config.json + CLI args
        |
   LoadConfig (stem-core)
        |
   LoadSourceImage         → {processedImg, description}
        |
   ComputeImageTraversal   → model Association
        |                    {img, imgN, imgSize, traversal, nPixels,
        |                     pixBright, pixHue, pixSat, rgbData}
        |
   SonifyImageMode         → freqAssigned[]
        |
   AnimateImageTraversal   → GIF
        |
   ExportImageData         → CSV
   ExportImagePNG          → PNG
```

## Model Association shape

`ComputeImageTraversal` returns:

| Key | Type | Description |
|-----|------|-------------|
| `"img"` | Image | Processed source image (imgSize × imgSize) |
| `"imgN"` | Integer | Hilbert curve order (imgSize = 2^imgN) |
| `"imgSize"` | Integer | Image side length in pixels |
| `"traversal"` | {{col,row},...} | 1-based pixel coordinates in Hilbert order |
| `"nPixels"` | Integer | Total pixels = imgSize^2 |
| `"pixBright"` | List[Real] | Grayscale brightness per traversal pixel, [0,1] |
| `"pixHue"` | List[Real] | HSB hue per traversal pixel, [0,1] |
| `"pixSat"` | List[Real] | HSB saturation per traversal pixel, [0,1] |
| `"rgbData"` | 3D Array | Full RGB image data, indexed [row, col, channel] |

## Sonification design

### Brightness mode
- `freqAssigned[i] = freqMin + pixBright[i] * (freqMax - freqMin)`
- Default range: 200–2000 Hz (one decade, musically a major 10th or so)
- Each pixel produces one note of `note_duration` seconds (default 50 ms)
- Mono output; amplitude fixed at 0.8 with a mild attack/decay envelope

### Colour mode
- Each pixel is assigned to the nearest of 10 named palette colours by
  Euclidean distance in RGB space
- Each colour has a fixed musical pitch (C2–E5 range); see `$imgPalette`
- Consecutive pixels with the same colour are merged into a single longer note
  with a tremolo-like envelope (harmonics {1.0, 0.30})
- Mono output

### HSB mode (Rangan 2018)
- Left channel: `freqL = 100 + pixHue * 3800` Hz
- Right channel: `freqR = 100 + pixBright * 3800` Hz
- Amplitude: `max(0.10, pixSat)` — fully desaturated pixels still audible
- Each pixel produces independent left/right notes of equal duration
- Both channels normalised separately to 0.92 peak

## The Hilbert curve

The Hilbert curve is a space-filling curve with the property that nearby
points in 1D (traversal order) are nearby in 2D (image space). This
makes it ideal for sonification: temporal proximity in the audio maps to
spatial proximity in the image.

`HilbertTraversalOrder[n]` (from stem-core) returns a list of `4^n` pixel
coordinates covering a `2^n × 2^n` grid in Hilbert order. Order 6 covers
64×64; order 7 covers 128×128.

## Common pitfalls

1. **Image size must be a power of 2**: the code rounds `imgSizeCfg` to the
   nearest power of 2 (capped at 256 = order 8). A 100×100 image becomes 128×128.

2. **`rgbData` indexing**: `rgbData[[ row, col, channel ]]` — row is the
   vertical index (1 = top), col is horizontal (1 = left). The traversal
   stores `{col, row}` pairs. Always index `rgbData[[ traversal[[i,2]],
   traversal[[i,1]] ]]`.

3. **GIF orientation**: `ImageData` returns rows top-to-bottom (row 1 = top),
   but `Raster` in `Graphics` has its origin at bottom-left. `Reverse`ing the
   `displayData` array corrects this before calling `Raster`.

4. **HSB export bypasses ExportAudioBuffer**: the stereo WAV uses WL's built-in
   `Sound[SampledSoundList[{leftBuf, rightBuf}, sr]]` and `Export[..., "WAV"]`
   directly, since `ExportAudioBuffer` only handles mono. This is intentional.

5. **Colour mode note merging**: `Split[colourIdxSeq]` groups consecutive equal
   elements. For images with smooth gradients nearly all colour runs are length
   1, so the run-length encoding provides little compression but keeps the
   musical phrasing structure.

## Physics / image modification guidance

Built-in test images are generated analytically from formulas — no file loading.
To add a new test image, add a case to the `Switch` in `LoadSourceImage` and
update `config.json` to document the new name.

To change the palette, edit `$imgPalette` in `src/model.wl`. The CSV column
`frequency_assigned` stores whatever frequency `SonifyImageMode` assigns,
so palette changes propagate automatically to all outputs.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSay`, `STEMDescribeWAV`, `STEMDescribeGIF`,
  `STEMDescribeCSV`, `FmtN`, `STEMPlayCmd`, `HilbertTraversalOrder`,
  `StemSynthNote`, `NormalizeBuffer`, `ExportAudioBuffer`,
  `ExportGIF`, `ExportCSV`, `EnsureDir`
- **Mathematica/WL**: `Image`, `ImageData`, `ColorConvert`, `ImageResize`,
  `ImageDimensions`, `Sound`, `SampledSoundList`, `Graphics`, `Raster`,
  `Disk`, `Line`, `Export`

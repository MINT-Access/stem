# Images

2D image sonification using Hilbert curve traversal. Converts spatial image
data — scientific visualisations, false-colour maps, probability densities —
into audio, making visual structure accessible through sound.

## How it works

Every image is resized to a 2^n × 2^n grid (default 64×64) and its pixels
are visited in Hilbert curve order. The Hilbert curve has a strong
locality-preserving property: pixels that are close together in the traversal
sequence are also close together in 2D space. This means spatial structure
(gradients, blobs, colour regions) becomes temporal structure in the audio —
you hear the image as it would be read by a systematic spatial scanner that
never teleports.

Three sonification modes are available, ranging from simple and accessible to
information-dense.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically

## Quick start

```sh
# Brightness mode, Gaussian test image (default)
wolframscript -file main.wl

# Colour mode
wolframscript -file main.wl -- --simulation.mode=colour

# Full HSB stereo mode
wolframscript -file main.wl -- --simulation.mode=hsb

# Different test images
wolframscript -file main.wl -- --simulation.images.test_image=temperature
wolframscript -file main.wl -- --simulation.images.test_image=quantum

# Your own image file
wolframscript -file main.wl -- --simulation.images.input_file=myimage.png

# Larger image (128x128)
wolframscript -file main.wl -- --simulation.images.size=128

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Modes

### brightness (default)

Each pixel's grayscale brightness maps linearly to frequency: dark pixels
produce low pitches, bright pixels produce high pitches. The default range is
200–2000 Hz. Each pixel is a short note of fixed duration (50 ms default).

**Best for:** first-time listeners. Smooth spatial gradients become smooth
pitch sweeps; sharp edges become abrupt pitch jumps. The Hilbert locality
means a uniform gradient produces a smooth continuous glide rather than a
random-sounding scatter.

```sh
wolframscript -file main.wl
# macOS:   afplay output/images_brightness_audio.wav
# Linux:   aplay  output/images_brightness_audio.wav
# Windows: Start-Process wmplayer output\images_brightness_audio.wav
```

### colour

Each pixel is mapped to the nearest of 10 named colours using Euclidean
distance in RGB space. Each colour has a fixed musical pitch (see table
below). Consecutive pixels with the same colour produce a single held note
rather than repeated attacks — so a red region is one long note at 196 Hz,
not hundreds of rapid 196 Hz clicks.

**Best for:** images with distinct colour regions (maps, categorical data,
false-colour scientific images). The colour-to-pitch table below lets a
listener build a mental map of which pitch means which colour.

```sh
wolframscript -file main.wl -- --simulation.mode=colour
# macOS:   afplay output/images_colour_audio.wav
# Linux:   aplay  output/images_colour_audio.wav
# Windows: Start-Process wmplayer output\images_colour_audio.wav
```

### hsb

Full-colour stereo sonification based on the approach of Rangan (2018).
Three image properties map to three audio properties simultaneously:

| Image property | Audio encoding |
|---|---|
| Hue | Left channel frequency (100–3900 Hz) |
| Brightness | Right channel frequency (100–3900 Hz) |
| Saturation | Amplitude of both channels (min 0.10) |

This is the most information-dense mode: a pure red pixel (hue=0, sat=1,
bri=0.5) produces a 100 Hz left tone with moderate amplitude; a bright cyan
pixel (hue=0.5, sat=1, bri=1) produces a 2050 Hz left tone and a 3900 Hz
right tone.

**Best for:** experienced listeners exploring full-colour scientific images.
Start with brightness mode first to build familiarity with the traversal
pattern before adding the two-channel encoding.

```sh
wolframscript -file main.wl -- --simulation.mode=hsb
# macOS:   afplay output/images_hsb_audio.wav
# Linux:   aplay  output/images_hsb_audio.wav
# Windows: Start-Process wmplayer output\images_hsb_audio.wav
```

## Colour-to-pitch mapping (colour mode)

The 10 colours are assigned to a C major scale spanning C3 to C5, chosen
so that adjacent scale degrees correspond to perceptually distinct colours:

| Colour | Pitch | Frequency |
|--------|-------|-----------|
| Black  | C3    | 130.81 Hz |
| Grey   | D3    | 164.81 Hz |
| Red    | E3    | 196.00 Hz |
| Orange | G3    | 220.00 Hz |
| Yellow | A3    | 261.63 Hz |
| Green  | C4    | 329.63 Hz |
| Cyan   | E4    | 392.00 Hz |
| Blue   | G4    | 440.00 Hz |
| Violet | A4    | 523.25 Hz |
| White  | C5    | 659.25 Hz |

The mapping is monotonic in perceived brightness: dark colours (black, grey)
map to low pitches; light colours (violet, white) map to high pitches. This
means the colour mode and brightness mode agree on the overall pitch contour,
while the colour mode additionally encodes hue identity through the specific
pitch choice.

## Built-in test images

Three scientific test images are built in and require no external file:

### gaussian (default)

A 2D Gaussian distribution centred on the image. Grayscale: black at the
edges, white at the centre. Good for learning the traversal pattern.

**Brightness mode:** listen for a slow sweep from low to high pitch as the
Hilbert curve spirals inward toward the bright centre. The sweep is not
monotone — the curve backtracks through dark regions — but has a clear
upward trend as it approaches the peak.

**Colour mode:** mostly black (low-C3) at the edges giving way to white
(high-C5) at the centre. The held-note logic means each concentric colour
band sounds as a distinct chord tone, not a rapid fire of clicks.

```sh
wolframscript -file main.wl -- --simulation.images.test_image=gaussian
```

### temperature

A radial false-colour temperature map: blue at the centre, cycling through
cyan, green, yellow, and red toward the edges. Designed to exercise the
colour mode with a full range of hues.

**Colour mode:** listen for a cycle through the pitch scale from low (blue
at the centre) to high (red at the edges), then back again as the Hilbert
curve reverses direction.

**HSB mode:** the full hue range (0–1) sweeps the left channel through the
entire 100–3900 Hz range. The saturation is constant and high, so the
amplitude is uniform.

```sh
wolframscript -file main.wl -- --simulation.images.test_image=temperature
```

### quantum

The |ψ_{1,2}(x,y)|² probability density for a 2D particle in a box, with
quantum numbers (nx=1, ny=2). Produces four probability lobes (two bright,
two less bright) arranged in a 2×2 pattern. Connects thematically to the
`quantum` app.

**Brightness mode:** hear the four-lobe structure as alternating loud and
quiet regions. The Hilbert curve locality means the two lobes on the same
row are heard consecutively before the curve jumps to the next row.

**HSB mode:** the false-colour rendering (black→red→yellow→white) maps the
density to left-channel frequency as a rising sweep within each lobe.

```sh
wolframscript -file main.wl -- --simulation.images.test_image=quantum
```

## Outputs

| File | Description |
|------|-------------|
| `output/images_<mode>_audio.wav` | Sonification audio (16-bit PCM, 44100 Hz) |
| `output/images_<mode>.gif` | 32-frame Hilbert traversal animation |
| `output/images_<mode>_data.csv` | Per-pixel table: index, col, row, brightness, hue, saturation, frequency |
| `output/images_<mode>.png` | The processed (resized) source image |

The CSV columns are:

| Column | Description |
|--------|-------------|
| `hilbert_index` | Position in the Hilbert traversal sequence (1 = first pixel visited) |
| `col` | Pixel column (1-based, left to right) |
| `row` | Pixel row (1-based, top to bottom) |
| `brightness` | Grayscale brightness [0, 1] |
| `hue` | HSB hue [0, 1] |
| `saturation` | HSB saturation [0, 1] |
| `frequency_assigned` | Frequency in Hz assigned in this mode |

## Performance notes

Audio duration scales as `pixels × note_duration`:

| Image size | Pixels | Duration at 50 ms/pixel |
|---|---|---|
| 32×32  | 1,024   | ~51 s |
| 64×64  | 4,096   | ~205 s (~3.4 min) |
| 128×128 | 16,384 | ~819 s (~14 min) |
| 256×256 | 65,536 | ~55 min |

Reduce `--simulation.images.note_duration` (e.g. `0.01`) or image size
for faster exploration. The colour mode's note-holding logic can substantially
reduce audio duration when large image regions have uniform colour.

## Project structure

```
images/
  main.wl           — Entry point (thin orchestrator)
  experiments.wl    — Curated preset runs
  config.json       — App defaults
  src/
    model.wl        — LoadSourceImage, ComputeImageTraversal, colour palette
    sonify.wl       — SonifyImageMode (brightness / colour / hsb dispatch)
    animate.wl      — AnimateImageTraversal (32-frame GIF)
    output.wl       — ExportImageData, ExportImagePNG
  tests/
    test_model.wl   — Unit tests (palette shape, traversal correctness)
  output/           — Output files (not committed)
  README.md
  AGENTS.md
```

## Console output

Step numbers `[1/5]` through `[5/5]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

## Credits and further reading

The Hilbert curve traversal approach for image sonification is based on two
Wolfram Community contributions:

**Rangan (2018)** — *Image Sonification Using Hilbert Curves.*
Wolfram Community. Uses Wolfram's built-in `HilbertCurve[]` to traverse image
pixels in locality-preserving order, converting HSB colour values to audio
(hue → frequency, saturation → amplitude, brightness → stereo channel).
Source of the `hsb` mode design.

**Rao (WSRP25)** — *Sonification Strategies for 2D Images.*
Wolfram Summer Research Program. Two row-by-row methods: brightness mapping
and nearest-colour mapping with held notes for colour runs.
Source of the `brightness` and `colour` mode designs.

The `HilbertTraversalOrder[n]` function is provided by `stem-core/src/hilbert.wl`
and implements the standard d2xy bijection, equivalent to the traversal
encoded in Wolfram's `HilbertCurve[n, 2]`.

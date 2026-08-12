# Images

2D image sonification using Hilbert curve traversal (and, in
`scan_horizontal` mode, a simple raster scan). Converts spatial image
data — scientific visualisations, false-colour maps, probability
densities — into audio, making visual structure accessible through sound.

**New to image sonification?** Start with
[`images/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — a short, concrete
guide to the recommended listening order and the colour-to-pitch table.

## How it works

Every image is resized to a 2^n × 2^n grid (default 64×64) and its pixels
are visited in Hilbert curve order (or, in `scan_horizontal` mode, a plain
row-by-row raster order). The Hilbert curve has a strong
locality-preserving property: pixels that are close together in the traversal
sequence are also close together in 2D space. This means spatial structure
(gradients, blobs, colour regions) becomes temporal structure in the audio —
you hear the image as it would be read by a systematic spatial scanner that
never teleports. The raster scan lacks this property (it jumps back to the
start of the row after every row), which makes it a useful pedagogical
contrast: hear `scan_horizontal` first, then `brightness`, to experience the
Hilbert improvement directly.

Every run begins with a short spoken introduction — the image, its
dimensions, the mode, and how to interpret the pitches and timbres that
follow — synthesised and prepended to the WAV before export, so the file
starts with orientation and flows directly into the sonification.

Four sonification modes are available, ranging from simple and accessible to
information-dense.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically
- Optional for the spoken intro: macOS `say` (built in), Linux
  `espeak-ng` or `espeak`, or Windows PowerShell (built in) — the app
  falls back gracefully to text-only output if none is available

## Quick start

```sh
# Brightness mode, Gaussian test image (default; logarithmic pitch scale)
wolframscript -file main.wl

# Pedagogical simple scan — compare against brightness mode on the same image
wolframscript -file main.wl -- --simulation.mode=scan_horizontal

# Colour mode (spectral palette)
wolframscript -file main.wl -- --simulation.mode=colour

# Full HSB stereo mode (pitch + timbre)
wolframscript -file main.wl -- --simulation.mode=hsb

# Different test images
wolframscript -file main.wl -- --simulation.images.test_image=temperature
wolframscript -file main.wl -- --simulation.images.test_image=quantum

# Your own image file
wolframscript -file main.wl -- --simulation.images.input_file=myimage.png

# Larger image (128x128)
wolframscript -file main.wl -- --simulation.images.size=128

# Override brightness scaling (default is log; linear is also available)
wolframscript -file main.wl -- --simulation.images.brightness_scale=linear
wolframscript -file main.wl -- --simulation.images.brightness_gamma=2.0

# Slower colour scan (held notes easier to count by ear)
wolframscript -file main.wl -- --simulation.images.note_duration_base=0.05

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Modes

### brightness (default)

Each pixel's grayscale brightness maps to frequency: dark pixels produce low
pitches, bright pixels produce high pitches. The default range is
200–2000 Hz. Each pixel is a short note of `note_duration_base` seconds
(default 20 ms).

Brightness-to-frequency scaling is configurable via
`--simulation.images.brightness_scale`:

- `log` (default) — `freq = freqMin * (freqMax/freqMin)^(brightness^gamma)`.
  Matches how human hearing perceives frequency logarithmically, and suits
  most scientific data, which is rarely uniformly distributed. `gamma`
  (default 1.0) reshapes the curve: values above 1 compress the highlights
  (only the very brightest pixels reach the top of the range); values below
  1 compress the shadows instead.
- `linear` — `freq = freqMin + brightness*(freqMax - freqMin)`, the
  original behaviour.

For images larger than 32×32, four brief 880 Hz click markers are mixed in
at the 25%, 50%, and 75% points of the traversal — a subtle orientation
aid, like an audible grid line, so a listener can track spatial progress
through a long traversal without a spoken interruption.

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

### scan_horizontal

The pedagogical counterpart to `brightness`: the exact same brightness-to-
frequency mapping (respecting `brightness_scale`/`brightness_gamma`), but
traversed in a simple left-to-right, row-by-row raster scan instead of
Hilbert order. The GIF shows a horizontal sweep line moving down the image
row by row, rather than the Hilbert curve path.

**Best for:** hearing exactly what the Hilbert curve buys you. Listen to
this mode first, then `brightness` on the same image — the raster version
jumps abruptly at the end of every row (nearby pixels in the image are
*not* nearby in time), while the Hilbert version glides smoothly.

```sh
wolframscript -file main.wl -- --simulation.mode=scan_horizontal
# macOS:   afplay output/images_scan_horizontal_audio.wav
# Linux:   aplay  output/images_scan_horizontal_audio.wav
# Windows: Start-Process wmplayer output\images_scan_horizontal_audio.wav
```

### colour

Each pixel is mapped to the nearest of 9 colours — 7 spanning the visible
light spectrum from violet to red, plus white for broadband/saturated colour
and black for absent/zero colour — using colour distance in the perceptually
uniform Lab colour space. Each
colour has a fixed musical pitch that rises with spectral position (see
table below). Consecutive pixels with the same colour produce a single
held note rather than repeated attacks — so a large red region is one long
note, not hundreds of rapid clicks — with duration proportional to region
size via `--simulation.images.note_duration_base` (default 0.02 s/pixel).

**Best for:** images with distinct colour regions (maps, categorical data,
false-colour scientific images). The colour-to-pitch table below lets a
listener build a mental map of which pitch means which colour, and the
held-note duration directly tells you how large a region is.

```sh
wolframscript -file main.wl -- --simulation.mode=colour
# macOS:   afplay output/images_colour_audio.wav
# Linux:   aplay  output/images_colour_audio.wav
# Windows: Start-Process wmplayer output\images_colour_audio.wav
```

### hsb

Full-colour stereo sonification. Hue maps to a shared pitch on both
channels; saturation controls amplitude on both channels; and — unlike a
simple two-frequency stereo split — brightness is encoded as **timbre**
rather than a second pitch:

| Image property | Audio encoding |
|---|---|
| Hue | Pitch, shared by both channels (100–3900 Hz) |
| Brightness | Timbre of the right channel: pure sine (dark) → + 2nd harmonic (medium) → + 2nd and 3rd harmonics (bright) |
| Saturation | Amplitude of both channels (min 0.10) |

The left channel is always a clean, pure-sine reference tone at the
hue-mapped pitch. The right channel plays the *same* pitch but with
increasingly rich harmonic content as the pixel gets brighter. This gives
two simultaneous scientific channels — pitch encodes colour, timbre
encodes brightness — the same principle the `asteroids` app uses to
distinguish hazardous from safe objects by timbre.

**Best for:** experienced listeners exploring full-colour scientific images.
Start with `brightness` mode first to build familiarity with the traversal
pattern before adding the pitch+timbre encoding.

```sh
wolframscript -file main.wl -- --simulation.mode=hsb
# macOS:   afplay output/images_hsb_audio.wav
# Linux:   aplay  output/images_hsb_audio.wav
# Windows: Start-Process wmplayer output\images_hsb_audio.wav
```

## Colour-to-pitch mapping (colour and hsb modes' pitch reference)

The 7 spectral colours are ordered by position in the visible light
spectrum — violet (shortest wavelength) to red (longest) — plus white
(broadband/saturated) and black (absent/zero, heard as silence):

| Colour | Pitch | Frequency |
|--------|-------|-----------|
| Violet | C3 | 130.81 Hz |
| Blue   | D3 | 146.83 Hz |
| Cyan   | F3 | 174.61 Hz |
| Green  | G3 | 196.00 Hz |
| Yellow | A3 | 220.00 Hz |
| Orange | C4 | 261.63 Hz |
| Red    | D4 | 293.66 Hz |
| White  | G4 | 392.00 Hz |
| Black  | — (silent) | 0 Hz |

Pitch rises monotonically with spectral position, so the pitch contour
tracks the rainbow directly: violet is the lowest note, red is the
highest, and a long held note in `colour` mode means a large uniform
region of that colour. See `LISTENING_GUIDE.md` for a fuller explanation
and listening tips.

## Built-in test images

Three scientific test images are built in and require no external file:

### gaussian (default)

A 2D Gaussian distribution centred on the image. Grayscale: black at the
edges, white at the centre. Good for learning the traversal pattern.

**Brightness mode:** listen for a slow sweep from low to high pitch as the
Hilbert curve spirals inward toward the bright centre. The sweep is not
monotone — the curve backtracks through dark regions — but has a clear
upward trend as it approaches the peak.

**Colour mode:** mostly violet (lowest pitch) at the edges giving way to
white (highest pitch) at the centre. The held-note logic means each
concentric colour band sounds as a distinct pitch, not a rapid fire of
clicks.

```sh
wolframscript -file main.wl -- --simulation.images.test_image=gaussian
```

### temperature

A radial false-colour temperature map: blue at the centre, cycling through
cyan, green, yellow, and red toward the edges. Designed to exercise the
colour mode with a full range of hues.

**Colour mode:** listen for a cycle through the spectral pitch scale from
blue (low-ish) at the centre out through cyan, green, yellow, to red
(highest) at the edges, then back again as the Hilbert curve reverses
direction.

**HSB mode:** the full hue range (0–1) sweeps the shared pitch through the
entire 100–3900 Hz range; the saturation is constant and high, so the
amplitude is uniform, and the timbre channel tracks brightness.

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

**HSB mode:** the false-colour rendering (black→red→yellow→white) maps
brightness to right-channel timbre — the two bright lobes stand out as
richer, more harmonically complex tones against the quieter, purer-toned
background.

```sh
wolframscript -file main.wl -- --simulation.images.test_image=quantum
```

## Outputs

| File | Description |
|------|-------------|
| `output/images_<mode>_audio.wav` | Spoken intro + sonification, single file (16-bit PCM, 44100 Hz) |
| `output/images_<mode>.gif` | Traversal animation, frame count/rate synced to the WAV's duration (Hilbert path, or horizontal sweep line for scan_horizontal) |
| `output/images_<mode>_data.csv` | Per-pixel table: index, col, row, brightness, hue, saturation, frequency |
| `output/images_<mode>.png` | The processed (resized) source image |

The CSV columns are:

| Column | Description |
|--------|-------------|
| `hilbert_index` | Position in the traversal sequence (1 = first pixel visited) |
| `col` | Pixel column (1-based, left to right) |
| `row` | Pixel row (1-based, top to bottom) |
| `brightness` | Grayscale brightness [0, 1] |
| `hue` | HSB hue [0, 1] |
| `saturation` | HSB saturation [0, 1] |
| `frequency_assigned` | Frequency in Hz assigned in this mode |

## Configuration parameters (`images/config.json`)

| Key | Default | Description |
|-----|---------|--------------|
| `simulation.mode` | `"brightness"` | `brightness`, `scan_horizontal`, `colour`, or `hsb` |
| `simulation.images.size` | `64` | Image side length in pixels; rounded to the nearest power of 2 (max 256) |
| `simulation.images.input_file` | `""` | Path to a custom image file; overrides `test_image` when non-empty |
| `simulation.images.test_image` | `"gaussian"` | Built-in test image: `gaussian`, `temperature`, or `quantum` |
| `simulation.images.freq_min` | `200` | Lowest frequency (Hz) for brightness/scan_horizontal modes |
| `simulation.images.freq_max` | `2000` | Highest frequency (Hz) for brightness/scan_horizontal modes |
| `simulation.images.brightness_scale` | `"log"` | `log` (default) or `linear` brightness-to-frequency mapping |
| `simulation.images.brightness_gamma` | `1.0` | Log-scale exponent; >1 compresses highlights, <1 compresses shadows |
| `simulation.images.note_duration_base` | `0.02` | Seconds per pixel (brightness/scan_horizontal/hsb); seconds-per-pixel run-length factor (colour) |
| `simulation.images.scan_direction` | `"hilbert"` | `hilbert` (default) or `raster`; `scan_horizontal` always uses raster regardless of this key |

## Performance notes

Audio duration scales as `pixels × note_duration_base`:

| Image size | Pixels | Duration at 20 ms/pixel (default) |
|---|---|---|
| 32×32  | 1,024   | ~20 s |
| 64×64  | 4,096   | ~82 s |
| 128×128 | 16,384 | ~328 s (~5.5 min) |
| 256×256 | 65,536 | ~22 min |

Reduce `--simulation.images.note_duration_base` (e.g. `0.005`) or image size
for faster exploration. The colour mode's note-holding logic can substantially
reduce audio duration when large image regions have uniform colour.

## Project structure

```
images/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl       — 13 curated preset runs
  config.json          — App defaults
  LISTENING_GUIDE.md    — Recommended listening order and pitch reference
  src/
    model.wl           — LoadSourceImage, ComputeImageTraversal, $imgPalette,
                          NearestPaletteIndex, BrightnessToFreq, RasterTraversalOrder,
                          ColourRunsFromIndices
    sonify.wl           — SonifyImageMode (brightness/scan_horizontal/colour/hsb dispatch)
    speech.wl           — Spoken intro synthesis (SpeechSynthesize -> platform TTS ->
                          text-only fallback) and BuildIntroText
    animate.wl          — AnimateImageTraversal (Hilbert), AnimateRasterScan (raster)
    output.wl           — ExportImageData, ExportImagePNG
  tests/
    test_model.wl       — Unit tests (palette, Lab lookup, brightness scaling,
                          run-length encoding, traversal correctness)
  output/               — Output files (not committed)
  README.md
  AGENTS.md
```

## Console output

Step numbers `[1/5]` through `[5/5]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. The spoken introduction text is printed before
synthesis and, when a TTS engine is available, is also embedded as audio
at the start of the WAV file. Set `STEM_SPEAK=1` for spoken stage
announcements in addition to the intro:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

## Credits and further reading

The Hilbert curve traversal approach for image sonification is based on two
Wolfram Community contributions, adapted here for a scientific rather than
general-purpose accessibility context — see `LISTENING_GUIDE.md` for the
full rationale.

**Rangan (2018)** — *Image Sonification Using Hilbert Curves.*
Wolfram Community. Uses Wolfram's built-in `HilbertCurve[]` to traverse image
pixels in locality-preserving order, converting HSB colour values to audio
(hue → frequency, saturation → amplitude, brightness → stereo channel).
Source of the original `hsb` mode design; stem's `hsb` mode adapts this by
encoding brightness as timbre rather than a second frequency.

**Rao (WSRP25)** — *Sonification Strategies for 2D Images.*
Wolfram Summer Research Program. Two row-by-row methods: brightness mapping
and nearest-colour mapping with held notes for colour runs, using a
chord-tone palette and RGB-distance `compareColor[]`. Source of the
`brightness` and `colour` mode designs; stem's `colour` mode instead orders
the palette by visible-spectrum position and matches colours using Lab
colour distance.

The `HilbertTraversalOrder[n]` function is provided by `stem-core/src/hilbert.wl`
and implements the standard d2xy bijection, equivalent to the traversal
encoded in Wolfram's `HilbertCurve[n, 2]`.

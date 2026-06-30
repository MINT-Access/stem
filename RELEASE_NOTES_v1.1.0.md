# v1.1.0 — Four New Simulations, Cross-Platform Support, and Project Consolidation

v1.0.0 established the project with eight physics and mathematics simulations running on macOS. v1.1.0 adds four new scientific domains — 2D wave propagation, Lagrange point dynamics, image sonification, and CMB cosmology — makes the project runnable on Windows and Linux for the first time, and brings all four new apps into the same structural and architectural conventions as the original eight. The total is now twelve simulations, each producing audio, animation, and data files from a single terminal command.

---

## New apps — recommended listening order

The four new apps are introduced below in the order they appear in the full twelve-app demo listening guide (`demo/README.md`). Each is self-contained: you do not need to listen to all twelve to appreciate any one of them. The recommended entry point for the project as a whole — for new listeners especially — remains `signal/output/chord_narrative_full.wav`, which is unchanged from v1.0.0 and explains what sonification is before any physics is introduced.

---

### waves — 2D wave propagation

The wave equation is one of the most fundamental equations in physics. It governs every ripple on a pond, every sound moving through air, every seismic tremor propagating through the earth. In two dimensions the equation says that the displacement of any point in a medium changes at a rate determined by how different it is from its neighbours: a point higher than its surroundings is pulled back down; a point lower is pushed up. This local coupling propagates disturbances outward at a fixed speed, creating the expanding wavefronts that are immediately recognisable when you drop a stone into still water.

This app solves the wave equation numerically on two different geometries using Wolfram's finite element method. In `ripple` mode, a Gaussian impulse at the centre of a circular membrane produces an expanding ring that crosses six listening points at increasing distances from the source. In `interference` mode, two coherent point sources inside a rectangular tank create a standing fringe pattern — the spatial analogue of beating in music theory, where two nearly-identical pitches produce rhythmic amplitude swells in time. Listening to `waves` and `signal` in sequence makes the symmetry between the time domain and the space domain concrete: in `signal`, frequencies add and cancel over time; in `waves`, the same superposition principle plays out across space.

In `ripple` mode, the six listening points are assigned positions across the stereo field from left (nearest the source) to right (furthest). The wavefront reaches the innermost point first, producing a burst of sound hard left; a fraction of a second later the second point responds, slightly to the right; and so on, until the expanding ring has swept the entire stereo field. The time gaps between the bursts are directly proportional to the wave speed — a listener can estimate propagation speed from the silences between arrivals. After the initial sweep, the wave reflects off the fixed boundary and returns inward, and the arrival sequence repeats in reverse: the outermost point fires first this time, then the inner ones in succession, and the stereo sweep runs right to left.

```sh
afplay waves/output/ripple_audio.wav
# Six wavefront arrivals sweep left to right in stereo.
# Listen for the reflection: after the last point sounds, the wave
# bounces back and the sweep repeats in reverse.
```

---

### lagrange — Lagrange point dynamics

In the rotating reference frame of two massive bodies orbiting their common centre of mass — the Sun and Jupiter, for example — there are five special positions where a third, massless body can remain in equilibrium. Three of them lie on the axis connecting the two primaries and are unstable: any small perturbation sends an object placed there spiralling away. Two of them form equilateral triangles with both primaries and are genuinely stable, provided the secondary body is light enough relative to the primary. Jupiter satisfies this condition easily. More than ten thousand asteroids actually occupy Jupiter's L4 and L5 points in the real solar system, where they have been librating for billions of years. They are the Trojan asteroids, and they are the proof that this stability is real.

The app places a test particle near one of the five Lagrange points and integrates its equations of motion numerically. Three quantities are mapped to audio simultaneously. Pitch tracks the test particle's angular velocity around the barycentre: as the particle librates in its slow tadpole orbit around L4 or L5, its angular velocity oscillates quasi-periodically, producing a slowly undulating tone. Stereo pan follows the particle's x-coordinate in the co-rotating frame, so the sound drifts left and right as the particle swings toward the Sun and then toward Jupiter. Volume tracks the inverse of the distance to the nearest primary, so the particle sounds louder when it swings closest to either body. Short accent tones mark the peaks of the angular velocity, giving the libration rhythm an audible metered pulse over the continuous tone.

In `l4` mode, the tone is calm and periodic, slowly drifting in stereo and undulating in pitch without ever resolving or escaping. That boundedness — the fact that the sound continues indefinitely without change in character — is what orbital stability sounds like. In `l1` mode, the particle is placed near the unstable L1 saddle point and the dynamics are completely different: the sound begins similarly steady, then slowly destabilises as the particle's trajectory diverges exponentially, and finally the pitch sweeps abruptly as the particle escapes onto a transfer orbit. The contrast between the two modes is immediate and visceral, and it makes the abstract concept of stability and instability directly perceptible without a diagram.

```sh
afplay lagrange/output/l4_audio.wav
# A test particle librating around Jupiter's L4 Trojan point.
# The tone drifts left and right and slowly undulates in pitch
# but never escapes — this is what orbital stability sounds like.
```

---

### images — Image sonification via Hilbert curve

A 2D scientific image contains spatial structure — gradients, boundaries, clusters, peaks — that has historically been one of the harder forms of data to make accessible by ear. A row-by-row scan produces a sound where spatially adjacent pixels in two-dimensional space jump around unpredictably in time, because adjacent rows are far apart in the scan sequence. This app uses the Hilbert curve, a space-filling path through the image grid, to overcome that problem. The Hilbert curve has the mathematical property that pixels adjacent in the traversal sequence are also nearby in two-dimensional space — the curve never teleports. This locality property means that spatial structure in the image becomes temporal structure in the audio: a gradient becomes a smooth pitch sweep; a sharp boundary becomes an abrupt pitch jump; a region of uniform colour becomes a held note.

In `brightness` mode, each pixel's grayscale value maps linearly to frequency between 200 Hz (dark) and 2000 Hz (bright), with each pixel producing a short note of fifty milliseconds. In `colour` mode, each pixel is classified into one of ten named colours and assigned a fixed musical pitch from a C major scale — red is E3, blue is G4, white is C5 — with consecutive pixels of the same colour merged into a single held note rather than a rapid sequence of attacks. A sighted user watching the GIF sees the Hilbert curve tracing through the image, highlighting each pixel in order; a listener hears the same traversal as a continuous pitch sweep whose smoothness directly reflects the spatial coherence of the image.

The default test image is a 2D Gaussian distribution centred on the grid: black at the edges, white at the centre. In `brightness` mode, the traversal begins in a corner of the image among the dark outer pixels, producing a low tone. As the curve spirals inward the pitch climbs, with brief dips whenever the path crosses a slightly darker region, until it reaches the brightest central pixels and the pitch is at its highest. The sweep is not perfectly monotone — the Hilbert curve backtracks through darker regions as it works inward — but it has a clear upward trend, and the overall movement from low to high accurately reflects the image's radially symmetric structure. Three built-in test images are available: `gaussian` (the default), `temperature` (a radial false-colour heat map), and `quantum` (the |ψ|² probability density for a particle in a box, with four lobes).

```sh
afplay images/output/images_brightness_audio.wav
# A 64x64 Gaussian image traversed in Hilbert order.
# Low pitch at the dark edges, rising steadily toward the bright centre.
# The sweep is smooth — that smoothness is the Hilbert locality property.
```

---

### cosmology — CMB power spectrum

Roughly 380,000 years after the Big Bang, the universe cooled enough for hydrogen atoms to form and the primordial plasma to become transparent. The light released at that moment — the Cosmic Microwave Background — has been travelling toward us ever since, reaching us from all directions at a nearly uniform temperature of 2.725 Kelvin. The tiny temperature variations in that glow, roughly one part in one hundred thousand, carry a detailed record of what the early universe looked like: which scales had dense plasma, which had rarefied plasma, and how far sound waves had propagated before the plasma froze. That record is encoded in the angular power spectrum — a plot of how much temperature variation exists at each angular scale on the sky — and its shape encodes the universe's composition as precisely as a fingerprint encodes a person's identity.

The power spectrum has a characteristic shape with three immediately recognisable features. At large angular scales it is flat: a broad plateau reflecting the large-scale gravitational imprint called the Sachs-Wolfe effect. Around an angular scale of 0.82 degrees it swells dramatically to a first acoustic peak — the scale of a sound wave that completed exactly half an oscillation before recombination, and was frozen into the CMB at maximum compression. This first peak is the loudest signal in the spectrum, and its position tells us the universe is spatially flat. Two smaller peaks follow at finer scales: the second is noticeably lower than the first, suppressed by the extra inertia that ordinary baryons add to the acoustic oscillations; the third is comparable to the second. Beyond the third peak the power falls steadily as photon diffusion washes out structure at small scales — the Silk damping tail. The relative heights of the peaks measure the baryon density, the dark matter density, and the photon mean free path at recombination. Planck's measurements of these peaks, announced in 2013 and refined through 2018, are the most precise cosmological measurements ever made.

The sonification assigns one note to each multipole l from 2 to 2000. Both pitch and volume follow the power D_l at each scale. A listener hears the large-scale plateau as a quiet, moderately-pitched drone lasting several seconds; then a clear swell as the power rises toward the first acoustic peak around l = 220, marked by an accent tone at its crest — the loudest and highest-pitched moment in the file; then a dip and two smaller swells as the second and third peaks pass; and finally a long, gradually quietening descent as diffusion erases small-scale structure. The first peak is louder than everything that follows, which is what the geometry of a flat universe sounds like. The second peak's suppression relative to the first is audible as a distinct asymmetry — and that asymmetry is the sound of ordinary matter constituting about 5% of the universe's total energy content.

```sh
afplay cosmology/output/cmb_spectrum_audio.wav
# The CMB power spectrum from l=2 to l=2000.
# Listen for the swell to the first acoustic peak (the loudest moment),
# then the two smaller harmonics, then the long fade into the Silk damping tail.
```

---

## Infrastructure

### Cross-platform support

v1.0.0 was macOS-only: audio playback used `afplay` and spoken output used the `say` command, both built-in macOS tools. v1.1.0 wraps both behind stem-core abstractions that detect the platform at runtime. The `STEMPlay` function issues `afplay` on macOS, `aplay` on Linux, and a PowerShell `SoundPlayer` call on Windows. The `STEMSay` function uses `say` on macOS, `espeak-ng` (or `espeak`) on Linux, and the PowerShell `System.Speech.Synthesis.SpeechSynthesizer` on Windows. All file paths throughout the codebase now use Wolfram's `FileNameJoin` rather than string concatenation, ensuring that path separators are correct on Windows.

The signal app's narrative WAV — the spoken guide to Fourier analysis — uses the same three-platform dispatch internally, so the narrative output is generated correctly on Linux and Windows without modification. Setting `STEM_SPEAK=1` for spoken stage announcements also works on all three platforms.

macOS remains the primary tested and supported platform. Windows and Linux users are encouraged to open a GitHub issue if they encounter problems; the path and audio routing code is structured to be straightforward to debug and extend.

Installation instructions, prerequisite package names for all three platforms, and platform-specific `afplay` / `aplay` / `wmplayer` equivalents are in the root `README.md`.

### Project structure

The four new apps now match the eight-app convention. Each is split into a `src/` directory containing separate files for model, sonification, animation, and output logic; a `tests/` directory with a self-contained test runner that exits 0 on success and 1 on failure; an `experiments.wl` for curated preset runs; and an `AGENTS.md` for AI-assisted development guidance. The shared stem-core library now serves all twelve apps from a single `init.wl` entry point.

### Bug fixes

Two bugs present in v1.0.0 are fixed in this release.

On Apple Silicon Macs (M2, M3, M4), the asteroids app printed a `WriteString[$stderr]` error at startup. The issue was a reference to `$stderr` that succeeded on Intel hardware but failed on Apple Silicon; the fix guards the call with a `StreamQ` check before writing.

The demo script previously wrote some app outputs directly into `demo/<app>/` rather than `demo/<app>/output/`, which caused `afplay demo/<app>/output/<file>` commands in `demo/README.md` to fail for those apps. All demo outputs now land in `demo/<app>/output/` consistently, and the `--check-only` verification mode checks that directory.

---

## Getting started

**Prerequisites:** [Wolfram Engine](https://www.wolfram.com/engine/) (free) or Mathematica 13+, with `wolframscript` on your PATH. Verify with `wolframscript -version`. An internet connection is required only for the asteroids app (live NASA data) and for the cosmology app when using `--simulation.cosmology.source=planck`.

The three most important commands to run first:

**1. The narrative — understand sonification in four minutes**

```sh
wolframscript -file signal/main.wl -- --simulation.mode=chord
afplay signal/output/chord_narrative_full.wav
```

This is unchanged from v1.0.0 and remains the best entry point for any new listener. It runs the Fourier analysis demonstration and produces a self-contained audio guide: spoken introduction, clean C major chord, chord buried in noise, chord recovered by the DFT. Listen to it before anything else.

**2. The demo — all twelve apps in one run**

```sh
wolframscript -file demo.wl
```

Runs all twelve apps in sequence (approximately five to six minutes on a modern Mac), collects every output into `demo/`, and writes `demo/demo-report.md` with per-app runtimes and PASS/FAIL status. After it finishes, follow the listening guide in `demo/README.md` for the recommended order and the `afplay` command for each output.

**3. The crown jewel — the oldest sound in the universe**

```sh
wolframscript -file cosmology/main.wl
afplay cosmology/output/cmb_spectrum_audio.wav
```

Computes the CMB angular power spectrum and exports it as audio. Listen for the quiet plateau at the start, then the swell to the first acoustic peak — the loudest moment, marked by an accent tone — then two smaller harmonics, and then the long fade into the Silk damping tail. The peak positions and relative heights encode the geometry of the universe, the baryon density, and the dark matter density. Planck measured them to percent-level precision; this app makes them perceptible by ear.

---

## Acknowledgements

This project was developed with [Claude Code](https://claude.ai/claude-code) (Anthropic). The asteroids app uses NASA's [Near Earth Object Web Service (NeoWs)](https://api.nasa.gov/) and the [JPL Small Body Database API](https://ssd-api.jpl.nasa.gov/doc/sbdb.html) for live orbital data. The cosmology app's `--simulation.cosmology.source=planck` mode fetches the Planck 2018 best-fit TT power spectrum from the [Planck Legacy Archive](https://pla.esac.esa.int/). The images app's `hsb` mode is based on Srinath Rangan's 2018 Wolfram Community post *Image Sonification Using Hilbert Curves*; the `brightness` and `colour` modes draw on Neha Rao's 2025 Wolfram Summer Research Program work on sonification strategies for 2D images. MINT Access is a Swiss organisation and the go-to partner for universities, publishers, and companies serving the university sector that want to make their STEM teaching and research more accessible — website at [mintaccess.ch](https://www.mintaccess.ch/) (German).

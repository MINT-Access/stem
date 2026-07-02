# stem — Release Notes

**stem** is twelve physics, mathematics, and cosmology simulations that run entirely from the terminal, each producing a CSV data file, an animated GIF, and — most importantly — a WAV audio file you can listen to on macOS, Linux, or Windows. The project is developed by [MINT Access](https://www.mintaccess.ch/), a Swiss organisation that partners with universities, publishers, and companies serving the university sector to make teaching and research in STEM fields more accessible. What makes it different from other scientific simulation projects is that accessibility is not an afterthought: the audio output is the primary result, not a bonus. Every app is designed so that a blind user listening through headphones experiences the same scientific content as a sighted user watching the animation — and in several cases, the audio reveals structure that the visual cannot. The project launched as v1.0.0 with eight simulations running on macOS only. v1.1.0 adds four new scientific domains — 2D wave propagation, Lagrange point dynamics, image sonification, and CMB cosmology — makes the project runnable on Windows and Linux for the first time, and brings all four new apps into the same structural and architectural conventions as the original eight.

---

## What's included in v1.1.0

### Apps — recommended listening order

The order below follows the listening guide in `demo/README.md`. It is designed to build understanding progressively: start with signal processing (which explains what sonification is, in spoken audio) and its spatial companion, 2D wave propagation, then move through pendulum chaos, cellular computation, number theory, quantum mechanics, more deterministic chaos, live asteroid data, Lagrange point stability, image sonification, gravitational waves, and finish with the cosmic microwave background.

---

### 1. signal — Fourier analysis

The discrete Fourier transform is the mathematical tool that decomposes any signal — sound, light, a radio transmission, a seismogram — into a sum of pure frequencies. This app generates a signal, corrupts it with random noise, then uses the DFT to identify and recover the original frequencies. Unlike every other app in this project, the WAV output *is* the phenomenon: you hear the signal directly, not a sonification of something else.

Three modes are available. The `chord` mode generates a C major chord (C4 + E4 + G4), buries it in noise, and recovers it via a comb filter — signal-to-noise ratio improves from roughly 8 dB to 30 dB. The `sweep` mode demonstrates a linear frequency chirp. The `am` mode demonstrates amplitude modulation, where a 440 Hz carrier is modulated at 4 Hz and recovered from noise.

The single most accessible output in the entire project is `chord_narrative_full.wav`: a spoken guide that chains introduction, clean signal, noisy signal, and recovered signal into one continuous audio file. A listener who has never heard of the Fourier transform can follow the complete demonstration from start to finish without reading a word. Sighted users additionally see a PNG spectrum plot that shows exactly which frequency bins carry power; blind users hear the same story in sequence, which arguably makes the filtering effect clearer — it is easier to perceive a dramatic change in sound quality than to compare two overlapping spectral curves.

```sh
afplay signal/output/chord_narrative_full.wav
# Spoken introduction, then: clean chord → noisy chord → recovered chord.
# Listen for how clearly the three notes re-emerge from the noise.
```

---

### 2. waves — 2D wave propagation

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

### 3. pendulum — Nonlinear pendulum ODE

A pendulum is the canonical introduction to differential equations: a rod pivoting at one end, pulled by gravity, described by a simple nonlinear equation. The *double* pendulum — two rods connected end-to-end — is one of the simplest systems in nature that is chaotic: two starting positions that differ by a fraction of a degree will eventually produce completely unrelated trajectories.

The app solves the equations of motion numerically using Wolfram's `NDSolve`. In `double` mode, each bob is sonified independently and assigned to one stereo channel: the upper bob to the left, the lower to the right. Pitch is mapped from swing angle using the A minor pentatonic scale; each half-swing (from one zero-crossing to the next) produces one note; volume follows angular velocity. The rhythm and pitch of each channel begins coherent and gradually diverges as the system expresses its chaos — the stereo field opens and closes unpredictably as the two bobs fall in and out of phase.

A sighted user watching the GIF sees the geometric divergence of the trajectory as a visual pattern. A listener hears exactly the same divergence as a rhythmic and harmonic relationship that gradually loses its regularity — the same information, a different sensory encoding.

```sh
afplay pendulum/output/double_audio.wav
# Two pendulum bobs in binaural stereo. Listen for when the left
# and right channels fall out of sync — that is chaos becoming audible.
```

---

### 4. cellular — Conway's Game of Life and Rule 110

A cellular automaton is a grid of cells where each cell's next state depends only on its current neighbours, according to a fixed rule. Conway's Game of Life uses a 2D grid with a single rule (B3/S23: a dead cell with exactly 3 live neighbours is born; a live cell with 2 or 3 survives). From this rule, arbitrarily complex structures emerge — gliders, oscillators, spaceships — and the system is computationally universal.

The R-pentomino is a five-cell seed that evolves chaotically for 1103 generations before finally stabilising. The app runs 300 of those generations. Population (live cell count) is mapped to pitch, the left-right density asymmetry controls stereo pan, and the rate of population change drives volume. Sudden population explosions and collapses trigger short-burst tones at 900 Hz and 150 Hz respectively.

A sighted user watches the GIF and sees spatial patterns — gliders crossing the grid, dense clusters forming and dissolving. The audio strips away the spatial information and makes the population dynamics directly perceptible: the listener hears the colony growing, stabilising briefly, then erupting again. Both experiences are genuine, and neither is reducible to the other.

```sh
afplay cellular/output/life_rpentomino_audio.wav
# Five cells expanding into a 300-generation chaotic colony.
# Listen for the sudden volume spikes — those are population explosions.
```

---

### 5. primes — Prime gap rhythm

The prime numbers (2, 3, 5, 7, 11, …) are the atoms of arithmetic: every integer factors uniquely into primes. Their distribution becomes more spread out as numbers grow larger — roughly, the average gap between consecutive primes near the number N is approximately the natural logarithm of N. But within that statistical trend, the gaps are irregular: sometimes two primes are adjacent (twin primes, gap = 2), sometimes there is a gap of 30 or more.

The `gaps` mode maps this gap sequence to audio. Each prime triggers a short sine burst at a time proportional to its distance from the first prime, and at a pitch that rises slowly with the prime value. The `gaps_slow.wav` output plays the same sequence at quarter tempo, stretching 30 seconds to 120 seconds. At this pace, twin prime pairs (gap = 2) are clearly audible as near-simultaneous double-attacks — a rapid one-two tap — while large gaps become clearly perceptible silences. Sighted users can look at the animated gap chart; listeners hear the rhythm directly, and the slow version makes individual gap lengths countable by ear in a way that no static visualisation can match.

```sh
afplay primes/output/gaps_slow.wav
# 5000 prime gaps at quarter tempo. Listen for the double-attacks
# (twin primes) and count the silences between them.
```

---

### 6. quantum — Quantum harmonic oscillator

In quantum mechanics, a particle does not have a definite position: it is described by a wave function whose squared magnitude gives the probability of finding the particle at each location. A *coherent state* is a special quantum state that behaves as classically as quantum mechanics allows: the probability cloud oscillates back and forth in the potential well without spreading, following the trajectory a classical particle would.

The app solves the time-dependent Schrödinger equation exactly by expanding the initial state in energy eigenstates — the precise quantum modes of the system — and evolving each one analytically. Stereo pan tracks the mean position ⟨x⟩(t), pitch tracks the position variance (how spread-out the wave packet is), and volume tracks the speed of the mean position. For a coherent state with amplitude α = 3.0 (a large-amplitude oscillation), the result is a smooth, sinusoidal tone that pans left and right in lockstep with the wave packet's motion.

Sighted users watch the animated probability density rise and fall across the GIF. Listeners hear the same oscillation directly as pitch and pan — and arguably perceive the *smoothness* and *periodicity* of the coherent state more immediately in audio than in a visual animation, because smoothness is a property of sound that human hearing is acutely sensitive to.

```sh
afplay quantum/output/qho_audio.wav
# A quantum wave packet oscillating in a harmonic potential.
# The tone is almost perfectly smooth and periodic — that smoothness
# is what makes this state "as classical as quantum mechanics allows".
```

---

### 7. lorenz — Strange attractors

A *strange attractor* is a region of a dynamical system that trajectories are drawn toward but never escape — and never repeat. The Lorenz system (three coupled differential equations, published in 1963) was the first rigorous demonstration that a deterministic system — one with no randomness whatsoever — can produce behaviour so sensitive to initial conditions that it is practically unpredictable. This is the origin of the phrase "butterfly effect."

The Rössler attractor (the preset used in the demo) is a cousin of Lorenz with a simpler geometric structure: one wing instead of two, producing a more melodic and less jagged sonification. Each local extremum of the x-coordinate triggers one note; the x-value maps to pitch via the minor pentatonic scale; volume follows the magnitude of the excursion. The result is an improvisation that has discernible phrase structure — similar figures recur — but never quite repeats.

Sighted users watch the trajectory build up in x-z projection, coloured blue (early) through orange to red (recent). Listeners hear the same trajectory as a melodic sequence, and because the attractor has a characteristic shape, certain melodic motifs keep recurring — the audio makes the statistical regularity of chaos more immediately recognisable than the visual does.

```sh
afplay lorenz/output/rossler_audio.wav
# The Rössler attractor as melody. Listen for melodic phrases that
# almost repeat but drift — that drift is deterministic chaos.
```

---

### 8. asteroids — Live NASA data

Every day, dozens of asteroids pass near Earth. NASA's Near Earth Object Web Service (NeoWs) provides real-time close-approach data: miss distance, relative velocity, estimated diameter, and hazard classification. This app fetches the last seven days of data, fetches each asteroid's orbital elements from the JPL Small Body Database to compute its direction in the sky, and turns the dataset into a WAV file where each asteroid is one note.

Pitch is mapped from miss distance (farther away → higher pitch, using the minor pentatonic scale with root C3). Duration is inversely proportional to relative velocity (faster asteroids produce shorter notes). Volume is proportional to estimated diameter. Timbre distinguishes hazardous from non-hazardous: safe asteroids use a warm three-harmonic bell tone; hazardous asteroids use a brighter, harsher five-harmonic voice. The ordering runs farthest to closest — a steady build toward Earth — so the texture thickens and harshens as the asteroids approach.

This is the only app whose output changes every time it is run, because the data is live. A sighted user sees the GIF: a top-down solar system with asteroids revealed one by one, coloured cyan (safe) or red (hazardous). A listener hears the same information: the texture brightens and sharpens as hazardous objects appear, and the ear picks up the timbre contrast between safe and hazardous immediately, without needing to read a colour legend.

```sh
NASA_API_KEY=$NASA_API_KEY afplay asteroids/output/asteroids_$(date +%Y-%m-%d -v-6d)_$(date +%Y-%m-%d).wav
# Or simply: afplay asteroids/output/asteroids_*.wav
# Each note is one asteroid. The harsh-timbred notes are the hazardous ones.
```

---

### 9. lagrange — Lagrange point dynamics

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

### 10. images — Image sonification via Hilbert curve

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

### 11. relativity — Gravitational waves and black hole orbits

On 14 September 2015, the LIGO gravitational wave detectors registered a signal 1.3 billion years in the making: two black holes, 36 and 29 times the mass of the Sun, had been spiralling together and finally merged. As two massive bodies orbit each other, they radiate energy as gravitational waves — ripples in spacetime itself. As energy is lost the orbit shrinks, the frequency rises, the amplitude grows, until the bodies merge in an instant. The resulting signal is a *chirp*: a rising frequency sweep ending abruptly, followed by an exponentially decaying ringdown as the merged remnant oscillates and settles.

The gravitational wave strain h(t) is literally a waveform — it has amplitude and frequency, varying in time — so it can be played directly as audio after time-stretching (the default 4× stretch makes the sub-second LIGO chirp clearly audible). The simulation uses the post-Newtonian analytic approximation, the same mathematical model used to construct LIGO's matched filter templates. Four physical correctness checks verify the formulas on every run. Three preset WAV files are produced automatically: GW150914 (the first detection), GW170817 (a neutron star merger), and a stellar-mass binary for comparison.

A sighted user sees the waveform and frequency evolution plots. A listener hears exactly what LIGO's data-analysis software looked for: the characteristic pitch rise, the amplitude swell, the abrupt cutoff at merger, and the fading ringdown. Because the chirp is defined by its time-frequency structure, audio is arguably the most natural medium for experiencing it — LIGO researchers have listened to their detections since the first one.

```sh
afplay relativity/output/chirp.wav
# GW150914 at 4x time stretch. Rising pitch and volume, then silence
# at merger, then a brief fading ringdown. This is what LIGO heard.
```

---

### 12. cosmology — CMB power spectrum

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

## Infrastructure and platform support

### Cross-platform support

v1.0.0 was macOS-only: audio playback used `afplay` and spoken output used the `say` command, both built-in macOS tools. v1.1.0 wraps both behind stem-core abstractions that detect the platform at runtime. The `STEMPlay` function issues `afplay` on macOS, `aplay` on Linux, and a PowerShell `SoundPlayer` call on Windows. The `STEMSay` function uses `say` on macOS, `espeak-ng` (or `espeak`) on Linux, and the PowerShell `System.Speech.Synthesis.SpeechSynthesizer` on Windows. All file paths throughout the codebase now use Wolfram's `FileNameJoin` rather than string concatenation, ensuring that path separators are correct on Windows.

The signal app's narrative WAV — the spoken guide to Fourier analysis — uses the same three-platform dispatch internally, so the narrative output is generated correctly on Linux and Windows without modification. Setting `STEM_SPEAK=1` for spoken stage announcements also works on all three platforms.

macOS remains the primary tested and supported platform. Windows and Linux users are encouraged to open a GitHub issue if they encounter problems; the path and audio routing code is structured to be straightforward to debug and extend.

Installation instructions, prerequisite package names for all three platforms, and platform-specific `afplay` / `aplay` / `wmplayer` equivalents are in the root `README.md`.

### Bug fixes

Two bugs present in v1.0.0 are fixed in this release.

On Apple Silicon Macs (M2, M3, M4), the asteroids app printed a `WriteString[$stderr]` error at startup. The issue was a reference to `$stderr` that succeeded on Intel hardware but failed on Apple Silicon; the fix guards the call with a `StreamQ` check before writing.

The demo script previously wrote some app outputs directly into `demo/<app>/` rather than `demo/<app>/output/`, which caused `afplay demo/<app>/output/<file>` commands in `demo/README.md` to fail for those apps. All demo outputs now land in `demo/<app>/output/` consistently, and the `--check-only` verification mode checks that directory.

### Project structure and consolidation

The four new apps now match the eight-app convention established in v1.0.0. Each is split into a `src/` directory containing separate files for model, sonification, animation, and output logic; a `tests/` directory with a self-contained test runner that exits 0 on success and 1 on failure; an `experiments.wl` for curated preset runs; and an `AGENTS.md` for AI-assisted development guidance. The shared stem-core library now serves all twelve apps from a single `init.wl` entry point.

Every app uses a four-layer configuration hierarchy:

```
hardcoded defaults  →  config/config.json  →  <app>/config.json  →  CLI --key=value
```

Each layer overrides the previous. Parameters are addressed by dot-separated key paths, and both `--key=value` and `--key value` forms are accepted. Negative values work correctly (`--simulation.qho.alpha=-2.0`). To inspect the fully merged config for any app without running the simulation:

```sh
wolframscript -file pendulum/main.wl -- --config-dump | python3 -m json.tool
```

This makes it straightforward to verify exactly which parameters are active before a run, and to reproduce results precisely by recording the config dump alongside the output files.

`stem-core/src/sonification.wl` provides a three-layer pipeline that converts a numeric trajectory into a stereo WAV file: **SpatialLayer** maps the x-coordinate of the trajectory to stereo pan; **MotionLayer** maps trajectory speed to pitch via a musical scale lookup; **EventLayer** inserts accent tones at labelled events (local extrema, zero crossings, population explosions, asteroid approaches, orbital peaks). The three layers are mixed and peak-normalised before export. This design underpins the original eight apps — the trajectory format (`n × 5` matrix: `{t, x, y, z, speed}`) is the same regardless of what the coordinates represent — and the new apps build on the same shared synthesis and export primitives, adapting the layer mappings to each domain (angular velocity and libration for lagrange, Hilbert-order pixel traversal for images, multipole power for cosmology).

All apps run fully headlessly via `wolframscript -file` with no display server. Every console output line is a self-contained announcement formatted for screen readers: numbers are never split across Print arguments, labels and units are always on the same line, and major sections are delimited by `=== heading ===` markers. WAV is the right output format for an accessible scientific demonstration because it requires no display, no GUI toolkit, no browser, and no internet connection to experience — `afplay`/`aplay`/`wmplayer` all work from a terminal controlled entirely by a screen reader and keyboard navigation.

### Demo runner

`demo.wl` runs all twelve apps in sequence with their most compelling presets, collects every output into `demo/<appname>/output/`, and writes a machine-readable run report to `demo/demo-report.md`. Total runtime is approximately five to six minutes on a modern Mac, up from three to four minutes for the original eight apps.

```sh
wolframscript -file demo.wl                        # full run
STEM_SPEAK=1 wolframscript -file demo.wl           # with spoken stage announcements
NASA_API_KEY=$NASA_API_KEY wolframscript -file demo.wl   # include live asteroid data
wolframscript -file demo.wl -- --check-only        # verify a previous run without re-running
```

The demo report records the Wolfram Language version, OS version, per-app duration, file count, file sizes, and PASS/FAIL status for each app. It also generates a `demo/README.md` with the recommended listening order and playback commands for every output WAV.

---

## Getting started

**Prerequisites:** [Wolfram Engine](https://www.wolfram.com/engine/) (free) or Mathematica 13+, with `wolframscript` on your PATH. Verify with `wolframscript -version`. An internet connection is required only for the asteroids app (live NASA data) and for the cosmology app when using `--simulation.cosmology.source=planck`.

The three most important commands to run first:

**1. The narrative — understand sonification in four minutes**

```sh
wolframscript -file signal/main.wl -- --simulation.mode=chord
afplay signal/output/chord_narrative_full.wav
```

This runs the Fourier analysis demonstration and produces a self-contained audio guide: spoken introduction, clean C major chord, chord buried in noise, chord recovered by the DFT. Listen to it before anything else — it explains what sonification is and why frequency-domain filtering works, while you hear it happening.

**2. The demo — all twelve apps in one run**

```sh
wolframscript -file demo.wl
```

Runs all twelve apps in sequence (approximately five to six minutes on a modern Mac), collects every output into `demo/`, and writes `demo/demo-report.md` with per-app runtimes and PASS/FAIL status. After it finishes, follow the listening guide in `demo/README.md` for the recommended order and the playback command for each output.

**3. The crown jewel — the oldest sound in the universe**

```sh
wolframscript -file cosmology/main.wl
afplay cosmology/output/cmb_spectrum_audio.wav
```

Computes the CMB angular power spectrum and exports it as audio. Listen for the quiet plateau at the start, then the swell to the first acoustic peak — the loudest moment, marked by an accent tone — then two smaller harmonics, and then the long fade into the Silk damping tail. The peak positions and relative heights encode the geometry of the universe, the baryon density, and the dark matter density. Planck measured them to percent-level precision; this app makes them perceptible by ear.

---

## Acknowledgements

This project was developed with [Claude Code](https://claude.ai/claude-code) (Anthropic). The asteroids app uses NASA's [Near Earth Object Web Service (NeoWs)](https://api.nasa.gov/) and the [JPL Small Body Database API](https://ssd-api.jpl.nasa.gov/doc/sbdb.html) for live orbital data. The cosmology app's `--simulation.cosmology.source=planck` mode fetches the Planck 2018 best-fit TT power spectrum from the [Planck Legacy Archive](https://pla.esac.esa.int/). The images app's `hsb` mode is based on Srinath Rangan's 2018 Wolfram Community post *Image Sonification Using Hilbert Curves*; the `brightness` and `colour` modes draw on Neha Rao's 2025 Wolfram Summer Research Program work on sonification strategies for 2D images. MINT Access is a Swiss organisation and the go-to partner for universities, publishers, and companies serving the university sector that want to make their STEM teaching and research more accessible — website at [mintaccess.ch](https://www.mintaccess.ch/) (German).

# v1.0.0 — Accessible STEM Simulations in Wolfram Language

> **Note:** v1.0.0 was macOS-only. Cross-platform support (Linux, Windows) was
> added after this release. On Linux use `aplay` instead of `afplay`; on Windows
> PowerShell use `Start-Process wmplayer`. See the root `README.md` for details.

This is the first release of **stem**: eight physics and mathematics simulations that run entirely from the terminal, each producing a CSV data file, an animated GIF, and — most importantly — a WAV audio file you can play with `afplay` (macOS). The project is developed by [MINT Access](https://www.mintaccess.ch/), a Swiss organisation that partners with universities, publishers, and companies serving the university sector to make teaching and research in STEM fields more accessible. What makes it different from other scientific simulation projects is that accessibility is not an afterthought: the audio output is the primary result, not a bonus. Every app is designed so that a blind user listening through headphones experiences the same scientific content as a sighted user watching the animation — and in several cases, the audio reveals structure that the visual cannot.

---

## Apps — recommended listening order

The order below follows the listening guide in `demo/README.md`. It is designed to build understanding progressively: start with signal processing (which explains what sonification is, in spoken audio), then move through deterministic chaos, cellular computation, number theory, quantum mechanics, more chaos, live data, and finish with gravitational waves.

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

### 2. pendulum — Nonlinear pendulum ODE

A pendulum is the canonical introduction to differential equations: a rod pivoting at one end, pulled by gravity, described by a simple nonlinear equation. The *double* pendulum — two rods connected end-to-end — is one of the simplest systems in nature that is chaotic: two starting positions that differ by a fraction of a degree will eventually produce completely unrelated trajectories.

The app solves the equations of motion numerically using Wolfram's `NDSolve`. In `double` mode, each bob is sonified independently and assigned to one stereo channel: the upper bob to the left, the lower to the right. Pitch is mapped from swing angle using the A minor pentatonic scale; each half-swing (from one zero-crossing to the next) produces one note; volume follows angular velocity. The rhythm and pitch of each channel begins coherent and gradually diverges as the system expresses its chaos — the stereo field opens and closes unpredictably as the two bobs fall in and out of phase.

A sighted user watching the GIF sees the geometric divergence of the trajectory as a visual pattern. A listener hears exactly the same divergence as a rhythmic and harmonic relationship that gradually loses its regularity — the same information, a different sensory encoding.

```sh
afplay pendulum/output/double_audio.wav
# Two pendulum bobs in binaural stereo. Listen for when the left
# and right channels fall out of sync — that is chaos becoming audible.
```

---

### 3. cellular — Conway's Game of Life and Rule 110

A cellular automaton is a grid of cells where each cell's next state depends only on its current neighbours, according to a fixed rule. Conway's Game of Life uses a 2D grid with a single rule (B3/S23: a dead cell with exactly 3 live neighbours is born; a live cell with 2 or 3 survives). From this rule, arbitrarily complex structures emerge — gliders, oscillators, spaceships — and the system is computationally universal.

The R-pentomino is a five-cell seed that evolves chaotically for 1103 generations before finally stabilising. The app runs 300 of those generations. Population (live cell count) is mapped to pitch, the left-right density asymmetry controls stereo pan, and the rate of population change drives volume. Sudden population explosions and collapses trigger short-burst tones at 900 Hz and 150 Hz respectively.

A sighted user watches the GIF and sees spatial patterns — gliders crossing the grid, dense clusters forming and dissolving. The audio strips away the spatial information and makes the population dynamics directly perceptible: the listener hears the colony growing, stabilising briefly, then erupting again. Both experiences are genuine, and neither is reducible to the other.

```sh
afplay cellular/output/life_rpentomino_audio.wav
# Five cells expanding into a 300-generation chaotic colony.
# Listen for the sudden volume spikes — those are population explosions.
```

---

### 4. primes — Prime gap rhythm

The prime numbers (2, 3, 5, 7, 11, …) are the atoms of arithmetic: every integer factors uniquely into primes. Their distribution becomes more spread out as numbers grow larger — roughly, the average gap between consecutive primes near the number N is approximately the natural logarithm of N. But within that statistical trend, the gaps are irregular: sometimes two primes are adjacent (twin primes, gap = 2), sometimes there is a gap of 30 or more.

The `gaps` mode maps this gap sequence to audio. Each prime triggers a short sine burst at a time proportional to its distance from the first prime, and at a pitch that rises slowly with the prime value. The `gaps_slow.wav` output plays the same sequence at quarter tempo, stretching 30 seconds to 120 seconds. At this pace, twin prime pairs (gap = 2) are clearly audible as near-simultaneous double-attacks — a rapid one-two tap — while large gaps become clearly perceptible silences. Sighted users can look at the animated gap chart; listeners hear the rhythm directly, and the slow version makes individual gap lengths countable by ear in a way that no static visualisation can match.

```sh
afplay primes/output/gaps_slow.wav
# 5000 prime gaps at quarter tempo. Listen for the double-attacks
# (twin primes) and count the silences between them.
```

---

### 5. quantum — Quantum harmonic oscillator

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

### 6. lorenz — Strange attractors

A *strange attractor* is a region of a dynamical system that trajectories are drawn toward but never escape — and never repeat. The Lorenz system (three coupled differential equations, published in 1963) was the first rigorous demonstration that a deterministic system — one with no randomness whatsoever — can produce behaviour so sensitive to initial conditions that it is practically unpredictable. This is the origin of the phrase "butterfly effect."

The Rössler attractor (the preset used in the demo) is a cousin of Lorenz with a simpler geometric structure: one wing instead of two, producing a more melodic and less jagged sonification. Each local extremum of the x-coordinate triggers one note; the x-value maps to pitch via the minor pentatonic scale; volume follows the magnitude of the excursion. The result is an improvisation that has discernible phrase structure — similar figures recur — but never quite repeats.

Sighted users watch the trajectory build up in x-z projection, coloured blue (early) through orange to red (recent). Listeners hear the same trajectory as a melodic sequence, and because the attractor has a characteristic shape, certain melodic motifs keep recurring — the audio makes the statistical regularity of chaos more immediately recognisable than the visual does.

```sh
afplay lorenz/output/rossler_audio.wav
# The Rössler attractor as melody. Listen for melodic phrases that
# almost repeat but drift — that drift is deterministic chaos.
```

---

### 7. asteroids — Live NASA data

Every day, dozens of asteroids pass near Earth. NASA's Near Earth Object Web Service (NeoWs) provides real-time close-approach data: miss distance, relative velocity, estimated diameter, and hazard classification. This app fetches the last seven days of data, fetches each asteroid's orbital elements from the JPL Small Body Database to compute its direction in the sky, and turns the dataset into a WAV file where each asteroid is one note.

Pitch is mapped from miss distance (farther away → higher pitch, using the minor pentatonic scale with root C3). Duration is inversely proportional to relative velocity (faster asteroids produce shorter notes). Volume is proportional to estimated diameter. Timbre distinguishes hazardous from non-hazardous: safe asteroids use a warm three-harmonic bell tone; hazardous asteroids use a brighter, harsher five-harmonic voice. The ordering runs farthest to closest — a steady build toward Earth — so the texture thickens and harshens as the asteroids approach.

This is the only app whose output changes every time it is run, because the data is live. A sighted user sees the GIF: a top-down solar system with asteroids revealed one by one, coloured cyan (safe) or red (hazardous). A listener hears the same information: the texture brightens and sharpens as hazardous objects appear, and the ear picks up the timbre contrast between safe and hazardous immediately, without needing to read a colour legend.

```sh
NASA_API_KEY=$NASA_API_KEY afplay asteroids/output/asteroids_$(date +%Y-%m-%d -v-6d)_$(date +%Y-%m-%d).wav
# Or simply: afplay asteroids/output/asteroids_*.wav
# Each note is one asteroid. The harsh-timbred notes are the hazardous ones.
```

---

### 8. relativity — Gravitational waves and black hole orbits

On 14 September 2015, the LIGO gravitational wave detectors registered a signal 1.3 billion years in the making: two black holes, 36 and 29 times the mass of the Sun, had been spiralling together and finally merged. As two massive bodies orbit each other, they radiate energy as gravitational waves — ripples in spacetime itself. As energy is lost the orbit shrinks, the frequency rises, the amplitude grows, until the bodies merge in an instant. The resulting signal is a *chirp*: a rising frequency sweep ending abruptly, followed by an exponentially decaying ringdown as the merged remnant oscillates and settles.

The gravitational wave strain h(t) is literally a waveform — it has amplitude and frequency, varying in time — so it can be played directly as audio after time-stretching (the default 4× stretch makes the sub-second LIGO chirp clearly audible). The simulation uses the post-Newtonian analytic approximation, the same mathematical model used to construct LIGO's matched filter templates. Four physical correctness checks verify the formulas on every run. Three preset WAV files are produced automatically: GW150914 (the first detection), GW170817 (a neutron star merger), and a stellar-mass binary for comparison.

A sighted user sees the waveform and frequency evolution plots. A listener hears exactly what LIGO's data-analysis software looked for: the characteristic pitch rise, the amplitude swell, the abrupt cutoff at merger, and the fading ringdown. Because the chirp is defined by its time-frequency structure, audio is arguably the most natural medium for experiencing it — LIGO researchers have listened to their detections since the first one.

```sh
afplay relativity/output/chirp.wav
# GW150914 at 4x time stretch. Rising pitch and volume, then silence
# at merger, then a brief fading ringdown. This is what LIGO heard.
```

---

## Infrastructure

### Config system

Every app uses a four-layer configuration hierarchy:

```
hardcoded defaults  →  config/config.json  →  <app>/config.json  →  CLI --key=value
```

Each layer overrides the previous. Parameters are addressed by dot-separated key paths, and both `--key=value` and `--key value` forms are accepted. Negative values work correctly (`--simulation.qho.alpha=-2.0`). To inspect the fully merged config for any app without running the simulation:

```sh
wolframscript -file pendulum/main.wl -- --config-dump | python3 -m json.tool
```

This makes it straightforward to verify exactly which parameters are active before a run, and to reproduce results precisely by recording the config dump alongside the output files.

### Sonification pipeline

`stem-core/src/sonification.wl` provides a three-layer pipeline that converts any numeric trajectory into a stereo WAV file. All eight apps use it (pendulum uses it twice, once per bob).

- **SpatialLayer** maps the x-coordinate of the trajectory to stereo pan, using a configurable curve. This encodes the spatial position of the simulated object in the listener's soundscape.
- **MotionLayer** maps trajectory speed to pitch via a musical scale lookup, with configurable root frequency and octave range. This encodes the *rate of change* of the system — fast-moving objects produce higher notes.
- **EventLayer** inserts accent tones at labelled events (local extrema, zero crossings, population explosions, asteroid approaches). This encodes discrete events that would otherwise be lost in continuous pitch and pan.

The three layers are mixed and peak-normalised before export. The design generalises across all eight apps because the trajectory format (`n × 5` matrix: `{t, x, y, z, speed}`) is the same regardless of what the coordinates represent — pendulum angle, attractor position, wave-packet mean, or orbital radius. Each app maps its domain quantities onto this format, then hands off to the shared pipeline.

### Accessibility

All apps run fully headlessly via `wolframscript -file` with no display server. Every console output line is a self-contained announcement formatted for VoiceOver: numbers are never split across Print arguments, labels and units are always on the same line, and major sections are delimited by `=== heading ===` markers that VoiceOver announces clearly.

Setting `STEM_SPEAK=1` before any app enables spoken announcements via the macOS `say` command at each pipeline stage and on completion:

```sh
STEM_SPEAK=1 wolframscript -file signal/main.wl -- --simulation.mode=chord
```

WAV is the right output format for an accessible scientific demonstration because it requires no display, no GUI toolkit, no browser, and no internet connection to experience. `afplay file.wav` works from any macOS terminal, including one controlled entirely by VoiceOver and keyboard navigation. The `signal` app's narrative WAV goes one step further: it is a complete, self-contained audio document that explains and demonstrates Fourier analysis with no supporting text required.

### Demo script

`demo.wl` runs all eight apps in sequence with their most compelling presets, collects every output into `demo/<appname>/`, and writes a machine-readable run report to `demo/demo-report.md`. Total runtime is approximately three to four minutes.

```sh
wolframscript -file demo.wl                        # full run
STEM_SPEAK=1 wolframscript -file demo.wl           # with spoken stage announcements
NASA_API_KEY=$NASA_API_KEY wolframscript -file demo.wl   # include live asteroid data
wolframscript -file demo.wl -- --check-only        # verify a previous run without re-running
```

The demo report records the Wolfram Language version, macOS version, per-app duration, file count, file sizes, and PASS/FAIL status for each app. It also generates a `demo/README.md` with the recommended listening order and `afplay` commands for every output WAV.

---

## Getting started

**Prerequisites:** [Wolfram Engine](https://www.wolfram.com/engine/) (free) or Mathematica 13+, with `wolframscript` on your PATH. Verify with `wolframscript -version`. An internet connection is required only for the asteroids app.

The three most important commands to run first:

**1. The narrative — understand sonification in four minutes**

```sh
wolframscript -file signal/main.wl -- --simulation.mode=chord
afplay signal/output/chord_narrative_full.wav
```

This runs the Fourier analysis demonstration and produces a self-contained audio guide. Listen to it before anything else. It will explain what sonification is and why frequency-domain filtering works, while you hear it happening.

**2. The demo — see what all eight apps produce**

```sh
wolframscript -file demo.wl
```

Runs all eight apps in sequence (~3–4 minutes), collects outputs into `demo/`, and writes `demo/demo-report.md`. After it finishes, play the outputs in the recommended order using the `afplay` commands in `demo/README.md`.

**3. The crown jewel — gravitational waves from LIGO's first detection**

```sh
wolframscript -file relativity/main.wl
afplay relativity/output/chirp.wav
```

Computes the GW150914 chirp waveform using the post-Newtonian approximation and exports it as audio at 4× time stretch. Listen for the rising pitch, the growing volume, the abrupt silence at merger, and the brief fading ringdown. This signal, detected on 14 September 2015 at the LIGO observatories, confirmed Einstein's prediction of gravitational waves from a century earlier.

---

## Acknowledgements

This project was developed with [Claude Code](https://claude.ai/claude-code) (Anthropic). The asteroids app uses NASA's [Near Earth Object Web Service (NeoWs)](https://api.nasa.gov/) and the [JPL Small Body Database API](https://ssd-api.jpl.nasa.gov/doc/sbdb.html) for live orbital data. MINT Access is a Swiss organisation and the go-to partner for universities, publishers, and companies serving the university sector that want to make their STEM teaching and research more accessible — website at [mintaccess.ch](https://www.mintaccess.ch/) (German).

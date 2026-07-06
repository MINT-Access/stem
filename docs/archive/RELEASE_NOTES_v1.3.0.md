# stem — Release Notes (v1.3.0)

v1.3.0 adds three new apps — `thermo/` (classical statistical mechanics),
`montecarlo/` (the 2D Ising model's ferromagnetic phase transition), and
`magnetic/` (charged-particle motion in electromagnetic fields) — bringing
the project to sixteen physics, mathematics, and cosmology simulations.
`dynamical/`, the logistic map app, already landed in v1.2.0; what's new
this release is the infrastructure underneath it all: every app's
spoken-word audio now goes through the same cross-platform speech pipeline,
and `cellular/`'s sonifications gained a note-holding enhancement that
makes population dynamics dramatically more audible. Two new sonification
paradigms debut alongside the new apps — additive spectral synthesis, where
the sound literally *is* a probability distribution rather than a
representation of one, and a dual-layer approach that mixes a continuous
carrier with a spatial Hilbert-curve scan running simultaneously, the first
time this project has combined two sonification strategies in one output.

---

## New app — thermo/ (Maxwell-Boltzmann distribution and statistical mechanics)

Temperature, at the molecular level, is nothing more than the average
kinetic energy of a gas's molecules — but "average" hides an enormous
spread: some molecules drift slowly, others streak past at several times
the average speed, and the precise shape of that spread is described by the
Maxwell-Boltzmann distribution, one of the founding results of statistical
mechanics. As a gas heats up, the distribution doesn't just shift toward
higher speeds — it broadens, because faster molecules deviate from the
average by ever-larger absolute amounts even though the underlying physics
hasn't changed at all.

This app takes an unusual approach to sonifying that curve: rather than
mapping a single derived number (like mean speed) to pitch, `distribution`
mode synthesises dozens of simultaneous sine partials whose amplitudes
trace the distribution's actual shape at each temperature — the sound's
spectral envelope literally *is* f(v), not a stand-in for it. `ensemble`
mode samples a fixed set of particles from that same distribution and lets
them exchange speeds via elastic collisions, audible as a chord that
continuously reshuffles which voice holds which pitch while the chord's
overall character stays perfectly fixed — thermal equilibrium is a stable
macroscopic state built from a restlessly fluctuating microscopic one.
`equipartition` mode compares a monatomic and a diatomic gas side by side:
translational motion is identical for both (left channel), but the
diatomic gas gets an additional, audible right-channel drone from its
rotational degrees of freedom — the equipartition theorem's extra heat
capacity made literally audible as a second voice.

`cooling` mode is the emotional centre of the app. Starting at 1000 K and
relaxing exponentially toward 50 K following Newton's law of cooling, the
spectral envelope doesn't just quiet down — it visibly contracts,
complexity draining out of the sound as the gas settles toward stillness,
in exactly the shape thermodynamics predicts.

```sh
wolframscript -file thermo/main.wl -- --simulation.mode=cooling
afplay thermo/output/cooling_audio.wav
# Listen for the sound narrowing and quieting as the gas cools from
# 1000 K to 50 K — molecular motion itself running down.

wolframscript -file thermo/main.wl
afplay thermo/output/distribution_audio.wav
# The Maxwell-Boltzmann distribution swept from 100 K to 1000 K for
# helium: the sound broadens and brightens exactly as fast as the
# molecules themselves speed up.
```

---

## New app — montecarlo/ (2D Ising model and ferromagnetic phase transition)

The two-dimensional Ising model — a grid of magnetic spins, each pointing
up or down, each influenced only by its four nearest neighbours — is the
simplest physical system that exhibits a genuine phase transition, and one
of the few whose transition has an exact analytic solution (Lars Onsager,
1944). Below a critical temperature T_c ≈ 2.269 (in natural units),
neighbouring spins align spontaneously and the whole lattice magnetises;
above it, thermal noise wins and magnetisation averages to zero. The same
universality class — the same critical exponents, the same qualitative
behaviour near the transition — governs everyday ferromagnets, the
liquid-gas critical point, and even binary alloy mixtures, despite their
wildly different microscopic physics.

Sampling every one of a lattice's astronomically many possible
configurations is impossible even for a modest grid, so the app uses the
Metropolis algorithm: at each step, flip a random spin, and accept the flip
unconditionally if it lowers the system's energy — but *also* accept it
with a temperature-dependent probability even when it raises the energy.
That willingness to occasionally accept a "bad" move isn't a compromise;
it's the only way to correctly sample thermal fluctuations rather than
getting stuck in one low-energy configuration. Two sonification layers run
simultaneously: a continuous carrier tracks the global observables
(magnetisation, energy, susceptibility), while a quieter background layer
scans the spin grid itself in Hilbert-curve order, holding one note per
aligned domain — the same run-length note-holding technique introduced in
`cellular/` this release, reused here for the first time on a second app.

`quench` mode has the clearest narrative arc in the project: starting from
a fully randomised, high-temperature configuration and instantaneously
dropping to a cold temperature, the audio opens turbulent — competing
domains fighting for territory — and gradually settles as larger domains
absorb smaller ones, approaching a quiet, ordered tone punctuated by
occasional domain-wall events. `critical` mode, by contrast, never resolves
either way: held exactly at T_c, correlated domains form and dissolve at
every size simultaneously, producing the most texturally complex,
scale-free sound in the project — the literal audio signature of a
continuous phase transition.

```sh
wolframscript -file montecarlo/main.wl -- --simulation.mode=quench
afplay montecarlo/output/quench_audio.wav
# Disorder, struggle, order: starts turbulent, gradually settles into
# a steady ferromagnetic tone as domains coarsen.

wolframscript -file montecarlo/main.wl -- --simulation.mode=critical
afplay montecarlo/output/critical_audio.wav
# Held exactly at the critical point — the most complex, scale-free
# texture in the project, never quite resolving either way.
```

---

## New app — magnetic/ (charged particles in electromagnetic fields)

Sixty thousand kilometres above Earth's equator, the planet's own magnetic
field traps billions of charged particles from the solar wind in two
doughnut-shaped bands — the Van Allen radiation belts — where they bounce
back and forth between reflection points near the poles, over and over,
for as long as the field holds them. This app simulates the same physics,
the Lorentz force `F = q(E + v×B)`, across four configurations, and
`mirror` mode reproduces the Van Allen mechanism directly: a magnetic field
that strengthens away from a midplane reflects a spiralling particle back
toward the centre whenever its pitch angle is steep enough, and the app's
pitch rises as the particle approaches each reflection point and falls as
it retreats, with a sharp accent at every bounce.

Of every sonification in the project, `cyclotron` mode's is the most
direct: a charged particle in a uniform magnetic field orbits at a
frequency that depends only on its charge-to-mass ratio and the field
strength — never on its speed — and this app's audio frequency literally
*is* that cyclotron frequency, after a fixed scale factor, rather than a
mapping of some other derived quantity. `drift` mode adds a perpendicular
electric field, producing a cycloid — circular motion riding on a steady
sideways drift — audible as a pitch that oscillates while the stereo image
steadily slides from one side to the other.

`multi` mode sounds a proton, an alpha particle, and an electron gyrating
in the same field simultaneously, each at its own cyclotron frequency: a
chord whose frequency ratios directly encode the three particles' relative
masses (the electron's true frequency is 1836 times the proton's — far too
high to hear, so it is rescaled to preserve the musical interval while
staying audible, with the real ratio explained in the spoken
introduction).

```sh
wolframscript -file magnetic/main.wl -- --simulation.mode=mirror
afplay magnetic/output/mirror_audio.wav
# Pitch rises and falls as the particle bounces between mirror points
# — the same physics that traps solar-wind particles in the Van Allen belts.

wolframscript -file magnetic/main.wl -- --simulation.mode=multi
afplay magnetic/output/multi_audio.wav
# Proton, alpha particle, and electron gyrating in the same field —
# a chord whose frequency ratios are the particles' mass ratios.
```

---

## Infrastructure and improvements

### Speech synthesis consistency

Every app's spoken-word audio — introductions, narrative transitions,
spoken summaries — now goes through the same three-tier pipeline: Wolfram's
built-in `SpeechSynthesize[]` first, falling back to the operating system's
native text-to-speech (macOS `say`, Linux `espeak-ng`, Windows
`SpeechSynthesizer`) if that's unavailable, falling back to silence (with
the surrounding audio structure otherwise unchanged) if both fail. `signal/`
was the last holdout, previously calling platform-native tools directly
with no `SpeechSynthesize[]` attempt at all; its narrative WAV files
(`chord_narrative_full.wav` and its `sweep`/`am` equivalents) retain their
exact structure — spoken introduction, clean signal, spoken transition,
noisy signal, spoken transition, recovered signal, spoken summary — now
generated the same way on every platform.

### cellular/ note-holding

`cellular/`'s Game of Life and Rule 110 sonifications previously produced a
continuous stream of notes, one per generation, even while the population
held perfectly steady. A run-length articulation scheme now holds a single
sustained tone through stable periods and only triggers a new note when the
population changes by more than a configurable threshold
(`articulation_threshold`, default 15% relative change; `articulation_mode`
also supports an absolute-count threshold via `articulation_threshold_abs`,
default 5). A steady colony now sounds steady; population explosions and
collapses stand out clearly against that stillness rather than blending
into a wash of continuous notes. The existing extinction/explosion accent
tones are unchanged. This same run-length technique now also powers
`montecarlo/`'s spatial Hilbert-curve layer — the first time it has been
reused on a second app.

### Documentation and consistency

`docs/APPS.md` now documents all sixteen apps, including the new
`simulation.cellular.*` config keys the note-holding enhancement
introduced. The root `README.md` and `AGENTS.md` are updated throughout —
repository layout, Quick Start examples, per-app descriptions, and (in
`AGENTS.md`) two new sonification-paradigm notes: additive spectral
synthesis (`thermo/`) and dual-layer trajectory-plus-spatial sonification
(`montecarlo/`).

---

## Getting started

**Prerequisites:** [Wolfram Engine](https://www.wolfram.com/engine/) (free)
or Mathematica 13+, with `wolframscript` on your PATH. Verify with
`wolframscript -version`. An internet connection is required only for the
asteroids app (live NASA data) and for the cosmology app when using
`--simulation.cosmology.source=planck`.

The three most important commands to run first:

**1. The narrative — understand sonification in four minutes**

```sh
wolframscript -file signal/main.wl -- --simulation.mode=chord
afplay signal/output/chord_narrative_full.wav
```

Unchanged from previous releases, and still the best entry point: a
self-contained audio guide — spoken introduction, clean chord, chord
buried in noise, chord recovered by the DFT — that explains what
sonification is while you hear it happening.

**2. The demo — all sixteen apps in one run**

```sh
wolframscript -file demo.wl
```

Runs all sixteen apps in sequence (measured: seventeen passes total, since
`dynamical/` demonstrates two modes — approximately four to five minutes
on a modern Mac, including live asteroid data), collects every output into
`demo/`, and writes `demo/demo-report.md` with per-app runtimes and
PASS/FAIL status. Follow the listening guide in `demo/README.md` for the
recommended order and the playback command for each output.

**3. The crown jewel for v1.3.0 — order from disorder in thirty seconds**

```sh
wolframscript -file montecarlo/main.wl -- --simulation.mode=quench
afplay montecarlo/output/quench_audio.wav
```

An instantaneous temperature drop from fully disordered to deep in the
ferromagnetic phase. Listen for the audio starting turbulent — competing
magnetic domains fighting for territory — and gradually settling into a
steady, ordered tone as larger domains absorb smaller ones. This is the
same physics that decides whether a permanent magnet forms when molten
iron cools past its Curie point, heard start to finish in about thirty
seconds.

---

## Acknowledgements

This project was developed with [Claude Code](https://claude.ai/claude-code)
(Anthropic). The asteroids app uses NASA's [Near Earth Object Web Service
(NeoWs)](https://api.nasa.gov/) and the [JPL Small Body Database
API](https://ssd-api.jpl.nasa.gov/doc/sbdb.html) for live orbital data. The
cosmology app's `--simulation.cosmology.source=planck` mode fetches the
Planck 2018 best-fit TT power spectrum from the [Planck Legacy
Archive](https://pla.esac.esa.int/). The images app's `hsb` mode is based on
Srinath Rangan's 2018 Wolfram Community post *Image Sonification Using
Hilbert Curves*; the `brightness` and `colour` modes, and the run-length
note-holding technique introduced in `cellular/` this release and now
reused in `montecarlo/`'s spatial layer, draw on Neha Rao's 2025 Wolfram
Summer Research Program work on sonification strategies for 2D images.
MINT Access is a Swiss organisation and the go-to partner for
universities, publishers, and companies serving the university sector that
want to make their STEM teaching and research more accessible — website at
[mintaccess.ch](https://www.mintaccess.ch/) (German).

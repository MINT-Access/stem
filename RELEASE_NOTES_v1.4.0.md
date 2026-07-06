# stem — Release Notes (v1.4.0)

v1.4.0 adds five new apps — `hydrogen/` (the hydrogen atom's wave functions
and emission spectrum), `bayes/` (Bayesian inference), `scattering/`
(Rutherford alpha-particle scattering), `resonance/` (orbital resonances),
and `fluid/` (the Kármán vortex street) — completing a planned expansion
across quantum mechanics, probability and statistics, particle physics,
celestial mechanics, and fluid dynamics. The project now covers twenty-one
physics, mathematics, and cosmology simulations. This release also marks a
deliberate pause in new-app development: with this breadth of coverage in
place, the next phase turns from building toward bringing the project into
active use at universities, publishers, and research institutions.

---

## New app — hydrogen/ (the hydrogen atom: wave functions and the Balmer series)

Hydrogen is the only atom whose Schrödinger equation can be solved exactly,
in closed form — and that exact solution turns out to explain something you
can see with your own eyes on any clear night. Four of hydrogen's emission
lines fall in the visible spectrum, the Balmer series, and those same four
precise frequencies of light appear in the spectrum of every star ever
observed, including the Sun. Niels Bohr explained why those frequencies take
exactly the values they do in 1913 — energy levels quantised as
`E_n = -13.6/n²` electron-volts, with a photon's frequency fixed by the
energy difference between two levels — one of the founding results of
quantum mechanics.

Three modes make different parts of that picture audible. `orbitals` mode
scans a wave function's probability density across a 2D cross-section using
the same Hilbert-curve traversal `images/` uses for photographs — nodes,
the surfaces where an electron has exactly zero probability of appearing,
become audible silences as the scan crosses them. `spectrum` mode sonifies
the complete emission spectrum, first as a chord with every line ringing
simultaneously, then as a sweep from ultraviolet through the four
bell-marked Balmer lines to infrared. `transitions` mode follows a single
electron cascading down through the energy levels toward the ground state,
choosing a different random sequence of quantum jumps each time — twenty
different melodies, all obeying the same selection rule, all ending on the
same final note.

```sh
wolframscript -file hydrogen/main.wl -- --simulation.mode=spectrum
afplay hydrogen/output/spectrum_audio.wav
# The full n=2 to n=8 emission spectrum: a chord of every line at once,
# then a sweep from UV through the four bell-marked Balmer lines — the
# actual visible colour of hydrogen — to infrared.

wolframscript -file hydrogen/main.wl -- --simulation.mode=transitions
afplay hydrogen/output/transitions_audio.wav
# Twenty independent electron cascades from an excited state to the
# ground state — twenty different quantum melodies, each obeying the
# same rule, all converging on the same final note.
```

---

## New app — bayes/ (Bayesian inference: uncertainty becoming certainty)

Every scientist updates their beliefs as evidence arrives, but Bayesian
inference makes that process precise: start with a prior — what you
believed before seeing any data — combine it with the likelihood of the
data you actually observed, and arrive at a posterior, an updated belief
that is not a single number but an entire distribution of remaining
possibilities. This app makes three kinds of Bayesian updating directly
audible, with no differential equations, orbital mechanics, or wave
functions involved at all — the most conceptually distinct app in the
project.

`coin` mode's posterior over an unknown coin's bias is sonified the same
way `thermo/`'s Maxwell-Boltzmann distribution is: as a spectral
envelope, dozens of simultaneous sine partials whose amplitudes trace the
distribution's actual shape, so the sound's spectral character literally
*is* the belief state rather than a stand-in for it. The two apps share a
technique but not a driver — `thermo/`'s spectrum narrows because
temperature falls; `bayes/`'s narrows because information accumulates —
and hearing the same narrowing sound emerge from two completely unrelated
physical processes is a striking demonstration that "spectral narrowing"
is a general signature of concentrating probability, not a coincidence
specific to either field. `model` mode asks a different kind of question
— not "what is the parameter?" but "which of two competing hypotheses does
the data support?" — and answers it with a stereo field that drifts
toward whichever hypothesis the accumulating evidence favours, the Bayes
factor made audible as physical position.

```sh
wolframscript -file bayes/main.wl
afplay bayes/output/coin_audio.wav
# A coin's bias updated flip by flip: the sound begins broad and
# uncertain — every bias equally plausible — and narrows to a focused
# tone as 100 simulated flips accumulate. The narrowing is the inference.

wolframscript -file bayes/main.wl -- --simulation.mode=model
afplay bayes/output/model_audio.wav
# Two competing hypotheses about the same coin. Listen on headphones for
# the stereo image drifting toward whichever hypothesis the data favours
# — the weight of evidence, heard as physical position.
```

---

## New app — scattering/ (Rutherford scattering: the experiment that discovered the nucleus)

In 1909, Hans Geiger and Ernest Marsden, working under Ernest Rutherford at
the University of Manchester, fired alpha particles at a sheet of gold foil
and found that a small fraction bounced almost straight back. Under J.J.
Thomson's prevailing model of the atom — positive charge spread evenly
through a diffuse sphere — that result should have been essentially
impossible; Rutherford later described it as "almost as incredible as if
you fired a 15-inch shell at a piece of tissue paper and it came back and
hit you." The only explanation was that almost all of the atom's mass and
positive charge is concentrated in a tiny, dense nucleus — the discovery
Rutherford announced in 1911, and the model of the atom still essentially
correct today.

`discovery` mode recreates that historical comparison directly in
binaural stereo: the left channel plays what Thomson's diffuse-charge model
predicts — a quiet, uniform background confined to less than one degree of
deflection, and nothing more — while the right channel plays the same
background under Rutherford's nuclear model, but now with occasional loud,
sharp large-angle events layered on top, events the Thomson model is
structurally incapable of producing at any volume. Those sudden events,
audible in the right channel and completely absent from the left, are what
changed physics: the same evidence Geiger and Marsden actually recorded,
made audible as the presence or absence of a sound that either can or
cannot exist depending on where an atom's charge really sits.

```sh
wolframscript -file scattering/main.wl -- --simulation.mode=discovery
afplay scattering/output/discovery_audio.wav
# Headphones recommended. Left channel: Thomson's plum-pudding model,
# confined to under one degree. Right channel: Rutherford's nuclear
# model, same quiet background plus rare, loud backscatter events the
# left channel cannot produce at any volume — the discovery of the
# atomic nucleus, in stereo.
```

---

## New app — resonance/ (orbital resonances: gravity as music)

Io, Europa, and Ganymede — three of Jupiter's largest moons — orbit in a
period ratio of almost exactly 4:2:1, a three-body Laplace resonance that
has held steady for billions of years. In musical terms, 4:2:1 is a
two-octave interval, the widest possible spacing built from the most
consonant ratio there is. This app assigns each moon a note a perfect
octave apart from its neighbours — Ganymede plays C3, Europa C4, Io C5 —
and sounds each note once per completed orbit, so the three-voice canon
that results is not a decorative arrangement layered onto the physics; it
is the orbital mechanics itself, with a 1:2:4 ratio of note counts because
that is exactly the period ratio. That same three-voice pattern has been
playing, unheard, in the Jovian system since long before humans existed to
notice it.

The same underlying mechanism — repeated gravitational kicks from a
resonance with Jupiter — appears twice more in this app, working in the
opposite direction. `kirkwood` mode sonifies the asteroid belt's density as
a function of distance from the Sun, and the Kirkwood gaps — regions swept
almost completely clear by resonant encounters with Jupiter, noticed by
Daniel Kirkwood in 1866 — are audible as sudden silences in an otherwise
continuous sweep. `saturn` mode does the same for Saturn's rings, where the
Cassini Division, visible through any small backyard telescope since 1675,
produces the longest and clearest silence of all. Johannes Kepler spent
much of his career searching for a "harmony of the spheres" in planetary
motion and got the details wrong — but the Galilean moons, discovered just
nine years before his death, are the genuine article he never lived to
hear.

```sh
wolframscript -file resonance/main.wl
afplay resonance/output/galilean_audio.wav
# Count the notes: exactly 4 Io (C5) for every 1 Ganymede (C3), 2 Europa
# (C4) in between. A two-octave chord locked in place by gravity, playing
# the same rhythm since before the Earth had an atmosphere.
```

---

## New app — fluid/ (Kármán vortex street: the sound of flow)

A flagpole singing in a steady wind, a humming power line, the aeroelastic
flutter that tore apart the original Tacoma Narrows Bridge in 1940 — all
three are the same phenomenon: fluid flowing past a bluff obstacle sheds
alternating vortices from each side, producing an oscillating force at a
characteristic frequency named after Theodore von Kármán, who analysed its
stability in 1911. This app maps that Strouhal frequency directly onto
audio pitch, so `karman` mode's tone is not a representation of the
shedding rate — it *is* the shedding rate, rescaled into the audible range.

`strouhal` mode's centrepiece is a genuine bifurcation, heard rather than
plotted: below a Reynolds number of about 47 the flow is steady and
symmetric, and the audio is silent; at that threshold, vortex shedding
switches on and a pure tone appears from nothing. It is the same
mathematical event as the logistic map's first period-doubling in
`dynamical/` — a smooth, continuous change in a parameter producing a
sudden, qualitative change in behaviour — here playing out in the physics
of flowing fluid instead of an abstract equation. `flag` mode applies the
same underlying idea to a flexible flag flapping in the flow, modelled as a
driven oscillator whose flutter frequency pans audibly left and right with
every flap.

```sh
wolframscript -file fluid/main.wl
afplay fluid/output/karman_audio.wav
# A steady tone at the Strouhal frequency, Re=150, with alternating
# clicks marking each vortex shed from the top and bottom of the
# cylinder — the pitch a wire or flagpole actually sings in the wind.

wolframscript -file fluid/main.wl -- --simulation.mode=strouhal
afplay fluid/output/strouhal_audio.wav
# Silence, then a pure tone appearing out of nothing near Re=47 — a
# fluid-dynamical bifurcation, the same kind of event as the logistic
# map's first period-doubling, heard instead of plotted.
```

---

## What comes next

Version 1.4.0 completes the current development phase. The project now
covers an unusually broad range of undergraduate physics and mathematics —
quantum mechanics, chaos theory, statistical physics, orbital mechanics,
electromagnetism, atomic physics, probability, and fluid dynamics — all
accessible from a terminal with a pair of headphones, cross-platform, with
a generated HTML demonstration page that needs no installation to explore.

The next phase shifts focus from building new apps to bringing the project
into active use: conversations with universities and publishers about
accessible figure supplements and teaching demonstrations, and continued
development of the mintaccess.ch demonstration website. The codebase
remains open, and new apps will return in future development phases.

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

**2. The demo — all twenty-one apps in one run**

```sh
wolframscript -file demo.wl
```

Runs all twenty-one apps in sequence (measured: 22 passes total, since
`dynamical/` demonstrates two modes — approximately five minutes on a
modern Mac, including live asteroid data), collects every output into
`demo/`, and writes `demo/demo-report.md` with per-app runtimes and
PASS/FAIL status. Follow the listening guide in `demo/README.md` for the
recommended order and the playback command for each output, or open
`demo/demo.html` in a browser for the same tour with inline audio players.

**3. The crown jewel for v1.4.0 — a chord held in place by gravity**

```sh
wolframscript -file resonance/main.wl
afplay resonance/output/galilean_audio.wav
```

Io, Europa, and Ganymede playing a two-octave chord — C5, C4, C3 — one
note per completed orbit, in an exact 4:2:1 ratio. It is the same chord,
the same rhythm, every time, because the physics that produces it hasn't
changed in billions of years. Johannes Kepler imagined a harmony of the
spheres in 1619 and got the details wrong; the Galilean moons, discovered
by his contemporary Galileo just nine years earlier, are proof the idea
itself was right all along.

---

## Acknowledgements

This project was developed with [Claude Code](https://claude.ai/claude-code)
(Anthropic). No new external data sources were introduced this release; the
asteroids app continues to use NASA's [Near Earth Object Web Service
(NeoWs)](https://api.nasa.gov/) and the [JPL Small Body Database
API](https://ssd-api.jpl.nasa.gov/doc/sbdb.html) for live orbital data, and
the cosmology app's `--simulation.cosmology.source=planck` mode continues to
fetch the Planck 2018 best-fit TT power spectrum from the [Planck Legacy
Archive](https://pla.esac.esa.int/). The images app's `hsb` mode is based on
Srinath Rangan's 2018 Wolfram Community post *Image Sonification Using
Hilbert Curves*; the `brightness` and `colour` modes, and the run-length
note-holding technique introduced in `cellular/` and now reused in
`montecarlo/`'s spatial layer, draw on Neha Rao's 2025 Wolfram Summer
Research Program work on sonification strategies for 2D images. More
broadly, the simulation and sonification approaches used across all
twenty-one apps in this project have been informed throughout by the
Wolfram Language community's educational examples and documentation —
thank you to everyone whose public work made this project's breadth
possible. MINT Access is a Swiss organisation and the go-to partner for
universities, publishers, and companies serving the university sector that
want to make their STEM teaching and research more accessible — website at
[mintaccess.ch](https://www.mintaccess.ch/) (German).

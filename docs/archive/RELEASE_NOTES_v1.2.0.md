# stem — Release Notes (v1.2.0)

v1.2.0 builds on v1.1.0's twelve-app, three-platform foundation with a new
app, a significant scientific-accuracy upgrade to an existing one, and a
round of consistency polish. The centrepiece is `dynamical/`, sonifying the
logistic map's period-doubling route to chaos — one of the clearest possible
demonstrations that a rhythm can double, double again, and dissolve into
chaos, then return to order exactly where mathematics says it must. The
`images/` app is redesigned around scientific colour theory and human
hearing rather than general-purpose accessibility conventions, and a batch
of wording and consistency fixes brings the demo page and documentation in
line with both changes.

---

## New app — dynamical/ (logistic map)

The logistic map, x_{n+1} = r·x_n·(1−x_n), is one of the simplest equations
in mathematics that produces chaos: a single line, one parameter, describing
population growth bounded by a carrying capacity. As the growth rate r
increases from 0 to 4, the long-term behaviour of the map undergoes one of
the most famous sequences of transitions in nonlinear dynamics. Below r=1
the population collapses to zero; between 1 and 3 it settles to a single
stable value; at r≈3.0 that value suddenly splits into two, alternating
forever; at r≈3.449 it splits again into four; at r≈3.544 into eight; and by
r≈3.5644 the period-doublings have accumulated into full chaos. This app
makes that cascade audible: `sweep` mode traverses r from 2.5 to 4.0 in a
single audio file, and `iterate` mode fixes r (or a named preset) and plays
the map's actual time evolution as a directly countable rhythm.

The ratio between successive period-doubling intervals converges to the
Feigenbaum constant, δ≈4.66920160910299 — not a quirk of this particular
equation, but a universal number that appears in the period-doubling route
to chaos of *any* smooth one-dimensional map with a single hump. Discovering
this universality was one of the founding results of chaos theory: wildly
different physical systems approach chaos via period-doubling at the same
rate. This app locates the first three bifurcation points numerically, via
root-finding on the map's own stability conditions rather than hardcoding
known values, and verifies the ratio directly against δ on every run,
alongside three other correctness checks (the analytic fixed point at
r=2.8, the period-2 sum formula at r=3.2, and a positive Lyapunov exponent
at r=4.0).

The standout listening moment is the period-3 window, near r≈3.83: deep
inside the chaotic region, the map suddenly locks into a clean, repeating
three-note cycle before dissolving back into chaos as r increases further.
This is not a fluke. A landmark 1975 theorem by Li and Yorke — titled,
simply, "Period Three Implies Chaos" — proved that any continuous
one-dimensional map with a period-3 orbit must also have points of every
other period, with chaotic behaviour mathematically guaranteed nearby. The
period-3 window's existence is not an accident of the logistic map
specifically; it is a necessary consequence of having a period-3 orbit at
all. Sonification is built from discrete, precisely-timed notes rather than
a continuous tone, specifically so this rhythm is countable by ear: pitch
follows the map's value on a three-octave minor pentatonic scale, stereo pan
tracks the same value left-to-right, and volume tracks how much the value
changed from the previous iteration — the chaotic region's larger jumps
sound audibly louder and busier than the steady periodic region. In sweep
mode, three accent tones mark the first bifurcation, the onset of chaos, and
the period-3 window as the sweep reaches them, announced both on screen and
by voice.

```sh
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=period3_window
afplay dynamical/output/iterate_audio.wav
# Listen for a clean three-note rhythm appearing spontaneously inside what
# should be pure chaos — an island of order that mathematics guarantees
# must exist, right where you hear it.
```

---

## images/ enhancements

The `images/` app's original design, adapted from two Wolfram Community
image-sonification techniques, prioritised general-purpose accessibility
conventions — a chord-tone colour palette, linear brightness scaling. This
release redesigns the app around scientific data instead, on the premise
that a false-colour temperature map or a probability density plot deserves
a sonification scheme built for scientific meaning rather than borrowed from
general accessibility practice.

Five changes drive that redesign. The `colour` mode's palette now orders
nine colours by their position in the visible light spectrum — violet the
lowest pitch, red the highest, plus white and black as endpoints — matched
to each pixel using colour distance in the perceptually uniform Lab colour
space rather than raw RGB distance, so pitch now tracks a meaningful
physical quantity instead of an arbitrary chord voicing. The `brightness`
mode defaults to logarithmic brightness-to-pitch scaling, matching how human
hearing perceives frequency and how most scientific data is actually
distributed, with a configurable gamma to compress highlights or shadows; a
`linear` option remains available. A new `scan_horizontal` mode traverses
the image in simple row-by-row order rather than Hilbert-curve order,
specifically so a listener can hear the Hilbert curve's locality benefit
directly by comparing the two on the same image. In `hsb` mode, brightness
is now encoded as timbre — a pure reference tone growing richer with
harmonics — rather than a second, independent pitch, so pitch and timbre
together carry colour and brightness as two simultaneously perceptible
channels instead of two pitches a listener has to track separately. And
every run now opens with a short spoken introduction describing the image,
its dimensions, the mode in use, and how to interpret what follows, with
soft orientation clicks at the quarter-points of large traversals.

See [`images/LISTENING_GUIDE.md`](images/LISTENING_GUIDE.md) for the
recommended listening sequence — starting with `scan_horizontal`, then
`brightness`, to hear the Hilbert curve's benefit directly, followed by
`colour` and `hsb`.

---

## Polish and consistency fixes

A round of wording and demo-page consistency fixes accompanies this
release. The generated demo page's audio player labels previously read
"Full narrative (recommended)" for every app, though only `signal` actually
has a spoken narrative; each app now has its own accurate, descriptive
label. The word "musical" — used loosely throughout the demo page and a few
app descriptions to describe what is, in every case, a scientific data
encoding rather than an aesthetic product — has been replaced with more
precise language throughout. A `docs/PRE_RELEASE_REFINEMENTS.md` tracking
document was also introduced during this release cycle to record polish
items as they were noticed, so they could be resolved deliberately in this
consolidation pass rather than accumulating indefinitely.

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

This runs the Fourier analysis demonstration and produces a self-contained
audio guide: spoken introduction, clean C major chord, chord buried in
noise, chord recovered by the DFT. Listen to it before anything else — it
explains what sonification is and why frequency-domain filtering works,
while you hear it happening.

**2. The demo — all thirteen apps in one run**

```sh
wolframscript -file demo.wl
```

Runs all thirteen apps in sequence (approximately four minutes on a modern
Mac), collects every output into `demo/`, and writes `demo/demo-report.md`
with per-app runtimes and PASS/FAIL status. After it finishes, follow the
listening guide in `demo/README.md` for the recommended order and the
playback command for each output.

**3. The crown jewel — order, guaranteed, inside chaos**

```sh
wolframscript -file dynamical/main.wl -- --simulation.dynamical.preset=period3_window
afplay dynamical/output/iterate_audio.wav
```

Fixes the logistic map at r≈3.83, deep in the chaotic region, and plays its
actual time evolution. Listen for a clean, repeating three-note rhythm
appearing spontaneously in what should be pure chaos — the period-3 window.
Its existence is not a coincidence: a 1975 theorem proves that any map with
a period-3 orbit must also be chaotic nearby, so this moment of order is
mathematically guaranteed to exist, and this app lets you hear exactly where
it is.

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
Hilbert Curves*; the `brightness` and `colour` modes draw on Neha Rao's 2025
Wolfram Summer Research Program work on sonification strategies for 2D
images, adapted in this release for scientific rather than general-purpose
use. MINT Access is a Swiss organisation and the go-to partner for
universities, publishers, and companies serving the university sector that
want to make their STEM teaching and research more accessible — website at
[mintaccess.ch](https://www.mintaccess.ch/) (German).

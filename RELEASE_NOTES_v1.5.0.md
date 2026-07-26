# stem — Release Notes (v1.5.0)

v1.5.0 adds eleven new apps — `blackbody/`, `compton/`,
`quantum_tunnelling/`, `clt/`, `henon/`, `brownian/`, `qubit/`, `bell/`,
`grover/`, `quantum_statistics/`, and `mandelbrot/` — taking the project
from 21 apps to 32. It also does something the project hasn't done
before: a full correctness audit of every app, old and new alike, which
found and fixed five real bugs, including one in the shared
sonification pipeline every trajectory-based app depends on. More on
that below — it's arguably the more important story in this release,
even though eleven new apps is the bigger number.

---

## New apps

### blackbody/ — Planck black body radiation

Sweeps a black body's spectral radiance across the electromagnetic
spectrum, sonifying the Planck curve itself as a spectral envelope
(reusing `thermo/`'s additive-synthesis technique directly). `spectrum`
mode marks the 400–700nm visible band with accent taps — hear how
little of a star's actual output falls inside the narrow window human
eyes can see. `temperature` mode sweeps 2500K–40000K, making Wien's
displacement law (the peak shifting to higher pitch) and the
Stefan-Boltzmann law (total power, log-compressed into loudness) audible
together. `star` mode tours six named presets, red dwarf through white
dwarf, ending with the Sun landing exactly where Wien's law says it
should: peak emission in the visible band, 5778K.

```sh
wolframscript -file blackbody/main.wl -- --simulation.mode=star \
                                          --simulation.blackbody.preset=all
afplay blackbody/output/star_audio.wav
```

### compton/ — Compton scattering

A photon scatters off an electron and comes out with less energy — the
1923 experiment that proved light carries momentum, not just energy.
`scatter` mode plays a single collision at Compton's own historical
values (71pm Mo K-alpha X-rays, 90°) as a narrated sequence. `sweep`
turns the scattering formula itself into a continuous glissando.
`energy` sweeps incident photon energy from 1 keV to 5 MeV, crossing
the electron's rest energy (511 keV) where incoming and outgoing
pitches audibly pull apart. `discovery` reuses `scattering/`'s binaural
classical-vs-quantum structure — left channel Thomson's (wrong)
prediction, right channel the real, energy-dependent result.

```sh
wolframscript -file compton/main.wl -- --simulation.mode=discovery
afplay compton/output/discovery_audio.wav
```

### quantum_tunnelling/ — barriers that aren't quite barriers

A particle with too little energy to classically cross a barrier still
sometimes does. `barrier` mode plays a single crossing as a narrated
event whose reflected and transmitted tones sound *simultaneously* —
both genuinely happen, weighted by probability, not a coin flip. Three
presets span twelve orders of magnitude: a textbook electron (T≈2.35%),
a scanning-tunnelling-microscope gap (T≈7.5×10⁻⁶), and an
illustrative-only alpha-decay barrier (T≈7×10⁻¹⁰) — the last one
honestly labelled as a simplified stand-in for the real (non-rectangular)
Coulomb barrier Gamow actually solved in 1928. `energy` mode sweeps
particle energy across the barrier height into a genuine surprise:
perfect-transmission resonances *above* the barrier, the same
standing-wave condition that quantizes `quantum/`'s particle-in-a-box.

```sh
wolframscript -file quantum_tunnelling/main.wl -- --simulation.mode=energy
afplay quantum_tunnelling/output/energy_audio.wav
```

### clt/ — the Central Limit Theorem

`sweep` mode sums N=1–30 draws from one source distribution and
sonifies the *raw* sample mean — the one quantity that genuinely
narrows and smooths into a bell shape at the same time, unlike a
standardized version, which only ever does the latter. `compare` mode
instead sonifies the *standardized* mean for two deliberately different
sources (uniform, exponential) simultaneously in binaural stereo,
isolating the universality of the limiting shape from each source's own
scale. `dice` mode sonifies the sum of up to ten fair dice — the most
recognisable version of this theorem there is. All four correctness
checks are built against exact, independently-derivable references
(the Irwin-Hall distribution, dice combinatorics, exact kurtosis
constants) rather than the generator's own formula — a discipline this
release leans on hard; see the audit section below for why.

```sh
wolframscript -file clt/main.wl -- --simulation.mode=compare
afplay clt/output/compare_audio.wav
```

### henon/ — a second, 2D route to chaos

Michel Hénon built this map in 1976 as a simplified model of a Poincaré
section through the Lorenz attractor — a real, direct link to `lorenz/`
already in this repo. `attractor` mode (default) settles onto the
classic strange attractor and sonifies it via `lorenz/`'s own
continuous-trajectory technique. `sweep` mode traverses the map's own
period-doubling route to chaos, turning up a period-7 window near
a≈1.227 — this app's own analogue of `dynamical/`'s period-3 window,
independently confirmed, not copied from a table. `reverse` mode
demonstrates the map's exact invertibility (unlike the logistic map)
with a short, deliberately honest exact-inverse demonstration, since
the inverse map is area-*expanding* and long backward integration would
amplify numerical error rather than genuinely reverse the dynamics.

```sh
wolframscript -file henon/main.wl -- --simulation.mode=sweep
afplay henon/output/sweep_audio.wav
```

### brownian/ — how we found out atoms are real

Robert Brown watched pollen grains jitter in water in 1827 and wasn't
sure why. Einstein explained it in 1905; Perrin's experiments confirmed
it a few years later, settling a centuries-old dispute about whether
atoms actually exist. `walk` mode sonifies a single random walk — pan
and pitch from position, but *volume from displacement, not speed*, a
deliberate departure from this project's more common convention, since
"how far it's wandered" is the physically meaningful quantity for
diffusion. `ensemble` mode makes the √t growth law audible directly, as
a clean rising tone cutting through the noise a single walker can't
avoid. `temperature` mode sweeps the Stokes-Einstein relation. A random
walk is, not incidentally, exactly the Central Limit Theorem applied to
position — the third explicit connection this app draws, alongside
`thermo/` and `dynamical/`.

```sh
wolframscript -file brownian/main.wl -- --simulation.mode=ensemble
afplay brownian/output/ensemble_audio.wav
```

### qubit/, bell/, grover/ — a quantum-computing trio

Three apps building on each other. `qubit/` is the foundational piece:
a single qubit on the Bloch sphere, gate operations (each an exactly
unitary matrix), Rabi oscillation, and Born-rule measurement converging
via Monte Carlo, echoing `bayes/coin`'s flip-by-flip belief update.

`bell/` has the strongest historical arc in the whole project: Einstein,
Podolsky and Rosen argued in 1935 that quantum mechanics must be
incomplete; Bell showed in 1964 the question was experimentally
answerable; Aspect's experiments in the 1980s, and decades of
increasingly rigorous follow-ups, showed nature disagrees with every
local hidden-variable theory. Clauser, Aspect, and Zeilinger shared the
2022 Nobel Prize for this line of work. `chsh` mode derives (not
recalls) the measurement angles that push the CHSH correlation to
2√2 ≈ 2.828 — verified against an exhaustive enumeration of all sixteen
possible local-hidden-variable strategies, none of which can exceed 2.

`grover/` demonstrates the other reason quantum computing matters: a
proven O(√N) search speedup over any classical algorithm's O(N). Its
geometry is exact — every iteration is precisely a rotation by 2θ in a
2D subspace — which means there's a genuine optimal stopping point:
keep iterating past it and the answer gets *worse*, not better.

```sh
wolframscript -file qubit/main.wl -- --simulation.mode=rabi
wolframscript -file bell/main.wl -- --simulation.mode=chsh
wolframscript -file grover/main.wl -- --simulation.mode=compare
afplay bell/output/chsh_audio.wav
```

### quantum_statistics/ — the quantum/thermo bridge

`thermo/`'s classical Maxwell-Boltzmann gas turns out to be a limiting
case of something deeper. This app sonifies Bose-Einstein, Fermi-Dirac,
and Maxwell-Boltzmann occupation numbers together, and proves the
connection algebraically rather than asserting it: the fractional
deviation of either quantum distribution from the classical one turns
out to equal the quantum distribution's own occupation number, an exact
identity, not an approximation that happens to look good near some
chosen threshold. `fermi_sea` mode gives fermions their own spotlight —
the Pauli exclusion principle's sharp T→0 step function, audibly
sharpening and blurring with temperature.

```sh
wolframscript -file quantum_statistics/main.wl -- --simulation.mode=fermi_sea
afplay quantum_statistics/output/fermi_sea_audio.wav
```

### mandelbrot/ — the boundary is where it gets interesting

The classic fractal, sonified via the same Hilbert-curve traversal
`images/` and `cosmology/sky` already use. The escape radius (2) is
derived here, not just cited as convention. The app's own headline
claim — that the set's boundary produces the most complex audio — is
quantified, not just asserted: the boundary zone's local pitch
variation measures 5.4× the interior's and 57.7× the exterior's, on the
actual field this app generates. `julia` mode very nearly shipped with
the commonly-cited textbook constant (−0.7+0.27015i) as its default,
until verification showed that point is actually *outside* the
Mandelbrot set — giving a disconnected Julia set, exactly the wrong
kind of example for a mode built around the Mandelbrot-Julia
connectivity theorem. The default is now a verified interior point (the
Douady rabbit, −0.123+0.745i) instead.

```sh
wolframscript -file mandelbrot/main.wl -- --simulation.mode=zoom
afplay mandelbrot/output/mandelbrot_zoom.wav
```

---

## A correctness audit, and what it found

Every app in this project — the 21 that shipped before this release and
the 11 new ones — was reviewed line by line against independently
derived physics: hand-worked formulas, from-scratch symbolic
derivations, and real numerical simulations checked against each app's
own claims, not just its own tests. Most apps held up exactly. Five did
not, and all five are fixed in this release:

- **`asteroids/`** — Earth's own hardcoded orbital elements stored the
  *longitude* of perihelion where the *argument* of perihelion was
  needed, double-counting the ascending-node angle. The bug introduced
  a constant ~11.26° error in Earth's computed position on every run,
  silently biasing where every asteroid sourced from real orbital
  elements was placed in the visualization.
- **`compton/`** — a missing minus sign in the recoil-electron angle
  calculation meant the exported CSV data disagreed with the app's own
  diagram about which side the electron recoiled toward. The diagram
  happened to look right anyway, because a *second*, independent sign
  flip elsewhere was silently compensating for the first.
- **`cosmology/`** — the most significant single bug this release
  found. `sky` mode's simulated CMB temperature map was roughly 90×
  too quiet — its own correctness check had the identical missing
  normalization factor as the generator it was meant to be checking,
  so both were wrong in exactly the same way and the check passed
  regardless. Fixed, and verified against an independently-derived,
  convention-free physical relation. `sky` mode also gained a
  resolution-limit diagnostic: it now reports plainly which named
  acoustic peaks a given `sky_resolution` setting can and can't
  represent, rather than silently truncating them.
- **`quantum/`** — the quantum harmonic oscillator's spatial
  eigenfunctions used the standard formula for ω=1 specifically, but
  never actually scaled with ω — even though the app's own README
  documents `--simulation.qho.omega=2.0` as a real example. The bug was
  invisible at the default ω=1 (where the broken and correct formulas
  are identical) and undetectable by either of the app's own existing
  checks, which is exactly why an independent, from-scratch
  verification against the analytic oscillation amplitude was needed to
  catch it.
- **`stem-core/sonification.wl`** — the widest-reaching fix. The shared
  `SpatialLayer` function clipped pan values back into their configured
  range after spline interpolation, but not pitch or volume — meaning
  cubic-spline overshoot could, for sharply-varying or sparsely-sampled
  trajectories, push pitch outside its configured Hz range entirely,
  including negative. This affects every app built on
  `SonifyTrajectory` or the shared layer functions directly —
  `lorenz/`, `henon/attractor`, `brownian/walk`, `lagrange/`, and any
  future app that reuses the same pipeline.

Three older apps — `lorenz/`, `pendulum/`, and `magnetic/` — predated
this project's convention of four correctness checks printed on every
run. All three now have them: `lorenz/` gained an exact
constant-divergence check (Lorenz only — Rössler's divergence turns out
to depend on position, so no equivalent check was forced onto it where
it wouldn't be true), equilibrium-point verification for both systems,
and Lyapunov exponents computed via proper Benettin renormalization,
not the naive single-perturbation estimate that under-reports them.
`pendulum/` gained an exact elliptic-integral period check valid at any
amplitude (not just the small-angle approximation), and a
chaos-sensitivity check for the double pendulum that discovered the
app's own 120° default doesn't reliably show strong chaos within a
reasonable integration time — the check now uses an independently
verified 130° instead. `magnetic/`'s existing per-mode check structure
was confirmed to already be the right design (a drift-velocity check
genuinely doesn't mean anything during mirror mode) and is now
documented as deliberate rather than looking like a gap.

---

## What comes next

Feedback from an early listener flagged several things worth a proper
pass rather than a quick patch: one app whose sonification is quiet
enough to sound broken rather than merely subtle, an animation/audio
tempo mismatch worth investigating across the apps that have both, and
an inconsistency in whether spoken narration is embedded in a sound
file or kept separate when a file bundles multiple sonifications. All
three are real, all three deserve real attention, and none of them made
it into this release on purpose — they're next.

A few more app ideas are still on the shelf: `nbody/` (genuinely
chaotic N-body gravity), `diffraction/` (the double-slit experiment,
probably the single best high-school hook left in the backlog), and a
few others in `docs/V1.5.0_APP_IDEAS.md`'s "not yet built" section.

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

**2. The demo — all thirty-two apps in one run**

```sh
wolframscript -file demo.wl
```

Runs all thirty-two apps in sequence (measured: 33/33 runs — 32 unique
apps, `dynamical/` demonstrates two modes — including live asteroid
data), collects every output into `demo/`, and writes
`demo/demo-report.md` with per-app runtimes and PASS/FAIL status.
Follow the listening guide in `demo/README.md` for the recommended
order, or open `demo/demo.html` in a browser for the same tour with
inline audio players.

**3. The crown jewel for v1.5.0 — angles nobody handed us**

```sh
wolframscript -file bell/main.wl -- --simulation.mode=chsh
afplay bell/output/chsh_audio.wav
```

Two entangled qubits, measured at four angles chosen not because a
textbook says so, but because this app derives them: an actual
optimization over the correlation formula, verified afterward to reach
2.828..., exactly 2√2 — the same number Alain Aspect measured in a real
laboratory in the early 1980s, the number no theory where particles
carry their own hidden, predetermined answers can ever exceed. Compare
it against the naive-looking angle choice a few centimetres away in the
same file, which gives exactly 2 — the classical ceiling, and no
higher. Bell showed in 1964 that this was a question physics could
actually answer. Nature answered it. Clauser, Aspect, and Zeilinger
shared a Nobel Prize for confirming that in the lab, in 2022, some forty
years after Aspect's own first measurement — and fifty-eight years after
Bell wrote the inequality down.

---

## Acknowledgements

This project was developed with [Claude Code](https://claude.ai/claude-code)
(Anthropic), including this release's correctness audit, which was
conducted as a dedicated review pass independent of each app's original
build session — every formula re-derived or independently re-verified,
not re-read. No new external data sources were introduced this release;
`asteroids/` continues to use NASA's NeoWs and the JPL Small Body
Database API, and `cosmology/`'s `--simulation.cosmology.source=planck`
mode continues to fetch from the Planck Legacy Archive. MINT Access is
a Swiss organisation and the go-to partner for universities, publishers,
and companies serving the university sector that want to make their
STEM teaching and research more accessible — website at
[mintaccess.ch](https://www.mintaccess.ch/) (German).

# Hydrogen Atom — Agent Guide

## Project overview

Sonifies the quantum mechanics of the hydrogen atom — the only
exactly-solvable atom, and the foundation of all atomic physics and
spectroscopy. Three modes:

| Mode | What it sonifies | Traversal / structure |
|------|-------------------|------------------------|
| `orbitals` (default) | \|psi_nlm\|^2 on a 2D xz cross-section | Hilbert curve (stem-core) |
| `spectrum` | Full n=2..n_max emission spectrum | Chord, then a UV->IR sweep |
| `transitions` | n_realizations random electron cascades | Grotrian energy-level diagram |

Closest sibling apps: `quantum/` (1D wave-packet time evolution — this
app is spatial/spectroscopic instead, no time evolution) and `images/`
(the Hilbert-traversal sonification approach that `orbitals` mode reuses
directly, applied to a wave function instead of a photograph).

Atomic units throughout for wave functions (a0 = hbar = m_e = e = 1);
eV/nm/Hz/s for energy levels and spectroscopy, matching how these
numbers are actually quoted in atomic physics and astronomy.

## Project structure

```
hydrogen/
  main.wl              -- entry point; mode branching; per-mode pipeline
  config.json          -- app defaults (mode, hydrogen sub-config)
  experiments.wl         -- 10 curated preset invocations
  LISTENING_GUIDE.md     -- user-facing listening order and physics notes
  AGENTS.md              -- this file
  src/
    model.wl            -- physics: energy levels, wave functions, Einstein A,
                           spectral lines, cascade simulation, correctness checks
    sonify.wl            -- audio synthesis for all three modes
    speech.wl            -- BuildIntroText/BuildIntroBuffer (SpeechSynthesize[] ->
                           platform TTS -> text-only fallback)
    animate.wl            -- GIF/PNG rendering for all three modes
    output.wl             -- CSV export + PASS/FAIL correctness-check printing
  tests/
    test_model.wl        -- unit tests for model.wl
  output/                -- generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                          # orbitals, 2p (210)
wolframscript -file main.wl -- --simulation.hydrogen.orbital=100     # 1s orbital
wolframscript -file main.wl -- --simulation.hydrogen.orbital=320     # 3d_z^2 orbital
wolframscript -file main.wl -- --simulation.hydrogen.orbital=321     # 3d clover orbital
wolframscript -file main.wl -- --simulation.mode=spectrum            # full emission spectrum
wolframscript -file main.wl -- --simulation.mode=transitions         # cascade from n=5
wolframscript -file main.wl -- --simulation.hydrogen.n_start=7       # cascade from n=7
wolframscript -file main.wl -- --simulation.hydrogen.n_realizations=5
wolframscript -file main.wl -- --config-dump
wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Data flow

```
config -> ComputeOrbitalTraversal / BuildSpectrumAudio / SimulateCascade x n_realizations
            |                          |                       |
     orbitalModel               spectrumResult          cascadesList
   {density,traversal,             {lines,               (list of lists
    densityFlat,...}            audioFreqs,amps,           of transition
            |                    chordBuf,sweepBuf}           steps)
     SonifyOrbitals                    |                       |
            |                    AnimateSpectrum          SonifyCascades
     AnimateOrbital                    |                       |
            |                    ExportSpectrumCSV        AnimateTransitions
     ExportOrbitalsCSV                                          |
                                                          ExportTransitionsCSV
```

Every mode also calls `BuildIntroBuffer` (speech.wl) to prepend a spoken
orientation sentence to its main WAV, following the same
intro-then-pause-then-audio pattern used in `thermo/`, `montecarlo/`,
and `images/`. `spectrum` mode additionally appends a spoken **outro**
after the sweep (the only mode that does; see main.wl's `[3/5]` step) —
there was no existing outro pattern anywhere else in the codebase, so
`BuildSpectrumOutroText[]`/reusing `BuildIntroBuffer` for the outro text
is this app's own addition.

## Physics notes

### Wave functions: no built-in `HydrogenWavefunction[]`

`Quiet[Check[HydrogenWavefunction[1,0,0,{0,0,0.1}], $Failed]]` returns
the call **unevaluated** (not `$Failed`) on this Wolfram Engine install
— it is simply not a built-in symbol here. `model.wl` implements the
wave function directly instead:

```
HydrogenRadialR[n,l,r] = Sqrt[(2/n)^3 (n-l-1)!/(2n(n+l)!)] *
  Exp[-r/n] * (2r/n)^l * LaguerreL[n-l-1, 2l+1, 2r/n]
HydrogenPsi[n,l,m,r,theta,phi] = HydrogenRadialR[n,l,r] * SphericalHarmonicY[l,m,theta,phi]
```

`SphericalHarmonicY` and `LaguerreL` **are** available and used directly.
Verified numerically (not just by formula lookup) that `HydrogenRadialR`
normalises to 1 (`Integrate[R^2 r^2, {r,0,Infinity}] = 1`) for several
`(n,l)` pairs — see `tests/test_model.wl`.

### The 3d "clover" orbital: sum vs. difference

The task spec that inspired this app describes the `"321"` orbital as
the real combination `(psi_{3,2,1} + psi_{3,2,-1})/Sqrt[2]`. **This sum
is identically zero everywhere in the xz cross-section this app
sonifies** (verified numerically): `Y_l^m + Y_l^{-m}` is proportional to
`Sin[m*phi]` for odd m, which vanishes at `phi = 0` and `phi = Pi` — the
only two phi values that occur in the y=0 plane. That combination is
the real **d_yz** orbital, which by construction is zero wherever y=0.

`model.wl`'s `OrbitalPointDensity` uses the **difference** instead,
`(psi_{n,l,m} - psi_{n,l,-m})/Sqrt[2]` — the real **d_xz** orbital,
which is non-zero in the xz-plane and produces the actual four-lobe
clover pattern. Both combinations have identical 3D normalisation (the
cross term between different m states integrates to zero over phi
either way); only the choice of which one is visible in *this*
particular cross-section differs. If you ever add an orbital mode that
samples a different plane (e.g. y=0 replaced by a plane through an
arbitrary phi), re-derive which combination is non-zero there before
reusing this code — it is plane-specific, not a general fact about
"the m=+-1 combination."

### Einstein A coefficients: hard-coded Balmer + an approximation elsewhere

Four literal values (`$BalmerA` in model.wl) for Halpha/Hbeta/Hgamma/Hdelta
(n=3,4,5,6 -> n=2). Every other `(n_upper, n_lower)` pair — every other
series, and every cascade transition not landing on n_lower=2 with
n_upper in {3,4,5,6} — falls back to `A ~ (deltaE)^3 / n_upper^3`,
scaled by `$AApproxScale = 2.77*^7` (chosen as the geometric mean of
`A_actual/A_formula` across the four known Balmer points, so the
approximation's overall scale is a reasonable middle ground rather than
overfit to either end of the Balmer series). This is explicitly an
approximation "for sonification purposes" per the spec, not a matrix-
element calculation — don't read scientific precision into the
non-Balmer numbers.

### Cascade transition probabilities: `$CascadeSoftPower`

Raw Einstein-A ratios between competing transitions from a given state
span 2-4 orders of magnitude (e.g. from `{5,2}`: `A{2,1}` (hard-coded
Balmer, 2.53e6) vs. `A{4,1}`/`A{4,3}` (generic formula, ~6e3) — a
~400:1 ratio). Weighting `SimulateCascade`'s branch selection by raw A
made cascades from the default start state **deterministic**: all 20
realisations took the identical `{5,2}->{2,1}->{1,0}` path (verified —
see git history / this file's derivation notes if you need to
reproduce the calculation). That defeats the entire premise of
"20 different quantum melodies."

The fix: weight by `A^$CascadeSoftPower` with `$CascadeSoftPower = 0.3`,
compressing the dynamic range while still favouring brighter transitions
on average. Empirically this gives the dominant branch from `{5,2}` a
~55% share (vs. ~92% at power=1, or a flat ~25% as power->0), which
produces genuinely varied path lengths and branches across 20
realisations while still usually favouring the brightest transition —
matching the LISTENING_GUIDE's "notice which notes appear in most
realisations... and which are rare." If you change `n_start`/`l_start`
defaults, re-run a quick diversity check (`Table[Length[SimulateCascade[...]], {20}]`
across a few seeds) before assuming the default power still gives good
variety — the amount of skew depends on which specific Balmer-vs-generic
comparison the start state's first step makes.

### The 2s trap: metastable state exclusion

The 2s state (`{2,0}`) cannot decay to 1s (`{1,0}`) via any allowed
E1 (`Delta l = +-1`) transition — real hydrogen atoms that land in 2s
are famously metastable, decaying only via a much slower two-photon
process this app does not model. Left unhandled, a cascade landing in
`{2,0}` would have **zero** allowed further transitions
(`AllowedTransitionsFrom[2,0] === {}`) and get permanently stuck,
breaking the "every cascade reaches the ground state" guarantee that
`transitions_audio.wav`'s narration promises.

`AllowedTransitionsFrom` therefore excludes `{2,0}` as a candidate
**target** state everywhere (not just when it would be a dead end) —
see the comment at its definition in `model.wl`. This is a deliberate,
documented physics simplification (this cascade only models E1
transitions), not an oversight; see LISTENING_GUIDE.md's "Quantum
randomness in the cascade" section for the user-facing explanation.

### Correctness-check tolerances: why 0.1%, not 0.01%

The app's energy-level formula uses the infinite-nuclear-mass Rydberg
constant (13.6057 eV, as specified), while the textbook reference
wavelengths (656.279 nm for H-alpha, 121.567 nm for Lyman-alpha) are the
real, reduced-mass-and-air-refraction values. The mismatch this
introduces is a fixed ~0.025% (H-alpha) to ~0.05% (Lyman-alpha) —
dominated by the electron/proton reduced-mass correction (~1/1836) —
and does **not** shrink even using full-precision CODATA constants
(verified: swapping in `h = 4.135667696e-15`, full-precision Rydberg
energy, etc. changes the computed wavelength by <1e-6%). A 0.01%
tolerance is therefore unachievable with the formula as specified; all
wavelength-precision checks in this app (`RydbergCheck`, the two
wavelength unit tests) use 0.1% instead.

### Wave function normalisation check: two cutoffs, not one

`WaveFunctionNormalizationCheck` uses **two different** radial cutoffs
for its two sub-checks, and this is intentional, not an inconsistency:

- The grid-vs-continuum 2D check (part b) uses the **actual**
  sonification `rMax = 3n^2` — it is validating that the discretised
  grid correctly reproduces its own continuous integral, so it must use
  the same domain the app actually sonifies.
- The full-3D-normalises-to-1 check (part a) uses a wider
  `rMaxCheck = Max[3n^2, 8n]` — because for n=1, `3n^2 = 3` Bohr radii
  only encloses ~94% of \|1s\|^2's total probability (the exponential
  tail is not yet negligible that close in), while for n>=2 it is
  generous enough. Using the sonification's own (tight for n=1) `rMax`
  for this check would make it fail for the 1s orbital specifically —
  not because anything is wrong with the wave function, but because 6%
  of a legitimately normalised wave function's probability just lives
  outside a 3-Bohr-radius box. `rMaxCheck` exists to separate "is the
  formula normalised" from "how much of the tail happens to fit in the
  box we chose to sonify."

## Common pitfalls

1. **CLI numeric coercion on the orbital key.** `ParseCliOverrides`
   (stem-core/config.wl) turns any numeric-looking CLI value into an
   actual number — `--simulation.hydrogen.orbital=100` arrives at
   `GetCfg` as the **Integer** `100`, not the **String** `"100"`. Since
   `$Orbitals`'s keys are strings, a naive `KeyExistsQ[$Orbitals,
   orbitalKeyCfg]` silently fails and falls back to the default every
   time — this was an actual bug caught while building this app (every
   `--orbital=` override was silently ignored). The fix in `main.wl` is
   `ToString[GetCfg[...]]` before the lookup, which normalises both the
   CLI-Integer and the config.json-String cases. If you add another
   string-valued config key that CLI users are likely to pass numeric-
   looking values for, apply the same `ToString` guard.

2. **Don't reassign a `With`-bound variable.** An earlier draft of
   `main.wl`'s orbitals branch wrote
   `With[{orbitalKey = GetCfg[...]}, orbitalKey = If[...]; ...]` —
   `With` bindings are substituted as literal constants, not mutable
   symbols, so the reassignment is a `Set::wrsym`-class error. The
   orbitals branch now uses plain top-level assignments instead of
   `With` for exactly this reason (the spectrum and transitions
   branches don't reassign their `With`-bound config variables, so they
   keep the `With` wrapper safely).

3. **`Riffle[list, seps]` with `Length[seps] = Length[list]-1`** is
   the correct, built-in way to interleave a pause buffer between N
   audio chunks — `sonify.wl`'s `SonifyCascades` uses this to place a
   0.3s silence between realisations without a manual loop.

4. **Density spans many orders of magnitude.** Both the orbitals'
   pitch/amplitude mapping and the animation's colour mapping use a
   *log*-compressed density (thresholded at `1e-6 * max` to define
   "node = silence"), not a linear one — a linear map would show/sound
   like almost nothing but a single bright point, since \|psi\|^2 falls
   off very steeply away from its peak.

## GIF/WAV duration sync (fixed post-v1.5.0)

**The bug.** All three modes' GIFs played far shorter than their
matching WAVs: `orbitals.gif` measured 3.2s vs `orbitals_audio.wav`
105.6s (33x!), `spectrum.gif` 3.92s vs `spectrum_audio.wav` 43.96s
(11.2x), `transitions.gif` 6.0s vs `transitions_audio.wav` 54.87s
(9.1x).

**Root cause.** `AnimateOrbital`/`AnimateSpectrum`/`AnimateTransitions`
each exported at a fixed frame rate (10/`Max[2,nLines/4]`/2 fps
respectively) with a frame count tied only to the number of discrete
simulated states (32 fixed frames for orbitals; one frame per spectral
line for spectrum; one frame per cascade step, capped at 4
realisations, for transitions) — the same fixed-nFrames/fixed-frameRate
pattern found repo-wide, decoupled from how long the matching WAV
actually plays. All three WAVs also carry a spoken intro baked directly
into the audio buffer (`BuildIntroBuffer` in `speech.wl`, prepended in
`main.wl`) whose length depends on the platform TTS engine and isn't
known ahead of time — for orbitals mode this, plus a long note-per-pixel
buffer (4096 pixels x 0.02s), is what drives the 33x gap.

**The fix.** Each `Animate*` now takes a `targetDuration` argument and
solves `frameRate` from a frame-count *budget* (150) divided by
`targetDuration`, clamped to `[$HydrogenMinGifFps, $HydrogenMaxGifFps]`
(2-30 fps), with the frame count recomputed at the clamp boundary so
playback duration lands almost exactly on `targetDuration` — same
reasoning as `lorenz/src/animate.wl`'s `ExportAnimation`. Spectrum and
transitions modes have far fewer distinct visual states (spectral
lines / cascade steps) than the 150-frame budget; `Subdivide`'s
rounding holds a state across several consecutive frames rather than
erroring, the same way `fluid/AnimateStrouhal` and `grover/AnimateSearch`
handle it. `main.wl` already built each mode's full WAV (including its
spoken intro) *before* calling the matching `Animate*`, so no
call-site reordering was needed — the WAV's actual total sample count
`/ sr` is just threaded through as `targetDuration`. `experiments.wl`'s
per-orbital and per-cascade helpers needed the same value threaded
through; its `spectrum_full` block has no single narrated WAV (only
separate chord/sweep files, no intro), so its GIF targets chord+sweep
duration back to back — the actual listening length of that
experiment's two WAVs.

**Verification (regenerated via `wolframscript -file main.wl` for all
three modes, plus 4 experiment presets via `experiments.wl`):**

| Output | GIF before | WAV | GIF after | Ratio after |
|--------|-----------|-----|-----------|-------------|
| orbitals | 3.2s | 105.6s | 105.5s | 1.00x |
| spectrum | 3.92s | 43.96s | 43.5s | 0.99x |
| transitions | 6.0s | 53.59s* | 54.0s | 1.01x |
| orbital_1s (preset) | — | 20.48s | 21.0s | 1.03x |
| orbital_2p (preset) | — | 81.92s | 82.0s | 1.00x |
| cascade_default (preset) | — | 37.7s | 37.5s | 0.99x |
| cascade_high (preset) | — | 29.42s | 30.0s | 1.02x |

*transitions mode simulates random cascades on every run (no fixed
seed in `main.wl`), so the "before" and "after" WAV durations differ
slightly run to run; the sync ratio is what matters and holds regardless.

`tests/test_model.wl` (23/23 tests, unaffected by this change) still
passes.

## Dependencies

- Mathematica or Wolfram Engine (any recent version with
  `SphericalHarmonicY`, `LaguerreL`; `HydrogenWavefunction` is **not**
  required/available and is not used)
- `stem-core` (sibling `../stem-core`) — `HilbertTraversalOrder`,
  `SonifyTrajectory` (not used by this app; bespoke synthesis instead,
  same pattern as `images/`/`thermo/`), `StemSynthNote`,
  `NormalizeBuffer`, `ExportAudioBuffer`, `ExportGIF`, `ExportCSV`,
  `EnsureDir`, `STEMHeading`, `STEMSection`, `STEMPrintN`,
  `STEMDescribeCSV/WAV/GIF`, `STEMSay`, `FmtN`, `GetCfg`, `DeepMerge`,
  `LoadConfig`
- No external paclets required

# Grover — Agent Guide

## Project overview

Sonifies Grover's search algorithm: the optimal-stopping search curve,
a binaural classical-vs-quantum speedup race, and the algorithm's
literal 2D rotation geometry. The third app in this project's
quantum-computing batch, completing what [`qubit/`](../qubit/AGENTS.md)
and [`bell/`](../bell/AGENTS.md) started. Three modes:

| Mode | Physics | Output |
|------|---------|--------|
| `search` (default) | `P(marked)=Sin[(2k+1)*theta]^2`, rise then fall past the optimum | Discrete per-iteration notes, accent at the optimum; curve GIF/PNG |
| `compare` | Classical `N/2` vs quantum `~(Pi/4)*Sqrt[N]` query counts | Binaural race WAV; growing-gap GIF/PNG across N |
| `geometry` | The literal 2*theta-per-iteration rotation in a 2D subspace | Continuous pan/pitch rotation; 2D unit-circle GIF/PNG |

Closest sibling apps: `qubit/` (the same unitary-operator conventions,
extended from a single `2x2` gate to full `NxN` oracle/diffusion
operators) and `bell/` (the same "derive the geometry/angle from
scratch, verify independently, don't trust a remembered constant"
discipline this app's own build brief explicitly demanded, given the
`k_opt` formula and `Sqrt[N]` approximation are exactly the kind of
number this project's correctness audit has repeatedly caught being
wrong when merely recalled).

## Key design decisions (read before modifying sonify.wl or model.wl)

### 1. The rotation-by-2theta claim — derived via explicit matrix construction, not asserted from the standard "two reflections compose to a rotation" argument

The geometric argument ("two reflections compose to a rotation by
twice the angle between the mirror lines") is a clean, standard piece
of plane geometry, but this app does not merely cite it — it was
verified directly against the actual oracle/diffusion/Grover matrices
this app defines:

1. Built `oracleOp = I - 2|w><w|`, `diffusionOp = 2|s><s| - I`,
   `groverOp = diffusionOp . oracleOp` as explicit `NxN` real matrices
   (`GroverOperators`).
2. Verified all three unitary (`O^T O = I`) for several `N` — this is
   also correctness check 3.
3. Built the orthonormal 2D basis `{|w>, |s'>}` explicitly (`|s'>` is
   `|s>`'s component orthogonal to `|w>`, normalised), and computed
   `groverOp` restricted to this basis (`basis[[i]] . groverOp . basis[[j]]`).
4. Compared this restricted `2x2` matrix directly against
   `RotationMatrix[-2*theta]` (the sign/orientation is a basis
   convention discovered empirically by comparing both `RotationMatrix[2*theta]`
   and `RotationMatrix[-2*theta]` against the computed matrix, not
   assumed in advance) — agreement to machine precision
   (`~6.7e-16`) for `N=16`.
5. Independently confirmed the angle interpretation by tracking the
   actual state vector through repeated applications of `groverOp`,
   projecting onto `{|w>,|s'>}`, and measuring
   `ArcTan[component_sPrime, component_w]` at each step — this angle
   advances by exactly `(2k+1)*theta`, matching the closed form to
   machine precision at every `k` tested (transcript below).

Verification transcript (N=16, marked index 7):

```
k=0  angle from |w> axis = 0.252680  expected (2k+1)*theta = 0.252680  diff=1.1e-16
k=1  angle from |w> axis = 0.758041  expected (2k+1)*theta = 0.758041  diff=1.1e-16
k=2  angle from |w> axis = 1.263401  expected (2k+1)*theta = 1.263401  diff=2.2e-16
k=3  angle from |w> axis = 1.768762  expected (2k+1)*theta = 1.768762  diff=0.0
k=4  angle from |w> axis = 2.274122  expected (2k+1)*theta = 2.274122  diff=4.4e-16
k=5  angle from |w> axis = 2.779483  expected (2k+1)*theta = 2.779483  diff=0.0
```

### 2. Classical comparison framing: average-case N/2, not worst-case N

`compare` mode's classical channel uses `N/2` (average-case linear
search), not `N` (worst case). Reasoning: the quantum count being
compared against (`k_opt`, from `Round[Pi/(4*theta)-1/2]`) is itself
an *exact optimum* — the best Grover can do, not a worst case. Pairing
an exact quantum optimum against a classical *worst* case would
overstate the speedup with an apples-to-oranges comparison; pairing it
against classical's own *average* case (the expected number of
queries a linear search needs, given the marked item's position is
uniformly unknown) is the honest, matched comparison — both sides are
"typical/expected performance," not "best case vs worst case" or
"worst case vs worst case" (Grover has no meaningful worst case at a
fixed iteration count — it is deterministic given `k`). The gap is
still enormous (`~5x` at `N=64`, growing without bound as `N` grows)
even using classical's more favourable average-case framing, so this
choice does not understate the speedup either — it is the fairer
number, not a more dramatic one.

### 3. GroverOptimalK vs GroverOptimalKBySimulation — a genuinely discovered edge case at small N, and why the check's search window matters

`GroverOptimalK` returns the `k` nearest the FIRST peak of
`P(marked)`, per the standard meaning of "optimal number of
iterations": fewer queries is the entire point of the speedup, so even
if a *later* peak happened to be numerically higher, stopping there
would defeat the purpose. This distinction is not academic — it was
discovered empirically while building `GroverOptimalKBySimulation`
(the correctness check's independent verification path):

An initial, naively-large search window for the argmax
(`kMax = Max[20, Round[2*Pi/(4*theta)]]`, intended to search "well past
the optimum" per the build brief) found, for `N=8`: `k=6` giving
`P(marked)=0.99989`, HIGHER than `k=2`'s `P(marked)=0.94531` — the
formula's own intended answer. This is real: at `N=8`,
`theta=20.7deg`, so `(2k+1)*theta` at `k=2` is `103.5deg` (`13.5deg`
past the ideal `90deg` peak), while at `k=6` it is `269.2deg`
(`0.8deg` past `270deg`, the SECOND peak of `Sin[]^2`, which happens
to land closer to its own target on this N's particular discrete
`k`-grid). Both are real local maxima of the same formula; `k=6` is
simply not the *intended* "optimal number of iterations" — it costs 3x
more queries for a probability advantage of `0.0546`, a bad trade by
the actual metric that matters (fewest queries).

**Fix**: `GroverOptimalKBySimulation`'s search window is sized from
the OSCILLATION PERIOD (`Floor[Pi/(4*theta)] + 2`, derived from
`Sin[]^2`'s period being `Pi` in its argument, i.e. `Pi/(2*theta)`
steps in `k` for a full cycle — using HALF that period plus a small
buffer keeps the search safely within the region where the first peak
is still the unique maximum), not from `GroverOptimalK`'s own point
formula. This is a genuinely different construction (period-based, not
point-based) even though the two are obviously related mathematically
— confirmed to agree with `GroverOptimalK` exactly for
`N in {4,8,16,32,64,128,256,1024,4096,65536,1048576}` with this
windowing, where the naive wide window failed at `N=8` and `N=16`.

### 4. N=2 is a fully degenerate special case — discovered, not assumed, and deliberately excluded from the correctness check's test list

At `N=2`, `Sin[theta]=1/Sqrt[2]`, so `theta=45deg` exactly — the
symmetric fixed point of the whole construction. Direct computation:
`Sin[(2k+1)*45deg]^2 = 0.5` for EVERY integer `k` (`{0.5, 0.5, 0.5,
0.5, 0.5, ...}` for `k=0..5`, verified to `~1e-16`). Iterating never
helps at `N=2` — there is no "optimal" number of iterations in any
meaningful sense (every `k` is equally, exactly as good as `k=0`, i.e.
not iterating at all). `OptimalIterationCountCheck`'s test list
starts at `N=4`, not `N=2`, specifically because of this: the
formula's point estimate and any simulated-argmax search both remain
technically well-defined at `N=2`, but comparing them there tests
nothing meaningful (an all-ties list's "argmax" is an artifact of
floating-point noise, not a real optimum) — this is documented here
rather than silently worked around, and `tests/test_model.wl` has its
own explicit test confirming the `N=2` degeneracy directly.

### 5. compare mode's audio tick interval is auto-scaled, not fixed — discovered while building the curated experiments

An initial fixed tick interval (`0.12s` per classical tick, regardless
of `N`) produced a **4-minute-plus WAV** for a `compare_large_n`
experiment at `N=4096` (`2048` classical ticks × `0.12s` = `246s`).
`BuildCompareAudio`'s `tickInterval` is now derived from a target total
classical duration (`Clip[targetDuration/nClassical, {0.02, 0.15}]`):
comfortable, clearly-discrete spacing at small `N`, shrinking toward a
`0.02s` floor (a denser "buzz," itself an honest illustration of "so
many queries needed") at large `N`, rather than letting duration grow
without bound. The curated `compare_large_n` experiment itself was
also tuned down from `N=4096` to `N=512` (`256` classical queries,
`~15x` speedup, `~6s` of classical ticks) to keep a *curated* example
actually short enough to listen to, independent of the general
auto-scaling fix.

### 6. geometry mode sonifies a CONTINUOUS extension of an inherently discrete process — the same choice qubit/gates makes, for the same reason

Grover iterations are discrete integer steps; there is no physical
sense in which the state rotates "partway" between iteration `k` and
`k+1`. `geometry` mode nonetheless sonifies (and animates, via the GIF)
a smooth continuous rotation, linearly interpolating the iteration
index itself — because the underlying mechanism genuinely IS a
constant-rate rotation (exactly `2*theta` per step, always), so
representing it continuously is a faithful visualisation of the
mechanism, not an invented smoothing. This is the same choice
`qubit/gates` makes for its own gate-to-gate Bloch-sphere rotations
(`GateRotationPath`), reused here for an analogous reason.

## Numeric findings from this build session (new results, not assumed in advance)

Optimal iteration count, exact formula vs. the common `(Pi/4)*Sqrt[N]`
approximation, for several `N`:

| N | theta (deg) | k_opt (exact) | (Pi/4)*Sqrt[N] | round() | error |
|---|---|---|---|---|---|
| 4 | 30.000 | 1 | 1.571 | 2 | +1 |
| 8 | 20.705 | 2 | 2.221 | 2 | 0 |
| 16 | 14.478 | 3 | 3.142 | 3 | 0 |
| 32 | 10.182 | 4 | 4.443 | 4 | 0 |
| 64 | 7.181 | 6 | 6.283 | 6 | 0 |
| 128 | 5.071 | 8 | 8.886 | 9 | +1 |
| 256 | 3.583 | 12 | 12.566 | 13 | +1 |
| 1024 | 1.791 | 25 | 25.133 | 25 | 0 |
| 4096 | 0.895 | 50 | 50.265 | 50 | 0 |
| 65536 | 0.224 | 201 | 201.062 | 201 | 0 |
| 1048576 | 0.056 | 804 | 804.248 | 804 | 0 |

The approximation is accurate to within `+-1` across every `N` tested
here, including quite small `N` — worse in *relative* terms at small
`N` (an error of `1` matters more when `k_opt` itself is `1` or `8`
than when it is `804`), exactly as expected since the approximation
`Sin[theta]~=theta` (used to get from the exact `Pi/(4*theta)-1/2` to
the `Sqrt[N]`-only form) degrades as `theta` grows for small `N`.

## Project structure

```
grover/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json            — default simulation parameters
  experiments.wl          — 7 curated preset invocations
  LISTENING_GUIDE.md       — user-facing recommended listening sequence
  AGENTS.md                 — this file
  src/
    model.wl                 — Oracle/diffusion/Grover operators (explicit
                          NxN matrices), closed-form probability, exact +
                          independently-simulated optimal-k, four
                          correctness checks, three per-mode model builders
    sonify.wl                  — search's discrete per-iteration notes,
                          compare's auto-scaled binaural race, geometry's
                          phase-accumulated continuous rotation
    speech.wl                    — Spoken intro synthesis and per-mode intro text
    animate.wl                     — P(marked) curve with optimum marked
                          (search), log-log growing-gap chart (compare),
                          2D unit-circle rotation diagram (geometry)
    output.wl                      — CSV export and console summaries
  tests/
    test_model.wl                 — Unit tests (operators, closed form vs
                          simulation, optimal-k incl. N=2 degeneracy,
                          sqrt(N) approximation, all four correctness
                          checks, model builders)
  output/                           — generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                    # search, N=64, rise then fall
wolframscript -file main.wl -- --simulation.mode=compare         # binaural classical vs quantum race
wolframscript -file main.wl -- --simulation.mode=geometry        # continuous 2D rotation
wolframscript -file main.wl -- --simulation.grover.n_items=1024  # larger N
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks

All four run unconditionally, every invocation, regardless of mode,
always at fixed canonical parameters (independent of the active
mode's own configured `N`):

1. **Rotation angle** — see design decision 1. Exact relation, tight
   tolerance.
2. **Optimal iteration count** — see design decision 3. Exact match
   across eight different `N` values.
3. **Operator unitarity** — oracle, diffusion, and `G`, all `O^T O=I`.
   Exact, tight tolerance.
4. **Closed form vs direct simulation** — see the module header in
   `model.wl`. Exact relation, tight tolerance, across five `(N,k)`
   combinations.

## Common pitfalls

1. **A wide/naive search window for "the argmax of P(marked)" can find
   the WRONG peak** — see design decision 3. `Sin[]^2` is periodic;
   searching too far past the intended optimum can land on a
   numerically-higher LATER peak that is not the intended answer.
   Always size such a search window from the oscillation's own period,
   not an arbitrary large constant.
2. **N=2 is fully degenerate** — see design decision 4. Don't use it
   as a "small N" test case for anything optimal-k-related; every `k`
   gives exactly the same probability.
3. **A fixed audio tick/note interval does not scale to large N** —
   see design decision 5. Any per-item or per-query discrete-event
   sonification in this app auto-scales its interval from a target
   total duration, not a hardcoded constant.
4. **`FmtN[x, N]` with a small integer `N` breaks on multi-digit
   values** — the same `NumberForm::reqsigz` pitfall documented in
   `bell/AGENTS.md` and `pendulum/AGENTS.md`. Avoided throughout
   `output.wl` by using fixed-decimal specs (e.g. `{8,1}`) for values
   that can span a wide magnitude range (query counts from single
   digits up to hundreds of thousands).
5. **`tolerance_?NumericQ:0.05`-style optional-argument patterns parse
   WRONG** in WL — binds as `tolerance_ ? (NumericQ:0.05)`, not
   `Optional[tolerance_?NumericQ, 0.05]`. Same pitfall documented in
   every prior v1.5.0 app's `AGENTS.md`; avoided throughout via
   explicit `Optional[x_?NumericQ, default]`.

## GIF/WAV duration sync (fixed post-v1.5.0)

**The bug.** All three modes' GIFs played far shorter than their
matching WAVs: `grover_search.gif` measured 3.25s vs `grover_search.wav`
18.67s (5.7x), `grover_compare.gif` 3.2s vs 21.25s (6.6x),
`grover_geometry.gif` 4.29s vs 26.69s (6.2x).

**Root cause.** `AnimateSearch`/`AnimateCompare`/`AnimateGeometry`
exported at a fixed frame rate (4/12/3 fps respectively) with a frame
count tied only to the number of discrete simulation steps or sweep
points — the same fixed-nFrames/fixed-frameRate pattern found across
the repo, decoupled from how long the matching sonification actually
plays. As in `fluid/`, the WAV also carries a spoken intro
(`BuildIntroBuffer` in `speech.wl`) prepended directly into the audio
buffer in `main.wl`/`experiments.wl`, whose length depends on the
platform TTS engine and isn't known ahead of time.

**The fix.** Each `Animate*` now takes a `targetDuration` argument and
solves `frameRate` from a frame-count *budget* (150) divided by
`targetDuration`, clamped to `[$GroverMinGifFps, $GroverMaxGifFps]`
(2-30 fps), with the frame count recomputed at the clamp boundary so
playback duration lands almost exactly on `targetDuration` — same
reasoning as `lorenz/src/animate.wl`'s `ExportAnimation`. Search and
geometry modes have far fewer distinct visual states (Grover iterations,
often ~10-15) than the 150-frame budget; `Subdivide`'s rounding holds
each state across several consecutive frames rather than erroring, the
same way `AnimateStrouhal` handles it in `fluid/`. Because the true
duration is only known once the intro speech is synthesised,
`main.wl` was reordered to build the WAV (steps renumbered 4→5) *before*
rendering the GIF (5→4) for all three modes, passing the WAV's actual
total sample count `/ sr` straight through as `targetDuration`;
`experiments.wl` already built audio before animating and only needed
the same value threaded into its `Animate*` calls.

**Verification (regenerated via `wolframscript -file main.wl` for all
three modes):**

| Mode | GIF before | WAV | GIF after | Ratio after |
|------|-----------|-----|-----------|-------------|
| search | 3.25s | 18.67s | 18.00s | 0.96x |
| compare | 3.2s | 21.25s | 21.00s | 0.99x |
| geometry | 4.29s | 26.69s | 27.00s | 1.01x |

`tests/test_model.wl` (24/24 tests, unaffected by this change) still
passes.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `StemSynthNote` (search notes, compare ticks/chimes), `STEMHeading`,
  `STEMSection`, `STEMSay`, `STEMPrintN`, `STEMDescribeWAV`,
  `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`, `STEMPlayCmd`,
  `NormalizeBuffer`, `ExportGIF`, `ExportCSV`, `EnsureDir`.
- **Mathematica/WL**: `Outer`, `UnitVector`, `IdentityMatrix`
  (operator construction), `RotationMatrix` (rotation-angle
  verification), `Accumulate`/`Rescale` (phase-accumulation
  glissando), `Graphics`, `Arrow`, `Sound`, `SampledSoundList`,
  `Export`, `SpeechSynthesize`, `AudioQ`, `AudioData`,
  `AudioSampleRate`, `RunProcess` (platform TTS fallback), `Import`
  (reading TTS-generated WAV files).

## Speech synthesis note

`speech.wl`'s three-tier fallback (`SpeechSynthesize[]` -> platform TTS
-> text-only `STEMSay`) duplicates the pattern already used in
`qubit/src/speech.wl`, `bell/src/speech.wl`, and every other app's
`speech.wl` file — still out of scope for stem-core consolidation per
every prior app's own build spec.

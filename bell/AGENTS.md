# Bell — Agent Guide

## Project overview

Sonifies two entangled qubits: Bell correlations, the CHSH inequality,
and repeated Bell-state measurement. The second app in this project's
quantum-computing batch, building on [`qubit/`](../qubit/AGENTS.md)'s
Bloch-sphere and gate machinery; `grover/` is planned as a future third
member. Three modes:

| Mode | Physics | Output |
|------|---------|--------|
| `correlations` (default) | `E(a,b)=Cos[a-b]` swept over angle difference, vs. a genuine local hidden-variable prediction | Binaural WAV (classical left, quantum right); overlay GIF/PNG |
| `chsh` | The actual CHSH value `S` at the derived-optimal angles | Narrated build-up + binaural verdict WAV; gauge GIF/PNG |
| `measurement` | Many paired Born-rule measurements, joint Monte Carlo | Binaural click WAV + running-correlation glissando; convergence PNG |

Closest sibling apps: `qubit/` (the same measurement-operator and
Bloch-vector conventions, extended from one qubit to two — see design
decision 0), `compton/discovery` and `scattering/discovery` (the
binaural classical-vs-quantum idiom `correlations` mode reuses
directly), and `bayes/coin` (the evidence-accumulating structure
`measurement` mode shares conceptually, not technically).

## Key design decisions (read before modifying sonify.wl or model.wl)

### 0. State representation: two independent Pauli operators on a shared 4-dimensional state, not qubit/'s {alpha,beta} pair

`qubit/` represents a single qubit's state as `{alpha,beta}`, a
length-2 complex vector. A two-qubit entangled state lives in a
4-dimensional Hilbert space (`{|00>,|01>,|10>,|11>}`) that does NOT
factor into two independent 2-vectors — that is exactly what
"entangled" means. This app represents `|Phi+>` as a single length-4
complex vector and builds measurement operators via `KroneckerProduct`
on the two qubits' individual `2x2` Pauli operators, rather than
forcing `qubit/`'s single-qubit representation onto a fundamentally
two-qubit problem. `BellMeasurementOperator[theta]` — the single-qubit
piece, `Cos[theta]*PauliZ + Sin[theta]*PauliX` — is the one piece that
genuinely IS shared conceptually with `qubit/`'s own gate matrices
(both are single-qubit `2x2` operators), duplicated rather than
imported per this codebase's no-shared-src/ convention.

### 1. E(a,b) = Cos[a-b] — derived, not assumed, and verified two independent ways

The build spec explicitly warned that more than one sign/phase
convention circulates for Bell correlations (which Bell state, which
operator convention change `Cos` to `-Cos`, or `a-b` to `a+b`).
Verified before writing any downstream code:

- `E(a,b) = <Phi+| A(a) (x) A(b) |Phi+>` computed via
  `KroneckerProduct[BellMeasurementOperator[a], BellMeasurementOperator[b]]`
  sandwiched between `Conjugate[Phi]` and `Phi` (`Phi = {1,0,0,1}/Sqrt[2]`
  in the `{|00>,|01>,|10>,|11>}` basis), then `Simplify`'d symbolically.
  Result: `Cos[a-b]`, confirmed by directly checking
  `FullSimplify[symbolic - Cos[a-b]] === 0` (not just "looks like it").
- **Independent verification** (`QuantumCorrelationViaRotation`, used
  only by correctness check 2): diagonalise `A(a)` and `A(b)` via
  `Eigensystem` (NOT the `KroneckerProduct`-sandwich formula above —
  genuinely different code), build the unitary change-of-basis
  matrices `Ua, Ub` (eigenvectors as rows, `+1`-eigenvalue first),
  apply `KroneckerProduct[Ua,Ub]` to `Phi`, and recover `E(a,b)` from
  the resulting computational-basis outcome PROBABILITIES via the Born
  rule (`P++ - P+- - P-+ + P--`). Agreement with the closed form: to
  machine precision (`~1e-16`) at every angle tested — see the
  transcript below.
- **Joint probabilities**, used by `measurement` mode's Monte Carlo
  sampling: `P++ = P-- = (1+E)/4`, `P+- = P-+ = (1-E)/4`. This follows
  algebraically from `<A>=<B>=0` (verified — see design decision 3
  below) and `<AB>=E`, but was ALSO cross-checked directly against
  `QuantumCorrelationViaRotation`'s own rotated-probability output at
  several angles (not just trusted algebraically) before adopting it
  as `JointProbabilities`'s implementation.

Verification transcript (six random angle pairs, closed form vs.
independent rotation method):

```
a=4.354 b=0.464  cos(a-b)=-0.732861  independent=-0.732861  diff=1.1e-16
a=0.444 b=1.482  cos(a-b)= 0.507947  independent= 0.507947  diff=2.2e-16
a=0.213 b=4.092  cos(a-b)=-0.740608  independent=-0.740608  diff=1.1e-16
a=0.025 b=0.437  cos(a-b)= 0.916322  independent= 0.916322  diff=0.0
a=0.224 b=1.347  cos(a-b)= 0.433760  independent= 0.433760  diff=3.9e-16
a=0.606 b=1.127  cos(a-b)= 0.867447  independent= 0.867447  diff=1.1e-16
```

### 2. The CHSH-optimal angles — found by global numerical optimisation, confirmed exact symbolically, NOT recalled from memory

This is the single highest-risk unverified-constant point the build
spec flagged explicitly, and the exact kind of mistake this project's
own correctness-audit history has repeatedly caught (see e.g.
`henon/AGENTS.md`'s Jacobian check, `magnetic/AGENTS.md`'s frequency
check, `qubit/AGENTS.md`'s Rabi derivation — all independently
re-derived rather than trusted from training data).

**Process actually followed:**

1. `NMaximize[{S[a,ap,b,bp], 0<=a<2Pi, ...}, {a,ap,b,bp}, Method->"DifferentialEvolution"]`
   — a GLOBAL search over all four angles, not a local solver seeded
   near a remembered guess. Result: `Max S = 2.8284271247461903`,
   angles `(a,ap,b,bp) = (344.84, 74.84, 29.84, 119.84)` degrees.
2. Only the pairwise DIFFERENCES matter (`E(a,b)=Cos[a-b]` only
   depends on `a-b`), and those differences work out to exactly
   `{-45,-135,45,-45}` degrees. Fixing `b=0` WLOG (an overall rotation
   of the whole apparatus changes nothing physical) gives the
   canonical set `a=-45, a'=45, b=0, b'=90` degrees — the same
   solution up to that overall rotation.
3. **Symbolic confirmation**, not just numerical agreement:
   `Simplify[Cos[-Pi/4] - Cos[-Pi/4-Pi/2] + Cos[Pi/4] + Cos[Pi/4-Pi/2] - 2*Sqrt[2]] === 0`
   evaluates to `True` — the canonical angles give EXACTLY
   `2*Sqrt[2]`, not merely close to it.
4. **Global-max sanity check**: 200,000 random angle quadruples,
   maximum `S` found was `2.82808...`, strictly below `2*Sqrt[2]` —
   consistent with `(a,ap,b,bp)=(-45,45,0,90)` deg being the true
   maximum (Tsirelson's bound, provable independently via operator
   norms, though not re-derived here).
5. **Naive-angle contrast** (`ChshOptimalityCheck`'s second half): the
   "reasonable-looking" choice `a=0,a'=90,b=0,b'=90` (both parties
   measuring 90 degrees apart, no relative 45-degree offset) gives
   `S=2` EXACTLY — indistinguishable from the classical bound. This
   demonstrates the optimisation step in point 1 actually mattered,
   not just that a formula was copied down correctly.

### 3. Marginal statistics are exactly 0.5, independent of the other qubit's SETTING (no-signalling) — verified, and precisely worded

`JointProbabilities[a,b]["Ppp"] + JointProbabilities[a,b]["Ppm"]`
(Alice's marginal probability of `+1`, summed over both of Bob's
possible outcomes) equals exactly `0.5` for every `(a,b)` tested —
this is the no-signalling property: Alice's own statistics never
depend on which angle `b` Bob chose to measure at. This is NOT the
same statement as "Alice's outcome is independent of Bob's actual
result" — conditioned on a SPECIFIC Bob outcome, Alice's distribution
IS correlated (`P(Alice=+1|Bob=+1) = (1+E)/2 != 0.5` in general — that
correlation is literally the entanglement being measured). Precise
wording matters here: "marginal, regardless of the other's SETTING"
(true, no-signalling) is a different claim from "regardless of the
other's OUTCOME" (false in general — conflating the two would misstate
a foundational fact about entanglement). `MeasurementModel` computes
and prints both `marginalA`/`marginalB` (unconditional) so this is an
application-wide verified invariant, not just a one-off printed
diagnostic.

### 4. The `correlations` mode "classical" comparison is a real derived local model, not an arbitrary straight line

The build spec suggested "e.g. a linear interpolation between the
settings" as an illustrative example of a "reasonable-looking"
classical model. Rather than inventing an arbitrary straight line,
this app derives the actual prediction of a genuine local
hidden-variable toy model (the classic EPR-Bohm-style construction):
both particles share a hidden direction `lambda`, uniform on
`[0,2*Pi)`; each deterministically outputs `Sign[Cos[setting-lambda]]`
— fully local (each side's output depends only on its own setting and
the shared `lambda`) and deterministic given `lambda`.

`E_classical(delta) = (1/2Pi) * Integrate[Sign[Cos[lambda]] *
Sign[Cos[lambda-delta]], {lambda,0,2Pi}]` was evaluated directly via
`Integrate` (not assumed), giving
`ConditionalExpression[1 - 2*delta/Pi, 2*delta<Pi]` — a genuine
triangular function, not a guess that happens to look linear. Cross-
checked against `NIntegrate` at eight `delta` values from `0` to `Pi`,
matching to `~1e-9` at every point. This model was also confirmed to
itself never exceed the classical CHSH bound (`NMaximize` over all
four angles using this `E_classical` gives `Max S = 2.000000000000001`
— consistent with it genuinely being a local hidden-variable model,
an independent sanity check on the derivation).

One further finding, documented here rather than acted on: evaluating
THIS SAME `lambda`-sharing model's CHSH value at the CHSH-optimal
QUANTUM angles gives a pointwise-constant term of exactly `+2` for
EVERY single `lambda` (not just on average) — a degenerate special
case of this particular model at this particular angle configuration,
discovered while sizing a statistical tolerance for a Monte Carlo
version of the LHV bound check. It is why `LocalHiddenVariableBoundCheck`
(design decision 5 below) does NOT reuse this `lambda`-sharing model
for its own Monte Carlo half — a model with zero sampling variance at
the angles of interest cannot demonstrate anything statistically, so a
genuinely different construction (random convex mixtures of the 16
deterministic strategies) was used instead.

### 5. LocalHiddenVariableBoundCheck: exhaustive enumeration (exact) chosen over pure Monte Carlo, plus a complementary Monte Carlo sweep

The build spec allowed either "Monte-Carlo-sample local hidden-variable
models... or an exhaustive enumeration if tractable." With only
`2^4=16` deterministic strategies (each of Alice's two settings and
Bob's two settings gets a fixed `+-1` outcome), exhaustive enumeration
is trivially tractable AND exact — checking `Max[Abs[Svals]] == 2` over
all 16 is a complete proof of the bound (any probabilistic local model
is a convex mixture of these 16, and `S` is linear, so no mixture can
exceed the bound achieved at the vertices), not merely a sample of
some. This is strictly stronger than a statistical estimate, so it was
chosen as the check's primary/authoritative half.

The check ALSO runs a genuine Monte Carlo sweep as a complementary
empirical confirmation, satisfying the build spec's request to make
the bound concrete via sampling: `nTrials` (default 20000) random
convex-weight mixtures over the same 16 strategies (`RandomReal[
GammaDistribution[1,1], 16]`, normalised — a standard way to sample
uniformly from the probability simplex), each mixture's `S` computed
as `weights . Svals` (linear, since expectation is linear), confirming
none exceed `|S|<=2` either. Empirically these random mixtures land
far from the bound (`max |S| ~1.6` over 20000 samples in testing) since
reaching `|S|=2` exactly requires a pure deterministic strategy — this
is expected and not a weakness of the check; the EXACT enumeration
already proves the bound tightly, and the Monte Carlo half exists to
make it concrete across the (uncountably infinite) space of general
local models, not to find a tighter bound itself.

### 6. Why `measurement` mode caps discrete audio clicks at 40 trials but the running-correlation glissando covers the full run

`n_trials` defaults to 2000 (matching `qubit/measurement`'s own
default, for good CSV/PNG statistics). Playing every single trial as
an audible discrete click (`compton/scatter`'s idiom) would make the
WAV impractically long at that count. `$bellAudibleTrials = 40` caps
the discrete Alice-left/Bob-right click phase to a representative
sample — the same "readable sample of a much larger dataset"
convention `bayes/model`'s `FlipSequenceText` uses (`$bayesMeterMaxChars
= 120`) for the identical reason. The CONTINUOUS running-correlation
glissando that follows, unlike the discrete clicks, still covers the
FULL `nTrials` run — `BuildGlissandoBuffer` (duplicated from
`qubit/src/sonify.wl`) interpolates the complete `runningCorr` array.

### 7. `chsh` mode's gauge: a two-phase build-up (not a single static reading), and why it gets a GIF despite S being a single fixed number

Unlike `correlations` (a genuine sweep) or `qubit/gates` (a genuine
continuous trajectory), `chsh` mode's `S` is a single fixed number —
there is no natural continuous quantity to animate.
`compton/discovery` handles an analogous "no natural animation"
situation with a static-PNG-only output. This app instead animates the
CUMULATIVE PARTIAL SUM building toward `S` term by term
(`E(a,b)`, then `E(a,b)-E(a,b')`, then `+E(a',b)`, landing on the
final `S`) — directly mirroring the AUDIO's own four-note build-up
structure (see `sonify.wl`'s `BuildChshAudio`), so the GIF and WAV tell
the same story in sync rather than the GIF being static while the
audio narrates a sequence. The final PNG is simply the last frame
(the completed gauge), matching every other mode's "GIF animates,
PNG is the static end state" convention.

## Rabi-formula-style derivation summary (for reference)

Unlike `qubit/rabi`'s single formula, this app has three separate
derived results, each verified independently before use:

1. `E(a,b) = Cos[a-b]` — tensor-product sandwich, verified against
   diagonalisation + Born-rule computation (design decision 1).
2. CHSH-optimal angles give `S = 2*Sqrt[2]` exactly — global numerical
   optimisation, verified symbolically and against a 200k-sample
   random search (design decision 2).
3. `E_classical(delta) = 1 - 2*delta/Pi` — direct `Integrate` of a
   genuine local hidden-variable model, verified against `NIntegrate`
   (design decision 4).

## Project structure

```
bell/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json            — default simulation parameters
  experiments.wl          — 7 curated preset invocations
  LISTENING_GUIDE.md       — user-facing recommended listening sequence
  AGENTS.md                 — this file
  src/
    model.wl                 — Bell state, measurement operators, E(a,b) (+
                          independent verification), classical local model,
                          CHSH value + derived-optimal angles, joint
                          probability sampling, four correctness checks
    sonify.wl                  — correlations' binaural sweep, chsh's
                          build-up + verdict gauge, measurement's clicks +
                          running-correlation glissando (BuildGlissandoBuffer
                          duplicated from qubit/src/sonify.wl)
    speech.wl                    — Spoken intro synthesis and per-mode intro text
    animate.wl                     — quantum/classical overlay with moving
                          marker (correlations), cumulative gauge build-up
                          (chsh), running-correlation plot (measurement)
    output.wl                      — CSV export and console summaries
  tests/
    test_model.wl                 — Unit tests (operators, E(a,b), joint
                          probabilities, classical model, CHSH, all four
                          correctness checks, model builders)
  output/                           — generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                   # correlations, binaural sweep
wolframscript -file main.wl -- --simulation.mode=chsh          # CHSH gauge at derived-optimal angles
wolframscript -file main.wl -- --simulation.mode=measurement   # 2000 paired measurements
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks

All four run unconditionally, every invocation, regardless of mode,
always at fixed canonical parameters (the derived-optimal CHSH angles):

1. **Bell state normalization** — `|Phi+|^2 = 1`. Exact, tight tolerance.
2. **Quantum correlation, independent verification** — see design
   decision 1. Exact relation, tight tolerance.
3. **CHSH optimality** — see design decision 2. Exact relation, tight
   tolerance, plus a strict-inequality margin check against the naive
   angle choice.
4. **Local hidden-variable bound** — see design decision 5. Exact
   (enumeration) plus empirical (Monte Carlo).

## Common pitfalls

1. **`FmtN[x, N]` with a small integer `N` breaks on multi-digit
   values** — `FmtN[180.0, 2]` triggers `NumberForm::reqsigz`
   ("padding with zeros") because 2 significant figures cannot
   represent a 3-digit integer part. The exact same bug this
   session's `pendulum/AGENTS.md` documents for its own chaos-ratio
   printing. Fixed throughout `output.wl` by using a fixed-decimal
   spec (`{6,2}`) for angle values that can range up to `+-180`,
   instead of a significant-figures spec.
2. **`tolerance_?NumericQ:0.05`-style optional-argument patterns parse
   WRONG** in WL — binds as `tolerance_ ? (NumericQ:0.05)`, not
   `Optional[tolerance_?NumericQ, 0.05]`. Same pitfall documented in
   every prior v1.5.0/v1.6.0 app's `AGENTS.md`; this app avoids it by
   using `Optional[x_?NumericQ, default]` explicitly throughout.
3. **A local hidden-variable model can have ZERO sampling variance at
   specific angle settings** — see design decision 4's final
   paragraph. Don't assume any LHV construction is automatically
   suitable for a statistical Monte Carlo check; verify it actually
   has variance at the settings you intend to test it at.
4. **Marginal vs. conditional statistics are easy to conflate** — see
   design decision 3. "Regardless of the other's setting" (true) and
   "regardless of the other's outcome" (false) sound similar but are
   different claims; get the wording right in any documentation this
   app produces.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `StemSynthNote` (chsh build-up notes, measurement clicks),
  `STEMHeading`, `STEMSection`, `STEMSay`, `STEMPrintN`,
  `STEMDescribeWAV`, `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`,
  `STEMPlayCmd`, `NormalizeBuffer`, `ExportGIF`, `ExportCSV`,
  `EnsureDir`.
- **Mathematica/WL**: `KroneckerProduct`, `Eigensystem`,
  `ConjugateTranspose` (operator/state math), `NMaximize` (CHSH angle
  optimisation), `Integrate`/`NIntegrate` (classical model
  derivation), `RandomChoice`/`GammaDistribution` (joint sampling, LHV
  Monte Carlo), `Accumulate`/`Interpolation` (running correlation and
  glissando curves), `Graphics`, `Sound`, `SampledSoundList`,
  `Export`, `SpeechSynthesize`, `AudioQ`, `AudioData`,
  `AudioSampleRate`, `RunProcess` (platform TTS fallback), `Import`
  (reading TTS-generated WAV files).

## Speech synthesis note

`speech.wl`'s three-tier fallback (`SpeechSynthesize[]` -> platform TTS
-> text-only `STEMSay`) duplicates the pattern already used in
`qubit/src/speech.wl` and every other app's `speech.wl` file — still
out of scope for stem-core consolidation per every prior app's own
build spec.

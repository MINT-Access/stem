# Bell — Entanglement and the CHSH Inequality

Sonifies two entangled qubits — Bell correlations, the CHSH inequality,
and repeated Bell-state measurement. The second app in this project's
quantum-computing batch, building directly on [`qubit/`](../qubit/README.md)'s
single-qubit machinery; `grover/` (a search algorithm) is planned as a
future third member.

**New to this app?** Start with
[`bell/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — the recommended
listening sequence across all three modes.

## The story

In 1935, Einstein, Podolsky, and Rosen (EPR) argued that quantum
mechanics must be an incomplete description of reality. Their example:
prepare two particles in an entangled state, separate them by an
arbitrary distance, then measure one. Quantum mechanics predicts the
other particle's measurement outcome becomes correlated instantly, no
matter how far apart they are — Einstein called this "spooky action at
a distance" and argued it meant the particles must have carried
definite, predetermined properties all along ("hidden variables"),
with quantum mechanics simply failing to describe them. For thirty
years this remained a philosophical dispute: elegant, unsettling, and
seemingly untestable.

John Bell changed that in 1964. He showed that *any* theory in which
each particle carries predetermined local properties — regardless of
its details — must obey a specific statistical inequality relating
correlations measured at different angle settings. Quantum mechanics
predicts that real entangled particles violate it. This turned a
philosophical argument into an experimental question with a definite,
measurable answer.

Alain Aspect's experiments in the early 1980s, and decades of
progressively more rigorous "loophole-free" follow-ups by John
Clauser, Anton Zeilinger, and many others, found that nature sides
firmly with quantum mechanics: the inequality is violated, exactly as
quantum mechanics predicts and no local hidden-variable theory can
reproduce. Clauser, Aspect, and Zeilinger shared the **2022 Nobel
Prize in Physics** "for experiments with entangled photons,
establishing the violation of Bell inequalities and pioneering quantum
information science." This app makes that violation directly audible:
`correlations` mode lets you hear the real quantum curve pull away
from the best any local theory could do, and `chsh` mode turns the
actual inequality-violating number into a gauge reading you can both
see and hear.

## The physics

### The Bell state and quantum correlation

Two qubits prepared in the Bell state

    |Phi+> = (|00> + |11>) / Sqrt[2]

are maximally entangled: neither qubit has a definite state on its
own, but measuring both together always reveals a strict correlation.
Each qubit is measured along an axis at angle `theta` in its own
Bloch-sphere plane, via the dichotomic (`+-1`-eigenvalue) observable

    A(theta) = Cos[theta] * PauliZ + Sin[theta] * PauliX

(verified Hermitian with eigenvalues `{-1,1}` before use — a genuine
measurement operator, not an arbitrary matrix). For Alice measuring at
angle `a` and Bob at angle `b`, the correlation

    E(a,b) = <Phi+| A(a) (x) A(b) |Phi+>

was **derived directly** — computed via explicit tensor-product matrix
arithmetic on the state and operators this app actually defines, not
assumed from memory (the build brief for this app explicitly warned
that the sign and exact form of this result depends on which Bell
state and which operator convention is used). It simplifies to

    E(a,b) = Cos[a - b]

and was verified a second, completely independent way before being
trusted: diagonalising `A(a)` and `A(b)` via `Eigensystem`, rotating
`|Phi+>` into the resulting computational bases, and recovering `E(a,b)`
from the Born-rule outcome probabilities — a different computational
route sharing no code with the tensor-product derivation, agreeing to
machine precision at every angle tested (see `AGENTS.md` design
decision 1 for the full transcript, and correctness check 2).

A consequence worth stating explicitly: each qubit's own **marginal**
measurement statistics (ignoring what the other qubit's outcome was)
are exactly 50/50, regardless of which angle the *other* party chose
to measure at. This is why entanglement cannot be used to send a
signal faster than light — Alice's local statistics never reveal
anything about Bob's setting, only the *joint* outcomes (which require
comparing notes afterward, at ordinary speed) show the correlation.

### The CHSH inequality

For four measurement settings — `a`, `a'` for Alice, `b`, `b'` for Bob
— define

    S = E(a,b) - E(a,b') + E(a',b) + E(a',b')

**Any local hidden-variable theory obeys `|S| <= 2`.** This is not
merely asserted here: each hidden-variable instance assigns a
definite, predetermined `+-1` outcome to *every possible* setting in
advance (Alice and Bob each just read off their assigned value for
whichever setting they actually use) — there are exactly `2^4 = 16`
such deterministic strategies, and `S` is linear in their fixed
outcomes, so exhaustively enumerating all 16 is a complete, exact
proof, not a sample: every single one gives `S = +-2` exactly (see
correctness check 4, and `AGENTS.md` design decision 3). Any
probabilistic local model is a convex mixture of these 16 strategies,
and convexity means no mixture can exceed the bound achieved at the
extremes — confirmed separately by Monte-Carlo-sampling thousands of
random probability-weighted mixtures, none of which exceed `|S|=2`
either.

Quantum mechanics allows `|S|` up to `2*Sqrt[2] ~= 2.828` (Tsirelson's
bound, 1980). **The angle configuration that achieves this maximum was
found here by numerical optimisation** (global search over all four
angles via `NMaximize`, not a value recalled from memory — see
`AGENTS.md` design decision 2 for the full search and the symbolic
confirmation that it equals `2*Sqrt[2]` exactly):

    a = -45 deg,  a' = 45 deg,  b = 0 deg,  b' = 90 deg

A "reasonable-looking" but non-optimal alternative — both parties
measuring along two axes 90 degrees apart, with no 45-degree offset
between their frames (`a=0,a'=90,b=0,b'=90`) — gives `S=2` exactly,
indistinguishable from the classical ceiling. Only the specific
45-degree-offset configuration extracts the full quantum advantage;
`chsh` mode's default settings are the derived-optimal ones, and
`ChshOptimalityCheck` verifies both numbers directly (see Correctness
checks below).

### The classical comparison in `correlations` mode

The "classical" curve `correlations` mode plays alongside the real
quantum one is not an arbitrary straight line — it is the actual
prediction of a genuine local hidden-variable toy model: both
particles carry a shared hidden direction `lambda` (uniform on
`[0,2*Pi)`), and each deterministically outputs the sign of its own
alignment with its measurement axis, `Sign[Cos[setting - lambda]]`.
Integrating this model's correlation over `lambda` (`Integrate`, not
assumed) gives a triangular function of the angle difference,
`E_classical(delta) = 1 - 2*delta/Pi` for `delta` in `[0,Pi]` — see
`AGENTS.md` design decision 4 for the derivation and its numerical
cross-check. This is what any theory of *this* kind can achieve; the
gap between it and the real `Cos[delta]` curve is exactly what Bell's
theorem exploits.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically
- Optional for the spoken intro: macOS `say` (built in), Linux
  `espeak-ng`/`espeak`, or Windows PowerShell (built in) — falls back
  to text-only output if none is available

## Quick start

```sh
# Correlations mode (default): binaural sweep, quantum vs classical
wolframscript -file main.wl

# CHSH mode: the actual inequality-violating number, as a gauge
wolframscript -file main.wl -- --simulation.mode=chsh

# Measurement mode: 2000 paired Born-rule measurements
wolframscript -file main.wl -- --simulation.mode=measurement

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Modes

### correlations (default)

Sweeps the angle difference continuously and sonifies `E(a,b)` as a
binaural comparison — reusing the phase-accumulation glissando
technique from `compton/sweep`, `relativity/`'s chirp, and
`qubit/rabi` (`Sin[2 Pi Accumulate[f]*dt]`). The LEFT channel plays
the classical (local hidden-variable) triangular prediction; the RIGHT
channel plays the real quantum `Cos[delta]` curve — the same
left=classical/right=quantum convention `compton/discovery` and
`scattering/discovery` already establish in this codebase, of which
this mode is a natural third member.

**Best for:** hearing the gap between quantum and classical predictions
open and close as the angle difference sweeps — the gap is exactly
what a Bell test measures.

### chsh

Computes the actual `S` value at the derived-optimal angles and
presents it as a gauge reading: a short narrated build-up (one note
per correlation term, `compton/scatter`'s discrete-event idiom) followed
by a sustained binaural "verdict" — LEFT holds the fixed classical-
bound reference pitch, RIGHT holds the actual `S` value's pitch, so
the audible gap between the two held tones is exactly how far quantum
correlations exceed what any local theory permits. The GIF animates
the same build-up visually, term by term, against both the classical
(`|S|<=2`) and Tsirelson (`|S|<=2*Sqrt[2]`) bounds.

**Best for:** hearing (and seeing) Bell's theorem reduced to a single,
concrete number that a local hidden-variable theory simply cannot
produce.

### measurement

Simulates many independent paired measurement trials, sampled directly
from the TRUE joint quantum probability distribution (not from the
marginals independently — the whole point of entanglement is that the
joint distribution is correlated in a way no product of marginals can
reproduce). Alice's outcomes click on the LEFT channel, Bob's on the
RIGHT, individually unpredictable 50/50 — for a short audible sample of
trials — followed by a continuous glissando (the same technique
`qubit/rabi` and `qubit/measurement` use) tracking the running
correlation estimate over the *full* trial count, converging toward
the true `E(a,b)`.

**Best for:** hearing quantum randomness on each side individually,
while the correlation *between* the two sides becomes statistically
unmistakable — the quantum analogue of
[`bayes/coin`](../bayes/README.md)'s flip-by-flip belief update.

## Correctness checks

All four run unconditionally, every invocation, regardless of mode,
always at fixed canonical parameters (diagnostic-only: print
`[PASS]`/`[FAIL]`, never abort):

1. **Bell state normalization** — `|Phi+|^2 = 1`. Exact, tight tolerance.
2. **Quantum correlation, independent verification** — the closed form
   `E(a,b)=Cos[a-b]` vs. an independent diagonalisation/Born-rule
   computation sharing no code with the closed form. Exact relation,
   tight tolerance.
3. **CHSH optimality** — the derived-optimal angles give `S` equal to
   `2*Sqrt[2]` to near-machine precision, AND a naive (non-optimal)
   angle choice gives a strictly, meaningfully smaller `S` —
   demonstrating the optimisation step actually mattered.
4. **Local hidden-variable bound** — exhaustive enumeration of all 16
   deterministic local strategies (exact: every one gives `S=+-2`)
   plus Monte-Carlo-sampling thousands of random probabilistic
   mixtures of them (empirical), confirming none exceed `|S|<=2` —
   the check that makes Bell's theorem concrete rather than asserted.

## Outputs

| File | Description |
|------|-------------|
| `output/bell_correlations.wav` | Binaural: classical (left) vs quantum (right) correlation sweep |
| `output/bell_correlations.gif` | `E(a,b)` curve, quantum vs classical overlay, moving marker |
| `output/bell_correlations.png` | Static version of the same overlay |
| `output/bell_correlations.csv` | Per-step: angle difference, quantum E, classical E |
| `output/bell_chsh.wav` | Narrated build-up + binaural classical/quantum verdict |
| `output/bell_chsh.gif` | Gauge animation, S built up term by term against both bounds |
| `output/bell_chsh.png` | Static final gauge reading |
| `output/bell_chsh.csv` | The four correlation terms, S, and both bounds |
| `output/bell_measurement.wav` | Binaural Alice/Bob outcome clicks, then running-correlation glissando |
| `output/bell_measurement.png` | Running correlation estimate vs. trial, true value dashed |
| `output/bell_measurement.csv` | Per-trial: trial number, Alice outcome, Bob outcome, running correlation |

## Configuration parameters (`bell/config.json`)

| Key | Default | Used by |
|-----|---------|---------|
| `simulation.mode` | `"correlations"` | all |
| `simulation.bell.n_steps` | `200` | correlations |
| `simulation.bell.b_angle_deg` | `0.0` | correlations (Bob's fixed angle; the sweep is over Alice's angle difference from this) |
| `simulation.bell.chsh_a_deg` / `chsh_ap_deg` | `-45.0` / `45.0` | chsh (Alice's two settings; derived-optimal) |
| `simulation.bell.chsh_b_deg` / `chsh_bp_deg` | `0.0` / `90.0` | chsh (Bob's two settings; derived-optimal) |
| `simulation.bell.alice_angle_deg` / `bob_angle_deg` | `-45.0` / `0.0` | measurement |
| `simulation.bell.n_trials` | `2000` | measurement |
| `simulation.bell.seed` | `11` | measurement (reproducible runs) |

## Project structure

```
bell/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl         — 7 curated preset invocations
  config.json              — App defaults
  LISTENING_GUIDE.md         — Recommended listening sequence
  src/
    model.wl                  — Bell state, measurement operators, E(a,b)
                            (+ independent verification), CHSH value and
                            derived-optimal angles, local hidden-variable
                            enumeration/Monte Carlo, four correctness checks
    sonify.wl                   — correlations' binaural sweep, chsh's
                            build-up + verdict gauge, measurement's clicks
                            + running-correlation glissando
    speech.wl                     — Spoken intro synthesis and per-mode intro text
    animate.wl                      — quantum/classical overlay (correlations),
                            cumulative gauge build-up (chsh), running-
                            correlation plot (measurement)
    output.wl                       — CSV export and console summaries
  tests/
    test_model.wl                  — Unit tests
  output/                            — Output files (not committed)
  README.md
  AGENTS.md
```

## Connection to `qubit/`, `compton/discovery`, `scattering/discovery`, and `bayes/`

`bell/` builds directly on [`qubit/`](../qubit/README.md)'s Bloch-sphere
and gate machinery (the same measurement-operator and Bloch-vector
conventions, extended from one qubit to two), and its three sonification
techniques are each borrowed because the technique genuinely fits, not
as an arbitrary rotation through existing idioms: the phase-accumulation
glissando `correlations` and `measurement` share with `compton/sweep`,
`relativity/`'s chirp, and `qubit/rabi`; the classical-vs-quantum
binaural structure `correlations` shares with
[`compton/discovery`](../compton/README.md) and
[`scattering/discovery`](../scattering/README.md) (of which it is a
natural third member — Bell's own argument IS a classical-vs-quantum
comparison at its core); and the evidence-accumulating structure
`measurement` shares conceptually with
[`bayes/coin`](../bayes/README.md). This app is also the deliberate
second step of a small quantum-computing batch: `grover/` (a search
algorithm built from single- and multi-qubit gates) is planned as a
future third member.

## Console output

Step numbers `[1/5]` through `[5/5]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements in
addition to the intro:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

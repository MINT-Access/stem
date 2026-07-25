# Grover — Search Algorithm

Sonifies Grover's search algorithm — the optimal-stopping search
curve, a binaural classical-vs-quantum speedup race, and the
algorithm's own literal 2D rotation geometry. The third app in this
project's quantum-computing batch, building on
[`qubit/`](../qubit/README.md)'s and [`bell/`](../bell/README.md)'s
foundations, and the one that demonstrates the other half of why
quantum computing matters beyond entanglement's foundational weirdness:
a genuine, provable computational speedup.

**New to this app?** Start with
[`grover/LISTENING_GUIDE.md`](LISTENING_GUIDE.md) — the recommended
listening sequence across all three modes.

## The algorithm

Grover's algorithm searches an unsorted database of `N=2^n` items for
one marked item in `O(Sqrt[N])` queries, versus the `O(N)` any
classical algorithm needs on average — a genuine, proven quantum
speedup, not merely a faster constant factor.

### The geometry — derived, not just cited

Starting from the uniform superposition `|s> = (1/Sqrt[N]) Sum|x>`,
the marked state `|w>` and the uniform superposition of all *unmarked*
states `|s'>` span a 2D real subspace. Define `Sin[theta] = 1/Sqrt[N]`
— the overlap of `|s>` with `|w>`. Within this subspace:

- The **oracle** (phase-flip the marked state) is `I - 2|w><w|` — a
  reflection about the `|s'>` axis (the hyperplane orthogonal to `|w>`
  restricted to this 2D plane).
- **Diffusion** (inversion about the mean amplitude) is `2|s><s| - I`
  — a reflection about the `|s>` axis.
- Two reflections compose to a rotation by twice the angle between the
  mirror lines — so each Grover iteration is **exactly a rotation by
  `2*theta`**.

This was verified directly, not asserted: building the oracle,
diffusion, and combined Grover operator as explicit `NxN` matrices for
several `N`, restricting the combined operator to the `{|w>,|s'>}`
basis, and confirming it equals `RotationMatrix[2*theta]` to machine
precision (see `AGENTS.md` design decision 1 for the full transcript).
After `k` iterations the amplitude on `|w>` is `Sin[(2k+1)*theta]`, so

    P(marked) = Sin[(2k+1)*theta]^2

— verified by directly applying the explicit Grover matrix `k` times
to the initial state and reading the squared amplitude, agreeing with
the closed form to machine precision at every `(N,k)` tested.

### The optimal stopping point — more isn't always better

`P(marked)` rises toward 1 and then **falls again** if you keep
iterating past the peak — over-rotating genuinely makes the search
worse, a fact worth stating explicitly since it runs against a naive
"more iterations = better" intuition. The optimal `k` is the integer
nearest `Pi/(4*theta) - 1/2`. The common approximation
`k_opt ~= (Pi/4)*Sqrt[N]` is good for large `N` but was checked, not
assumed — see the actual numbers this app's build session produced,
below.

**A genuinely discovered edge case, not glossed over**: for very small
`N` (large `theta`), the discrete grid of achievable angles can put a
*later* peak numerically closer to `Pi/2` than the intended first
peak, giving a technically-higher probability at a later `k`. The
"optimal number of iterations" in this app always means the **first**
peak — fewer queries is the entire point of the speedup, so a later,
accidentally-higher peak is not a better answer. `N=2` is a fully
degenerate special case: `P(marked) = 0.5` for *every* `k` — iterating
never helps at all (see `AGENTS.md` design decision 4).

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically
- Optional for the spoken intro: macOS `say` (built in), Linux
  `espeak-ng`/`espeak`, or Windows PowerShell (built in) — falls back
  to text-only output if none is available

## Quick start

```sh
# Search mode (default): N=64, rise then fall past the optimum
wolframscript -file main.wl

# Compare mode: binaural classical-vs-quantum race
wolframscript -file main.wl -- --simulation.mode=compare

# Geometry mode: the literal 2D rotation, continuous
wolframscript -file main.wl -- --simulation.mode=geometry

# Inspect merged config
wolframscript -file main.wl -- --config-dump
```

## Modes

### search (default)

Runs Grover iterations on a configurable `N` and marked index,
sonifying `P(marked)` as a discrete note per iteration (each iteration
genuinely IS a discrete oracle+diffusion query, unlike a continuous
physical process) — pitch tracks `P(marked)(k)` directly, with a
bright accent marking the true optimal iteration, audible against the
notes continuing to fall in pitch if iteration goes past it.

**Best for:** hearing the "rise, then fall past the optimum" story
directly — the single clearest illustration that more quantumness
isn't automatically better.

### compare

A binaural race: LEFT channel ticks through an average-case classical
linear search (`N/2` queries), RIGHT channel ticks through Grover's
optimal iteration count — both start together, so the literal
*duration* difference between the two channels' final "found" chimes
is the speedup, made audible. The same classical-vs-quantum binaural
lineage as [`compton/discovery`](../compton/README.md),
[`scattering/discovery`](../scattering/README.md), and
[`bell/correlations`](../bell/README.md).

**Best for:** hearing the speedup as a literal difference in how long
each side takes to find the answer — no formulas needed.

### geometry

Sonifies the literal 2D rotation picture directly: the state vector's
angle within the `{|w>,|unmarked>}` subspace advancing by exactly
`2*theta` per iteration, as a continuously rotating pan/pitch (the
same phase-accumulation technique `compton/sweep` and `bell/
correlations` use) — PAN traces the vector's signed marked-axis
component, PITCH is driven by `P(marked)` exactly as in `search` mode,
so geometry mode sounds like search mode's own mechanism made
continuous.

**Best for:** hearing (and, via the GIF, seeing) the exact geometric
mechanism behind the probability curve — not just its result.

## Correctness checks

All four run unconditionally, every invocation, regardless of mode,
always at fixed canonical parameters (diagnostic-only: print
`[PASS]`/`[FAIL]`, never abort):

1. **Rotation angle, exact** — the Grover operator, restricted to the
   `{|w>,|s'>}` subspace, equals `RotationMatrix[2*theta]` to machine
   precision, via explicit matrix construction for a specific `N`.
2. **Optimal iteration count, exact for given N** — direct simulation
   (period-windowed argmax search, sharing only the matrix-free
   `Sin[]^2` formula with the point estimate, not its search logic)
   matches `Round[Pi/(4*theta) - 1/2]` exactly, for eight different
   `N` values.
3. **Operator unitarity, exact** — oracle, diffusion, and their
   product `G` all satisfy `G^T G = I` for a specific `N`.
4. **Closed form vs direct simulation, exact** — `Sin[(2k+1)*theta]^2`
   matches direct repeated application of the explicit Grover matrix,
   for five different `(N,k)` combinations.

## Outputs

| File | Description |
|------|-------------|
| `output/grover_search.wav` | Discrete per-iteration notes, accent at the optimum |
| `output/grover_search.gif` | `P(marked)` curve building up, optimal point marked |
| `output/grover_search.png` | Static full curve, rise then fall, optimum marked |
| `output/grover_search.csv` | Per-iteration: iteration k, P(marked) |
| `output/grover_compare.wav` | Binaural race: classical (left) vs quantum (right) |
| `output/grover_compare.gif` | Classical vs quantum query count, growing gap across N |
| `output/grover_compare.png` | Static version of the same growing-gap chart |
| `output/grover_compare.csv` | N, classical queries, quantum queries (swept range) |
| `output/grover_geometry.wav` | Continuous rotation, pan/pitch phase-accumulated |
| `output/grover_geometry.gif` | 2D unit-circle rotation diagram, vector advancing |
| `output/grover_geometry.png` | Final rotation state, full path traced |
| `output/grover_geometry.csv` | Per-iteration: iteration, angle (rad), amplitude on marked state |

## Configuration parameters (`grover/config.json`)

| Key | Default | Used by |
|-----|---------|---------|
| `simulation.mode` | `"search"` | all |
| `simulation.grover.n_items` | `64` | search, compare, geometry (must be a power of 2) |
| `simulation.grover.marked_index` | `42` | search, compare, geometry |
| `simulation.grover.n_iterations` | `12` | search, geometry (deliberately past the optimum, so the fall is audible/visible) |
| `simulation.grover.compare_n_min` / `compare_n_max` | `4.0` / `1048576.0` | compare (swept range for the growing-gap chart) |
| `simulation.grover.compare_n_steps` | `100` | compare |

## Project structure

```
grover/
  main.wl              — Entry point (thin orchestrator)
  experiments.wl         — 7 curated preset invocations
  config.json              — App defaults
  LISTENING_GUIDE.md         — Recommended listening sequence
  src/
    model.wl                  — Oracle/diffusion/Grover operators, closed-form
                            probability, optimal-k (exact + independent
                            simulation), four correctness checks
    sonify.wl                   — search's per-iteration notes, compare's
                            binaural race, geometry's phase-accumulated
                            rotation
    speech.wl                     — Spoken intro synthesis and per-mode intro text
    animate.wl                      — P(marked) curve (search), growing-gap
                            chart (compare), 2D rotation diagram (geometry)
    output.wl                       — CSV export and console summaries
  tests/
    test_model.wl                  — Unit tests
  output/                            — Output files (not committed)
  README.md
  AGENTS.md
```

## Connection to `qubit/`, `bell/`, and the discovery-mode lineage

`grover/` completes the small quantum-computing batch `qubit/` (a
single qubit's Bloch sphere and gates) and `bell/` (two entangled
qubits, the CHSH inequality) began — the same measurement operators
and unitary-matrix conventions apply, extended here to full `N`-item
oracle/diffusion operators. `compare` mode's binaural race is the
third member of this codebase's classical-vs-quantum comparison
lineage, alongside `compton/discovery`, `scattering/discovery`, and
`bell/correlations` — each comparing what a pre-quantum theory predicts
against what nature (or, here, a quantum algorithm) actually delivers.

## Console output

Step numbers `[1/5]` through `[5/5]` mark each pipeline stage. Export
confirmations use `STEMDescribeWAV`, `STEMDescribeGIF`, and
`STEMDescribeCSV`. Set `STEM_SPEAK=1` for spoken stage announcements in
addition to the intro:

```sh
STEM_SPEAK=1 wolframscript -file main.wl
```

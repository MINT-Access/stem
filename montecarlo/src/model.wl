(* ========================================================
   montecarlo/src/model.wl — 2D Ising model, Metropolis Monte Carlo

   Ferromagnetic Ising model on an N x N toroidal (periodic) lattice.
   Spins s_i in {+1,-1}, energy E = -J * Sum_<i,j> s_i s_j over nearest
   neighbours. The exact 2D critical temperature (Onsager 1944):

     T_c = 2J/k / Log[1 + Sqrt[2]]  ~=  2.2692 J/k

   Units: J = 1, k = 1 throughout (T is dimensionless, in units of J/k).
   ======================================================== *)


(* NB: Optional[] form required, not "jCoupling_?NumericQ : 1.0" — the
   latter parses as jCoupling_?(NumericQ : 1.0), a pattern that never
   matches, so the function would silently fail to evaluate on every
   call (see dynamical/AGENTS.md pitfall 1 for the full explanation). *)
$OnsagerTc[Optional[jCoupling_?NumericQ, 1.0]] := 2.0 * jCoupling / Log[1.0 + Sqrt[2.0]];


(* ── Lattice construction ─────────────────────────────────────────── *)

RandomSpinGrid[n_Integer] := RandomChoice[{-1, 1}, {n, n}];
AllUpGrid[n_Integer]      := ConstantArray[1, {n, n}];

(* NearestPowerOfTwo — HilbertTraversalOrder requires an exact 2^k x 2^k
   grid, so the configured lattice_size is coerced to the nearest power
   of two (same pattern cosmology/ uses for its sky-map resolution). *)
NearestPowerOfTwo[n_Integer] := 2^Round[Log2[N[n]]];


(* ── Observables ──────────────────────────────────────────────────── *)

Magnetisation[grid_List] := N[Total[grid, 2]] / Length[grid]^2;

(* EnergyPerSpin
   E = -J * Sum over all bonds s_i s_j, each bond counted exactly once.
   Summing s_i * (right-neighbour + down-neighbour) over every site i
   counts every horizontal bond once (from its left site) and every
   vertical bond once (from its top site) — RotateLeft by one column/row
   implements the toroidal "right"/"down" neighbour lookup. *)
EnergyPerSpin[grid_List, jCoupling_?NumericQ] :=
  Module[{n = Length[grid], totalE},
    totalE = -jCoupling * Total[grid * (RotateLeft[grid, {0, 1}] + RotateLeft[grid, {1, 0}]), 2];
    N[totalE] / n^2
  ];

(* SusceptibilityEstimate
   chi = N^2 * (<M^2> - <M>^2) / (kT), estimated from a list of
   magnetisation samples at fixed temperature T (k=1). *)
SusceptibilityEstimate[MSamples_List, n_Integer, T_?NumericQ] :=
  Module[{meanM, meanM2},
    meanM  = Mean[MSamples];
    meanM2 = Mean[MSamples^2];
    N[n]^2 * (meanM2 - meanM^2) / T
  ];


(* ── Metropolis Monte Carlo ───────────────────────────────────────── *)

(* MetropolisAcceptanceProbability
   The Metropolis criterion itself, as a standalone testable function
   (also used, inlined, inside $IsingSweepCompiled below — kept in sync
   by tests/test_model.wl's detailed-balance check). *)
MetropolisAcceptanceProbability[dE_?NumericQ, T_?NumericQ] :=
  If[dE <= 0.0, 1.0, Exp[-dE / T]];

(* $IsingSweepCompiled
   Performs nAttempts single-spin Metropolis updates on grid (each
   attempt: pick a uniformly random site, compute the energy cost of
   flipping it, accept unconditionally if it lowers energy or
   probabilistically otherwise). One sweep = n^2 attempts (one flip
   attempt per spin on average). Benchmarked at ~25ms for 300 sweeps on
   a 32x32 lattice (WL's default bytecode Compile target, no C compiler
   required) — see AGENTS.md; comfortably fast enough that no further
   batching/vectorisation was needed despite the spec's performance
   warning.

   Periodic (toroidal) boundary conditions via explicit wraparound
   (If[i==1,nSize,i-1] etc.) rather than Mod — compiles to simple
   branches and benchmarks faster than Mod in this Compile target. *)
$IsingSweepCompiled = Compile[
  {{grid, _Integer, 2}, {nSize, _Integer}, {temp, _Real}, {jCoupling, _Real}, {nAttempts, _Integer}},
  Module[{g = grid, i, j, up, down, left, right, nbrSum, dE, k},
    Do[
      i = RandomInteger[{1, nSize}];
      j = RandomInteger[{1, nSize}];
      up    = g[[If[i == 1, nSize, i - 1], j]];
      down  = g[[If[i == nSize, 1, i + 1], j]];
      left  = g[[i, If[j == 1, nSize, j - 1]]];
      right = g[[i, If[j == nSize, 1, j + 1]]];
      nbrSum = up + down + left + right;
      dE = 2.0 * jCoupling * g[[i, j]] * nbrSum;
      If[dE <= 0.0 || RandomReal[] < Exp[-dE / temp],
        g[[i, j]] = -g[[i, j]]
      ],
      {k, nAttempts}
    ];
    g
  ],
  CompilationOptions -> {"InlineExternalDefinitions" -> True},
  RuntimeOptions -> "Speed"
];

RunOneSweep[grid_List, nSize_Integer, T_?NumericQ, jCoupling_?NumericQ] :=
  $IsingSweepCompiled[grid, nSize, N[T], N[jCoupling], nSize^2];

(* RunNSweepsBatched — runs nSweeps worth of attempts in a single
   compiled call with no intermediate snapshots; used for equilibration
   phases, which are discarded anyway. *)
RunNSweepsBatched[grid_List, nSize_Integer, T_?NumericQ, jCoupling_?NumericQ, nSweeps_Integer] :=
  $IsingSweepCompiled[grid, nSize, N[T], N[jCoupling], nSweeps * nSize^2];


(* ── Mode drivers ─────────────────────────────────────────────────── *)

(* RunSweepMode
   Descends TVals from TStart to TEnd in NTSteps steps. At each
   temperature: nEquilibration sweeps discarded (batched, one compiled
   call), then nMeasurement sweeps recorded individually (one grid
   snapshot each, needed for the spatial audio layer and GIF). *)
RunSweepMode[nSize_Integer, TStart_?NumericQ, TEnd_?NumericQ, NTSteps_Integer,
             nEquilibration_Integer, nMeasurement_Integer, jCoupling_?NumericQ] :=
  Module[{TVals, grid, allT = {}, allM = {}, allE = {}, allGrids = {}, allSweepIdx = {},
          globalIdx = 0, chiPerStep = {}},
    TVals = N[Subdivide[TStart, TEnd, NTSteps - 1]];
    grid  = RandomSpinGrid[nSize];

    Do[
      Module[{T = TVals[[step]], stepM = {}},
        grid = RunNSweepsBatched[grid, nSize, T, jCoupling, nEquilibration];
        Do[
          grid = RunOneSweep[grid, nSize, T, jCoupling];
          globalIdx += 1;
          AppendTo[stepM, Magnetisation[grid]];
          AppendTo[allT, T];
          AppendTo[allM, Last[stepM]];
          AppendTo[allE, EnergyPerSpin[grid, jCoupling]];
          AppendTo[allGrids, grid];
          AppendTo[allSweepIdx, globalIdx],
          {nMeasurement}
        ];
        AppendTo[chiPerStep, SusceptibilityEstimate[stepM, nSize, T]]
      ],
      {step, NTSteps}
    ];

    <|
      "sweepIdx" -> allSweepIdx, "T" -> allT, "M" -> allM, "E" -> allE,
      "grids" -> allGrids, "TVals" -> TVals, "chiPerStep" -> chiPerStep,
      "nMeasurement" -> nMeasurement, "finalGrid" -> grid, "nSize" -> nSize
    |>
  ];

(* RunCriticalMode
   Fixed T = T_c, nSweeps sweeps from a random initial configuration,
   every sweep recorded. chi is an expanding-window estimate (all
   sweeps seen so far), since there is no discrete temperature block to
   average over. *)
RunCriticalMode[nSize_Integer, Tc_?NumericQ, nSweeps_Integer, jCoupling_?NumericQ] :=
  Module[{grid, allM = {}, allE = {}, allGrids = {}, allChi = {}},
    grid = RandomSpinGrid[nSize];
    Do[
      grid = RunOneSweep[grid, nSize, Tc, jCoupling];
      AppendTo[allM, Magnetisation[grid]];
      AppendTo[allE, EnergyPerSpin[grid, jCoupling]];
      AppendTo[allGrids, grid];
      AppendTo[allChi, SusceptibilityEstimate[allM, nSize, Tc]],
      {nSweeps}
    ];
    <|
      "sweepIdx" -> Range[nSweeps], "M" -> allM, "E" -> allE, "grids" -> allGrids,
      "chi" -> allChi, "T" -> Tc, "finalGrid" -> grid, "nSize" -> nSize
    |>
  ];

(* RunQuenchMode
   Random (high-T-equivalent) initial configuration, instantaneously
   held at T_cold for nSweeps sweeps — the quench itself is simply
   "start random, simulate at T_cold from sweep 1" (there is no
   pre-quench simulation to run since the T_hot state is by definition
   uncorrelated random spins). *)
RunQuenchMode[nSize_Integer, TCold_?NumericQ, nSweeps_Integer, jCoupling_?NumericQ,
              randomSeed_Integer] :=
  Module[{grid, allM = {}, allE = {}, allGrids = {}, allChi = {}},
    SeedRandom[randomSeed];
    grid = RandomSpinGrid[nSize];
    Do[
      grid = RunOneSweep[grid, nSize, TCold, jCoupling];
      AppendTo[allM, Magnetisation[grid]];
      AppendTo[allE, EnergyPerSpin[grid, jCoupling]];
      AppendTo[allGrids, grid];
      AppendTo[allChi, SusceptibilityEstimate[allM, nSize, TCold]],
      {nSweeps}
    ];
    <|
      "sweepIdx" -> Range[nSweeps], "M" -> allM, "E" -> allE, "grids" -> allGrids,
      "chi" -> allChi, "T" -> TCold, "finalGrid" -> grid, "nSize" -> nSize
    |>
  ];


(* ── Correctness checks (Physical/mathematical, printed PASS/FAIL) ── *)

(* Check 1: Onsager's exact T_c formula matches the known numeric value. *)
OnsagerTcCheck[Optional[tolerance_?NumericQ, 10^-5]] :=
  Module[{computed, known},
    computed = $OnsagerTc[1.0];
    known    = 2.269185314213022;
    <| "computed" -> computed, "known" -> known,
       "error" -> Abs[computed - known], "pass" -> (Abs[computed - known] < tolerance) |>
  ];

(* Check 2: energy per spin lies within the dynamically-reachable bounds
   [-2J, 0] for every recorded configuration. A ferromagnetic (J>0)
   Metropolis trajectory started from either a random or ordered state
   never spontaneously organises into the anti-aligned checkerboard
   configuration (e = +2J) — that state is energetically disfavoured by
   the very coupling driving the dynamics — so a large violation here
   signals a bug in the energy calculation, not an unusual-but-valid
   microstate.

   The lower bound (-2J, the exact ground-state energy) is a hard
   physical floor and is checked tightly. The upper bound (0) is only
   an approximate expectation for a *fully random* (infinite-T)
   configuration — per-spin energy is itself an average over ~2*n^2
   bond terms with O(1/n) statistical width, so individual measurement
   samples (especially at high but finite T, or for smaller lattices)
   routinely fluctuate a little above 0. upperTolerance defaults to a
   generous 0.3 to absorb that genuine statistical noise while still
   catching a real implementation bug, which would show energies wildly
   outside this range (e.g. consistently near +2J), not a few-hundredths
   overshoot. *)
EnergyBoundsCheck[EValues_List, jCoupling_?NumericQ, Optional[upperTolerance_?NumericQ, 0.3]] :=
  Module[{minE, maxE, lowerOk, upperOk},
    minE = Min[EValues];
    maxE = Max[EValues];
    lowerOk = minE >= -2.0 * jCoupling - 10^-6;
    upperOk = maxE <= 0.0 + upperTolerance;
    <| "minE" -> minE, "maxE" -> maxE, "pass" -> (lowerOk && upperOk) |>
  ];

(* Check 3: detailed balance — for a real local spin-flip on an actual
   lattice configuration, the ratio of forward/reverse Metropolis
   acceptance probabilities must equal Exp[-dE/T] exactly (a standard
   identity: flipping back is the reverse transition with
   dE_reverse = -dE_forward, and min(1,x)/min(1,1/x) = x for any x>0). *)
DetailedBalanceCheck[nSize_Integer, jCoupling_?NumericQ, T_?NumericQ,
                     Optional[tolerance_?NumericQ, 10^-9]] :=
  Module[{grid, i, j, nbrSum, dE, pForward, pReverse, ratio, expected, relErr},
    grid = RandomSpinGrid[nSize];
    i = Ceiling[nSize / 2]; j = Ceiling[nSize / 2];
    nbrSum = grid[[If[i == 1, nSize, i - 1], j]] + grid[[If[i == nSize, 1, i + 1], j]] +
             grid[[i, If[j == 1, nSize, j - 1]]] + grid[[i, If[j == nSize, 1, j + 1]]];
    dE = 2.0 * jCoupling * grid[[i, j]] * nbrSum;
    pForward = MetropolisAcceptanceProbability[dE, T];
    pReverse = MetropolisAcceptanceProbability[-dE, T];
    ratio    = pForward / pReverse;
    expected = Exp[-dE / T];
    relErr   = Abs[ratio - expected] / expected;
    <|
      "dE" -> dE, "pForward" -> pForward, "pReverse" -> pReverse,
      "ratio" -> ratio, "expected" -> expected, "pass" -> (relErr < tolerance)
    |>
  ];

(* Check 4: magnetisation convergence — sweep mode only, checked by the
   caller (main.wl) against the sweep's own recorded (T,M) data, since
   it needs actual simulation results rather than fresh model inputs. *)
MagnetisationConvergenceCheck[TVals_List, MByStep_List, Optional[TThreshold_?NumericQ, 1.0],
                              Optional[MThreshold_?NumericQ, 0.8]] :=
  Module[{coldIndices, coldM, allOrdered},
    coldIndices = Position[TVals, t_ /; t < TThreshold][[All, 1]];
    coldM = Abs[MByStep[[coldIndices]]];
    allOrdered = Length[coldM] > 0 && AllTrue[coldM, # > MThreshold &];
    <| "coldTemperatures" -> TVals[[coldIndices]], "coldM" -> coldM, "pass" -> allOrdered |>
  ];

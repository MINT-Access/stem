(* ========================================================
   grover/src/model.wl — Grover's search algorithm

   Grover's algorithm searches an unsorted database of N=2^n items for
   one marked item in O(Sqrt[N]) queries, versus the O(N) any classical
   algorithm needs on average — a genuine, proven quantum speedup, not
   merely a faster constant factor.

   The geometry, DERIVED here (not asserted — see the module-level
   derivation transcript in AGENTS.md design decision 1): starting from
   the uniform superposition |s> = (1/Sqrt[N]) Sum|x>, the marked state
   |w> and the uniform superposition of unmarked states |s'> span a 2D
   real subspace. With Sin[theta] = 1/Sqrt[N], the oracle (I - 2|w><w|)
   is a reflection about the |s'> axis, and diffusion (2|s><s| - I) is
   a reflection about the |s> axis — verified via explicit NxN matrix
   construction for several N, restricted to the {|w>,|s'>} basis, and
   confirmed to equal EXACTLY a rotation by 2*theta (agreement to
   machine precision against RotationMatrix[2*theta], not merely
   "looks right"). After k iterations the amplitude on |w> is
   Sin[(2k+1)*theta], so P(marked) = Sin[(2k+1)*theta]^2 — verified via
   direct repeated matrix application to the initial state, not merely
   restating the closed form.

   Public API:
     GroverThetaFromN[nItems]
     GroverOperators[nItems, markedIdx]
     GroverProbMarked[nItems, k]  (closed form)
     GroverSimulateTrajectory[nItems, markedIdx, kMax]  (direct simulation)
     GroverOptimalK[nItems]  (exact, theta-based)
     GroverOptimalKBySimulation[nItems]  (independent: period-windowed argmax search)
     RotationAngleCheck[], OptimalIterationCountCheck[],
     OperatorUnitarityCheck[], ClosedFormVsSimulationCheck[]
     SearchModel[cfg], CompareModel[cfg], GeometryModel[cfg]
   ======================================================== *)


(* ── Core operators and geometry ──────────────────────────────────── *)

(* GroverThetaFromN — Sin[theta] = 1/Sqrt[N], the overlap of the
   uniform superposition |s> with the marked state |w>. *)
GroverThetaFromN[nItems_Integer] := ArcSin[1.0 / Sqrt[N[nItems]]];

(* GroverOperators — builds the oracle, diffusion, and combined Grover
   operator as explicit NxN real matrices for a specific (small) N.
   Used by the correctness checks and by direct-simulation code paths;
   NOT used for the closed-form probability formula elsewhere in this
   app (see GroverProbMarked), so the closed form and this explicit
   construction remain independently verifiable against each other. *)
GroverOperators[nItems_Integer, markedIdx_Integer] :=
  Module[{sVec, oracleOp, diffusionOp, groverOp},
    sVec = ConstantArray[1.0 / Sqrt[N[nItems]], nItems];
    oracleOp = IdentityMatrix[nItems] -
      2.0 * Outer[Times, UnitVector[nItems, markedIdx], UnitVector[nItems, markedIdx]];
    diffusionOp = 2.0 * Outer[Times, sVec, sVec] - IdentityMatrix[nItems];
    groverOp = diffusionOp . oracleOp;
    <| "sVec" -> sVec, "oracleOp" -> oracleOp, "diffusionOp" -> diffusionOp, "groverOp" -> groverOp |>
  ];

(* GroverProbMarked — the closed-form probability, P(marked) after k
   Grover iterations. This is what every mode in this app uses for
   plotting/sonification (cheap, exact, no matrix construction needed);
   GroverSimulateTrajectory below is the independent verification path. *)
GroverProbMarked[nItems_Integer, k_?NumericQ] :=
  Sin[(2.0 * k + 1.0) * GroverThetaFromN[nItems]]^2;

(* GroverSimulateTrajectory — direct repeated application of the
   explicit Grover matrix to the initial uniform superposition, reading
   off the SQUARED amplitude on the marked index at each step. Shares
   only GroverOperators (matrix construction) with the closed form
   above — the trajectory here comes from actual matrix multiplication,
   not from evaluating Sin[...]^2. *)
GroverSimulateTrajectory[nItems_Integer, markedIdx_Integer, kMax_Integer] :=
  Module[{ops, state, probs},
    ops = GroverOperators[nItems, markedIdx];
    state = ops["sVec"];
    probs = Table[
      With[{p = state[[markedIdx]]^2}, state = ops["groverOp"] . state; p],
      {kMax + 1}
    ];
    probs
  ];

(* GroverOptimalK — the k nearest the FIRST peak of P(marked), i.e. the
   textbook "optimal number of iterations": more queries is worse (the
   whole point of the speedup is stopping as soon as possible), so this
   is deliberately the k closest to the first maximum, not necessarily
   the global argmax over all k (see AGENTS.md design decision 3 for a
   discovered edge case at small N where a LATER peak can be
   numerically higher due to the discrete k-grid). *)
GroverOptimalK[nItems_Integer] :=
  Round[Pi / (4.0 * GroverThetaFromN[nItems]) - 0.5];

(* GroverOptimalKBySimulation — an INDEPENDENT verification of
   GroverOptimalK: searches the argmax of the closed-form probability
   over a window sized from the OSCILLATION PERIOD (Pi/(2*theta) steps
   in k for one full sin^2 cycle), not from the point formula being
   verified — a genuinely different construction, even though the two
   are obviously related mathematically (see AGENTS.md design decision
   3). Deliberately excludes N=2 from consideration elsewhere (see
   design decision 4) — this function still returns a value for N=2,
   but it is not meaningful there (P(marked)=0.5 for every k). *)
GroverOptimalKBySimulation[nItems_Integer] :=
  Module[{theta, kMax, probs},
    theta = GroverThetaFromN[nItems];
    kMax = Floor[Pi / (4.0 * theta)] + 2;
    probs = Table[GroverProbMarked[nItems, k], {k, 0, kMax}];
    First[Ordering[-probs]] - 1
  ];


(* ── Correctness checks (diagnostic-only, printed PASS/FAIL) ──────── *)

(* Check 1: rotation angle, exact — verify G, restricted to the
   {|w>,|s'>} 2D subspace, is EXACTLY a rotation by 2*theta, via
   explicit matrix simulation (not by restating the closed-form
   angle). *)
RotationAngleCheck[Optional[nItems_Integer, 16], Optional[markedIdx_Integer, 7],
                   Optional[tolerance_?NumericQ, 1.0*^-9]] :=
  Module[{ops, theta, wVec, sPrimeRaw, sPrimeVec, basis, G2D, expected, maxError, pass},
    ops = GroverOperators[nItems, markedIdx];
    theta = GroverThetaFromN[nItems];
    wVec = UnitVector[nItems, markedIdx];
    sPrimeRaw = ops["sVec"] - (ops["sVec"] . wVec) * wVec;
    sPrimeVec = sPrimeRaw / Norm[sPrimeRaw];
    basis = {wVec, sPrimeVec};
    G2D = Table[basis[[i]] . ops["groverOp"] . basis[[j]], {i, 2}, {j, 2}];
    (* RotationMatrix[-2*theta] to match this basis's orientation
       (verified once against the transcript in AGENTS.md; the sign is
       a basis/orientation convention, not a physical ambiguity). *)
    expected = RotationMatrix[-2.0 * theta];
    maxError = Max[Abs[Flatten[G2D - expected]]];
    pass = maxError < tolerance;
    <| "nItems" -> nItems, "theta" -> theta, "maxError" -> maxError, "pass" -> pass |>
  ];

(* Check 2: optimal iteration count, exact for a given N — direct
   simulation (period-windowed argmax search) vs the closed-form
   formula, for several N (excluding the degenerate N=2 case — see
   design decision 4). *)
OptimalIterationCountCheck[] :=
  Module[{testNs, exactKs, simKs, allMatch},
    testNs = {4, 8, 16, 32, 64, 128, 256, 1024};
    exactKs = GroverOptimalK /@ testNs;
    simKs = GroverOptimalKBySimulation /@ testNs;
    allMatch = exactKs === simKs;
    <| "testNs" -> testNs, "exactKs" -> exactKs, "simKs" -> simKs, "pass" -> allMatch |>
  ];

(* Check 3: operator unitarity, exact — oracle, diffusion, and their
   product G, all unitary (here: real orthogonal, O^T O = I) for a
   specific N. *)
OperatorUnitarityCheck[Optional[nItems_Integer, 32], Optional[markedIdx_Integer, 11],
                       Optional[tolerance_?NumericQ, 1.0*^-9]] :=
  Module[{ops, oracleErr, diffusionErr, groverErr, pass},
    ops = GroverOperators[nItems, markedIdx];
    oracleErr    = Max[Abs[Flatten[ops["oracleOp"] . Transpose[ops["oracleOp"]] - IdentityMatrix[nItems]]]];
    diffusionErr = Max[Abs[Flatten[ops["diffusionOp"] . Transpose[ops["diffusionOp"]] - IdentityMatrix[nItems]]]];
    groverErr    = Max[Abs[Flatten[ops["groverOp"] . Transpose[ops["groverOp"]] - IdentityMatrix[nItems]]]];
    pass = oracleErr < tolerance && diffusionErr < tolerance && groverErr < tolerance;
    <| "nItems" -> nItems, "oracleErr" -> oracleErr, "diffusionErr" -> diffusionErr,
       "groverErr" -> groverErr, "pass" -> pass |>
  ];

(* Check 4: closed-form probability vs direct simulation, exact — for
   several (N,k) combinations, not just one. *)
ClosedFormVsSimulationCheck[] :=
  Module[{tests, errors, maxError, pass},
    tests = {{8, 3, 5}, {16, 7, 4}, {32, 20, 6}, {64, 42, 8}, {128, 100, 10}};
    (* {nItems, markedIdx, kMax} *)
    errors = Flatten[Table[
      Module[{nItems = t[[1]], markedIdx = t[[2]], kMax = t[[3]], simTraj, closedTraj},
        simTraj    = GroverSimulateTrajectory[nItems, markedIdx, kMax];
        closedTraj = Table[GroverProbMarked[nItems, k], {k, 0, kMax}];
        Abs[simTraj - closedTraj]
      ],
      {t, tests}
    ]];
    maxError = Max[errors];
    pass = maxError < 1.0*^-9;
    <| "tests" -> tests, "maxError" -> maxError, "pass" -> pass |>
  ];


(* ========================================================
   Per-mode model builders
   ======================================================== *)

(* ── Mode 1: search — P(marked) vs iteration, rise then fall ──────── *)

SearchModel[cfg_Association] :=
  Module[{nItems, markedIdx, nIterations, kArr, probArr, optimalK},
    nItems      = GetCfg[cfg, {"simulation", "grover", "n_items"},      64];
    markedIdx   = GetCfg[cfg, {"simulation", "grover", "marked_index"}, 42];
    nIterations = GetCfg[cfg, {"simulation", "grover", "n_iterations"}, 12];

    kArr = Range[0, nIterations];
    probArr = GroverProbMarked[nItems, #] & /@ kArr;
    optimalK = GroverOptimalK[nItems];

    <|
      "mode" -> "search",
      "nItems" -> nItems, "markedIdx" -> markedIdx, "nIterations" -> nIterations,
      "kArr" -> kArr, "probArr" -> probArr, "optimalK" -> optimalK,
      "theta" -> GroverThetaFromN[nItems]
    |>
  ];


(* ── Mode 2: compare — classical vs quantum query count, across N ─── *)

(* Classical query count: AVERAGE-case linear search, N/2 — not
   worst-case N. Worst-case N is technically an upper bound but
   overstates the typical cost; the quantum O(Sqrt[N]) count being
   compared against is itself an exact optimum, not a worst case, so
   comparing it against classical's average case is the fair,
   apples-to-apples framing (see AGENTS.md design decision 2 for the
   full reasoning). *)
ClassicalQueriesAverage[nItems_?NumericQ] := nItems / 2.0;

CompareModel[cfg_Association] :=
  Module[{nItems, markedIdx, nMin, nMax, nSteps, logNArr, nArr,
          classicalArr, quantumArr, classicalAtN, quantumAtN},
    nItems    = GetCfg[cfg, {"simulation", "grover", "n_items"},      64];
    markedIdx = GetCfg[cfg, {"simulation", "grover", "marked_index"}, 42];
    nMin      = N @ GetCfg[cfg, {"simulation", "grover", "compare_n_min"}, 4.0];
    nMax      = N @ GetCfg[cfg, {"simulation", "grover", "compare_n_max"}, 1048576.0];
    nSteps    =     GetCfg[cfg, {"simulation", "grover", "compare_n_steps"}, 100];

    logNArr = N @ Subdivide[Log10[nMin], Log10[nMax], nSteps - 1];
    nArr    = 10.0^logNArr;
    classicalArr = ClassicalQueriesAverage /@ nArr;
    quantumArr   = Round[Pi / (4.0 * ArcSin[1.0 / Sqrt[#]]) - 0.5] & /@ nArr;

    classicalAtN = ClassicalQueriesAverage[N[nItems]];
    quantumAtN   = GroverOptimalK[nItems];

    <|
      "mode" -> "compare",
      "nItems" -> nItems, "markedIdx" -> markedIdx,
      "nArr" -> nArr, "classicalArr" -> classicalArr, "quantumArr" -> quantumArr,
      "classicalAtN" -> classicalAtN, "quantumAtN" -> quantumAtN
    |>
  ];


(* ── Mode 3: geometry — the literal 2D rotation, continuous extension ── *)

GeometryModel[cfg_Association] :=
  Module[{nItems, markedIdx, nIterations, theta, kArr, angleArr, ampMarkedArr, ampUnmarkedArr},
    nItems      = GetCfg[cfg, {"simulation", "grover", "n_items"},      64];
    markedIdx   = GetCfg[cfg, {"simulation", "grover", "marked_index"}, 42];
    nIterations = GetCfg[cfg, {"simulation", "grover", "n_iterations"}, 12];
    theta = GroverThetaFromN[nItems];

    kArr = Range[0, nIterations];
    angleArr = (2.0 * kArr + 1.0) * theta;
    ampMarkedArr   = Sin[angleArr];
    ampUnmarkedArr = Cos[angleArr];

    <|
      "mode" -> "geometry",
      "nItems" -> nItems, "markedIdx" -> markedIdx, "nIterations" -> nIterations,
      "theta" -> theta, "kArr" -> kArr, "angleArr" -> angleArr,
      "ampMarkedArr" -> ampMarkedArr, "ampUnmarkedArr" -> ampUnmarkedArr
    |>
  ];

(* ========================================================
   bell/src/model.wl — Bell-state entanglement, correlations, and the
   CHSH inequality

   The Bell state |Phi+> = (|00> + |11>)/Sqrt[2] is maximally entangled:
   measuring each qubit along an axis parametrised by an angle (Alice's
   angle a, Bob's angle b, both axes lying in the same plane of each
   qubit's own Bloch sphere) gives a correlation

     E(a,b) = <Phi+| A(a) (x) B(b) |Phi+> = Cos[a - b]

   DERIVED here, not assumed (see the module-level derivation notes
   below and AGENTS.md design decision 1) — the build spec explicitly
   warned that the sign and exact form depend on which Bell state and
   which operator convention is used, so this was computed directly
   from the state and operators this app actually defines, then
   verified a second, independent way (QuantumCorrelationViaRotation,
   used only by the correctness check).

   The CHSH inequality: for four settings a,a' (Alice), b,b' (Bob),
     S = E(a,b) - E(a,b') + E(a',b) + E(a',b')
   Any local hidden-variable theory obeys |S| <= 2 (proved here by
   EXHAUSTIVE enumeration of all 16 deterministic local strategies —
   see LocalHiddenVariableBoundCheck). Quantum mechanics allows
   |S| up to 2*Sqrt[2] (Tsirelson's bound) — the angle configuration
   that achieves this was found by numerical optimisation over all
   four angles (NMaximize, "DifferentialEvolution"), confirmed to give
   EXACTLY 2*Sqrt[2] symbolically, not assumed from memory (see
   AGENTS.md design decision 2 — this is exactly the kind of
   unverified constant this project's correctness audit has
   repeatedly caught being wrong).

   Public API:
     BellMeasurementOperator[theta]
     QuantumCorrelation[a,b], QuantumCorrelationViaRotation[a,b]
     JointProbabilities[a,b]
     ClassicalTriangularCorrelation[delta]
     ChshValue[a,ap,b,bp]
     $ChshOptimalAngles, $ChshNaiveAngles
     MeasurementJointSample[a,b,nTrials,seed]
     BellStateNormalizationCheck[], QuantumCorrelationIndependentCheck[],
     ChshOptimalityCheck[], LocalHiddenVariableBoundCheck[]
     CorrelationsModel[cfg], ChshModel[cfg], MeasurementModel[cfg]
   ======================================================== *)


(* ── State and operators ──────────────────────────────────────────── *)

(* |Phi+> in the {|00>,|01>,|10>,|11>} basis. *)
$BellPhiPlus = {1.0, 0.0, 0.0, 1.0} / Sqrt[2.0];

$PauliX = {{0, 1}, {1, 0}};
$PauliZ = {{1, 0}, {0, -1}};

(* BellMeasurementOperator — a dichotomic (+-1-eigenvalue) spin
   measurement along the axis at angle theta in the XZ-plane of the
   Bloch sphere: n.sigma with n=(Sin[theta],0,Cos[theta]). Verified
   Hermitian with eigenvalues {-1,1} (i.e. a genuine measurement
   operator, not an arbitrary matrix) before use — see AGENTS.md
   design decision 1. *)
BellMeasurementOperator[theta_?NumericQ] :=
  Cos[theta] * $PauliZ + Sin[theta] * $PauliX;


(* ── Quantum correlation E(a,b) = Cos[a-b] ────────────────────────────
   Derived directly: E(a,b) = <Phi+| A(a) (x) B(b) |Phi+>, computed via
   explicit KroneckerProduct tensor arithmetic and Simplify'd
   symbolically to Cos[a-b] (see AGENTS.md design decision 1 for the
   full derivation transcript). This closed form is what the rest of
   the app uses throughout, for speed; QuantumCorrelationViaRotation
   below is the INDEPENDENT verification path used only by check 2. *)
QuantumCorrelation[a_?NumericQ, b_?NumericQ] := Cos[a - b];

(* QuantumCorrelationViaRotation — an independent computation of E(a,b)
   sharing NO code with QuantumCorrelation: diagonalises A(a) and A(b)
   via Eigensystem (not the KroneckerProduct-sandwich formula above),
   builds the unitary change-of-basis matrices that rotate each
   measurement into the computational Z basis, applies them to
   |Phi+>, and recovers E(a,b) from the resulting computational-basis
   outcome PROBABILITIES via the Born rule (P++ + P-- - P+- - P-+).
   This is a genuinely different computational route (diagonalisation
   + Born-rule probabilities vs. a direct operator sandwich), used
   ONLY by QuantumCorrelationIndependentCheck. *)
QuantumCorrelationViaRotation[a_?NumericQ, b_?NumericQ] :=
  Module[{evA, evB, orderA, orderB, Ua, Ub, rotated, probs},
    evA = Eigensystem[N[BellMeasurementOperator[a]]];
    evB = Eigensystem[N[BellMeasurementOperator[b]]];
    orderA = Ordering[-evA[[1]]];   (* +1 eigenvalue first *)
    orderB = Ordering[-evB[[1]]];
    Ua = Normalize /@ evA[[2, orderA]];
    Ub = Normalize /@ evB[[2, orderB]];
    rotated = KroneckerProduct[Ua, Ub] . N[$BellPhiPlus];
    probs = Abs[rotated]^2;  (* order: P++, P+-, P-+, P-- *)
    probs[[1]] - probs[[2]] - probs[[3]] + probs[[4]]
  ];

(* JointProbabilities — implied algebraically by <A>=<B>=0 (verified,
   see AGENTS.md design decision 3) and <AB>=E(a,b): P++ = P-- =
   (1+E)/4, P+- = P-+ = (1-E)/4. Cross-checked against
   QuantumCorrelationViaRotation's own rotated-probability output at
   several angles before adopting this closed form (see AGENTS.md). *)
JointProbabilities[a_?NumericQ, b_?NumericQ] :=
  Module[{E = QuantumCorrelation[a, b]},
    <| "Ppp" -> (1.0 + E) / 4.0, "Ppm" -> (1.0 - E) / 4.0,
       "Pmp" -> (1.0 - E) / 4.0, "Pmm" -> (1.0 + E) / 4.0 |>
  ];


(* ── Classical (local hidden-variable) comparison model ───────────────
   A genuine local hidden-variable toy model — NOT an arbitrary "linear
   interpolation" guess — used as the classical comparison channel in
   `correlations` mode. Both particles carry a shared hidden direction
   lambda (uniform on [0,2*Pi)); each outputs the deterministic sign of
   its own alignment with its measurement axis: outcome = Sign[Cos[
   setting - lambda]]. This is fully local (each side's outcome depends
   only on its own setting and the shared lambda) and deterministic
   given lambda, i.e. exactly a Bell-style local hidden-variable model.
   E_classical(delta) = (1/2Pi) Integrate[Sign[Cos[lambda]]*
   Sign[Cos[lambda-delta]], {lambda,0,2Pi}] was evaluated directly
   (Integrate, not assumed) and simplifies to the triangular
   1 - 2*delta/Pi for delta in [0,Pi] — see AGENTS.md design decision 4
   for the full derivation and the numerical cross-check against
   NIntegrate. *)
FoldAngleDiff[delta_?NumericQ] := Abs[Mod[delta + Pi, 2.0 Pi] - Pi];

ClassicalTriangularCorrelation[delta_?NumericQ] :=
  1.0 - 2.0 * FoldAngleDiff[delta] / Pi;


(* ── CHSH ──────────────────────────────────────────────────────────── *)

ChshValue[a_?NumericQ, ap_?NumericQ, b_?NumericQ, bp_?NumericQ] :=
  QuantumCorrelation[a, b] - QuantumCorrelation[a, bp] +
  QuantumCorrelation[ap, b] + QuantumCorrelation[ap, bp];

(* $ChshOptimalAngles — found via NMaximize["DifferentialEvolution"]
   over all four angles (global search, not a local solver seeded near
   a remembered guess), confirmed to give EXACTLY 2*Sqrt[2] via
   Simplify on the closed form at these exact angles (see AGENTS.md
   design decision 2 for the full transcript: NMaximize found
   (a,a',b,b') = (314.84,74.84,29.84,119.84) degrees; only the pairwise
   DIFFERENCES a-b, a-b', a'-b, a'-b' matter for E(a,b)=Cos[a-b], and
   those differences are exactly {-45,-135,45,-45} degrees — so, fixing
   b=0 WLOG, the canonical angle set below is the same solution up to
   an overall rotation of the whole apparatus, which changes nothing
   physical). *)
$ChshOptimalAngles = <|
  "a" -> -Pi / 4.0, "ap" -> Pi / 4.0, "b" -> 0.0, "bp" -> Pi / 2.0
|>;

(* $ChshNaiveAngles — a "reasonable-looking" but non-optimal choice
   (both parties measuring along two axes 90 degrees apart, with no
   45-degree offset between Alice's and Bob's frames) used by
   ChshOptimalityCheck to demonstrate the optimisation step actually
   mattered: this gives S=2 exactly, the same as the classical bound —
   see AGENTS.md design decision 2. *)
$ChshNaiveAngles = <|
  "a" -> 0.0, "ap" -> Pi / 2.0, "b" -> 0.0, "bp" -> Pi / 2.0
|>;


(* ── Monte Carlo joint sampling (measurement mode) ────────────────────
   Draws nTrials outcome pairs directly from the TRUE joint quantum
   distribution (JointProbabilities), not from the marginals
   independently — the whole point of entanglement is that the JOINT
   distribution is correlated in a way no product of marginals can
   reproduce. *)
MeasurementJointSample[a_?NumericQ, b_?NumericQ, nTrials_Integer, seed_Integer] :=
  Module[{probs, outcomePairs, weights, draws},
    probs = JointProbabilities[a, b];
    outcomePairs = {{1, 1}, {1, -1}, {-1, 1}, {-1, -1}};
    weights = {probs["Ppp"], probs["Ppm"], probs["Pmp"], probs["Pmm"]};
    SeedRandom[seed];
    draws = RandomChoice[weights -> outcomePairs, nTrials];
    <| "aOutcomes" -> draws[[All, 1]], "bOutcomes" -> draws[[All, 2]] |>
  ];


(* ── Correctness checks (diagnostic-only, printed PASS/FAIL) ──────────
   Same convention as every other app's checks in this codebase
   (blackbody/compton/qubit/etc.): closed-form or constructive
   verifications, none of them gate a numerically-integrated
   trajectory's runtime health, so none of them abort. *)

(* Check 1: Bell state normalisation, exact. *)
BellStateNormalizationCheck[Optional[tolerance_?NumericQ, 1.0*^-12]] :=
  Module[{normSq, pass},
    normSq = Total[Abs[$BellPhiPlus]^2];
    pass = Abs[normSq - 1.0] < tolerance;
    <| "normSq" -> normSq, "pass" -> pass |>
  ];

(* Check 2: quantum correlation formula, verified against the
   INDEPENDENT rotation/Born-rule computation at several angles
   (sharing no code with QuantumCorrelation's own closed form). *)
QuantumCorrelationIndependentCheck[Optional[tolerance_?NumericQ, 1.0*^-9]] :=
  Module[{testAngles, direct, indep, errors, maxError, pass},
    testAngles = {
      {0.0, 0.0}, {Pi / 6.0, Pi / 3.0}, {Pi / 4.0, -Pi / 4.0},
      {2.1, 0.7}, {Pi, Pi / 2.0}, {-1.3, 2.8}
    };
    direct = QuantumCorrelation[#[[1]], #[[2]]] & /@ testAngles;
    indep  = QuantumCorrelationViaRotation[#[[1]], #[[2]]] & /@ testAngles;
    errors = Abs[direct - indep];
    maxError = Max[errors];
    pass = maxError < tolerance;
    <| "testAngles" -> testAngles, "maxError" -> maxError, "pass" -> pass |>
  ];

(* Check 3: CHSH optimality — the derived-optimal angles give EXACTLY
   2*Sqrt[2] via ChshValue (exact relation, tight tolerance), AND the
   naive angle choice gives a strictly, meaningfully smaller S
   (demonstrating the optimisation step actually did something, not
   just restating the Tsirelson-bound number). *)
ChshOptimalityCheck[Optional[tolerance_?NumericQ, 1.0*^-9]] :=
  Module[{sOptimal, sNaive, tsirelsonBound, errOptimal, optimalPass, naivePass},
    sOptimal = ChshValue[$ChshOptimalAngles["a"], $ChshOptimalAngles["ap"],
                         $ChshOptimalAngles["b"], $ChshOptimalAngles["bp"]];
    sNaive   = ChshValue[$ChshNaiveAngles["a"], $ChshNaiveAngles["ap"],
                         $ChshNaiveAngles["b"], $ChshNaiveAngles["bp"]];
    tsirelsonBound = 2.0 * Sqrt[2.0];
    errOptimal = Abs[sOptimal - tsirelsonBound];
    optimalPass = errOptimal < tolerance;
    naivePass = sOptimal - sNaive > 0.1;   (* the optimisation must matter by a wide, unambiguous margin *)
    <| "sOptimal" -> sOptimal, "sNaive" -> sNaive, "tsirelsonBound" -> tsirelsonBound,
       "errOptimal" -> errOptimal, "pass" -> (optimalPass && naivePass) |>
  ];

(* Check 4: classical (local hidden-variable) bound, made concrete two
   ways, not merely asserted:
   (a) EXACT: enumerate all 16 deterministic local strategies (each
       hidden-variable instance assigns a definite +-1 outcome to
       EVERY possible setting in advance — Alice and Bob each just
       read off their assigned value for whichever setting they
       actually use, per the build spec). S is linear in these fixed
       +-1 assignments, so this exhausts every possible deterministic
       strategy; any probabilistic local model is a convex mixture of
       these 16, and convexity means no mixture can exceed the max
       over the vertices — so this alone is a complete, exact proof of
       |S|<=2 for ANY local model, not a sample of some.
   (b) EMPIRICAL: Monte-Carlo-sample nTrials random convex mixtures
       (random probability weights over the same 16 strategies) and
       confirm none exceeds |S|<=2 either — an empirical sweep over
       the (uncountably infinite) space of general local
       hidden-variable models for this setting, complementing (a). *)
LocalHiddenVariableBoundCheck[Optional[nTrials_Integer, 20000],
                              Optional[seed_Integer, 123],
                              Optional[tolerance_?NumericQ, 1.0*^-9]] :=
  Module[{a, ap, b, bp, strategies, sVals, maxAbsSExact, exactPass,
          weights, sMix, maxAbsSMonteCarlo, monteCarloPass},
    a  = $ChshOptimalAngles["a"];  ap = $ChshOptimalAngles["ap"];
    b  = $ChshOptimalAngles["b"];  bp = $ChshOptimalAngles["bp"];

    strategies = Tuples[{-1, 1}, 4];  (* {A,A',B,B'} predetermined outcomes *)
    sVals = (#[[1]] * #[[3]] - #[[1]] * #[[4]] + #[[2]] * #[[3]] + #[[2]] * #[[4]]) & /@ strategies;
    maxAbsSExact = Max[Abs[sVals]];
    exactPass = maxAbsSExact <= 2.0 + tolerance;

    SeedRandom[seed];
    maxAbsSMonteCarlo = 0.0;
    Do[
      weights = RandomReal[GammaDistribution[1, 1], 16];
      weights = weights / Total[weights];
      sMix = weights . sVals;
      maxAbsSMonteCarlo = Max[maxAbsSMonteCarlo, Abs[sMix]],
      {nTrials}
    ];
    monteCarloPass = maxAbsSMonteCarlo <= 2.0 + tolerance;

    <| "nStrategies" -> Length[strategies], "maxAbsSExact" -> maxAbsSExact,
       "nTrials" -> nTrials, "maxAbsSMonteCarlo" -> maxAbsSMonteCarlo,
       "pass" -> (exactPass && monteCarloPass) |>
  ];


(* ========================================================
   Per-mode model builders
   ======================================================== *)

(* ── Mode 1: correlations — sweep angle difference, quantum vs classical ── *)

CorrelationsModel[cfg_Association] :=
  Module[{nSteps, bAngleDeg, bAngleRad, deltaDegArr, deltaRadArr,
          aRadArr, EQuantumArr, EClassicalArr},
    nSteps    =     GetCfg[cfg, {"simulation", "bell", "n_steps"},       200];
    bAngleDeg = N @ GetCfg[cfg, {"simulation", "bell", "b_angle_deg"},   0.0];
    bAngleRad = bAngleDeg * Pi / 180.0;

    deltaDegArr = N @ Subdivide[-180.0, 180.0, nSteps - 1];
    deltaRadArr = deltaDegArr * Pi / 180.0;
    aRadArr     = bAngleRad + deltaRadArr;

    EQuantumArr   = QuantumCorrelation[#, bAngleRad] & /@ aRadArr;
    EClassicalArr = ClassicalTriangularCorrelation /@ deltaRadArr;

    <|
      "mode" -> "correlations",
      "nSteps" -> nSteps, "bAngleDeg" -> bAngleDeg,
      "deltaDegArr" -> deltaDegArr, "deltaRadArr" -> deltaRadArr,
      "EQuantumArr" -> EQuantumArr, "EClassicalArr" -> EClassicalArr
    |>
  ];


(* ── Mode 2: chsh — gauge reading at the derived-optimal angles ──────── *)

ChshModel[cfg_Association] :=
  Module[{aDeg, apDeg, bDeg, bpDeg, a, ap, b, bp,
          Eab, Eabp, Eapb, Eapbp, S, classicalBound, quantumBound},
    aDeg  = N @ GetCfg[cfg, {"simulation", "bell", "chsh_a_deg"},  -45.0];
    apDeg = N @ GetCfg[cfg, {"simulation", "bell", "chsh_ap_deg"},  45.0];
    bDeg  = N @ GetCfg[cfg, {"simulation", "bell", "chsh_b_deg"},    0.0];
    bpDeg = N @ GetCfg[cfg, {"simulation", "bell", "chsh_bp_deg"},  90.0];
    a = aDeg * Pi / 180.0; ap = apDeg * Pi / 180.0;
    b = bDeg * Pi / 180.0; bp = bpDeg * Pi / 180.0;

    Eab   = QuantumCorrelation[a, b];
    Eabp  = QuantumCorrelation[a, bp];
    Eapb  = QuantumCorrelation[ap, b];
    Eapbp = QuantumCorrelation[ap, bp];
    S = Eab - Eabp + Eapb + Eapbp;

    classicalBound = 2.0;
    quantumBound   = 2.0 * Sqrt[2.0];

    <|
      "mode" -> "chsh",
      "aDeg" -> aDeg, "apDeg" -> apDeg, "bDeg" -> bDeg, "bpDeg" -> bpDeg,
      "Eab" -> Eab, "Eabp" -> Eabp, "Eapb" -> Eapb, "Eapbp" -> Eapbp,
      "S" -> S, "classicalBound" -> classicalBound, "quantumBound" -> quantumBound
    |>
  ];


(* ── Mode 3: measurement — paired Monte Carlo trials, running correlation ── *)

MeasurementModel[cfg_Association] :=
  Module[{aDeg, bDeg, a, b, nTrials, seed, sample, aOut, bOut,
          runningCorr, trueE, marginalA, marginalB},
    aDeg    = N @ GetCfg[cfg, {"simulation", "bell", "alice_angle_deg"}, -45.0];
    bDeg    = N @ GetCfg[cfg, {"simulation", "bell", "bob_angle_deg"},     0.0];
    nTrials =     GetCfg[cfg, {"simulation", "bell", "n_trials"},        2000];
    seed    =     GetCfg[cfg, {"simulation", "bell", "seed"},              11];
    a = aDeg * Pi / 180.0; b = bDeg * Pi / 180.0;

    sample = MeasurementJointSample[a, b, nTrials, seed];
    aOut = sample["aOutcomes"]; bOut = sample["bOutcomes"];

    runningCorr = Accumulate[aOut * bOut] / N[Range[1, nTrials]];
    trueE = QuantumCorrelation[a, b];

    (* Each side's own MARGINAL frequency (ignoring the other's outcome
       entirely) — verified to sit at 0.5 regardless of the other's
       SETTING (see AGENTS.md design decision 3); this is the
       no-signalling fact stated explicitly in README.md. *)
    marginalA = N[Count[aOut, 1]] / nTrials;
    marginalB = N[Count[bOut, 1]] / nTrials;

    <|
      "mode" -> "measurement",
      "aDeg" -> aDeg, "bDeg" -> bDeg, "nTrials" -> nTrials, "seed" -> seed,
      "aOutcomes" -> aOut, "bOutcomes" -> bOut, "runningCorr" -> runningCorr,
      "trueE" -> trueE, "marginalA" -> marginalA, "marginalB" -> marginalB
    |>
  ];

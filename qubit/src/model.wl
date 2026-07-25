(* ========================================================
   qubit/src/model.wl — single-qubit states, gates, Rabi
   oscillation, and measurement.

   State convention: a pure qubit state is stored as a 2-component
   complex vector {alpha, beta} = alpha|0> + beta|1>, |alpha|^2+|beta|^2=1.

   Bloch sphere convention (verified before use — see AGENTS.md):
     |psi> = Cos[theta/2]|0> + Exp[I phi] Sin[theta/2]|1>
     r = (sin(theta)cos(phi), sin(theta)sin(phi), cos(theta))
   Equivalently, via Pauli expectation values (the form actually used
   throughout this file, since it needs no particular phase gauge on
   alpha,beta — verified to agree with the theta,phi form exactly):
     r_x = <psi|sigma_x|psi> = 2 Re[Conjugate[alpha] beta]
     r_y = <psi|sigma_y|psi> = 2 Im[Conjugate[alpha] beta]
     r_z = <psi|sigma_z|psi> = |alpha|^2 - |beta|^2

   Public API:
     GateMatrix[name] -- 2x2 unitary for "X","Y","Z","H","S","T",
                          or "Rx:theta"/"Ry:theta"/"Rz:theta"
     BlochVector[alpha,beta]
     ApplyGate[{alpha,beta}, U]
     GatesTrajectory[{alpha0,beta0}, gateNames, nStepsPerGate]
     RabiProbability1[Omega,t], RabiSchrodingerCheck[]
     MeasurementTrials[alpha,beta,nTrials,seed]
     Four correctness checks: GateUnitarityCheck[], BlochLengthCheck[],
     RabiFormulaCheck[], BornRuleMonteCarloCheck[]
   ======================================================== *)


(* ── Gate matrices ────────────────────────────────────────────────── *)

$PauliX = {{0, 1}, {1, 0}};
$PauliY = {{0, -I}, {I, 0}};
$PauliZ = {{1, 0}, {0, -1}};

GateH[] := N[(1.0/Sqrt[2.0]) * {{1, 1}, {1, -1}}];
GateS[] := {{1.0, 0.0}, {0.0, I}};
GateT[] := {{1.0, 0.0}, {0.0, Exp[I*Pi/4.0]}};

(* Rx/Ry/Rz — verified to equal MatrixExp[-I*theta/2*Pauli] exactly
   (to machine precision) before use, not just "look like" the
   textbook forms. *)
GateRx[theta_?NumericQ] := {{Cos[theta/2.0], -I*Sin[theta/2.0]},
                             {-I*Sin[theta/2.0], Cos[theta/2.0]}};
GateRy[theta_?NumericQ] := {{Cos[theta/2.0], -Sin[theta/2.0]},
                             {Sin[theta/2.0], Cos[theta/2.0]}};
GateRz[theta_?NumericQ] := {{Exp[-I*theta/2.0], 0.0}, {0.0, Exp[I*theta/2.0]}};

(* GateMatrix — dispatcher. Plain names ("X","Y","Z","H","S","T") for
   the fixed gates; "Rx:1.5708" (colon-separated angle in radians) for
   the parametrized rotations, since config.json is JSON and a gate
   sequence is most naturally a flat list of strings. *)
GateMatrix[name_String] :=
  Module[{parts},
    If[StringContainsQ[name, ":"],
      parts = StringSplit[name, ":"];
      Switch[parts[[1]],
        "Rx", GateRx[ToExpression[parts[[2]]]],
        "Ry", GateRy[ToExpression[parts[[2]]]],
        "Rz", GateRz[ToExpression[parts[[2]]]],
        _, $Failed
      ],
      Switch[name,
        "X", N[$PauliX], "Y", N[$PauliY], "Z", N[$PauliZ],
        "H", GateH[], "S", GateS[], "T", GateT[],
        _, $Failed
      ]
    ]
  ];

$AllFixedGateNames = {"X", "Y", "Z", "H", "S", "T"};


(* ── Bloch vector and gate action ────────────────────────────────── *)

BlochVector[alpha_, beta_] :=
  {2.0*Re[Conjugate[alpha]*beta], 2.0*Im[Conjugate[alpha]*beta], Abs[alpha]^2 - Abs[beta]^2};

ApplyGate[{alpha_, beta_}, U_] :=
  Module[{result = U.{alpha, beta}}, {result[[1]], result[[2]]}];


(* ── Bloch-vector rotation matrix induced by a gate ──────────────────
   R_ij = (1/2) Tr[sigma_i . U . sigma_j . U^dagger] — the 3x3 real
   rotation on the Bloch vector induced by conjugation rho'=U rho U^dagger.
   Global-phase-invariant by construction (U and Exp[I*phase]*U give
   identical R), which is exactly right since global phase has no
   physical effect on the Bloch vector. *)
BlochRotationMatrix[U_] :=
  Module[{Ud = ConjugateTranspose[U], paulis = {$PauliX, $PauliY, $PauliZ}},
    Table[
      (1.0/2.0) * Re[Tr[paulis[[i]] . U . paulis[[j]] . Ud]],
      {i, 3}, {j, 3}
    ]
  ];

(* AxisAngleFromR — robust axis/angle extraction. The naive formula
   (axis proportional to R's antisymmetric part, divided by Sin[angle])
   DIVIDES BY ZERO at angle=Pi — discovered while verifying this app's
   own gates: X, Y, Z, and H are all EXACTLY 180-degree rotations, so
   this is not an edge case here, it's the common case. Falls back to
   the symmetric-part method (axis.axis^T = (R+I)/2 at angle=Pi) when
   angle is close to Pi. Used only for the `gates` mode ANIMATION path
   (see GateRotationPath below) — none of the four correctness checks
   depend on this extraction, they act on the exact 2x2 matrices
   directly, so this function's ~1e-8 numerical precision near
   angle=Pi (from ArcCos's own ill-conditioning near cos=-1) has no
   bearing on correctness, only on animation smoothness. *)
AxisAngleFromR[R_] :=
  Module[{tr, angle, axis, antiSym, symPart, pivotIdx},
    tr = Tr[R];
    angle = ArcCos[Clip[(tr - 1.0) / 2.0, {-1.0, 1.0}]];
    Which[
      Abs[angle] < 10^-8,
        axis = {0.0, 0.0, 1.0},
      Abs[angle - Pi] < 10^-6,
        symPart = (R + IdentityMatrix[3]) / 2.0;
        pivotIdx = First[Ordering[-Diagonal[symPart]]];
        axis = symPart[[All, pivotIdx]] / Sqrt[symPart[[pivotIdx, pivotIdx]]],
      True,
        antiSym = {R[[3, 2]] - R[[2, 3]], R[[1, 3]] - R[[3, 1]], R[[2, 1]] - R[[1, 2]]};
        axis = antiSym / (2.0 * Sin[angle])
    ];
    <| "axis" -> axis, "angle" -> angle |>
  ];

(* GateRotationPath — the continuous family of Bloch vectors traced
   out as a gate's rotation is applied gradually from s=0 (identity)
   to s=1 (the full gate), sampled at nSteps+1 points. This is what
   makes `gates` mode's animation/sonification a genuine continuous
   ROTATION rather than a discrete jump — a gate physically IS a
   rotation of the Bloch vector about some axis, so animating that
   rotation continuously (rather than snapping between states) is the
   physically honest choice, not just a visual embellishment. *)
GateRotationPath[rStart_List, gateName_String, nSteps_Integer] :=
  Module[{U, R, aa, axis, angle},
    U = GateMatrix[gateName];
    R = BlochRotationMatrix[U];
    aa = AxisAngleFromR[R];
    axis = aa["axis"]; angle = aa["angle"];
    Table[RotationMatrix[s * angle, axis].rStart, {s, N[Subdivide[0.0, 1.0, nSteps]]}]
  ];

(* GatesTrajectory — applies a sequence of named gates to an initial
   state, returning BOTH the exact post-gate states (via the real 2x2
   unitary, for CSV export / the "what state are we actually in"
   record) AND the continuous Bloch-vector path through all gates
   concatenated (for animation/sonification). *)
GatesTrajectory[{alpha0_, beta0_}, gateNames_List, nStepsPerGate_Integer] :=
  Module[{state = {alpha0, beta0}, states, rPath, gateBoundaries, U, rCurrent, seg},
    states = {state};
    rCurrent = BlochVector[alpha0, beta0];
    rPath = {rCurrent};
    gateBoundaries = {1};
    Do[
      U = GateMatrix[gateNames[[k]]];
      seg = Rest[GateRotationPath[rCurrent, gateNames[[k]], nStepsPerGate]];
      rPath = Join[rPath, seg];
      rCurrent = Last[seg];
      state = ApplyGate[state, U];
      states = Append[states, state];
      AppendTo[gateBoundaries, Length[rPath]],
      {k, Length[gateNames]}
    ];
    <| "states" -> states, "rPath" -> rPath, "gateBoundaries" -> gateBoundaries,
       "gateNames" -> gateNames |>
  ];


(* ── Rabi oscillation ─────────────────────────────────────────────── *)

(* RabiProbability1 — closed-form solution for a qubit driven on
   resonance, H = -(Omega/2) sigma_x (rotating frame, hbar=1), starting
   in |0>. Derived and verified two independent ways before use (see
   AGENTS.md): matrix exponentiation of H, and direct NDSolve
   integration of the coupled Schrodinger equation for the two
   amplitudes — both agree with this closed form to ~1e-12 or better. *)
RabiProbability1[Omega_?NumericQ, t_?NumericQ] := Sin[Omega * t / 2.0]^2;

(* RabiSchrodingerSolve — independent verification path: integrates
   i c0'[t] = H11 c0 + H12 c1, i c1'[t] = H21 c0 + H22 c1 directly
   (H = -(Omega/2) sigma_x), from c0(0)=1,c1(0)=0, and returns P(1) at
   the requested times. Does NOT use RabiProbability1 anywhere in its
   own computation — this is what makes RabiFormulaCheck a genuine
   independent check of the closed form, not a restatement of it. *)
RabiSchrodingerSolve[Omega_?NumericQ, tVals_List] :=
  Module[{H, sol, c0fn, c1fn},
    H = -(Omega / 2.0) * N[$PauliX];
    sol = NDSolve[
      {I*c0'[t] == H[[1, 1]]*c0[t] + H[[1, 2]]*c1[t],
       I*c1'[t] == H[[2, 1]]*c0[t] + H[[2, 2]]*c1[t],
       c0[0] == 1.0, c1[0] == 0.0},
      {c0, c1}, {t, 0, Max[tVals]},
      MaxStepSize -> 0.001, PrecisionGoal -> 12, AccuracyGoal -> 12];
    c1fn = c1 /. First[sol];
    Abs[c1fn[#]]^2 & /@ tVals
  ];


(* ── Measurement (Monte Carlo, matching bayes/'s and clt/'s technique) ─
   MeasurementTrials — nTrials independent Born-rule measurements of a
   state {alpha,beta}: outcome 1 with probability |beta|^2, outcome 0
   with probability |alpha|^2 (SeedRandom'd for reproducible runs, the
   same convention scattering/'s random_seed and clt/'s SampleXbarN
   use). Returns outcomes (0/1 per trial) and the running EMPIRICAL
   frequency of outcome 0 via Accumulate — the quantity that should
   converge to |alpha|^2 as nTrials grows. *)
MeasurementTrials[alpha_, beta_, nTrials_Integer, seed_Integer] :=
  Module[{p1, outcomes, cumZeros, runningFreq0},
    p1 = Abs[beta]^2;
    SeedRandom[seed];
    outcomes = RandomVariate[BernoulliDistribution[p1], nTrials];
    cumZeros = Accumulate[1 - outcomes];
    runningFreq0 = cumZeros / N[Range[nTrials]];
    <| "outcomes" -> outcomes, "runningFreq0" -> runningFreq0,
       "trueP0" -> Abs[alpha]^2, "trueP1" -> p1, "nTrials" -> nTrials |>
  ];


(* ────────────────────────────────────────────────────────────
   Correctness checks — diagnostic-only (print PASS/FAIL, never
   abort), per blackbody/AGENTS.md §3.
   ──────────────────────────────────────────────────────────── *)

(* Check 1 — gate unitarity, exact. Every fixed gate plus three
   representative rotation angles, verified via U^dagger U = I to
   near-machine precision. *)
GateUnitarityCheck[tolerance_:10^-9] :=
  Module[{testGates, resids, maxResid},
    testGates = Join[$AllFixedGateNames, {"Rx:0.73", "Ry:1.9", "Rz:2.4"}];
    resids = Map[
      Function[name,
        Max[Abs[Flatten[ConjugateTranspose[GateMatrix[name]].GateMatrix[name] - IdentityMatrix[2]]]]
      ],
      testGates
    ];
    maxResid = Max[resids];
    <| "testGates" -> testGates, "resids" -> resids, "maxResid" -> maxResid,
       "pass" -> maxResid < tolerance |>
  ];

(* Check 2 — Bloch vector length conservation, exact. Applies several
   gates in a row and verifies |r|=1 after EVERY gate (not just the
   final one) — a check that only looked at the end state could miss
   an intermediate gate that briefly left the sphere and another that
   happened to bring it back. *)
BlochLengthCheck[tolerance_:10^-9] :=
  Module[{gateSeq, traj, lengths, maxErr},
    gateSeq = {"H", "T", "S", "X", "Ry:0.9", "H", "Z"};
    traj = GatesTrajectory[{1.0, 0.0}, gateSeq, 2];
    lengths = Norm /@ (BlochVector[#[[1]], #[[2]]] & /@ traj["states"]);
    maxErr = Max[Abs[lengths - 1.0]];
    <| "gateSeq" -> gateSeq, "lengths" -> lengths, "maxError" -> maxErr,
       "pass" -> maxErr < tolerance |>
  ];

(* Check 3 — Rabi formula, exact. Compares the closed form against an
   independently-integrated Schrodinger equation (RabiSchrodingerSolve,
   which shares no code with RabiProbability1) at several times. Exact
   relation (both sides solve the same, exactly-solvable ODE), tight
   tolerance. *)
RabiFormulaCheck[Optional[Omega_?NumericQ, 1.7], tolerance_:10^-6] :=
  Module[{tVals, closedForm, independent, maxErr},
    tVals = {0.5, 1.0, 1.5, 2.0, 3.0};
    closedForm  = RabiProbability1[Omega, #] & /@ tVals;
    independent = RabiSchrodingerSolve[Omega, tVals];
    maxErr = Max[Abs[closedForm - independent]];
    <| "tVals" -> tVals, "closedForm" -> closedForm, "independent" -> independent,
       "maxError" -> maxErr, "pass" -> maxErr < tolerance |>
  ];

(* Check 4 — Born rule via Monte Carlo, generous (statistically-sized)
   tolerance. Empirical frequency of outcome 0 over nTrials compared
   to the true |alpha|^2 using a binomial standard-error band
   (matching scattering/'s check 4 convention: >=4-sigma, with a
   floor so the tolerance never collapses to zero at small trial
   counts), rather than an arbitrary flat percentage. *)
BornRuleMonteCarloCheck[Optional[alpha_, 0.6], Optional[beta_, 0.8],
                        Optional[nTrials_Integer, 20000], Optional[seed_Integer, 314]] :=
  Module[{trials, p0True, empFreq0Final, sigma, tolFreq, pass},
    trials = MeasurementTrials[alpha, beta, nTrials, seed];
    p0True = trials["trueP0"];
    empFreq0Final = Last[trials["runningFreq0"]];
    sigma = Sqrt[Max[p0True * (1.0 - p0True) / nTrials, 10^-12]];
    tolFreq = Max[4.0 * sigma, 0.01];
    pass = Abs[empFreq0Final - p0True] <= tolFreq;
    <| "p0True" -> p0True, "empFreq0" -> empFreq0Final, "sigma" -> sigma,
       "tolFreq" -> tolFreq, "nTrials" -> nTrials, "pass" -> pass |>
  ];

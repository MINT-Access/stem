#!/usr/bin/env wolframscript

(* bell/tests/test_model.wl — Unit tests for the Bell-state model *)

$projectRoot  = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];

passed = 0; failed = 0;
AssertTrue[label_String, condition_] :=
  If[TrueQ[condition],
    Print["  PASS  ", label]; passed++,
    Print["  FAIL  ", label]; failed++
  ];

Print["=== bell/src/model.wl unit tests ==="];
Print[""];

(* ── BellMeasurementOperator ──────────────────────────────────────── *)
Print["-- BellMeasurementOperator --"];
AssertTrue["A(0) = PauliZ", BellMeasurementOperator[0.0] === N[$PauliZ]];
AssertTrue["A(Pi/2) = PauliX",
  Max[Abs[Flatten[BellMeasurementOperator[Pi/2.0] - N[$PauliX]]]] < 10^-12];
AssertTrue["A(theta) is Hermitian for a generic angle",
  Module[{A = BellMeasurementOperator[0.83]}, Max[Abs[Flatten[A - ConjugateTranspose[A]]]] < 10^-12]];
AssertTrue["A(theta)^2 = identity (eigenvalues +-1) for a generic angle",
  Module[{A = BellMeasurementOperator[0.83]}, Max[Abs[Flatten[A.A - IdentityMatrix[2]]]] < 10^-9]];
Print[""];

(* ── Bell state normalization ─────────────────────────────────────── *)
Print["-- Bell state --"];
AssertTrue["|Phi+> is normalized", Abs[Total[Abs[$BellPhiPlus]^2] - 1.0] < 10^-12];
Print[""];

(* ── Quantum correlation E(a,b) = Cos[a-b] ────────────────────────── *)
Print["-- QuantumCorrelation --"];
AssertTrue["E(a,a) = 1 (same setting, perfect correlation)",
  Abs[QuantumCorrelation[0.7, 0.7] - 1.0] < 10^-12];
AssertTrue["E(a,a+Pi/2) = 0 (perpendicular settings, no correlation)",
  Abs[QuantumCorrelation[0.0, Pi/2.0]] < 10^-12];
AssertTrue["E(a,a+Pi) = -1 (opposite settings, perfect anti-correlation)",
  Abs[QuantumCorrelation[0.0, Pi] - (-1.0)] < 10^-9];
AssertTrue["QuantumCorrelationViaRotation agrees with QuantumCorrelation (independent method)",
  Module[{tests = {{0.3, 1.1}, {-0.7, 2.4}, {Pi/3.0, -Pi/5.0}}},
    Max[Abs[(QuantumCorrelation[#[[1]], #[[2]]] & /@ tests) -
            (QuantumCorrelationViaRotation[#[[1]], #[[2]]] & /@ tests)]] < 10^-9]];
Print[""];

(* ── JointProbabilities ───────────────────────────────────────────── *)
Print["-- JointProbabilities --"];
Module[{p = JointProbabilities[0.4, 1.1]},
  AssertTrue["joint probabilities sum to 1", Abs[Total[Values[p]] - 1.0] < 10^-12];
  AssertTrue["Ppp = Pmm (symmetric for Phi+)", Abs[p["Ppp"] - p["Pmm"]] < 10^-12];
  AssertTrue["Ppm = Pmp (symmetric for Phi+)", Abs[p["Ppm"] - p["Pmp"]] < 10^-12];
  AssertTrue["all probabilities non-negative", AllTrue[Values[p], # >= -10^-12 &]];
];
AssertTrue["marginal P(Alice=+1) is exactly 0.5 regardless of Bob's setting (no-signalling)",
  Module[{bAngles = {0.0, 0.9, 2.7, -1.4}},
    AllTrue[bAngles, Abs[(JointProbabilities[0.55, #]["Ppp"] + JointProbabilities[0.55, #]["Ppm"]) - 0.5] < 10^-12 &]]];
Print[""];

(* ── Classical (local hidden-variable) model ──────────────────────── *)
Print["-- ClassicalTriangularCorrelation --"];
AssertTrue["E_classical(0) = 1", Abs[ClassicalTriangularCorrelation[0.0] - 1.0] < 10^-12];
AssertTrue["E_classical(Pi) = -1", Abs[ClassicalTriangularCorrelation[Pi] - (-1.0)] < 10^-9];
AssertTrue["E_classical(Pi/2) = 0", Abs[ClassicalTriangularCorrelation[Pi/2.0]] < 10^-9];
AssertTrue["E_classical is even: same at +delta and -delta",
  Abs[ClassicalTriangularCorrelation[0.9] - ClassicalTriangularCorrelation[-0.9]] < 10^-12];
AssertTrue["E_classical matches direct numerical integration at delta=Pi/3",
  Module[{numeric, delta = Pi/3.0},
    numeric = (1.0/(2.0 Pi)) NIntegrate[Sign[Cos[lam]]*Sign[Cos[lam - delta]], {lam, 0, 2 Pi}];
    Abs[ClassicalTriangularCorrelation[delta] - numeric] < 10^-6]];
Print[""];

(* ── CHSH ──────────────────────────────────────────────────────────── *)
Print["-- ChshValue / optimal angles --"];
AssertTrue["ChshValue at derived-optimal angles equals 2*Sqrt[2]",
  Abs[ChshValue[$ChshOptimalAngles["a"], $ChshOptimalAngles["ap"],
               $ChshOptimalAngles["b"], $ChshOptimalAngles["bp"]] - 2.0 Sqrt[2.0]] < 10^-9];
AssertTrue["ChshValue never exceeds 2*Sqrt[2] (Tsirelson bound) over random angles",
  Module[{trials, vals},
    SeedRandom[99];
    trials = Table[RandomReal[{0, 2 Pi}, 4], {500}];
    vals = ChshValue[#[[1]], #[[2]], #[[3]], #[[4]]] & /@ trials;
    Max[vals] <= 2.0 Sqrt[2.0] + 10^-6]];
Print[""];

(* ── MeasurementJointSample ───────────────────────────────────────── *)
Print["-- MeasurementJointSample --"];
Module[{s = MeasurementJointSample[0.3, 1.0, 500, 7]},
  AssertTrue["aOutcomes has nTrials entries", Length[s["aOutcomes"]] === 500];
  AssertTrue["bOutcomes has nTrials entries", Length[s["bOutcomes"]] === 500];
  AssertTrue["all outcomes are +1 or -1",
    AllTrue[Join[s["aOutcomes"], s["bOutcomes"]], # === 1 || # === -1 &]];
  AssertTrue["same seed reproduces identical outcomes",
    MeasurementJointSample[0.3, 1.0, 500, 7]["aOutcomes"] === s["aOutcomes"]];
  AssertTrue["empirical correlation is within statistical range of E(a,b)",
    Abs[Mean[s["aOutcomes"] * s["bOutcomes"]] - QuantumCorrelation[0.3, 1.0]] < 0.15];
];
Print[""];

(* ── The four correctness checks, run directly ────────────────────── *)
Print["-- Correctness checks --"];
AssertTrue["BellStateNormalizationCheck passes", BellStateNormalizationCheck[]["pass"]];
AssertTrue["QuantumCorrelationIndependentCheck passes", QuantumCorrelationIndependentCheck[]["pass"]];
AssertTrue["ChshOptimalityCheck passes", ChshOptimalityCheck[]["pass"]];
AssertTrue["LocalHiddenVariableBoundCheck passes", LocalHiddenVariableBoundCheck[]["pass"]];
Print[""];

(* ── Model builders ───────────────────────────────────────────────── *)
Print["-- Model builders --"];
Module[{cm = CorrelationsModel[<||>]},
  AssertTrue["CorrelationsModel EQuantumArr has nSteps entries", Length[cm["EQuantumArr"]] === cm["nSteps"]];
  AssertTrue["CorrelationsModel EQuantumArr stays within [-1,1]",
    Max[cm["EQuantumArr"]] <= 1.0 + 10^-9 && Min[cm["EQuantumArr"]] >= -1.0 - 10^-9];
];
Module[{chm = ChshModel[<||>]},
  AssertTrue["ChshModel default S equals 2*Sqrt[2] (default config uses the derived-optimal angles)",
    Abs[chm["S"] - 2.0 Sqrt[2.0]] < 10^-9];
];
Module[{mm = MeasurementModel[<||>]},
  AssertTrue["MeasurementModel runningCorr has nTrials entries", Length[mm["runningCorr"]] === mm["nTrials"]];
  AssertTrue["MeasurementModel marginals are close to 0.5",
    Abs[mm["marginalA"] - 0.5] < 0.05 && Abs[mm["marginalB"] - 0.5] < 0.05];
];
Print[""];

Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

#!/usr/bin/env wolframscript

(* grover/tests/test_model.wl — Unit tests for the Grover model *)

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

Print["=== grover/src/model.wl unit tests ==="];
Print[""];

(* ── GroverThetaFromN ──────────────────────────────────────────────── *)
Print["-- GroverThetaFromN --"];
AssertTrue["Sin[theta]=1/Sqrt[N] for N=64", Abs[Sin[GroverThetaFromN[64]] - 1.0/Sqrt[64.0]] < 10^-12];
AssertTrue["theta for N=2 is exactly 45 degrees", Abs[GroverThetaFromN[2] - Pi/4.0] < 10^-9];
Print[""];

(* ── GroverOperators ───────────────────────────────────────────────── *)
Print["-- GroverOperators --"];
Module[{ops = GroverOperators[16, 5]},
  AssertTrue["oracle is unitary", Max[Abs[Flatten[ops["oracleOp"].Transpose[ops["oracleOp"]] - IdentityMatrix[16]]]] < 10^-9];
  AssertTrue["diffusion is unitary", Max[Abs[Flatten[ops["diffusionOp"].Transpose[ops["diffusionOp"]] - IdentityMatrix[16]]]] < 10^-9];
  AssertTrue["Grover operator is unitary", Max[Abs[Flatten[ops["groverOp"].Transpose[ops["groverOp"]] - IdentityMatrix[16]]]] < 10^-9];
  AssertTrue["oracle flips sign only on marked index",
    Module[{diff = ops["oracleOp"] - IdentityMatrix[16]},
      diff[[5,5]] == -2.0 && Total[Abs[Flatten[diff]]] == 2.0]];
];
Print[""];

(* ── GroverProbMarked / GroverSimulateTrajectory ──────────────────── *)
Print["-- GroverProbMarked / GroverSimulateTrajectory --"];
AssertTrue["P(marked)=1/N at k=0 (before any iteration)",
  Abs[GroverProbMarked[64, 0] - 1.0/64.0] < 10^-9];
AssertTrue["closed form matches direct simulation for N=16, k=0..8",
  Module[{sim = GroverSimulateTrajectory[16, 3, 8], closed},
    closed = Table[GroverProbMarked[16, k], {k, 0, 8}];
    Max[Abs[sim - closed]] < 10^-9]];
AssertTrue["direct simulation gives a valid probability at every k (in [0,1])",
  Module[{sim = GroverSimulateTrajectory[32, 9, 15]}, AllTrue[sim, 0.0 <= # <= 1.0 + 10^-9 &]]];
Print[""];

(* ── GroverOptimalK / GroverOptimalKBySimulation ──────────────────── *)
Print["-- GroverOptimalK --"];
AssertTrue["exact optimal k matches independent period-windowed simulation for several N",
  Module[{testNs = {4, 8, 16, 32, 64, 128, 256, 1024, 4096}},
    (GroverOptimalK[#] & /@ testNs) === (GroverOptimalKBySimulation[#] & /@ testNs)]];
AssertTrue["optimal k is where P(marked) is at (or extremely near) its first local max",
  Module[{n = 64, kOpt, pAtOpt, pBefore, pAfter},
    kOpt = GroverOptimalK[n];
    pAtOpt = GroverProbMarked[n, kOpt];
    pBefore = GroverProbMarked[n, kOpt - 1];
    pAfter = GroverProbMarked[n, kOpt + 1];
    pAtOpt >= pBefore && pAtOpt >= pAfter]];
AssertTrue["N=2 is a degenerate edge case: P(marked)=0.5 for every k",
  Module[{vals = GroverProbMarked[2, #] & /@ Range[0, 5]},
    Max[Abs[vals - 0.5]] < 10^-9]];
Print[""];

(* ── pi/4*Sqrt[N] approximation accuracy ───────────────────────────── *)
Print["-- sqrt(N) approximation --"];
AssertTrue["pi/4*Sqrt[N] rounds to within 1 of the exact optimal k, for N>=8",
  Module[{testNs = {8, 16, 32, 64, 128, 256, 1024, 4096, 65536}},
    AllTrue[testNs, Abs[Round[(Pi/4.0)*Sqrt[N[#]]] - GroverOptimalK[#]] <= 1 &]]];
Print[""];

(* ── The four correctness checks, run directly ────────────────────── *)
Print["-- Correctness checks --"];
AssertTrue["RotationAngleCheck passes", RotationAngleCheck[]["pass"]];
AssertTrue["OptimalIterationCountCheck passes", OptimalIterationCountCheck[]["pass"]];
AssertTrue["OperatorUnitarityCheck passes", OperatorUnitarityCheck[]["pass"]];
AssertTrue["ClosedFormVsSimulationCheck passes", ClosedFormVsSimulationCheck[]["pass"]];
Print[""];

(* ── Model builders ───────────────────────────────────────────────── *)
Print["-- Model builders --"];
Module[{sm = SearchModel[<||>]},
  AssertTrue["SearchModel probArr has nIterations+1 entries", Length[sm["probArr"]] === sm["nIterations"] + 1];
  AssertTrue["SearchModel P(marked) peaks near the optimal k",
    Abs[sm["probArr"][[sm["optimalK"] + 1]] - Max[sm["probArr"]]] < 10^-9];
];
Module[{cm = CompareModel[<||>]},
  AssertTrue["CompareModel classical queries exceed quantum queries", cm["classicalAtN"] > cm["quantumAtN"]];
  AssertTrue["CompareModel nArr is monotonically increasing", OrderedQ[cm["nArr"]]];
  AssertTrue["CompareModel classicalArr grows linearly, quantumArr sub-linearly (ratio increases with N)",
    Module[{ratios = cm["classicalArr"] / cm["quantumArr"]}, ratios[[-1]] > ratios[[1]]]];
];
Module[{gm = GeometryModel[<||>]},
  AssertTrue["GeometryModel angle advances by exactly 2*theta per iteration",
    Module[{diffs = Differences[gm["angleArr"]]}, Max[Abs[diffs - 2.0*gm["theta"]]] < 10^-9]];
  AssertTrue["GeometryModel ampMarkedArr^2 + ampUnmarkedArr^2 = 1 (unit vector)",
    Max[Abs[gm["ampMarkedArr"]^2 + gm["ampUnmarkedArr"]^2 - 1.0]] < 10^-9];
];
Print[""];

Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

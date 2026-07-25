#!/usr/bin/env wolframscript

(* qubit/tests/test_model.wl — Unit tests for the qubit model *)

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

Print["=== qubit/src/model.wl unit tests ==="];
Print[""];

(* ── Gate matrices ────────────────────────────────────────────────── *)
Print["-- Gate matrices --"];
AssertTrue["X|0> = |1>", GateMatrix["X"].{1.0, 0.0} == {0.0, 1.0}];
AssertTrue["Z|0> = |0>", GateMatrix["Z"].{1.0, 0.0} == {1.0, 0.0}];
AssertTrue["Z|1> = -|1>", GateMatrix["Z"].{0.0, 1.0} == {0.0, -1.0}];
AssertTrue["H|0> = (|0>+|1>)/Sqrt[2]",
  Max[Abs[GateMatrix["H"].{1.0, 0.0} - {1.0/Sqrt[2.0], 1.0/Sqrt[2.0]}]] < 10^-12];
AssertTrue["S = diag(1,i)", GateMatrix["S"][[2, 2]] === I];
AssertTrue["T phase is Exp[I Pi/4]", Abs[GateMatrix["T"][[2, 2]] - Exp[I*Pi/4.0]] < 10^-12];
AssertTrue["Rx(0) = identity", Max[Abs[Flatten[GateMatrix["Rx:0.0"] - IdentityMatrix[2]]]] < 10^-12];
(* NOTE: ToString[] on a machine real keeps only ~6 significant digits
   by default (e.g. ToString[2.0*Pi] gives "6.28319", not the full
   value) -- ToString[x, InputForm] round-trips through ToExpression[]
   exactly instead. Discovered when this exact test failed with a
   ~2.3e-6 residual instead of ~1e-16 using plain ToString[]. See
   AGENTS.md common pitfalls. *)
AssertTrue["Rz(2 Pi) = -identity (spinor double-cover)",
  Max[Abs[Flatten[GateMatrix["Rz:" <> ToString[2.0*Pi, InputForm]] - (-IdentityMatrix[2])]]] < 10^-9];
Print[""];

(* ── Bloch vector ─────────────────────────────────────────────────── *)
Print["-- BlochVector --"];
AssertTrue["|0> has Bloch vector (0,0,1)", BlochVector[1.0, 0.0] === {0.0, 0.0, 1.0}];
AssertTrue["|1> has Bloch vector (0,0,-1)", BlochVector[0.0, 1.0] === {0.0, 0.0, -1.0}];
AssertTrue["(|0>+|1>)/Sqrt[2] has Bloch vector (1,0,0)",
  Max[Abs[BlochVector[1.0/Sqrt[2.0], 1.0/Sqrt[2.0]] - {1.0, 0.0, 0.0}]] < 10^-12];
AssertTrue["(|0>+i|1>)/Sqrt[2] has Bloch vector (0,1,0)",
  Max[Abs[BlochVector[1.0/Sqrt[2.0], I/Sqrt[2.0]] - {0.0, 1.0, 0.0}]] < 10^-12];
AssertTrue["|r|=1 for a generic normalized state",
  Abs[Norm[BlochVector[0.6, 0.8*Exp[I*1.3]]] - 1.0] < 10^-12];
Print[""];

(* ── GatesTrajectory ──────────────────────────────────────────────── *)
Print["-- GatesTrajectory --"];
Module[{traj = GatesTrajectory[{1.0, 0.0}, {"H", "H"}, 10]},
  AssertTrue["states has nGates+1 entries", Length[traj["states"]] === 3];
  AssertTrue["H*H = identity: final state matches initial",
    Max[Abs[Last[traj["states"]] - {1.0, 0.0}]] < 10^-9];
  AssertTrue["rPath has nGates*nStepsPerGate+1 entries", Length[traj["rPath"]] === 21];
  AssertTrue["gateBoundaries starts at 1", First[traj["gateBoundaries"]] === 1];
  AssertTrue["gateBoundaries ends at rPath length", Last[traj["gateBoundaries"]] === Length[traj["rPath"]]];
  AssertTrue["every point on rPath has |r|=1",
    Max[Abs[Norm /@ traj["rPath"] - 1.0]] < 10^-6];
];
Print[""];

(* ── Rabi ─────────────────────────────────────────────────────────── *)
Print["-- Rabi --"];
AssertTrue["P(1)=0 at t=0", RabiProbability1[1.5, 0.0] === 0.0];
AssertTrue["P(1)=1 at t=Pi/Omega (first full inversion)",
  Abs[RabiProbability1[1.5, Pi/1.5] - 1.0] < 10^-9];
AssertTrue["P(1) is periodic with period 2 Pi/Omega",
  Abs[RabiProbability1[1.5, 0.7] - RabiProbability1[1.5, 0.7 + 2.0*Pi/1.5]] < 10^-9];
Module[{tVals = {0.3, 0.9, 1.7}, closedForm, independent},
  closedForm  = RabiProbability1[1.2, #] & /@ tVals;
  independent = RabiSchrodingerSolve[1.2, tVals];
  AssertTrue["RabiSchrodingerSolve agrees with closed form (independent check)",
    Max[Abs[closedForm - independent]] < 10^-8];
];
Print[""];

(* ── Measurement ──────────────────────────────────────────────────── *)
Print["-- MeasurementTrials --"];
Module[{m = MeasurementTrials[0.6, 0.8, 1000, 42]},
  AssertTrue["outcomes has nTrials entries", Length[m["outcomes"]] === 1000];
  AssertTrue["runningFreq0 has nTrials entries", Length[m["runningFreq0"]] === 1000];
  AssertTrue["outcomes are all 0 or 1", AllTrue[m["outcomes"], # === 0 || # === 1 &]];
  AssertTrue["trueP0 equals |alpha|^2", m["trueP0"] === 0.36];
  AssertTrue["final running frequency is within 10% of true P0 at 1000 trials",
    Abs[Last[m["runningFreq0"]] - 0.36] < 0.05];
  AssertTrue["same seed reproduces identical outcomes",
    MeasurementTrials[0.6, 0.8, 1000, 42]["outcomes"] === m["outcomes"]];
];
Print[""];

(* ── The four correctness checks, run directly ───────────────────── *)
Print["-- Correctness checks --"];
AssertTrue["GateUnitarityCheck passes", GateUnitarityCheck[]["pass"]];
AssertTrue["BlochLengthCheck passes", BlochLengthCheck[]["pass"]];
AssertTrue["RabiFormulaCheck passes", RabiFormulaCheck[]["pass"]];
AssertTrue["BornRuleMonteCarloCheck passes", BornRuleMonteCarloCheck[]["pass"]];
Print[""];

Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

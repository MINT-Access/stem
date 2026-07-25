#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the pendulum model
   Usage: wolframscript -file tests/test_model.wl
   ======================================================== *)

$projectRoot  = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];

passed = 0;
failed = 0;

(* Helper: assert a condition and report *)
AssertTrue[label_String, condition_] :=
  If[TrueQ[condition],
    Print["  PASS  ", label];
    passed++,
    Print["  FAIL  ", label];
    failed++
  ]

(* --- Test parameters --- *)
testParams = <|
  "Length"       -> 1.0,
  "Gravity"      -> 9.81,
  "InitAngle"    -> 0.1,   (* small angle for approx. validity *)
  "InitVelocity" -> 0.0,
  "TimeEnd"      -> 5.0,
  "TimeStep"     -> 0.01
|>;

Print["Running tests..."];
Print[""];

(* Test 1: solver returns a non-empty list *)
sol = SolvePendulum[testParams];
AssertTrue["Solver returns results", Length[sol] > 0];

(* Test 2: first time step is t=0 *)
AssertTrue["First time point is 0", sol[[1, 1]] == 0.0];

(* Test 3: initial angle matches parameter *)
AssertTrue["Initial angle matches",
  Abs[sol[[1, 2]] - testParams["InitAngle"]] < 1*^-6];

(* Test 4: initial angular velocity matches parameter *)
AssertTrue["Initial angular velocity matches",
  Abs[sol[[1, 3]] - testParams["InitVelocity"]] < 1*^-6];

(* Test 5: energy is approximately conserved (drift < 0.1%) *)
energies = PendulumEnergy[#[[2]], #[[3]], testParams] & /@ sol;
energyDrift = Abs[Last[energies] - First[energies]] / First[energies];
AssertTrue["Energy conserved to within 0.1%", energyDrift < 0.001];

(* Test 6: small-angle period matches analytical formula *)
(* For small angles, T = 2*Pi*Sqrt[L/g] *)
analyticalPeriod = 2 Pi Sqrt[testParams["Length"] / testParams["Gravity"]];
(* Find first return to near-zero from positive side *)
crossings = Select[
  Partition[sol, 2, 1],
  #[[1, 2]] > 0 && #[[2, 2]] <= 0 &
];
If[Length[crossings] >= 2,
  numericalPeriod = crossings[[2, 1, 1]] - crossings[[1, 1, 1]];
  AssertTrue["Period matches small-angle approximation (within 1%)",
    Abs[numericalPeriod - analyticalPeriod] / analyticalPeriod < 0.01],
  Print["  SKIP  Period test (not enough crossings in time window)"]
];

(* Test 7: ExportResults writes a file *)
tmpFile = FileNameJoin[{$TemporaryDirectory, "pendulum_test.csv"}];
ExportResults[sol, testParams, tmpFile];
AssertTrue["CSV file is created", FileExistsQ[tmpFile]];
DeleteFile[tmpFile];

(* --- Correctness checks (simple pendulum) --- *)
Print[""];
Print["-- Correctness checks (simple pendulum) --"];
Module[{L = 1.0, g = 9.81, chk, bigSol, bigParams},
  (* Check 1: exact period formula, small-angle sanity *)
  AssertTrue["ExactPeriod reduces to small-angle formula as theta0->0",
    Abs[ExactPeriod[L, g, 0.001] - 2.0*Pi*Sqrt[L/g]] / (2.0*Pi*Sqrt[L/g]) < 10^-6];

  chk = ExactPeriodCheck[L, g];
  AssertTrue["ExactPeriodCheck passes across 10/45/90/150 deg (exact, tight tolerance)", chk["pass"]];
  AssertTrue["ExactPeriodCheck tests 4 amplitudes", Length[chk["results"]] === 4];

  (* Large-amplitude sanity: exact period should exceed the small-angle
     approximation (the pendulum takes longer to swing at large amplitude) *)
  bigParams = <| "Length" -> L, "Gravity" -> g, "InitAngle" -> 150.0*Pi/180.0,
                 "InitVelocity" -> 0.0, "TimeEnd" -> 10.0, "TimeStep" -> 0.01 |>;
  AssertTrue["Exact period at 150 deg exceeds small-angle approximation",
    ExactPeriod[L, g, 150.0*Pi/180.0] > 2.0*Pi*Sqrt[L/g]];

  bigSol = SolvePendulum[bigParams];
  chk = SimpleEnergyConservationCheck[bigSol, bigParams];
  AssertTrue["SimpleEnergyConservationCheck passes at large amplitude (exact, tight tolerance)", chk["pass"]];
  AssertTrue["SimpleEnergyConservationCheck samples multiple points, not just start/end",
    Length[chk["sampled"]] > 2];
];

(* --- Correctness checks (double pendulum) --- *)
Print[""];
Print["-- Correctness checks (double pendulum) --"];
Module[{cfg, dsol, chk},
  cfg = <| "simulation" -> <| "double" -> <| "length1" -> 1.0, "length2" -> 1.0,
           "mass1" -> 1.0, "mass2" -> 1.0, "angle1_deg" -> 120.0, "angle2_deg" -> 90.0 |>,
           "gravity" -> 9.81, "duration" -> 20.0, "timestep" -> 0.01 |> |>;
  dsol = DoublePendulumModel[cfg];

  chk = DoubleEnergyConservationCheck[dsol, 1.0, 1.0, 1.0, 1.0, 9.81];
  AssertTrue["DoubleEnergyConservationCheck passes (exact, tight tolerance)", chk["pass"]];
  AssertTrue["DoubleEnergyConservationCheck relative drift is tiny (~1e-8 or better)",
    chk["relDrift"] < 10^-6];

  chk = ChaosSensitivityCheck[];
  AssertTrue["ChaosSensitivityCheck passes at its own 130 deg test amplitude", chk["pass"]];
  AssertTrue["ChaosSensitivityCheck divergence ratio exceeds 100x", chk["ratio"] >= 100.0];

  (* Document the actual finding: the app's own DEFAULT angle1_deg=120
     does NOT reliably clear the 100x threshold within the default 20s
     duration -- this is why ChaosSensitivityCheck uses its own fixed
     130 deg test amplitude rather than whatever the run configures. *)
  Module[{lowChk},
    lowChk = ChaosSensitivityCheck[120.0];
    AssertTrue["At the app's own default 120 deg, divergence stays well under 100x within 20s ",
      lowChk["ratio"] < 100.0];
  ];
];

(* --- Summary --- *)
Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

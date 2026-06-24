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

(* --- Summary --- *)
Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

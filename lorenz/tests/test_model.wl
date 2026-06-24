#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the Lorenz model
   Usage: wolframscript -file tests/test_model.wl
   ======================================================== *)

$projectRoot  = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];

passed = 0;
failed = 0;

AssertTrue[label_String, cond_] :=
  If[TrueQ[cond],
    Print["  PASS  ", label]; passed++,
    Print["  FAIL  ", label]; failed++
  ]

AssertNear[label_String, val_, ref_, tol_:0.01] :=
  AssertTrue[label, Abs[val - ref] < tol * Abs[ref + 0.0001]]

(* Standard parameters *)
params = <|
  "Sigma" -> 10.0, "Rho" -> 28.0, "Beta" -> 8/3,
  "InitX" -> 1.0, "InitY" -> 1.0, "InitZ" -> 1.0,
  "TimeEnd" -> 5.0, "TimeStep" -> 0.01
|>;

Print["Running Lorenz tests..."];
Print[""];

sol = SolveLorenz[params];

(* Test 1: solver produces output *)
AssertTrue["Solver returns results", Length[sol] > 0];

(* Test 2: correct number of steps *)
expectedSteps = Round[params["TimeEnd"] / params["TimeStep"]] + 1;
AssertTrue["Step count correct",
  Abs[Length[sol] - expectedSteps] <= 2];

(* Test 3: first time is 0 *)
AssertTrue["First time point is 0", sol[[1, 1]] == 0.0];

(* Test 4: initial conditions match *)
AssertTrue["InitX matches", Abs[sol[[1, 2]] - params["InitX"]] < 1*^-6];
AssertTrue["InitY matches", Abs[sol[[1, 3]] - params["InitY"]] < 1*^-6];
AssertTrue["InitZ matches", Abs[sol[[1, 4]] - params["InitZ"]] < 1*^-6];

(* Test 5: solution stays within known attractor bounds *)
(* For classic params, |x|<25, |y|<30, 0<z<50 approximately *)
AssertTrue["x stays in attractor bounds",
  AllTrue[sol[[All, 2]], Abs[#] < 30 &]];
AssertTrue["z stays positive (above fixed points)",
  AllTrue[sol[[All, 4]], # > 0 &]];

(* Test 6: solution is not constant (chaos means it moves) *)
xRange = Max[sol[[All, 2]]] - Min[sol[[All, 2]]];
AssertTrue["x varies significantly (not stuck)", xRange > 5.0];

(* Test 7: butterfly effect — two close trajectories diverge.
   The (1,1,1) initial condition is in a transient phase until
   ~t=12 s before landing on the attractor; TimeEnd=5 s is too
   short to see 10x divergence. Use TimeEnd=20 s instead. *)
{sol1, sol2} = SolveLorenzPair[<| params, "TimeEnd" -> 20.0 |>, 0.001];
divAtStart = LorenzDivergence[sol1, sol2][[1, 2]];
divAtEnd   = LorenzDivergence[sol1, sol2][[-1, 2]];
AssertTrue["Trajectories diverge (butterfly effect)",
  divAtEnd > divAtStart * 10];

(* Test 8: ExportResults writes a file *)
tmpFile = FileNameJoin[{$TemporaryDirectory, "lorenz_test.csv"}];
ExportResults[sol, params, tmpFile];
AssertTrue["CSV file created", FileExistsQ[tmpFile]];
DeleteFile[tmpFile];

(* Test 9: divergence list has correct length *)
div = LorenzDivergence[sol1, sol2];
AssertTrue["Divergence list matches solution length",
  Length[div] == Length[sol1]];

Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

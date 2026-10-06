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
Print["-- Correctness checks (Lorenz) --"];
Module[{sigma = 10.0, rho = 28.0, beta = 8.0/3.0, chk},
  chk = LorenzDivergenceCheck[sigma, rho, beta];
  AssertTrue["LorenzDivergenceCheck passes (exact, tight tolerance)", chk["pass"]];
  AssertTrue["Divergence equals -(sigma+1+beta)", chk["expected"] === -(sigma+1.0+beta)];

  chk = LorenzEquilibriumCheck[sigma, rho, beta];
  AssertTrue["LorenzEquilibriumCheck passes (exact, tight tolerance)", chk["pass"]];
  AssertTrue["C+ z-coordinate equals rho-1", Abs[chk["cPlus"][[3]] - (rho-1.0)] < 10^-9];

  chk = LorenzLyapunovCheck[sigma, rho, beta];
  AssertTrue["LorenzLyapunovCheck passes (empirical, generous tolerance)", chk["pass"]];
  AssertTrue["Largest Lyapunov exponent is positive (chaos signature)", chk["lambda1"] > 0];

  chk = TrajectoryBoundedCheck[sol];
  AssertTrue["TrajectoryBoundedCheck passes on a real solved trajectory", chk["pass"]];
];
Print[""];

Print["-- Correctness checks (Rossler) --"];
Module[{a = 0.2, b = 0.2, c = 5.7, chk, rsol, rparams},
  chk = RosslerDivergenceCheck[a, b, c];
  AssertTrue["RosslerDivergenceCheck passes (exact, tight tolerance)", chk["pass"]];
  AssertTrue["Rossler divergence is NOT constant across test points (genuinely x-dependent)",
    Length[DeleteDuplicates[Round[chk["divergences"], 10^-6]]] > 1];

  chk = RosslerEquilibriumCheck[a, b, c];
  AssertTrue["RosslerEquilibriumCheck passes (exact, tight tolerance)", chk["pass"]];
  AssertTrue["Two distinct equilibria found", Length[chk["equilibria"]] === 2];

  chk = RosslerLyapunovCheck[a, b, c];
  AssertTrue["RosslerLyapunovCheck passes (empirical, generous tolerance)", chk["pass"]];
  AssertTrue["Largest Lyapunov exponent is positive (chaos signature)", chk["lambda1"] > 0];

  rparams = <| "A"->a, "B"->b, "C"->c, "InitX"->0.1, "InitY"->0.0, "InitZ"->0.0,
               "TimeEnd"->10.0, "TimeStep"->0.01 |>;
  rsol = SolveRossler[rparams];
  chk = TrajectoryBoundedCheck[rsol];
  AssertTrue["TrajectoryBoundedCheck passes on a real solved Rossler trajectory", chk["pass"]];
];

Print[""];
Print["-- Transient discard and presets --"];
Module[{p, sol, kept},
  p = <| "Sigma"->10.0, "Rho"->28.0, "Beta"->8/3, "InitX"->0.1, "InitY"->0.0, "InitZ"->0.0,
         "TimeEnd"->7.0, "TimeStep"->0.005 |>;
  sol  = SolveLorenz[p];
  kept = DiscardTransient[sol, 5.0];
  AssertTrue["DiscardTransient keeps duration/dt + 1 samples after a 5 s transient (401 of 1401)",
    Length[sol] === 1401 && Length[kept] === 401];
  AssertTrue["the retained part restarts at t = 0 and ends at t = 2 (the duration)",
    kept[[1, 1]] == 0 && Abs[kept[[-1, 1]] - 2.0] < 10^-9];
  AssertTrue["the retained first state is the solution's state at t = 5",
    kept[[1, 2 ;; 4]] === sol[[1001, 2 ;; 4]]];
  AssertTrue["a zero transient leaves the solution unchanged", DiscardTransient[sol, 0] === sol];
];
AssertTrue["six presets: classic, butterfly, stable, wild, slow, rho9996",
  Keys[$lorenzPresets] === {"classic", "butterfly", "stable", "wild", "slow", "rho9996"}];
AssertTrue["the stable preset uses rho = 20", $lorenzPresets["stable"]["Rho"] == 20.0];
Module[{p, sol, beta = 8/3., rho = 20.0, cp, last, speed},
  p    = LorenzPresetParams["stable"];
  sol  = DiscardTransient[SolveLorenz[Append[p, "TimeEnd" -> 5.0 + p["TimeEnd"]]], 5.0];
  cp   = {Sqrt[beta (rho - 1)], Sqrt[beta (rho - 1)], rho - 1};
  last = Last[sol][[2 ;; 4]];
  speed = Norm[(sol[[-1, 2 ;; 4]] - sol[[-2, 2 ;; 4]]) / 0.005];
  AssertTrue["stable preset: after 5 s transient + 30 s, within 0.5 of C+ or C-",
    Min[Norm[last - cp], Norm[last - {-1, -1, 1} cp]] < 0.5];
  AssertTrue["stable preset: speed at the end below 1", speed < 1];
];

Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

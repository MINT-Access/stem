#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the quantum mechanics model
   Usage: wolframscript -file tests/test_model.wl
   ======================================================== *)

$projectRoot  = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

passed = 0;
failed = 0;

AssertTrue[label_String, condition_] :=
  If[TrueQ[condition],
    Print["  PASS  ", label];
    passed++,
    Print["  FAIL  ", label];
    failed++
  ]

Print["Running tests..."];
Print[""];

(* --- QHOModel tests --- *)

qhoCfg = <|
  "simulation" -> <|
    "mode" -> "qho",
    "qho" -> <|
      "alpha"    -> 2.0,
      "omega"    -> 1.0,
      "n_modes"  -> 10,
      "x_range"  -> {-8.0, 8.0},
      "n_points" -> 100,
      "duration" -> 6.28318,
      "timestep" -> 0.1
    |>
  |>
|>;

qho = QHOModel[qhoCfg];

(* Test 1: returns Association with required keys *)
AssertTrue["QHOModel returns Association with density/x/t keys",
  AssociationQ[qho] && KeyExistsQ[qho, "density"] &&
  KeyExistsQ[qho, "x"] && KeyExistsQ[qho, "t"]];

(* Test 2: density matrix has correct dimensions {nt, nx} *)
With[{nt = Length[qho["t"]], nx = Length[qho["x"]]},
  AssertTrue["Density matrix has correct dimensions",
    Dimensions[qho["density"]] === {nt, nx}]];

(* Test 3: density values are non-negative *)
AssertTrue["Density values are all >= 0",
  Min[qho["density"]] >= -1*^-10];

(* Test 4: normalisation holds (integral |psi|^2 dx ≈ 1) at t=0 *)
With[{dx = qho["dx"], row0 = qho["density"][[1]]},
  norm0 = Total[row0] * dx;
  AssertTrue["Normalisation at t=0 is within 1% of 1",
    Abs[norm0 - 1.0] < 0.01]];

(* Test 5: mode field is "qho" *)
AssertTrue["QHOModel mode field is \"qho\"",
  qho["mode"] === "qho"];

(* Test 6: mean energy matches analytical formula <E> = omega*(|alpha|^2 + 0.5) *)
With[{alpha = 2.0, omega = 1.0},
  expectedEnergy = omega * (alpha^2 + 0.5);
  AssertTrue["Mean energy matches <E> = omega(|alpha|^2 + 1/2)",
    Abs[qho["mean_energy"] - expectedEnergy] < 1*^-6]];

(* Test 7: norm_ok is True for the test parameters *)
AssertTrue["QHO normalisation check passes",
  qho["norm_ok"] === True];

(* --- BoxModel tests --- *)

boxCfg = <|
  "simulation" -> <|
    "mode" -> "box",
    "box" -> <|
      "L"        -> 10.0,
      "n_modes"  -> 5,
      "n_points" -> 100,
      "duration" -> 10.0,
      "timestep" -> 0.1
    |>
  |>
|>;

box = BoxModel[boxCfg];

(* Test 8: returns Association with mode field "box" *)
AssertTrue["BoxModel mode field is \"box\"",
  box["mode"] === "box"];

(* Test 9: spatial grid runs from 0 to L *)
AssertTrue["Box spatial grid starts at 0",
  Abs[First[box["x"]]] < 1*^-10];
AssertTrue["Box spatial grid ends at L",
  Abs[Last[box["x"]] - 10.0] < 1*^-6];

(* Test 10: normalisation holds at t=0 *)
With[{dx = box["dx"], row0 = box["density"][[1]]},
  norm0 = Total[row0] * dx;
  AssertTrue["Box normalisation at t=0 is within 1% of 1",
    Abs[norm0 - 1.0] < 0.01]];

(* Test 11: mean energy = (E_1 + E_2) / 2 for (phi_1 + phi_2)/sqrt(2) *)
With[{L = 10.0},
  E1 = N[1^2 * Pi^2 / (2 * L^2)];
  E2 = N[2^2 * Pi^2 / (2 * L^2)];
  expectedEnergy = (E1 + E2) / 2;
  AssertTrue["Box mean energy matches (E1+E2)/2 for phi_1 + phi_2 state",
    Abs[box["mean_energy"] - expectedEnergy] < 1*^-6]];

(* --- DensityToTrajectory tests --- *)

traj = DensityToTrajectory[qho];

(* Test 12: trajectory has 5 columns {t, x, y, z, speed} *)
AssertTrue["DensityToTrajectory returns {nt, 5} matrix",
  Dimensions[traj][[2]] === 5];

(* Test 13: time column matches model time grid *)
AssertTrue["Trajectory first time point is 0",
  Abs[traj[[1, 1]]] < 1*^-10];

(* --- Summary --- *)
Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

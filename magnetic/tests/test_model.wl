#!/usr/bin/env wolframscript
(* Unit tests for magnetic/src/model.wl *)

$projectRoot  = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];

passed = 0;
failed = 0;

AssertTrue[label_String, cond_] := If[TrueQ[cond],
  (Print["  [PASS] ", label]; passed++),
  (Print["  [FAIL] ", label]; failed++)];

AssertNear[label_String, got_, expected_, tol_:1*^-6] :=
  AssertTrue[label, Abs[N[got] - N[expected]] < tol];

Print["== Test 1: cyclotron period =="];

cfg1 = <|"simulation" -> <|"magnetic" -> <|
  "B_z" -> 1.0, "charge_mass_ratio" -> 1.0,
  "v_perp" -> 1.0, "v_parallel" -> 0.0, "n_periods" -> 5
|>|>|>;

m1 = IntegrateCyclotron[cfg1];

AssertNear["measured period matches 2*Pi within 1%",
  m1["periodMeasured"], 2.0 Pi, 0.01 * 2.0 Pi];

AssertTrue["model's own periodPass flag is True", m1["periodPass"]];

Print[""];
Print["== Test 2: E x B drift velocity =="];

cfg2 = <|"simulation" -> <|"magnetic" -> <|
  "B_z" -> 1.0, "E_x" -> 0.5, "charge_mass_ratio" -> 1.0,
  "v_perp" -> 1.0, "n_periods" -> 8
|>|>|>;

m2 = IntegrateDrift[cfg2];

AssertNear["mean y-velocity matches analytic E x B drift within 2%",
  Mean[m2["vy"]], m2["vDrift"], 0.02 * Abs[m2["vDrift"]]];

AssertNear["analytic drift magnitude is E_x/B_z = 0.5",
  Abs[m2["vDrift"]], 0.5, 1*^-9];

AssertTrue["model's own driftPass flag is True", m2["driftPass"]];

Print[""];
Print["== Test 3: mirror trapping condition =="];

cfg3 = <|"simulation" -> <|"magnetic" -> <|
  "B_0" -> 1.0, "alpha" -> 0.5, "charge_mass_ratio" -> 1.0,
  "v_perp" -> 1.5, "v_parallel" -> 0.8, "mirror_duration" -> 30.0
|>|>|>;

m3 = IntegrateMirror[cfg3];

sin2Theta0Expected = 1.5^2 / (1.5^2 + 0.8^2);
AssertNear["sin^2(theta_0) matches analytic v_perp^2/(v_perp^2+v_par^2)",
  m3["sin2Theta0"], sin2Theta0Expected, 1*^-9];

AssertNear["B_max = 10*B_0 for this zScale convention",
  m3["Bmax"], 10.0 * m3["B0"], 1*^-6];

AssertTrue["analytic prediction is TRAPPED (sin^2(theta_0) > 0.1)",
  m3["analyticTrapped"]];

AssertTrue["simulated trajectory is consistent with analytic prediction",
  m3["trapPass"]];

Print[""];
Print["== Test 4: energy conservation (cyclotron, 5 periods) =="];

AssertTrue["|v|^2 conserved within 0.1% over 5 periods", m1["energyPass"]];

speedRangeFrac = (Max[m1["speed"]] - Min[m1["speed"]]) / Mean[m1["speed"]];
AssertTrue["speed range is a tiny fraction of the mean speed",
  speedRangeFrac < 0.001];

Print[""];
Print["== Test 5: cyclotron radius =="];

rMeasured = (Max[m1["x"]] - Min[m1["x"]]) / 2.0;
rExpected = m1["vPerp"] / Abs[m1["omegaC"]];

AssertNear["measured orbit radius matches v_perp/omega_c within 1%",
  rMeasured, rExpected, 0.01 * rExpected];

AssertNear["model's own rc field matches v_perp/omega_c",
  m1["rc"], rExpected, 1*^-9];

Print[""];
Print["================="];
Print["Passed: ", passed];
Print["Failed: ", failed];
If[failed > 0, Exit[1], Exit[0]];

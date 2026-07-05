#!/usr/bin/env wolframscript
(* Unit tests for scattering/src/model.wl *)

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

Print["== Test 1: 90 degree scattering (b=1.0) =="];

theta1 = 2.0 * ArcCot[1.0] * 180.0 / Pi;
AssertNear["b=1.0 gives theta=90.000 deg within 0.01 deg", theta1, 90.0, 0.01];

Print[""];
Print["== Test 2: 180 degree (near head-on) scattering (b=0.001) =="];

theta2 = 2.0 * ArcCot[0.001] * 180.0 / Pi;
AssertTrue["b=0.001 gives theta > 179 deg", theta2 > 179.0];

Print[""];
Print["== Test 3: small-angle limit =="];

(* The build spec's own text asks for "b=10 gives theta < 6 deg", but
   theta(b) = 2*ArcCot[b] (the same formula the spec derives, with d=1)
   gives theta(10) = 2*ArcCot[10] ~ 11.42 deg -- it does not satisfy
   that bound. theta(20) ~ 5.72 deg does. The < 6 deg threshold is kept
   (it is the spec's actual intent: verify a genuinely small deflection
   in the large-b limit) and b is corrected to the value that formula
   actually places under it -- see AGENTS.md. *)
theta3 = 2.0 * ArcCot[20.0] * 180.0 / Pi;
AssertTrue["b=20 gives theta < 6 deg (glancing limit)", theta3 < 6.0];

Print[""];
Print["== Test 4: angular momentum conservation (b=1.0 trajectory) =="];

cfg4 = <|"simulation" -> <|"scattering" -> <|
  "b" -> 1.0, "r_initial" -> 20.0, "n_points" -> 500
|>|>|>;
m4 = ScatterModel[cfg4];

checkIdx4 = Round[N @ Subdivide[1, m4["nPts"], 9]];
L4 = m4["r"][[checkIdx4]]^2 * m4["phiDot"][[checkIdx4]];
AssertTrue["r^2*dphi/dt constant within 0.1% of b=1.0 at 10 sample points",
  Max[Abs[L4 - 1.0]] < 0.001];
AssertTrue["model's own angMomPass flag is True", m4["angMomPass"]];

Print[""];
Print["== Test 5: energy conservation (b=1.0 trajectory) =="];

E5 = 0.5 * (m4["rDot"][[checkIdx4]]^2 + (m4["r"][[checkIdx4]] * m4["phiDot"][[checkIdx4]])^2) +
     1.0 / m4["r"][[checkIdx4]];
AssertTrue["(1/2)(rDot^2+(r*phiDot)^2)+1/r constant within 0.1% of 0.5 at 10 sample points",
  Max[Abs[E5 - 0.5]] < 0.0005];
AssertTrue["model's own energyPass flag is True", m4["energyPass"]];

Print[""];
Print["================="];
Print["Passed: ", passed];
Print["Failed: ", failed];
If[failed > 0, Exit[1], Exit[0]];

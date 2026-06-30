#!/usr/bin/env wolframscript
(* Unit tests for lagrange/src/model.wl *)

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

(* Set test mass parameter — Sun-Jupiter system *)
$mu = 0.000954;

Print["== EOM helpers =="];

AssertTrue["r1 at origin near 1-mu",
  Abs[$r1[0.0, 0.0] - $mu] < 1*^-9];

AssertTrue["r2 at origin near mu",
  Abs[$r2[0.0, 0.0] - (1 - $mu)] < 1*^-9];

AssertNear["r1 is symmetric in y",
  $r1[0.3, 0.4], $r1[0.3, -0.4]];

AssertNear["r2 is symmetric in y",
  $r2[0.3, 0.4], $r2[0.3, -0.4]];

AssertTrue["fx has Coriolis term",
  Abs[$fx[0.0, 0.0, 1.0] - (2*1.0 + (-(1-$mu)*$mu/$r1[0,0]^3 - $mu*(-1+$mu)/$r2[0,0]^3))] < 1*^-8];

AssertTrue["Jacobi constant at rest at origin is positive",
  $jacobiC[0.0, 0.0, 0.0, 0.0] > 0];

AssertTrue["Jacobi constant at rest is larger than with velocity",
  $jacobiC[0.5, 0.5, 0.0, 0.0] > $jacobiC[0.5, 0.5, 0.5, 0.5]];

AssertTrue["omegaX approximate L1 guess is within 1.0 of zero (rough bracket check)",
  Abs[$omegaX[N[1 - $mu - ($mu/3)^(1/3)]]] < 1.0];

Print[""];
Print["== FindLagrangePoints =="];

$lpts = FindLagrangePoints[];

AssertTrue["returns Association",
  AssociationQ[$lpts]];

AssertTrue["has all 5 keys",
  Sort[Keys[$lpts]] === Sort[{"L1", "L2", "L3", "L4", "L5"}]];

AssertTrue["L4 has y > 0",
  $lpts["L4"][[2]] > 0];

AssertTrue["L5 has y < 0",
  $lpts["L5"][[2]] < 0];

AssertNear["L4 y-coordinate is sqrt(3)/2",
  $lpts["L4"][[2]], N[Sqrt[3]/2], 1*^-10];

AssertNear["L5 y-coordinate is -sqrt(3)/2",
  $lpts["L5"][[2]], -N[Sqrt[3]/2], 1*^-10];

AssertTrue["L1 x is between primaries",
  $lpts["L1"][[1]] > -$mu && $lpts["L1"][[1]] < 1 - $mu];

AssertTrue["L2 x is beyond secondary",
  $lpts["L2"][[1]] > 1 - $mu];

AssertTrue["L3 x is beyond primary (negative side)",
  $lpts["L3"][[1]] < -$mu];

AssertTrue["L1 y = 0",
  $lpts["L1"][[2]] === 0.0];

AssertTrue["L4 and L5 are symmetric (same x)",
  Abs[$lpts["L4"][[1]] - $lpts["L5"][[1]]] < 1*^-12];

AssertNear["L4 x-coordinate is 1/2 - mu",
  $lpts["L4"][[1]], 1/2 - $mu, 1*^-10];

AssertTrue["omegaX is zero at found L1",
  Abs[$omegaX[$lpts["L1"][[1]]]] < 1*^-8];

Print[""];
Print["== GeometryCheck =="];

AssertTrue["geometry check passes for sun-jupiter",
  GeometryCheck[$lpts]];

AssertTrue["r1 from L4 = 1.0",
  Abs[$r1[$lpts["L4"][[1]], $lpts["L4"][[2]]] - 1.0] < 1*^-6];

AssertTrue["r2 from L4 = 1.0",
  Abs[$r2[$lpts["L4"][[1]], $lpts["L4"][[2]]] - 1.0] < 1*^-6];

AssertTrue["r1 from L5 = 1.0",
  Abs[$r1[$lpts["L5"][[1]], $lpts["L5"][[2]]] - 1.0] < 1*^-6];

(* Geometry check fails with wrong mu *)
Block[{$mu = 0.5},
  $lptsBad = <|"L4" -> {0.3, 0.1}, "L5" -> {0.3, -0.1}|>;
  AssertTrue["geometry check fails for garbage lpts",
    !GeometryCheck[$lptsBad]]];

Print[""];
Print["== LibrationModel (fast: 1 orbital period) =="];

$cfgFast = <|"simulation" -> <|"lagrange" -> <|
  "perturbation"    -> 0.02,
  "duration_periods"-> 1
|>|>|>;

libModel = LibrationModel["l4", $lpts, True, $cfgFast];

AssertTrue["LibrationModel returns Association",
  AssociationQ[libModel]];

AssertTrue["has required keys",
  AllTrue[{"xV","yV","vxV","vyV","r1V","r2V","omV","invDV","dLP",
           "nPts","tEnd","lLabel","c1Pass","c2Pass","c3Pass","c4Pass"}, KeyExistsQ[libModel, #] &]];

AssertTrue["nPts = 600",
  libModel["nPts"] === 600];

AssertTrue["tEnd near 2*Pi (1 period)",
  Abs[libModel["tEnd"] - N[2*Pi]] < 0.01];

AssertTrue["lLabel = L4",
  libModel["lLabel"] === "L4"];

AssertTrue["c2Pass = True (passed from caller)",
  libModel["c2Pass"] === True];

AssertTrue["r1V all positive",
  Min[libModel["r1V"]] > 0];

AssertTrue["r2V all positive",
  Min[libModel["r2V"]] > 0];

AssertTrue["invDV all positive",
  Min[libModel["invDV"]] > 0];

AssertTrue["Jacobi check passes (c1Pass)",
  libModel["c1Pass"]];

AssertTrue["libration bounded (c3Pass)",
  libModel["c3Pass"]];

AssertTrue["no escape (c4Pass)",
  libModel["c4Pass"]];

Print[""];
Print["== EscapeModel (fast: L1 escape) =="];

escModel = EscapeModel[$lpts, True, $cfgFast];

AssertTrue["EscapeModel returns Association",
  AssociationQ[escModel]];

AssertTrue["has required keys",
  AllTrue[{"xV","yV","dL1","tActual","distGrowth","c1Pass","c3Pass","c4Pass"},
    KeyExistsQ[escModel, #] &]];

AssertTrue["tActual > 0",
  escModel["tActual"] > 0];

AssertTrue["distGrowth > 3 (escape confirmed)",
  escModel["distGrowth"] > 3.0];

AssertTrue["c3Pass (escape confirmed)",
  escModel["c3Pass"]];

Print[""];
Print["================="];
Print["Passed: ", passed];
Print["Failed: ", failed];
If[failed > 0, Exit[1], Exit[0]];

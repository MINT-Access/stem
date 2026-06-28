#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_analyse.wl
   Tests analysis functions using synthetic asteroid data.
   Does NOT call the NASA API — runs fully offline.
   Usage: wolframscript -file tests/test_analyse.wl
   ======================================================== *)

$projectRoot  = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "analyse.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];

passed = 0; failed = 0;

AssertTrue[label_String, cond_] :=
  If[TrueQ[cond],
    Print["  PASS  ", label]; passed++,
    Print["  FAIL  ", label]; failed++]

AssertNear[label_String, val_, ref_, tol_:0.001] :=
  AssertTrue[label, Abs[N[val] - N[ref]] <= tol * Abs[N[ref] + 1*^-9]]

(* --- Synthetic test data --- *)
testAsteroids = {
  <| "name"->"Ast-A", "approachDate"->"2026-06-20",
     "missDistanceKm"->300000.0, "velocityKmS"->12.5,
     "diamMinKm"->0.08, "diamMaxKm"->0.18, "diamMeanKm"->0.13,
     "isHazardous"->False, "absoluteMag"->22.1 |>,
  <| "name"->"Ast-B", "approachDate"->"2026-06-21",
     "missDistanceKm"->750000.0, "velocityKmS"->8.2,
     "diamMinKm"->0.30, "diamMaxKm"->0.50, "diamMeanKm"->0.40,
     "isHazardous"->True,  "absoluteMag"->20.3 |>,
  <| "name"->"Ast-C", "approachDate"->"2026-06-22",
     "missDistanceKm"->1500000.0, "velocityKmS"->22.0,
     "diamMinKm"->0.01, "diamMaxKm"->0.03, "diamMeanKm"->0.02,
     "isHazardous"->False, "absoluteMag"->26.0 |>,
  <| "name"->"Ast-D", "approachDate"->"2026-06-23",
     "missDistanceKm"->4000000.0, "velocityKmS"->15.0,
     "diamMinKm"->1.20, "diamMaxKm"->1.80, "diamMeanKm"->1.50,
     "isHazardous"->True,  "absoluteMag"->17.5 |>
};

Print["Running analysis tests (offline — no API call)..."];
Print[""];

(* Test 1: HazardousAsteroids filter *)
haz = HazardousAsteroids[testAsteroids];
AssertTrue["HazardousAsteroids returns 2", Length[haz] == 2];
AssertTrue["All returned are hazardous",
  AllTrue[haz, #["isHazardous"] &]];

(* Test 2: SafeAsteroids filter *)
safe = SafeAsteroids[testAsteroids];
AssertTrue["SafeAsteroids returns 2", Length[safe] == 2];
AssertTrue["None of safe are hazardous",
  AllTrue[safe, !#["isHazardous"] &]];

(* Test 3: ClosestAsteroids *)
closest = ClosestAsteroids[testAsteroids, 2];
AssertTrue["ClosestAsteroids returns 2", Length[closest] == 2];
AssertTrue["First is truly closest",
  closest[[1]]["missDistanceKm"] <= closest[[2]]["missDistanceKm"]];

(* Test 4: MissDistanceStats *)
stats = MissDistanceStats[testAsteroids];
AssertTrue["Count correct",   stats["count"] == 4];
AssertNear["Min distance",    stats["minKm"],    300000.0];
AssertNear["Max distance",    stats["maxKm"],   4000000.0];
AssertNear["Mean distance",   stats["meanKm"],  1637500.0];

(* Test 5: VelocityStats *)
vel = VelocityStats[testAsteroids];
AssertNear["Min velocity",  vel["minKmS"],  8.2];
AssertNear["Max velocity",  vel["maxKmS"],  22.0];

(* Test 6: SizeClass boundaries *)
AssertTrue["Small class (<50 m)",
  SizeClass[0.04] == "Small    (<50 m)"];
AssertTrue["Medium class (50-140 m)",
  SizeClass[0.10] == "Medium   (50-140 m)"];
AssertTrue["Large class (140 m - 1 km)",
  SizeClass[0.50] == "Large    (140 m - 1 km)"];
AssertTrue["Enormous class (>1 km)",
  SizeClass[1.50] == "Enormous (>1 km)"];

(* Test 7: SizeDistribution counts *)
dist = SizeDistribution[testAsteroids];
AssertTrue["Size distribution has 4 classes",
  Total[Values[dist]] == 4];

(* Test 8: Unit conversions *)
AssertNear["1 Lunar Distance converts correctly",
  ToLunarDistances[$LunarDistance], 1.0];
AssertNear["Earth radius converts correctly",
  ToEarthRadii[$EarthRadius], 1.0];

(* Test 9: ClosestApproachSummary includes name *)
summary = ClosestApproachSummary[testAsteroids[[1]]];
AssertTrue["Summary contains asteroid name",
  StringContainsQ[summary, testAsteroids[[1]]["name"]]];

(* Test 10: Hazardous summary includes warning *)
hazSummary = ClosestApproachSummary[testAsteroids[[2]]];
AssertTrue["Hazardous summary includes warning",
  StringContainsQ[hazSummary, "HAZARDOUS"]];

Print[""];
Print["Running orbital mechanics tests (offline — no API call)..."];
Print[""];

(* Test 11: SolveKepler — verify solution satisfies M = E - e sin E *)
Module[{e = 0.5, M = 1.0, E},
  E = SolveKepler[M, e];
  AssertTrue["Kepler: solution satisfies equation to 1e-10",
    Abs[E - e*Sin[E] - M] < 1*^-10]
];

(* Test 12: OrbitalToEcliptic2D — identity when i=0, Ω=0, ω=0 *)
Module[{res},
  res = OrbitalToEcliptic2D[1.0, 2.0, 0.0, 0.0, 0.0];
  AssertNear["OrbitalToEcliptic2D identity: x", res[[1]], 1.0];
  AssertNear["OrbitalToEcliptic2D identity: y", res[[2]], 2.0]
];

(* Test 13: ComputeGeocentricAngle with 433 Eros elements — result in [-Pi, Pi] *)
Module[{erosElements, angle},
  erosElements = <|
    "e"        -> 0.2229,
    "a"        -> 1.4580,
    "i"        -> 10.829,
    "om"       -> 304.32,
    "w"        -> 178.82,
    "ma"       -> 321.39,
    "per"      -> 643.219,
    "epoch_jd" -> 2451545.0
  |>;
  angle = ComputeGeocentricAngle[erosElements, "2026-06-26"];
  AssertTrue["ComputeGeocentricAngle: returns a real number",
    NumericQ[angle]];
  AssertTrue["ComputeGeocentricAngle: result in [-Pi, Pi]",
    NumericQ[angle] && -Pi <= angle <= Pi]
];

(* Test 14: AugmentAsteroidsWithAngles fallback — $Failed elements yields valid random angle *)
Module[{testAst, augmented, angle},
  testAst = <|
    "id"           -> "9999999",
    "name"         -> "Test-Fallback",
    "approachDate" -> "2026-06-26",
    "missDistanceKm" -> 500000.0,
    "velocityKmS"  -> 10.0,
    "diamMinKm"    -> 0.1,
    "diamMaxKm"    -> 0.2,
    "diamMeanKm"   -> 0.15,
    "isHazardous"  -> False,
    "absoluteMag"  -> 23.0,
    "orbital_elements" -> $Failed
  |>;
  augmented = AugmentAsteroidsWithAngles[{testAst}];
  angle     = augmented[[1]]["geocentricAngle"];
  AssertTrue["Fallback: geocentricAngle key present", KeyExistsQ[augmented[[1]], "geocentricAngle"]];
  AssertTrue["Fallback: angle is numeric",  NumericQ[angle]];
  AssertTrue["Fallback: angle in [0, 2Pi]", 0 <= angle <= 2*Pi]
];

Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the primes model
   Usage: wolframscript -file tests/test_model.wl
   ======================================================== *)

$projectRoot  = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];

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

(* --- UlamCoords tests --- *)

coords = UlamCoords[5];

(* Test 1: 5x5 grid produces 25 coordinates *)
AssertTrue["UlamCoords[5] produces 25 coordinates",
  Length[coords] === 25];

(* Test 2: all coordinates are in range [1,5] *)
AssertTrue["All Ulam coordinates are within grid bounds",
  Min[coords] >= 1 && Max[coords] <= 5];

(* Test 3: first coordinate is the centre of the grid *)
AssertTrue["Ulam spiral starts at centre {3,3}",
  coords[[1]] === {3, 3}];

(* --- UlamModel tests --- *)

ulamCfg = <|
  "simulation" -> <|
    "mode" -> "ulam",
    "ulam" -> <|
      "size"           -> 11,
      "color_primes"   -> "white",
      "color_composite"-> "black"
    |>
  |>
|>;

ulamModel = UlamModel[ulamCfg];

(* Test 4: returns Association with required keys *)
AssertTrue["UlamModel returns Association with grid/size/prime_count",
  AssociationQ[ulamModel] && KeyExistsQ[ulamModel, "grid"] &&
  KeyExistsQ[ulamModel, "size"] && KeyExistsQ[ulamModel, "prime_count"]];

(* Test 5: grid dimensions are size x size *)
AssertTrue["Ulam grid has correct dimensions",
  Dimensions[ulamModel["grid"]] === {11, 11}];

(* Test 6: mode field is "ulam" *)
AssertTrue["UlamModel mode field is \"ulam\"",
  ulamModel["mode"] === "ulam"];

(* Test 7: prime_count matches sum of grid *)
AssertTrue["prime_count equals Total[grid,2]",
  ulamModel["prime_count"] === Total[ulamModel["grid"], 2]];

(* Test 8: prime density is between 0 and 1 *)
AssertTrue["Prime density is between 0 and 1",
  0.0 < ulamModel["prime_density"] < 1.0];

(* Test 9: known primes are in the grid — 2 is at position coords[[2]] *)
With[{coord2 = ulamModel["coords"][[2]]},
  AssertTrue["Integer 2 is marked prime in the grid",
    ulamModel["grid"][[coord2[[1]], coord2[[2]]]] === 1]];

(* Test 10: 1 is not prime — position [[1]] should be 0 *)
With[{coord1 = ulamModel["coords"][[1]]},
  AssertTrue["Integer 1 is not marked prime in the grid",
    ulamModel["grid"][[coord1[[1]], coord1[[2]]]] === 0]];

(* --- GapsModel tests --- *)

gapsCfg = <|
  "simulation" -> <|
    "mode" -> "gaps",
    "gaps" -> <| "count" -> 50 |>
  |>
|>;

gapsModel = GapsModel[gapsCfg];

(* Test 11: returns Association with required keys *)
AssertTrue["GapsModel returns Association with primes/gaps/mean_gap",
  AssociationQ[gapsModel] && KeyExistsQ[gapsModel, "primes"] &&
  KeyExistsQ[gapsModel, "gaps"] && KeyExistsQ[gapsModel, "mean_gap"]];

(* Test 12: correct number of primes *)
AssertTrue["GapsModel returns exactly 50 primes",
  Length[gapsModel["primes"]] === 50];

(* Test 13: gaps has one fewer element than primes *)
AssertTrue["Gaps list is one shorter than primes list",
  Length[gapsModel["gaps"]] === Length[gapsModel["primes"]] - 1];

(* Test 14: first prime is 2 *)
AssertTrue["First prime is 2",
  gapsModel["primes"][[1]] === 2];

(* Test 15: all gaps are even (except the gap 2→3) *)
(* All prime gaps beyond the first are even since primes > 2 are odd *)
AssertTrue["All gaps after the first are even",
  AllTrue[Rest[gapsModel["gaps"]], EvenQ]];

(* Test 16: twin_prime_count matches gaps equal to 2 *)
twinCount = Length[Select[gapsModel["gaps"], # === 2 &]];
AssertTrue["twin_prime_count matches number of gaps equal to 2",
  gapsModel["twin_prime_count"] === twinCount];

(* Test 17: max_gap >= 2 *)
AssertTrue["max_gap is at least 2",
  gapsModel["max_gap"] >= 2];

(* --- Summary --- *)
Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

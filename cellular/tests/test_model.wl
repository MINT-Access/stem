#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the cellular automata model
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

(* --- LifeModel tests --- *)

smallCfg = <|
  "simulation" -> <|
    "mode" -> "life",
    "life" -> <|
      "rows" -> 20,
      "cols" -> 20,
      "generations" -> 10,
      "wrap" -> True,
      "starting_pattern" -> "rpentomino"
    |>
  |>
|>;

grid3D = LifeModel[smallCfg];

(* Test 1: returns a 3D array of the right shape *)
AssertTrue["LifeModel returns {gens, rows, cols} array",
  Dimensions[grid3D] === {10, 20, 20}];

(* Test 2: all values are 0 or 1 *)
AssertTrue["All cell values are 0 or 1",
  Min[grid3D] === 0 && Max[grid3D] === 1];

(* Test 3: R-pentomino initial population is 5 *)
AssertTrue["R-pentomino starts with 5 live cells",
  Total[grid3D[[1]], 2] === 5];

(* Test 4: population changes over time (R-pentomino is not static) *)
pops = Map[Total[#, 2] &, grid3D];
AssertTrue["Population is not constant over all generations",
  Length[Union[pops]] > 1];

(* --- GoLStep tests --- *)

(* Test 5: a 3x3 block (2x2 blinker core) is a still life *)
stillGrid = ConstantArray[0, {10, 10}];
stillGrid[[4, 4]] = 1; stillGrid[[4, 5]] = 1;
stillGrid[[5, 4]] = 1; stillGrid[[5, 5]] = 1;
AssertTrue["2x2 block is a still life",
  GoLStep[stillGrid, True] === stillGrid];

(* Test 6: a single cell dies from under-population *)
lonelyCfg = <|
  "simulation" -> <|
    "mode" -> "life",
    "life" -> <|
      "rows" -> 10, "cols" -> 10,
      "generations" -> 2, "wrap" -> True,
      "starting_pattern" -> "random"
    |>
  |>
|>;
lonelyGrid = ConstantArray[0, {10, 10}];
lonelyGrid[[5, 5]] = 1;
AssertTrue["Single isolated cell dies in one step",
  Total[GoLStep[lonelyGrid, True], 2] === 0];

(* --- Rule110Model tests --- *)

rule110Cfg = <|
  "simulation" -> <|
    "mode" -> "rule110",
    "rule110" -> <|
      "width" -> 30,
      "generations" -> 15,
      "initial" -> "single_cell"
    |>
  |>
|>;

r110 = Rule110Model[rule110Cfg];

(* Test 7: returns a 3D array with a singleton second dimension *)
AssertTrue["Rule110Model returns {gens, 1, width} array",
  Dimensions[r110] === {15, 1, 30}];

(* Test 8: all values are 0 or 1 *)
AssertTrue["Rule110 values are all 0 or 1",
  Min[r110] === 0 && Max[r110] === 1];

(* Test 9: single-cell initial condition starts with exactly 1 live cell *)
AssertTrue["Single-cell init has 1 live cell in generation 0",
  Total[r110[[1, 1]]] === 1];

(* --- LifeGrid tests --- *)

(* Test 10: gliderlgun pattern produces more than 5 cells *)
gunGrid = LifeGrid["gliderlgun", 80, 80];
AssertTrue["Glider gun grid has more than 5 live cells",
  Total[gunGrid, 2] > 5];

(* --- Sonification: run-length note articulation tests --- *)

articCfg[mode_String, threshRel_, threshAbs_] := <|
  "simulation" -> <|
    "cellular" -> <|
      "articulation_mode"          -> mode,
      "articulation_threshold"     -> threshRel,
      "articulation_threshold_abs" -> threshAbs
    |>
  |>
|>;

(* Test 11: stable run — all changes under 3% group into one run *)
stablePops = {100.0, 101.0, 100.0, 99.0, 101.0};
stableRuns = ComputeRuns[stablePops, articCfg["relative", 0.03, 5]];
AssertTrue["Stable population series groups into a single run",
  Length[stableRuns["runs"]] === 1 && stableRuns["runs"][[1]]["length"] === 5];

(* Test 12: articulation points at generations 2 and 4, not 3 *)
growthPops = {100.0, 150.0, 151.0, 200.0};
growthArtic = ComputeArticulations[growthPops, articCfg["relative", 0.03, 5]];
AssertTrue["Articulation fires at generations 2 and 4 but not 3",
  growthArtic === {1, 1, 0, 1}];

(* Test 13: note duration — run of length 10 at 0.06 s/gen = 0.6 s *)
AssertTrue["RunNoteDuration[10, 0.06] equals 0.6 seconds",
  Abs[RunNoteDuration[10, 0.06] - 0.6] < 10^-9];

(* Test 14: absolute mode — articulation at generation 4 (Δ=9 > 5), not 2 or 3 (Δ=3 each) *)
absPops = {100.0, 103.0, 106.0, 115.0};
absArtic = ComputeArticulations[absPops, articCfg["absolute", 0.03, 5]];
AssertTrue["Absolute-mode articulation fires only at generation 4",
  absArtic === {1, 0, 0, 1}];

(* Test 15: EventLayer preservation — explosion/collapse detection is
   independent of the run-length articulation refactor. A population
   series with a >40% rise and a later >40% drop must still produce
   exactly one explosion and one extinction event. *)
eventPops = {50.0, 50.0, 90.0, 90.0, 30.0, 30.0};
eventResult = DetectPopulationEvents[eventPops, <||>];
AssertTrue["Explosion (>40% rise) is still detected after refactor",
  eventResult["explosions"] === {1}];
AssertTrue["Extinction (>40% drop) is still detected after refactor",
  eventResult["extinctions"] === {3}];

(* --- Summary --- *)
Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the cellular automata model
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

(* --- Summary --- *)
Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

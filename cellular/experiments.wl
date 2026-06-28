#!/usr/bin/env wolframscript

(* ========================================================
   experiments.wl — Cellular automata parameter experiments

   Run all experiments:
     wolframscript -file experiments.wl

   Each experiment writes its own GIF, WAV, and CSV to output/
   so the results can be compared side by side.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];


(* --- Helper: run one named Life experiment --- *)

RunLifeExperiment[name_String, cfg_Association] :=
  Module[{grid3D, gens, outCSV, outGIF, outWAV},
    gens = GetCfg[cfg, {"simulation","life","generations"}, 300];
    Print[""];
    Print[">>> Experiment: ", name, "  (", gens, " generations)"];

    grid3D = LifeModel[cfg];
    PrintCellularSummary[grid3D, name];

    outCSV = FileNameJoin[{$outDir, name <> "_stats.csv"}];
    ExportCellularStats[grid3D, outCSV];
    Print["    CSV -> ", outCSV];

    outGIF = FileNameJoin[{$outDir, name <> "_animation.gif"}];
    AnimateCellular[grid3D, cfg, outGIF];
    Print["    GIF -> ", outGIF];

    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    SonifyCellular[grid3D, cfg, outWAV];
    Print["    WAV -> ", outWAV];
  ]


(* --- Helper: run one named Rule110 experiment --- *)

RunRule110Experiment[name_String, cfg_Association] :=
  Module[{grid3D, gens, outCSV, outGIF, outWAV},
    gens = GetCfg[cfg, {"simulation","rule110","generations"}, 200];
    Print[""];
    Print[">>> Experiment: ", name, "  (", gens, " generations)"];

    grid3D = Rule110Model[cfg];
    PrintCellularSummary[grid3D, name];

    outCSV = FileNameJoin[{$outDir, name <> "_stats.csv"}];
    ExportCellularStats[grid3D, outCSV];
    Print["    CSV -> ", outCSV];

    outGIF = FileNameJoin[{$outDir, name <> "_animation.gif"}];
    AnimateCellular[grid3D, cfg, outGIF];
    Print["    GIF -> ", outGIF];

    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    SonifyCellular[grid3D, cfg, outWAV];
    Print["    WAV -> ", outWAV];
  ]


(* ================================================================
   EXPERIMENT DEFINITIONS
   ================================================================ *)

(* --- rpentomino_default: classic 5-cell seed, 300 generations --- *)
(* The R-pentomino is the canonical Game of Life seed:
   a tiny 5-cell shape that produces centuries of chaotic activity. *)
RunLifeExperiment["rpentomino_default", <|
  "simulation" -> <|
    "mode" -> "life",
    "life" -> <|
      "rows" -> 80, "cols" -> 80,
      "generations" -> 300,
      "wrap" -> True,
      "starting_pattern" -> "rpentomino"
    |>
  |>,
  "animation" -> <| "fps" -> 10 |>,
  "sonification" -> <| "pitch" -> <| "min_hz" -> 150, "max_hz" -> 900 |> |>
|>];


(* --- glider_gun: Gosper Glider Gun emitting a glider every 30 generations --- *)
(* The glider gun is a periodic oscillator that manufactures gliders.
   After ~100 generations you hear regular pulses as each glider escapes
   and then wraps around to collide with the gun stream. *)
RunLifeExperiment["glider_gun", <|
  "simulation" -> <|
    "mode" -> "life",
    "life" -> <|
      "rows" -> 80, "cols" -> 80,
      "generations" -> 300,
      "wrap" -> True,
      "starting_pattern" -> "gliderlgun"
    |>
  |>,
  "animation" -> <| "fps" -> 10 |>,
  "sonification" -> <| "pitch" -> <| "min_hz" -> 150, "max_hz" -> 900 |>,
    "events" -> <| "extinction" -> True, "explosion" -> True |> |>
|>];


(* --- rule110_sparse: single-cell seed — grows into complex triangular patterns --- *)
(* Rule 110 from a single live cell produces an aperiodic spacetime diagram
   that is Turing-complete. The audio has a regular low-frequency pulse from
   the repeating triangular structure. *)
RunRule110Experiment["rule110_sparse", <|
  "simulation" -> <|
    "mode" -> "rule110",
    "rule110" -> <|
      "width" -> 120,
      "generations" -> 200,
      "initial" -> "single_cell"
    |>
  |>,
  "animation" -> <| "fps" -> 10 |>,
  "sonification" -> <| "pitch" -> <| "min_hz" -> 200, "max_hz" -> 800 |> |>
|>];


(* --- rule110_dense: random seed — fills quickly then organises --- *)
(* Starting from random noise, Rule 110 rapidly settles into its characteristic
   triangular pattern. The sonification captures the transition from chaos to
   structured repetition. *)
RunRule110Experiment["rule110_dense", <|
  "simulation" -> <|
    "mode" -> "rule110",
    "rule110" -> <|
      "width" -> 120,
      "generations" -> 200,
      "initial" -> "random"
    |>
  |>,
  "animation" -> <| "fps" -> 10 |>,
  "sonification" -> <| "pitch" -> <| "min_hz" -> 200, "max_hz" -> 800 |> |>
|>];


(* --- chaos: random 30% seed Game of Life — population statistics are stochastic --- *)
(* A random board explores the full Game of Life rule landscape.
   Population typically rises, crashes, and stabilises into a mix of still
   lifes and small oscillators. The audio captures this dramatic arc. *)
RunLifeExperiment["chaos", <|
  "simulation" -> <|
    "mode" -> "life",
    "life" -> <|
      "rows" -> 80, "cols" -> 80,
      "generations" -> 300,
      "wrap" -> True,
      "starting_pattern" -> "random"
    |>
  |>,
  "animation" -> <| "fps" -> 10 |>,
  "sonification" -> <| "pitch" -> <| "min_hz" -> 150, "max_hz" -> 900 |>,
    "events" -> <| "extinction" -> True, "explosion" -> True |> |>
|>];


Print[""];
Print["=== All experiments complete. Files are in output/ ==="];

#!/usr/bin/env wolframscript

(* ========================================================
   Cellular Automata — Entry Point
   Usage:
     wolframscript -file main.wl [-- [--key=value ...]]
     wolframscript -file main.wl -- --config-dump
     wolframscript -file main.wl -- --simulation.mode=rule110
     wolframscript -file main.wl -- --simulation.life.starting_pattern=gliderlgun
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

(* --- Load config (exits here if --config-dump is present) --- *)
$cliArgs = Select[Rest[$ScriptCommandLine], # =!= "--" &];
cfg  = LoadConfig["cellular", $cliArgs];
mode = GetCfg[cfg, {"simulation","mode"}, "life"];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

Which[

  (* ══════════════════════════════════════════════════════
     GAME OF LIFE
     ══════════════════════════════════════════════════════ *)
  mode === "life",

    pattern = GetCfg[cfg, {"simulation","life","starting_pattern"}, "rpentomino"];
    rows    = GetCfg[cfg, {"simulation","life","rows"},             80];
    cols    = GetCfg[cfg, {"simulation","life","cols"},             80];
    gens    = GetCfg[cfg, {"simulation","life","generations"},     300];
    wrap    = GetCfg[cfg, {"simulation","life","wrap"},           True];

    STEMHeading["Cellular Automata: Game of Life"];
    Print["  Pattern:     ", pattern];
    Print["  Grid:        ", rows, " x ", cols];
    Print["  Generations: ", gens];
    Print["  Boundary:    ", If[wrap, "toroidal (wrap)", "fixed (no wrap)"]];
    Print[""];

    STEMSay["Starting Game of Life: " <> pattern];

    Print["[1/4] Running simulation..."];
    grid3D = LifeModel[cfg];
    Print["  Computed ", Dimensions[grid3D][[1]], " generations."];
    PrintCellularSummary[grid3D, "life/" <> pattern];
    Print[""];

    Print["[2/4] Exporting statistics CSV..."];
    outCSV = FileNameJoin[{$outDir, "life_" <> pattern <> "_stats.csv"}];
    ExportCellularStats[grid3D, outCSV];
    STEMDescribeCSV[outCSV, gens, 6];
    Print[""];

    Print["[3/4] Rendering animation..."];
    STEMSay["Rendering animation"];
    outGIF = FileNameJoin[{$outDir, "life_" <> pattern <> "_animation.gif"}];
    AnimateCellular[grid3D, cfg, outGIF];
    STEMDescribeGIF[outGIF, gens, GetCfg[cfg, {"animation","fps"}, 10]];
    Print[""];

    Print["[4/4] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$outDir, "life_" <> pattern <> "_audio.wav"}];
    SonifyCellular[grid3D, cfg, outWAV];
    STEMDescribeWAV[outWAV, gens * 0.1];
    Print[""],


  (* ══════════════════════════════════════════════════════
     RULE 110
     ══════════════════════════════════════════════════════ *)
  mode === "rule110",

    width  = GetCfg[cfg, {"simulation","rule110","width"},       120];
    gens   = GetCfg[cfg, {"simulation","rule110","generations"}, 200];
    initIC = GetCfg[cfg, {"simulation","rule110","initial"},     "single_cell"];

    STEMHeading["Cellular Automata: Rule 110"];
    Print["  Width:       ", width];
    Print["  Generations: ", gens];
    Print["  Initial:     ", initIC];
    Print[""];

    STEMSay["Starting Rule 110 simulation"];

    Print["[1/4] Running simulation..."];
    grid3D = Rule110Model[cfg];
    Print["  Computed ", Dimensions[grid3D][[1]], " generations."];
    PrintCellularSummary[grid3D, "rule110"];
    Print[""];

    Print["[2/4] Exporting statistics CSV..."];
    outCSV = FileNameJoin[{$outDir, "rule110_stats.csv"}];
    ExportCellularStats[grid3D, outCSV];
    STEMDescribeCSV[outCSV, gens, 6];
    Print[""];

    Print["[3/4] Rendering spacetime diagram..."];
    STEMSay["Rendering spacetime diagram"];
    outGIF = FileNameJoin[{$outDir, "rule110_animation.gif"}];
    AnimateCellular[grid3D, cfg, outGIF];
    STEMDescribeGIF[outGIF, 1, GetCfg[cfg, {"animation","fps"}, 10]];
    Print[""];

    Print["[4/4] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$outDir, "rule110_audio.wav"}];
    SonifyCellular[grid3D, cfg, outWAV];
    STEMDescribeWAV[outWAV, gens * 0.1];
    Print[""],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"life\" or \"rule110\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Complete. Play audio: afplay " <> outWAV];

#!/usr/bin/env wolframscript

(* ========================================================
   Lorenz Attractor — Entry Point
   Usage: wolframscript -file main.wl [-- [--key=value ...]]
          wolframscript -file main.wl -- --config-dump
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
cfg = LoadConfig["lorenz", $cliArgs];

(* --- Build simulation params from config --- *)
With[{ic = GetCfg[cfg, {"simulation","initial_conditions"}, {0.1, 0.0, 0.0}]},
  params = <|
    "Sigma"    -> GetCfg[cfg, {"simulation","lorenz","sigma"}, 10.0],
    "Rho"      -> GetCfg[cfg, {"simulation","lorenz","rho"},   28.0],
    "Beta"     -> GetCfg[cfg, {"simulation","lorenz","beta"},  8/3],
    "InitX"    -> N[ic[[1]]],
    "InitY"    -> N[ic[[2]]],
    "InitZ"    -> N[ic[[3]]],
    "TimeEnd"  -> GetCfg[cfg, {"simulation","duration"},       40.0],
    "TimeStep" -> GetCfg[cfg, {"simulation","timestep"},       0.005]
  |>
];

STEMHeading["Lorenz Attractor"];
Print["  sigma = ", params["Sigma"],
      "   rho = ", params["Rho"],
      "   beta = ", FmtN[N[params["Beta"]], 4]];
Print["  Initial: (",
  params["InitX"], ", ",
  params["InitY"], ", ",
  params["InitZ"], ")"];
Print["  Duration: ", params["TimeEnd"], " s"];
Print[""];

(* 1. Solve *)
Print["[1/4] Solving Lorenz ODE..."];
solution = SolveLorenz[params];
Print["  Computed ", Length[solution], " steps."];
PrintSummary[solution, params];
Print[""];

(* 2. CSV *)
Print["[2/4] Exporting trajectory data..."];
outCSV = FileNameJoin[{$projectRoot, "data", "lorenz_trajectory.csv"}];
ExportResults[solution, params, outCSV];
STEMDescribeCSV[outCSV, Length[solution], 5];
Print[""];

(* 3. Animation *)
Print["[3/4] Rendering animation..."];
outGIF = FileNameJoin[{$projectRoot, "data", "lorenz_animation.gif"}];
ExportAnimation[solution, outGIF, 30, 150, "Lorenz Attractor"];
STEMDescribeGIF[outGIF, 150, 30];
Print[""];

(* 4. Sonification *)
Print["[4/4] Synthesising audio..."];
outWAV = FileNameJoin[{$projectRoot, "data", "lorenz_audio.wav"}];
ExportSonification[solution, params, cfg, outWAV];
STEMDescribeWAV[outWAV, solution[[-1, 1]]];
Print[""];

STEMHeading["Done"];
STEMSay["Play audio:  afplay " <> outWAV];

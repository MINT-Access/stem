#!/usr/bin/env wolframscript

(* ========================================================
   Pendulum Simulation — Entry Point
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
cfg = LoadConfig["pendulum", $cliArgs];

(* --- Build simulation params from config --- *)
params = <|
  "Length"       -> GetCfg[cfg, {"simulation","simple","length"},     1.0],
  "Gravity"      -> GetCfg[cfg, {"simulation","gravity"},             9.81],
  "InitAngle"    -> GetCfg[cfg, {"simulation","simple","angle_deg"}, 45.0] * Pi / 180.0,
  "InitVelocity" -> 0.0,
  "TimeEnd"      -> GetCfg[cfg, {"simulation","duration"},           20.0],
  "TimeStep"     -> GetCfg[cfg, {"simulation","timestep"},           0.01]
|>;

STEMHeading["Pendulum Simulation"];
Print["  Length:        ", FmtN[params["Length"], 3], " m"];
Print["  Initial angle: ", FmtN[params["InitAngle"], 4], " rad (",
  FmtN[params["InitAngle"] * 180.0 / Pi, 3], " deg)"];
Print["  Duration:      ", params["TimeEnd"], " s"];
Print["  Period (small-angle approx): ",
  FmtN[2 Pi Sqrt[params["Length"] / params["Gravity"]], 4], " s"];
Print[""];

(* --- 1. Run the simulation --- *)
Print["[1/4] Solving ODE..."];
solution = SolvePendulum[params];
Print["  Computed ", Length[solution], " time steps."];
Print[""];

(* --- 2. Export CSV results --- *)
Print["[2/4] Exporting CSV..."];
outCSV = FileNameJoin[{$projectRoot, "data", "results.csv"}];
ExportResults[solution, params, outCSV];
STEMDescribeCSV[outCSV, Length[solution], 5];
PrintSummary[solution, params];
Print[""];

(* --- 3. Export animation --- *)
Print["[3/4] Generating animation..."];
outGIF = FileNameJoin[{$projectRoot, "data", "pendulum_animation.gif"}];
ExportAnimation[solution, params, outGIF, 25, 1.0];
STEMDescribeGIF[outGIF];
Print[""];

(* --- 4. Export sonification --- *)
Print["[4/4] Generating sonification..."];
outWAV = FileNameJoin[{$projectRoot, "data", "pendulum_audio.wav"}];
ExportSonification[solution, params, cfg, outWAV];
STEMDescribeWAV[outWAV, solution[[-1, 1]]];
Print[""];

STEMHeading["Done"];
STEMSay["Pendulum Simulation complete"];

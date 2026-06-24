#!/usr/bin/env wolframscript

(* ========================================================
   Pendulum Simulation — Entry Point
   Usage: wolframscript -file main.wl
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

(* --- Simulation parameters --- *)
params = <|
  "Length"       -> 1.0,   (* metres    *)
  "Gravity"      -> 9.81,  (* m/s^2     *)
  "InitAngle"    -> 0.4,   (* radians, approx 23 degrees *)
  "InitVelocity" -> 0.0,   (* rad/s     *)
  "TimeEnd"      -> 10.0,  (* seconds   *)
  "TimeStep"     -> 0.01   (* seconds   *)
|>;

Print["=== Pendulum Simulation ==="];
Print["  Length:        ", params["Length"], " m"];
Print["  Initial angle: ", params["InitAngle"], " rad (",
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
Print["  CSV: ", outCSV];
PrintSummary[solution, params];
Print[""];

(* --- 3. Export animation --- *)
Print["[3/4] Generating animation..."];
outGIF = FileNameJoin[{$projectRoot, "data", "pendulum_animation.gif"}];
ExportAnimation[solution, params, outGIF, 25, 1.0];
Print["  GIF: ", outGIF];
Print[""];

(* --- 4. Export sonification --- *)
Print["[4/4] Generating sonification..."];
outWAV = FileNameJoin[{$projectRoot, "data", "pendulum_audio.wav"}];
ExportSonification[solution, params, outWAV];
Print["  WAV: ", outWAV];
Print[""];

Print["=== Done ==="];

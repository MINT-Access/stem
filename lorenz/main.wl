#!/usr/bin/env wolframscript

(* ========================================================
   Lorenz Attractor — Entry Point
   Usage: wolframscript -file main.wl
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

(* Classic chaotic parameters *)
params = <|
  "Sigma"    -> 10.0,
  "Rho"      -> 28.0,
  "Beta"     -> 8/3,
  "InitX"    -> 1.0,
  "InitY"    -> 1.0,
  "InitZ"    -> 1.0,
  "TimeEnd"  -> 40.0,
  "TimeStep" -> 0.005
|>;

STEMHeading["Lorenz Attractor"];
Print["  sigma = ", params["Sigma"],
      "   rho = ", params["Rho"],
      "   beta = ", params["Beta"]];
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
ExportSonification[solution, outWAV, "Scale" -> "MinorPentatonic"];
STEMDescribeWAV[outWAV, params["TimeEnd"]];
Print[""];

STEMHeading["Done"];
STEMSay["Play audio:  afplay " <> outWAV];

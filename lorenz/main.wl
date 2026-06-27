#!/usr/bin/env wolframscript

(* ========================================================
   Lorenz Attractor — Entry Point
   Usage: wolframscript -file main.wl [-- [--key=value ...]]
          wolframscript -file main.wl -- --config-dump
          wolframscript -file main.wl -- --simulation.mode rossler
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
cfg  = LoadConfig["lorenz", $cliArgs];
mode = GetCfg[cfg, {"simulation","mode"}, "lorenz"];

Which[

  (* ===== Lorenz attractor (default) ===== *)
  mode === "lorenz",

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

    Print["[1/4] Solving Lorenz ODE..."];
    solution = SolveLorenz[params];
    Print["  Computed ", Length[solution], " steps."];
    PrintSummary[solution, params];
    Print[""];

    Print["[2/4] Exporting trajectory data..."];
    outCSV = FileNameJoin[{$projectRoot, "data", "lorenz_trajectory.csv"}];
    ExportResults[solution, params, outCSV];
    STEMDescribeCSV[outCSV, Length[solution], 5];
    Print[""];

    Print["[3/4] Rendering animation..."];
    outGIF = FileNameJoin[{$projectRoot, "data", "lorenz_animation.gif"}];
    ExportAnimation[solution, outGIF, 30, 150, "Lorenz Attractor"];
    STEMDescribeGIF[outGIF, 150, 30];
    Print[""];

    Print["[4/4] Synthesising audio..."];
    outWAV = FileNameJoin[{$projectRoot, "data", "lorenz_audio.wav"}];
    ExportSonification[solution, params, cfg, outWAV];
    STEMDescribeWAV[outWAV, solution[[-1, 1]]];
    Print[""],

  (* ===== Rossler attractor ===== *)
  mode === "rossler",

    ic     = GetCfg[cfg, {"simulation","initial_conditions"}, {0.1, 0.0, 0.0}];
    rBlock = GetCfg[cfg, {"simulation","rossler"}, <|"a"->0.2,"b"->0.2,"c"->5.7|>];
    params = <|
      "A"       -> rBlock["a"],
      "B"       -> rBlock["b"],
      "C"       -> rBlock["c"],
      "InitX"   -> N[ic[[1]]],
      "InitY"   -> N[ic[[2]]],
      "InitZ"   -> N[ic[[3]]],
      "TimeEnd" -> GetCfg[cfg, {"simulation","duration"},  40.0],
      "TimeStep"-> GetCfg[cfg, {"simulation","timestep"}, 0.005]
    |>;

    STEMHeading["Rossler Attractor"];
    Print["  a = ", params["A"],
          "   b = ", params["B"],
          "   c = ", params["C"]];
    Print["  Initial: (",
      params["InitX"], ", ",
      params["InitY"], ", ",
      params["InitZ"], ")"];
    Print["  Duration: ", params["TimeEnd"], " s"];
    Print[""];

    Print["[1/4] Solving Rossler ODE..."];
    solution = SolveRossler[params];
    Print["  Computed ", Length[solution], " steps."];
    PrintSummary[solution, params];
    Print[""];

    Print["[2/4] Exporting trajectory data..."];
    outCSV = FileNameJoin[{$projectRoot, "data", "rossler_trajectory.csv"}];
    ExportResults[solution, params, outCSV];
    STEMDescribeCSV[outCSV, Length[solution], 5];
    Print[""];

    Print["[3/4] Rendering animation..."];
    outGIF = FileNameJoin[{$projectRoot, "data", "rossler_animation.gif"}];
    ExportAnimation[solution, outGIF, 30, 150, "Rossler Attractor"];
    STEMDescribeGIF[outGIF, 150, 30];
    Print[""];

    Print["[4/4] Synthesising audio..."];
    outWAV = FileNameJoin[{$projectRoot, "data", "rossler_audio.wav"}];
    ExportSonification[solution, params, cfg, outWAV];
    STEMDescribeWAV[outWAV, solution[[-1, 1]]];
    Print[""],

  (* ===== Unknown mode ===== *)
  True,
    Print["Error: unknown simulation.mode \"", mode, "\" -- expected lorenz or rossler."];
    Exit[1]

];

STEMHeading["Done"];
STEMSay["Complete. Play audio: afplay " <> outWAV];

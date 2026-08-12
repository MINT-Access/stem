#!/usr/bin/env wolframscript

(* ========================================================
   Lorenz Attractor — Entry Point
   Usage: wolframscript -file main.wl [-- [--key=value ...]]
          wolframscript -file main.wl -- --config-dump
          wolframscript -file main.wl -- --simulation.mode rossler
          wolframscript -file main.wl -- --simulation.mode=rossler
          Note: --key value (space) also accepted in addition to --key=value.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

(* Pre-process CLI args: convert "--key value" pairs to "--key=value"
   so both conventions work (ParseCliOverrides in stem-core requires =). *)
$rawArgs = Select[Rest[$ScriptCommandLine], # =!= "--" &];
$cliArgs = Module[{result = {}, i = 1, arg, next},
  While[i <= Length[$rawArgs],
    arg = $rawArgs[[i]];
    If[StringStartsQ[arg, "--"] && !StringContainsQ[arg, "="] &&
       arg =!= "--config-dump" &&
       i < Length[$rawArgs] &&
       !StringStartsQ[$rawArgs[[i + 1]], "--"],
      next = $rawArgs[[i + 1]];
      AppendTo[result, arg <> "=" <> next];
      i += 2,
      AppendTo[result, arg];
      i++
    ]
  ];
  result
];

(* --- Load config (exits here if --config-dump is present) --- *)
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

    Print["[1/5] Solving Lorenz ODE..."];
    STEMSay["Solving Lorenz ODE"];
    solution = SolveLorenz[params];
    Print["  Computed ", Length[solution], " steps."];
    PrintSummary[solution, params];
    Print[""];

    Print["[2/5] Correctness checks..."];
    STEMSay["Running correctness checks"];
    $divChk   = LorenzDivergenceCheck[params["Sigma"], params["Rho"], N[params["Beta"]]];
    $eqChk    = LorenzEquilibriumCheck[params["Sigma"], params["Rho"], N[params["Beta"]]];
    $lyapChk  = LorenzLyapunovCheck[params["Sigma"], params["Rho"], N[params["Beta"]]];
    $boundChk = TrajectoryBoundedCheck[solution];
    PrintCorrectnessChecks[$divChk, $eqChk, $lyapChk, $boundChk];
    Print["    1. Constant phase-space divergence: ", FmtN[$divChk["expected"], 4],
          " everywhere (max deviation ", FmtN[$divChk["maxError"], 6], ")  (exact, tight tolerance)"];
    Print["    2. Equilibria satisfy f=0: origin + C+/C- = (",
          FmtN[$eqChk["cPlus"][[1]], 4], ",", FmtN[$eqChk["cPlus"][[2]], 4], ",",
          FmtN[$eqChk["cPlus"][[3]], 4], ") and its mirror (max residual ",
          FmtN[$eqChk["maxError"], 6], ")  (exact, tight tolerance)"];
    Print["    3. Largest Lyapunov exponent: ", FmtN[$lyapChk["lambda1"], 4],
          " vs benchmark ", FmtN[$lyapChk["benchmark"], 4],
          "  (empirical comparison, generous tolerance)"];
    Print["    4. Trajectory boundedness: no overflow/NaN, all coordinates finite  (sanity)"];
    Print[""];

    Print["[3/5] Exporting trajectory data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "lorenz_trajectory.csv"}];
    ExportResults[solution, params, outCSV];
    STEMDescribeCSV[outCSV, Length[solution], 5];
    Print[""];

    Print["[4/5] Rendering animation..."];
    STEMSay["Rendering animation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "lorenz_animation.gif"}];
    {$gifFrames, $gifFps} = ExportAnimation[solution, outGIF, solution[[-1, 1]], 150, "Lorenz Attractor"];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    Print[""];

    Print["[5/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "lorenz_audio.wav"}];
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

    Print["[1/5] Solving Rossler ODE..."];
    STEMSay["Solving Rossler ODE"];
    solution = SolveRossler[params];
    Print["  Computed ", Length[solution], " steps."];
    PrintSummary[solution, params];
    Print[""];

    Print["[2/5] Correctness checks..."];
    STEMSay["Running correctness checks"];
    $divChk   = RosslerDivergenceCheck[params["A"], params["B"], params["C"]];
    $eqChk    = RosslerEquilibriumCheck[params["A"], params["B"], params["C"]];
    $lyapChk  = RosslerLyapunovCheck[params["A"], params["B"], params["C"]];
    $boundChk = TrajectoryBoundedCheck[solution];
    PrintCorrectnessChecks[$divChk, $eqChk, $lyapChk, $boundChk];
    Print["    1. Divergence formula nabla.f = a+x-c (NOT constant, unlike Lorenz): ",
          "max deviation ", FmtN[$divChk["maxError"], 6], "  (exact, tight tolerance)"];
    Print["    2. Both equilibria satisfy f=0 (max residual ",
          FmtN[$eqChk["maxError"], 6], ")  (exact, tight tolerance)"];
    Print["    3. Largest Lyapunov exponent: ", FmtN[$lyapChk["lambda1"], 4],
          " vs benchmark ", FmtN[$lyapChk["benchmark"], 4],
          "  (empirical comparison, generous tolerance)"];
    Print["    4. Trajectory boundedness: no overflow/NaN, all coordinates finite  (sanity)"];
    Print[""];

    Print["[3/5] Exporting trajectory data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "rossler_trajectory.csv"}];
    ExportResults[solution, params, outCSV];
    STEMDescribeCSV[outCSV, Length[solution], 5];
    Print[""];

    Print["[4/5] Rendering animation..."];
    STEMSay["Rendering animation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "rossler_animation.gif"}];
    {$gifFrames, $gifFps} = ExportAnimation[solution, outGIF, solution[[-1, 1]], 150, "Rossler Attractor"];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    Print[""];

    Print["[5/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "rossler_audio.wav"}];
    ExportSonification[solution, params, cfg, outWAV];
    STEMDescribeWAV[outWAV, solution[[-1, 1]]];
    Print[""],

  (* ===== Unknown mode ===== *)
  True,
    Print["Error: unknown simulation.mode \"", mode, "\" — expected \"lorenz\" or \"rossler\"."];
    Exit[1]

];

STEMHeading["Done"];
STEMSay["Complete. Play audio: " <> STEMPlayCmd[outWAV]];

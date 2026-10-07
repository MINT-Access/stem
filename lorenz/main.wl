#!/usr/bin/env wolframscript

(* ========================================================
   Lorenz Attractor — Entry Point
   Usage: wolframscript -file main.wl [-- [--key=value ...]]
          wolframscript -file main.wl -- --config-dump
          wolframscript -file main.wl -- --simulation.mode rossler
          wolframscript -file main.wl -- --simulation.mode=rossler
          wolframscript -file main.wl -- --simulation.lorenz.preset=stable
          wolframscript -file main.wl -- --simulation.lorenz.transient_seconds=0
          Note: --key value (space) also accepted in addition to --key=value.
   ======================================================== *)

$CharacterEncoding = "UTF8";   (* text I/O; keep literals ASCII, see AGENTS.md *)
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

    (* A named preset (simulation.lorenz.preset, see $lorenzPresets) sets
       sigma, rho, beta, duration and start (1, 1, 1) and writes
       lorenz_*_<preset> files; without one the config values are used. *)
    preset    = GetCfg[cfg, {"simulation","lorenz","preset"}, ""];
    transient = N @ GetCfg[cfg, {"simulation","lorenz","transient_seconds"}, 5.0];
    If[preset =!= "" && !KeyExistsQ[$lorenzPresets, preset],
      Print["  Preset \"", preset, "\" is not a lorenz preset and is ignored; the presets are ",
            StringRiffle[Keys[$lorenzPresets], ", "], "."]; preset = ""];
    params = If[preset =!= "", LorenzPresetParams[preset],
      With[{ic = GetCfg[cfg, {"simulation","initial_conditions"}, {0.1, 0.0, 0.0}]},
        <|
          "Sigma"    -> GetCfg[cfg, {"simulation","lorenz","sigma"}, 10.0],
          "Rho"      -> GetCfg[cfg, {"simulation","lorenz","rho"},   28.0],
          "Beta"     -> GetCfg[cfg, {"simulation","lorenz","beta"},  8/3],
          "InitX"    -> N[ic[[1]]],
          "InitY"    -> N[ic[[2]]],
          "InitZ"    -> N[ic[[3]]],
          "TimeEnd"  -> GetCfg[cfg, {"simulation","duration"},       40.0],
          "TimeStep" -> GetCfg[cfg, {"simulation","timestep"},       0.005]
        |>]];
    suffix = If[preset =!= "", "_" <> preset, ""];

    STEMHeading["Lorenz Attractor"];
    Print["  sigma = ", params["Sigma"],
          "   rho = ", params["Rho"],
          "   beta = ", FmtN[N[params["Beta"]], 4],
          If[preset =!= "", "   (preset " <> preset <> ": " <> $lorenzPresets[preset]["desc"] <> ")", ""]];
    Print["  Initial: (",
      params["InitX"], ", ",
      params["InitY"], ", ",
      params["InitZ"], ")"];
    Print["  The first ", FmtDec[transient], " s of the trajectory are discarded as transient; the next ",
          FmtDec[params["TimeEnd"]], " s are sonified, animated and exported."];
    Print[""];

    Print["[1/5] Solving Lorenz ODE..."];
    STEMSay["Solving Lorenz ODE"];
    solveParams = Append[params, "TimeEnd" -> transient + params["TimeEnd"]];
    If[preset =!= "" && TrueQ[$lorenzPresets[preset]["Dual"]],
      {solution, solution2} = DiscardTransient[#, transient] & /@ SolveLorenzPair[solveParams, 0.001],
      solution = DiscardTransient[SolveLorenz[solveParams], transient]];
    Print["  Computed ", Length[solution], " steps after the transient."];
    PrintSummary[solution, params];
    Print[""];

    Print["[2/5] Correctness checks..."];
    STEMSay["Running correctness checks"];
    (* Checks 1-3 use the run's sigma/rho/beta, except for a preset, where
       they use the canonical (10, 28, 8/3): check 3's benchmark is the
       rho = 28 exponent, and the stable preset (rho = 20) has none. *)
    chkP = If[preset =!= "", <|"Sigma" -> 10.0, "Rho" -> 28.0, "Beta" -> 8/3|>, params];
    If[preset =!= "", Print["  Checks 1 to 3 run at the canonical sigma = 10, rho = 28, beta = 8/3, ",
                            "not at the preset's parameters; check 4 uses this run's trajectory."]];
    $divChk   = LorenzDivergenceCheck[chkP["Sigma"], chkP["Rho"], N[chkP["Beta"]]];
    $eqChk    = LorenzEquilibriumCheck[chkP["Sigma"], chkP["Rho"], N[chkP["Beta"]]];
    $lyapChk  = LorenzLyapunovCheck[chkP["Sigma"], chkP["Rho"], N[chkP["Beta"]]];
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
    outCSV = FileNameJoin[{$projectRoot, "output", "lorenz_trajectory" <> suffix <> ".csv"}];
    ExportResults[solution, params, outCSV];
    STEMDescribeCSV[outCSV, Length[solution], 5];
    Print[""];

    Print["[4/5] Rendering animation..."];
    STEMSay["Rendering animation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "lorenz_animation" <> suffix <> ".gif"}];
    {$gifFrames, $gifFps} = If[preset =!= "" && TrueQ[$lorenzPresets[preset]["Dual"]],
      ExportDualAnimation[solution, solution2, outGIF, solution[[-1, 1]], 150],
      ExportAnimation[solution, outGIF, solution[[-1, 1]], 150,
        If[preset =!= "", "Lorenz rho=" <> FmtN[params["Rho"], 4], "Lorenz Attractor"]]];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    Print[""];

    Print["[5/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "lorenz_audio" <> suffix <> ".wav"}];
    $StemLastLimiter = None;
    ExportSonification[solution, params, cfg, outWAV];
    STEMDescribeWAV[outWAV, solution[[-1, 1]]];
    (* audio.limiter in config.json enables stem-core's look-ahead peak
       limiter for lorenz mode (not rossler): fast passages at the top of
       the pitch range otherwise hit the peak ceiling and hold the WAV
       below -17 LUFS. *)
    If[AssociationQ[$StemLastLimiter],
      Print["  The look-ahead peak limiter was applied to ", FileNameTake[outWAV], " with a ceiling of ",
            FmtDec[$StemLastLimiter["ceilingDB"], 1], " dBFS (", FmtDec[$StemLastLimiter["attackMs"]], " ms attack, ",
            FmtDec[$StemLastLimiter["releaseMs"]], " ms release), and its maximum gain reduction was ",
            FmtDec[$StemLastLimiter["maxReductionDB"], 2], " dB, bringing the WAV to ",
            FmtDec[$StemLastLimiter["lufs"], 2], " LUFS."],
      Print["  The peak limiter is off for this run (audio.limiter)."]];
    SyncWAVToGIF[outGIF, outWAV];
    STEMLoudnessLine[outWAV, -17.0];
    STEMTimingLine[<|"notes" -> WAVDuration[outWAV]|>];
    Print[""],

  (* ===== Rossler attractor ===== *)
  mode === "rossler",

    ic        = GetCfg[cfg, {"simulation","initial_conditions"}, {0.1, 0.0, 0.0}];
    rBlock    = GetCfg[cfg, {"simulation","rossler"}, <|"a"->0.2,"b"->0.2,"c"->5.7|>];
    transient = N @ GetCfg[cfg, {"simulation","rossler","transient_seconds"}, 50.0];
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
    Print["  The first ", FmtDec[transient], " s of the trajectory are discarded as transient; the next ",
          FmtDec[params["TimeEnd"]], " s are sonified, animated and exported."];
    Print[""];

    Print["[1/5] Solving Rossler ODE..."];
    STEMSay["Solving Rossler ODE"];
    solution = DiscardTransient[SolveRossler[Append[params, "TimeEnd" -> transient + params["TimeEnd"]]], transient];
    Print["  Computed ", Length[solution], " steps after the transient."];
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
    SyncWAVToGIF[outGIF, outWAV];
    STEMLoudnessLine[outWAV, -17.0];
    STEMTimingLine[<|"notes" -> WAVDuration[outWAV]|>];
    Print[""],

  (* ===== Unknown mode ===== *)
  True,
    Print["Error: unknown simulation.mode \"", mode, "\" \[LongDash] expected \"lorenz\" or \"rossler\"."];
    Exit[1]

];

STEMHeading["Done"];
STEMSay["Complete. Play audio: " <> STEMPlayCmd[outWAV]];

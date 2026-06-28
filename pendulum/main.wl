#!/usr/bin/env wolframscript

(* ========================================================
   Pendulum Simulation — Unified Entry Point
   Usage:
     wolframscript -file run.wl                                   # double pendulum (config default)
     wolframscript -file run.wl -- --simulation.mode=simple
     wolframscript -file run.wl -- --simulation.mode simple       # space form also accepted
     wolframscript -file run.wl -- --config-dump
     wolframscript -file run.wl -- --simulation.double.angle1_deg=150
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
cfg  = LoadConfig["pendulum", $cliArgs];
mode = GetCfg[cfg, {"simulation","mode"}, "simple"];

STEMHeading["Pendulum Simulation: " <> mode];
Print[""];

Which[

  (* ══════════════════════════════════════════════════════
     SIMPLE PENDULUM
     ══════════════════════════════════════════════════════ *)
  mode === "simple",

    params = <|
      "Length"       -> GetCfg[cfg, {"simulation","simple","length"},     1.0],
      "Gravity"      -> GetCfg[cfg, {"simulation","gravity"},             9.81],
      "InitAngle"    -> GetCfg[cfg, {"simulation","simple","angle_deg"}, 45.0] * Pi / 180.0,
      "InitVelocity" -> 0.0,
      "TimeEnd"      -> GetCfg[cfg, {"simulation","duration"},           20.0],
      "TimeStep"     -> GetCfg[cfg, {"simulation","timestep"},           0.01]
    |>;

    Print["  Length:        ", FmtN[params["Length"], 3], " m"];
    Print["  Initial angle: ",
      FmtN[params["InitAngle"] * 180.0 / Pi, 3], " deg"];
    Print["  Duration:      ", params["TimeEnd"], " s"];
    Print["  Period (small-angle approx): ",
      FmtN[2 Pi Sqrt[params["Length"] / params["Gravity"]], 4], " s"];
    Print[""];

    Print["[1/4] Solving ODE..."];
    STEMSay["Solving pendulum ODE"];
    solution = SolvePendulum[params];
    Print["  Computed ", Length[solution], " time steps."];
    Print[""];

    Print["[2/4] Exporting CSV..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "simple_results.csv"}];
    ExportResults[solution, params, outCSV];
    STEMDescribeCSV[outCSV, Length[solution], 5];
    PrintSummary[solution, params];
    Print[""];

    Print["[3/4] Generating animation..."];
    STEMSay["Generating animation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "simple_animation.gif"}];
    nFrames = ExportAnimation[solution, params, outGIF, 25, 1.0];
    STEMDescribeGIF[outGIF, nFrames, 25];
    Print[""];

    Print["[4/4] Generating sonification..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "simple_audio.wav"}];
    ExportSonification[solution, params, cfg, outWAV];
    STEMDescribeWAV[outWAV, solution[[-1, 1]]];
    Print[""],


  (* ══════════════════════════════════════════════════════
     DOUBLE PENDULUM
     ══════════════════════════════════════════════════════ *)
  mode === "double",

    With[
      {L1    = GetCfg[cfg, {"simulation","double","length1"},    1.0],
       L2    = GetCfg[cfg, {"simulation","double","length2"},    1.0],
       m1    = GetCfg[cfg, {"simulation","double","mass1"},      1.0],
       m2    = GetCfg[cfg, {"simulation","double","mass2"},      1.0],
       a1    = GetCfg[cfg, {"simulation","double","angle1_deg"}, 120.0],
       a2    = GetCfg[cfg, {"simulation","double","angle2_deg"},  90.0],
       tEnd  = GetCfg[cfg, {"simulation","duration"},            20.0]},

      Print["  L1=", L1, " m, L2=", L2, " m"];
      Print["  m1=", m1, " kg, m2=", m2, " kg"];
      Print["  angle1_0=", a1, " deg  angle2_0=", a2, " deg"];
      Print["  Duration=", tEnd, " s  (chaotic above ~60 deg)"];
      Print[""]
    ];

    Print["[1/4] Solving double pendulum ODE..."];
    STEMSay["Solving double pendulum ODE"];
    solution = DoublePendulumModel[cfg];
    Print["  Computed ", Length[solution], " time steps."];
    With[
      {th1 = solution[[All, 2]] * 180.0 / Pi,
       th2 = solution[[All, 4]] * 180.0 / Pi},
      Print["  theta1 range: [", FmtN[Min[th1], 4], ", ", FmtN[Max[th1], 4], "] deg"];
      Print["  theta2 range: [", FmtN[Min[th2], 4], ", ", FmtN[Max[th2], 4], "] deg"]
    ];
    Print[""];

    Print["[2/4] Exporting CSV..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "double_results.csv"}];
    ExportDoublePendulumResults[solution, outCSV];
    STEMDescribeCSV[outCSV, Length[solution], 5];
    Print[""];

    Print["[3/4] Generating animation..."];
    STEMSay["Generating animation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "double_animation.gif"}];
    nFrames = AnimateDoublePendulum[solution, cfg, outGIF];
    STEMDescribeGIF[outGIF, nFrames, 25];
    Print[""];

    Print["[4/4] Generating sonification..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "double_audio.wav"}];
    SonifyDoublePendulum[solution, cfg, outWAV];
    STEMDescribeWAV[outWAV, solution[[-1, 1]]];
    Print[""],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"simple\" or \"double\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Complete. Play audio: afplay " <> outWAV];

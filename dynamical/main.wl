#!/usr/bin/env wolframscript

(* ========================================================
   Dynamical Systems — Entry Point

   Sonifies the logistic map x_{n+1} = r x_n (1 - x_n) and its
   period-doubling route to chaos. First mode of a dynamical/
   app that may receive additional modes (Henon map, circle
   map, etc.) in future sessions.

   Usage:
     wolframscript -file main.wl [-- [--key=value ...]]
     wolframscript -file main.wl -- --config-dump
     wolframscript -file main.wl -- --simulation.mode=iterate
     wolframscript -file main.wl -- --simulation.dynamical.preset=fixed_point
     wolframscript -file main.wl -- --simulation.dynamical.preset=period2
     wolframscript -file main.wl -- --simulation.dynamical.preset=period4
     wolframscript -file main.wl -- --simulation.dynamical.preset=period3_window
     wolframscript -file main.wl -- --simulation.dynamical.preset=chaos
     wolframscript -file main.wl -- --simulation.dynamical.r=3.83
     wolframscript -file main.wl -- --simulation.dynamical.r_steps=1000
     wolframscript -file main.wl -- --simulation.dynamical.note_duration=0.04

   New to this app? Start with dynamical/LISTENING_GUIDE.md.

   Modes:
     sweep   (default) -- sweeps r from r_start to r_end, sonifying the
                           long-term attractor at each step; three named
                           accent tones mark the first period-doubling,
                           the onset of chaos, and the period-3 window
     iterate            -- fixes r (or a named preset) and sonifies the
                           map's actual time evolution over n_iterations

   Outputs (dynamical/output/):
     sweep_audio.wav / sweep.gif / sweep_data.csv
     iterate_audio.wav / iterate.gif / iterate_data.csv
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "speech.wl"}]];

(* Pre-process CLI args: convert "--key value" pairs to "--key=value". *)
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
      i += 1
    ]
  ];
  result
];

cfg  = LoadConfig["dynamical", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "sweep"];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

rStart      = N @ GetCfg[cfg, {"simulation", "dynamical", "r_start"},      2.5];
rEnd        = N @ GetCfg[cfg, {"simulation", "dynamical", "r_end"},        4.0];
rSteps      =     GetCfg[cfg, {"simulation", "dynamical", "r_steps"},      500];
rCfg        = N @ GetCfg[cfg, {"simulation", "dynamical", "r"},            3.8];
preset      =     GetCfg[cfg, {"simulation", "dynamical", "preset"},       ""];
nTransient  =     GetCfg[cfg, {"simulation", "dynamical", "n_transient"},  200];
nAttractor  =     GetCfg[cfg, {"simulation", "dynamical", "n_attractor"},  100];
nIterations =     GetCfg[cfg, {"simulation", "dynamical", "n_iterations"}, 300];
noteDuration = N @ GetCfg[cfg, {"simulation", "dynamical", "note_duration"}, 0.08];
x0          = N @ GetCfg[cfg, {"simulation", "dynamical", "x0"},           0.5];
sr          =     GetCfg[cfg, {"sonification", "sample_rate"},            44100];

STEMHeading["Dynamical Systems: Logistic Map"];
Print["  Mode: ", mode];
Print[""];

Print["[1/5] Correctness checks..."];
STEMSay["Running correctness checks"];
$feigenbaum = FeigenbaumCheck[];
$fixedPt    = FixedPointCheck[];
$period2Chk = Period2Check[];
$lyapunov   = LyapunovCheck[];
PrintCorrectnessChecks[$feigenbaum, $fixedPt, $period2Chk, $lyapunov];
Print["    1. Feigenbaum ratio: ", FmtN[$feigenbaum["ratio"], 5],
      "  (delta = ", FmtN[$FeigenbaumConstant, 6], ", ",
      FmtN[$feigenbaum["relError"] * 100, 4], "% error)"];
Print["    2. Fixed point (r=2.8): analytic ", FmtN[$fixedPt["analytic"], 6],
      "  numeric ", FmtN[$fixedPt["numeric"], 6]];
Print["    3. Period-2 (r=3.2): ", $period2Chk["nDistinct"], " distinct values, sum ",
      FmtN[N[$period2Chk["sum"]], 6], " (expected ", FmtN[$period2Chk["expected"], 6], ")"];
Print["    4. Lyapunov (r=4.0): ", FmtN[$lyapunov["lambda"], 6],
      "  (log 2 = ", FmtN[$lyapunov["expected"], 6], ", ",
      FmtN[$lyapunov["relError"] * 100, 4], "% error)"];
Print[""];

Which[

  (* ===== Sweep mode (default) ===== *)
  mode === "sweep",

    outWAV = FileNameJoin[{$outDir, "sweep_audio.wav"}];
    outGIF = FileNameJoin[{$outDir, "sweep.gif"}];
    outCSV = FileNameJoin[{$outDir, "sweep_data.csv"}];

    Print["  r: ", FmtN[rStart, 4], " -> ", FmtN[rEnd, 4],
          "  (", rSteps, " steps, ", nTransient, " transient + ",
          nAttractor, " attractor iterations per step)"];
    Print["  Note duration: ", FmtN[noteDuration * 1000, 4], " ms"];
    Print[""];

    Print["[2/5] Sweeping r and recording attractors..."];
    STEMSay["Sweeping r from " <> ToString[NumberForm[rStart,{3,2}]] <>
            " to " <> ToString[NumberForm[rEnd,{3,2}]]];
    sweepModel = SweepModel[rStart, rEnd, rSteps, x0, nTransient, nAttractor];
    Print["  Recorded ", rSteps, " r-values."];
    Print[""];

    Print["[3/5] Sonifying sweep..."];
    STEMSay["Sonifying the sweep. Listen for the rhythm doubling into chaos."];
    sweepResult = SonifySweep[sweepModel, noteDuration, sr];
    Print[""];

    introText   = BuildSweepIntroText[rStart, rEnd];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];

    finalLeft  = Join[introBuffer, pauseBuffer, sweepResult["leftBuf"]];
    finalRight = Join[introBuffer, pauseBuffer, sweepResult["rightBuf"]];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    totalDurSec = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWAV, totalDurSec];
    PrintSweepSummary[sweepModel, sweepResult["eventRs"]];
    Print[""];

    Print["[4/5] Rendering bifurcation diagram animation..."];
    STEMSay["Rendering the bifurcation diagram"];
    AnimateSweepBifurcation[sweepModel, sweepResult["eventRs"], outGIF];
    STEMDescribeGIF[outGIF, 60, 12];
    Print[""];

    Print["[5/5] Exporting data table..."];
    ExportSweepCSV[sweepResult, sweepModel["rValues"], outCSV];
    Print[""];

    STEMHeading["Done"];
    STEMSay[
      "Sweep complete. r ranged from " <> ToString[NumberForm[rStart,{3,2}]] <>
      " to " <> ToString[NumberForm[rEnd,{3,2}]] <> ". " <>
      "Total duration: " <> ToString[NumberForm[totalDurSec, {5,1}]] <> " seconds. " <>
      "Play audio: " <> STEMPlayCmd[outWAV]
    ],

  (* ===== Iterate mode ===== *)
  mode === "iterate",

    outWAV = FileNameJoin[{$outDir, "iterate_audio.wav"}];
    outGIF = FileNameJoin[{$outDir, "iterate.gif"}];
    outCSV = FileNameJoin[{$outDir, "iterate_data.csv"}];

    rActual = PresetR[preset, rCfg];
    presetDesc = PresetDescription[preset];

    Print["  r: ", FmtN[rActual, 6],
      If[preset =!= "", "  (preset: " <> preset <> ")", ""]];
    Print["  Iterations: ", nIterations, "   x0: ", FmtN[x0, 4]];
    Print["  Note duration: ", FmtN[noteDuration * 1000, 4], " ms"];
    Print[""];

    Print["[2/5] Iterating the map..."];
    STEMSay["Iterating the logistic map at r equals " <> ToString[NumberForm[rActual,{5,4}]]];
    iterateModel = IterateModelData[rActual, x0, nIterations, preset];
    Print[""];

    Print["[3/5] Sonifying iteration..."];
    STEMSay["Sonifying the iteration"];
    iterateResult = SonifyIterate[iterateModel, noteDuration, sr];
    Print[""];

    introText   = BuildIterateIntroText[rActual, presetDesc, nIterations, x0];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];

    finalLeft  = Join[introBuffer, pauseBuffer, iterateResult["leftBuf"]];
    finalRight = Join[introBuffer, pauseBuffer, iterateResult["rightBuf"]];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    totalDurSec = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWAV, totalDurSec];
    PrintIterateSummary[iterateModel];
    Print[""];

    Print["[4/5] Rendering time-series animation..."];
    STEMSay["Rendering the time series"];
    AnimateIterateTimeSeries[iterateModel, outGIF];
    STEMDescribeGIF[outGIF, 60, 12];
    Print[""];

    Print["[5/5] Exporting data table..."];
    ExportIterateCSV[iterateResult, outCSV];
    Print[""];

    STEMHeading["Done"];
    STEMSay[
      "Iteration complete. r equals " <> ToString[NumberForm[rActual,{5,4}]] <>
      If[presetDesc =!= "", ". " <> presetDesc <> ".", "."] <>
      " Play audio: " <> STEMPlayCmd[outWAV]
    ],

  (* ===== Unknown mode ===== *)
  True,
    Print["Error: unknown simulation.mode \"", mode, "\" -- expected \"sweep\" or \"iterate\"."];
    Exit[1]
];

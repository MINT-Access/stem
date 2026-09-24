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
     wolframscript -file main.wl -- --simulation.mode=lyapunov
     wolframscript -file main.wl -- --simulation.mode=lyapunov --simulation.dynamical.preset=lyapunov_window

   New to this app? Start with dynamical/LISTENING_GUIDE.md.

   Modes:
     sweep   (default) -- sweeps r from r_start to r_end, sonifying the
                           long-term attractor at each step; three named
                           accent tones mark the first period-doubling,
                           the onset of chaos, and the period-3 window
     iterate            -- fixes r (or a named preset) and sonifies the
                           map's actual time evolution over n_iterations
     lyapunov           -- sweeps r and sonifies the Lyapunov exponent
                           lambda(r) as a gliding tone against a steady
                           reference tone at lambda = 0, with marker
                           tones at the bifurcation points

   Outputs (dynamical/output/):
     sweep_audio.wav / sweep.gif / sweep_data.csv
     iterate_audio.wav / iterate.gif / iterate_data.csv
     lyapunov_audio.wav / lyapunov.gif / lyapunov_data.csv
       (with a preset: <preset>_audio.wav / <preset>.gif / <preset>_data.csv)
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
$lyapCurve  = LyapunovCurveCheck[];
PrintCorrectnessChecks[$feigenbaum, $fixedPt, $period2Chk, $lyapunov, $lyapCurve];
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
PrintLyapunovCurveCheck[$lyapCurve];
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
    Export[outWAV, Sound[SampledSoundList[NormalizeToLoudness[{finalLeft, finalRight}, -17.0, 0.97, sr], sr]], "WAV"];
    totalDurSec = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWAV, totalDurSec];
    PrintSweepSummary[sweepModel, sweepResult["eventRs"]];
    Print[""];

    Print["[4/5] Rendering bifurcation diagram animation..."];
    STEMSay["Rendering the bifurcation diagram"];
    {$gifFrames, $gifFps} = AnimateSweepBifurcation[sweepModel, sweepResult["eventRs"], outGIF, totalDurSec];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    SyncWAVToGIF[outGIF, outWAV];
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
    Export[outWAV, Sound[SampledSoundList[NormalizeToLoudness[{finalLeft, finalRight}, -17.0, 0.97, sr], sr]], "WAV"];
    totalDurSec = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWAV, totalDurSec];
    PrintIterateSummary[iterateModel];
    Print[""];

    Print["[4/5] Rendering time-series animation..."];
    STEMSay["Rendering the time series"];
    {$gifFrames, $gifFps} = AnimateIterateTimeSeries[iterateModel, outGIF, totalDurSec];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    SyncWAVToGIF[outGIF, outWAV];
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

  (* ===== Lyapunov mode ===== *)
  mode === "lyapunov",

    lyCfg[key_, default_] := GetCfg[cfg, {"simulation", "dynamical", "lyapunov", key}, default];
    lyRMin     = N @ lyCfg["r_min", 2.5];
    lyRMax     = N @ lyCfg["r_max", 4.0];
    lySteps    =     lyCfg["steps", 750];
    lyDur      = N @ lyCfg["duration_seconds", 120];
    lyRefHz    = N @ lyCfg["reference_hz", 220];
    lyOctaves  = N @ lyCfg["octaves_per_unit", 1.0];
    lyFloor    = N @ lyCfg["floor", -0.5];
    lyTrans    =     lyCfg["transient", 1000];
    lyAverage  =     lyCfg["average_iterations", 10000];

    lyName = "lyapunov";
    Which[
      KeyExistsQ[$lyapunovPresets, preset],
        lyRMin  = N @ $lyapunovPresets[preset]["r_min"];
        lyRMax  = N @ $lyapunovPresets[preset]["r_max"];
        lySteps =     $lyapunovPresets[preset]["steps"];
        lyDur   = N @ $lyapunovPresets[preset]["duration_seconds"];
        lyName  = preset,
      preset =!= "",
        Print["  Preset \"", preset, "\" is not a lyapunov-mode preset and is ignored; ",
              "lyapunov-mode presets: ", StringRiffle[Keys[$lyapunovPresets], ", "], "."]
    ];

    outWAV = FileNameJoin[{$outDir, lyName <> "_audio.wav"}];
    outGIF = FileNameJoin[{$outDir, lyName <> ".gif"}];
    outCSV = FileNameJoin[{$outDir, lyName <> "_data.csv"}];

    Print["  r: ", FmtN[lyRMin, 4], " -> ", FmtN[lyRMax, 4], "  (", lySteps, " steps over ",
          FmtDec[lyDur], " s", If[lyName =!= "lyapunov", ", preset: " <> lyName, ""], ")"];
    Print["  Each step: ", lyTrans, " transient iterations discarded, then the mean of ",
          "Log|r (1 - 2x)| over ", lyAverage, " iterations, floored at ", FmtDec[lyFloor], "."];
    Print["  Reference tone ", FmtDec[lyRefHz], " Hz; the lambda tone moves ",
          FmtDec[lyOctaves], " octave per unit of lambda."];
    Print[""];

    Print["[2/5] Computing the Lyapunov exponent at each r..."];
    STEMSay["Computing the Lyapunov exponent at each r"];
    lySweep     = LyapunovSweep[lyRMin, lyRMax, lySteps, x0, lyTrans, lyAverage, lyFloor];
    lyBif       = AttractorPoints[x0, #, lyTrans, nAttractor] & /@ lySweep[[All, 1]];
    lyCrossings = LyapunovZeroCrossings[lySweep];
    Print["  Computed lambda at ", lySteps, " r values."];
    Print[""];

    Print["[3/5] Sonifying the Lyapunov exponent..."];
    STEMSay["Sonifying the Lyapunov exponent"];
    lyResult = SonifyLyapunov[lySweep, lyDur, lyRefHz, lyOctaves, sr];
    Print["  The lambda tone runs from ", FmtDec[lyResult["toneHzRange"][[1]], 1], " to ",
          FmtDec[lyResult["toneHzRange"][[2]], 1], " Hz; A-weighting equal-loudness gain from ",
          FmtDec[lyResult["gainRangeDB"][[1]], 2], " to ", FmtDec[lyResult["gainRangeDB"][[2]], 2],
          " dB relative to the reference frequency."];
    Scan[Print["  Marker: ", #["label"], " at r = ", FmtDec[#["r"], 4], ", ",
               FmtDec[#["freq"]], " Hz, ", FmtDec[#["time"], 2], " s into the sweep."] &,
         lyResult["markers"]];

    lyFirstUp = SelectFirst[lyCrossings, #["direction"] === "upward" &, Missing[]];
    lyFirstUp = If[AssociationQ[lyFirstUp], lyFirstUp["r"], Missing[]];
    introText = BuildLyapunovIntroText[lyRMin, lyRMax];
    outroText = BuildLyapunovOutroText[lyRMin, lyRMax, lyFirstUp];
    Print["  Spoken intro: ", introText];
    Print["  Spoken outro: ", outroText];
    introBuffer = BuildIntroBuffer[introText, sr];
    outroBuffer = BuildIntroBuffer[outroText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    outroBuffer = If[Length[outroBuffer] > 0, NormalizeBuffer[outroBuffer, 0.95], outroBuffer];
    pauseBuffer = ConstantArray[0.0, Round[sr * 0.4]];
    introPart = If[Length[introBuffer] > 0, Join[introBuffer, pauseBuffer], {}];
    outroPart = If[Length[outroBuffer] > 0, Join[pauseBuffer, outroBuffer], {}];
    lyIntroSec = N[Length[introPart]] / sr;
    Print[""];

    finalLeft  = Join[introPart, lyResult["leftBuf"],  outroPart];
    finalRight = Join[introPart, lyResult["rightBuf"], outroPart];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[NormalizeToLoudness[{finalLeft, finalRight}, -17.0, 0.97, sr], sr]], "WAV"];
    totalDurSec = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWAV, totalDurSec];
    PrintLyapunovSummary[lySweep, lyCrossings, lyFloor, lyDur, lyIntroSec];
    Print[""];

    Print["[4/5] Rendering bifurcation diagram and Lyapunov exponent animation..."];
    STEMSay["Rendering the bifurcation diagram and the Lyapunov exponent"];
    {$gifFrames, $gifFps} = AnimateLyapunov[lySweep, lyBif, lyResult["markers"], lyFloor,
      <|"intro" -> lyIntroSec, "sweep" -> lyDur, "total" -> totalDurSec|>, outGIF];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    SyncWAVToGIF[outGIF, outWAV];
    PrintLoudnessLine[outWAV, -17.0];
    Print[""];

    Print["[5/5] Exporting data table..."];
    ExportLyapunovCSV[lySweep, lyFloor, lyDur, lyIntroSec, lyRefHz, lyOctaves, outCSV];
    Print[""];

    STEMHeading["Done"];
    STEMSay[
      "Lyapunov sweep complete. r ranged from " <> ToString[NumberForm[lyRMin,{3,2}]] <>
      " to " <> ToString[NumberForm[lyRMax,{3,2}]] <> ". " <>
      "Total duration: " <> ToString[NumberForm[totalDurSec, {5,1}]] <> " seconds. " <>
      "Play audio: " <> STEMPlayCmd[outWAV]
    ],

  (* ===== Unknown mode ===== *)
  True,
    Print["Error: unknown simulation.mode \"", mode, "\" -- expected \"sweep\", \"iterate\" or \"lyapunov\"."];
    Exit[1]
];

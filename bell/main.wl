#!/usr/bin/env wolframscript

(* ========================================================
   Bell — Entry Point
   Usage: wolframscript -file main.wl [-- [--key=value ...]]
          wolframscript -file main.wl -- --config-dump
          wolframscript -file main.wl -- --simulation.mode=chsh
          wolframscript -file main.wl -- --simulation.mode measurement
          Note: --key value (space) also accepted in addition to --key=value.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "speech.wl"}]];

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

cfg  = LoadConfig["bell", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "correlations"];
sr   = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];

STEMHeading["Bell"];
Print["  mode: ", mode];
Print[""];

(* ── Correctness checks — always at fixed canonical parameters
   (the derived-optimal CHSH angles), independent of the active mode's
   own configured parameters, the same convention every prior v1.5.0
   app's checks section uses. ── *)
Print["[1/5] Correctness checks..."];
STEMSay["Running correctness checks"];
$normChk = BellStateNormalizationCheck[];
$corrChk = QuantumCorrelationIndependentCheck[];
$chshChk = ChshOptimalityCheck[];
$lhvChk  = LocalHiddenVariableBoundCheck[];
PrintCorrectnessChecks[$normChk, $corrChk, $chshChk, $lhvChk];
Print["    1. Bell state normalization: |Phi+|^2 = ", FmtN[$normChk["normSq"], 12],
      "  (exact, tight tolerance)"];
Print["    2. Quantum correlation vs independent rotation/Born-rule computation: max error = ",
      FmtN[$corrChk["maxError"], 3], "  (exact relation, tight tolerance)"];
Print["    3. CHSH optimality: S at derived-optimal angles = ", FmtN[$chshChk["sOptimal"], 8],
      " vs Tsirelson bound 2*Sqrt[2] = ", FmtN[$chshChk["tsirelsonBound"], 8],
      "  (naive angle choice gives S = ", FmtN[$chshChk["sNaive"], 4], ")"];
Print["    4. Local hidden-variable bound: max |S| over all 16 deterministic strategies = ",
      FmtN[$lhvChk["maxAbsSExact"], 4], "; max |S| over ", $lhvChk["nTrials"],
      " random convex-mixture models = ", FmtN[$lhvChk["maxAbsSMonteCarlo"], 6],
      "  (both <= 2, the local-realist ceiling)"];
Print[""];

Which[

  (* ===== correlations (default) ===== *)
  mode === "correlations",

    duration = N @ GetCfg[cfg, {"sonification", "duration"}, 8.0];

    Print["[2/5] Computing correlation sweep..."];
    STEMSay["Computing Bell correlations"];
    corrModel = CorrelationsModel[cfg];
    PrintCorrelationsSummary[corrModel];
    Print[""];

    Print["[3/5] Exporting data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "bell_correlations.csv"}];
    ExportCorrelationsCSV[corrModel, outCSV];
    Print[""];

    Print["[4/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "bell_correlations.gif"}];
    outPNG = FileNameJoin[{$projectRoot, "output", "bell_correlations.png"}];
    AnimateCorrelations[corrModel, outGIF, outPNG];
    STEMDescribeGIF[outGIF, 40, 12];
    Print[""];

    Print["[5/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "bell_correlations.wav"}];
    {rawLeft, rawRight} = BuildCorrelationsAudio[corrModel, 220.0, 1400.0, duration, sr];
    introText   = BuildCorrelationsIntroText[];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuffer, rawLeft];
    finalRight = Join[introBuffer, pauseBuffer, rawRight];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""],

  (* ===== chsh ===== *)
  mode === "chsh",

    Print["[2/5] Computing CHSH value..."];
    STEMSay["Computing the C H S H value"];
    chshModel = ChshModel[cfg];
    PrintChshSummary[chshModel];
    Print[""];

    Print["[3/5] Exporting data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "bell_chsh.csv"}];
    ExportChshCSV[chshModel, outCSV];
    Print[""];

    Print["[4/5] Rendering visualisation..."];
    STEMSay["Rendering the gauge"];
    outGIF = FileNameJoin[{$projectRoot, "output", "bell_chsh.gif"}];
    outPNG = FileNameJoin[{$projectRoot, "output", "bell_chsh.png"}];
    AnimateChsh[chshModel, outGIF, outPNG];
    STEMDescribeGIF[outGIF, 7, 2];
    Print[""];

    Print["[5/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "bell_chsh.wav"}];
    {rawLeft, rawRight} = BuildChshAudio[chshModel, 220.0, 1400.0, 2.5, sr];
    introText   = BuildChshIntroText[chshModel["S"]];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuffer, rawLeft];
    finalRight = Join[introBuffer, pauseBuffer, rawRight];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""],

  (* ===== measurement ===== *)
  mode === "measurement",

    duration = N @ GetCfg[cfg, {"sonification", "duration"}, 8.0];

    Print["[2/5] Running paired measurements..."];
    STEMSay["Running paired measurements"];
    measModel = MeasurementModel[cfg];
    PrintMeasurementSummary[measModel];
    Print[""];

    Print["[3/5] Exporting data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "bell_measurement.csv"}];
    ExportMeasurementCSV[measModel, outCSV];
    Print[""];

    Print["[4/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    outPNG = FileNameJoin[{$projectRoot, "output", "bell_measurement.png"}];
    ExportMeasurementPNG[measModel, outPNG];
    Print[""];

    Print["[5/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "bell_measurement.wav"}];
    {rawLeft, rawRight} = BuildMeasurementAudio[measModel, 220.0, 1400.0, duration, sr];
    introText   = BuildMeasurementIntroText[measModel["nTrials"], measModel["trueE"]];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuffer, rawLeft];
    finalRight = Join[introBuffer, pauseBuffer, rawRight];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""],

  (* ===== unknown mode ===== *)
  True,
    Print["Error: unknown simulation.mode \"", mode, "\" — expected \"correlations\", \"chsh\", or \"measurement\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Complete. Play audio: " <> STEMPlayCmd[outWAV]];

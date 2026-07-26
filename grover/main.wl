#!/usr/bin/env wolframscript

(* ========================================================
   Grover — Entry Point
   Usage: wolframscript -file main.wl [-- [--key=value ...]]
          wolframscript -file main.wl -- --config-dump
          wolframscript -file main.wl -- --simulation.mode=compare
          wolframscript -file main.wl -- --simulation.mode geometry
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

cfg  = LoadConfig["grover", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "search"];
sr   = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];

STEMHeading["Grover"];
Print["  mode: ", mode];
Print[""];

(* ── Correctness checks — always at fixed canonical parameters,
   independent of the active mode's own configured parameters, the
   same convention every prior v1.5.0 app's checks section
   uses. ── *)
Print["[1/5] Correctness checks..."];
STEMSay["Running correctness checks"];
$rotChk        = RotationAngleCheck[];
$optKChk       = OptimalIterationCountCheck[];
$unitaryChk    = OperatorUnitarityCheck[];
$closedFormChk = ClosedFormVsSimulationCheck[];
PrintCorrectnessChecks[$rotChk, $optKChk, $unitaryChk, $closedFormChk];
Print["    1. Rotation angle (N=", $rotChk["nItems"], "): max error vs RotationMatrix[2*theta] = ",
      FmtN[$rotChk["maxError"], 3], "  (exact relation, tight tolerance)"];
Print["    2. Optimal iteration count: exact-formula k = ", $optKChk["exactKs"],
      " matches simulated-argmax k = ", $optKChk["simKs"], " for N = ", $optKChk["testNs"]];
Print["    3. Operator unitarity (N=", $unitaryChk["nItems"], "): oracle=",
      FmtN[$unitaryChk["oracleErr"], 3], "  diffusion=", FmtN[$unitaryChk["diffusionErr"], 3],
      "  Grover G=", FmtN[$unitaryChk["groverErr"], 3], "  (exact, tight tolerance)"];
Print["    4. Closed form vs direct simulation: max error over ", Length[$closedFormChk["tests"]],
      " (N,k) combinations = ", FmtN[$closedFormChk["maxError"], 3], "  (exact relation, tight tolerance)"];
Print[""];

Which[

  (* ===== search (default) ===== *)
  mode === "search",

    searchModel = SearchModel[cfg];
    PrintSearchSummary[searchModel];
    Print[""];

    Print["[2/5] Computing search trajectory..."];
    STEMSay["Running Grover iterations"];
    Print[""];

    Print["[3/5] Exporting data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "grover_search.csv"}];
    ExportSearchCSV[searchModel, outCSV];
    Print[""];

    Print["[4/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "grover_search.gif"}];
    outPNG = FileNameJoin[{$projectRoot, "output", "grover_search.png"}];
    AnimateSearch[searchModel, outGIF, outPNG];
    STEMDescribeGIF[outGIF, Length[searchModel["kArr"]], 4];
    Print[""];

    Print["[5/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "grover_search.wav"}];
    {rawLeft, rawRight} = BuildSearchAudio[searchModel, 220.0, 1400.0, 0.28, sr];
    introText   = BuildSearchIntroText[searchModel["nItems"], searchModel["optimalK"]];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuffer, rawLeft];
    finalRight = Join[introBuffer, pauseBuffer, rawRight];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""],

  (* ===== compare ===== *)
  mode === "compare",

    compareModel = CompareModel[cfg];
    PrintCompareSummary[compareModel];
    Print[""];

    Print["[2/5] Sweeping N..."];
    STEMSay["Sweeping problem size"];
    Print[""];

    Print["[3/5] Exporting data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "grover_compare.csv"}];
    ExportCompareCSV[compareModel, outCSV];
    Print[""];

    Print["[4/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "grover_compare.gif"}];
    outPNG = FileNameJoin[{$projectRoot, "output", "grover_compare.png"}];
    AnimateCompare[compareModel, outGIF, outPNG];
    STEMDescribeGIF[outGIF, 40, 12];
    Print[""];

    Print["[5/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "grover_compare.wav"}];
    {rawLeft, rawRight} = BuildCompareAudio[compareModel, 440.0, 6.0, sr];
    introText   = BuildCompareIntroText[compareModel["nItems"], Round[compareModel["classicalAtN"]], compareModel["quantumAtN"]];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuffer, rawLeft];
    finalRight = Join[introBuffer, pauseBuffer, rawRight];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""],

  (* ===== geometry ===== *)
  mode === "geometry",

    duration = N @ GetCfg[cfg, {"sonification", "duration"}, 8.0];

    geometryModel = GeometryModel[cfg];
    PrintGeometrySummary[geometryModel];
    Print[""];

    Print["[2/5] Computing rotation..."];
    STEMSay["Computing the rotation geometry"];
    Print[""];

    Print["[3/5] Exporting data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "grover_geometry.csv"}];
    ExportGeometryCSV[geometryModel, outCSV];
    Print[""];

    Print["[4/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "grover_geometry.gif"}];
    outPNG = FileNameJoin[{$projectRoot, "output", "grover_geometry.png"}];
    AnimateGeometry[geometryModel, outGIF, outPNG];
    STEMDescribeGIF[outGIF, Length[geometryModel["kArr"]], 3];
    Print[""];

    Print["[5/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "grover_geometry.wav"}];
    {rawLeft, rawRight} = BuildGeometryAudio[geometryModel, 220.0, 1400.0, duration, sr];
    introText   = BuildGeometryIntroText[geometryModel["nItems"]];
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
    Print["Error: unknown simulation.mode \"", mode, "\" — expected \"search\", \"compare\", or \"geometry\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Complete. Play audio: " <> STEMPlayCmd[outWAV]];

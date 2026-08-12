#!/usr/bin/env wolframscript

(* ========================================================
   Mandelbrot — Entry Point
   Usage: wolframscript -file main.wl [-- [--key=value ...]]
          wolframscript -file main.wl -- --config-dump
          wolframscript -file main.wl -- --simulation.mode=julia
          wolframscript -file main.wl -- --simulation.mode zoom
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

cfg  = LoadConfig["mandelbrot", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "mandelbrot"];
sr   = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];

STEMHeading["Mandelbrot"];
Print["  mode: ", mode];
Print[""];

(* ── Correctness checks — always at fixed canonical parameters,
   independent of the active mode's own configured parameters, the
   same convention every prior v1.5.0 app's checks section
   uses. ── *)
Print["[1/5] Correctness checks..."];
STEMSay["Running correctness checks"];
$escapeChk     = EscapeRadiusCheck[];
$memberChk     = MembershipFactsCheck[];
$cardioidChk   = MainCardioidBoundaryCheck[];
$complexityChk = BoundaryComplexityCheck[];
PrintCorrectnessChecks[$escapeChk, $memberChk, $cardioidChk, $complexityChk];
Print["    1. Escape radius: all ", Length[$escapeChk["results"]],
      " test (c,z) pairs strictly increasing past |z|=2  (derived, verified directly)"];
Print["    2. Membership facts: c=0 stable=", $memberChk["c0Stable"],
      "  c=-1 period-2=", $memberChk["cM1Cycle"], " bounded=", $memberChk["cM1Bounded"],
      "  c=1 escapes=", $memberChk["c1Escapes"]];
Print["    3. Main cardioid boundary (theta=", FmtN[$cardioidChk["theta"], 3], "): on-boundary=",
      $cardioidChk["onIter"], "  10% out=", $cardioidChk["outIter"], "  10% in=", $cardioidChk["inIter"],
      "  of ", $cardioidChk["maxIter"], " max"];
Print["    4. Boundary complexity: mean|delta| interior=", FmtN[$complexityChk["meanInterior"], {6, 2}],
      "  boundary=", FmtN[$complexityChk["meanBoundary"], {6, 2}],
      "  exterior=", FmtN[$complexityChk["meanExterior"], {6, 2}],
      "  (boundary/interior=", FmtN[$complexityChk["meanBoundary"] / Max[$complexityChk["meanInterior"], 10^-9], {5, 1}],
      "x, boundary/exterior=", FmtN[$complexityChk["meanBoundary"] / Max[$complexityChk["meanExterior"], 10^-9], {5, 1}], "x)"];
Print[""];

Which[

  (* ===== mandelbrot (default) ===== *)
  mode === "mandelbrot",

    mandelbrotModel = MandelbrotModel[cfg];
    PrintMandelbrotSummary[mandelbrotModel];
    Print[""];

    Print["[2/5] Computing iteration field..."];
    STEMSay["Computing the Mandelbrot set"];
    Print[""];

    Print["[3/5] Exporting data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "mandelbrot_mandelbrot.csv"}];
    ExportMandelbrotCSV[mandelbrotModel, outCSV];
    Print[""];

    (* Audio synthesised BEFORE the animation (steps swapped from a
       naive 4-then-5 numbering) because the GIF's frame rate/count are
       solved FROM the WAV's actual total duration -- see
       AnimateAndExportField's duration-sync contract in animate.wl and
       AGENTS.md, "GIF/WAV duration sync". *)
    Print["[4/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "mandelbrot_mandelbrot.wav"}];
    {rawBuffer, freqAssigned} = BuildMandelbrotAudio[mandelbrotModel, 200.0, 2200.0, 0.015, sr];
    introText   = BuildMandelbrotIntroText[mandelbrotModel["maxIter"]];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalBuffer = Join[introBuffer, pauseBuffer, rawBuffer];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[finalBuffer, sr]], "WAV"];
    $wavDurationSec = N[Length[finalBuffer]] / sr;
    STEMDescribeWAV[outWAV, $wavDurationSec];
    Print[""];

    Print["[5/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "mandelbrot_mandelbrot.gif"}];
    outPNG = FileNameJoin[{$projectRoot, "output", "mandelbrot_mandelbrot.png"}];
    {$gifFrames, $gifFps} = AnimateAndExportField[mandelbrotModel, outGIF, outPNG, $wavDurationSec];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    Print[""],

  (* ===== julia ===== *)
  mode === "julia",

    juliaModel = JuliaModel[cfg];
    PrintJuliaSummary[juliaModel];
    Print[""];

    Print["[2/5] Computing iteration field..."];
    STEMSay["Computing the Julia set"];
    Print[""];

    Print["[3/5] Exporting data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "mandelbrot_julia.csv"}];
    ExportJuliaCSV[juliaModel, outCSV];
    Print[""];

    (* Audio synthesised BEFORE the animation -- see the mandelbrot
       mode's block above for why the numbered steps are swapped. *)
    Print["[4/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "mandelbrot_julia.wav"}];
    {rawBuffer, freqAssigned} = BuildJuliaAudio[juliaModel, 200.0, 2200.0, 0.015, sr];
    introText   = BuildJuliaIntroText[juliaModel["cRe"], juliaModel["cIm"], juliaModel["cIsInterior"]];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalBuffer = Join[introBuffer, pauseBuffer, rawBuffer];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[finalBuffer, sr]], "WAV"];
    $wavDurationSec = N[Length[finalBuffer]] / sr;
    STEMDescribeWAV[outWAV, $wavDurationSec];
    Print[""];

    Print["[5/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "mandelbrot_julia.gif"}];
    outPNG = FileNameJoin[{$projectRoot, "output", "mandelbrot_julia.png"}];
    {$gifFrames, $gifFps} = AnimateAndExportField[juliaModel, outGIF, outPNG, $wavDurationSec];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    Print[""],

  (* ===== zoom ===== *)
  mode === "zoom",

    zoomModel = ZoomModel[cfg];
    PrintZoomSummary[zoomModel];
    Print[""];

    Print["[2/5] Computing iteration fields at each level..."];
    STEMSay["Computing the zoom sequence"];
    Print[""];

    Print["[3/5] Exporting data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "mandelbrot_zoom.csv"}];
    ExportZoomCSV[zoomModel, outCSV];
    Print[""];

    (* Audio synthesised BEFORE the animation -- see the mandelbrot
       mode's block above for why the numbered steps are swapped. *)
    Print["[4/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "mandelbrot_zoom.wav"}];
    {rawBuffer, freqAssigned} = BuildZoomAudio[zoomModel, 200.0, 2200.0, 0.006, sr];
    introText   = BuildZoomIntroText[zoomModel["nLevels"]];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalBuffer = Join[introBuffer, pauseBuffer, rawBuffer];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[finalBuffer, sr]], "WAV"];
    $wavDurationSec = N[Length[finalBuffer]] / sr;
    STEMDescribeWAV[outWAV, $wavDurationSec];
    Print[""];

    Print["[5/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "mandelbrot_zoom.gif"}];
    outPNG = FileNameJoin[{$projectRoot, "output", "mandelbrot_zoom.png"}];
    {$gifFrames, $gifFps} = AnimateZoom[zoomModel, outGIF, outPNG, $wavDurationSec];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    Print[""],

  (* ===== unknown mode ===== *)
  True,
    Print["Error: unknown simulation.mode \"", mode, "\" — expected \"mandelbrot\", \"julia\", or \"zoom\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Complete. Play audio: " <> STEMPlayCmd[outWAV]];

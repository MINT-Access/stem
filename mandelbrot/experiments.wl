#!/usr/bin/env wolframscript

(* mandelbrot/experiments.wl — Curated runs across all three mandelbrot
   modes. Each experiment calls the same pipeline as main.wl and writes
   its outputs to mandelbrot/output/, including the prepended spoken
   intro. *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "speech.wl"}]];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

RunExperiment[name_String, overrides_Association] :=
  Module[{cfg, mode, sr,
          mandelbrotModel, juliaModel, zoomModel,
          outWAV, outGIF, outPNG, outCSV,
          rawBuffer, freqAssigned, introText, introBuffer, pauseBuffer, finalBuffer, totalDurSec,
          gifFrames, gifFps},

    Print[""];
    STEMHeading["Experiment: " <> name];
    cfg = DeepMerge[LoadConfig["mandelbrot", {}], overrides];

    mode = GetCfg[cfg, {"simulation", "mode"}, "mandelbrot"];
    sr   =     GetCfg[cfg, {"sonification", "sample_rate"}, 44100];

    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    outGIF = FileNameJoin[{$outDir, name <> ".gif"}];
    outPNG = FileNameJoin[{$outDir, name <> ".png"}];
    outCSV = FileNameJoin[{$outDir, name <> "_data.csv"}];

    Which[

      mode === "mandelbrot",
        mandelbrotModel = MandelbrotModel[cfg];
        PrintMandelbrotSummary[mandelbrotModel];

        {rawBuffer, freqAssigned} = BuildMandelbrotAudio[mandelbrotModel, 200.0, 2200.0, 0.015, sr];
        introText   = BuildMandelbrotIntroText[mandelbrotModel["maxIter"]];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalBuffer = Join[introBuffer, pauseBuffer, rawBuffer];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[finalBuffer, sr]], "WAV"];
        totalDurSec = N[Length[finalBuffer]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        {gifFrames, gifFps} = AnimateAndExportField[mandelbrotModel, outGIF, outPNG, totalDurSec];
        STEMDescribeGIF[outGIF, gifFrames, gifFps];
        ExportMandelbrotCSV[mandelbrotModel, outCSV],

      mode === "julia",
        juliaModel = JuliaModel[cfg];
        PrintJuliaSummary[juliaModel];

        {rawBuffer, freqAssigned} = BuildJuliaAudio[juliaModel, 200.0, 2200.0, 0.015, sr];
        introText   = BuildJuliaIntroText[juliaModel["cRe"], juliaModel["cIm"], juliaModel["cIsInterior"]];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalBuffer = Join[introBuffer, pauseBuffer, rawBuffer];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[finalBuffer, sr]], "WAV"];
        totalDurSec = N[Length[finalBuffer]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        {gifFrames, gifFps} = AnimateAndExportField[juliaModel, outGIF, outPNG, totalDurSec];
        STEMDescribeGIF[outGIF, gifFrames, gifFps];
        ExportJuliaCSV[juliaModel, outCSV],

      mode === "zoom",
        zoomModel = ZoomModel[cfg];
        PrintZoomSummary[zoomModel];

        {rawBuffer, freqAssigned} = BuildZoomAudio[zoomModel, 200.0, 2200.0, 0.006, sr];
        introText   = BuildZoomIntroText[zoomModel["nLevels"]];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalBuffer = Join[introBuffer, pauseBuffer, rawBuffer];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[finalBuffer, sr]], "WAV"];
        totalDurSec = N[Length[finalBuffer]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        {gifFrames, gifFps} = AnimateZoom[zoomModel, outGIF, outPNG, totalDurSec];
        STEMDescribeGIF[outGIF, gifFrames, gifFps];
        ExportZoomCSV[zoomModel, outCSV]
    ];

    Print["  Experiment done: ", name]
  ];


(* ── Experiments ──────────────────────────────────────────────────────
   1-3: the recommended listening sequence (LISTENING_GUIDE.md) — run
   in order to hear the Mandelbrot/Julia connection from three angles. *)

RunExperiment["mandelbrot_default", <|
  "simulation" -> <| "mode" -> "mandelbrot" |>
|>];

RunExperiment["julia_default", <|
  "simulation" -> <| "mode" -> "julia" |>
|>];

RunExperiment["zoom_default", <|
  "simulation" -> <| "mode" -> "zoom" |>
|>];

(* 4. A Julia set for c OUTSIDE the Mandelbrot set — the disconnected
   ("Fatou dust") counterpart to the default connected example, heard
   and seen side by side with julia_default for direct contrast. *)
RunExperiment["julia_disconnected", <|
  "simulation" -> <|
    "mode" -> "julia",
    "mandelbrot" -> <| "julia_c_real" -> -0.7, "julia_c_imag" -> 0.27015 |>
  |>
|>];

(* 5. The Douady rabbit's own c value, but a much finer grid (128x128)
   for a noticeably richer rendering (still verified interior — the
   same c, just more resolution). *)
RunExperiment["julia_fine_grid", <|
  "simulation" -> <|
    "mode" -> "julia",
    "mandelbrot" -> <| "grid_size" -> 128, "max_iterations" -> 500 |>
  |>
|>];

(* 6. A higher-iteration-budget mandelbrot render — the boundary zone
   narrows and sharpens as max_iterations grows, since more points that
   looked "in the set" at a lower budget are revealed to actually
   escape, just very slowly. *)
RunExperiment["mandelbrot_high_iter", <|
  "simulation" -> <|
    "mode" -> "mandelbrot",
    "mandelbrot" -> <| "max_iterations" -> 1000 |>
  |>
|>];

(* 7. zoom mode centred on a different boundary point — near the
   period-3 bulb attached to the main cardioid, for a differently-
   shaped self-similar structure than the default seahorse valley. *)
RunExperiment["zoom_period3_bulb", <|
  "simulation" -> <|
    "mode" -> "zoom",
    "mandelbrot" -> <| "zoom_center_real" -> -0.1592, "zoom_center_imag" -> 1.0317, "zoom_levels" -> 3 |>
  |>
|>];

Print[""];
STEMHeading["All experiments complete"];
Print["  Output files written to: ", $outDir]

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
  Module[{cfg, mode, sr, fadeSeconds,
          mandelbrotModel, juliaModel, zoomModel,
          outWAV, outGIF, outPNG, outCSV,
          rawBuffer, freqAssigned, introText, introBuffer, pauseBuffer, fadeSilence, finalBuffer, totalDurSec,
          gifFrames, gifFps},

    Print[""];
    STEMHeading["Experiment: " <> name];
    cfg = DeepMerge[LoadConfig["mandelbrot", {}], overrides];

    mode = GetCfg[cfg, {"simulation", "mode"}, "mandelbrot"];
    sr   =     GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    (* See main.wl's own $overlayFadeSeconds comment -- same contract,
       mandelbrot/julia only (zoom has no overlay to fade). *)
    fadeSeconds = GetCfg[cfg, {"simulation", "mandelbrot", "overlay_fade_seconds"}, 1.0];

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
        introBuffer = STEMSpeakToBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        fadeSilence = ConstantArray[0.0, Round[sr * fadeSeconds]];
        finalBuffer = Join[introBuffer, pauseBuffer, rawBuffer, fadeSilence];
        EnsureDir[outWAV];
        finalBuffer = NormalizeToLoudness[finalBuffer, -17.0, 0.97, sr];
        Export[outWAV, Sound[SampledSoundList[finalBuffer, sr]], "WAV"];
        totalDurSec = N[Length[finalBuffer]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        {gifFrames, gifFps} = AnimateAndExportField[mandelbrotModel, outGIF, outPNG, totalDurSec,
                                                     150, $DefaultMaxAnimationDurationSec, fadeSeconds];
        STEMDescribeGIF[outGIF, gifFrames, gifFps];
        ExportMandelbrotCSV[mandelbrotModel, outCSV],

      mode === "julia",
        juliaModel = JuliaModel[cfg];
        PrintJuliaSummary[juliaModel];

        {rawBuffer, freqAssigned} = BuildJuliaAudio[juliaModel, 200.0, 2200.0, 0.015, sr];
        introText   = BuildJuliaIntroText[juliaModel["cRe"], juliaModel["cIm"], juliaModel["cIsInterior"]];
        introBuffer = STEMSpeakToBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        fadeSilence = ConstantArray[0.0, Round[sr * fadeSeconds]];
        finalBuffer = Join[introBuffer, pauseBuffer, rawBuffer, fadeSilence];
        EnsureDir[outWAV];
        finalBuffer = NormalizeToLoudness[finalBuffer, -17.0, 0.97, sr];
        Export[outWAV, Sound[SampledSoundList[finalBuffer, sr]], "WAV"];
        totalDurSec = N[Length[finalBuffer]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        {gifFrames, gifFps} = AnimateAndExportField[juliaModel, outGIF, outPNG, totalDurSec,
                                                     150, $DefaultMaxAnimationDurationSec, fadeSeconds];
        STEMDescribeGIF[outGIF, gifFrames, gifFps];
        ExportJuliaCSV[juliaModel, outCSV],

      mode === "zoom",
        zoomModel = ZoomModel[cfg];
        PrintZoomSummary[zoomModel];

        {rawBuffer, freqAssigned} = BuildZoomAudio[zoomModel, 200.0, 2200.0, 0.006, sr];
        introText   = BuildZoomIntroText[zoomModel["nLevels"]];
        introBuffer = STEMSpeakToBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalBuffer = Join[introBuffer, pauseBuffer, rawBuffer];
        EnsureDir[outWAV];
        finalBuffer = NormalizeToLoudness[finalBuffer, -17.0, 0.97, sr];
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

(* 8. The escape-gradient LinkedIn-video preset (see AGENTS.md, design
   decision 9): grid_size=128/max_iterations=1000/color_scheme=
   escape_gradient makes for a rich, slow-changing gradient render, but
   at the standard 0.015s/note that's a 264.7s raw sonification -- far
   outside a presentation clip's practical range. Unlike the original
   version of this preset (built by hand before design decision 10's
   BuildMandelbrotAudio maxDurationSec cap existed, using a SEPARATE,
   never-committed "video audio" resynthesis outside this file), this
   now caps the CANONICAL audio directly via BuildMandelbrotAudio's own
   maxDurationSec, so one WAV/GIF pair -- built through the normal,
   version-controlled pipeline below, not a one-off hand-patch -- is
   both this preset's real deliverable and the presentation-video
   source. maxDur=80.0 caps only the RAW note stream (CapNoteDuration);
   the intro/pause/fade riding on top of that still make the total WAV
   longer than 80s (measured: 99.6s) -- AnimateAndExportField is
   deliberately NOT given that same 80.0 as its own maxDurationSec cap
   (design decision 9's GIF-side knob), because that would re-cap the
   GIF back down to 80s against the now-100s WAV and reintroduce a
   GIF/WAV mismatch. With the audio side already fixed at the source
   (decision 10), the GIF-side cap this preset originally needed is no
   longer necessary -- the GIF paces to the full, already-reasonable
   ~100s WAV duration like any other preset. *)
RunGradientVideoPreset[] :=
  Module[{cfg, sr, fadeSeconds, maxDur, model, outWAV, outGIF, outPNG, outCSV,
          rawBuffer, freqAssigned, introText, introBuffer, pauseBuffer, fadeSilence,
          finalBuffer, totalDurSec, gifFrames, gifFps},
    Print[""];
    STEMHeading["Experiment: mandelbrot_high_iter_gradient"];
    cfg = DeepMerge[LoadConfig["mandelbrot", {}], <|
      "simulation" -> <|
        "mode" -> "mandelbrot",
        "mandelbrot" -> <| "grid_size" -> 128, "max_iterations" -> 1000, "color_scheme" -> "escape_gradient" |>
      |>
    |>];
    sr = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    fadeSeconds = GetCfg[cfg, {"simulation", "mandelbrot", "overlay_fade_seconds"}, 1.0];
    maxDur = 80.0;

    model = MandelbrotModel[cfg];
    PrintMandelbrotSummary[model];

    outWAV = FileNameJoin[{$outDir, "mandelbrot_high_iter_gradient_audio.wav"}];
    outGIF = FileNameJoin[{$outDir, "mandelbrot_high_iter_gradient.gif"}];
    outPNG = FileNameJoin[{$outDir, "mandelbrot_high_iter_gradient.png"}];
    outCSV = FileNameJoin[{$outDir, "mandelbrot_high_iter_gradient_data.csv"}];

    {rawBuffer, freqAssigned} = BuildMandelbrotAudio[model, 200.0, 2200.0, 0.015, sr, maxDur];
    introText   = BuildMandelbrotIntroText[model["maxIter"]];
    introBuffer = STEMSpeakToBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    fadeSilence = ConstantArray[0.0, Round[sr * fadeSeconds]];
    finalBuffer = Join[introBuffer, pauseBuffer, rawBuffer, fadeSilence];
    EnsureDir[outWAV];
    finalBuffer = NormalizeToLoudness[finalBuffer, -17.0, 0.97, sr];
    Export[outWAV, Sound[SampledSoundList[finalBuffer, sr]], "WAV"];
    totalDurSec = N[Length[finalBuffer]] / sr;
    STEMDescribeWAV[outWAV, totalDurSec];

    {gifFrames, gifFps} = AnimateAndExportField[model, outGIF, outPNG, totalDurSec,
                                                 150, $DefaultMaxAnimationDurationSec, fadeSeconds];
    STEMDescribeGIF[outGIF, gifFrames, gifFps];
    ExportMandelbrotCSV[model, outCSV];
    Print["  Experiment done: mandelbrot_high_iter_gradient"];
  ];

RunGradientVideoPreset[];

Print[""];
STEMHeading["All experiments complete"];
Print["  Output files written to: ", $outDir]

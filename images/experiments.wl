#!/usr/bin/env wolframscript

(* images/experiments.wl — Curated preset runs for image sonification.
   Each experiment calls the main pipeline with a specific configuration
   and writes its outputs to images/output/, including a prepended
   spoken intro, mirroring main.wl's behaviour exactly. *)

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
  Module[{cfg, mode, imgSizeCfg, inputFile, testImage, freqMin, freqMax,
          brightnessScale, brightnessGamma, noteDurationBase, scanDirectionCfg,
          sr, imgN, imgSize, travMode, processedImg, srcDesc, model,
          sonifyResult, channels, freqAssigned, colourStats,
          sonificationDurSec, introText, introBuffer, pauseBuffer,
          finalBuffer, finalLeft, finalRight, totalDurSec,
          outWAV, outGIF, outCSV, outPNG},
    Print[""];
    STEMHeading["Experiment: " <> name];
    cfg = DeepMerge[
      LoadConfig["images", {}],
      overrides
    ];
    mode             = GetCfg[cfg, {"simulation","mode"},                     "brightness"];
    imgSizeCfg       = GetCfg[cfg, {"simulation","images","size"},             64];
    inputFile        = GetCfg[cfg, {"simulation","images","input_file"},       ""];
    testImage        = GetCfg[cfg, {"simulation","images","test_image"},       "gaussian"];
    freqMin          = N @ GetCfg[cfg, {"simulation","images","freq_min"},     200];
    freqMax          = N @ GetCfg[cfg, {"simulation","images","freq_max"},     2000];
    brightnessScale  = GetCfg[cfg, {"simulation","images","brightness_scale"}, "log"];
    brightnessGamma  = N @ GetCfg[cfg, {"simulation","images","brightness_gamma"}, 1.0];
    noteDurationBase = N @ GetCfg[cfg, {"simulation","images","note_duration_base"}, 0.02];
    scanDirectionCfg = GetCfg[cfg, {"simulation","images","scan_direction"},   "hilbert"];
    sr               = GetCfg[cfg, {"sonification","sample_rate"}, 44100];

    travMode = If[mode === "scan_horizontal", "raster", scanDirectionCfg];
    imgN    = Min[8, Round[Log2[N[imgSizeCfg]]]];
    imgSize = 2^imgN;

    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    outGIF = FileNameJoin[{$outDir, name <> ".gif"}];
    outCSV = FileNameJoin[{$outDir, name <> "_data.csv"}];
    outPNG = FileNameJoin[{$outDir, name <> ".png"}];

    {processedImg, srcDesc} = LoadSourceImage[inputFile, testImage, imgSize];
    model = ComputeImageTraversal[processedImg, imgN, travMode];

    sonifyResult = SonifyImageMode[mode, model, freqMin, freqMax, noteDurationBase, sr,
                                    brightnessScale, brightnessGamma];
    channels     = sonifyResult["channels"];
    freqAssigned = sonifyResult["freqAssigned"];
    colourStats  = sonifyResult["colourStats"];

    sonificationDurSec = N[model["nPixels"] * noteDurationBase];
    introText = BuildIntroText[mode, srcDesc,
      ImageDimensions[processedImg][[1]], ImageDimensions[processedImg][[2]],
      brightnessScale, sonificationDurSec, colourStats];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];

    If[Length[channels] === 1,
      finalBuffer = Join[introBuffer, pauseBuffer, channels[[1]]];
      ExportAudioBuffer[finalBuffer, outWAV, sr];
      totalDurSec = N[Length[finalBuffer]] / sr,

      finalLeft  = Join[introBuffer, pauseBuffer, channels[[1]]];
      finalRight = Join[introBuffer, pauseBuffer, channels[[2]]];
      EnsureDir[outWAV];
      Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
      totalDurSec = N[Length[finalLeft]] / sr
    ];
    STEMDescribeWAV[outWAV, totalDurSec];

    If[mode === "scan_horizontal",
      AnimateRasterScan[model, outGIF, totalDurSec],
      AnimateImageTraversal[model, outGIF, totalDurSec]
    ];
    ExportImageData[model, freqAssigned, outCSV];
    ExportImagePNG[model, outPNG];
    Print["  Experiment done: ", name]
  ];


(* ── Experiments ────────────────────────────────────────────────────── *)

(* 1. Brightness — smooth Gaussian gradient: log pitch sweep (default scale) *)
RunExperiment["brightness_gaussian", <|
  "simulation" -> <|
    "mode" -> "brightness",
    "images" -> <|"test_image" -> "gaussian", "size" -> 32|>
  |>
|>];

(* 2. Colour — temperature map: concentric colour bands -> spectral palette *)
RunExperiment["colour_temperature", <|
  "simulation" -> <|
    "mode" -> "colour",
    "images" -> <|"test_image" -> "temperature", "size" -> 32|>
  |>
|>];

(* 3. HSB — quantum probability density: four lobes, pitch+timbre texture *)
RunExperiment["hsb_quantum", <|
  "simulation" -> <|
    "mode" -> "hsb",
    "images" -> <|"test_image" -> "quantum", "size" -> 32|>
  |>
|>];

(* 4. Brightness — 64x64 Gaussian: longer, smoother sweep *)
RunExperiment["brightness_gaussian_64", <|
  "simulation" -> <|
    "mode" -> "brightness",
    "images" -> <|"test_image" -> "gaussian", "size" -> 64|>
  |>
|>];

(* 5. Colour — quantum probability: compare to HSB to hear information difference *)
RunExperiment["colour_quantum", <|
  "simulation" -> <|
    "mode" -> "colour",
    "images" -> <|"test_image" -> "quantum", "size" -> 32|>
  |>
|>];

(* 6. Brightness — narrow frequency range (400-800 Hz): pitch differences more subtle *)
RunExperiment["brightness_narrow_range", <|
  "simulation" -> <|
    "mode" -> "brightness",
    "images" -> <|
      "test_image" -> "gaussian",
      "size" -> 32,
      "freq_min" -> 400,
      "freq_max" -> 800
    |>
  |>
|>];

(* 7. HSB — temperature map: colour structure audible in pitch and timbre *)
RunExperiment["hsb_temperature", <|
  "simulation" -> <|
    "mode" -> "hsb",
    "images" -> <|"test_image" -> "temperature", "size" -> 32|>
  |>
|>];

(* 8. Brightness — fast notes: pixel-by-pixel rhythm more prominent *)
RunExperiment["brightness_fast_notes", <|
  "simulation" -> <|
    "mode" -> "brightness",
    "images" -> <|
      "test_image" -> "gaussian",
      "size" -> 32,
      "note_duration_base" -> 0.01
    |>
  |>
|>];

(* 9. Scan horizontal — same Gaussian image as experiment 1: listen to
   this first, then brightness_gaussian, to hear the Hilbert locality
   improvement directly (per LISTENING_GUIDE.md's recommended sequence). *)
RunExperiment["scan_horizontal_gaussian", <|
  "simulation" -> <|
    "mode" -> "scan_horizontal",
    "images" -> <|"test_image" -> "gaussian", "size" -> 32|>
  |>
|>];

(* 10. Brightness — linear scale override, for direct comparison against
   the log-scale default (experiment 1). *)
RunExperiment["brightness_linear_gaussian", <|
  "simulation" -> <|
    "mode" -> "brightness",
    "images" -> <|
      "test_image" -> "gaussian",
      "size" -> 32,
      "brightness_scale" -> "linear"
    |>
  |>
|>];

(* 11. Brightness — log scale with gamma=2.5: compresses highlights, so
   only the brightest central pixels reach the top of the frequency range. *)
RunExperiment["brightness_gamma_compressed", <|
  "simulation" -> <|
    "mode" -> "brightness",
    "images" -> <|
      "test_image" -> "gaussian",
      "size" -> 32,
      "brightness_scale" -> "log",
      "brightness_gamma" -> 2.5
    |>
  |>
|>];

(* 12. Colour — slower scan (note_duration_base=0.05): held notes in
   colour mode become long enough to comfortably count by ear. *)
RunExperiment["colour_slow_scan", <|
  "simulation" -> <|
    "mode" -> "colour",
    "images" -> <|
      "test_image" -> "temperature",
      "size" -> 32,
      "note_duration_base" -> 0.05
    |>
  |>
|>];

(* 13. HSB — 64x64 quantum image: large enough to trigger the 25/50/75%
   quadrant orientation clicks and hear the dark-vs-bright timbre
   contrast across a longer traversal. *)
RunExperiment["hsb_timbre_demo", <|
  "simulation" -> <|
    "mode" -> "hsb",
    "images" -> <|"test_image" -> "quantum", "size" -> 64|>
  |>
|>];

Print[""];
STEMHeading["All experiments complete"];
Print["  Output files written to: ", $outDir]

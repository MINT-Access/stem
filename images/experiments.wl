#!/usr/bin/env wolframscript

(* images/experiments.wl — Curated preset runs for image sonification.
   Each experiment calls the main entry point with a specific configuration
   and writes its outputs to images/output/. *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

RunExperiment[name_String, overrides_Association] :=
  Module[{cfg, mode, imgSizeCfg, inputFile, testImage, freqMin, freqMax,
          noteDur, sr, imgN, imgSize, processedImg, srcDesc, model,
          freqAssigned, outWAV, outGIF, outCSV, outPNG},
    Print[""];
    STEMHeading["Experiment: " <> name];
    cfg = DeepMerge[
      LoadConfig["images", {}],
      overrides
    ];
    mode       = GetCfg[cfg, {"simulation","mode"},                  "brightness"];
    imgSizeCfg = GetCfg[cfg, {"simulation","images","size"},          64];
    inputFile  = GetCfg[cfg, {"simulation","images","input_file"},    ""];
    testImage  = GetCfg[cfg, {"simulation","images","test_image"},    "gaussian"];
    freqMin    = N @ GetCfg[cfg, {"simulation","images","freq_min"},  200];
    freqMax    = N @ GetCfg[cfg, {"simulation","images","freq_max"},  2000];
    noteDur    = N @ GetCfg[cfg, {"simulation","images","note_duration"}, 0.05];
    sr         = GetCfg[cfg, {"sonification","sample_rate"}, 44100];
    imgN    = Min[8, Round[Log2[N[imgSizeCfg]]]];
    imgSize = 2^imgN;

    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    outGIF = FileNameJoin[{$outDir, name <> ".gif"}];
    outCSV = FileNameJoin[{$outDir, name <> "_data.csv"}];
    outPNG = FileNameJoin[{$outDir, name <> ".png"}];

    {processedImg, srcDesc} = LoadSourceImage[inputFile, testImage, imgSize];
    model = ComputeImageTraversal[processedImg, imgN];
    freqAssigned = SonifyImageMode[mode, model, freqMin, freqMax, noteDur, sr, outWAV];
    AnimateImageTraversal[model, outGIF];
    ExportImageData[model, freqAssigned, outCSV];
    ExportImagePNG[model, outPNG];
    Print["  Experiment done: ", name]
  ];


(* ── Experiments ────────────────────────────────────────────────────── *)

(* 1. Brightness — smooth Gaussian gradient: linear pitch sweep *)
RunExperiment["brightness_gaussian", <|
  "simulation" -> <|
    "mode" -> "brightness",
    "images" -> <|"test_image" -> "gaussian", "size" -> 32|>
  |>
|>];

(* 2. Colour — temperature map: concentric colour bands -> musical scale *)
RunExperiment["colour_temperature", <|
  "simulation" -> <|
    "mode" -> "colour",
    "images" -> <|"test_image" -> "temperature", "size" -> 32|>
  |>
|>];

(* 3. HSB — quantum probability density: four lobes, rich stereo texture *)
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

(* 7. HSB — temperature map: colour structure audible in both stereo channels *)
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
      "note_duration" -> 0.02
    |>
  |>
|>];

Print[""];
STEMHeading["All experiments complete"];
Print["  Output files written to: ", $outDir]

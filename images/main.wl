#!/usr/bin/env wolframscript

(* ========================================================
   Image Sonification — Entry Point

   Converts 2D scientific images into audio using Hilbert
   curve traversal, making spatial image structure audible.
   Nearby pixels in the traversal are nearby in the image,
   so spatial gradients become temporal audio sweeps.

   Usage:
     wolframscript -file main.wl [-- [--key=value ...]]
     wolframscript -file main.wl -- --config-dump
     wolframscript -file main.wl -- --simulation.mode=brightness
     wolframscript -file main.wl -- --simulation.mode=colour
     wolframscript -file main.wl -- --simulation.mode=hsb
     wolframscript -file main.wl -- --simulation.images.test_image=temperature
     wolframscript -file main.wl -- --simulation.images.test_image=quantum
     wolframscript -file main.wl -- --simulation.images.input_file=myimage.png
     wolframscript -file main.wl -- --simulation.images.size=128

   Modes:
     brightness -- grayscale brightness -> frequency (200-2000 Hz);
                   Hilbert traversal order; mono WAV
     colour     -- each pixel mapped to nearest of 10 named colours;
                   each colour has a fixed pitch (C3-C5); consecutive
                   same-colour runs produce a held note; mono WAV
     hsb        -- Rangan (2018) full-colour approach: hue -> left
                   channel frequency (100-3900 Hz), brightness ->
                   right channel frequency, saturation -> amplitude;
                   stereo WAV; most information-dense

   Outputs (images/output/):
     images_<mode>_audio.wav  -- the sonification
     images_<mode>.gif        -- Hilbert traversal animation
     images_<mode>_data.csv   -- per-pixel data table
     images_<mode>.png        -- the processed source image
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];

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
      i += 1
    ]
  ];
  result
];

cfg  = LoadConfig["images", $cliArgs];
mode = GetCfg[cfg, {"simulation","mode"}, "brightness"];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

outWAV = FileNameJoin[{$outDir, "images_" <> mode <> "_audio.wav"}];
outGIF = FileNameJoin[{$outDir, "images_" <> mode <> ".gif"}];
outCSV = FileNameJoin[{$outDir, "images_" <> mode <> "_data.csv"}];
outPNG = FileNameJoin[{$outDir, "images_" <> mode <> ".png"}];

imgSizeCfg = GetCfg[cfg, {"simulation","images","size"},              64];
inputFile  = GetCfg[cfg, {"simulation","images","input_file"},        ""];
testImage  = GetCfg[cfg, {"simulation","images","test_image"},        "gaussian"];
freqMin    = N @ GetCfg[cfg, {"simulation","images","freq_min"},      200];
freqMax    = N @ GetCfg[cfg, {"simulation","images","freq_max"},      2000];
noteDur    = N @ GetCfg[cfg, {"simulation","images","note_duration"}, 0.05];
sr         = GetCfg[cfg, {"sonification","sample_rate"},              44100];

imgN    = Min[8, Round[Log2[N[imgSizeCfg]]]];
imgSize = 2^imgN;

STEMHeading["Image Sonification"];
Print["  Mode:           ", mode];
Print["  Image size:     ", imgSize, " x ", imgSize,
      " pixels  (Hilbert order ", imgN, ", ", imgSize^2, " pixels total)"];
Print["  Note duration:  ", FmtN[noteDur * 1000, 4], " ms"];
Print["  Audio duration: ", FmtN[N[imgSize^2 * noteDur], {7,1}], " s"];
If[mode === "brightness" || mode === "colour",
  Print["  Freq range:     ", FmtN[freqMin, 5], " Hz  to  ", FmtN[freqMax, 5], " Hz"]
];
Print[""];

Print["[1/5] Loading image..."];
STEMSay["Loading image"];
{processedImg, srcDesc} = LoadSourceImage[inputFile, testImage, imgSize];
Print["  Source: ", srcDesc];
Print["  Dimensions: ", ImageDimensions[processedImg][[1]], " x ",
      ImageDimensions[processedImg][[2]]];
Print[""];

Print["[2/5] Computing Hilbert curve traversal (order ", imgN, ")..."];
STEMSay["Computing Hilbert curve traversal"];
model = ComputeImageTraversal[processedImg, imgN];
Print["  Traversal length: ", model["nPixels"], " pixels  (", imgSize, "^2)"];
Print[""];

Print["[3/5] Sonifying (", mode, " mode)..."];
STEMSay["Sonifying image in " <> mode <> " mode"];
freqAssigned = SonifyImageMode[mode, model, freqMin, freqMax, noteDur, sr, outWAV];
Print[""];

Print["[4/5] Rendering Hilbert traversal animation..."];
STEMSay["Rendering traversal animation"];
AnimateImageTraversal[model, outGIF];
STEMDescribeGIF[outGIF, 32, 10];
Print[""];

Print["[5/5] Exporting data table and source image..."];
ExportImageData[model, freqAssigned, outCSV];
ExportImagePNG[model, outPNG];
Print[""];

STEMHeading["Done"];
STEMSay["Complete. Play audio: " <> STEMPlayCmd[outWAV]]

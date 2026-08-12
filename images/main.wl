#!/usr/bin/env wolframscript

(* ========================================================
   Image Sonification — Entry Point

   Converts 2D scientific images into audio using Hilbert
   curve traversal (or, in scan_horizontal mode, a simple
   raster scan), making spatial image structure audible.
   Nearby pixels in the traversal are nearby in the image,
   so spatial gradients become temporal audio sweeps.

   New to image sonification? Start with images/LISTENING_GUIDE.md.

   Usage:
     wolframscript -file main.wl [-- [--key=value ...]]
     wolframscript -file main.wl -- --config-dump
     wolframscript -file main.wl -- --simulation.mode=brightness
     wolframscript -file main.wl -- --simulation.mode=scan_horizontal
     wolframscript -file main.wl -- --simulation.mode=colour
     wolframscript -file main.wl -- --simulation.mode=hsb
     wolframscript -file main.wl -- --simulation.images.test_image=temperature
     wolframscript -file main.wl -- --simulation.images.test_image=quantum
     wolframscript -file main.wl -- --simulation.images.input_file=myimage.png
     wolframscript -file main.wl -- --simulation.images.size=128
     wolframscript -file main.wl -- --simulation.images.brightness_scale=linear
     wolframscript -file main.wl -- --simulation.images.note_duration_base=0.05

   Modes:
     brightness      -- grayscale brightness -> frequency (linear or log,
                        default log); Hilbert traversal; mono WAV; quadrant
                        orientation clicks for images larger than 32x32
     scan_horizontal -- same brightness mapping as above, but on a simple
                        left-to-right, row-by-row raster scan instead of
                        the Hilbert curve — a pedagogical contrast mode
     colour          -- each pixel mapped to the nearest of 9 spectral
                        colours (violet -> red, plus white/black) by Lab
                        colour distance; each colour has a fixed pitch;
                        consecutive same-colour runs become one held note
     hsb             -- hue -> shared pitch on both channels; left is a
                        pure reference tone, right adds brightness-
                        controlled harmonics (timbre encodes brightness);
                        saturation -> amplitude; stereo WAV

   A short spoken introduction (image, dimensions, mode, and how to
   interpret the mapping) is synthesised and prepended to the WAV
   before export, so the file begins with orientation and flows
   directly into the sonification.

   Outputs (images/output/):
     images_<mode>_audio.wav  -- spoken intro + sonification, single file
     images_<mode>.gif        -- traversal animation (Hilbert or raster scan)
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

imgSizeCfg       = GetCfg[cfg, {"simulation","images","size"},               64];
inputFile        = GetCfg[cfg, {"simulation","images","input_file"},         ""];
testImage        = GetCfg[cfg, {"simulation","images","test_image"},         "gaussian"];
freqMin          = N @ GetCfg[cfg, {"simulation","images","freq_min"},       200];
freqMax          = N @ GetCfg[cfg, {"simulation","images","freq_max"},       2000];
brightnessScale  = GetCfg[cfg, {"simulation","images","brightness_scale"},    "log"];
brightnessGamma  = N @ GetCfg[cfg, {"simulation","images","brightness_gamma"}, 1.0];
noteDurationBase = N @ GetCfg[cfg, {"simulation","images","note_duration_base"}, 0.02];
scanDirectionCfg = GetCfg[cfg, {"simulation","images","scan_direction"},      "hilbert"];
sr               = GetCfg[cfg, {"sonification","sample_rate"},               44100];

(* scan_horizontal always uses a raster traversal, regardless of the
   scan_direction config key (which lets other modes opt into raster
   traversal too, for experimentation). *)
travMode = If[mode === "scan_horizontal", "raster", scanDirectionCfg];

imgN    = Min[8, Round[Log2[N[imgSizeCfg]]]];
imgSize = 2^imgN;

STEMHeading["Image Sonification"];
Print["  Mode:               ", mode];
Print["  Image size:         ", imgSize, " x ", imgSize,
      " pixels  (order ", imgN, ", ", imgSize^2, " pixels total, ", travMode, " traversal)"];
Print["  Note duration base: ", FmtN[noteDurationBase * 1000, 4], " ms/pixel"];
Print["  Audio duration:     ", FmtN[N[imgSize^2 * noteDurationBase], {7,1}],
      " s  (before spoken intro)"];
If[mode === "brightness" || mode === "scan_horizontal",
  Print["  Freq range:         ", FmtN[freqMin, 5], " Hz  to  ", FmtN[freqMax, 5], " Hz"];
  Print["  Brightness scale:   ", brightnessScale, "  (gamma ", FmtN[brightnessGamma, 3], ")"]
];
Print[""];

Print["[1/5] Loading image..."];
STEMSay["Loading image"];
{processedImg, srcDesc} = LoadSourceImage[inputFile, testImage, imgSize];
Print["  Source: ", srcDesc];
Print["  Dimensions: ", ImageDimensions[processedImg][[1]], " x ",
      ImageDimensions[processedImg][[2]]];
Print[""];

Print["[2/5] Computing pixel traversal (", travMode, " order ", imgN, ")..."];
STEMSay["Computing " <> travMode <> " traversal"];
model = ComputeImageTraversal[processedImg, imgN, travMode];
Print["  Traversal length: ", model["nPixels"], " pixels  (", imgSize, "^2)"];
Print[""];

Print["[3/5] Sonifying (", mode, " mode)..."];
STEMSay["Sonifying image in " <> mode <> " mode"];
sonifyResult = SonifyImageMode[mode, model, freqMin, freqMax, noteDurationBase, sr,
                                brightnessScale, brightnessGamma];
channels     = sonifyResult["channels"];
freqAssigned = sonifyResult["freqAssigned"];
colourStats  = sonifyResult["colourStats"];
Print[""];

(* ── Spoken orientation intro: prepend to the sonification before export ── *)
sonificationDurSec = N[model["nPixels"] * noteDurationBase];
introText = BuildIntroText[mode, srcDesc,
  ImageDimensions[processedImg][[1]], ImageDimensions[processedImg][[2]],
  brightnessScale, sonificationDurSec, colourStats];
Print["  Spoken intro: ", introText];
introBuffer = BuildIntroBuffer[introText, sr];
introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];

If[Length[channels] === 1,
  finalBuffer = Join[introBuffer, pauseBuffer, channels[[1]]];
  ExportAudioBuffer[finalBuffer, outWAV, sr];
  totalDurSec = N[Length[finalBuffer]] / sr,

  (* stereo (hsb): duplicate the same intro into both channels so the
     spoken introduction is centred, not panned *)
  finalLeft  = Join[introBuffer, pauseBuffer, channels[[1]]];
  finalRight = Join[introBuffer, pauseBuffer, channels[[2]]];
  EnsureDir[outWAV];
  Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
  totalDurSec = N[Length[finalLeft]] / sr
];
STEMDescribeWAV[outWAV, totalDurSec];
Print[""];

(* GIF duration synced to the WAV's actual total duration (including
   its spoken intro) — see images/AGENTS.md "GIF/WAV duration sync". *)
Print["[4/5] Rendering traversal animation..."];
STEMSay["Rendering traversal animation"];
{$gifFrames, $gifFps} = If[mode === "scan_horizontal",
  AnimateRasterScan[model, outGIF, totalDurSec],
  AnimateImageTraversal[model, outGIF, totalDurSec]
];
STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
Print[""];

Print["[5/5] Exporting data table and source image..."];
ExportImageData[model, freqAssigned, outCSV];
ExportImagePNG[model, outPNG];
Print[""];

STEMHeading["Done"];
STEMSay["Complete. Play audio: " <> STEMPlayCmd[outWAV]]

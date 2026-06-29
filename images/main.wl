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
     brightness — grayscale brightness -> frequency (200-2000 Hz);
                  Hilbert traversal order; mono WAV
     colour     — each pixel mapped to nearest of 10 named colours;
                  each colour has a fixed pitch (C3-C5); consecutive
                  same-colour runs produce a held note; mono WAV
     hsb        — Rangan (2018) full-colour approach: hue -> left
                  channel frequency (100-3900 Hz), brightness ->
                  right channel frequency, saturation -> amplitude;
                  stereo WAV; most information-dense

   Outputs (images/output/):
     images_<mode>_audio.wav  — the sonification
     images_<mode>.gif        — Hilbert traversal animation
     images_<mode>_data.csv   — per-pixel data table
     images_<mode>.png        — the processed source image
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

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

(* ── Output file paths ──────────────────────────────────────────── *)
outWAV = FileNameJoin[{$outDir, "images_" <> mode <> "_audio.wav"}];
outGIF = FileNameJoin[{$outDir, "images_" <> mode <> ".gif"}];
outCSV = FileNameJoin[{$outDir, "images_" <> mode <> "_data.csv"}];
outPNG = FileNameJoin[{$outDir, "images_" <> mode <> ".png"}];

(* ── Config parameters ──────────────────────────────────────────── *)
imgSizeCfg = GetCfg[cfg, {"simulation","images","size"},          64];
inputFile  = GetCfg[cfg, {"simulation","images","input_file"},    ""];
testImage  = GetCfg[cfg, {"simulation","images","test_image"},    "gaussian"];
freqMin    = N @ GetCfg[cfg, {"simulation","images","freq_min"},  200];
freqMax    = N @ GetCfg[cfg, {"simulation","images","freq_max"},  2000];
noteDur    = N @ GetCfg[cfg, {"simulation","images","note_duration"}, 0.05];
sr         = GetCfg[cfg, {"sonification","sample_rate"},          44100];

(* Round to nearest power of 2; cap at 256 *)
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

(* ── [1/5] Load or generate source image ────────────────────────── *)
Print["[1/5] Loading image..."];
STEMSay["Loading image"];

rawImg = If[inputFile =!= "",
  Module[{img = Quiet[Import[inputFile]]},
    If[!ImageQ[img],
      Print["Error: could not load \"", inputFile, "\" as an image."];
      Exit[1]
    ];
    Print["  Source: ", inputFile];
    img
  ],
  Module[{img},
    img = Switch[testImage,

      "gaussian",
        (* 2D Gaussian centred on the image — smooth gradient,
           demonstrates brightness mode clearly *)
        With[{sz = imgSize, sig = imgSize / 4.0},
          Image[N @ Table[
            Exp[-((x - sz/2)^2 + (y - sz/2)^2) / (2.0 * sig^2)],
            {y, sz}, {x, sz}
          ]]
        ],

      "temperature",
        (* False-colour radial temperature map — concentric colour
           bands, demonstrates colour mode *)
        With[{sz = imgSize},
          Module[{d = N @ Table[
                    Sqrt[(x - sz/2)^2 + (y - sz/2)^2] / (sz / 2.0),
                    {y, sz}, {x, sz}]},
            Image[Map[
              Function[t,
                Which[
                  t < 0.25, {0.0, 4.0*t, 1.0},            (* blue  -> cyan  *)
                  t < 0.5,  {0.0, 1.0, 1.0 - 4.0*(t-0.25)}, (* cyan  -> green *)
                  t < 0.75, {4.0*(t-0.5), 1.0, 0.0},       (* green -> yellow *)
                  True,     {1.0, 1.0 - 4.0*(t-0.75), 0.0} (* yellow-> red   *)
                ]],
              d, {2}]]
          ]
        ],

      "quantum",
        (* |psi_{1,2}(x,y)|^2 for a 2D particle in a box —
           four probability lobes; connects to the quantum app *)
        With[{sz = imgSize},
          Module[{d = N @ Table[
                    Sin[Pi*x/sz]^2 * Sin[2*Pi*y/sz]^2,
                    {y, sz}, {x, sz}],
                  dmax},
            dmax = Max[d];
            Image[Map[
              Function[v,
                With[{t = v / dmax},
                  Which[
                    t < 0.333, {3.0*t, 0.0, 0.0},
                    t < 0.667, {1.0, 3.0*(t - 0.333), 0.0},
                    True,      {1.0, 1.0, 3.0*(t - 0.667)}
                  ]]],
              d, {2}]]
          ]
        ],

      _,
        Print["Warning: unknown test_image \"", testImage, "\" — using gaussian"];
        With[{sz = imgSize, sig = imgSize / 4.0},
          Image[N @ Table[
            Exp[-((x - sz/2)^2 + (y - sz/2)^2) / (2.0 * sig^2)],
            {y, sz}, {x, sz}
          ]]
        ]
    ];
    Print["  Source: built-in test image  (", testImage, ")"];
    img
  ]
];

(* Resize to exact imgSize × imgSize *)
processedImg = ImageResize[rawImg, {imgSize, imgSize}];
Print["  Dimensions: ", ImageDimensions[processedImg][[1]], " x ",
      ImageDimensions[processedImg][[2]]];
Print[""];

(* ── [2/5] Compute Hilbert curve traversal ──────────────────────── *)
Print["[2/5] Computing Hilbert curve traversal (order ", imgN, ")..."];
STEMSay["Computing Hilbert curve traversal"];
traversal = HilbertTraversalOrder[imgN];
nPixels   = Length[traversal];
Print["  Traversal length: ", nPixels, " pixels  (", imgSize, "^2)"];
Print[""];

(* Pre-extract pixel data for every traversal position.
   greyData: 2D array {height, width} of grayscale brightness [0,1]
   hsbData:  3D array {height, width, 3} of {hue, saturation, brightness}
   rgbData:  3D array {height, width, 3} of {r, g, b} *)
greyData = ImageData[ColorConvert[processedImg, "Grayscale"]];
hsbData  = ImageData[ColorConvert[processedImg, "HSB"]];
rgbData  = ImageData[ColorConvert[processedImg, "RGB"]];

pixBright = Table[greyData[[ traversal[[i,2]], traversal[[i,1]]   ]], {i, nPixels}];
pixHue    = Table[hsbData[[ traversal[[i,2]], traversal[[i,1]], 1 ]], {i, nPixels}];
pixSat    = Table[hsbData[[ traversal[[i,2]], traversal[[i,1]], 2 ]], {i, nPixels}];

(* freqAssigned is filled by the mode-specific block below for the CSV *)
freqAssigned = ConstantArray[0.0, nPixels];

(* ── Colour palette (used by colour mode) ───────────────────────── *)
$imgPalette = {
  <| "name" -> "black",  "rgb" -> {0.00, 0.00, 0.00}, "freq" -> 130.81 |>,
  <| "name" -> "grey",   "rgb" -> {0.50, 0.50, 0.50}, "freq" -> 164.81 |>,
  <| "name" -> "red",    "rgb" -> {0.90, 0.10, 0.10}, "freq" -> 196.00 |>,
  <| "name" -> "orange", "rgb" -> {1.00, 0.50, 0.00}, "freq" -> 220.00 |>,
  <| "name" -> "yellow", "rgb" -> {1.00, 0.90, 0.00}, "freq" -> 261.63 |>,
  <| "name" -> "green",  "rgb" -> {0.10, 0.80, 0.10}, "freq" -> 329.63 |>,
  <| "name" -> "cyan",   "rgb" -> {0.00, 0.80, 0.80}, "freq" -> 392.00 |>,
  <| "name" -> "blue",   "rgb" -> {0.10, 0.10, 0.90}, "freq" -> 440.00 |>,
  <| "name" -> "violet", "rgb" -> {0.50, 0.00, 0.90}, "freq" -> 523.25 |>,
  <| "name" -> "white",  "rgb" -> {1.00, 1.00, 1.00}, "freq" -> 659.25 |>
};


(* ── [3/5] Sonify ───────────────────────────────────────────────── *)

Which[

  (* ══════════════════════════════════════════════════════
     BRIGHTNESS MODE
     Each pixel's grayscale brightness maps to frequency.
     Low brightness (dark) -> low pitch; high (bright) -> high.
     ══════════════════════════════════════════════════════ *)
  mode === "brightness",

    Print["[3/5] Sonifying (brightness mode)..."];
    STEMSay["Sonifying image in brightness mode"];

    freqAssigned = freqMin + pixBright * (freqMax - freqMin);

    With[{fa = freqAssigned, nd = noteDur, sr0 = sr},
      audioBuffer = Flatten @ Table[
        StemSynthNote[fa[[i]], nd, 0.8, {1.0}, 0.2, sr0],
        {i, nPixels}
      ]
    ];
    ExportAudioBuffer[NormalizeBuffer[audioBuffer, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[nPixels * noteDur]];
    Print["  Mapping: dark pixels -> ", FmtN[freqMin, 5],
          " Hz;  bright pixels -> ", FmtN[freqMax, 5], " Hz"];
    Print[""],


  (* ══════════════════════════════════════════════════════
     COLOUR MODE
     Each pixel mapped to the nearest of 10 named colours
     (Euclidean distance in RGB space).  Each colour has a
     fixed musical pitch on a C major scale (C3 to C5).
     Consecutive pixels with the same colour produce a
     single held note rather than repeated attacks.
     ══════════════════════════════════════════════════════ *)
  mode === "colour",

    Print["[3/5] Sonifying (colour mode)..."];
    STEMSay["Sonifying image in colour mode"];

    Module[{paletteRGBvals, colourIdxSeq, colourRuns},

      paletteRGBvals = Map[#["rgb"] &, $imgPalette];

      (* Assign each traversal pixel to its nearest palette colour *)
      colourIdxSeq = Table[
        With[{pix = Take[rgbData[[ traversal[[i,2]], traversal[[i,1]] ]], 3]},
          First[Ordering[Map[Total[(pix - #)^2] &, paletteRGBvals], 1]]
        ],
        {i, nPixels}
      ];

      freqAssigned = Map[$imgPalette[[#]]["freq"] &, colourIdxSeq];

      (* Group consecutive same-colour pixels -> one note per run *)
      colourRuns = Split[colourIdxSeq];

      Print["  Palette colours found:   ",
            Length[DeleteDuplicates[colourIdxSeq]], " of ",
            Length[$imgPalette]];
      Print["  Consecutive colour runs: ", Length[colourRuns]];
      Print["  Mean run length:         ",
            FmtN[N[nPixels / Length[colourRuns]], {5,1}], " pixels"];

      audioBuffer = Flatten @ Map[
        Function[run,
          StemSynthNote[$imgPalette[[ First[run] ]]["freq"],
            Length[run] * noteDur, 0.8, {1.0, 0.30}, 0.5, sr]
        ],
        colourRuns
      ]
    ];

    ExportAudioBuffer[NormalizeBuffer[audioBuffer, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[nPixels * noteDur]];
    Print[""],


  (* ══════════════════════════════════════════════════════
     HSB MODE  (Rangan 2018)
     Full-colour stereo sonification:
       Left channel:  hue        -> frequency 100-3900 Hz
       Right channel: brightness -> frequency 100-3900 Hz
       Both channels: saturation -> amplitude
     The stereo image encodes two independent spectral
     dimensions simultaneously.
     ══════════════════════════════════════════════════════ *)
  mode === "hsb",

    Print["[3/5] Sonifying (HSB stereo mode)..."];
    STEMSay["Sonifying image in HSB stereo mode"];

    Module[{fLo = 100.0, fHi = 3900.0,
            freqL, freqR, amp,
            leftBuf, rightBuf, snd},

      freqL = fLo + pixHue    * (fHi - fLo);
      freqR = fLo + pixBright * (fHi - fLo);
      amp   = Map[Max[0.10, #] &, pixSat];

      freqAssigned = freqL;

      leftBuf  = NormalizeBuffer[
        Flatten @ Table[StemSynthNote[freqL[[i]], noteDur, amp[[i]], {1.0}, 0.1, sr], {i, nPixels}],
        0.92];
      rightBuf = NormalizeBuffer[
        Flatten @ Table[StemSynthNote[freqR[[i]], noteDur, amp[[i]], {1.0}, 0.1, sr], {i, nPixels}],
        0.92];

      EnsureDir[outWAV];
      snd = Sound[SampledSoundList[{leftBuf, rightBuf}, sr]];
      Export[outWAV, snd, "WAV"]
    ];

    STEMDescribeWAV[outWAV, N[nPixels * noteDur]];
    Print["  Left:  hue        -> freq 100-3900 Hz"];
    Print["  Right: brightness -> freq 100-3900 Hz"];
    Print["  Both:  saturation -> amplitude (min 0.10)"];
    Print[""],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"brightness\", \"colour\", or \"hsb\"."];
    Exit[1]
];


(* ── [4/5] Render traversal animation ──────────────────────────── *)
Print["[4/5] Rendering Hilbert traversal animation..."];
STEMSay["Rendering traversal animation"];

Module[{nGIFFrames = 32, displayData, gCoords, frameUpTo, gifFrames},

  (* Display the image as RGB; Reverse so row 1 (top) is at the top
     of the Raster (Raster origin is bottom-left in Graphics coords). *)
  displayData = Reverse @ ImageData[ColorConvert[processedImg, "RGB"]];

  (* Map {col, row} (1-based; row 1 = top of image) to Graphics
     coordinates where the origin is bottom-left. *)
  gCoords = Map[{#[[1]] - 0.5, imgSize - #[[2]] + 0.5} &, traversal];

  frameUpTo = Table[Max[1, Round[k * nPixels / nGIFFrames]], {k, nGIFFrames}];

  gifFrames = Table[
    With[{upTo = frameUpTo[[k]],
          pathG = gCoords[[1 ;; frameUpTo[[k]]]]},
      Graphics[{
        Raster[displayData, {{0, 0}, {imgSize, imgSize}}],
        {Opacity[0.8], RGBColor[1.0, 0.25, 0.0], Thin, Line[pathG]},
        {Yellow, Disk[Last[pathG], 0.65]}
      },
      PlotRange    -> {{0, imgSize}, {0, imgSize}},
      ImagePadding -> None,
      AspectRatio  -> 1,
      ImageSize    -> 256]
    ],
    {k, nGIFFrames}
  ];

  ExportGIF[gifFrames, outGIF, 10]
];

STEMDescribeGIF[outGIF, 32, 10];
Print[""];


(* ── [5/5] Export CSV and PNG ─────────────────────────────────────── *)
Print["[5/5] Exporting data table and source image..."];

ExportCSV[
  Join[
    {{"hilbert_index", "col", "row", "brightness", "hue", "saturation",
      "frequency_assigned"}},
    Table[
      {i,
       traversal[[i, 1]], traversal[[i, 2]],
       pixBright[[i]], pixHue[[i]], pixSat[[i]],
       freqAssigned[[i]]},
      {i, nPixels}
    ]
  ],
  outCSV
];
STEMDescribeCSV[outCSV, nPixels, 7];

Export[outPNG, processedImg, "PNG"];
Print["  PNG: ", outPNG];
Print[""];


(* ── Done ─────────────────────────────────────────────────────────── *)
STEMHeading["Done"];
STEMSay["Complete. Play audio: " <> STEMPlayCmd[outWAV]]

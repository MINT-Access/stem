(* images/src/animate.wl — Hilbert traversal animation *)

(* Both Animate* below used to export a fixed 32 frames @ 10 fps (3.2s)
   regardless of how long the matching WAV actually plays once its
   spoken intro and per-pixel note buffer are included (measured:
   images_brightness.gif 3.2s vs images_brightness_audio.wav 98.9s --
   31x). targetDuration below is the actual total WAV duration
   (main.wl/experiments.wl build the audio, including its spoken intro,
   before rendering the GIF, so this value is known exactly). nFrames is
   a RENDER BUDGET: frameRate is solved as nFrames/targetDuration then
   clamped to [$ImagesMinGifFps, $ImagesMaxGifFps] so the frame COUNT
   flexes at the clamp boundary, keeping actual playback duration
   exactly targetDuration -- same pattern as lorenz/src/animate.wl's
   ExportAnimation (hydrogen/AnimateOrbital is the same adaptation of
   this same traversal-sweep idiom). *)
$ImagesMinGifFps = 2;
$ImagesMaxGifFps = 30;
$ImagesGifFrameBudget = 150;

ImagesGifRate[targetDuration_?NumericQ, nFrames_:$ImagesGifFrameBudget] :=
  Clip[nFrames / targetDuration, {$ImagesMinGifFps, $ImagesMaxGifFps}];

(* Render a GIF of the Hilbert curve sweeping through the image.
   Each frame shows the path grown to that fraction of the traversal. *)
AnimateImageTraversal[model_Association, outGIF_String, targetDuration_?NumericQ] :=
  Module[{processedImg, imgSize, traversal, nPixels, frameRate, nGIFFrames,
          displayData, gCoords, frameUpTo, gifFrames},
    processedImg = model["img"];
    imgSize      = model["imgSize"];
    traversal    = model["traversal"];
    nPixels      = model["nPixels"];

    (* Row 1 of ImageData is the top of the image; Raster origin is bottom-left.
       Reversing makes the raster match the image's visual orientation. *)
    displayData = Reverse @ ImageData[ColorConvert[processedImg, "RGB"]];

    (* Map {col, row} (1-based, row 1 = top) to Graphics coordinates
       where the bottom-left corner is the origin. *)
    gCoords    = Map[{#[[1]] - 0.5, imgSize - #[[2]] + 0.5} &, traversal];
    frameRate  = ImagesGifRate[targetDuration];
    nGIFFrames = Max[2, Round[frameRate * targetDuration]];
    frameUpTo  = Table[Max[1, Round[k * nPixels / nGIFFrames]], {k, nGIFFrames}];

    gifFrames = Table[
      With[{pathG = gCoords[[1 ;; frameUpTo[[k]]]]},
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

    ExportGIF[gifFrames, outGIF, frameRate];
    {nGIFFrames, frameRate}
  ];

(* Render a GIF of a simple horizontal sweep line moving down the image
   row by row — the pedagogical scan_horizontal mode's counterpart to
   AnimateImageTraversal's Hilbert path, so the visual matches the
   simpler raster traversal this mode sonifies. *)
AnimateRasterScan[model_Association, outGIF_String, targetDuration_?NumericQ] :=
  Module[{processedImg, imgSize, frameRate, nGIFFrames,
          displayData, rowsAt, gifFrames},
    processedImg = model["img"];
    imgSize      = model["imgSize"];

    displayData = Reverse @ ImageData[ColorConvert[processedImg, "RGB"]];
    frameRate  = ImagesGifRate[targetDuration];
    nGIFFrames = Max[2, Round[frameRate * targetDuration]];
    rowsAt = Table[Max[1, Round[k * imgSize / nGIFFrames]], {k, nGIFFrames}];

    gifFrames = Table[
      With[{row = rowsAt[[k]], yPos = imgSize - rowsAt[[k]] + 0.5},
        Graphics[{
          Raster[displayData, {{0, 0}, {imgSize, imgSize}}],
          (* Already-scanned rows, shaded to show progress *)
          {Opacity[0.35], White, Rectangle[{0, imgSize - row}, {imgSize, imgSize}]},
          (* Current scan line *)
          {Opacity[0.9], RGBColor[1.0, 0.25, 0.0], Thick,
           Line[{{0, yPos}, {imgSize, yPos}}]}
        },
        PlotRange    -> {{0, imgSize}, {0, imgSize}},
        ImagePadding -> None,
        AspectRatio  -> 1,
        ImageSize    -> 256]
      ],
      {k, nGIFFrames}
    ];

    ExportGIF[gifFrames, outGIF, frameRate];
    {nGIFFrames, frameRate}
  ];

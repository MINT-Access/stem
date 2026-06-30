(* images/src/animate.wl — Hilbert traversal animation *)

(* Render a 32-frame GIF of the Hilbert curve sweeping through the image.
   Each frame shows the path grown to that fraction of the traversal. *)
AnimateImageTraversal[model_Association, outGIF_String] :=
  Module[{nGIFFrames = 32, processedImg, imgSize, traversal, nPixels,
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
    gCoords   = Map[{#[[1]] - 0.5, imgSize - #[[2]] + 0.5} &, traversal];
    frameUpTo = Table[Max[1, Round[k * nPixels / nGIFFrames]], {k, nGIFFrames}];

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

    ExportGIF[gifFrames, outGIF, 10]
  ];

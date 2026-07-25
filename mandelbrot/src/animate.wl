(* ========================================================
   mandelbrot/src/animate.wl — Rendering and Hilbert-traversal
   animation, reusing images/src/animate.wl's own AnimateImageTraversal
   pattern directly (path grown across the image, frame by frame)

   Colour convention (a rendering choice, not a derived fact, stated
   here for clarity): iteration count is mapped to hue via a smooth HSB
   sweep (fast-escaping = blue/violet, slow-escaping = red/orange), and
   points that never escape within the budget (i.e. "in the set" for
   this app's purposes) are rendered black — the same "interior is
   black" convention essentially every standard Mandelbrot renderer
   uses, adopted here for immediate visual recognisability.
   ======================================================== *)


(* IterationToColor — HSB hue sweep for escaping points, black for
   points at maxIter (treated as non-escaping / in the set). *)
IterationToColor[iter_Integer, maxIter_Integer] :=
  If[iter >= maxIter,
    {0.0, 0.0, 0.0},
    Module[{ratio = N[iter] / N[maxIter]},
      List @@ Hue[0.66 * (1.0 - ratio^0.4), 0.85, 0.95]
    ]
  ];

(* FieldToImage — renders an iteration-count field (in Hilbert-traversal
   order, paired with the traversal's own {col,row} coordinates) as an
   Image, row 1 = bottom (matching images/animate.wl's own Raster
   orientation convention). *)
FieldToImage[iterField_List, traversal_List, size_Integer, maxIter_Integer] :=
  Module[{grid},
    grid = ConstantArray[{0.0, 0.0, 0.0}, {size, size}];
    Do[
      grid[[ size - traversal[[i, 2]] + 1, traversal[[i, 1]] ]] = IterationToColor[iterField[[i]], maxIter],
      {i, Length[traversal]}
    ];
    Image[grid, ColorSpace -> "RGB"]
  ];

(* AnimateFieldTraversal — images/'s AnimateImageTraversal pattern,
   reused directly: a 32-frame GIF of the Hilbert path growing across
   the rendered field. *)
AnimateFieldTraversal[iterField_List, traversal_List, size_Integer, maxIter_Integer,
                      outGIF_String] :=
  Module[{nGIFFrames = 32, img, displayData, gCoords, frameUpTo, gifFrames, nPixels},
    nPixels = Length[traversal];
    img = FieldToImage[iterField, traversal, size, maxIter];
    displayData = Reverse @ ImageData[img];
    gCoords = Map[{#[[1]] - 0.5, size - #[[2]] + 0.5} &, traversal];
    frameUpTo = Table[Max[1, Round[k * nPixels / nGIFFrames]], {k, nGIFFrames}];
    gifFrames = Table[
      With[{pathG = gCoords[[1 ;; frameUpTo[[k]]]]},
        Graphics[{
          Raster[displayData, {{0, 0}, {size, size}}],
          {Opacity[0.8], RGBColor[1.0, 1.0, 1.0], Thin, Line[pathG]},
          {Yellow, Disk[Last[pathG], 0.65]}
        },
        PlotRange -> {{0, size}, {0, size}}, ImagePadding -> None,
        AspectRatio -> 1, ImageSize -> 320]
      ],
      {k, nGIFFrames}
    ];
    ExportGIF[gifFrames, outGIF, 10]
  ];


(* ========================================================
   MODE 1/2: mandelbrot, julia — shared renderer
   ======================================================== *)

AnimateAndExportField[model_Association, outGIF_String, outPNG_String] :=
  Module[{img, size, upscaled},
    AnimateFieldTraversal[model["iterField"], model["traversal"], model["size"], model["maxIter"], outGIF];
    size = model["size"];
    img = FieldToImage[model["iterField"], model["traversal"], size, model["maxIter"]];
    (* Export upscaled via Graphics/Raster (matching the GIF's own
       ImageSize->320 upscaling) -- exporting the raw Image directly
       would write it at its native size x size pixels (e.g. 64x64),
       far too small to view comfortably. *)
    upscaled = Graphics[Raster[Reverse @ ImageData[img], {{0, 0}, {size, size}}],
      PlotRange -> {{0, size}, {0, size}}, ImagePadding -> None,
      AspectRatio -> 1, ImageSize -> 512];
    Export[outPNG, upscaled, "PNG"];
    Print["  PNG: ", outPNG]
  ];


(* ========================================================
   MODE 3: zoom — GIF cycles through levels; PNG shows all levels in a grid
   ======================================================== *)

ZoomLevelLabel[k_Integer, levels_List] :=
  "level " <> ToString[k] <> "  (" <>
  ToString[NumberForm[levels[[k]]["magnification"], {6, 1}]] <> "x)";

ZoomLevelFrame[images_List, levels_List, k_Integer, size_Integer, imgSize_Integer] :=
  Graphics[{Raster[Reverse @ ImageData[images[[k]]], {{0, 0}, {size, size}}],
            Text[Style[ZoomLevelLabel[k, levels], White, 12, Background -> GrayLevel[0, 0.6]],
                 {size / 2.0, size * 0.06}]},
    PlotRange -> {{0, size}, {0, size}}, ImagePadding -> None,
    AspectRatio -> 1, ImageSize -> imgSize];

AnimateZoom[model_Association, outGIF_String, outPNG_String] :=
  Module[{levels, size, maxIter, framesPerLevel = 8, gifFrames, images,
          nLevels, nCols, nRows, panelSize, combined},
    levels = model["levels"]; size = model["size"]; maxIter = model["maxIter"];
    nLevels = Length[levels];

    images = Map[
      FieldToImage[#["iterField"], model["traversal"], size, maxIter] &,
      levels
    ];

    gifFrames = Flatten[Table[
      ZoomLevelFrame[images, levels, k, size, 320],
      {k, nLevels}, {framesPerLevel}
    ], 1];
    ExportGIF[gifFrames, outGIF, 6];

    (* Combined static PNG: all levels side by side in one Graphics
       row (via GraphicsGrid on the same Raster+Text frames the GIF
       already renders correctly), not ImageAssemble/ImageCompose --
       an earlier version using those produced garbled overlaid text,
       caught by viewing the actual rendered PNG during development. *)
    nCols = nLevels; nRows = 1;
    panelSize = 260;
    combined = GraphicsGrid[
      {Table[ZoomLevelFrame[images, levels, k, size, panelSize], {k, nLevels}]},
      Spacings -> 4, Background -> Black, ImageSize -> panelSize * nLevels
    ];
    Export[outPNG, combined, "PNG"];
    Print["  PNG: ", outPNG]
  ];

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


(* Sane bounds on GIF playback frame rate — see AnimateFieldTraversal /
   AnimateZoom for how these keep each animation's playback duration in
   sync with its matching WAV's actual duration (spoken intro + pause +
   sonification) without forcing an absurdly fast frame rate for a
   short render or an implausibly slow one for a long one (see
   AGENTS.md, "GIF/WAV duration sync"). *)
$MinAnimationFps = 2;
$MaxAnimationFps = 30;


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
   reused directly: a GIF of the Hilbert path growing across the
   rendered field.

   targetDuration should be the matching WAV's actual total duration
   (spoken intro + pause + per-pixel note stream, computed just before
   this call — see main.wl/experiments.wl). nFrames is a RENDER
   BUDGET, not a literal frame count: frameRate is solved as
   nFrames/targetDuration and clamped to [$MinAnimationFps,
   $MaxAnimationFps] so a short render doesn't demand a strobing frame
   rate and a long one doesn't demand an implausibly slow one — the
   frame COUNT is what flexes at the clamp boundary (recomputed as
   Round[frameRate * targetDuration]) so actual playback duration
   always equals targetDuration exactly. Returns {actualNFrames,
   frameRate} so callers can report real numbers via STEMDescribeGIF. *)
AnimateFieldTraversal[iterField_List, traversal_List, size_Integer, maxIter_Integer,
                      outGIF_String, targetDuration_?NumericQ, Optional[nFrames_Integer, 150]] :=
  Module[{img, displayData, gCoords, frameUpTo, gifFrames, nPixels, frameRate, actualNFrames},
    nPixels = Length[traversal];

    frameRate = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];

    img = FieldToImage[iterField, traversal, size, maxIter];
    displayData = Reverse @ ImageData[img];
    gCoords = Map[{#[[1]] - 0.5, size - #[[2]] + 0.5} &, traversal];
    frameUpTo = Table[Max[1, Round[k * nPixels / actualNFrames]], {k, actualNFrames}];

    Print["  Rendering ", actualNFrames, " traversal frames at ", FmtN[frameRate, 3],
          " fps (", FmtN[actualNFrames / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];

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
      {k, actualNFrames}
    ];
    ExportGIF[gifFrames, outGIF, frameRate];
    {actualNFrames, frameRate}
  ];


(* ========================================================
   MODE 1/2: mandelbrot, julia — shared renderer
   ======================================================== *)

(* AnimateAndExportField — see AnimateFieldTraversal for the
   targetDuration/nFrames duration-sync contract. Returns
   {actualNFrames, frameRate}. *)
AnimateAndExportField[model_Association, outGIF_String, outPNG_String,
                      targetDuration_?NumericQ, Optional[nFrames_Integer, 150]] :=
  Module[{img, size, upscaled, gifStats},
    gifStats = AnimateFieldTraversal[model["iterField"], model["traversal"], model["size"], model["maxIter"],
                                      outGIF, targetDuration, nFrames];
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
    Print["  PNG: ", outPNG];
    gifStats
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

(* AnimateZoom — GIF cycles through levels, each level held for a
   share of frames proportional to actualNFrames/nLevels. Same
   duration-sync contract as AnimateFieldTraversal (see its docstring):
   targetDuration is the matching WAV's actual total duration, nFrames
   is a render budget clamped to [$MinAnimationFps, $MaxAnimationFps]
   fps. framesPerLevel is distributed via cumulative rounding so the
   per-level counts sum to exactly actualNFrames (every level gets at
   least one frame) and total playback duration equals targetDuration
   exactly. Returns {actualNFrames, frameRate}. *)
AnimateZoom[model_Association, outGIF_String, outPNG_String,
           targetDuration_?NumericQ, Optional[nFrames_Integer, 150]] :=
  Module[{levels, size, maxIter, gifFrames, images,
          nLevels, nCols, nRows, panelSize, combined,
          frameRate, actualNFrames, cumCounts, framesPerLevelList},
    levels = model["levels"]; size = model["size"]; maxIter = model["maxIter"];
    nLevels = Length[levels];

    images = Map[
      FieldToImage[#["iterField"], model["traversal"], size, maxIter] &,
      levels
    ];

    frameRate = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[nLevels, Round[frameRate * targetDuration]];
    cumCounts = Round[Range[0, nLevels] * actualNFrames / nLevels];
    framesPerLevelList = Differences[cumCounts];

    Print["  Rendering ", actualNFrames, " frames across ", nLevels, " levels at ",
          FmtN[frameRate, 3], " fps (", FmtN[actualNFrames / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];

    gifFrames = Flatten[Table[
      ZoomLevelFrame[images, levels, k, size, 320],
      {k, nLevels}, {framesPerLevelList[[k]]}
    ], 1];
    ExportGIF[gifFrames, outGIF, frameRate];

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
    Print["  PNG: ", outPNG];
    {actualNFrames, frameRate}
  ];

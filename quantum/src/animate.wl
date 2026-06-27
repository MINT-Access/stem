(* ========================================================
   quantum/src/animate.wl — Visualisation for quantum density

   Public API:
     AnimateQuantum[solution, cfg, outDir]
       Returns the number of GIF frames written.

   Outputs:
     {mode}_density.gif  — animated |psi(x,t)|^2 (up to 100 frames)
     {mode}_density.png  — 3x3 snapshot grid at equal time intervals
   ======================================================== *)

AnimateQuantum[solution_Association, cfg_Association, outDir_String] :=
  Module[{density, xVals, tVals, nt, mode,
          imgW, imgH, frameRate,
          yMax, xMin, xMax,
          stride, frameIndices, nFrames, frames,
          panel9Indices, panels,
          gifPath, pngPath},

    density   = solution["density"];
    xVals     = solution["x"];
    tVals     = solution["t"];
    nt        = Length[tVals];
    mode      = solution["mode"];

    imgW      = GetCfg[cfg, {"animation","imageWidth"},  600];
    imgH      = GetCfg[cfg, {"animation","imageHeight"}, 300];
    frameRate = GetCfg[cfg, {"animation","frameRate"},   10];

    yMax = Max[density] * 1.1;
    xMin = Min[xVals];
    xMax = Max[xVals];

    (* ── Animated GIF: stride so total frames <= 100 ── *)
    stride       = Max[1, Floor[nt / 100]];
    frameIndices = Range[1, nt, stride];
    nFrames      = Length[frameIndices];

    frames = Map[
      Function[it,
        ListLinePlot[
          Transpose[{xVals, density[[it]]}],
          PlotRange      -> {{xMin, xMax}, {0, yMax}},
          PlotStyle      -> {Thick, RGBColor[0.3, 0.8, 1.0]},
          Background     -> GrayLevel[0.08],
          PlotLabel      -> Style[
            "t = " <> ToString[NumberForm[tVals[[it]], {4, 2}]],
            White, 11],
          AxesStyle      -> White,
          LabelStyle     -> White,
          Frame          -> True,
          FrameStyle     -> White,
          FrameTicks     -> Automatic,
          FrameTicksStyle -> White,
          ImageSize      -> {imgW, imgH}
        ]
      ],
      frameIndices
    ];

    gifPath = FileNameJoin[{outDir, mode <> "_density.gif"}];
    ExportGIF[frames, gifPath, frameRate];
    STEMDescribeGIF[gifPath, nFrames, frameRate];

    (* ── Static 3x3 PNG: 9 frames at equal time intervals ── *)
    panel9Indices = Round[Subdivide[1, nt, 8]];  (* 9 indices: 1..nt *)

    panels = Map[
      Function[it,
        ListLinePlot[
          Transpose[{xVals, density[[it]]}],
          PlotRange  -> {{xMin, xMax}, {0, yMax}},
          PlotStyle  -> {Thick, RGBColor[0.3, 0.8, 1.0]},
          Background -> GrayLevel[0.08],
          PlotLabel  -> Style[
            "t=" <> ToString[NumberForm[tVals[[it]], {3, 1}]],
            White, 9],
          Axes       -> False,
          Frame      -> True,
          FrameStyle -> White,
          FrameTicks -> None,
          ImageSize  -> 200
        ]
      ],
      panel9Indices
    ];

    pngPath = FileNameJoin[{outDir, mode <> "_density.png"}];
    EnsureDir[pngPath];
    Export[pngPath,
      GraphicsGrid[Partition[panels, 3],
        Background -> GrayLevel[0.08],
        ImageSize  -> 600]];
    Print["  Exported PNG: ", pngPath, " — 3x3 snapshot grid"];

    nFrames
  ]

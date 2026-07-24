(* ========================================================
   brownian/src/animate.wl — walk path / ensemble RMS(t) /
   temperature small-multiples visualisation

   walk: a growing path GIF, lorenz/'s progressive-reveal convention
   with a genuine connecting LINE (unlike henon/'s point cloud — a
   random walk's consecutive steps ARE spatially close for small dt,
   since displacement per step is small and diffusive rather than
   chaotically folding, so a line reads correctly here).

   ensemble: r(t) vs t, NOT a 2D spatial plot — a handful of individual
   walkers' own noisy r(t) traced faintly behind the clean ensemble-
   averaged RMS(t) curve (echoing thermo/ensemble's individual-vs-
   aggregate contrast), plus a dashed sqrt(4Dt) reference curve so the
   "shape, not just magnitude" claim is visible directly.

   temperature: a small-multiples panel of representative walks at a
   few temperatures, side by side — the visual echo of the audio's own
   per-temperature-frame structure.
   ======================================================== *)


(* ── walk mode ─────────────────────────────────────────────────── *)

ComputeWalkPlotRange[walkTable_List] :=
  Module[{xs, ys, xpad, ypad},
    xs = walkTable[[All, 2]];
    ys = walkTable[[All, 3]];
    xpad = 0.08 * Max[Max[xs] - Min[xs], 10^-12];
    ypad = 0.08 * Max[Max[ys] - Min[ys], 10^-12];
    {{Min[xs] - xpad, Max[xs] + xpad}, {Min[ys] - ypad, Max[ys] + ypad}}
  ];

RenderWalkFrame[walkTable_List, k_Integer, plotRange_, title_String:""] :=
  Module[{pts, n, segSize, segments, lines, dot},
    pts = walkTable[[1 ;; k, {2, 3}]];
    n = Length[pts];
    segSize = Max[1, Floor[n / 200]];
    segments = Partition[pts, segSize + 1, segSize, {1, 1}];
    lines = MapIndexed[
      {Blend[{RGBColor[0.1, 0.2, 0.8], RGBColor[0.1, 0.7, 0.9],
              RGBColor[1.0, 0.6, 0.1], RGBColor[0.9, 0.1, 0.1]},
             #2[[1]] / Length[segments]],
       Thickness[0.0025], Line[#1]} &,
      segments
    ];
    dot = {White, PointSize[0.016], Point[Last[pts]]};
    Graphics[
      {lines, dot},
      PlotRange -> plotRange,
      AspectRatio -> 1,
      Background -> GrayLevel[0.08],
      ImageSize -> {480, 480},
      Frame -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["x", White, 11], Style["y", White, 11]},
      PlotLabel -> Style[title, White, 10],
      FrameTicks -> None
    ]
  ];

ExportWalkAnimation[walkTable_List, filePath_String, frameRate_:12, nFrames_:100,
                    title_String:"Brownian Walk"] :=
  Module[{plotRange, indices, frames},
    plotRange = ComputeWalkPlotRange[walkTable];
    indices = Round[Subdivide[1, Length[walkTable], nFrames - 1]];
    indices = Max[2, #] & /@ indices;
    Print["  Rendering ", Length[indices], " frames..."];
    frames = RenderWalkFrame[walkTable, #, plotRange, title] & /@ indices;
    ExportGIF[frames, filePath, frameRate]
  ];

ExportWalkPNG[walkTable_List, filePath_String, title_String:"Brownian Walk"] :=
  Module[{plotRange, frame},
    plotRange = ComputeWalkPlotRange[walkTable];
    frame = RenderWalkFrame[walkTable, Length[walkTable], plotRange, title];
    EnsureDir[filePath];
    Export[filePath, frame, "PNG"];
    filePath
  ];


(* ── ensemble mode ─────────────────────────────────────────────── *)

ExportEnsemblePNG[ensembleModel_Association, filePath_String] :=
  Module[{t, rms, samplePaths, D, individualR, theoryCurve,
          individualLines, rmsLine, theoryLine, frame, tMax, rMax},
    t = ensembleModel["t"];
    rms = ensembleModel["rms"];
    samplePaths = ensembleModel["samplePaths"];
    D = ensembleModel["D"];

    individualR = Map[Sqrt[#[[All, 1]]^2 + #[[All, 2]]^2] &, samplePaths];
    theoryCurve = Sqrt[4.0 * D * t];

    tMax = Last[t];
    rMax = 1.15 * Max[Max[rms], Max[Flatten[individualR]], Max[theoryCurve]];

    individualLines = {GrayLevel[0.45], Thin, Line[Transpose[{t, #}]]} & /@ individualR;
    theoryLine = {Dashed, GrayLevel[0.75], Thickness[0.0025], Line[Transpose[{t, theoryCurve}]]};
    rmsLine = {RGBColor[0.2, 0.7, 1.0], Thickness[0.005], Line[Transpose[{t, rms}]]};

    frame = Graphics[
      {individualLines, theoryLine, rmsLine},
      PlotRange -> {{0, tMax}, {0, rMax}},
      AspectRatio -> 0.55,
      Background -> GrayLevel[0.08],
      ImageSize -> {700, 400},
      Frame -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["t (s)", White, 11], Style["r (m)", White, 11]},
      PlotLabel -> Style[
        "Ensemble RMS(t) (blue) vs individual walkers (grey) vs theory sqrt(4Dt) (dashed)",
        White, 9],
      FrameTicks -> True
    ];
    EnsureDir[filePath];
    Export[filePath, frame, "PNG"];
    filePath
  ];


(* ── temperature mode ──────────────────────────────────────────── *)

(* ExportTemperaturePanel — small-multiples panel: one short walk
   snapshot per representative temperature, side by side, sharing a
   common plot range so relative jiggle amplitude is directly
   comparable by eye — the visual echo of the audio's own per-
   temperature-frame structure. *)
ExportTemperaturePanel[tVals_List, walkTables_List, filePath_String] :=
  Module[{allX, allY, xpad, ypad, plotRange, panels, frame},
    allX = Flatten[Map[#[[All, 2]] &, walkTables]];
    allY = Flatten[Map[#[[All, 3]] &, walkTables]];
    xpad = 0.1 * Max[Max[allX] - Min[allX], 10^-12];
    ypad = 0.1 * Max[Max[allY] - Min[allY], 10^-12];
    plotRange = {{Min[allX] - xpad, Max[allX] + xpad}, {Min[allY] - ypad, Max[allY] + ypad}};

    panels = MapThread[
      Function[{T, walkTable},
        Graphics[
          {RGBColor[1.0, 0.6, 0.1], Thickness[0.003], Line[walkTable[[All, {2, 3}]]]},
          PlotRange -> plotRange,
          AspectRatio -> 1,
          Background -> GrayLevel[0.08],
          ImageSize -> {200, 200},
          Frame -> True,
          FrameStyle -> Directive[White, Thin],
          FrameTicks -> None,
          PlotLabel -> Style[FmtN[T, {3, 0}] <> " K", White, 10]
        ]
      ],
      {tVals, walkTables}
    ];

    frame = GraphicsGrid[{panels}, Background -> GrayLevel[0.05], Spacings -> {5, 0}];
    EnsureDir[filePath];
    Export[filePath, frame, "PNG"];
    filePath
  ];

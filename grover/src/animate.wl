(* ========================================================
   grover/src/animate.wl — Visualisations for all three modes

   search: qubit/rabi's curve style, extended with a marked optimal
     point (compton/sweep's own "curve drawn once, marker walks along
     it" idiom for the GIF).

   compare: compton/energy's log-x sweep style, showing classical
     (linear, N/2) and quantum (~Sqrt[N]) query counts diverging as N
     grows, with a moving marker at the app's own configured N.

   geometry: a genuinely different visual — a literal 2D unit-circle
     rotation diagram (not a curve plot), the state vector advancing
     by 2*theta per iteration within the {|w>,|unmarked>} plane.
   ======================================================== *)


(* ========================================================
   MODE 1: search — P(marked) vs iteration, optimum marked
   ======================================================== *)

RenderSearchFrame[model_Association, upTo_Integer] :=
  Module[{kArr, probArr, optimalK, plotRange},
    kArr = model["kArr"]; probArr = model["probArr"]; optimalK = model["optimalK"];
    plotRange = {{0, Last[kArr]}, {0, 1.05}};
    Graphics[
      {
        {RGBColor[0.2, 0.7, 1.0], Thickness[0.003], Line[Transpose[{kArr, probArr}][[1 ;; upTo]]]},
        {Dashed, RGBColor[0.9, 0.7, 0.2], Line[{{optimalK, 0}, {optimalK, 1.05}}]},
        {RGBColor[1.0, 0.6, 0.1], PointSize[0.02], Point[{kArr[[upTo]], probArr[[upTo]]}]},
        Text[Style["optimal k=" <> ToString[optimalK], White, 10, RGBColor[0.9, 0.7, 0.2]],
             {optimalK + 0.3, 0.15}]
      },
      Background -> Black, Frame -> True, FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["Grover iteration k", White, 10], Style["P(marked)", White, 10]},
      PlotLabel  -> Style["Grover Search \[LongDash] rise, then fall past the optimum", White, 12],
      PlotRange  -> plotRange, ImageSize -> {620, 380}, AspectRatio -> 0.5
    ]
  ];

AnimateSearch[model_Association, outGif_String, outPng_String] :=
  Module[{n, indices, frames, kArr, probArr, optimalK, staticPlt},
    n = Length[model["kArr"]];
    indices = Range[1, n];
    frames = RenderSearchFrame[model, #] & /@ indices;
    ExportGIF[frames, outGif, 4];

    kArr = model["kArr"]; probArr = model["probArr"]; optimalK = model["optimalK"];
    staticPlt = Graphics[
      {
        {RGBColor[0.1, 0.4, 0.8], Thickness[0.0032], Line[Transpose[{kArr, probArr}]]},
        {RGBColor[0.15, 0.55, 0.95], PointSize[0.015], Point[Transpose[{kArr, probArr}]]},
        {Dashed, RGBColor[0.8, 0.5, 0.05], Line[{{optimalK, 0}, {optimalK, 1.05}}]},
        Text[Style["optimal k=" <> ToString[optimalK], 11, RGBColor[0.8, 0.5, 0.05]],
             {optimalK + 0.3, 0.15}]
      },
      Background -> White, Frame -> True,
      FrameLabel -> {"Grover iteration k", "P(marked)"},
      PlotLabel  -> Style["Grover Search: P(marked) Rises, Then Falls Past the Optimum", 13, Bold],
      GridLines  -> Automatic,
      PlotRange  -> {{0, Last[kArr]}, {0, 1.05}},
      ImageSize  -> {620, 380}, AspectRatio -> 0.5
    ];
    Export[outPng, staticPlt, "PNG"];
    Print["  PNG: ", outPng];
    Length[frames]
  ];


(* ========================================================
   MODE 2: compare — classical vs quantum query count, log-x sweep
   ======================================================== *)

RenderCompareFrame[model_Association, upTo_Integer] :=
  Module[{logN, classicalArr, quantumArr, plotRange},
    logN = Log10[model["nArr"]];
    classicalArr = Log10[model["classicalArr"]];
    quantumArr   = Log10[model["quantumArr"]];
    plotRange = {{Min[logN], Max[logN]}, {0, Max[classicalArr] * 1.1}};
    Graphics[
      {
        {RGBColor[0.2, 0.4, 0.9], Thickness[0.003], Line[Transpose[{logN, classicalArr}][[1 ;; upTo]]]},
        {RGBColor[0.9, 0.35, 0.1], Thickness[0.003], Line[Transpose[{logN, quantumArr}][[1 ;; upTo]]]},
        {RGBColor[0.4, 0.6, 1.0], PointSize[0.015], Point[{logN[[upTo]], classicalArr[[upTo]]}]},
        {RGBColor[1.0, 0.55, 0.2], PointSize[0.015], Point[{logN[[upTo]], quantumArr[[upTo]]}]},
        Text[Style["classical: N/2", White, 10, RGBColor[0.4, 0.6, 1.0]], {logN[[upTo]] - 1.2, classicalArr[[upTo]] + 0.3}],
        Text[Style["quantum: ~Sqrt[N]", White, 10, RGBColor[1.0, 0.55, 0.2]], {logN[[upTo]] - 1.2, Max[quantumArr[[upTo]] - 0.4, 0.1]}]
      },
      Background -> Black, Frame -> True, FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["log10(N)", White, 10], Style["log10(queries)", White, 10]},
      PlotLabel  -> Style["Classical vs Quantum Search: the Growing Gap", White, 12],
      PlotRange  -> plotRange, ImageSize -> {620, 380}, AspectRatio -> 0.5
    ]
  ];

AnimateCompare[model_Association, outGif_String, outPng_String,
              Optional[nFrames_Integer, 40]] :=
  Module[{nSteps, indices, frames, logN, classicalArr, quantumArr, staticPlt},
    nSteps = Length[model["nArr"]];
    indices = DeleteDuplicates[Round[Subdivide[1, nSteps, Min[nFrames, nSteps] - 1]]];
    frames = RenderCompareFrame[model, #] & /@ indices;
    ExportGIF[frames, outGif, 12];

    logN = Log10[model["nArr"]];
    classicalArr = Log10[model["classicalArr"]];
    quantumArr   = Log10[model["quantumArr"]];
    staticPlt = Graphics[
      {
        {RGBColor[0.1, 0.3, 0.8], Thickness[0.0032], Line[Transpose[{logN, classicalArr}]]},
        {RGBColor[0.85, 0.3, 0.05], Thickness[0.0032], Line[Transpose[{logN, quantumArr}]]},
        Text[Style["classical: N/2 queries", 11, RGBColor[0.1, 0.3, 0.8]], {Max[logN] - 2.0, Max[classicalArr] - 0.3}],
        Text[Style["quantum: ~(\[Pi]/4)*Sqrt[N] queries", 11, RGBColor[0.85, 0.3, 0.05]], {Max[logN] - 2.5, Min[quantumArr] + 1.0}]
      },
      Background -> White, Frame -> True,
      FrameLabel -> {"log10(N)", "log10(queries)"},
      PlotLabel  -> Style["Classical vs Quantum Search: the Growing Gap", 13, Bold],
      GridLines  -> Automatic,
      PlotRange  -> {{Min[logN], Max[logN]}, {0, Max[classicalArr] * 1.1}},
      ImageSize  -> {620, 380}, AspectRatio -> 0.5
    ];
    Export[outPng, staticPlt, "PNG"];
    Print["  PNG: ", outPng];
    Length[frames]
  ];


(* ========================================================
   MODE 3: geometry — literal 2D unit-circle rotation diagram
   ======================================================== *)

RenderGeometryFrame[model_Association, upTo_Integer] :=
  Module[{ampMarkedArr, ampUnmarkedArr, x, y, pathX, pathY, circlePts},
    ampMarkedArr = model["ampMarkedArr"]; ampUnmarkedArr = model["ampUnmarkedArr"];
    x = ampUnmarkedArr[[upTo]]; y = ampMarkedArr[[upTo]];
    pathX = ampUnmarkedArr[[1 ;; upTo]]; pathY = ampMarkedArr[[1 ;; upTo]];
    circlePts = Table[{Cos[t], Sin[t]}, {t, 0.0, 2.0 Pi, 2.0 Pi / 100}];
    Graphics[
      {
        {GrayLevel[0.4], Thickness[0.0015], Line[circlePts]},
        {Gray, Thickness[0.002], Line[{{-1.15, 0}, {1.15, 0}}]},
        {Gray, Thickness[0.002], Line[{{0, -1.15}, {0, 1.15}}]},
        {RGBColor[0.4, 0.7, 1.0], Thickness[0.0025], Dashed, Line[Transpose[{pathX, pathY}]]},
        {RGBColor[1.0, 0.6, 0.1], Thickness[0.006], Arrowheads[0.05], Arrow[{{0, 0}, {x, y}}]},
        Text[Style["|unmarked\[RightAngleBracket]", White, 11], {1.32, -0.08}],
        Text[Style["|w\[RightAngleBracket] (marked)", White, 11], {0.05, 1.28}],
        Text[Style["k=" <> ToString[upTo - 1], White, 12], {-1.0, -1.28}]
      },
      Background -> Black,
      PlotRange -> {{-1.5, 1.5}, {-1.4, 1.4}},
      ImageSize -> {480, 460},
      PlotLabel -> Style["Grover Rotation \[LongDash] the Literal 2D Geometry", White, 13]
    ]
  ];

AnimateGeometry[model_Association, outGif_String, outPng_String] :=
  Module[{n, frames, staticPlt},
    n = Length[model["kArr"]];
    frames = RenderGeometryFrame[model, #] & /@ Range[1, n];
    ExportGIF[frames, outGif, 3];

    staticPlt = RenderGeometryFrame[model, n];
    Export[outPng, staticPlt, "PNG"];
    Print["  PNG: ", outPng];
    Length[frames]
  ];

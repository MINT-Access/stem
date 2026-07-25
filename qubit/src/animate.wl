(* ========================================================
   qubit/src/animate.wl — Bloch sphere path / Rabi curve /
   measurement convergence visualisation

   gates: an actual 3D Bloch sphere (Graphics3D) with the vector's
   continuous rotation path traced on its surface, growing frame by
   frame — lorenz/'s progressive-reveal convention extended to a
   genuine 3D sphere rather than a flat projection, since the whole
   point of a Bloch sphere is that the vector stays ON the sphere
   throughout (check 2's own claim, made visible).

   rabi: P(1)(t) vs t, a single smooth curve.

   measurement: running empirical frequency vs trial number, with a
   dashed reference line at the true |alpha|^2 — bayes/coin's own
   convergence-plot idea, adapted (linear trial axis for simplicity,
   not log).
   ======================================================== *)


(* ── gates mode ────────────────────────────────────────────────────── *)

BlochSphereGraphics3D[pathSegments_, currentPoint_, title_String:""] :=
  Graphics3D[
    {
      {Opacity[0.12], Specularity[White, 10], Sphere[{0, 0, 0}, 1.0]},
      {GrayLevel[0.5], Thin, Line[{{-1.3, 0, 0}, {1.3, 0, 0}}]},
      {GrayLevel[0.5], Thin, Line[{{0, -1.3, 0}, {0, 1.3, 0}}]},
      {GrayLevel[0.5], Thin, Line[{{0, 0, -1.3}, {0, 0, 1.3}}]},
      Text[Style["|0\[RightAngleBracket]", White, 12], {0, 0, 1.15}],
      Text[Style["|1\[RightAngleBracket]", White, 12], {0, 0, -1.15}],
      pathSegments,
      {White, Sphere[currentPoint, 0.05]}
    },
    Boxed -> False, Axes -> False,
    ViewPoint -> {1.6, -2.6, 1.4},
    ImageSize -> {520, 520},
    Background -> GrayLevel[0.08],
    PlotLabel -> Style[title, White, 11]
  ];

RenderGatesFrame[rPath_List, k_Integer, title_String:""] :=
  Module[{pts, n, segSize, segments, lines},
    pts = rPath[[1 ;; k]];
    n = Length[pts];
    segSize = Max[1, Floor[n / 150]];
    segments = Partition[pts, segSize + 1, segSize, {1, 1}];
    lines = MapIndexed[
      {Blend[{RGBColor[0.1, 0.2, 0.8], RGBColor[0.1, 0.7, 0.9],
              RGBColor[1.0, 0.6, 0.1], RGBColor[0.9, 0.1, 0.1]},
             #2[[1]] / Max[Length[segments], 1]],
       Thickness[0.006], Line[#1]} &,
      segments
    ];
    BlochSphereGraphics3D[lines, Last[pts], title]
  ];

ExportGatesAnimation[rPath_List, filePath_String, frameRate_:10, nFrames_:80,
                     title_String:"Qubit Gate Sequence"] :=
  Module[{indices, frames},
    indices = Round[Subdivide[1, Length[rPath], nFrames - 1]];
    indices = Max[2, #] & /@ indices;
    Print["  Rendering ", Length[indices], " frames..."];
    frames = RenderGatesFrame[rPath, #, title] & /@ indices;
    ExportGIF[frames, filePath, frameRate]
  ];

ExportGatesPNG[rPath_List, filePath_String, title_String:"Qubit Gate Sequence"] :=
  Module[{frame},
    frame = RenderGatesFrame[rPath, Length[rPath], title];
    EnsureDir[filePath];
    Export[filePath, frame, "PNG"];
    filePath
  ];


(* ── rabi mode ─────────────────────────────────────────────────────── *)

ExportRabiPNG[tVals_List, p1Vals_List, Omega_?NumericQ, filePath_String] :=
  Module[{plotRange, curve, frame},
    plotRange = {{0, Last[tVals]}, {0, 1.05}};
    curve = {RGBColor[0.2, 0.7, 1.0], Thickness[0.004], Line[Transpose[{tVals, p1Vals}]]};
    frame = Graphics[
      {curve},
      PlotRange -> plotRange,
      AspectRatio -> 0.45,
      Background -> GrayLevel[0.08],
      ImageSize -> {700, 340},
      Frame -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["t", White, 11], Style["P(1)", White, 11]},
      PlotLabel -> Style["Rabi oscillation, \[CapitalOmega] = " <> ToString[NumberForm[Omega, {3, 2}]], White, 10],
      FrameTicks -> True
    ];
    EnsureDir[filePath];
    Export[filePath, frame, "PNG"];
    filePath
  ];


(* ── measurement mode ─────────────────────────────────────────────── *)

ExportMeasurementPNG[trialsResult_Association, filePath_String] :=
  Module[{n, trials, runningFreq, p0True, plotRange, curve, refLine, frame},
    n = trialsResult["nTrials"];
    trials = N[Range[n]];
    runningFreq = trialsResult["runningFreq0"];
    p0True = trialsResult["trueP0"];
    plotRange = {{1, n}, {0, 1}};
    curve = {RGBColor[0.2, 0.9, 0.5], Thickness[0.0025], Line[Transpose[{trials, runningFreq}]]};
    refLine = {Dashed, White, Thickness[0.002], Line[{{1, p0True}, {n, p0True}}]};
    frame = Graphics[
      {curve, refLine},
      PlotRange -> plotRange,
      AspectRatio -> 0.45,
      Background -> GrayLevel[0.08],
      ImageSize -> {700, 340},
      Frame -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["trial", White, 11], Style["running P(0)", White, 11]},
      PlotLabel -> Style[
        "Empirical P(0) converging to |\[Alpha]|^2 = " <>
        ToString[NumberForm[p0True, {3, 3}]] <> " (dashed)", White, 10],
      FrameTicks -> True
    ];
    EnsureDir[filePath];
    Export[filePath, frame, "PNG"];
    filePath
  ];

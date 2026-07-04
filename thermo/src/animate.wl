(* ========================================================
   thermo/src/animate.wl — GIF animations for all four modes
   ======================================================== *)


(* ── Mode 1: distribution ─────────────────────────────────────────── *)

RenderDistributionFrame[T_?NumericQ, massAmu_?NumericQ, TStart_?NumericQ, TEnd_?NumericQ,
                        vGlobalMax_?NumericQ] :=
  Module[{vs, fs, vp, vmean, vrms, colorFrac, curveColor, yMax},
    vs  = (N[Range[0, 200]] / 200) * vGlobalMax;
    fs  = MBDensity[#, massAmu, T] & /@ vs;
    yMax = Max[fs] * 1.15;
    vp    = MostProbableSpeed[massAmu, T];
    vmean = MeanSpeed[massAmu, T];
    vrms  = RMSSpeed[massAmu, T];
    colorFrac  = Clip[(T - TStart) / (TEnd - TStart), {0.0, 1.0}];
    curveColor = Blend[{RGBColor[0.2, 0.4, 0.9], RGBColor[0.95, 0.25, 0.2]}, colorFrac];

    Graphics[
      {
        {curveColor, Thickness[0.005], Line[Transpose[{vs, fs}]]},
        {Dashed, RGBColor[0.3, 0.6, 1.0],  Line[{{vp,    0}, {vp,    yMax}}]},
        {Dashed, RGBColor[0.3, 0.9, 0.3],  Line[{{vmean, 0}, {vmean, yMax}}]},
        {Dashed, RGBColor[0.95, 0.3, 0.3], Line[{{vrms,  0}, {vrms,  yMax}}]}
      },
      PlotRange  -> {{0, vGlobalMax}, {0, yMax}},
      Background -> Black,
      ImageSize  -> {600, 400},
      Frame      -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["speed v (m/s)", White, 11], Style["f(v)", White, 11]},
      PlotLabel  -> Style["Maxwell-Boltzmann Distribution \[LongDash] T = " <>
                           ToString[Round[T]] <> " K", White, 12],
      Axes       -> False
    ]
  ];

AnimateDistribution[distResult_Association, massAmu_?NumericQ, TEndFull_?NumericQ,
                    outGIF_String, Optional[nFrames_Integer, 60]] :=
  Module[{TVals, TStart, TEnd, indices, vGlobalMax, frames},
    TVals  = distResult["TVals"];
    TStart = First[TVals];
    TEnd   = Last[TVals];
    indices    = DeleteDuplicates[Round[Subdivide[1, Length[TVals], Min[nFrames, Length[TVals]] - 1]]];
    vGlobalMax = MaxSpeed[massAmu, TEndFull];

    Print["  Rendering ", Length[indices], " distribution frames..."];
    frames = RenderDistributionFrame[TVals[[#]], massAmu, TStart, TEnd, vGlobalMax] & /@ indices;
    ExportGIF[frames, outGIF, 12];
    Length[frames]
  ];


(* ── Mode 2: ensemble ─────────────────────────────────────────────── *)

RenderEnsembleFrame[speeds_List, massAmu_?NumericQ, T_?NumericQ, vGlobalMax_?NumericQ,
                    stepIdx_Integer] :=
  Module[{nBins = 15, binWidth, analyticVs, analyticCounts, meanSpeed},
    binWidth       = vGlobalMax / nBins;
    meanSpeed      = Mean[speeds];
    analyticVs     = (N[Range[0, 100]] / 100) * vGlobalMax;
    analyticCounts = (MBDensity[#, massAmu, T] & /@ analyticVs) * Length[speeds] * binWidth;

    Show[
      Histogram[speeds, {0, vGlobalMax, binWidth}, "Count",
        ChartStyle -> RGBColor[0.2, 0.7, 0.9],
        PlotRange  -> {{0, vGlobalMax}, {0, Automatic}},
        Background -> Black,
        ImageSize  -> {600, 400},
        Frame      -> True,
        FrameStyle -> Directive[White, Thin],
        FrameLabel -> {Style["speed (m/s)", White, 11], Style["count", White, 11]},
        PlotLabel  -> Style["Ensemble \[LongDash] step " <> ToString[stepIdx] <> ",  T = " <>
                             ToString[Round[T]] <> " K,  mean = " <> ToString[Round[meanSpeed]] <>
                             " m/s", White, 11]
      ],
      ListLinePlot[Transpose[{analyticVs, analyticCounts}],
        PlotStyle -> {RGBColor[1.0, 0.6, 0.1], Thickness[0.005]}]
    ]
  ];

AnimateEnsemble[ensembleModel_Association, outGIF_String, Optional[nFrames_Integer, 60]] :=
  Module[{history, massAmu, T, vGlobalMax, nSteps, indices, frames},
    history    = ensembleModel["speedsHistory"];
    massAmu    = ensembleModel["massAmu"];
    T          = ensembleModel["T"];
    vGlobalMax = MaxSpeed[massAmu, T] * 1.3;   (* headroom for outlier speeds *)
    nSteps     = Length[history];
    indices    = DeleteDuplicates[Round[Subdivide[1, nSteps, Min[nFrames, nSteps] - 1]]];

    Print["  Rendering ", Length[indices], " ensemble histogram frames..."];
    frames = RenderEnsembleFrame[history[[#]], massAmu, T, vGlobalMax, # - 1] & /@ indices;
    ExportGIF[frames, outGIF, 10];
    Length[frames]
  ];


(* ── Mode 3: cooling ──────────────────────────────────────────────── *)

RenderCoolingFrame[t_?NumericQ, T_?NumericQ, THot_?NumericQ, TCold_?NumericQ, tau_?NumericQ,
                   duration_?NumericQ, massAmu_?NumericQ, vGlobalMax_?NumericQ] :=
  Module[{tVals, TCurve, topPlot, vs, fs, bottomPlot},
    tVals  = (N[Range[0, 100]] / 100) * duration;
    TCurve = CoolingTemperature[#, THot, TCold, tau] & /@ tVals;

    topPlot = Graphics[
      {
        {RGBColor[0.9, 0.5, 0.2], Thickness[0.004], Line[Transpose[{tVals, TCurve}]]},
        {Yellow, PointSize[0.025], Point[{t, T}]}
      },
      PlotRange  -> {{0, duration}, {TCold * 0.8, THot * 1.05}},
      Background -> Black,
      ImageSize  -> {600, 220},
      Frame      -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["time (s)", White, 10], Style["T (K)", White, 10]},
      PlotLabel  -> Style["Cooling: T = " <> ToString[Round[T]] <> " K", White, 12]
    ];

    vs = (N[Range[0, 200]] / 200) * vGlobalMax;
    fs = MBDensity[#, massAmu, T] & /@ vs;
    bottomPlot = Graphics[
      {
        {Blend[{RGBColor[0.95, 0.3, 0.2], RGBColor[0.3, 0.5, 0.9]}, Clip[T / THot, {0, 1}]],
         Thickness[0.004], Line[Transpose[{vs, fs}]]}
      },
      PlotRange  -> {{0, vGlobalMax}, {0, Automatic}},
      Background -> Black,
      ImageSize  -> {600, 220},
      Frame      -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["speed v (m/s)", White, 10], Style["f(v)", White, 10]}
    ];

    GraphicsColumn[{topPlot, bottomPlot}, Background -> Black, Spacings -> 0.5]
  ];

AnimateCooling[coolResult_Association, massAmu_?NumericQ, outGIF_String,
              Optional[nFrames_Integer, 60]] :=
  Module[{times, TVals, THot, TCold, tau, duration, vGlobalMax, nSteps, indices, frames},
    times    = coolResult["times"];
    TVals    = coolResult["TVals"];
    THot     = coolResult["THot"];
    TCold    = coolResult["TCold"];
    tau      = coolResult["tau"];
    duration = Last[times] + coolResult["frameDuration"];
    vGlobalMax = MaxSpeed[massAmu, THot];
    nSteps     = Length[times];
    indices    = DeleteDuplicates[Round[Subdivide[1, nSteps, Min[nFrames, nSteps] - 1]]];

    Print["  Rendering ", Length[indices], " cooling frames..."];
    frames = RenderCoolingFrame[times[[#]], TVals[[#]], THot, TCold, tau, duration,
                                massAmu, vGlobalMax] & /@ indices;
    ExportGIF[frames, outGIF, 10];
    Length[frames]
  ];


(* ── Mode 4: equipartition ────────────────────────────────────────── *)

(* Always shows the fixed monatomic-vs-diatomic archetype comparison
   (100% translational vs 60/40 translational/rotational at room
   temperature), regardless of which molecule type the audio is
   currently sonifying — the point of this panel is the comparison
   itself. Room-temperature 60/40 split does not vary with T here
   (vibrational-mode onset at very high T is an explicitly optional
   "bonus" per the build spec; not implemented — see AGENTS.md). *)
RenderEquipartitionFrame[T_?NumericQ] :=
  Module[{diatomicRotFrac, monoChart, diChart},
    diatomicRotFrac = RotationalFraction[300.0, "diatomic"];

    monoChart = PieChart[{1.0},
      ChartLabels -> {"Translational 100%"},
      ChartStyle  -> {RGBColor[0.25, 0.55, 0.95]},
      PlotLabel   -> Style["Monatomic (He, Ar) \[LongDash] T=" <> ToString[Round[T]] <> "K",
                            White, 11],
      Background  -> Black, ImageSize -> {300, 300}
    ];
    diChart = PieChart[{1.0 - diatomicRotFrac, diatomicRotFrac},
      ChartLabels -> {"Translational " <> ToString[Round[(1.0 - diatomicRotFrac) * 100]] <> "%",
                      "Rotational " <> ToString[Round[diatomicRotFrac * 100]] <> "%"},
      ChartStyle  -> {RGBColor[0.25, 0.55, 0.95], RGBColor[0.95, 0.55, 0.15]},
      PlotLabel   -> Style["Diatomic (N2, O2) \[LongDash] T=" <> ToString[Round[T]] <> "K",
                            White, 11],
      Background  -> Black, ImageSize -> {300, 300}
    ];
    GraphicsRow[{monoChart, diChart}, Background -> Black, ImageSize -> 640]
  ];

AnimateEquipartition[eqResult_Association, outGIF_String, Optional[nFrames_Integer, 30]] :=
  Module[{TVals, nSteps, indices, frames},
    TVals   = eqResult["TVals"];
    nSteps  = Length[TVals];
    indices = DeleteDuplicates[Round[Subdivide[1, nSteps, Min[nFrames, nSteps] - 1]]];

    Print["  Rendering ", Length[indices], " equipartition frames..."];
    frames = RenderEquipartitionFrame[TVals[[#]]] & /@ indices;
    ExportGIF[frames, outGIF, 8];
    Length[frames]
  ];

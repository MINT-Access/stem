(* ========================================================
   blackbody/src/animate.wl — GIF/PNG rendering for all three modes

   All curves are plotted as relative spectral radiance (each curve
   normalised so its own peak = 1.0) against log10(frequency/Hz) --
   the physical radiance values span many orders of magnitude across
   this app's temperature range, so an un-normalised y-axis would make
   most curves look like flat lines next to the hottest one.

   Peak markers and "Peak" labelling follow the convention established
   in cosmology/src/animate.wl's CMB spectrum PNG (red dot + text label
   at each marked feature); GIF colour/background conventions follow
   thermo/src/animate.wl (black background, blue->red colour blend
   tracking the swept parameter).

   GIF playback duration is driven by targetDuration — the actual WAV
   length (spoken intro/outro + chord/sweep/segments, N[Length[
   finalLeft]]/sr from main.wl), not a fixed frame count/rate — so the
   animation and its sonification stay in sync. nFrames is a RENDER
   BUDGET, not a literal frame count: frameRate is solved as
   nFrames/targetDuration and clamped to [$MinAnimationFps,
   $MaxAnimationFps] (2-30 fps), then the actual frame count is
   recomputed from the clamped rate so playback duration always equals
   targetDuration exactly. See lorenz/src/animate.wl's ExportAnimation
   for the reference version of this pattern.
   ======================================================== *)

$MinAnimationFps = 2;
$MaxAnimationFps = 30;


(* ── Shared curve helpers ─────────────────────────────────────────── *)

NormalizedCurvePoints[T_?NumericQ, nuMin_?NumericQ, nuMax_?NumericQ,
                     Optional[nPoints_Integer, 300]] :=
  Module[{nus, bs, bmax},
    nus  = Table[nuMin * (nuMax / nuMin)^(N[i] / nPoints), {i, 0, nPoints}];
    bs   = Quiet[PlanckRadianceFreq[#, T] & /@ nus, General::munfl];
    bmax = Max[bs];
    If[bmax <= 0.0, bmax = 1.0];
    <| "nu" -> nus, "logNu" -> Log10[nus], "B" -> bs / bmax |>
  ];

(* FormatKelvinShort — compact temperature label for plot annotations,
   e.g. "23.0kK" rather than "22974K" (which crowds label rows). *)
FormatKelvinShort[T_?NumericQ] :=
  If[T >= 1000.0,
    ToString[Round[T / 1000.0, 0.1]] <> "kK",
    ToString[Round[T]] <> "K"
  ];

VisibleBandShading[] :=
  {Opacity[0.22], RGBColor[0.85, 0.85, 0.15],
   Rectangle[{Log10[$VisibleFreqLo], 0}, {Log10[$VisibleFreqHi], 1.08}]};

PeakMarkerGraphics[T_?NumericQ, nuMin_?NumericQ, nuMax_?NumericQ, label_String,
                   Optional[color_, Red], Optional[labelRow_Integer, 0]] :=
  Module[{peakNu, logPeak, labelY},
    peakNu = Clip[PeakFrequencyFromWavelength[T], {nuMin, nuMax}];
    logPeak = Log10[peakNu];
    labelY  = 1.05 + 0.16 * labelRow;
    {
      {color, PointSize[0.016], Point[{logPeak, 1.03}]},
      Text[Style[label, 7, color], {logPeak, labelY}]
    }
  ];


(* ── Mode 1: spectrum (and star, single preset) ──────────────────── *)

RenderSpectrumStaticPNG[T_?NumericQ, nuMin_?NumericQ, nuMax_?NumericQ, outPNG_String] :=
  Module[{pts, plt},
    pts = NormalizedCurvePoints[T, nuMin, nuMax];
    plt = Graphics[
      {
        {RGBColor[0.18, 0.42, 0.78], Thickness[0.0022], Line[Transpose[{pts["logNu"], pts["B"]}]]},
        VisibleBandShading[],
        PeakMarkerGraphics[T, nuMin, nuMax, "Peak"]
      },
      PlotRange  -> {{Log10[nuMin], Log10[nuMax]}, {0, 1.25}},
      Frame      -> True,
      FrameLabel -> {"log\!\(\*SubscriptBox[\(10\),\(\)]\)(frequency / Hz)", "relative spectral radiance"},
      PlotLabel  -> Style["Planck Black Body Spectrum \[LongDash] T = " <> ToString[Round[T]] <> " K", 13, Bold],
      GridLines  -> Automatic,
      Background -> White,
      ImageSize  -> {600, 360}
    ];
    Export[outPNG, plt, "PNG"];
    Print["  PNG: ", outPNG]
  ];

RenderSpectrumSweepFrame[T_?NumericQ, nuMin_?NumericQ, nuMax_?NumericQ,
                        spec_Association, k_Integer] :=
  Module[{pts, curveColor, currentLogNu, currentAmp},
    pts        = NormalizedCurvePoints[T, nuMin, nuMax];
    curveColor = Blend[{RGBColor[0.2, 0.4, 0.9], RGBColor[0.95, 0.25, 0.2]}, N[k] / spec["nBins"]];
    currentLogNu = Log10[spec["nuBins"][[k]]];
    currentAmp   = spec["amps"][[k]];

    Graphics[
      {
        {Gray, Thickness[0.0018], Line[Transpose[{pts["logNu"], pts["B"]}]]},
        VisibleBandShading[],
        {Dashed, White, Thin, Line[{{currentLogNu, 0}, {currentLogNu, 1.05}}]},
        {curveColor, PointSize[0.03], Point[{currentLogNu, currentAmp}]}
      },
      PlotRange  -> {{Log10[nuMin], Log10[nuMax]}, {0, 1.15}},
      Background -> Black,
      Frame      -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["log10(frequency / Hz)", White, 10], Style["relative radiance", White, 10]},
      PlotLabel  -> Style["Spectrum sweep \[LongDash] bin " <> ToString[k] <> "/" <> ToString[spec["nBins"]], White, 11],
      ImageSize  -> {600, 400}
    ]
  ];

AnimateSpectrum[T_?NumericQ, spec_Association, nuMin_?NumericQ, nuMax_?NumericQ,
               outGIF_String, outPNG_String, targetDuration_?NumericQ,
               Optional[nFrames_Integer, 150]] :=
  Module[{nBins, frameRate, actualNFrames, indices, frames},
    nBins         = spec["nBins"];
    frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];
    indices       = Clip[Round[Subdivide[1, nBins, actualNFrames - 1]], {1, nBins}];
    Print["  Rendering ", Length[indices], " spectrum sweep frames at ", FmtN[frameRate, 3],
          " fps (", FmtN[Length[indices] / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];
    frames = RenderSpectrumSweepFrame[T, nuMin, nuMax, spec, #] & /@ indices;
    ExportGIF[frames, outGIF, frameRate];
    RenderSpectrumStaticPNG[T, nuMin, nuMax, outPNG];
    {Length[frames], frameRate}
  ];


(* ── Mode 2: temperature ──────────────────────────────────────────── *)

RenderTemperatureFrame[T_?NumericQ, Tmin_?NumericQ, Tmax_?NumericQ,
                       nuMin_?NumericQ, nuMax_?NumericQ] :=
  Module[{pts, colorFrac, curveColor},
    pts = NormalizedCurvePoints[T, nuMin, nuMax];
    colorFrac  = Clip[(Log[T] - Log[Tmin]) / (Log[Tmax] - Log[Tmin]), {0.0, 1.0}];
    curveColor = Blend[{RGBColor[0.85, 0.15, 0.1], RGBColor[0.2, 0.4, 0.95]}, colorFrac];

    Graphics[
      {
        {curveColor, Thickness[0.005], Line[Transpose[{pts["logNu"], pts["B"]}]]},
        VisibleBandShading[],
        PeakMarkerGraphics[T, nuMin, nuMax, "Peak"]
      },
      PlotRange  -> {{Log10[nuMin], Log10[nuMax]}, {0, 1.25}},
      Background -> Black,
      Frame      -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["log10(frequency / Hz)", White, 11], Style["relative radiance", White, 11]},
      PlotLabel  -> Style["Black Body Spectrum \[LongDash] T = " <> ToString[Round[T]] <> " K", White, 12]
    ]
  ];

AnimateTemperature[tempResult_Association, nuMin_?NumericQ, nuMax_?NumericQ,
                   outGIF_String, targetDuration_?NumericQ, Optional[nFrames_Integer, 150]] :=
  Module[{TVals, Tmin, Tmax, nSteps, frameRate, actualNFrames, indices, frames},
    TVals         = tempResult["TVals"];
    Tmin          = First[TVals]; Tmax = Last[TVals];
    nSteps        = Length[TVals];
    frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];
    indices       = Clip[Round[Subdivide[1, nSteps, actualNFrames - 1]], {1, nSteps}];

    Print["  Rendering ", Length[indices], " temperature-sweep frames at ", FmtN[frameRate, 3],
          " fps (", FmtN[Length[indices] / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];
    frames = RenderTemperatureFrame[TVals[[#]], Tmin, Tmax, nuMin, nuMax] & /@ indices;
    ExportGIF[frames, outGIF, frameRate];
    {Length[frames], frameRate}
  ];

RenderTemperatureStaticPNG[Tmin_?NumericQ, Tmax_?NumericQ, nuMin_?NumericQ, nuMax_?NumericQ,
                           outPNG_String, Optional[nCurves_Integer, 6]] :=
  Module[{Ts, curves, plt},
    (* Log-spaced, not linear: the peak frequency scales with T, so
       linearly-spaced T samples bunch their peaks together at the hot
       end in log-frequency space -- log-spacing keeps the curves and
       their peak labels visually separated across the plot. *)
    Ts = Table[Tmin * (Tmax / Tmin)^(N[i] / (nCurves - 1)), {i, 0, nCurves - 1}];
    curves = MapIndexed[
      Function[{T, idx},
        Module[{pts, colorFrac, curveColor},
          pts = NormalizedCurvePoints[T, nuMin, nuMax];
          colorFrac  = Clip[(Log[T] - Log[Tmin]) / (Log[Tmax] - Log[Tmin]), {0.0, 1.0}];
          curveColor = Blend[{RGBColor[0.85, 0.15, 0.1], RGBColor[0.1, 0.25, 0.85]}, colorFrac];
          {
            {curveColor, Thickness[0.0025], Line[Transpose[{pts["logNu"], pts["B"]}]]},
            PeakMarkerGraphics[T, nuMin, nuMax, FormatKelvinShort[T], curveColor, First[idx] - 1]
          }
        ]
      ],
      Ts
    ];

    plt = Graphics[
      Flatten[{VisibleBandShading[], curves}, 1],
      PlotRange  -> {{Log10[nuMin], Log10[nuMax]}, {0, 1.1 + 0.16 * nCurves}},
      Frame      -> True,
      FrameLabel -> {"log\!\(\*SubscriptBox[\(10\),\(\)]\)(frequency / Hz)", "relative spectral radiance"},
      PlotLabel  -> Style["Wien's Law: Peak Shift with Temperature (" <>
                          ToString[Round[Tmin]] <> "K \[LongDash] " <> ToString[Round[Tmax]] <> "K)", 13, Bold],
      GridLines  -> Automatic,
      Background -> White,
      ImageSize  -> {620, 380 + 14 * nCurves}
    ];
    Export[outPNG, plt, "PNG"];
    Print["  PNG: ", outPNG]
  ];


(* ── Mode 3: star ─────────────────────────────────────────────────── *)

(* Single-preset star runs reuse AnimateSpectrum/RenderSpectrumStaticPNG
   directly (main.wl calls those, not a separate function here). The
   functions below are for preset="all" only. *)

RenderStarTourFrame[order_List, presets_Association, upTo_Integer,
                    nuMin_?NumericQ, nuMax_?NumericQ] :=
  Module[{shownKeys, currentKey, currentT, faded, current},
    shownKeys  = order[[1 ;; upTo]];
    currentKey = Last[shownKeys];
    currentT   = presets[currentKey];

    faded = Map[
      Function[key,
        With[{pts = NormalizedCurvePoints[presets[key], nuMin, nuMax]},
          {Gray, Opacity[0.35], Thickness[0.0018], Line[Transpose[{pts["logNu"], pts["B"]}]]}
        ]
      ],
      shownKeys[[1 ;; -2]]
    ];

    current = With[{pts = NormalizedCurvePoints[currentT, nuMin, nuMax]},
      {
        {RGBColor[0.95, 0.7, 0.15], Thickness[0.005], Line[Transpose[{pts["logNu"], pts["B"]}]]},
        PeakMarkerGraphics[currentT, nuMin, nuMax, StarDisplayName[currentKey], Yellow]
      }
    ];

    Graphics[
      Flatten[{VisibleBandShading[], faded, current}, 1],
      PlotRange  -> {{Log10[nuMin], Log10[nuMax]}, {0, 1.3}},
      Background -> Black,
      Frame      -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["log10(frequency / Hz)", White, 11], Style["relative radiance", White, 11]},
      PlotLabel  -> Style[StarDisplayName[currentKey] <> " \[LongDash] " <>
                          ToString[Round[currentT]] <> " K", White, 12],
      ImageSize  -> {620, 400}
    ]
  ];

(* Each star's reveal (order[[1;;k]], faded trail + current highlighted)
   is a discrete step, one per star, not a continuous quantity to
   subsample directly -- same situation as asteroids/src/animate.wl's
   per-asteroid reveal. actualNFrames splits into a reveal phase (evenly
   sampling the n stars, naturally repeating a star across consecutive
   frames when the budget exceeds n) and a holdFrac share holding the
   final, fully-revealed frame. *)
AnimateStarTour[order_List, presets_Association, nuMin_?NumericQ, nuMax_?NumericQ,
                outGIF_String, targetDuration_?NumericQ, Optional[nFrames_Integer, 150],
                Optional[holdFrac_?NumericQ, 0.15]] :=
  Module[{n, frameRate, actualNFrames, holdCount, revealCount, revealIndices, frames},
    n = Length[order];

    frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];
    holdCount     = Max[1, Round[actualNFrames * holdFrac]];
    revealCount   = Max[1, actualNFrames - holdCount];
    revealIndices = If[revealCount <= 1, {n},
      Clip[Round[Subdivide[1, n, revealCount - 1]], {1, n}]];

    Print["  Rendering ", actualNFrames, " star-tour frames (", Length[revealIndices],
          " reveal + ", holdCount, " hold) at ", FmtN[frameRate, 3],
          " fps (", FmtN[actualNFrames / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];

    frames = RenderStarTourFrame[order, presets, #, nuMin, nuMax] & /@ revealIndices;
    frames = Join[frames, ConstantArray[Last[frames], holdCount]];
    ExportGIF[frames, outGIF, frameRate];
    {Length[frames], frameRate}
  ];

RenderStarTourStaticPNG[order_List, presets_Association, nuMin_?NumericQ, nuMax_?NumericQ,
                        outPNG_String] :=
  Module[{colors, curves, plt},
    colors = AssociationThread[order,
      Table[Blend[{RGBColor[0.85, 0.15, 0.1], RGBColor[0.1, 0.25, 0.85]}, N[i - 1] / (Length[order] - 1)],
            {i, Length[order]}]];
    curves = MapIndexed[
      Function[{key, idx},
        With[{T = presets[key], pts = NormalizedCurvePoints[presets[key], nuMin, nuMax]},
          {
            {colors[key], Thickness[0.0025], Line[Transpose[{pts["logNu"], pts["B"]}]]},
            PeakMarkerGraphics[T, nuMin, nuMax, StarShortName[key], colors[key], First[idx] - 1]
          }
        ]
      ],
      order
    ];

    plt = Graphics[
      Flatten[{VisibleBandShading[], curves}, 1],
      PlotRange  -> {{Log10[nuMin], Log10[nuMax]}, {0, 1.1 + 0.16 * Length[order]}},
      Frame      -> True,
      FrameLabel -> {"log\!\(\*SubscriptBox[\(10\),\(\)]\)(frequency / Hz)", "relative spectral radiance"},
      PlotLabel  -> Style["Six Black Bodies, Red Dwarf to White Dwarf", 13, Bold],
      GridLines  -> Automatic,
      Background -> White,
      ImageSize  -> {640, 400 + 14 * Length[order]}
    ];
    Export[outPNG, plt, "PNG"];
    Print["  PNG: ", outPNG]
  ];

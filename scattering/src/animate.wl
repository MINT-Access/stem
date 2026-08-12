(* ========================================================
   scattering/src/animate.wl — GIF rendering for all three modes

   Public API:
     AnimateScatter[model, outGif, targetDuration]      -> {nFrames, fps}
     AnimateDistribution[model, outGif, targetDuration] -> {nFrames, fps}
     AnimateDiscovery[model, outGif, targetDuration]    -> {nFrames, fps}

   targetDuration is the GIF's intended PLAYBACK length in seconds --
   callers pass the same "main content" duration basis (see
   ScatterMainDuration / DistributionMainDuration / DiscoveryMainDuration
   in sonify.wl) used to size the matching WAV's main buffer, so the
   animation and its sonification play for the same length instead of
   the GIF racing through a fixed 40-frame/15-fps count in ~2.7s while
   the audio (main content plus spoken intro/outro) runs many times
   longer.

   $ScatFrameBudget is a RENDER BUDGET, not a literal frame count: the
   frame rate is solved as budget/targetDuration and clamped to
   [$ScatMinFps, $ScatMaxFps] so a very short trajectory doesn't demand
   a strobing frame rate and a very long one doesn't demand an
   implausibly slow one -- the frame COUNT is what flexes at the clamp
   boundary (recomputed as Round[fps * targetDuration]) so actual
   playback duration always equals targetDuration exactly. *)

$ScatFrameBudget = 150;
$ScatMinFps      = 2;
$ScatMaxFps      = 30;

ScatAnimationRate[targetDuration_?NumericQ] :=
  Clip[$ScatFrameBudget / targetDuration, {$ScatMinFps, $ScatMaxFps}]


(* ========================================================
   SCATTER MODE — 2D hyperbolic trajectory around the nucleus
   ======================================================== *)

AnimateScatter[model_Association, outGif_String, targetDuration_?NumericQ] :=
  Module[{
    xArr, yArr, speedArr, nPts, nFrames, frameRate, speedMin, speedMax,
    vInitHat, vFinalHat, p0, pf, extend, footPoint,
    incomingA, incomingB, outgoingA, outgoingB,
    angle1, angle2, arcR, plotHalfRange, thetaDeg, frames
  },
    xArr = model["x"]; yArr = model["y"]; speedArr = model["speed"];
    nPts = Length[xArr];
    frameRate = ScatAnimationRate[targetDuration];
    nFrames = Max[2, Round[frameRate * targetDuration]];
    Print["  Rendering ", nFrames, " frames at ", FmtN[frameRate, 3],
          " fps (", FmtN[nFrames / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];
    {speedMin, speedMax} = MinMax[speedArr];
    thetaDeg = model["thetaAnalyticDeg"];

    vInitHat  = model["vInit"]  / Norm[model["vInit"]];
    vFinalHat = model["vFinal"] / Norm[model["vFinal"]];
    p0 = {xArr[[1]], yArr[[1]]};
    pf = {xArr[[-1]], yArr[[-1]]};
    extend = 1.3 * model["rInitEff"];

    incomingA = p0 - extend * vInitHat;  incomingB = p0 + extend * vInitHat;
    outgoingA = pf - extend * vFinalHat; outgoingB = pf + extend * vFinalHat;

    (* Foot of perpendicular from the nucleus to the incoming asymptote
       -- its distance from the origin is the impact parameter b. *)
    footPoint = p0 + (-(p0 . vInitHat)) * vInitHat;

    angle1 = ArcTan[vInitHat[[1]],  vInitHat[[2]]];
    angle2 = ArcTan[vFinalHat[[1]], vFinalHat[[2]]];
    arcR   = 0.12 * extend;

    plotHalfRange = 1.1 * Max[Max[Abs[xArr]], Max[Abs[yArr]], model["rMin"] + 1.0];

    frames = Table[
      With[{nS = Max[2, Round[k * nPts / nFrames]]},
        Graphics[{
          (* Dashed incoming/outgoing asymptotes *)
          {GrayLevel[0.45], Dashing[{0.02, 0.015}], Line[{incomingA, incomingB}]},
          {GrayLevel[0.45], Dashing[{0.02, 0.015}], Line[{outgoingA, outgoingB}]},

          (* Impact parameter b, as an arrow from the nucleus to the
             incoming asymptote's closest point *)
          {RGBColor[0.9, 0.8, 0.2], AbsoluteThickness[1.3], Arrowheads[0.025],
           Arrow[{{0.0, 0.0}, footPoint}]},
          {RGBColor[0.9, 0.8, 0.2], FontSize -> 9,
           Text["b = " <> ToString[NumberForm[model["b"], {4, 2}]],
                footPoint * 0.55 + {0.0, 0.25 * arcR}]},

          (* Scattering-angle arc between the two asymptote directions *)
          {RGBColor[0.6, 0.9, 0.5], AbsoluteThickness[1.3], Circle[{0.0, 0.0}, arcR, {angle1, angle2}]},
          {RGBColor[0.6, 0.9, 0.5], FontSize -> 10,
           Text["theta = " <> ToString[NumberForm[thetaDeg, {5, 1}]] <> " deg",
                1.6 * arcR * {Cos[(angle1 + angle2) / 2.0], Sin[(angle1 + angle2) / 2.0]}]},

          (* Trajectory trail, coloured by speed: blue = slow, red = fast
             (fastest at periapsis) *)
          Table[
            {Blend[{RGBColor[0.2, 0.4, 1.0], RGBColor[1.0, 0.25, 0.2]},
                   If[speedMax - speedMin < 1.0*^-9, 0.5,
                      Clip[Rescale[speedArr[[i]], {speedMin, speedMax}, {0.0, 1.0}], {0.0, 1.0}]]],
             AbsoluteThickness[2.0],
             Line[{{xArr[[i]], yArr[[i]]}, {xArr[[i + 1]], yArr[[i + 1]]}}]},
            {i, 1, nS - 1}],

          (* Nucleus and current particle position *)
          {RGBColor[1.0, 0.6, 0.0], Disk[{0.0, 0.0}, 0.03 * plotHalfRange]},
          {White, Disk[{xArr[[nS]], yArr[[nS]]}, 0.02 * plotHalfRange]}
        },
        Background -> Black,
        PlotRange -> plotHalfRange * {{-1, 1}, {-1, 1}},
        ImageSize -> 460, Frame -> False, Axes -> False]
      ],
      {k, nFrames}
    ];
    ExportGIF[frames, outGif, frameRate];
    {nFrames, frameRate}
  ]


(* ========================================================
   DISTRIBUTION MODE — b vs theta scatter plot + growing histogram
   ======================================================== *)

AnimateDistribution[model_Association, outGif_String, targetDuration_?NumericQ] :=
  Module[{b, thetaDeg, n, bmax, nFrames, frameRate, curveB, curveTheta, histMax, frames},
    b = model["b"]; thetaDeg = model["thetaDeg"]; n = model["n"]; bmax = model["bmax"];
    frameRate = ScatAnimationRate[targetDuration];
    nFrames = Max[2, Round[frameRate * targetDuration]];
    Print["  Rendering ", nFrames, " frames at ", FmtN[frameRate, 3],
          " fps (", FmtN[nFrames / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];

    curveB     = N @ Subdivide[0.05, bmax, 200];
    curveTheta = 2.0 * ArcCot[curveB] * 180.0 / Pi;
    histMax    = Max[8.0, 0.5 * n];

    frames = Table[
      With[{nS = Max[1, Round[k * n / nFrames]]},
        GraphicsRow[{
          Graphics[{
            {GrayLevel[0.6], Dashing[{0.015, 0.015}], Line[Transpose[{curveB, curveTheta}]]},
            Table[
              {If[thetaDeg[[i]] > 90.0, Red, RGBColor[0.25, 0.7, 1.0]],
               PointSize[0.012], Point[{b[[i]], thetaDeg[[i]]}]},
              {i, nS}]
          },
          Background -> Black, Frame -> True, FrameStyle -> GrayLevel[0.6],
          LabelStyle -> White, FrameLabel -> {"impact parameter b", "theta (deg)"},
          PlotRange -> {{0, bmax}, {0, 180}}, AspectRatio -> 1, ImageSize -> 300],

          Histogram[thetaDeg[[;; nS]], {0, 180, 10},
            ChartStyle -> RGBColor[0.25, 0.7, 1.0],
            Background -> Black, FrameStyle -> GrayLevel[0.6], LabelStyle -> White,
            FrameLabel -> {"theta (deg)", "count"},
            PlotRange -> {{0, 180}, {0, histMax}}, ImageSize -> 300,
            Epilog -> {Red, Dashed, Line[{{90, 0}, {90, histMax}}]}]
        }]
      ],
      {k, nFrames}
    ];
    ExportGIF[frames, outGif, frameRate];
    {nFrames, frameRate}
  ]


(* ========================================================
   DISCOVERY MODE — Thomson vs Rutherford side-by-side histograms
   ======================================================== *)

AnimateDiscovery[model_Association, outGif_String, targetDuration_?NumericQ] :=
  Module[{thomsonThetaDeg, rutherfordThetaDeg, n, nFrames, frameRate, histMax, frames},
    thomsonThetaDeg    = model["thomsonThetaDeg"];
    rutherfordThetaDeg = model["rutherfordThetaDeg"];
    n = model["n"];
    frameRate = ScatAnimationRate[targetDuration];
    nFrames = Max[2, Round[frameRate * targetDuration]];
    Print["  Rendering ", nFrames, " frames at ", FmtN[frameRate, 3],
          " fps (", FmtN[nFrames / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];
    histMax = Max[8.0, 0.6 * n];

    frames = Table[
      With[{nS = Max[1, Round[k * n / nFrames]]},
        Column[{
          Style["Geiger-Marsden experiment: Thomson vs Rutherford", White, Bold, 14],
          GraphicsRow[{
            Histogram[thomsonThetaDeg[[;; nS]], {0, 180, 5},
              ChartStyle -> RGBColor[0.3, 0.6, 1.0],
              Background -> Black, FrameStyle -> GrayLevel[0.6], LabelStyle -> White,
              FrameLabel -> {"theta (deg)", "count"}, PlotLabel -> Style["Thomson", White],
              PlotRange -> {{0, 180}, {0, histMax}}, ImageSize -> 300],

            Histogram[rutherfordThetaDeg[[;; nS]], {0, 180, 5},
              ChartStyle -> RGBColor[1.0, 0.45, 0.15],
              Background -> Black, FrameStyle -> GrayLevel[0.6], LabelStyle -> White,
              FrameLabel -> {"theta (deg)", "count"}, PlotLabel -> Style["Rutherford", White],
              PlotRange -> {{0, 180}, {0, histMax}}, ImageSize -> 300,
              Epilog -> {Red, Dashed, Line[{{90, 0}, {90, histMax}}]}]
          }]
        },
        Background -> Black]
      ],
      {k, nFrames}
    ];
    ExportGIF[frames, outGif, frameRate];
    {nFrames, frameRate}
  ]

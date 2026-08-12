(* ========================================================
   bayes/src/animate.wl — GIF animations for all three modes

   GIF playback duration is driven by targetDuration — the actual WAV
   length (intro speech + pause + sonification, N[Length[finalLeft]]/sr
   from main.wl), not a fixed frame count/rate — so the animation and
   its sonification stay in sync. nFrames is a RENDER BUDGET, not a
   literal frame count: frameRate is solved as nFrames/targetDuration
   and clamped to [$MinAnimationFps,$MaxAnimationFps] (2-30 fps), then
   the actual frame count is recomputed from the clamped rate so
   playback duration always equals targetDuration exactly. See
   lorenz/src/animate.wl's ExportAnimation for the reference version of
   this pattern.
   ======================================================== *)

$MinAnimationFps = 2;
$MaxAnimationFps = 30;


(* ── Mode 1: coin — Beta posterior narrowing ─────────────────────── *)

RenderCoinFrame[stepAssoc_Association, thetaTrue_?NumericQ, priorVariance_?NumericQ] :=
  Module[{alpha, beta, colorFrac, curveColor, yMax},
    alpha = stepAssoc["alpha"]; beta = stepAssoc["beta"];
    colorFrac  = Clip[1.0 - stepAssoc["variance"] / priorVariance, {0.0, 1.0}];
    curveColor = Blend[{RGBColor[0.2, 0.4, 0.9], RGBColor[0.95, 0.35, 0.15]}, colorFrac];
    yMax = Max[10.0, 1.15 * PDF[BetaDistribution[alpha, beta], BetaMode[alpha, beta]]];

    Plot[PDF[BetaDistribution[alpha, beta], theta], {theta, 0, 1},
      PlotStyle  -> {curveColor, Thickness[0.006]},
      PlotRange  -> {{0, 1}, {0, yMax}},
      Background -> Black,
      ImageSize  -> {600, 400},
      Frame      -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["coin bias \[Theta]", White, 11], Style["posterior density", White, 11]},
      PlotLabel  -> Style[
        "Flip " <> ToString[stepAssoc["flip"]] <> "  (" <>
        If[stepAssoc["outcome"] === 1, "H", "T"] <> ")   mean = " <>
        ToString[NumberForm[stepAssoc["mean"], {4, 3}]], White, 12],
      Epilog -> {Dashed, RGBColor[0.9, 0.9, 0.2], Thickness[0.003],
        Line[{{thetaTrue, 0}, {thetaTrue, yMax}}]}
    ]
  ];

AnimateCoin[seq_List, thetaTrue_?NumericQ, outGIF_String, targetDuration_?NumericQ,
           Optional[nFrames_Integer, 150]] :=
  Module[{n = Length[seq], indices, priorVariance, frameRate, actualNFrames, frames},
    priorVariance = BetaVariance[1.0, 1.0];
    frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];
    indices       = Clip[Round[Subdivide[1, n, actualNFrames - 1]], {1, n}];
    Print["  Rendering ", Length[indices], " coin posterior frames at ", FmtN[frameRate, 3],
          " fps (", FmtN[Length[indices] / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];
    frames = RenderCoinFrame[seq[[#]], thetaTrue, priorVariance] & /@ indices;
    ExportGIF[frames, outGIF, frameRate];
    {Length[frames], frameRate}
  ];


(* ── Mode 2: gaussian — posterior shifting and narrowing ─────────── *)

RenderGaussianFrame[stepAssoc_Association, muLo_?NumericQ, muHi_?NumericQ,
                    muTrue_?NumericQ, mu0_?NumericQ] :=
  Module[{postMean, postSD, yMax, ciLow, ciHigh},
    postMean = stepAssoc["mean"];
    postSD   = Sqrt[stepAssoc["variance"]];
    ciLow    = stepAssoc["ci_low"];
    ciHigh   = stepAssoc["ci_high"];
    yMax     = 1.15 * PDF[NormalDistribution[postMean, postSD], postMean];

    Show[
      Quiet[Plot[PDF[NormalDistribution[postMean, postSD], mu], {mu, muLo, muHi},
        PlotStyle  -> {RGBColor[0.3, 0.7, 0.95], Thickness[0.006]},
        Filling    -> Axis,
        FillingStyle -> Directive[Opacity[0.15], RGBColor[0.3, 0.7, 0.95]],
        PlotRange  -> {{muLo, muHi}, {0, yMax}},
        Background -> Black,
        ImageSize  -> {600, 400},
        Frame      -> True,
        FrameStyle -> Directive[White, Thin],
        FrameLabel -> {Style["\[Mu]", White, 11], Style["posterior density", White, 11]},
        PlotLabel  -> Style[
          "Observation " <> ToString[stepAssoc["observation"]] <> "   mean = " <>
          ToString[NumberForm[postMean, {4, 3}]], White, 12]
      ], General::munfl],
      Graphics[{
        Opacity[0.25], RGBColor[0.9, 0.6, 0.1],
        Rectangle[{ciLow, 0}, {ciHigh, yMax}]
      }],
      Graphics[{
        {Dashed, RGBColor[0.9, 0.9, 0.2], Thickness[0.003], Line[{{muTrue, 0}, {muTrue, yMax}}]},
        {Dashed, RGBColor[0.6, 0.6, 0.6], Thickness[0.0025], Line[{{mu0, 0}, {mu0, yMax}}]},
        {White, PointSize[0.02], Point[{stepAssoc["x_obs"], 0}]}
      }]
    ]
  ];

AnimateGaussian[seq_List, muLo_?NumericQ, muHi_?NumericQ, muTrue_?NumericQ, mu0_?NumericQ,
               outGIF_String, targetDuration_?NumericQ, Optional[nFrames_Integer, 150]] :=
  Module[{n = Length[seq], indices, frameRate, actualNFrames, frames},
    frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];
    indices       = Clip[Round[Subdivide[1, n, actualNFrames - 1]], {1, n}];
    Print["  Rendering ", Length[indices], " gaussian posterior frames at ", FmtN[frameRate, 3],
          " fps (", FmtN[Length[indices] / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];
    frames = RenderGaussianFrame[seq[[#]], muLo, muHi, muTrue, mu0] & /@ indices;
    ExportGIF[frames, outGIF, frameRate];
    {Length[frames], frameRate}
  ];


(* ── Mode 3: model — Bayes factor meter ──────────────────────────── *)

(* Flip sequence rendered as wrapped H/T text, revealed up to the
   current flip only — capped to the most recent $bayesMeterMaxChars
   outcomes so the panel stays readable once nFlips grows past a
   couple of screenfuls of monospace text. *)
$bayesMeterMaxChars  = 120;
$bayesMeterCharsPerRow = 24;

FlipSequenceText[flips_List, uptoIdx_Integer] :=
  Module[{visible, letters, rows},
    visible = flips[[1 ;; uptoIdx]];
    visible = If[Length[visible] > $bayesMeterMaxChars,
      visible[[-$bayesMeterMaxChars ;;]], visible];
    letters = If[# === 1, "H", "T"] & /@ visible;
    rows = StringJoin /@ Partition[letters, UpTo[$bayesMeterCharsPerRow]];
    StringRiffle[rows, "\n"]
  ];

(* Gauge x-axis is -log10(K): H1 (fair) is the left end, H2 (biased) the
   right end (per the build spec), but positive log10(K) means H1 is
   favoured, so the raw statistic must be negated to land the needle on
   the correctly-labelled side — same reasoning as the audio pan sign
   in sonify.wl's BuildModelAudio. *)
RenderModelFrame[flips_List, stepAssoc_Association, meterRange_?NumericQ] :=
  Module[{logK, gaugeX, gaugeFrac, flipIdx, needleColor},
    logK      = stepAssoc["log_bayes_factor"];
    flipIdx   = stepAssoc["flip"];
    gaugeX    = Clip[-logK, {-meterRange, meterRange}];
    gaugeFrac = gaugeX / meterRange;
    needleColor = Blend[{RGBColor[0.95, 0.35, 0.15], RGBColor[0.3, 0.6, 0.95]},
      (gaugeFrac + 1.0) / 2.0];

    Column[{
      Graphics[{
        {Gray, Thickness[0.01], Line[{{-meterRange, 0}, {meterRange, 0}}]},
        {Dashed, RGBColor[0.7, 0.7, 0.3], Line[{{-1, -0.3}, {-1, 0.3}}]},
        {Dashed, RGBColor[0.7, 0.7, 0.3], Line[{{1, -0.3}, {1, 0.3}}]},
        {Dashed, RGBColor[0.9, 0.4, 0.2], Line[{{-2, -0.3}, {-2, 0.3}}]},
        {Dashed, RGBColor[0.9, 0.4, 0.2], Line[{{2, -0.3}, {2, 0.3}}]},
        {needleColor, PointSize[0.05], Point[{gaugeX, 0}]},
        {White, Text[Style["H1: fair coin", White, 12], {-meterRange * 0.85, 0.7}]},
        {White, Text[Style["H2: biased coin", White, 12], {meterRange * 0.85, 0.7}]},
        {White, Text[Style["log10(K) = " <>
          ToString[NumberForm[logK, {5, 3}]], White, 13], {0, -0.7}]}
      },
        PlotRange  -> {{-meterRange * 1.05, meterRange * 1.05}, {-1.1, 1.1}},
        Background -> Black,
        ImageSize  -> {600, 220},
        PlotLabel  -> Style["Bayes Factor Meter \[LongDash] flip " <> ToString[flipIdx], White, 13]
      ],
      Graphics[{White, Text[
        Style[FlipSequenceText[flips, flipIdx], White, 14, FontFamily -> "Courier"],
        {0, 0}]},
        Background -> Black, ImageSize -> {600, 180}
      ]
    }, Background -> Black]
  ];

AnimateModel[flips_List, modelSeq_List, outGIF_String, targetDuration_?NumericQ,
            Optional[nFrames_Integer, 150], Optional[meterRange_?NumericQ, 3.0]] :=
  Module[{n = Length[modelSeq], indices, frameRate, actualNFrames, frames},
    frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];
    indices       = Clip[Round[Subdivide[1, n, actualNFrames - 1]], {1, n}];
    Print["  Rendering ", Length[indices], " Bayes factor meter frames at ", FmtN[frameRate, 3],
          " fps (", FmtN[Length[indices] / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];
    frames = RenderModelFrame[flips, modelSeq[[#]], meterRange] & /@ indices;
    ExportGIF[frames, outGIF, frameRate];
    {Length[frames], frameRate}
  ];

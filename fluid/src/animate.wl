(* ========================================================
   fluid/src/animate.wl — GIF rendering for karman/strouhal/flag
   ======================================================== *)

(* GIF playback duration used to be decoupled from the accompanying WAV:
   a fixed $FluidGifFrameRate (8 fps) times a fixed frame count (32, or up
   to 50 for strouhal) gave a GIF of ~4-6.5s regardless of how long the
   sonification actually ran (karman/flag ~40-46s, strouhal ~47s, once
   the spoken intro is included -- see sonify.wl's
   FluidPrependIntroAndExport, which now returns the actual total WAV
   duration so callers can pass it here as targetDuration).

   nFrames below is a RENDER BUDGET, not a literal frame count: frameRate
   is solved as nFrames/targetDuration then clamped to
   [$FluidMinGifFps, $FluidMaxGifFps] so a short run doesn't demand a
   strobing frame rate and a long one doesn't demand an implausibly slow
   one -- the frame COUNT is what flexes at the clamp boundary (recomputed
   as Round[frameRate*targetDuration]) so actual playback duration always
   equals targetDuration exactly. Same pattern as lorenz/src/animate.wl. *)
$FluidMinGifFps = 2;
$FluidMaxGifFps = 30;
$FluidGifFrameBudget = 150;

FluidGifRate[targetDuration_?NumericQ, nFrames_:$FluidGifFrameBudget] :=
  Clip[nFrames / targetDuration, {$FluidMinGifFps, $FluidMaxGifFps}];


(* ── Shared vortex-flow-field renderer (karman mode + strouhal's
   top panel) ─────────────────────────────────────────────────── *)
RenderVortexFlowGraphic[vortexList_List, dCyl_?NumericQ, titleText_String] :=
  Module[{posDots, negDots},
    posDots = Select[vortexList, #[[3]] > 0 &][[All, {1, 2}]];
    negDots = Select[vortexList, #[[3]] < 0 &][[All, {1, 2}]];
    Graphics[
      {
        {GrayLevel[0.55], Disk[{0.0, 0.0}, 0.5 * dCyl]},
        {Black, Thick, Arrowheads[0.04], Arrow[{{-1.8 * dCyl, 4.3 * dCyl}, {-0.7 * dCyl, 4.3 * dCyl}}]},
        {RGBColor[0.15, 0.35, 0.95], PointSize[0.022], If[Length[posDots] > 0, Point[posDots], {}]},
        {RGBColor[0.9, 0.15, 0.15], PointSize[0.022], If[Length[negDots] > 0, Point[negDots], {}]}
      },
      PlotRange   -> {{-2.0 * dCyl, 20.0 * dCyl}, {-5.0 * dCyl, 5.0 * dCyl}},
      AspectRatio -> 200 / 520,
      Background -> White,
      ImageSize  -> {520, 200},
      Frame      -> True,
      FrameStyle -> Directive[Black, Thin],
      FrameLabel -> {Style["x / D", Black, 10], Style["y / D", Black, 10]},
      PlotLabel  -> Style[titleText, Black, 11],
      Axes -> False
    ]
  ];


(* ════════════════════════════════════════════════════════
   KARMAN MODE
   ════════════════════════════════════════════════════════ *)
AnimateKarman[model_Association, outDir_String, targetDuration_?NumericQ] :=
  Module[{nFrames, frameRate, frameTimes, frames, outGIF, sim, dCyl, titleFn},
    sim   = model["sim"];
    dCyl  = model["D"];
    frameRate = FluidGifRate[targetDuration];
    nFrames   = Max[2, Round[frameRate * targetDuration]];
    frameTimes = N @ Subdivide[0.02 * model["duration"], model["duration"], nFrames - 1];
    titleFn[t_] := "Karman vortex street -- Re=" <> ToString[NumberForm[model["Re"], {5,1}]] <>
                   "   t=" <> ToString[NumberForm[t, {5,1}]];

    frames = Table[
      RenderVortexFlowGraphic[VortexFrameAt[sim, t], dCyl, titleFn[t]],
      {t, frameTimes}
    ];

    outGIF = FileNameJoin[{outDir, "karman.gif"}];
    ExportGIF[frames, outGIF, frameRate];
    STEMDescribeGIF[outGIF, nFrames, frameRate];
    {nFrames, frameRate}
  ];


(* ════════════════════════════════════════════════════════
   STROUHAL MODE — two-panel: flow snapshot + St vs Re curve
   ════════════════════════════════════════════════════════ *)
RenderStrouhalBottomPanel[model_Association, upToIdx_Integer] :=
  Module[{reValues, steps, curveRe, curveSt, measuredPts, cursorRe},
    reValues = model["reValues"];
    steps    = model["steps"];
    cursorRe = reValues[[upToIdx]];

    curveRe = N @ Subdivide[Max[26.0, model["reStart"]], model["reEnd"], 60];
    curveSt = StrouhalNumber /@ curveRe;

    measuredPts = Table[
      If[steps[[k]]["shedding"], {reValues[[k]], steps[[k]]["stMeasured"]}, Nothing],
      {k, upToIdx}
    ];

    Graphics[
      {
        {Dashed, GrayLevel[0.4], Line[{{$ReOnset, -0.05}, {$ReOnset, 0.25}}]},
        {GrayLevel[0.65], Thick, Line[Transpose[{curveRe, curveSt}]]},
        {RGBColor[0.15, 0.65, 0.25], PointSize[0.012], If[Length[measuredPts] > 0, Point[measuredPts], {}]},
        {Red, Thickness[0.005], Line[{{cursorRe, -0.05}, {cursorRe, 0.25}}]}
      },
      PlotRange   -> {{model["reStart"], model["reEnd"]}, {-0.05, 0.25}},
      AspectRatio -> 260 / 520,
      Background  -> White,
      ImageSize   -> {520, 260},
      ImagePadding -> {{55, 15}, {40, 45}},
      Frame       -> True,
      FrameStyle  -> Directive[Black, Thin],
      FrameLabel  -> {Style["Re", Black, 10], Style["St", Black, 10]},
      PlotLabel   -> Style["St vs Re  (grey = 0.198(1-19.7/Re) reference, dashed = onset)", Black, 10],
      Axes -> False
    ]
  ];

RenderStrouhalFrame[model_Association, upToIdx_Integer] :=
  Module[{step, topPanel},
    step = model["steps"][[upToIdx]];
    topPanel = If[step["shedding"] && step["sim"] =!= None,
      RenderVortexFlowGraphic[
        Last[step["sim"]["stepHistory"]], model["D"],
        "Flow at Re=" <> ToString[NumberForm[step["Re"], {5,1}]]],
      Graphics[
        {Text[Style["steady flow -- no shedding (Re=" <>
          ToString[NumberForm[step["Re"], {5,1}]] <> ")", Black, 12], {9.0, 0.0}],
         {GrayLevel[0.55], Disk[{0.0, 0.0}, 0.5 * model["D"]]}},
        PlotRange -> {{-2.0 * model["D"], 20.0 * model["D"]}, {-5.0 * model["D"], 5.0 * model["D"]}},
        AspectRatio -> 200 / 520,
        Background -> White, ImageSize -> {520, 200}, Frame -> True,
        FrameStyle -> Directive[Black, Thin], Axes -> False]
    ];
    Column[{topPanel, RenderStrouhalBottomPanel[model, upToIdx]}, Spacings -> 0.6]
  ];

AnimateStrouhal[model_Association, outDir_String, targetDuration_?NumericQ] :=
  Module[{nFrames, frameRate, indices, frames, outGIF},
    frameRate = FluidGifRate[targetDuration];
    nFrames   = Max[2, Round[frameRate * targetDuration]];
    (* model["reSteps"] discrete Re steps are the only distinct visual
       states available; if nFrames exceeds that (short targetDuration
       forcing the fps clamp up), Subdivide's rounding naturally repeats
       indices -- a brief hold on a state rather than an error. *)
    indices = Round[Subdivide[1, model["reSteps"], nFrames - 1]];
    indices = Max[1, #] & /@ indices;

    frames = RenderStrouhalFrame[model, #] & /@ indices;

    outGIF = FileNameJoin[{outDir, "strouhal.gif"}];
    ExportGIF[frames, outGIF, frameRate];
    STEMDescribeGIF[outGIF, Length[frames], frameRate];
    {Length[frames], frameRate}
  ];


(* ════════════════════════════════════════════════════════
   FLAG MODE
   ════════════════════════════════════════════════════════ *)

(* FlagShapeAt — synthesises a full spatial flag shape from the
   single tracked quantity y_tip(t): a clamped-cantilever-like
   quadratic bending profile (zero deflection and slope at the fixed
   leading edge) plus a small traveling-wave ripple that grows toward
   the tip, purely for a visually plausible "flag" GIF -- the ripple
   term has no bearing on the audio (which uses y_tip(t) alone) or
   on any correctness check; documented in AGENTS.md as cosmetic. *)
FlagShapeAt[t_?NumericQ, yTip_?NumericQ, flagLength_?NumericQ, fFlag_?NumericQ, nSeg_Integer] :=
  Module[{xs, frac},
    xs = N @ Subdivide[0.0, flagLength, nSeg - 1];
    Table[
      frac = x / flagLength;
      {x, yTip * frac^2 + 0.15 * yTip * frac * Sin[2.0 Pi * (frac - 3.0 * fFlag * t)]},
      {x, xs}
    ]
  ];

FlagCurveColor[curvature_?NumericQ, curvMax_?NumericQ] :=
  Blend[{RGBColor[0.15, 0.35, 0.95], RGBColor[0.9, 0.15, 0.15]},
        Clip[Abs[curvature] / (curvMax + 1.0*^-9), {0.0, 1.0}]];

RenderFlagFrame[shape_List, trail_List, flagLength_?NumericQ] :=
  Module[{n = Length[shape], curvatures, curvMax, segs},
    curvatures = Table[
      If[1 < i < n,
        Abs[shape[[i - 1, 2]] - 2.0 shape[[i, 2]] + shape[[i + 1, 2]]],
        0.0],
      {i, n}];
    curvMax = Max[curvatures, 1.0*^-6];
    segs = Table[
      {FlagCurveColor[curvatures[[i]], curvMax], Thickness[0.012],
       Line[{shape[[i]], shape[[i + 1]]}]},
      {i, n - 1}];

    Graphics[
      {
        {GrayLevel[0.3], PointSize[0.02], Point[{0.0, 0.0}]},
        segs,
        {GrayLevel[0.6, 0.5], PointSize[0.012], Point /@ trail}
      },
      PlotRange  -> {{0.0, flagLength}, {-flagLength / 2.0, flagLength / 2.0}},
      Background -> White,
      ImageSize  -> {480, 320},
      Frame      -> True,
      FrameStyle -> Directive[Black, Thin],
      FrameLabel -> {Style["x", Black, 10], Style["y", Black, 10]},
      PlotLabel  -> Style["Flag flutter", Black, 11],
      Axes -> False
    ]
  ];

AnimateFlag[model_Association, outDir_String, targetDuration_?NumericQ] :=
  Module[{yTipInterp, nFrames, frameRate, frameTimes, flagLength, fFlag, nSeg,
          shapes, trailLen, frames, outGIF},
    yTipInterp = Interpolation[Transpose[{model["model"]["tArr"], model["model"]["yArr"]}]];
    flagLength = model["flagLength"];
    fFlag      = model["model"]["fFlag"];
    nSeg       = 24;
    frameRate  = FluidGifRate[targetDuration];
    nFrames    = Max[2, Round[frameRate * targetDuration]];
    trailLen   = 6;

    frameTimes = N @ Subdivide[0.0, model["duration"], nFrames - 1];
    shapes = Table[FlagShapeAt[t, yTipInterp[t], flagLength, fFlag, nSeg], {t, frameTimes}];

    frames = Table[
      RenderFlagFrame[
        shapes[[i]],
        Last /@ shapes[[Max[1, i - trailLen] ;; i]],
        flagLength],
      {i, nFrames}
    ];

    outGIF = FileNameJoin[{outDir, "flag.gif"}];
    ExportGIF[frames, outGIF, frameRate];
    STEMDescribeGIF[outGIF, nFrames, frameRate];
    {nFrames, frameRate}
  ];

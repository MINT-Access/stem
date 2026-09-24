(* ========================================================
   dynamical/src/animate.wl — Bifurcation diagram and
   time-series animation export
   ======================================================== *)


(* GIF timing: frame delay and frame count come from stem-core's
   GIFFramePlan, which clamps the requested rate to 2-30 fps, rounds the
   frame delay to whole centiseconds (what the GIF format stores) and
   derives the frame count from that delay; main.wl then measures both
   files with SyncWAVToGIF. *)


(* ── Sweep mode: progressive bifurcation diagram ─────────────────────
   x-axis: r; y-axis: attractor x values [0,1]. Dots accumulate as the
   sweep advances; a red cursor line marks the current r; dashed grey
   lines mark the three named events (first bifurcation, chaos onset,
   period-3 window). *)

RenderSweepFrame[rValues_List, attractors_List, upToStep_Integer, eventRVals_List] :=
  Module[{pts, cursorR, rMin, rMax},
    pts = Flatten[
      Table[Map[{rValues[[k]], #} &, attractors[[k]]], {k, upToStep}],
      1
    ];
    cursorR = rValues[[upToStep]];
    rMin = First[rValues]; rMax = Last[rValues];
    Graphics[
      {
        {PointSize[0.0012], RGBColor[0.2, 0.9, 0.9], Point[pts]},
        Map[{Dashed, GrayLevel[0.55], Line[{{#, 0}, {#, 1}}]} &, eventRVals],
        {Red, Thickness[0.004], Line[{{cursorR, 0}, {cursorR, 1}}]}
      },
      PlotRange   -> {{rMin, rMax}, {0, 1}},
      Background  -> Black,
      ImageSize   -> {600, 420},
      Frame       -> True,
      FrameStyle  -> Directive[White, Thin],
      FrameLabel  -> {Style["r", White, 11], Style["x", White, 11]},
      PlotLabel   -> Style["Logistic Map Bifurcation Diagram", White, 12],
      Axes        -> False
    ]
  ];

(* AnimateSweepBifurcation
   Builds frames and writes an animated GIF whose PLAYBACK DURATION
   matches targetDuration — the same total WAV duration (spoken intro +
   pause + sonified sweep) main.wl/experiments.wl compute as totalDurSec
   right before calling this, so the bifurcation-diagram animation and
   its sonification stay in sync instead of the GIF racing through the
   whole sweep in a few seconds while a 500-step sweep's audio plays for
   over a minute.

   nFrames is a RENDER BUDGET, not a literal frame count: frameRate is
   solved as nFrames/targetDuration and then clamped to
   [2, 30] fps (stem-core GIFFramePlan) so a short run doesn't demand a
   strobing frame rate and a long one doesn't demand an implausibly slow
   one — the frame COUNT is what flexes at the clamp boundary (recomputed
   as Round[frameRate * targetDuration]) so actual playback duration
   equals targetDuration to within half a frame delay.

   Returns {actualNFrames, frameRate} so callers can report what was
   actually rendered via STEMDescribeGIF. *)
AnimateSweepBifurcation[sweepModel_Association, eventRs_Association,
                        outGIF_String, targetDuration_?NumericQ,
                        Optional[nFrames_Integer, 150]] :=
  Module[{plan, rValues, attractors, nSteps, indices, frames, eventRVals,
          frameRate, actualNFrames},
    rValues    = sweepModel["rValues"];
    attractors = sweepModel["attractors"];
    nSteps     = Length[rValues];
    eventRVals = Values[eventRs];

    plan      = GIFFramePlan[targetDuration, nFrames / targetDuration];
    frameRate = plan["FrameRate"];
    actualNFrames = plan["FrameCount"];

    indices = Round[Subdivide[1, nSteps, actualNFrames - 1]];
    indices = Max[1, #] & /@ indices;

    Print["  Rendering ", Length[indices], " bifurcation-diagram frames at ",
          FmtDec[frameRate], " fps (", FmtDec[plan["FrameDelay"]], " s per frame, ",
          FmtDec[plan["GIFDuration"]], " s in total)."];
    frames = RenderSweepFrame[rValues, attractors, #, eventRVals] & /@ indices;

    ExportGIF[frames, outGIF, plan];
    {actualNFrames, frameRate}
  ];


(* ── Iterate mode: x_n vs n time series ──────────────────────────────
   Points appear one at a time, connected by a line; the current point
   is highlighted with a larger marker; title shows r and preset. *)

RenderIterateFrame[trajectory_List, upToN_Integer, r_?NumericQ, preset_String] :=
  Module[{pts, title},
    pts   = Table[{i - 1, trajectory[[i]]}, {i, upToN}];
    title = "Logistic Map: r = " <> ToString[NumberForm[r, {5, 4}]] <>
            If[preset =!= "", "  (" <> preset <> ")", ""];
    Graphics[
      {
        {RGBColor[0.2, 0.6, 0.95], Thin, Line[pts]},
        {Yellow, PointSize[0.02], Point[Last[pts]]}
      },
      PlotRange   -> {{0, Length[trajectory] - 1}, {0, 1}},
      Background  -> GrayLevel[0.08],
      ImageSize   -> {600, 380},
      Frame       -> True,
      FrameStyle  -> Directive[White, Thin],
      FrameLabel  -> {Style["iteration n", White, 11], Style["x_n", White, 11]},
      PlotLabel   -> Style[title, White, 11]
    ]
  ];

(* AnimateIterateTimeSeries
   Same duration-sync contract as AnimateSweepBifurcation (see its
   docstring): targetDuration should be the total WAV duration (spoken
   intro + pause + sonified iteration) computed just before this call,
   nFrames is a render budget, and frameRate is solved and clamped to
   [2, 30] fps (stem-core GIFFramePlan) so playback duration always
   equals targetDuration to within half a frame delay. Returns {actualNFrames, frameRate}. *)
AnimateIterateTimeSeries[iterateModel_Association, outGIF_String,
                         targetDuration_?NumericQ, Optional[nFrames_Integer, 150]] :=
  Module[{plan, trajectory, n, r, preset, indices, frames, frameRate, actualNFrames},
    trajectory = iterateModel["trajectory"];
    n       = Length[trajectory];
    r       = iterateModel["r"];
    preset  = iterateModel["preset"];

    plan      = GIFFramePlan[targetDuration, nFrames / targetDuration];
    frameRate = plan["FrameRate"];
    actualNFrames = plan["FrameCount"];

    indices = Round[Subdivide[2, n, actualNFrames - 1]];
    indices = Max[2, #] & /@ indices;

    Print["  Rendering ", Length[indices], " time-series frames at ",
          FmtDec[frameRate], " fps (", FmtDec[plan["FrameDelay"]], " s per frame, ",
          FmtDec[plan["GIFDuration"]], " s in total)."];
    frames = RenderIterateFrame[trajectory, #, r, preset] & /@ indices;

    ExportGIF[frames, outGIF, plan];
    {actualNFrames, frameRate}
  ];


(* ── Lyapunov mode: bifurcation diagram over lambda(r) ─────────────────
   Two panels sharing the r axis: the bifurcation diagram at the sweep's
   r steps on top, lambda(r) below with a solid zero line and the floor
   as a dashed line; marker r values are orange ticks along the top and
   bottom edges of both panels. Both panels are static, so they are
   drawn and rasterised once; each frame is that image plus a red cursor
   through both panels and a line of text with the current r and lambda.
   The panels use fixed sizes and ImagePadding (in printer's points), so
   an r value maps to an exact column and the cursor lines up with the
   plots. The background is rasterised at 144 dpi, which is the 2x pixel
   size Export gives the other GIFs in this app (1440 x 1200 here). *)

$lyapunovPanelW   = 720;
$lyapunovPanelH   = 300;
$lyapunovPadding  = {{64, 24}, {42, 34}};   (* {{left, right}, {bottom, top}} pixels *)

LyapunovPanelOpts[rMin_, rMax_, yRange_List, yLabel_String, xLabel_] :=
  {
    PlotRange -> {{rMin, rMax}, yRange}, PlotRangePadding -> None, PlotRangeClipping -> True,
    ImageSize -> {$lyapunovPanelW, $lyapunovPanelH}, ImagePadding -> $lyapunovPadding,
    AspectRatio -> Full,
    Background -> Black, Frame -> True, FrameStyle -> Directive[White, Thin],
    FrameTicksStyle -> Directive[White, 10],
    FrameLabel -> {xLabel, Style[yLabel, White, 12]}, Axes -> False
  };

LyapunovMarkerTicks[markers_List, {yLo_, yHi_}] :=
  Module[{len = 0.07 * (yHi - yLo)},
    {RGBColor[1.0, 0.6, 0.15], AbsoluteThickness[2],
     Line[{{#, yLo}, {#, yLo + len}}] & /@ markers,
     Line[{{#, yHi}, {#, yHi - len}}] & /@ markers}
  ];

(* LyapunovBackground — the two static panels stacked, as one Image. *)
LyapunovBackground[sweep_List, bifPoints_List, markerRs_List, floor_?NumericQ, yRange_List] :=
  Module[{rs = sweep[[All, 1]], rMin, rMax, top, bottom, pts},
    rMin = First[rs]; rMax = Last[rs];
    pts  = Flatten[MapThread[Function[{r, xs}, {r, #} & /@ xs], {rs, bifPoints}], 1];
    top = Graphics[
      {{AbsolutePointSize[1], RGBColor[0.2, 0.9, 0.9], Point[pts]},
       LyapunovMarkerTicks[markerRs, {0, 1}]},
      LyapunovPanelOpts[rMin, rMax, {0, 1}, "x", None]];
    bottom = Graphics[
      {{GrayLevel[0.85], AbsoluteThickness[1], Line[{{rMin, 0}, {rMax, 0}}]},
       {GrayLevel[0.7], Dashed, AbsoluteThickness[1], Line[{{rMin, floor}, {rMax, floor}}]},
       {RGBColor[0.45, 0.75, 1.0], AbsoluteThickness[1.5], Line[sweep]},
       LyapunovMarkerTicks[markerRs, yRange]},
      LyapunovPanelOpts[rMin, rMax, yRange, "\[Lambda]", Style["r", White, 12]]];
    ImageAssemble[{{Rasterize[top, ImageResolution -> 144]},
                   {Rasterize[bottom, ImageResolution -> 144]}}]
  ];

(* RenderTwoPanelFrame
   A frame of a two-panel animation built on a rasterised background from
   LyapunovPanelOpts panels (lyapunov and divergence modes): the
   background, a red cursor at data value xVal through both panels, and a
   line of text in the top padding, leftText left-aligned and rightText
   right-aligned. *)
RenderTwoPanelFrame[bg_Image, xVal_?NumericQ, xMin_?NumericQ, xMax_?NumericQ,
                    leftText_, rightText_] :=
  Module[{w = $lyapunovPanelW, h = $lyapunovPanelH, l, rt, b, t, xPix},
    {{l, rt}, {b, t}} = $lyapunovPadding;
    xPix = l + (xVal - xMin) / (xMax - xMin) * (w - l - rt);
    Graphics[
      {Inset[bg, {0, 0}, {0, 0}, {w, 2 h}],
       {Red, AbsoluteThickness[2],
        Line[{{xPix, h + b}, {xPix, 2 h - t}}], Line[{{xPix, b}, {xPix, h - t}}]},
       Text[leftText, {l, 2 h - t / 2}, {-1, 0}],
       Text[rightText, {w - rt, 2 h - t / 2}, {1, 0}]},
      PlotRange -> {{0, w}, {0, 2 h}}, PlotRangePadding -> None,
      ImagePadding -> None, ImageSize -> {w, 2 h}, Background -> Black
    ]
  ];

(* RenderLyapunovFrame — background plus cursor at r and the r/lambda text. *)
RenderLyapunovFrame[bg_Image, r_?NumericQ, lambda_?NumericQ, rMin_?NumericQ, rMax_?NumericQ] :=
  RenderTwoPanelFrame[bg, r, rMin, rMax,
    Style["Logistic map: bifurcation diagram and Lyapunov exponent", White, 12],
    Style["r = " <> ToString[NumberForm[r, {4, 2}]] <> "    \[Lambda] = " <>
          ToString[NumberForm[lambda, {3, 2}, NumberSigns -> {"\[Minus]", ""}]],
          Yellow, Bold, 13]];

(* AnimateLyapunov
   The GIF covers the whole WAV, so the two can start together: during
   the spoken intro the cursor waits at r_min, during the sweep it moves
   with the audio, and during the outro it rests at r_max. Frame i shows
   the r heard at the middle of its display interval. timing holds
   "intro" (seconds before the sweep starts, pause included), "sweep"
   (the sweep's duration) and "total" (the WAV's duration). Frame delay
   and count come from GIFFramePlan; nFrames is a render budget.
   Returns {frameCount, frameRate}. *)
AnimateLyapunov[sweep_List, bifPoints_List, markers_List, floor_?NumericQ,
                timing_Association, outGIF_String, Optional[nFrames_Integer, 300]] :=
  Module[{rs = sweep[[All, 1]], lams = sweep[[All, 2]], rMin, rMax, yRange, bg, lamOf,
          plan, delay, times, rAt, frames},
    rMin = First[rs]; rMax = Last[rs];
    yRange = {floor - 0.1, Max[Max[lams], 0.0] + 0.1};
    bg = LyapunovBackground[sweep, bifPoints, #["r"] & /@ markers, floor, yRange];
    lamOf = Interpolation[sweep, InterpolationOrder -> 1];

    plan  = GIFFramePlan[timing["total"], nFrames / timing["total"]];
    delay = plan["FrameDelay"];
    times = (Range[plan["FrameCount"]] - 0.5) * delay;
    rAt   = rMin + Clip[(times - timing["intro"]) / timing["sweep"], {0.0, 1.0}] * (rMax - rMin);

    Print["  Rendering ", plan["FrameCount"], " frames at ", FmtDec[plan["FrameRate"]],
          " fps (", FmtDec[delay], " s per frame, ", FmtDec[plan["GIFDuration"]], " s in total)."];
    frames = RenderLyapunovFrame[bg, #, lamOf[#], rMin, rMax] & /@ rAt;

    ExportGIF[frames, outGIF, plan];
    {plan["FrameCount"], plan["FrameRate"]}
  ];


(* ── Divergence mode: two orbits over their separation ─────────────────
   Two panels sharing the n axis, drawn once and rasterised like the
   lyapunov mode's: the two orbits x_n (blue, left channel) and y_n
   (orange, right channel) on top; Log10 of the separation below, with the
   least-squares fit over the pre-saturation range (solid green), the
   slope LyapunovExponent predicts from the fit's starting point over the
   same range (dashed yellow), and the saturation level (grey line).
   Separations below 1e-16, including exact zeros, are drawn at 1e-16.
   The y axis runs from 1e-16 (or a decade below delta, if lower) to 1 so
   that the four presets share the same axes. *)

$divergenceColorX = RGBColor[0.35, 0.7, 1.0];
$divergenceColorY = RGBColor[1.0, 0.6, 0.2];

DivergenceBackground[orbits_Association, fit_Association, lambda_?NumericQ,
                     saturation_?NumericQ] :=
  Module[{xs = orbits["x"], ys = orbits["y"], sep = orbits["separation"], nMax, yLo,
          ls, fitPts, predPts, ns, top, bottom},
    nMax = Length[xs] - 1;
    yLo  = Min[-16.0, Floor[Log10[orbits["delta"]]] - 1.0];
    ls   = Log10[Clip[sep, {10.^yLo, 1.0}]];
    ns   = {0, fit["nEnd"]};
    fitPts  = {#, (fit["intercept"] + fit["slope"] * #) / Log[10.]} & /@ ns;
    predPts = {#, (fit["intercept"] + lambda * #) / Log[10.]} & /@ ns;
    top = Graphics[
      {{$divergenceColorX, AbsoluteThickness[1.5], Line[Transpose[{Range[0, nMax], xs}]]},
       {$divergenceColorY, AbsoluteThickness[1.5], Dashing[{0.012, 0.008}],
        Line[Transpose[{Range[0, nMax], ys}]]}},
      LyapunovPanelOpts[0, nMax, {0, 1}, "x", None]];
    bottom = Graphics[
      {{GrayLevel[0.7], AbsoluteThickness[1], Line[{{0, Log10[saturation]}, {nMax, Log10[saturation]}}]},
       {GrayLevel[0.9], AbsoluteThickness[1.2], Line[Transpose[{Range[0, nMax], ls}]]},
       {GrayLevel[0.9], AbsolutePointSize[2.5], Point[Transpose[{Range[0, nMax], ls}]]},
       {RGBColor[0.3, 0.9, 0.4], Opacity[0.7], AbsoluteThickness[5], Line[fitPts]},
       {Yellow, AbsoluteThickness[2], Dashed, Line[predPts]}},
      LyapunovPanelOpts[0, nMax, {yLo - 0.5, 0.5}, "log10 |x \[Minus] y|",
        Style["iteration n", White, 12]]];
    ImageAssemble[{{Rasterize[top, ImageResolution -> 144]},
                   {Rasterize[bottom, ImageResolution -> 144]}}]
  ];

(* AnimateDivergence
   Same timing contract as AnimateLyapunov: the GIF covers the whole WAV,
   the cursor waits at n = 0 during the intro, moves one iteration per
   note_duration during the sonified part and rests at the last n during
   the outro. timing holds "intro" (seconds before the first note),
   "noteDuration" and "total" (WAV duration). Returns {frameCount, frameRate}. *)
AnimateDivergence[orbits_Association, fit_Association, lambda_?NumericQ,
                  saturation_?NumericQ, timing_Association, outGIF_String,
                  Optional[nFrames_Integer, 300]] :=
  Module[{nMax = Length[orbits["x"]] - 1, bg, plan, delay, times, nAt, legend, values, frames},
    bg = DivergenceBackground[orbits, fit, lambda, saturation];
    plan  = GIFFramePlan[timing["total"], nFrames / timing["total"]];
    delay = plan["FrameDelay"];
    times = (Range[plan["FrameCount"]] - 0.5) * delay;
    nAt   = Clip[(times - timing["intro"]) / timing["noteDuration"], {0.0, N[nMax]}];
    legend = Row[{Style["left: x0 = " <> ToString[orbits["x0"]], $divergenceColorX, 12],
                  Style["    right: x0 + \[Delta]", $divergenceColorY, 12]}];
    values = Style[Row[{"r = ", NumberForm[N[orbits["r"]], {3, 2}],
                        "   \[Delta] = ", ScientificForm[N[orbits["delta"]], {2, 1}],
                        "   fitted slope ", NumberForm[fit["slope"], {4, 3}, NumberSigns -> {"\[Minus]", ""}],
                        "   predicted \[Lambda] ", NumberForm[lambda, {4, 3}, NumberSigns -> {"\[Minus]", ""}]}],
                   Yellow, Bold, 12];
    Print["  Rendering ", plan["FrameCount"], " frames at ", FmtDec[plan["FrameRate"]],
          " fps (", FmtDec[delay], " s per frame, ", FmtDec[plan["GIFDuration"]], " s in total)."];
    frames = RenderTwoPanelFrame[bg, #, 0, nMax, legend, values] & /@ nAt;
    ExportGIF[frames, outGIF, plan];
    {plan["FrameCount"], plan["FrameRate"]}
  ];

(* ========================================================
   dynamical/src/animate.wl — Bifurcation diagram and
   time-series animation export
   ======================================================== *)


(* Sane bounds on GIF playback frame rate — see AnimateSweepBifurcation /
   AnimateIterateTimeSeries for how these keep animation/audio duration
   in sync without forcing an absurdly fast or glacial frame rate at
   the extremes (a short iterate run vs. a long sweep). *)
$MinAnimationFps = 2;
$MaxAnimationFps = 30;


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
   [$MinAnimationFps, $MaxAnimationFps] so a short run doesn't demand a
   strobing frame rate and a long one doesn't demand an implausibly slow
   one — the frame COUNT is what flexes at the clamp boundary (recomputed
   as Round[frameRate * targetDuration]) so actual playback duration
   always equals targetDuration exactly.

   Returns {actualNFrames, frameRate} so callers can report what was
   actually rendered via STEMDescribeGIF. *)
AnimateSweepBifurcation[sweepModel_Association, eventRs_Association,
                        outGIF_String, targetDuration_?NumericQ,
                        Optional[nFrames_Integer, 150]] :=
  Module[{rValues, attractors, nSteps, indices, frames, eventRVals,
          frameRate, actualNFrames},
    rValues    = sweepModel["rValues"];
    attractors = sweepModel["attractors"];
    nSteps     = Length[rValues];
    eventRVals = Values[eventRs];

    frameRate = Clip[nFrames / targetDuration,
      {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];

    indices = Round[Subdivide[1, nSteps, actualNFrames - 1]];
    indices = Max[1, #] & /@ indices;

    Print["  Rendering ", Length[indices], " bifurcation-diagram frames at ",
          FmtN[frameRate, 3], " fps (", FmtN[Length[indices] / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];
    frames = RenderSweepFrame[rValues, attractors, #, eventRVals] & /@ indices;

    ExportGIF[frames, outGIF, frameRate];
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
   [$MinAnimationFps, $MaxAnimationFps] so playback duration always
   equals targetDuration exactly. Returns {actualNFrames, frameRate}. *)
AnimateIterateTimeSeries[iterateModel_Association, outGIF_String,
                         targetDuration_?NumericQ, Optional[nFrames_Integer, 150]] :=
  Module[{trajectory, n, r, preset, indices, frames, frameRate, actualNFrames},
    trajectory = iterateModel["trajectory"];
    n       = Length[trajectory];
    r       = iterateModel["r"];
    preset  = iterateModel["preset"];

    frameRate = Clip[nFrames / targetDuration,
      {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];

    indices = Round[Subdivide[2, n, actualNFrames - 1]];
    indices = Max[2, #] & /@ indices;

    Print["  Rendering ", Length[indices], " time-series frames at ",
          FmtN[frameRate, 3], " fps (", FmtN[Length[indices] / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];
    frames = RenderIterateFrame[trajectory, #, r, preset] & /@ indices;

    ExportGIF[frames, outGIF, frameRate];
    {actualNFrames, frameRate}
  ];

(* ========================================================
   dynamical/src/animate.wl — Bifurcation diagram and
   time-series animation export
   ======================================================== *)


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

AnimateSweepBifurcation[sweepModel_Association, eventRs_Association,
                        outGIF_String, Optional[nFrames_Integer, 60]] :=
  Module[{rValues, attractors, nSteps, indices, frames, eventRVals},
    rValues    = sweepModel["rValues"];
    attractors = sweepModel["attractors"];
    nSteps     = Length[rValues];
    eventRVals = Values[eventRs];

    indices = Round[Subdivide[1, nSteps, nFrames - 1]];
    indices = Max[1, #] & /@ indices;

    Print["  Rendering ", Length[indices], " bifurcation-diagram frames..."];
    frames = RenderSweepFrame[rValues, attractors, #, eventRVals] & /@ indices;

    ExportGIF[frames, outGIF, 12]
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

AnimateIterateTimeSeries[iterateModel_Association, outGIF_String,
                         Optional[nFrames_Integer, 60]] :=
  Module[{trajectory, n, r, preset, indices, frames},
    trajectory = iterateModel["trajectory"];
    n       = Length[trajectory];
    r       = iterateModel["r"];
    preset  = iterateModel["preset"];

    indices = Round[Subdivide[2, n, nFrames - 1]];
    indices = Max[2, #] & /@ indices;

    Print["  Rendering ", Length[indices], " time-series frames..."];
    frames = RenderIterateFrame[trajectory, #, r, preset] & /@ indices;

    ExportGIF[frames, outGIF, 12]
  ];

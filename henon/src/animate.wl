(* ========================================================
   henon/src/animate.wl — Hénon attractor / sweep / reverse
   visualisation

   attractor: a growing point-cloud on the map's native (x,y)
   plane, lorenz/'s progressive-reveal convention adapted from a
   continuous line (lorenz's ODE trajectory) to discrete points
   (Hénon's map has no "in between" — only iterates), which is
   also where the fractal cross-section becomes visible as more
   points accumulate.

   sweep: a bifurcation diagram, direct dynamical/RenderSweepFrame
   adaptation (x column of each a-step's settled points plotted
   against a, moving cursor + dashed event lines).

   reverse: a single static plot with the three phases (forward,
   reversed, inverse-demo) colour-coded on top of each other, since
   the reversed and inverse-demo phases occupy the SAME (x,y)
   points as the forward phase — the interesting thing to see is
   that they coincide, not that they trace a different path.
   ======================================================== *)


(* ExportAttractorAnimation/AnimateSweepBifurcation used to export at a
   fixed frame rate (12 fps) with a frame count decoupled from how long
   the matching WAV actually plays once its spoken intro is included
   (measured: henon_attractor.gif 8.0s vs henon_attractor.wav 28.57s;
   henon_sweep.gif 19.92s vs henon_sweep.wav 140.33s). targetDuration
   below is the actual total WAV duration (main.wl/experiments.wl build
   the audio, including its spoken intro, before rendering the GIF, so
   this value is known exactly). nFrames is a RENDER BUDGET: frameRate
   is solved as nFrames/targetDuration then clamped to
   [$HenonMinGifFps, $HenonMaxGifFps] so the frame COUNT flexes at the
   clamp boundary, keeping actual playback duration exactly
   targetDuration — same pattern as lorenz/src/animate.wl's
   ExportAnimation. Sweep mode has only as many distinct bifurcation-
   diagram states as a_steps (discrete Reynolds-style sweep points, no
   "in between"); when the render budget exceeds that, Subdivide's
   rounding holds a state across consecutive frames rather than
   erroring, same as fluid's AnimateStrouhal. *)
$HenonMinGifFps = 2;
$HenonMaxGifFps = 30;
$HenonGifFrameBudget = 150;

HenonGifRate[targetDuration_?NumericQ, nFrames_:$HenonGifFrameBudget] :=
  Clip[nFrames / targetDuration, {$HenonMinGifFps, $HenonMaxGifFps}];


(* ── shared colour ramp (attractor + sweep) ────────────────────────
   Matches lorenz/'s blue -> cyan -> orange -> red gradient
   (early -> recent), duplicated per the same no-shared-src/
   convention noted in sonify.wl. *)
HenonTrajectoryColour[frac_?NumericQ] :=
  Blend[{RGBColor[0.1, 0.2, 0.8],
         RGBColor[0.1, 0.7, 0.9],
         RGBColor[1.0, 0.6, 0.1],
         RGBColor[0.9, 0.1, 0.1]}, frac];


(* ── attractor mode ─────────────────────────────────────────────── *)

ComputeAttractorPlotRange[trajectory_List] :=
  Module[{xs, ys, xpad, ypad},
    xs = trajectory[[All, 1]];
    ys = trajectory[[All, 2]];
    xpad = 0.08 * (Max[xs] - Min[xs]);
    ypad = 0.08 * (Max[ys] - Min[ys]);
    {{Min[xs] - xpad, Max[xs] + xpad}, {Min[ys] - ypad, Max[ys] + ypad}}
  ];

RenderAttractorFrame[trajectory_List, k_Integer, plotRange_, title_String:""] :=
  Module[{pts, n, colourGroups, dot},
    pts = trajectory[[1 ;; k]];
    n   = Length[pts];
    colourGroups = MapIndexed[
      {HenonTrajectoryColour[#2[[1]] / n], PointSize[0.006], Point[#1]} &,
      pts
    ];
    dot = {White, PointSize[0.02], Point[Last[pts]]};

    Graphics[
      {colourGroups, dot},
      PlotRange  -> plotRange,
      Background -> GrayLevel[0.08],
      ImageSize  -> {700, 280},
      AspectRatio -> Automatic,
      Frame      -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["x", White, 11], Style["y", White, 11]},
      PlotLabel  -> Style[title, White, 10],
      FrameTicks -> None
    ]
  ];

(* ExportAttractorAnimation — growing point-cloud GIF, lorenz-style
   evenly-spaced frame indices always ending at the full point set. *)
ExportAttractorAnimation[trajectory_List, filePath_String, targetDuration_?NumericQ,
                         nFrames_:$HenonGifFrameBudget, title_String:"Hénon Attractor"] :=
  Module[{plotRange, frameRate, actualNFrames, indices, frames},
    frameRate     = HenonGifRate[targetDuration, nFrames];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];
    plotRange = ComputeAttractorPlotRange[trajectory];
    indices = Round[Subdivide[1, Length[trajectory], actualNFrames - 1]];
    indices = Max[2, #] & /@ indices;
    Print["  Rendering ", Length[indices], " frames at ", N[frameRate], " fps (",
          N[Length[indices] / frameRate], "s, matching audio duration ", N[targetDuration], "s)..."];
    frames = RenderAttractorFrame[trajectory, #, plotRange, title] & /@ indices;
    ExportGIF[frames, filePath, frameRate];
    {actualNFrames, frameRate}
  ];

(* ExportAttractorPNG — full static attractor, all points, sized and
   coloured so the fractal banded structure is legible. *)
ExportAttractorPNG[trajectory_List, filePath_String, title_String:"Hénon Attractor"] :=
  Module[{plotRange, frame},
    plotRange = ComputeAttractorPlotRange[trajectory];
    frame = RenderAttractorFrame[trajectory, Length[trajectory], plotRange, title];
    EnsureDir[filePath];
    Export[filePath, frame, "PNG"];
    filePath
  ];


(* ── sweep mode: bifurcation diagram ────────────────────────────── *)

(* RenderSweepFrame — dynamical/RenderSweepFrame adapted for {x,y}
   attractor points instead of scalar x: plots the x-COLUMN of each
   a-step's settled points against a. Accumulates all steps up to
   upToStep, draws a red cursor line at the current a, and dashed
   grey lines at each named landmark a-value. *)
RenderSweepFrame[aValues_List, attractors_List, upToStep_Integer, landmarks_Association,
                 fullYRange_List] :=
  Module[{pts, cursorA, eventLines, plotRange, yLo, yHi},
    pts = Flatten[
      Table[Map[{aValues[[k]], #[[1]]} &, attractors[[k]]], {k, upToStep}],
      1
    ];
    cursorA = aValues[[upToStep]];
    {yLo, yHi} = fullYRange;
    plotRange = {{First[aValues], Last[aValues]}, {yLo, yHi}};

    eventLines = Map[
      With[{ea = landmarks[#]},
        If[NumericQ[ea] && ea >= First[aValues] && ea <= cursorA,
          {Dashed, GrayLevel[0.5], Line[{{ea, yLo}, {ea, yHi}}]},
          {}
        ]
      ] &,
      {"first_bifurcation", "chaos_onset", "periodic_window"}
    ];

    Graphics[
      {{GrayLevel[0.85], PointSize[0.0012], Point[pts]},
       eventLines,
       {Red, Thickness[0.003], Line[{{cursorA, yLo}, {cursorA, yHi}}]}},
      PlotRange  -> plotRange,
      AspectRatio -> 420/700,
      Background -> GrayLevel[0.05],
      ImageSize  -> {700, 420},
      Frame      -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["a", White, 11], Style["x", White, 11]},
      FrameTicks -> True
    ]
  ];

ComputeSweepYRange[attractors_List] :=
  Module[{allX, pad},
    allX = Flatten[Map[#[[All, 1]] &, attractors]];
    pad = 0.08 * (Max[allX] - Min[allX]);
    {Min[allX] - pad, Max[allX] + pad}
  ];

AnimateSweepBifurcation[sweepModel_Association, landmarks_Association, filePath_String,
                        targetDuration_?NumericQ, nFrames_:$HenonGifFrameBudget] :=
  Module[{aValues, attractors, nSteps, yRange, frameRate, actualNFrames, indices, frames},
    aValues    = sweepModel["aValues"];
    attractors = sweepModel["attractors"];
    nSteps     = Length[aValues];
    yRange     = ComputeSweepYRange[attractors];
    frameRate     = HenonGifRate[targetDuration, nFrames];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];
    (* nSteps discrete a-steps are the only distinct visual states;
       Subdivide's rounding naturally holds a state across consecutive
       frames when actualNFrames exceeds nSteps - 1. *)
    indices = Clip[Round[Subdivide[2, nSteps, actualNFrames - 1]], {2, nSteps}];
    Print["  Rendering ", Length[indices], " bifurcation-diagram frames at ", N[frameRate],
          " fps (", N[Length[indices] / frameRate], "s, matching audio duration ", N[targetDuration], "s)..."];
    frames = RenderSweepFrame[aValues, attractors, #, landmarks, yRange] & /@ indices;
    ExportGIF[frames, filePath, frameRate];
    {actualNFrames, frameRate}
  ];

ExportSweepPNG[sweepModel_Association, landmarks_Association, filePath_String] :=
  Module[{aValues, attractors, nSteps, yRange, frame},
    aValues    = sweepModel["aValues"];
    attractors = sweepModel["attractors"];
    nSteps     = Length[aValues];
    yRange     = ComputeSweepYRange[attractors];
    frame = RenderSweepFrame[aValues, attractors, nSteps, landmarks, yRange];
    EnsureDir[filePath];
    Export[filePath, frame, "PNG"];
    filePath
  ];


(* ── reverse mode: three-phase overlay ──────────────────────────── *)

(* ExportReversePNG — the forward segment as a faint grey path with
   markers, the reversed replay's points overlaid in blue (same
   locations, confirming Reverse[] changed only order not position),
   and the inverse-demo's recovered points overlaid in orange
   directly on top of the corresponding original forward points —
   the "proof" is that orange lands exactly on grey. A single static
   plot rather than a GIF: what matters here is spatial coincidence,
   which a still image shows more clearly than an animation would. *)
(* NOTE: consecutive forward-segment points are NOT connected with a
   path line across the FULL segment — adjacent iterates of a chaotic
   map are not adjacent in (x,y) space (that's what "chaotic" means),
   so a line through all 41+ points is just visual noise, unlike
   lorenz's genuinely continuous ODE flow. Only the short highlighted
   subsequence actually used in the inverse-map demo gets a connecting
   line, since that handful of points is small enough to read as a
   path rather than a scribble. *)
ExportReversePNG[reverseModel_Association, filePath_String] :=
  Module[{fwd, inv, expected, plotRange, xs, ys, xpad, ypad,
          fwdPts, highlightPath, highlightPts, invPts, frame},
    fwd      = reverseModel["forwardSeg"];
    inv      = reverseModel["inverseDemo"];
    expected = reverseModel["inverseDemoExpected"];  (* = highlighted subsequence, oldest-first *)

    xs = fwd[[All, 1]]; ys = fwd[[All, 2]];
    xpad = 0.1 * (Max[xs] - Min[xs]); ypad = 0.1 * (Max[ys] - Min[ys]);
    plotRange = {{Min[xs] - xpad, Max[xs] + xpad}, {Min[ys] - ypad, Max[ys] + ypad}};

    fwdPts        = {GrayLevel[0.5], PointSize[0.005], Point[fwd]};
    highlightPath = {White, Thin, Line[expected]};
    highlightPts  = {White, PointSize[0.008], Point[expected]};
    invPts        = {Orange, PointSize[0.013], Point[inv]};

    frame = Graphics[
      {fwdPts, highlightPath, highlightPts, invPts},
      PlotRange   -> plotRange,
      AspectRatio -> Automatic,
      Background  -> GrayLevel[0.08],
      ImageSize   -> {620, 380},
      Frame       -> True,
      FrameStyle  -> Directive[White, Thin],
      FrameLabel  -> {Style["x", White, 11], Style["y", White, 11]},
      PlotLabel   -> Style[
        "Hénon reverse: grey = full forward segment; white = last " <>
        ToString[Length[expected]] <> " points (path shown); orange = " <>
        "inverse-map-recovered points (should sit exactly on white)",
        White, 9],
      FrameTicks  -> None
    ];
    EnsureDir[filePath];
    Export[filePath, frame, "PNG"];
    filePath
  ];

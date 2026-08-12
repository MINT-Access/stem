(* ========================================================
   src/animate.wl — Lorenz attractor animation export

   Renders the growing trajectory as an animated GIF.
   The path is drawn in 3D projection (x-z plane, the
   classic "butterfly" view), with a colour gradient from
   cool blue (early) to red (recent) so the direction of
   travel is immediately readable.

   Optionally renders TWO trajectories side by side to
   visualise the butterfly effect.
   ======================================================== *)


(* Sane bounds on GIF playback frame rate — see ExportAnimation for how
   these get used to keep animation/audio duration in sync without
   forcing an absurdly fast or glacial frame rate at the extremes. *)
$MinAnimationFps = 2;
$MaxAnimationFps = 30;


(* ProjectXZ
   Project a {t,x,y,z} point onto the x-z plane (classic view). *)

ProjectXZ[pt_] := {pt[[2]], pt[[4]]}


(* TrajectoryColour
   Maps a fractional position along the trajectory (0..1)
   to a colour: deep blue → cyan → orange → red. *)

TrajectoryColour[frac_?NumericQ] :=
  Blend[{RGBColor[0.1,0.2,0.8],
         RGBColor[0.1,0.7,0.9],
         RGBColor[1.0,0.6,0.1],
         RGBColor[0.9,0.1,0.1]}, frac]


(* RenderFrame
   Draws the trajectory up to index k, coloured by time.
   plotRange — fixed {{xmin,xmax},{zmin,zmax}} for stability. *)

RenderFrame[solution_List, k_Integer, plotRange_, title_String:""] :=
  Module[
    {pts, n, segSize, segments, lines, dot},

    pts    = ProjectXZ /@ solution[[1 ;; k]];
    n      = Length[pts];
    segSize = Max[1, Floor[n / 200]];   (* ~200 colour segments *)

    segments = Partition[pts, segSize + 1, segSize, {1,1}];

    lines = MapIndexed[
      {TrajectoryColour[#2[[1]] / Length[segments]],
       Thickness[0.003],
       Line[#1]
      } &,
      segments
    ];

    (* Current position marker *)
    dot = {White, PointSize[0.018], Point[Last[pts]]};

    Graphics[
      {lines, dot},
      PlotRange   -> plotRange,
      Background  -> GrayLevel[0.08],
      ImageSize   -> {500, 420},
      Frame       -> True,
      FrameStyle  -> Directive[White, Thin],
      FrameLabel  -> {
        Style["x", White, 11],
        Style["z", White, 11]
      },
      PlotLabel   -> Style[title, White, 10],
      FrameTicks  -> None
    ]
  ]


(* ComputePlotRange
   Computes a fixed plot range from the full solution
   so the view does not jump between frames. *)

ComputePlotRange[solution_List] :=
  Module[{xs, zs, xpad, zpad},
    xs   = solution[[All, 2]];
    zs   = solution[[All, 4]];
    xpad = 0.05 * (Max[xs] - Min[xs]);
    zpad = 0.05 * (Max[zs] - Min[zs]);
    {{Min[xs] - xpad, Max[xs] + xpad},
     {Min[zs] - zpad, Max[zs] + zpad}}
  ]


(* ExportAnimation
   Builds frames and writes an animated GIF whose PLAYBACK DURATION
   matches targetDuration — normally the same trajectory duration
   (solution[[-1,1]]) used to size the accompanying WAV, so the GIF and
   its sonification stay in sync instead of the GIF racing through the
   whole trajectory in a few seconds while the audio plays for the
   simulation's real length.

   nFrames is a RENDER BUDGET, not a literal frame count: frameRate is
   solved as nFrames/targetDuration and then clamped to
   [$MinAnimationFps, $MaxAnimationFps] (2-30 fps) so a very short
   trajectory doesn't demand a strobing frame rate and a very long one
   doesn't demand an implausibly slow one — the frame COUNT is what
   flexes at the clamp boundary (recomputed as Round[frameRate *
   targetDuration]) so the actual playback duration always equals
   targetDuration exactly, not just approximately.

   solution      — output of SolveLorenz
   filePath      — destination, e.g. "output/lorenz_animation.gif"
   targetDuration — desired GIF playback length in seconds
   nFrames       — frame-count budget at the nominal rate (default 150)
   title         — optional label shown on the animation

   Returns {actualNFrames, frameRate} so callers can report what was
   actually rendered (STEMDescribeGIF wants both). *)

ExportAnimation[solution_List, filePath_String, targetDuration_?NumericQ,
                nFrames_:150, title_String:"Lorenz Attractor"] :=
  Module[
    {plotRange, indices, frames, frameRate, actualNFrames},

    frameRate = Clip[nFrames / targetDuration,
      {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];

    plotRange = ComputePlotRange[solution];

    (* Indices into solution, evenly spaced, always ending at last point *)
    indices = Round[Subdivide[1, Length[solution], actualNFrames - 1]];
    indices = Max[2, #] & /@ indices;   (* at least 2 points to draw *)

    Print["  Rendering ", Length[indices], " frames at ", FmtN[frameRate, 3],
          " fps (", FmtN[Length[indices] / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];

    frames = RenderFrame[solution, #, plotRange, title] & /@ indices;

    ExportGIF[frames, filePath, frameRate];
    {actualNFrames, frameRate}
  ]


(* ExportDualAnimation
   Side-by-side animation of two trajectories (butterfly effect).
   sol1, sol2 — outputs of SolveLorenzPair.
   targetDuration, nFrames — same meaning and sync purpose as in
   ExportAnimation; the accompanying WAV is sonified from sol1, so
   callers should pass sol1[[-1,1]] as targetDuration. *)

ExportDualAnimation[sol1_List, sol2_List, filePath_String,
                    targetDuration_?NumericQ, nFrames_:150] :=
  Module[
    {allPts, plotRange, indices, frames, frameRate, actualNFrames},

    frameRate = Clip[nFrames / targetDuration,
      {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];

    (* Compute a shared plot range covering both trajectories *)
    allPts   = Join[sol1, sol2];
    plotRange = ComputePlotRange[allPts];

    indices = Round[Subdivide[1, Length[sol1], actualNFrames - 1]];
    indices = Max[2, #] & /@ indices;

    Print["  Rendering ", Length[indices], " dual frames at ", FmtN[frameRate, 3],
          " fps (", FmtN[Length[indices] / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];

    frames = Map[
      Function[k,
        GraphicsGrid[
          {{
            RenderFrame[sol1, Min[k, Length[sol1]], plotRange,
              "Trajectory 1"],
            RenderFrame[sol2, Min[k, Length[sol2]], plotRange,
              "Trajectory 2 (+0.001)"]
          }},
          Background  -> GrayLevel[0.08],
          ImageSize   -> {900, 380},
          Spacings    -> {0, 0}
        ]
      ],
      indices
    ];

    ExportGIF[frames, filePath, frameRate];
    {actualNFrames, frameRate}
  ]

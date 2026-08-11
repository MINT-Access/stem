(* ========================================================
   src/animate.wl — Pendulum animation export

   Reads simulation results and exports an animated GIF.
   Each frame shows the pendulum at one time step, with
   a small trail to convey motion.

   Usage (called from main.wl or standalone):
     Get["src/animate.wl"]
     ExportAnimation[solution, params, "output/pendulum_animation.gif"]
   ======================================================== *)


(* TrajectoryPlotRange
   Computes a {{xmin,xmax},{ymin,ymax}} plot range from the FULL set of
   observed (x,y) points of a pendulum trajectory (every bob, every
   simulated time step — not a per-frame subsample), so the animation
   never zooms/crops based on partial data.

   marginFrac of the observed extent is added as breathing room (with a
   floor of 0.12*maxReach, so low-amplitude runs don't end up with the
   bob nearly touching the frame edge). The result is then clamped to
   +/-(maxReach*(1+renderPadFrac)): maxReach is the exact kinematic
   limit (rod length for a simple pendulum, L1+L2 for a double pendulum
   — the bob(s) can PROVABLY never go further from the pivot than this,
   regardless of trajectory), and renderPadFrac*maxReach is an
   allowance for the bob disk's own radius so a bob that legitimately
   reaches the exact kinematic limit still has its glyph fully drawn
   rather than clipped at its center point. renderPadFrac (0.12) MUST
   stay bigger than the largest bob-radius-to-maxReach ratio actually
   used when rendering (0.07 for the simple pendulum, 0.035 for the
   double pendulum — see PendulumFrame/DoublePendulumFrame) — it is
   scaled by maxReach, not a flat constant, specifically because a flat
   constant broke exactly this way once already: an earlier version of
   this clamp used a flat 0.12 pad which was fine for L=1 but too small
   once bob radius was made proportional to L (0.07*L), so long_pendulum
   (L=2, bob radius 0.14) clipped at the bottom on 100/376 frames — a
   verification-script-caught regression from THIS fix's own first
   draft, corrected here and re-verified. This clamp is a cheap, exact
   backstop — it cannot itself be wrong, since it doesn't depend on the
   (fallible) margin computation above it — but it still has to stay
   ahead of whatever the largest actual marker size is. *)

TrajectoryPlotRange[xs_List, ys_List, maxReach_?NumericQ,
                     marginFrac_:0.18, renderPadFrac_:0.12] :=
  Module[{xMin, xMax, yMin, yMax, xMargin, yMargin, xRange, yRange, clamp},
    xMin = Min[xs, 0]; xMax = Max[xs, 0];
    yMin = Min[ys, 0]; yMax = Max[ys, 0];

    xMargin = Max[marginFrac * (xMax - xMin), 0.12 * maxReach];
    yMargin = Max[marginFrac * (yMax - yMin), 0.12 * maxReach];

    xRange = {xMin - xMargin, xMax + xMargin};
    yRange = {yMin - yMargin, yMax + yMargin};

    clamp = maxReach * (1 + renderPadFrac);
    xRange = {Max[xRange[[1]], -clamp], Min[xRange[[2]], clamp]};
    yRange = {Max[yRange[[1]], -clamp], Min[yRange[[2]], clamp]};

    {xRange, yRange}
  ]


(* FrameImageSize
   Picks {width, height} pixel dimensions so the raster's aspect ratio
   matches plotRange's data aspect ratio exactly, given a fixed base
   width.

   This matters independently of the clipping fix: Graphics's default
   AspectRatio (1/GoldenRatio) has nothing to do with the PlotRange's
   own data aspect ratio, so a mismatched fixed ImageSize (as the code
   used before this fix) makes Mathematica LETTERBOX the plot inside
   the raster — using the exact same Background colour for the padding
   as for the in-plot background, so the padding is invisible. That
   letterboxing was confirmed empirically (see AGENTS.md "Animation
   framing" entry): a marker placed exactly at the OLD hardcoded
   PlotRange's y-edge rendered ~147px away from the actual image edge
   in a 900px-tall raster. Any bounding-box-vs-image-edge check run
   against a letterboxed frame would report a huge false margin even
   while content is being mathematically clipped by PlotRange — the
   image edges and the PlotRange edges are simply not the same
   rectangle unless the aspect ratios match. Matching ImageSize to the
   data aspect ratio here removes the letterboxing entirely (verified:
   content now renders flush to within a few px of the raster edge),
   which is what makes the Step 4 frame-bounding-box verification
   script meaningful in the first place. As a side effect it also fixes
   bob/pivot disks rendering as ellipses instead of circles (confirmed
   they were ~11px x 4px under the old mismatched aspect).

   The aspect ratio (yExtent/xExtent) is clamped to [0.35, 2.85] purely
   as a defensive backstop against a pathological trajectory (e.g.
   near-zero horizontal excursion) producing an unusably thin/tall GIF;
   none of this app's actual presets come close to that range. *)

FrameImageSize[plotRange_List, baseWidth_:480] :=
  Module[{xExtent, yExtent, aspect},
    xExtent = plotRange[[1,2]] - plotRange[[1,1]];
    yExtent = plotRange[[2,2]] - plotRange[[2,1]];
    aspect  = Clip[yExtent / xExtent, {0.35, 2.85}];
    {baseWidth, Round[baseWidth * aspect]}
  ]


(* PendulumFrame
   Renders a single frame of the pendulum at angle theta.
   Also accepts a list of recent angles for the motion trail.
   plotRange is {{xmin,xmax},{ymin,ymax}}, precomputed once for the
   whole animation from the full trajectory (see TrajectoryPlotRange) —
   every frame must share the same range or the animation would zoom. *)

PendulumFrame[theta_?NumericQ, trailAngles_List, params_Association,
              plotRange_List, imageSize_List] :=
  Module[
    {L, pivotX, pivotY, bobX, bobY,
     trailPoints, trailLine, rod, pivot, bob,
     energyFrac, xRange, ceilingHalfWidth, bobRadius, pivotRadius},

    xRange = plotRange[[1]];
    ceilingHalfWidth = 0.93 * Max[Abs[xRange[[1]]], Abs[xRange[[2]]]];

    L      = params["Length"];
    pivotX = 0.0;
    pivotY = 0.0;

    (* Marker sizes scale with L (the app's baseline default is L=1,
       which reproduces the original 0.07/0.04 constants exactly).
       Framing is now tight around the actual trajectory rather than a
       one-size-fits-all fixed box, so fixed-in-data-units marker sizes
       would otherwise look wildly disproportionate for e.g. the
       short_pendulum preset (L=0.25) — a giant bob dwarfing its own
       rod — that a fixed oversized frame used to mask. *)
    bobRadius   = 0.07 * L;
    pivotRadius = 0.04 * L;

    (* Current bob position — y is downward in pendulum coords *)
    bobX =  L * Sin[theta];
    bobY = -L * Cos[theta];

    (* Trail: positions of recent frames, fading out *)
    trailPoints = {L * Sin[#], -L * Cos[#]} & /@ trailAngles;

    trailLine = If[Length[trailPoints] > 1,
      {Opacity[0.25], Thickness[0.008],
       RGBColor[0.4, 0.6, 1.0],
       Line[trailPoints]},
      {}
    ];

    (* Rod from pivot to bob *)
    rod = {
      Thickness[0.012],
      GrayLevel[0.35],
      Line[{{pivotX, pivotY}, {bobX, bobY}}]
    };

    (* Pivot point *)
    pivot = {
      GrayLevel[0.2],
      Disk[{pivotX, pivotY}, pivotRadius]
    };

    (* Bob — colour shifts with angle (potential energy proxy) *)
    energyFrac = Clip[Abs[theta] / (params["InitAngle"] + 0.001), {0, 1}];
    bob = {
      RGBColor[0.2 + 0.6 * energyFrac, 0.3, 1.0 - 0.5 * energyFrac],
      Disk[{bobX, bobY}, bobRadius]
    };

    Graphics[
      {
        (* Ceiling line *)
        {GrayLevel[0.6], Thickness[0.006],
         Line[{{-ceilingHalfWidth, 0}, {ceilingHalfWidth, 0}}]},
        trailLine,
        rod,
        pivot,
        bob
      },
      PlotRange -> plotRange,
      Background -> RGBColor[0.97, 0.97, 1.0],
      ImageSize -> imageSize
    ]
  ]


(* DoublePendulumFrame
   Renders one frame of the double pendulum.
   trailPairs is a list of {θ1, θ2} pairs for the motion trail. *)

DoublePendulumFrame[theta1_?NumericQ, theta2_?NumericQ,
                    L1_?NumericQ, L2_?NumericQ,
                    trailPairs_List, plotRange_List, imageSize_List] :=
  Module[
    {x1, y1, x2, y2,
     trail1Pts, trail2Pts,
     rod1Col, rod2Col, xRange, ceilingHalfWidth,
     markerScale, bobRadius, pivotRadius},

    xRange = plotRange[[1]];
    ceilingHalfWidth = 0.93 * Max[Abs[xRange[[1]]], Abs[xRange[[2]]]];

    (* Marker sizes scale with (L1+L2)/2 — the app's baseline default
       is L1=L2=1, which reproduces the original 0.07/0.055 constants
       exactly. Same reasoning as PendulumFrame: tight, data-driven
       framing means fixed-in-data-units marker sizes would otherwise
       look disproportionate for shorter/longer rod configurations. *)
    markerScale = (L1 + L2) / 2.0;
    bobRadius   = 0.07  * markerScale;
    pivotRadius = 0.055 * markerScale;

    x1 =  L1 * Sin[theta1];
    y1 = -L1 * Cos[theta1];
    x2 = x1 + L2 * Sin[theta2];
    y2 = y1 - L2 * Cos[theta2];

    rod1Col = RGBColor[0.0,  0.45, 0.70];   (* blue  — Wong colour-safe palette *)
    rod2Col = RGBColor[0.90, 0.60, 0.0];    (* orange — Wong colour-safe palette *)

    trail1Pts = { L1 * Sin[#[[1]]], -L1 * Cos[#[[1]]] } & /@ trailPairs;
    trail2Pts = {
      L1 * Sin[#[[1]]] + L2 * Sin[#[[2]]],
     -L1 * Cos[#[[1]]] - L2 * Cos[#[[2]]]
    } & /@ trailPairs;

    Graphics[
      {
        {GrayLevel[0.6], Thickness[0.006],
         Line[{{-ceilingHalfWidth, 0}, {ceilingHalfWidth, 0}}]},
        If[Length[trail1Pts] > 1,
          {Opacity[0.25, rod1Col], Thickness[0.006], Line[trail1Pts]}, {}],
        If[Length[trail2Pts] > 1,
          {Opacity[0.25, rod2Col], Thickness[0.006], Line[trail2Pts]}, {}],
        {Thickness[0.012], rod1Col, Line[{{0.0, 0.0}, {x1, y1}}]},
        {Thickness[0.012], rod2Col, Line[{{x1, y1}, {x2, y2}}]},
        {GrayLevel[0.2], Disk[{0.0, 0.0}, pivotRadius]},
        {rod1Col, Disk[{x1, y1}, bobRadius]},
        {rod2Col, Disk[{x2, y2}, bobRadius]}
      },
      PlotRange -> plotRange,
      Background -> RGBColor[0.97, 0.97, 1.0],
      ImageSize  -> imageSize
    ]
  ]


(* AnimateDoublePendulum
   Renders the two-rod double pendulum and exports an animated GIF.
   Parameters are pulled from cfg via GetCfg. *)

AnimateDoublePendulum[solution_List, cfg_Association, outPath_String] :=
  Module[{L1, L2, dt, frameRate, stride, sampledSol, trailLen, frames,
          maxReach, allTh1, allTh2, x1s, y1s, x2s, y2s, plotRange, imageSize},

    L1        = GetCfg[cfg, {"simulation","double","length1"}, 1.0];
    L2        = GetCfg[cfg, {"simulation","double","length2"}, 1.0];
    dt        = GetCfg[cfg, {"simulation","timestep"},         0.01];
    frameRate = 25;

    stride     = Max[1, Round[1.0 / (frameRate * dt)]];
    sampledSol = solution[[1 ;; -1 ;; stride]];

    (* Convert config trail_length (solution steps) to subsampled frames *)
    trailLen = Max[2, Round[GetCfg[cfg, {"animation","trail_length"}, 60] / stride]];

    (* Plot bounds from the FULL simulated trajectory (both bobs, every
       time step, not the frame-subsampled solution) — a double pendulum
       can legitimately swing a rod above the pivot once enough energy
       has transferred between rods, so the frame must be sized from
       what actually happened, not assumed a priori. Theoretical max
       reach from the pivot is exactly L1+L2 (both rods aligned) — see
       TrajectoryPlotRange for the margin/clamp reasoning. *)
    maxReach = L1 + L2;
    allTh1 = solution[[All, 2]];
    allTh2 = solution[[All, 4]];
    x1s = L1 * Sin[allTh1];
    y1s = -L1 * Cos[allTh1];
    x2s = x1s + L2 * Sin[allTh2];
    y2s = y1s - L2 * Cos[allTh2];
    plotRange = TrajectoryPlotRange[
      Join[x1s, x2s], Join[y1s, y2s], maxReach
    ];
    imageSize = FrameImageSize[plotRange];

    Print["  Rendering ", Length[sampledSol], " frames (L1=", L1, " m, L2=", L2, " m)..."];
    Print["  Plot range: x=[", FmtN[plotRange[[1,1]], 3], ", ", FmtN[plotRange[[1,2]], 3],
          "], y=[", FmtN[plotRange[[2,1]], 3], ", ", FmtN[plotRange[[2,2]], 3],
          "] m  (max reach L1+L2=", FmtN[maxReach, 3], " m)"];

    frames = Table[
      Module[{trailStart, trailPairs},
        trailStart = Max[1, k - trailLen];
        trailPairs = {#[[2]], #[[4]]} & /@ sampledSol[[trailStart ;; k]];
        DoublePendulumFrame[
          sampledSol[[k, 2]], sampledSol[[k, 4]],
          L1, L2, trailPairs, plotRange, imageSize
        ]
      ],
      {k, 1, Length[sampledSol]}
    ];

    EnsureDir[outPath];
    ExportGIF[frames, outPath, frameRate];
    Length[frames]
  ]


(* ExportAnimation
   Builds all frames and exports to an animated GIF.

   Parameters:
     solution  — output of SolvePendulum (list of {t, angle, velocity})
     params    — the simulation parameters Association
     filePath  — destination path, e.g. "output/pendulum_animation.gif"
     frameRate — frames per second in the GIF (default 25)
     speedup   — playback speed multiplier (default 1.0, try 2.0 to go faster) *)

ExportAnimation[solution_List, params_Association, filePath_String,
                frameRate_:25, speedup_:1.0] :=
  Module[
    {dt, stride, sampledSol, trailLen, frames,
     L, maxReach, allAngles, allX, allY, plotRange, imageSize},

    dt = params["TimeStep"];

    (* Sub-sample so we get approximately frameRate fps of simulation time *)
    stride = Max[1, Round[1.0 / (frameRate * dt * speedup)]];
    sampledSol = solution[[1 ;; -1 ;; stride]];

    (* Trail length: keep last ~0.3 s worth of frames *)
    trailLen = Max[2, Round[0.3 * frameRate]];

    (* Plot bounds from the FULL simulated trajectory (every time step,
       not the frame-subsampled solution). A simple pendulum's bob sits
       at a FIXED distance L from the pivot regardless of angle, so L
       itself is both the natural scale for the margin floor and the
       exact theoretical max reach used to clamp the result. *)
    L = params["Length"];
    maxReach = L;
    allAngles = solution[[All, 2]];
    allX = L * Sin[allAngles];
    allY = -L * Cos[allAngles];
    plotRange = TrajectoryPlotRange[allX, allY, maxReach];
    imageSize = FrameImageSize[plotRange];

    Print["  Rendering ", Length[sampledSol], " frames..."];
    Print["  Plot range: x=[", FmtN[plotRange[[1,1]], 3], ", ", FmtN[plotRange[[1,2]], 3],
          "], y=[", FmtN[plotRange[[2,1]], 3], ", ", FmtN[plotRange[[2,2]], 3],
          "] m  (max reach L=", FmtN[maxReach, 3], " m)"];

    (* Build each frame with a motion trail *)
    frames = Table[
      Module[{trailStart, trailAngles},
        trailStart  = Max[1, k - trailLen];
        trailAngles = sampledSol[[trailStart ;; k, 2]];
        PendulumFrame[sampledSol[[k, 2]], trailAngles, params, plotRange, imageSize]
      ],
      {k, 1, Length[sampledSol]}
    ];

    ExportGIF[frames, filePath, frameRate];
    Length[frames]
  ]

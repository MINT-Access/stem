(* ========================================================
   quantum/src/animate.wl — Visualisation for quantum density

   Public API:
     AnimateQuantum[solution, cfg, outDir]
       Returns the number of GIF frames written.

   Outputs:
     {mode}_density.gif  — animated |psi(x,t)|^2, playback duration
                           matched exactly to {mode}_audio.wav (both
                           derived from Last[t], the simulation's real
                           time span — see SonifyQuantum in sonify.wl)
     {mode}_density.png  — 3x3 snapshot grid at equal time intervals
   ======================================================== *)


(* Sane bounds on GIF playback frame rate — mirrors lorenz's
   src/animate.wl. Keeps a short-duration run (few timesteps over a
   short Last[t]) from demanding a strobing frame rate, and a long one
   from demanding an implausibly slow one. Frame COUNT is what flexes
   at the clamp boundary (see AnimateQuantum) so playback duration
   still lands on targetDuration exactly. *)
$MinAnimationFps = 2;
$MaxAnimationFps = 30;


AnimateQuantum[solution_Association, cfg_Association, outDir_String] :=
  Module[{density, xVals, tVals, nt, mode,
          imgW, imgH, targetDuration, frameRate,
          yMax, xMin, xMax,
          frameIndices, nFrames, frames,
          panel9Indices, panels,
          gifPath, pngPath},

    density   = solution["density"];
    xVals     = solution["x"];
    tVals     = solution["t"];
    nt        = Length[tVals];
    mode      = solution["mode"];

    imgW      = GetCfg[cfg, {"animation","imageWidth"},  600];
    imgH      = GetCfg[cfg, {"animation","imageHeight"}, 300];

    yMax = Max[density] * 1.1;
    xMin = Min[xVals];
    xMax = Max[xVals];

    (* GIF playback must match {mode}_audio.wav exactly. SonifyQuantum
       sonifies at duration -> Last[t] (see sonify.wl), so the GIF uses
       the same value here rather than a fixed config frameRate. *)
    targetDuration = Last[tVals];

    (* ── Animated GIF: nt (the number of simulated timesteps) is a
       render budget, not a literal frame count. frameRate is solved
       as nt/targetDuration and clamped to [$MinAnimationFps,
       $MaxAnimationFps]; actualNFrames (nFrames below) is then
       recomputed from the clamped rate so playback duration lands on
       targetDuration exactly, even when the clamp bites. animation.
       frameRate from config is no longer used — see AGENTS.md
       "Animation framing" for why. ── *)
    frameRate    = Clip[nt / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
    nFrames      = Max[2, Round[frameRate * targetDuration]];
    frameIndices = Round[Subdivide[1, nt, nFrames - 1]];

    Print["  Rendering ", nFrames, " frames at ", FmtN[frameRate, 3],
          " fps (", FmtN[nFrames / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];

    frames = Map[
      Function[it,
        ListLinePlot[
          Transpose[{xVals, density[[it]]}],
          PlotRange      -> {{xMin, xMax}, {0, yMax}},
          PlotStyle      -> {Thick, RGBColor[0.3, 0.8, 1.0]},
          Background     -> GrayLevel[0.08],
          PlotLabel      -> Style[
            "t = " <> ToString[NumberForm[tVals[[it]], {4, 2}]],
            White, 11],
          AxesStyle      -> White,
          LabelStyle     -> White,
          Frame          -> True,
          FrameStyle     -> White,
          FrameTicks     -> Automatic,
          FrameTicksStyle -> White,
          ImageSize      -> {imgW, imgH}
        ]
      ],
      frameIndices
    ];

    gifPath = FileNameJoin[{outDir, mode <> "_density.gif"}];
    ExportGIF[frames, gifPath, frameRate];
    STEMDescribeGIF[gifPath, nFrames, frameRate];

    (* ── Static 3x3 PNG: 9 frames at equal time intervals ── *)
    panel9Indices = Round[Subdivide[1, nt, 8]];  (* 9 indices: 1..nt *)

    panels = Map[
      Function[it,
        ListLinePlot[
          Transpose[{xVals, density[[it]]}],
          PlotRange  -> {{xMin, xMax}, {0, yMax}},
          PlotStyle  -> {Thick, RGBColor[0.3, 0.8, 1.0]},
          Background -> GrayLevel[0.08],
          PlotLabel  -> Style[
            "t=" <> ToString[NumberForm[tVals[[it]], {3, 1}]],
            White, 9],
          Axes       -> False,
          Frame      -> True,
          FrameStyle -> White,
          FrameTicks -> None,
          ImageSize  -> 200
        ]
      ],
      panel9Indices
    ];

    pngPath = FileNameJoin[{outDir, mode <> "_density.png"}];
    EnsureDir[pngPath];
    Export[pngPath,
      GraphicsGrid[Partition[panels, 3],
        Background -> GrayLevel[0.08],
        ImageSize  -> 600]];
    Print["  Exported PNG: ", pngPath, " — 3x3 snapshot grid"];

    nFrames
  ]

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


(* GIF timing: frame delay and frame count come from stem-core's
   GIFFramePlan, which clamps the requested rate to 2-30 fps, rounds the
   frame delay to whole centiseconds (what the GIF format stores) and
   derives the frame count from that delay; main.wl then measures both
   files with SyncWAVToGIF. *)


AnimateQuantum[solution_Association, cfg_Association, outDir_String] :=
  Module[{plan, density, xVals, tVals, nt, mode,
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
       as nt/targetDuration and clamped to [2, 30] fps (stem-core GIFFramePlan); actualNFrames (nFrames below) is then
       recomputed from the clamped rate so playback duration lands on
       targetDuration to within half a frame delay, even when the clamp bites. animation.
       frameRate from config is no longer used — see AGENTS.md
       "Animation framing" for why. ── *)
    plan         = GIFFramePlan[targetDuration, nt / targetDuration];
    frameRate    = plan["FrameRate"];
    nFrames      = plan["FrameCount"];
    frameIndices = Round[Subdivide[1, nt, nFrames - 1]];

    Print["  Rendering ", nFrames, " frames at ", FmtDec[frameRate],
          " fps (", FmtDec[plan["FrameDelay"]], " s per frame, ",
        FmtDec[plan["GIFDuration"]], " s in total)."];

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
    ExportGIF[frames, gifPath, plan];
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
    ExportPNG[pngPath,
      GraphicsGrid[Partition[panels, 3],
        Background -> GrayLevel[0.08],
        ImageSize  -> 600]];
    Print["  Exported PNG: ", pngPath, " — 3x3 snapshot grid"];

    nFrames
  ]

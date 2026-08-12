(* ========================================================
   src/animate.wl — Cellular automata animation export

   AnimateCellular[grid3D, cfg, outPath, targetDuration]

   For Game of Life (nRows > 1):
     Renders one ArrayPlot frame per generation and exports
     an animated GIF.  Cell size is derived from canvas size
     and grid dimensions — not hardcoded.  Playback duration is
     matched to targetDuration (the accompanying WAV's exact
     length, generations * base_note_duration — see
     ResolveBaseNoteDuration in sonify.wl) by solving frame rate
     from the render budget nGen/targetDuration and clamping it
     to a sane range; see ExportGIFForLife below.

   For Rule 110 (nRows == 1):
     The spacetime diagram (all generations stacked vertically)
     is exported as a PNG and as a single-frame GIF for pipeline
     consistency.  The full spacetime view is necessary because
     the Rule 110 triangle pattern is only legible as a whole, so
     there is no frame rate to solve for — instead the single
     frame's hold time (its GIF "delay") is set directly to
     targetDuration, so a viewer holding the GIF open for one loop
     sees it for as long as the WAV plays.
   ======================================================== *)


(* Sane bounds on Game-of-Life GIF playback frame rate — mirrors
   lorenz's src/animate.wl. Keeps a very short WAV (few generations,
   large base_note_duration) from demanding a strobing frame rate, and
   a very long one from demanding an implausibly slow one. Frame COUNT
   (subsampled from the nGen generations, see AnimateCellular) is what
   flexes at the clamp boundary so playback duration still lands on
   targetDuration exactly. Not used by the Rule 110 branch, which has
   no frame rate to clamp — see module header above. *)
$MinAnimationFps = 2;
$MaxAnimationFps = 30;


(* CellularFrame
   Renders one generation of a 2D grid as an ArrayPlot.
   Live cells are white, dead cells are black (high contrast). *)

CellularFrame[genGrid_?MatrixQ, cellPx_Integer] :=
  ArrayPlot[
    genGrid,
    ColorRules -> {0 -> Black, 1 -> White},
    ImageSize  -> cellPx * Reverse[Dimensions[genGrid]],
    Frame      -> None,
    PlotRangePadding -> None
  ]


(* AnimateCellular
   Dispatches on grid shape:
     nRows > 1  → animated GIF (frames subsampled from the nGen
                  generations, frame rate solved from targetDuration)
     nRows == 1 → spacetime PNG + single-frame GIF held for
                  targetDuration

   targetDuration is the accompanying WAV's exact duration in seconds
   (generations * base_note_duration — see ResolveBaseNoteDuration in
   sonify.wl; callers compute it via CellularAudioDuration) so GIF and
   WAV playback stay in sync. animation.fps from config is no longer
   used for either branch — see AGENTS.md "Animation framing" for why.

   Returns {actualNFrames, frameRate} for STEMDescribeGIF reporting. *)

AnimateCellular[grid3D_List, cfg_Association, outPath_String, targetDuration_?NumericQ] :=
  Module[{nGen, nRows, nCols, width, height, cellPx,
          frames, spacetime, spacetimePlot, pngPath,
          frameRate, actualNFrames, indices},

    {nGen, nRows, nCols} = Dimensions[grid3D];
    width  = GetCfg[cfg, {"animation","width"},  480];
    height = GetCfg[cfg, {"animation","height"}, 480];

    (* Compute cell pixel size to fill the configured canvas *)
    cellPx = Max[1, Floor[Min[width / nCols, height / nRows]]];

    If[nRows === 1,

      (* ── Rule 110: spacetime diagram ──
         One static frame; its GIF "frame rate" only controls how long
         that single frame is held before the (infinite) loop repeats,
         so set it directly from targetDuration rather than clamping —
         a slow hold isn't a strobing/glacial-playback concern the way
         a multi-frame rate would be. Guard against a degenerate
         (near-zero or negative) targetDuration with a 0.1s floor. *)
      Print["  Building Rule 110 spacetime diagram (", nGen, " gen x ", nCols, " cells)..."];
      STEMSay["Building Rule 110 spacetime diagram"];

      spacetime = grid3D[[All, 1, All]];   (* {nGen, nCols} matrix *)
      spacetimePlot = ArrayPlot[
        spacetime,
        ColorRules -> {0 -> White, 1 -> Black},
        ImageSize  -> {cellPx * nCols, cellPx * nGen},
        Frame      -> None,
        PlotRangePadding -> None
      ];

      pngPath = StringReplace[outPath, ".gif" -> "_spacetime.png"];
      EnsureDir[pngPath];
      Export[pngPath, spacetimePlot, "PNG"];
      Print["  Spacetime PNG — ", pngPath];

      frameRate = 1.0 / Max[targetDuration, 0.1];
      Print["  Single-frame GIF held for ", FmtN[Max[targetDuration, 0.1], 3],
            "s per loop (matching audio duration)..."];

      ExportGIF[{spacetimePlot}, outPath, frameRate];
      {1, frameRate},

      (* ── Game of Life: animated GIF ──
         nGen is a render budget, not a literal frame count: frameRate
         is solved as nGen/targetDuration and clamped to
         [$MinAnimationFps, $MaxAnimationFps], then actualNFrames is
         recomputed as Round[frameRate * targetDuration] so playback
         duration lands on targetDuration exactly even when the clamp
         bites. Frames are indices into the nGen generations, evenly
         subsampled (identical to nGen when unclamped, which is the
         common case at the default 0.06s/generation tempo). *)
      frameRate = Clip[nGen / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
      actualNFrames = Max[2, Round[frameRate * targetDuration]];
      indices = Round[Subdivide[1, nGen, actualNFrames - 1]];

      Print["  Rendering ", Length[indices], " frames (", nRows, "x", nCols,
            " grid, ", cellPx, " px/cell) at ", FmtN[frameRate, 3], " fps (",
            FmtN[Length[indices] / frameRate, 3],
            "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];
      STEMSay["Rendering " <> ToString[Length[indices]] <> " frames"];

      frames = Table[
        (If[Mod[i, 50] === 1 && i > 1,
           STEMSay["Rendered " <> ToString[i-1] <> " of " <>
                   ToString[Length[indices]] <> " frames"]];
         CellularFrame[grid3D[[indices[[i]]]], cellPx]),
        {i, 1, Length[indices]}
      ];

      ExportGIF[frames, outPath, frameRate];
      {actualNFrames, frameRate}
    ]
  ]

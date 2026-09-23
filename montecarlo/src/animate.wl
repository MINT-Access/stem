(* ========================================================
   montecarlo/src/animate.wl — Spin-grid and M(T) GIF animations
   ======================================================== *)


(* GIF timing: frame delay and frame count come from stem-core's
   GIFFramePlan, which clamps the requested rate to 2-30 fps, rounds the
   frame delay to whole centiseconds (what the GIF format stores) and
   derives the frame count from that delay; main.wl then measures both
   files with SyncWAVToGIF. *)


(* RenderGridFrame — spin +1 = white, spin -1 = black. (grid+1)/2 maps
   {-1,1} to {0,1} so GrayLevel can render it directly. *)
RenderGridFrame[grid_List, title_String] :=
  ArrayPlot[(grid + 1) / 2,
    ColorFunction -> GrayLevel, ColorFunctionScaling -> False,
    PlotLabel  -> Style[title, White, 12],
    Background -> Black,
    ImageSize  -> {420, 420},
    Frame      -> False,
    Mesh       -> None
  ];

(* RenderMCurveFrame — M(T) traced left-to-right as the sweep advances,
   a moving cursor at the current point, and a dashed red line at T_c. *)
RenderMCurveFrame[TVals_List, MVals_List, upToIdx_Integer, Tc_?NumericQ] :=
  Module[{pts},
    pts = Transpose[{TVals[[1 ;; upToIdx]], MVals[[1 ;; upToIdx]]}];
    Graphics[
      {
        {RGBColor[0.2, 0.5, 0.9], Thickness[0.004], Line[pts]},
        {Dashed, Red, Thickness[0.003], Line[{{Tc, -1.0}, {Tc, 1.0}}]},
        {Yellow, PointSize[0.02], Point[Last[pts]]}
      },
      PlotRange  -> {{Min[TVals], Max[TVals]}, {-1.0, 1.0}},
      Background -> Black,
      ImageSize  -> {420, 200},
      Frame      -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["T", White, 10], Style["M", White, 10]}
    ]
  ];

(* AnimateSweep — two-panel: spin grid on top, M(T) curve below.

   targetDuration should be the matching WAV's actual total duration
   (spoken intro + pause + sonified sweep, i.e. main.wl's totalDur /
   experiments.wl's sonifyResult["totalDuration"]) computed just before
   this call. nFrames is a RENDER BUDGET, not a literal frame count:
   frameRate is solved as nFrames/targetDuration and clamped to
   [2, 30] fps (stem-core GIFFramePlan) so a short run doesn't demand a
   strobing frame rate and a long one doesn't demand an implausibly
   slow one — the frame COUNT is what flexes at the clamp boundary
   (recomputed as Round[frameRate * targetDuration]) so actual playback
   duration equals targetDuration to within half a frame delay. Returns
   {actualNFrames, frameRate} so callers can report real numbers via
   STEMDescribeGIF. *)
AnimateSweep[sweepResult_Association, Tc_?NumericQ, outGIF_String,
            targetDuration_?NumericQ, Optional[nFrames_Integer, 150]] :=
  Module[{plan, grids, TVals, MVals, nRows, indices, frames, frameRate, actualNFrames},
    grids  = sweepResult["grids"];
    TVals  = sweepResult["T"];
    MVals  = sweepResult["M"];
    nRows  = Length[grids];

    plan      = GIFFramePlan[targetDuration, nFrames / targetDuration];
    frameRate = plan["FrameRate"];
    actualNFrames = plan["FrameCount"];

    indices = Round[Subdivide[1, nRows, actualNFrames - 1]];
    indices = Max[1, #] & /@ indices;

    Print["  Rendering ", Length[indices], " sweep frames at ", FmtDec[frameRate],
          " fps (", FmtDec[plan["FrameDelay"]], " s per frame, ",
        FmtDec[plan["GIFDuration"]], " s in total)."];
    frames = Table[
      Module[{idx = indices[[k]], title, gridPlot, curvePlot},
        title = "T = " <> ToString[NumberForm[TVals[[idx]], {4, 3}]] <>
                "   |M| = " <> ToString[NumberForm[Abs[MVals[[idx]]], {4, 3}]];
        gridPlot  = RenderGridFrame[grids[[idx]], title];
        curvePlot = RenderMCurveFrame[TVals, MVals, idx, Tc];
        GraphicsColumn[{gridPlot, curvePlot}, Background -> Black, Spacings -> 0.3]
      ],
      {k, Length[indices]}
    ];
    ExportGIF[frames, outGIF, plan];
    {Length[frames], frameRate}
  ];

(* AnimateCritical — single panel, spin grid at fixed T = T_c.
   Same duration-sync contract as AnimateSweep (see its docstring).
   Returns {actualNFrames, frameRate}. *)
AnimateCritical[critResult_Association, Tc_?NumericQ, outGIF_String,
                targetDuration_?NumericQ, Optional[nFrames_Integer, 150]] :=
  Module[{plan, grids, nRows, indices, frames, frameRate, actualNFrames},
    grids = critResult["grids"];
    nRows = Length[grids];

    plan      = GIFFramePlan[targetDuration, nFrames / targetDuration];
    frameRate = plan["FrameRate"];
    actualNFrames = plan["FrameCount"];

    indices = Round[Subdivide[1, nRows, actualNFrames - 1]];
    indices = Max[1, #] & /@ indices;

    Print["  Rendering ", Length[indices], " critical frames at ", FmtDec[frameRate],
          " fps (", FmtDec[plan["FrameDelay"]], " s per frame, ",
        FmtDec[plan["GIFDuration"]], " s in total)."];
    frames = Table[
      RenderGridFrame[grids[[indices[[k]]]],
        "T = T_c = " <> ToString[NumberForm[Tc, {4, 3}]] <> "   sweep " <> ToString[indices[[k]]]],
      {k, Length[indices]}
    ];
    ExportGIF[frames, outGIF, plan];
    {Length[frames], frameRate}
  ];

(* AnimateQuench — single panel, spin grid coarsening from random noise
   toward large domains. Same duration-sync contract as AnimateSweep
   (see its docstring). Returns {actualNFrames, frameRate}. *)
AnimateQuench[quenchResult_Association, TCold_?NumericQ, outGIF_String,
             targetDuration_?NumericQ, Optional[nFrames_Integer, 150]] :=
  Module[{plan, grids, nRows, indices, frames, frameRate, actualNFrames},
    grids = quenchResult["grids"];
    nRows = Length[grids];

    plan      = GIFFramePlan[targetDuration, nFrames / targetDuration];
    frameRate = plan["FrameRate"];
    actualNFrames = plan["FrameCount"];

    indices = Round[Subdivide[1, nRows, actualNFrames - 1]];
    indices = Max[1, #] & /@ indices;

    Print["  Rendering ", Length[indices], " quench frames at ", FmtDec[frameRate],
          " fps (", FmtDec[plan["FrameDelay"]], " s per frame, ",
        FmtDec[plan["GIFDuration"]], " s in total)."];
    frames = Table[
      RenderGridFrame[grids[[indices[[k]]]],
        "T_cold = " <> ToString[NumberForm[TCold, {3, 2}]] <> "   sweep " <> ToString[indices[[k]]]],
      {k, Length[indices]}
    ];
    ExportGIF[frames, outGIF, plan];
    {Length[frames], frameRate}
  ];

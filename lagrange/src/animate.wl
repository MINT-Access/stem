(* lagrange/src/animate.wl — CR3BP trajectory GIF and PNG rendering *)

(* GIF playback duration is derived from the target audio duration (see
   LibrationAudioDuration/EscapeAudioDuration in sonify.wl) rather than a
   fixed frame count/rate, so the GIF and its matching WAV play for the
   same length. nFrames below is a RENDER BUDGET, not a literal frame
   count: the frame rate is solved as nFrames/targetDuration and clamped
   to a sane fps range; the frame count then flexes at that clamp so the
   actual playback duration matches targetDuration exactly. *)
$MinAnimationFps = 2;
$MaxAnimationFps = 30;

(* Build a single GIF frame showing the trajectory grown to step nShow.
   mu, lpts, markLP, and preset are for visual annotation. *)
MakeLagrangeFrame[xyAll_List, nShow_Integer, mu_?NumericQ,
                  lpts_Association, markLP_String, preset_String] :=
  Module[{nS = Clip[nShow, {1, Length[xyAll]}], cur, trace},
    cur   = xyAll[[nS]];
    trace = If[nS > 1, xyAll[[1;;nS]], {cur}];
    Graphics[{
      {RGBColor[1.0, 0.95, 0.15], Disk[{-mu, 0.0}, 0.07]},
      {RGBColor[0.9, 0.50, 0.10], Disk[{1-mu, 0.0}, 0.025]},
      {GrayLevel[0.6], PointSize[0.012], Point /@ Values[lpts]},
      {White, FontFamily -> "Helvetica", FontSize -> 7,
       Text["L1", lpts["L1"] + {0.0,  0.08}],
       Text["L2", lpts["L2"] + {0.0,  0.08}],
       Text["L3", lpts["L3"] + {0.0, -0.10}],
       Text["L4", lpts["L4"] + {0.0,  0.08}],
       Text["L5", lpts["L5"] + {0.0, -0.10}]},
      {RGBColor[0.4, 0.9, 0.4], PointSize[0.02], Point[lpts[markLP]]},
      If[Length[trace] > 1,
        {Opacity[0.85], RGBColor[0.2, 0.85, 1.0], AbsoluteThickness[1.2], Line[trace]},
        {}],
      {White, Disk[cur, 0.018]},
      {GrayLevel[0.8], FontSize -> 8,
       Text["CR3BP co-rotating frame   mu=" <> ToString[NumberForm[mu, {5,4}]], {0.0, 1.22}]},
      {GrayLevel[0.6], FontSize -> 7,
       Text[preset, {0.0, -1.22}]}
    },
    Background -> Black,
    PlotRange  -> {{-1.65, 1.65}, {-1.30, 1.30}},
    ImageSize  -> 420,
    Frame      -> False,
    Axes       -> False]
  ];

(* Render GIF and PNG for l4/l5 libration.
   PNG: full static trajectory; GIF: animated traversal whose playback
   duration matches targetDuration (the paired WAV's duration). *)
AnimateLibration[model_Association, outDir_String,
                 lpts_Association, mu_?NumericQ, preset_String,
                 targetDuration_?NumericQ, nFrameBudget_:150] :=
  Module[{xFn, yFn, xV, yV, x0, y0, lPos, lLabel, tEnd,
          frameRate, nFrames, nGIFPts, tGIF, xyGIF, gifFrames, gifPath, pngPath, pngGfx,
          L1, L2, L3, L4, L5},
    xFn    = model["xFn"];
    yFn    = model["yFn"];
    xV     = model["xV"];
    yV     = model["yV"];
    x0     = model["x0"];
    y0     = model["y0"];
    lPos   = model["lPos"];
    lLabel = model["lLabel"];
    tEnd   = model["tEnd"];
    L1 = lpts["L1"]; L2 = lpts["L2"]; L3 = lpts["L3"];
    L4 = lpts["L4"]; L5 = lpts["L5"];

    pngPath = FileNameJoin[{outDir, ToLowerCase[lLabel] <> ".png"}];
    pngGfx  = Graphics[{
      {RGBColor[1.0, 0.95, 0.15], Disk[{-mu, 0.0}, 0.07]},
      {RGBColor[0.9, 0.50, 0.10], Disk[{1-mu, 0.0}, 0.025]},
      {GrayLevel[0.6], PointSize[0.012], Point /@ Values[lpts]},
      {White, FontSize -> 8,
       Text["L1", L1 + {0.0,  0.08}], Text["L2", L2 + {0.0,  0.08}],
       Text["L3", L3 + {0.0, -0.10}], Text["L4", L4 + {0.0,  0.08}],
       Text["L5", L5 + {0.0, -0.10}]},
      {RGBColor[0.4, 0.9, 0.4], PointSize[0.018], Point[lPos]},
      {RGBColor[0.2, 0.85, 1.0], AbsoluteThickness[0.8], Line @ Transpose[{xV, yV}]},
      {RGBColor[1.0, 0.4, 0.0], Disk[{x0, y0}, 0.018]}
    },
    Background -> Black,
    PlotRange  -> {{-1.65, 1.65}, {-1.30, 1.30}},
    ImageSize  -> 500, Frame -> False, Axes -> False];
    EnsureDir[pngPath];
    Export[pngPath, pngGfx, "PNG"];
    Print["  PNG: ", pngPath];

    frameRate = Clip[nFrameBudget / targetDuration,
      {$MinAnimationFps, $MaxAnimationFps}];
    nFrames   = Max[2, Round[frameRate * targetDuration]];
    nGIFPts   = Max[400, 3 * nFrames];
    tGIF      = N @ Rescale[Range[nGIFPts], {1, nGIFPts}, {0, tEnd}];
    xyGIF     = Transpose[{xFn /@ tGIF, yFn /@ tGIF}];
    gifFrames = Table[
      MakeLagrangeFrame[xyGIF, Max[2, Floor[k * nGIFPts / nFrames]],
                        mu, lpts, lLabel, preset],
      {k, nFrames}];
    gifPath = FileNameJoin[{outDir, ToLowerCase[lLabel] <> ".gif"}];
    ExportGIF[gifFrames, gifPath, frameRate];
    Print["  GIF: ", gifPath, " (", nFrames, " frames, ", FmtN[frameRate, 3],
          " fps, ", FmtN[nFrames / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)"];
    {nFrames, frameRate}
  ];

(* Render GIF and PNG for L1 escape.
   PNG: full static trajectory in red; GIF: animated traversal whose
   playback duration matches targetDuration (the paired WAV's duration). *)
AnimateEscape[model_Association, outDir_String,
              lpts_Association, mu_?NumericQ, preset_String,
              targetDuration_?NumericQ, nFrameBudget_:150] :=
  Module[{xFn, yFn, xV, yV, x0, y0, tActual,
          frameRate, nFrames, nGIFPts, tGIF, xyGIF, gifFrames, gifPath, pngPath, pngGfx,
          L1, L2, L3, L4, L5},
    xFn     = model["xFn"];
    yFn     = model["yFn"];
    xV      = model["xV"];
    yV      = model["yV"];
    x0      = model["x0"];
    y0      = model["y0"];
    tActual = model["tActual"];
    L1 = lpts["L1"]; L2 = lpts["L2"]; L3 = lpts["L3"];
    L4 = lpts["L4"]; L5 = lpts["L5"];

    pngPath = FileNameJoin[{outDir, "l1.png"}];
    pngGfx  = Graphics[{
      {RGBColor[1.0, 0.95, 0.15], Disk[{-mu, 0.0}, 0.07]},
      {RGBColor[0.9, 0.50, 0.10], Disk[{1-mu, 0.0}, 0.025]},
      {GrayLevel[0.6], PointSize[0.012], Point /@ Values[lpts]},
      {White, FontSize -> 8,
       Text["L1", L1 + {0.0,  0.08}], Text["L2", L2 + {0.0,  0.08}],
       Text["L3", L3 + {0.0, -0.10}], Text["L4", L4 + {0.0,  0.08}],
       Text["L5", L5 + {0.0, -0.10}]},
      {RGBColor[0.9, 0.3, 0.9], PointSize[0.018], Point[L1]},
      {RGBColor[1.0, 0.4, 0.4], AbsoluteThickness[0.8], Line @ Transpose[{xV, yV}]},
      {RGBColor[1.0, 0.4, 0.0], Disk[{x0, y0}, 0.018]}
    },
    Background -> Black,
    PlotRange  -> {{-1.65, 1.65}, {-1.30, 1.30}},
    ImageSize  -> 500, Frame -> False, Axes -> False];
    EnsureDir[pngPath];
    Export[pngPath, pngGfx, "PNG"];
    Print["  PNG: ", pngPath];

    frameRate = Clip[nFrameBudget / targetDuration,
      {$MinAnimationFps, $MaxAnimationFps}];
    nFrames   = Max[2, Round[frameRate * targetDuration]];
    nGIFPts   = Max[400, 3 * nFrames];
    tGIF      = N @ Rescale[Range[nGIFPts], {1, nGIFPts}, {0, tActual}];
    xyGIF     = Transpose[{xFn /@ tGIF, yFn /@ tGIF}];
    gifFrames = Table[
      MakeLagrangeFrame[xyGIF, Max[2, Floor[k * nGIFPts / nFrames]],
                        mu, lpts, "L1", preset],
      {k, nFrames}];
    gifPath = FileNameJoin[{outDir, "l1.gif"}];
    ExportGIF[gifFrames, gifPath, frameRate];
    Print["  GIF: ", gifPath, " (", nFrames, " frames, ", FmtN[frameRate, 3],
          " fps, ", FmtN[nFrames / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)"];
    {nFrames, frameRate}
  ];

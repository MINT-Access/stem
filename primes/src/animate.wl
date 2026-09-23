(* ========================================================
   primes/animate.wl — Visualisation for prime number patterns

   Public API:
     AnimatePrimes[model, cfg, outDir]
       Dispatches on model["mode"]:
         "ulam" → PNG + single-frame GIF + centre zoom
         "gaps" → animated BarChart GIF (progressive reveal)
   ======================================================== *)


(* Render budget: target number of progressive-reveal frames before the
   fps/duration solve below adjusts the actual count. Not a hard cap —
   see AnimateGaps. *)
$GapsFrameBudget = 50;


(* ── Ulam spiral visualisation ────────────────────────── *)

AnimateUlam[model_Association, cfg_Association, outDir_String] :=
  Module[{plan, grid, n, colorPrimes, colorComposite,
          width, height,
          primeColor, compositeColor,
          primePlot, mainPath, gifPath,
          zoom, half, centre, zoomGrid, zoomPlot, zoomPath},

    grid           = model["grid"];
    n              = model["size"];
    colorPrimes    = GetCfg[cfg, {"simulation","ulam","color_primes"},    "white"];
    colorComposite = GetCfg[cfg, {"simulation","ulam","color_composite"}, "black"];
    width  = GetCfg[cfg, {"animation","width"},  600];
    height = GetCfg[cfg, {"animation","height"}, 600];

    primeColor     = If[colorPrimes    === "white", White, Black];
    compositeColor = If[colorComposite === "black", Black, White];

    (* ── Full spiral PNG ── *)
    Print["  Rendering ", n, "x", n, " Ulam spiral..."];
    primePlot = ArrayPlot[grid,
      ColorRules       -> {1 -> primeColor, 0 -> compositeColor},
      ImageSize        -> {width, height},
      Frame            -> None,
      PlotRangePadding -> None
    ];

    mainPath = FileNameJoin[{outDir, "ulam_spiral.png"}];
    EnsureDir[mainPath];
    Export[mainPath, primePlot, "PNG"];
    Print["  Spiral PNG: ", mainPath];

    (* Single-frame GIF, held for the length of the row-scan audio
       ($UlamScanDuration, sonify.wl) the same way cellular's Rule 110
       spacetime GIF is held for its audio -- previously it was shown
       for one 12 fps frame (0.08 s) per loop. *)
    gifPath = FileNameJoin[{outDir, "ulam_spiral.gif"}];
    plan = GIFFramePlan[$UlamScanDuration, 1.0 / $UlamScanDuration,
                        "MinFps" -> 0, "MinFrames" -> 1, "MaxFrames" -> 1];
    ExportGIF[{primePlot}, gifPath, plan];
    STEMDescribeGIF[gifPath, 1, plan["FrameRate"]];

    (* ── Zoomed 31×31 centre region with visible cell borders ── *)
    zoom   = 31;
    half   = Floor[zoom / 2];
    centre = Ceiling[n / 2];

    zoomGrid = grid[[centre - half ;; centre + half,
                      centre - half ;; centre + half]];

    zoomPlot = ArrayPlot[zoomGrid,
      ColorRules       -> {1 -> primeColor, 0 -> compositeColor},
      ImageSize        -> {300, 300},
      Frame            -> True,
      FrameTicks       -> None,
      Mesh             -> All,
      MeshStyle        -> Directive[Gray, Opacity[0.4]],
      PlotRangePadding -> None
    ];

    zoomPath = FileNameJoin[{outDir, "ulam_centre_zoom.png"}];
    Export[zoomPath, zoomPlot, "PNG"];
    Print["  Centre zoom PNG (31x31): ", zoomPath];

    (* Accessibility announcement *)
    STEMSay["Ulam spiral complete. " <>
      ToString[n] <> " by " <> ToString[n] <> " grid. " <>
      ToString[model["prime_count"]] <> " primes. " <>
      "Density " <>
      ToString[Round[N[model["prime_density"]] * 100.0, 0.1]] <>
      " percent."]
  ]


(* ── Prime gap animation ──────────────────────────────── *)

AnimateGaps[model_Association, cfg_Association, outDir_String] :=
  Module[{plan, gaps, primes, meanGap, twinCount, maxGapDisplay,
          width, height, nGaps, tempoBpm, toneDurMs, targetDuration,
          frameRate, actualNFrames,
          frameEnds, nFrames, frames, histPlot,
          gapDist, sortedGapVals, distCounts,
          finalFrame, gifPath},

    gaps          = model["gaps"];
    primes        = model["primes"];
    meanGap       = model["mean_gap"];
    twinCount     = model["twin_prime_count"];
    maxGapDisplay = GetCfg[cfg, {"simulation","gaps","max_gap_display"}, 72];
    width  = GetCfg[cfg, {"animation","width"},  600];
    height = GetCfg[cfg, {"animation","height"}, 600];

    nGaps = Length[gaps];

    (* Target duration must match the base WAV's length exactly: SonifyGaps'
       baseDuration (same formula, same tempo_bpm config key) plus the
       one tone_duration_ms tail it renders after the last onset. *)
    tempoBpm       = GetCfg[cfg, {"sonification","gaps","tempo_bpm"}, 120];
    toneDurMs      = GetCfg[cfg, {"sonification","gaps","tone_duration_ms"}, 80];
    targetDuration = 30.0 * 120.0 / N[tempoBpm] + N[toneDurMs] / 1000.0;

    (* $GapsFrameBudget is a render-budget target, not a literal frame
       count: GIFFramePlan (stem-core) clamps budget/duration to 2-30 fps,
       rounds the frame delay to whole centiseconds and derives the frame
       count from it (capped at nGaps, lengthening the delay if the cap
       applies). Frames are spread evenly across the gap sequence via
       Subdivide so the reveal still progresses smoothly. *)
    plan          = GIFFramePlan[targetDuration, $GapsFrameBudget / targetDuration,
                                 "MaxFrames" -> nGaps];
    frameRate     = plan["FrameRate"];
    actualNFrames = plan["FrameCount"];

    frameEnds = Max[1, #] & /@ Round[Subdivide[1, nGaps, actualNFrames - 1]];
    nFrames   = Length[frameEnds];

    Print["  Building ", nFrames, " animation frames at ", FmtDec[frameRate],
          " fps (", FmtDec[plan["FrameDelay"]], " s per frame, ",
          FmtDec[plan["GIFDuration"]], " s in total)."];

    (* Gap frequency histogram for the final frame inset *)
    gapDist       = model["gap_distribution"];
    sortedGapVals = Sort[Keys[gapDist]];
    distCounts    = gapDist /@ sortedGapVals;

    histPlot = BarChart[distCounts,
      ChartLabels  -> Placed[Map[ToString, sortedGapVals], Axis],
      ChartStyle   -> RGBColor[0.9, 0.5, 0.1],
      Frame        -> True,
      FrameLabel   -> {{"Count", None}, {"Gap", None}},
      PlotLabel    -> Style["Gap distribution", 9],
      ImageSize    -> {220, 180},
      FrameTicksStyle -> Directive[FontSize -> 7]
    ];

    frames = Table[
      With[{endIdx = frameEnds[[f]]},
        With[{
          mainPlot = ListLinePlot[
            gaps[[1 ;; endIdx]],
            Filling     -> Axis,
            FillingStyle -> Directive[RGBColor[0.3, 0.6, 0.9], Opacity[0.7]],
            PlotStyle   -> Directive[RGBColor[0.15, 0.4, 0.75]],
            PlotRange   -> {{0, nGaps + 1}, {0, maxGapDisplay + 2}},
            Frame       -> True,
            FrameLabel  -> {{"Gap size (p[n+1] - p[n])", None},
                             {"Prime index n", None}},
            PlotLabel   -> "Prime gaps (first " <> ToString[endIdx] <> " of " <>
                           ToString[nGaps] <> ")",
            Epilog      -> {Directive[Red, Dashed, Thickness[0.002]],
                            Line[{{0, meanGap}, {nGaps + 1, meanGap}}]},
            ImageSize   -> {width, height}
          ]},
          If[f === nFrames,
            (* Final frame: add histogram inset *)
            Show[mainPlot,
              Epilog -> Join[
                {Directive[Red, Dashed, Thickness[0.002]],
                 Line[{{0, meanGap}, {nGaps + 1, meanGap}}]},
                {Inset[histPlot, Scaled[{0.72, 0.72}], Center, Scaled[0.27]]}
              ]
            ],
            mainPlot
          ]
        ]
      ],
      {f, nFrames}
    ];

    gifPath = FileNameJoin[{outDir, "gaps_animation.gif"}];
    EnsureDir[gifPath];
    ExportGIF[frames, gifPath, plan];
    STEMDescribeGIF[gifPath, nFrames, frameRate];

    STEMSay[ToString[Length[primes]] <> " primes analysed. " <>
      "Mean gap " <> ToString[Round[meanGap, 0.01]] <> ". " <>
      "Twin prime pairs: " <> ToString[twinCount] <> "."]
  ]


AnimatePrimes[model_Association, cfg_Association, outDir_String] :=
  If[model["mode"] === "ulam",
    AnimateUlam[model, cfg, outDir],
    AnimateGaps[model, cfg, outDir]
  ]

(* ========================================================
   primes/animate.wl — Visualisation for prime number patterns

   Public API:
     AnimatePrimes[model, cfg, outDir]
       Dispatches on model["mode"]:
         "ulam" → PNG + single-frame GIF + centre zoom
         "gaps" → animated BarChart GIF (progressive reveal)
   ======================================================== *)


(* ── Ulam spiral visualisation ────────────────────────── *)

AnimateUlam[model_Association, cfg_Association, outDir_String] :=
  Module[{grid, n, colorPrimes, colorComposite,
          fps, width, height,
          primeColor, compositeColor,
          primePlot, mainPath, gifPath,
          zoom, half, centre, zoomGrid, zoomPlot, zoomPath},

    grid           = model["grid"];
    n              = model["size"];
    colorPrimes    = GetCfg[cfg, {"simulation","ulam","color_primes"},    "white"];
    colorComposite = GetCfg[cfg, {"simulation","ulam","color_composite"}, "black"];
    fps    = GetCfg[cfg, {"animation","fps"},    12];
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

    (* Single-frame GIF for pipeline consistency *)
    gifPath = FileNameJoin[{outDir, "ulam_spiral.gif"}];
    ExportGIF[{primePlot}, gifPath, fps];
    STEMDescribeGIF[gifPath, 1, fps];

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
  Module[{gaps, primes, meanGap, twinCount, maxGapDisplay,
          fps, width, height, nGaps, step,
          frameEnds, nFrames, frames, histPlot,
          gapDist, sortedGapVals, distCounts,
          finalFrame, gifPath},

    gaps          = model["gaps"];
    primes        = model["primes"];
    meanGap       = model["mean_gap"];
    twinCount     = model["twin_prime_count"];
    maxGapDisplay = GetCfg[cfg, {"simulation","gaps","max_gap_display"}, 72];
    fps    = GetCfg[cfg, {"animation","fps"},    12];
    width  = GetCfg[cfg, {"animation","width"},  600];
    height = GetCfg[cfg, {"animation","height"}, 600];

    nGaps = Length[gaps];

    (* Cap at 50 frames so large counts stay responsive *)
    step     = Max[50, Ceiling[nGaps / 50]];
    frameEnds = Range[step, nGaps, step];
    If[Length[frameEnds] === 0 || Last[frameEnds] =!= nGaps,
      AppendTo[frameEnds, nGaps]];
    nFrames = Length[frameEnds];

    Print["  Building ", nFrames, " animation frames (step=", step, ")..."];

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
    ExportGIF[frames, gifPath, fps];
    STEMDescribeGIF[gifPath, nFrames, fps];

    STEMSay[ToString[Length[primes]] <> " primes analysed. " <>
      "Mean gap " <> ToString[Round[meanGap, 0.01]] <> ". " <>
      "Twin prime pairs: " <> ToString[twinCount] <> "."]
  ]


AnimatePrimes[model_Association, cfg_Association, outDir_String] :=
  If[model["mode"] === "ulam",
    AnimateUlam[model, cfg, outDir],
    AnimateGaps[model, cfg, outDir]
  ]

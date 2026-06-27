(* ========================================================
   relativity/src/animate.wl — Visualisation for gravitational wave chirp

   Public API:
     AnimateRelativity[model, cfg, outDir]

   Outputs:
     chirp.gif — 60-frame animated GIF revealing the waveform left-to-right
     chirp.png — static two-panel PNG: waveform + frequency evolution
   ======================================================== *)


(* DecimateForPlot
   Take at most maxPts evenly spaced elements from a list. *)

DecimateForPlot[list_List, maxPts_Integer : 3000] :=
  Module[{n = Length[list], step},
    If[n <= maxPts, list,
      step = Max[1, Floor[n / maxPts]];
      list[[1 ;; ;; step]]
    ]
  ]

DecimateForPlotPairs[pairs_List, maxPts_Integer : 3000] :=
  Module[{n = Length[pairs], step},
    If[n <= maxPts, pairs,
      step = Max[1, Floor[n / maxPts]];
      pairs[[1 ;; ;; step]]
    ]
  ]


(* ── AnimateRelativity ────────────────────────────────── *)

AnimateRelativity[model_Association, cfg_Association, outDir_String] :=
  Module[{
    mode, tFull, hFull, fFull, mergerIdx, tc,
    tInspiral, hInspiral, fInspiral,
    n, nInspiral,
    fps, width, height,
    hMax, fPeak, fQnm, tTotal,
    nFrames, frameIndices, frames,
    frame, revealN, revealT, revealH, revealF,
    dotT, dotF,
    wavePanel, freqPanel,
    gifPath, pngPath,
    mergerLine, mergerT
  },

  mode      = model["mode"];
  tFull     = model["time"];
  hFull     = model["strain"];
  fFull     = model["frequency"];
  mergerIdx = model["merger_index"];
  tc        = model["coalescence_time"];

  (* Inspiral-only arrays for animation range *)
  tInspiral = tFull[[;; mergerIdx]];
  hInspiral = hFull[[;; mergerIdx]];
  fInspiral = fFull[[;; mergerIdx]];
  n         = Length[tFull];
  nInspiral = mergerIdx;

  fps    = GetCfg[cfg, {"animation","fps"},    30];
  width  = GetCfg[cfg, {"animation","width"},  800];
  height = GetCfg[cfg, {"animation","height"}, 400];

  hMax   = Max[Abs[hFull]] * 1.05;
  fPeak  = model["peak_frequency"];
  fQnm   = fFull[[mergerIdx + 1]];   (* first ringdown sample frequency = QNM freq *)
  tTotal = Last[tFull];
  mergerT = tc;

  (* ── 60-frame animated GIF ──────────────────────────── *)
  nFrames = 60;

  (* Distribute frames over the full signal (inspiral + ringdown) *)
  frameIndices = Round @ Subdivide[1, n, nFrames];
  frameIndices = Clip[frameIndices, {1, n}];

  frames = Map[
    Function[fi,
      (* Reveal waveform up to sample fi *)
      revealN = fi;
      revealT = DecimateForPlotPairs[
        Transpose[{tFull[[;; revealN]], hFull[[;; revealN]]}], 2000];
      revealF = DecimateForPlotPairs[
        Transpose[{tInspiral, fInspiral}], 800];

      (* Current position dot on frequency track *)
      dotT = tFull[[fi]];
      dotF = fFull[[fi]];

      (* Panel 1: waveform revealed left to right *)
      wavePanel = ListLinePlot[
        revealT,
        PlotRange    -> {{0, tTotal}, {-hMax, hMax}},
        PlotStyle    -> Directive[RGBColor[0.25, 0.75, 1.0], Thickness[0.002]],
        Background   -> GrayLevel[0.07],
        Frame        -> True,
        FrameStyle   -> White,
        FrameLabel   -> {{Style["Strain h(t)", White, 9], None},
                         {Style["Time (s)",    White, 9], None}},
        LabelStyle   -> White,
        PlotLabel    -> Style["Gravitational wave strain", White, 10],
        ImageSize    -> {width/2, height},
        (* Merger vertical line once we pass it *)
        Epilog -> If[dotT >= mergerT,
          {Directive[Dashed, Thick, RGBColor[1.0, 0.55, 0.0]],
           Line[{{mergerT, -hMax}, {mergerT, hMax}}],
           Text[Style["merger", RGBColor[1.0, 0.75, 0.2], 9],
                {mergerT, hMax * 0.88}, {-0.1, 0}]},
          {}]
      ];

      (* Panel 2: frequency evolution with moving dot *)
      freqPanel = Show[
        ListLinePlot[
          revealF,
          PlotRange    -> {{0, mergerT}, {0, fPeak * 1.12}},
          PlotStyle    -> Directive[RGBColor[1.0, 0.45, 0.15], Thickness[0.003]],
          Background   -> GrayLevel[0.07],
          Frame        -> True,
          FrameStyle   -> White,
          FrameLabel   -> {{Style["Frequency (Hz)", White, 9], None},
                           {Style["Time (s)",       White, 9], None}},
          LabelStyle   -> White,
          PlotLabel    -> Style["Instantaneous GW frequency", White, 10],
          ImageSize    -> {width/2, height}
        ],
        (* Moving dot at current position (only during inspiral) *)
        If[dotT <= mergerT,
          Graphics[{
            PointSize[0.018],
            RGBColor[1.0, 1.0, 0.2],
            Point[{Min[dotT, mergerT * 0.999], Min[dotF, fPeak]}]
          }],
          Graphics[{}]
        ]
      ];

      GraphicsGrid[
        {{wavePanel, freqPanel}},
        Background -> GrayLevel[0.07],
        Spacings   -> 2,
        ImageSize  -> {width, height}
      ]
    ],
    frameIndices
  ];

  gifPath = FileNameJoin[{outDir, "chirp.gif"}];
  ExportGIF[frames, gifPath, fps];
  STEMDescribeGIF[gifPath, nFrames, fps];

  (* ── Static PNG: full waveform + frequency evolution ── *)
  Print["  Exporting static PNG..."];

  pngPath = FileNameJoin[{outDir, "chirp.png"}];
  EnsureDir[pngPath];

  Export[pngPath,
    GraphicsGrid[
      {{
        (* Full waveform *)
        ListLinePlot[
          DecimateForPlotPairs[Transpose[{tFull, hFull}], 4000],
          PlotRange    -> {{0, tTotal}, {-hMax, hMax}},
          PlotStyle    -> Directive[RGBColor[0.25, 0.75, 1.0], Thickness[0.0015]],
          Background   -> GrayLevel[0.07],
          Frame        -> True,
          FrameStyle   -> White,
          FrameLabel   -> {{Style["Strain h(t)", White, 9], None},
                           {Style["Time (s)",    White, 9], None}},
          LabelStyle   -> White,
          PlotLabel    -> Style["GW strain — chirp + ringdown", White, 11],
          ImageSize    -> {width/2, height},
          Epilog       -> {
            Directive[Dashed, Thick, RGBColor[1.0, 0.55, 0.0]],
            Line[{{mergerT, -hMax}, {mergerT, hMax}}],
            Text[Style["merger", RGBColor[1.0, 0.75, 0.2], 9],
                 {mergerT, hMax * 0.88}, {-0.1, 0}]
          }
        ],
        (* Full frequency track *)
        ListLinePlot[
          DecimateForPlotPairs[Transpose[{tInspiral, fInspiral}], 2000],
          PlotRange    -> {{0, mergerT}, {0, fPeak * 1.12}},
          PlotStyle    -> Directive[RGBColor[1.0, 0.45, 0.15], Thickness[0.003]],
          Background   -> GrayLevel[0.07],
          Frame        -> True,
          FrameStyle   -> White,
          FrameLabel   -> {{Style["Frequency (Hz)", White, 9], None},
                           {Style["Time (s)",       White, 9], None}},
          LabelStyle   -> White,
          PlotLabel    -> Style["Instantaneous GW frequency", White, 11],
          ImageSize    -> {width/2, height},
          Epilog       -> {
            (* Ringdown QNM label *)
            Directive[Dashed, GrayLevel[0.6]],
            Line[{{0, fQnm}, {mergerT, fQnm}}],
            Text[Style["f_qnm = " <> ToString[Round[fQnm]] <> " Hz",
                        GrayLevel[0.75], 8],
                 {mergerT * 0.05, fQnm}, {-1, -1.2}]
          }
        ]
      }},
      Background -> GrayLevel[0.07],
      Spacings   -> 4,
      ImageSize  -> {width, height}
    ],
    "PNG"];

  Print["  Exported PNG: ", pngPath]
]

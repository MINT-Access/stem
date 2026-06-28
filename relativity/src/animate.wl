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

  mode = model["mode"];
  If[mode === "geodesic", Return @ AnimateGeodesic[model, cfg, outDir]];

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


(* ── AnimateGeodesic ──────────────────────────────────── *)

AnimateGeodesic[model_Association, cfg_Association, outDir_String] :=
  Module[{
    orbitType, tauArr, rArr, phiArr, n, tauEnd,
    xRs, yRs, rMaxRs, plotRange,
    fps, width,
    nFrames, frameIndices, frames,
    orbitColor, particleColor,
    bhDisk, photonSphereCircle, iscoCircle,
    revealXY, dotXY, fi,
    gifPath, pngPath
  },

  orbitType = model["orbit_type"];
  tauArr    = model["tau"];
  rArr      = model["r"];
  phiArr    = model["phi"];
  n         = Length[tauArr];

  (* Convert to r_s units: r_s = 2M, so r/r_s = r̃/2 *)
  xRs = model["x"] / 2.0;
  yRs = model["y"] / 2.0;

  fps   = GetCfg[cfg, {"animation","fps"},   30];
  width = GetCfg[cfg, {"animation","width"}, 800];

  rMaxRs    = model["r_max"] / 2.0 * 1.18;   (* axis half-extent in r_s *)
  plotRange = {{-rMaxRs, rMaxRs}, {-rMaxRs, rMaxRs}};

  orbitColor = Switch[orbitType,
    "bound",    RGBColor[0.25, 0.78, 1.0],
    "plunging", RGBColor[1.0,  0.38, 0.12],
    "photon",   RGBColor[0.82, 0.95, 0.22],
    _,          RGBColor[0.5,  0.9,  0.5]
  ];
  particleColor = RGBColor[1.0, 1.0, 0.3];

  (* Reference circles drawn as Graphics primitives in r_s units *)
  bhDisk = {Black, Disk[{0.0, 0.0}, 1.0]};   (* event horizon: r = 1 r_s = 2M *)
  photonSphereCircle = {
    Directive[Dashed, RGBColor[1.0, 0.55, 0.15], Thickness[0.002]],
    Circle[{0.0, 0.0}, 1.5]                   (* photon sphere: r = 1.5 r_s = 3M *)
  };
  iscoCircle = If[orbitType =!= "photon",
    {Directive[Dashed, GrayLevel[0.42], Thickness[0.0015]],
     Circle[{0.0, 0.0}, 3.0]},                (* ISCO: r = 3 r_s = 6M *)
    {}
  ];

  (* ── Animated GIF: 60 frames revealing the trajectory ── *)
  nFrames      = 60;
  frameIndices = Clip[Round @ Subdivide[1, n, nFrames], {1, n}];

  frames = Map[
    Function[fi,
      revealXY = Transpose[{xRs[[;; fi]], yRs[[;; fi]]}];
      dotXY    = {xRs[[fi]], yRs[[fi]]};
      Graphics[
        {
          {GrayLevel[0.07], Rectangle[{-rMaxRs, -rMaxRs}, {rMaxRs, rMaxRs}]},
          bhDisk, photonSphereCircle, iscoCircle,
          {Directive[orbitColor, Thickness[0.002]], Line[revealXY]},
          {PointSize[0.022], particleColor, Point[dotXY]}
        },
        PlotRange  -> plotRange,
        Background -> GrayLevel[0.07],
        Frame      -> True, FrameStyle -> White,
        FrameLabel -> {{Style["y  (r_s)", White, 9], None},
                       {Style["x  (r_s)", White, 9], None}},
        LabelStyle -> White,
        PlotLabel  -> Style[
          Switch[orbitType,
            "bound",    "Schwarzschild geodesic — bound orbit (GR periapsis precession)",
            "plunging", "Schwarzschild geodesic — plunging orbit (past event horizon)",
            "photon",   "Schwarzschild geodesic — photon (gravitational lensing)",
            _,          "Schwarzschild geodesic"],
          White, 10],
        ImageSize -> {width, width}
      ]
    ],
    frameIndices
  ];

  gifPath = FileNameJoin[{outDir, "geodesic.gif"}];
  ExportGIF[frames, gifPath, fps];
  STEMDescribeGIF[gifPath, nFrames, fps];

  (* ── Static PNG: full trajectory ── *)
  Print["  Exporting static PNG..."];
  pngPath = FileNameJoin[{outDir, "geodesic.png"}];
  EnsureDir[pngPath];

  Export[pngPath,
    Graphics[
      {
        {GrayLevel[0.07], Rectangle[{-rMaxRs, -rMaxRs}, {rMaxRs, rMaxRs}]},
        bhDisk, photonSphereCircle, iscoCircle,
        {Directive[orbitColor, Thickness[0.0018]],
         Line @ Transpose[{xRs, yRs}]},
        (* labels *)
        Text[Style["event horizon",  GrayLevel[0.65], 8],  {0.0, 1.12},   {0, -1}],
        Text[Style["photon sphere",  RGBColor[1.0, 0.7, 0.4], 8], {1.6, 0.0}, {-1, 0}],
        If[orbitType =!= "photon",
          Text[Style["ISCO", GrayLevel[0.55], 8], {3.1, 0.0}, {-1, 0}],
          Nothing]
      },
      PlotRange  -> plotRange,
      Background -> GrayLevel[0.07],
      Frame      -> True, FrameStyle -> White,
      FrameLabel -> {{Style["y  (r_s)", White, 9], None},
                     {Style["x  (r_s)", White, 9], None}},
      LabelStyle -> White,
      PlotLabel  -> Style[
        Switch[orbitType,
          "bound",    "Schwarzschild bound orbit — GR periapsis precession (rosette)",
          "plunging", "Schwarzschild plunging orbit — particle crosses event horizon",
          "photon",   "Photon geodesic — gravitational lensing by Schwarzschild BH",
          _,          "Schwarzschild geodesic"],
        White, 11],
      ImageSize -> {width, width}
    ],
    "PNG"
  ];

  Print["  Exported PNG: ", pngPath]
]

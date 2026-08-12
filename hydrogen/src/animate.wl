(* ========================================================
   hydrogen/src/animate.wl — Visualisation for all three modes

   Public API:
     AnimateOrbital[orbitalModel, outGIF, outPNG, targetDuration]
     AnimateSpectrum[spectrumResult, outGIF, targetDuration]
     AnimateTransitions[cascadesList, nStart, outGIF, targetDuration]
   ======================================================== *)


(* All three Animate* below used to export at a fixed frame rate/frame
   count (orbitals: 32 frames @ 10 fps; spectrum: nLines frames @
   Max[2,nLines/4] fps; transitions: N frames @ 2 fps) entirely
   decoupled from how long the matching WAV actually plays once its
   spoken intro is included (measured: orbitals.gif 3.2s vs
   orbitals_audio.wav 105.6s -- 33x; spectrum.gif 3.92s vs
   spectrum_audio.wav 43.96s -- 11.2x; transitions.gif 6.0s vs
   transitions_audio.wav 54.87s -- 9.1x). targetDuration below is the
   actual total WAV duration (main.wl builds each mode's audio,
   including its spoken intro, before rendering the matching GIF, so
   this value is known exactly). nFrames is a RENDER BUDGET: frameRate
   is solved as nFrames/targetDuration then clamped to
   [$HydrogenMinGifFps, $HydrogenMaxGifFps] so the frame COUNT flexes
   at the clamp boundary, keeping actual playback duration exactly
   targetDuration -- same pattern as lorenz/src/animate.wl's
   ExportAnimation. Spectrum and transitions modes have only as many
   distinct visual states as spectral lines / cascade steps (often far
   fewer than the render budget); Subdivide's rounding holds a state
   across consecutive frames when that happens, rather than erroring. *)
$HydrogenMinGifFps = 2;
$HydrogenMaxGifFps = 30;
$HydrogenGifFrameBudget = 150;

HydrogenGifRate[targetDuration_?NumericQ, nFrames_:$HydrogenGifFrameBudget] :=
  Clip[nFrames / targetDuration, {$HydrogenMinGifFps, $HydrogenMaxGifFps}];


(* ── Orbitals: Hilbert sweep over the coloured density map ────────
   Same visual language as images/src/animate.wl's
   AnimateImageTraversal, adapted to a physics colour map (dark purple
   = low density, bright yellow = high density) applied to the same
   log-compressed density used for pitch in sonify.wl, since |psi|^2
   spans many orders of magnitude and a linear colour map would show
   nothing but a single bright dot. *)

OrbitalColorFunction[t_?NumericQ] :=
  Blend[{RGBColor[0.10, 0.0, 0.24], RGBColor[0.42, 0.0, 0.42],
         RGBColor[0.90, 0.35, 0.10], RGBColor[1.0, 0.95, 0.25]}, Clip[t, {0.0, 1.0}]];

OrbitalDensityToRGB[density_List] :=
  Module[{flat, dMax, threshold, logNorm},
    flat      = Flatten[density];
    dMax      = Max[flat];
    threshold = dMax * 1.0*^-6;
    logNorm = Map[
      If[# <= threshold, 0.0,
        Clip[(Log[Max[#, threshold]] - Log[threshold]) / (Log[dMax] - Log[threshold]), {0.0, 1.0}]
      ] &,
      density, {2}
    ];
    Map[List @@ OrbitalColorFunction[#] &, logNorm, {2}]
  ];

AnimateOrbital[orbitalModel_Association, outGIF_String, outPNG_String, targetDuration_?NumericQ] :=
  Module[{density, gridSize, traversal, nPixels, rgbGrid, displayData,
          gCoords, frameRate, nGIFFrames, frameUpTo, gifFrames, staticFig},

    density   = orbitalModel["density"];
    gridSize  = orbitalModel["gridSize"];
    traversal = orbitalModel["traversal"];
    nPixels   = orbitalModel["nPixels"];

    rgbGrid = OrbitalDensityToRGB[density];
    (* Row 1 of density is z = -rMax (bottom physically); Reverse so the
       Raster shows +z at the top, matching the image's visual orientation
       (same fix as images/src/animate.wl applies to ImageData). *)
    displayData = Reverse[rgbGrid];

    gCoords = Map[{#[[1]] - 0.5, gridSize - #[[2]] + 0.5} &, traversal];
    frameRate  = HydrogenGifRate[targetDuration];
    nGIFFrames = Max[2, Round[frameRate * targetDuration]];
    frameUpTo = Table[Max[1, Round[k * nPixels / nGIFFrames]], {k, nGIFFrames}];

    gifFrames = Table[
      With[{pathG = gCoords[[1 ;; frameUpTo[[k]]]]},
        Graphics[{
          Raster[displayData, {{0, 0}, {gridSize, gridSize}}],
          {Opacity[0.8], White, Thin, Line[pathG]},
          {Yellow, Disk[Last[pathG], gridSize * 0.012]}
        },
        PlotRange -> {{0, gridSize}, {0, gridSize}},
        ImagePadding -> None, AspectRatio -> 1, ImageSize -> 320]
      ],
      {k, nGIFFrames}
    ];
    ExportGIF[gifFrames, outGIF, frameRate];
    STEMDescribeGIF[outGIF, nGIFFrames, frameRate];

    staticFig = Graphics[
      {Raster[displayData, {{0, 0}, {gridSize, gridSize}}]},
      PlotRange -> {{0, gridSize}, {0, gridSize}},
      ImagePadding -> None, AspectRatio -> 1, ImageSize -> 400,
      PlotLabel -> Style[
        OrbitalDisplayName[orbitalModel["orbitalKey"]] <> " -- |psi|^2 cross-section (x z plane)",
        White, 12],
      Background -> GrayLevel[0.08]
    ];
    EnsureDir[outPNG];
    Export[outPNG, staticFig];
    Print["  PNG: ", outPNG];

    nGIFFrames
  ];


(* ── Spectrum: growing stem plot with a sweeping cursor ───────────
   x-axis: log(wavelength), so the twenty-eight-fold range from 91 nm
   (Lyman) to ~1900 nm (Paschen) is legible. y-axis: relative amplitude.
   Colour: Lyman = violet/UV; Balmer lines use their approximate real
   colours (Halpha red, Hbeta blue-green, Hgamma/Hdelta violet); Paschen
   and redder series = dark red/IR. *)

SpectrumLineColor[line_Association] :=
  Which[
    line["n_lower"] == 1, RGBColor[0.58, 0.0, 0.85],
    line["n_lower"] == 2,
      Switch[line["n_upper"],
        3, RGBColor[0.90, 0.10, 0.10],
        4, RGBColor[0.10, 0.75, 0.70],
        5, RGBColor[0.55, 0.15, 0.85],
        6, RGBColor[0.42, 0.0, 0.62],
        _, RGBColor[0.42, 0.0, 0.62]
      ],
    True, RGBColor[0.55, 0.08, 0.05]
  ];

SpectrumFrame[sweepLines_List, sweepAmps_List, revealCount_Integer] :=
  Module[{logLam, xMin, xMax, toX, stems, cursorX},
    logLam = Map[Log[#["lambda_nm"]] &, sweepLines];
    xMin = Min[logLam]; xMax = Max[logLam];
    toX[lam_] := Rescale[Log[lam], {xMin, xMax}, {0.5, 9.5}];
    stems = Table[
      {SpectrumLineColor[sweepLines[[i]]], Thickness[0.007],
       Line[{{toX[sweepLines[[i]]["lambda_nm"]], 0},
             {toX[sweepLines[[i]]["lambda_nm"]], sweepAmps[[i]]}}]},
      {i, revealCount}
    ];
    cursorX = toX[sweepLines[[revealCount]]["lambda_nm"]];
    Graphics[
      Join[stems, {{Yellow, Thickness[0.003], Line[{{cursorX, 0}, {cursorX, 1.08}}]}}],
      PlotRange -> {{0, 10}, {0, 1.1}}, Background -> GrayLevel[0.08],
      ImageSize -> 520, Frame -> True, FrameStyle -> White, FrameTicks -> None,
      PlotLabel -> Style["Hydrogen emission spectrum -- UV (left) to IR (right)", White, 12]
    ]
  ];

AnimateSpectrum[spectrumResult_Association, outGIF_String, targetDuration_?NumericQ] :=
  Module[{lines, order, sweepLines, sweepAmps, nLines, frameRate, nFrames, indices, frames},
    lines      = spectrumResult["lines"];
    order      = spectrumResult["sweepOrder"];
    sweepLines = lines[[order]];
    sweepAmps  = spectrumResult["amps"][[order]];
    nLines     = Length[sweepLines];
    frameRate  = HydrogenGifRate[targetDuration];
    nFrames    = Max[2, Round[frameRate * targetDuration]];
    (* nLines discrete spectral-line reveal states are the only distinct
       visual states; Subdivide's rounding naturally holds a state
       across consecutive frames when nFrames exceeds nLines. *)
    indices = Clip[Round[Subdivide[1, nLines, nFrames - 1]], {1, nLines}];
    frames = SpectrumFrame[sweepLines, sweepAmps, #] & /@ indices;
    ExportGIF[frames, outGIF, frameRate];
    {nFrames, frameRate}
  ];


(* ── Transitions: Grotrian (energy-level) diagram ─────────────────
   Horizontal lines at each E_n; arrows animate one transition at a
   time for the first few realisations (each realisation's arrows are
   cleared before the next begins). *)

GrotrianSeriesColor[nLower_Integer] :=
  Which[nLower == 1, RGBColor[0.58, 0.0, 0.85],
        nLower == 2, RGBColor[0.90, 0.25, 0.10],
        True,        RGBColor[0.55, 0.08, 0.05]];

GrotrianFrame[maxN_Integer, stepsShown_List, realizationIdx_Integer] :=
  Module[{levels, arrows, xArrow},
    levels = Table[
      {Gray, Thin, Line[{{0.2, EnergyLevelEV[n]}, {9.8, EnergyLevelEV[n]}}]},
      {n, 1, maxN}
    ];
    arrows = Table[
      With[{step = stepsShown[[k]], xA = 1.0 + 1.6 * (k - 1)},
        {
          {GrotrianSeriesColor[step["n_lower"]], Thick,
           Arrowheads[0.025],
           Arrow[{{xA, EnergyLevelEV[step["n_upper"]]}, {xA, EnergyLevelEV[step["n_lower"]]}}]},
          Text[
            Style[ToString[NumberForm[step["lambda_nm"], {5, 1}]] <> " nm", White, 8],
            {xA + 0.55, (EnergyLevelEV[step["n_upper"]] + EnergyLevelEV[step["n_lower"]]) / 2.0}
          ]
        }
      ],
      {k, Length[stepsShown]}
    ];
    Graphics[
      Join[levels, Flatten[arrows, 1],
        {Text[Style["Realisation " <> ToString[realizationIdx], White, 11], {5, 1.3}]}],
      PlotRange -> {{0, 10}, {-14.5, 2}}, Background -> GrayLevel[0.08],
      ImageSize -> 520, Frame -> False,
      Epilog -> Table[
        Text[Style["n=" <> ToString[n], LightGray, 8], {0.0, EnergyLevelEV[n]}],
        {n, 1, maxN}
      ]
    ]
  ];

AnimateTransitions[cascadesList_List, nStart_Integer, outGIF_String, targetDuration_?NumericQ] :=
  Module[{nRealToShow, allFrames, nAvail, frameRate, nFrames, indices, frames},
    nRealToShow = Min[4, Length[cascadesList]];
    allFrames = Flatten[
      Table[
        Table[
          GrotrianFrame[nStart, cascadesList[[real, 1 ;; k]], real],
          {k, 1, Length[cascadesList[[real]]]}
        ],
        {real, nRealToShow}
      ],
      1
    ];
    nAvail    = Length[allFrames];
    frameRate = HydrogenGifRate[targetDuration];
    nFrames   = Max[2, Round[frameRate * targetDuration]];
    (* nAvail discrete cascade-step states are the only distinct visual
       states; Subdivide's rounding holds a state across consecutive
       frames when nFrames exceeds nAvail. *)
    indices = Clip[Round[Subdivide[1, nAvail, nFrames - 1]], {1, nAvail}];
    frames = allFrames[[indices]];
    ExportGIF[frames, outGIF, frameRate];
    {nFrames, frameRate}
  ];

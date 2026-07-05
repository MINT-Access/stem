(* ========================================================
   hydrogen/src/animate.wl — Visualisation for all three modes

   Public API:
     AnimateOrbital[orbitalModel, outGIF, outPNG]
     AnimateSpectrum[spectrumResult, outGIF]
     AnimateTransitions[cascadesList, nStart, outGIF]
   ======================================================== *)


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

AnimateOrbital[orbitalModel_Association, outGIF_String, outPNG_String] :=
  Module[{density, gridSize, traversal, nPixels, rgbGrid, displayData,
          gCoords, nGIFFrames = 32, frameUpTo, gifFrames, staticFig},

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
    ExportGIF[gifFrames, outGIF, 10];
    STEMDescribeGIF[outGIF, nGIFFrames, 10];

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

AnimateSpectrum[spectrumResult_Association, outGIF_String] :=
  Module[{lines, order, sweepLines, sweepAmps, nLines, frames},
    lines      = spectrumResult["lines"];
    order      = spectrumResult["sweepOrder"];
    sweepLines = lines[[order]];
    sweepAmps  = spectrumResult["amps"][[order]];
    nLines     = Length[sweepLines];
    frames = Table[SpectrumFrame[sweepLines, sweepAmps, k], {k, 1, nLines}];
    ExportGIF[frames, outGIF, Max[2, Round[nLines / 4.0]]];
    nLines
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

AnimateTransitions[cascadesList_List, nStart_Integer, outGIF_String] :=
  Module[{nRealToShow, frames},
    nRealToShow = Min[4, Length[cascadesList]];
    frames = Flatten[
      Table[
        Table[
          GrotrianFrame[nStart, cascadesList[[real, 1 ;; k]], real],
          {k, 1, Length[cascadesList[[real]]]}
        ],
        {real, nRealToShow}
      ],
      1
    ];
    ExportGIF[frames, outGIF, 2];
    Length[frames]
  ];

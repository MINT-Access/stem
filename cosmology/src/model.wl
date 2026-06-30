(* cosmology/src/model.wl — CMB spectrum model and sky map generation *)

(* Approximate acoustic peak positions and amplitudes for standard flat LCDM.
   {l_center, D_peak [muK^2], sigma_l}  --  approximate Planck 2018 values *)
$cmbPeakSpecs = {
  {220.0,  5400.0,  88.0},
  {540.0,  2500.0, 100.0},
  {810.0,  2200.0, 108.0},
  {1120.0, 1100.0, 115.0},
  {1430.0,  550.0, 122.0}
};

(* Analytic LCDM approximation for D_l = l(l+1)C_l/(2pi) in muK^2.
   Combines Sachs-Wolfe plateau + inter-peak floor + five Gaussian peaks. *)
SimulatedDl[l_?NumericQ] :=
  With[{lN = N[l]},
    With[{
      sw  = 1100.0 / (1.0 + (lN / 50.0)^2.0),
      bg  = 200.0  * Exp[-(lN / 600.0)^2.0],
      gau = Total @ Map[Function[pk,
              pk[[2]] * Exp[-((lN - pk[[1]])^2) / (2.0 * pk[[3]]^2)]
            ], $cmbPeakSpecs]
    },
      N @ Max[0.0, sw + bg + gau]
    ]
  ];

(* Convert D_l to C_l = 2pi * D_l / (l(l+1)) *)
DlToCl[l_?NumericQ, dl_?NumericQ] :=
  If[N[l] <= 1.0, 0.0, N[2.0 Pi * dl / (N[l] * (N[l] + 1.0))]];

(* Load the CMB power spectrum from the named source.
   Returns {lArr, dlArr, clArr}.
   Requires FetchPlanckSpectrum from fetch.wl to be loaded. *)
LoadSpectrum[sourceName_String, lMax_Integer] :=
  Module[{lArr, nL, dlArr, clArr},
    lArr = Range[2, lMax];
    nL   = Length[lArr];

    If[sourceName === "planck",
      Module[{result, lPlanck, dlPlanck, clInterp},
        result = FetchPlanckSpectrum[lMax];
        If[Length[result] === 2 && Length[result[[1]]] > 50,
          lPlanck  = N @ result[[1]];
          dlPlanck = N @ result[[2]];
          clInterp = Interpolation[
            Transpose[{lPlanck, dlPlanck}], InterpolationOrder -> 1];
          dlArr = N @ Map[
            Function[l,
              If[l >= Min[lPlanck] && l <= Max[lPlanck],
                Max[0.0, Quiet[clInterp[N[l]]]],
                SimulatedDl[l]
              ]
            ],
            N @ lArr
          ];
          Print["  Planck 2018 data: l = ", Min[lPlanck], " to ", Max[lPlanck],
                "  (", Length[lPlanck], " points)"],
          Print["  [WARNING] Planck fetch failed -- using simulated spectrum."];
          dlArr = N @ Map[SimulatedDl, lArr]
        ]
      ],
      dlArr = N @ Map[SimulatedDl, lArr];
      Print["  Analytic \[CapitalLambda]CDM approximation (5-Gaussian-peak model)"]
    ];

    clArr = N @ MapThread[DlToCl, {lArr, dlArr}];
    STEMPrintN["D_l range",
      N @ Min[dlArr],
      "\[Mu]K^2  to  " <> FmtN[N @ Max[dlArr], 5] <> " \[Mu]K^2", 5];
    {lArr, dlArr, clArr}
  ];

(* Run physical correctness checks 1-3 on the power spectrum.
   Prints check results and returns an Association with peak detection data. *)
CMBPhysicsChecks[lArr_List, dlArr_List] :=
  Module[{nNeg, thresh, peakIdxs, peakLVals, peakDlVals, lPk1, found, mono},
    (* Check 1: D_l >= 0 everywhere *)
    nNeg = Count[dlArr, _?(# < 0.0 &)];
    Print["  [", If[nNeg === 0, "PASS", "FAIL"], "] ",
          "D_l >= 0 for all l  (", nNeg, " negative values)"];

    (* Detect acoustic peaks: local maxima above 30% of global max *)
    thresh   = 0.30 * Max[dlArr];
    peakIdxs = Select[Range[2, Length[dlArr] - 1], Function[i,
      dlArr[[i]] > dlArr[[i - 1]] &&
      dlArr[[i]] > dlArr[[i + 1]] &&
      dlArr[[i]] > thresh
    ]];
    peakLVals  = lArr[[peakIdxs]];
    peakDlVals = dlArr[[peakIdxs]];

    (* Check 2: first acoustic peak l in [180, 260] *)
    lPk1  = If[Length[peakLVals] > 0, First[peakLVals], -1];
    found = Length[peakLVals] > 0;
    Print["  [", If[found && 180 <= lPk1 <= 260, "PASS", "FAIL"], "] ",
          "First acoustic peak at l = ",
          If[found, ToString[lPk1], "not found"],
          "  (expected 180 - 260)"];

    (* Check 3: peak 1 amplitude > last-detected peak (Silk damping) *)
    mono = Length[peakDlVals] < 2 ||
           AllTrue[Differences[peakDlVals], # <= 0.0 &];
    Print["  [", If[Length[peakDlVals] < 2, "PASS",
                    If[First[peakDlVals] > Last[peakDlVals], "PASS", "FAIL"]], "] ",
          "Peak 1 amplitude > last detected peak (Silk damping)"];
    If[!mono && Length[peakDlVals] >= 2,
      Print["  [WARN] Not strictly pairwise decreasing -- peak 2 < peak 3 ",
            "is physically expected with baryon loading"]
    ];

    <|
      "peakIdxs"   -> peakIdxs,
      "peakLVals"  -> peakLVals,
      "peakDlVals" -> peakDlVals
    |>
  ];

(* Generate a simulated flat-sky CMB temperature anisotropy map using a
   Gaussian random field with the given C_l power spectrum.
   Returns an Association with the map, traversal, and per-pixel audio data. *)
GenerateSkyMap[lArr_List, clArr_List, hilbertN_Integer,
               patchDeg_?NumericQ, noteDur_?NumericQ,
               freqLo_?NumericQ, freqHi_?NumericQ] :=
  Module[{actualN = 2^hilbertN,
          patchRad, lPerPix, clInterp, kIdx, lGrid, clGrid,
          sigmaGrid, coeffs, mapT, traversal, nPix, pixTemps,
          tMin, tMax, tNorm, varActual, varExpected, ratio},

    patchRad = N[patchDeg * Pi / 180.0];
    lPerPix  = N[2.0 Pi / patchRad];

    clInterp = Interpolation[
      Transpose[{N @ lArr, N @ clArr}], InterpolationOrder -> 1];

    kIdx  = N @ Join[Range[0, actualN/2 - 1], Range[-actualN/2, -1]];
    lGrid = Outer[(#1^2 + #2^2)^0.5 * lPerPix &, kIdx, kIdx];

    clGrid = Map[
      Function[l,
        If[l < 2.0 || l > Max[lArr], 0.0,
          N @ Max[0.0, Quiet[clInterp[Min[N[l], N @ Max[lArr]]]]]
        ]
      ],
      lGrid, {2}
    ];

    sigmaGrid = N @ Sqrt[clGrid / 2.0] * actualN / Sqrt[patchRad^2];
    SeedRandom[271828];
    coeffs = sigmaGrid *
      (RandomVariate[NormalDistribution[0, 1], {actualN, actualN}] +
       I * RandomVariate[NormalDistribution[0, 1], {actualN, actualN}]);

    mapT = N @ Re[InverseFourier[coeffs, FourierParameters -> {1, -1}]];

    STEMPrintN["Map std dev",
      N @ StandardDeviation[Flatten[mapT]], "uK", 5];
    STEMPrintN["Map range",
      N @ Min[Flatten[mapT]],
      "uK  to  " <> FmtN[N @ Max[Flatten[mapT]], 5] <> " uK", 5];
    Print[""];

    (* Sanity check 4: map variance vs flat-sky expected *)
    Print["-- Physical correctness check (4) --"];
    varActual   = N @ Variance[Flatten[mapT]];
    varExpected = N @ Total[Flatten[clGrid]] / (actualN^2 * patchRad^2);
    ratio = If[varExpected > 0.0, varActual / varExpected, -1.0];
    Print["  [", If[0.5 < ratio < 2.0, "PASS", "FAIL"], "] ",
          "Map variance: ", FmtN[varActual, 5], " uK^2  ",
          "vs flat-sky sum_k C_l(k)/(N^2 Omega) = ",
          FmtN[varExpected, 5], " uK^2  ",
          "(ratio = ", FmtN[ratio, {4, 2}], ")"];
    Print[""];

    traversal = HilbertTraversalOrder[hilbertN];
    nPix      = Length[traversal];
    pixTemps  = Table[
      mapT[[ traversal[[i, 2]], traversal[[i, 1]] ]],
      {i, nPix}
    ];
    tMin  = N @ Min[pixTemps];
    tMax  = N @ Max[pixTemps];
    tNorm = N[(pixTemps - tMin) / Max[tMax - tMin, 1.0*^-10]];

    <|
      "mapT"      -> mapT,
      "traversal" -> traversal,
      "nPix"      -> nPix,
      "pixTemps"  -> pixTemps,
      "tNorm"     -> tNorm,
      "actualN"   -> actualN,
      "freqLo"    -> freqLo,
      "freqHi"    -> freqHi,
      "noteDur"   -> noteDur
    |>
  ];

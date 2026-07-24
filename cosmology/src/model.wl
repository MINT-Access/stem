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

    (* Resolution-limit diagnostic: a patch of angular size patchDeg
       sampled at actualN x actualN pixels can only represent
       multipoles up to the grid's Nyquist limit, lNyquist =
       (actualN/2)*lPerPix -- structure at higher l is simply absent
       from lGrid by construction (every grid point's l already sits at
       or below this value; the l>Max[lArr] guard above never actually
       triggers in the normal case where lNyquist < Max[lArr], since
       lGrid never reaches that high to begin with). Previously this
       was silently the case with no way for a user to know how much of
       the configured l_max their chosen sky_resolution could actually
       show. Report it explicitly here: what fraction of the spectrum's
       total power falls inside the achievable range, and by name,
       which of $cmbPeakSpecs's peaks are/aren't reachable, using the
       same (2l+1)/(4 Pi) full-sky weighting used elsewhere in this
       file to convert C_l into a power contribution -- see AGENTS.md
       for why sky_resolution, not l_max, is treated as the user's
       actual request: growing resolution to match a requested l_max
       automatically would change this mode's runtime cost without the
       user asking for that; capping and clearly reporting what a
       user's chosen resolution can and cannot show respects the
       resolution they picked. *)
    Module[{lNyquist, totalPower, reachedPower, reachedFrac,
            reachableSpecs, unreachableSpecs},
      lNyquist = (actualN / 2.0) * lPerPix;
      totalPower   = Total[N[clArr] * (2.0*N[lArr] + 1.0) / (4.0 * Pi)];
      reachedPower = Total[Pick[N[clArr] * (2.0*N[lArr] + 1.0) / (4.0 * Pi),
                                Thread[N[lArr] <= lNyquist]]];
      reachedFrac  = If[totalPower > 0.0, reachedPower / totalPower, 1.0];
      reachableSpecs   = Select[$cmbPeakSpecs, #[[1]] <= lNyquist &];
      unreachableSpecs = Select[$cmbPeakSpecs, #[[1]] >  lNyquist &];

      Print["  Sky resolution ", actualN, "x", actualN, " over a ",
            FmtN[patchDeg, {3,0}], " deg patch resolves l = 2 to ",
            FmtN[lNyquist, {5,0}], " (", FmtN[reachedFrac * 100.0, {4,1}],
            "% of this spectrum's total power)."];
      If[Length[unreachableSpecs] > 0,
        Print["  Peaks NOT represented in the sky texture at this ",
              "resolution (l = ", StringRiffle[
                FmtN[#, {5,0}] & /@ unreachableSpecs[[All, 1]], ", "],
              "): increase --simulation.cosmology.sky_resolution to ",
              "resolve them; doubling resolution roughly doubles lNyquist."]
      ];
      Print[""]
    ];

    (* sigmaGrid: amplitude of each Fourier-space Gaussian coefficient.
       GetCfg's InverseFourier is called below with FourierParameters ->
       {1,-1} -- WL's "physicist/engineering" DFT convention, where the
       inverse transform alone carries a full 1/actualN normalisation
       PER AXIS (1/actualN^2 total for this 2D transform), unlike the
       "unitary" 1/Sqrt[n] convention. For a real field built by taking
       Re[InverseFourier[coeffs]] of independent (non-Hermitian-
       symmetric) complex Gaussian coefficients, this means
       Var[mapT] = Sum[sigmaGrid^2] / actualN^4 (each of the two
       factors of 1/actualN^2 in the inverse transform's normalisation
       contributes once to the variance, since Var is quadratic in the
       transform). Matching that against the continuum flat-sky target
       Var[T] = (1/patchRad^2) * Sum[clGrid] (from Var[T] =
       Integral[d^2l/(2 Pi)^2, C_l] discretised on this grid, so the
       (2 Pi)^2 exactly cancels lPerPix^2 = (2 Pi/patchRad)^2 -- see
       AGENTS.md) requires sigmaGrid ~ Sqrt[clGrid] * actualN^2 /
       patchRad, not actualN^1 -- the previous formula was missing a
       full factor of actualN, making the simulated map's RMS
       temperature scale DOWN as resolution increases instead of
       staying fixed for a fixed patch size, and making it read ~90x
       too quiet/low-contrast at the default 64x64 resolution (~1.1uK
       RMS instead of the ~100uK RMS a real CMB patch this size and
       power spectrum should show). Verified numerically: reproducing
       this exact FFT convention in an independent implementation and
       comparing against the convention-free full-sky physical relation
       Var[T] = Sum[D_l*(2l+1)/(2*l*(l+1))] (~120uK RMS for this
       spectrum) confirms the corrected formula below, not the
       original. The extra Sqrt[2] corrects a second, smaller,
       unrelated factor: only the REAL part of the inverse transform is
       kept (Re[...] below), which carries half the total complex-field
       variance for non-Hermitian-symmetric input. *)
    sigmaGrid = N @ Sqrt[clGrid / 2.0] * Sqrt[2.0] * actualN^2 / Sqrt[patchRad^2];
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

    (* Sanity check 4: map variance vs flat-sky expected.
       varExpected is the continuum flat-sky target derived above
       (Var[T] = Sum[clGrid]/patchRad^2, from Var[T] =
       Integral[d^2l/(2Pi)^2, C_l] discretised on this grid) -- it has
       NO actualN dependence, since the total large-scale power a fixed
       patch shows should not shrink as it's resolved into more pixels.
       (The previous version of this formula divided by an extra
       actualN^2, which is the same missing factor sigmaGrid was
       missing above -- the two bugs cancelled each other out and made
       this check falsely PASS on a map that was actually ~90x too
       quiet; fixing only one of the two would have made the check
       FAIL instead of catching the truth, so both had to be corrected
       together.) *)
    Print["-- Physical correctness check (4) --"];
    varActual   = N @ Variance[Flatten[mapT]];
    varExpected = N @ Total[Flatten[clGrid]] / patchRad^2;
    ratio = If[varExpected > 0.0, varActual / varExpected, -1.0];
    Print["  [", If[0.5 < ratio < 2.0, "PASS", "FAIL"], "] ",
          "Map variance: ", FmtN[varActual, 5], " uK^2  ",
          "vs flat-sky sum_k C_l(k)/Omega = ",
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

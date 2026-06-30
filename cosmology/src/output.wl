(* cosmology/src/output.wl — CSV and PNG data export *)

(* Export the CMB power spectrum data table.
   Flags the first 3 acoustic peaks in the is_peak column. *)
ExportSpectrumData[lArr_List, dlArr_List, clArr_List,
                   peakData_Association, outCSV_String] :=
  Module[{nL, peakIdxs, isPeakArr},
    nL        = Length[lArr];
    peakIdxs  = peakData["peakIdxs"];
    isPeakArr = ConstantArray[0, nL];
    Do[isPeakArr[[idx]] = 1,
       {idx, Take[peakIdxs, Min[3, Length[peakIdxs]]]}];
    ExportCSV[
      Join[
        {{"l", "Cl_uK2", "Dl_uK2", "is_peak"}},
        Table[
          {lArr[[i]], clArr[[i]], dlArr[[i]], isPeakArr[[i]]},
          {i, nL}
        ]
      ],
      outCSV
    ];
    STEMDescribeCSV[outCSV, nL, 4]
  ];

(* Export the simulated CMB sky map as PNG and write the per-pixel CSV. *)
ExportSkyData[skyModel_Association, outCSV_String, outPNG_String] :=
  Module[{mapT, traversal, pixTemps, tNorm, nPix, freqLo, freqHi, skyImg},
    mapT      = skyModel["mapT"];
    traversal = skyModel["traversal"];
    pixTemps  = skyModel["pixTemps"];
    tNorm     = skyModel["tNorm"];
    nPix      = skyModel["nPix"];
    freqLo    = skyModel["freqLo"];
    freqHi    = skyModel["freqHi"];

    skyImg = Image[N[(mapT - Min[mapT]) / Max[Max[mapT] - Min[mapT], 1.0*^-10]]];
    Export[outPNG, skyImg, "PNG"];
    Print["  PNG: ", outPNG];

    ExportCSV[
      Join[
        {{"hilbert_index", "col", "row", "temperature_uK", "frequency_hz"}},
        Table[
          {i,
           traversal[[i, 1]], traversal[[i, 2]],
           pixTemps[[i]],
           N[freqLo * (freqHi / freqLo)^tNorm[[i]]]},
          {i, nPix}
        ]
      ],
      outCSV
    ];
    STEMDescribeCSV[outCSV, nPix, 5]
  ];

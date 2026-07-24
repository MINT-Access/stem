(* ========================================================
   brownian/src/output.wl — CSV export and console summaries
   ======================================================== *)


(* ExportWalkCSV — columns: n, t, x, y, r *)
ExportWalkCSV[walkTable_List, outCSV_String] :=
  Module[{n, header, rows},
    n = Length[walkTable];
    header = {{"n", "t", "x", "y", "r"}};
    rows = Table[
      {i - 1, walkTable[[i, 1]], walkTable[[i, 2]], walkTable[[i, 3]], walkTable[[i, 4]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 5]
  ];


(* ExportEnsembleCSV — columns: n, t, ensemble_rms, ensemble_msd,
   walker_1_r, walker_2_r, walker_3_r (a few individual samples,
   for direct visual/numeric comparison against the ensemble average) *)
ExportEnsembleCSV[ensembleModel_Association, outCSV_String] :=
  Module[{t, rms, msd, samplePaths, nSampleCols, sampleR, header, rows, n},
    t   = ensembleModel["t"];
    rms = ensembleModel["rms"];
    msd = ensembleModel["msd"];
    samplePaths = ensembleModel["samplePaths"];
    nSampleCols = Min[3, Length[samplePaths]];
    sampleR = Table[Sqrt[samplePaths[[k, All, 1]]^2 + samplePaths[[k, All, 2]]^2], {k, nSampleCols}];
    n = Length[t];

    header = {Join[{"n", "t", "ensemble_rms", "ensemble_msd"},
                    Table["walker_" <> ToString[k] <> "_r", {k, nSampleCols}]]};
    rows = Table[
      Join[{i - 1, t[[i]], rms[[i]], msd[[i]]}, Table[sampleR[[k, i]], {k, nSampleCols}]],
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 4 + nSampleCols]
  ];


(* ExportTemperatureCSV — columns: T, D, final_r, max_r, rms_r *)
ExportTemperatureCSV[tVals_List, dVals_List, walkTables_List, outCSV_String] :=
  Module[{n, header, rows, finalR, maxR, rmsR},
    n = Length[tVals];
    header = {{"T_kelvin", "D_m2_per_s", "final_r", "max_r", "rms_r"}};
    rows = Table[
      finalR = Last[walkTables[[i]][[All, 4]]];
      maxR   = Max[walkTables[[i]][[All, 4]]];
      rmsR   = Sqrt[Mean[walkTables[[i]][[All, 4]]^2]];
      {tVals[[i]], dVals[[i]], finalR, maxR, rmsR},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 5]
  ];


(* PrintCorrectnessChecks
   Prints the "Checks: 1[PASS] 2[FAIL] ..." line, consistent with the
   style used across the v1.5.0 apps. *)
PrintCorrectnessChecks[msdChk_Association, seChk_Association,
                       kurtChk_Association, sqrtChk_Association] :=
  Print["  Checks: ",
    If[msdChk["pass"],  "1[PASS]", "1[FAIL]"], " ",
    If[seChk["pass"],   "2[PASS]", "2[FAIL]"], " ",
    If[kurtChk["pass"], "3[PASS]", "3[FAIL]"], " ",
    If[sqrtChk["pass"], "4[PASS]", "4[FAIL]"]
  ];


(* PrintWalkSummary *)
PrintWalkSummary[walkTable_List, D_?NumericQ, dt_?NumericQ] :=
  Module[{n, finalR, maxR},
    n = Length[walkTable];
    finalR = Last[walkTable[[All, 4]]];
    maxR   = Max[walkTable[[All, 4]]];
    STEMSection["Walk Summary"];
    Print["  D: ", FmtN[D, 4], " m^2/s   dt: ", FmtN[dt, 4], " s"];
    STEMPrintN["Steps", n - 1];
    Print["  Final displacement r: ", FmtN[finalR, 6], " m"];
    Print["  Max displacement r:   ", FmtN[maxR, 6], " m"];
  ];


(* PrintEnsembleSummary *)
PrintEnsembleSummary[ensembleModel_Association] :=
  Module[{t, rms},
    t = ensembleModel["t"];
    rms = ensembleModel["rms"];
    STEMSection["Ensemble Summary"];
    STEMPrintN["Walkers", ensembleModel["nWalkers"]];
    STEMPrintN["Steps", ensembleModel["nSteps"]];
    Print["  D: ", FmtN[ensembleModel["D"], 4], " m^2/s"];
    Print["  RMS at t=", FmtN[Last[t], 3], "s: ", FmtN[Last[rms], 6], " m"];
    Print["  RMS at t=", FmtN[t[[Ceiling[Length[t]/2]]], 3], "s: ",
          FmtN[rms[[Ceiling[Length[rms]/2]]], 6], " m  (roughly half the time, ",
          "but not roughly half the RMS -- that is the sqrt(t) law)"];
  ];


(* PrintTemperatureSummary *)
PrintTemperatureSummary[tVals_List, dVals_List] :=
  Module[{},
    STEMSection["Temperature Summary"];
    STEMPrintN["Temperature steps", Length[tVals]];
    Print["  T range: ", FmtN[First[tVals], 4], " K -> ", FmtN[Last[tVals], 4], " K"];
    Print["  D range: ", FmtN[First[dVals], 4], " -> ", FmtN[Last[dVals], 4], " m^2/s  (ratio ",
          FmtN[Last[dVals] / First[dVals], 4], "x -- a real but modest change, ",
          "not a dramatic one, over water's physically realistic liquid range; see AGENTS.md)"];
  ];

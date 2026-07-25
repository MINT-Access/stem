(* ========================================================
   quantum_statistics/src/output.wl — CSV export and console summaries
   ======================================================== *)


(* ExportSpectrumCSV — eps, n_BE, n_FD, n_MB *)
ExportSpectrumCSV[model_Association, outCSV_String] :=
  Module[{n, header, rows, beCol},
    n = model["nSteps"];
    beCol = Replace[model["beArr"], _Missing -> "", {1}];
    header = {{"epsilon_eV", "n_BE", "n_FD", "n_MB"}};
    rows = Table[
      {model["epsArr"][[i]], beCol[[i]], model["fdArr"][[i]], model["mbArr"][[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 4]
  ];


(* ExportTemperatureCSV — T, n_BE, n_FD, n_MB, at the reference energy *)
ExportTemperatureCSV[model_Association, outCSV_String] :=
  Module[{n, header, rows, beCol},
    n = model["nSteps"];
    beCol = Replace[model["beArr"], _Missing -> "", {1}];
    header = {{"T_K", "n_BE", "n_FD", "n_MB"}};
    rows = Table[
      {model["TArr"][[i]], beCol[[i]], model["fdArr"][[i]], model["mbArr"][[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 4]
  ];


(* ExportFermiSeaCSV — eps, then one n_FD column per T (wide format) *)
ExportFermiSeaCSV[model_Association, outCSV_String] :=
  Module[{nEps, nT, header, rows},
    nEps = Length[model["epsArr"]]; nT = Length[model["TArr"]];
    header = {Join[{"epsilon_eV"}, ("n_FD_T" <> ToString[NumberForm[#, {6, 0}]] <> "K") & /@ model["TArr"]]};
    rows = Table[
      Join[{model["epsArr"][[i]]}, Table[model["fdByT"][[k, i]], {k, nT}]],
      {i, nEps}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, nEps, nT + 1]
  ];


(* PrintCorrectnessChecks — "Checks: 1[PASS] 2[FAIL] ..." line, consistent
   with the style used across the v1.5.0/v1.6.0 apps. *)
PrintCorrectnessChecks[classicalChk_Association, boundChk_Association,
                       stepChk_Association, divergeChk_Association] :=
  Print["  Checks: ",
    If[classicalChk["pass"], "1[PASS]", "1[FAIL]"], " ",
    If[boundChk["pass"],     "2[PASS]", "2[FAIL]"], " ",
    If[stepChk["pass"],      "3[PASS]", "3[FAIL]"], " ",
    If[divergeChk["pass"],   "4[PASS]", "4[FAIL]"]
  ];


PrintSpectrumSummary[model_Association] :=
  Module[{},
    STEMSection["Spectrum Summary"];
    Print["  Temperature: ", FmtN[model["T"], {6, 1}], " K   (kT = ",
          FmtN[$kBeV * model["T"], 6], " eV)"];
    Print["  Energy range: ", FmtN[model["epsMin"], 4], " to ", FmtN[model["epsMax"], 4], " eV,  ",
          model["nSteps"], " steps,  mu = 0"];
    Print["  n_MB range: [", FmtN[Min[model["mbArr"]], 4], ", ", FmtN[Max[model["mbArr"]], 4], "]"];
  ];


PrintTemperatureSummary[model_Association] :=
  Module[{},
    STEMSection["Temperature Summary"];
    Print["  Reference energy: ", FmtN[model["epsRef"], 4], " eV   mu = 0"];
    Print["  Temperature range: ", FmtN[model["TMin"], {8, 1}], " to ", FmtN[model["TMax"], {8, 1}], " K"];
    Print["  n_BE at T_min: ", FmtN[First[model["beArr"]], 4],
          "   n_BE at T_max: ", FmtN[Last[model["beArr"]], 6]];
  ];


PrintFermiSeaSummary[model_Association] :=
  Module[{},
    STEMSection["Fermi Sea Summary"];
    Print["  Fermi energy (mu): ", FmtN[model["muFermi"], 4], " eV"];
    Print["  Temperature steps: ", model["nTSteps"], "   range: ",
          FmtN[model["TMin"], {8, 1}], " to ", FmtN[model["TMax"], {8, 1}], " K"];
    Print["  10-90 transition width at coldest T: ",
          FmtN[2.0 * Log[9.0] * $kBeV * First[model["TArr"]], 6], " eV"];
    Print["  10-90 transition width at warmest T: ",
          FmtN[2.0 * Log[9.0] * $kBeV * Last[model["TArr"]], 6], " eV"];
  ];

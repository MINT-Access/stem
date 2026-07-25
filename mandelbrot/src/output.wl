(* ========================================================
   mandelbrot/src/output.wl — CSV export and console summaries
   ======================================================== *)


(* ExportMandelbrotCSV — hilbert_index, c_real, c_imag, iteration_count *)
ExportMandelbrotCSV[model_Association, outCSV_String] :=
  Module[{n, header, rows, c},
    n = model["nPixels"];
    header = {{"hilbert_index", "c_real", "c_imag", "iteration_count"}};
    rows = Table[
      c = GridToComplex[model["traversal"][[i, 1]], model["traversal"][[i, 2]], model["size"],
                        model["reMin"], model["reMax"], model["imMin"], model["imMax"]];
      {i, Re[c], Im[c], model["iterField"][[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 4]
  ];


(* ExportJuliaCSV — hilbert_index, z0_real, z0_imag, iteration_count *)
ExportJuliaCSV[model_Association, outCSV_String] :=
  Module[{n, header, rows, z0},
    n = model["nPixels"];
    header = {{"hilbert_index", "z0_real", "z0_imag", "iteration_count"}};
    rows = Table[
      z0 = GridToComplex[model["traversal"][[i, 1]], model["traversal"][[i, 2]], model["size"],
                         model["reMin"], model["reMax"], model["imMin"], model["imMax"]];
      {i, Re[z0], Im[z0], model["iterField"][[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 4]
  ];


(* ExportZoomCSV — level, magnification, hilbert_index, iteration_count *)
ExportZoomCSV[model_Association, outCSV_String] :=
  Module[{header, rows, levels, n},
    levels = model["levels"]; n = model["nPixels"];
    header = {{"level", "magnification", "hilbert_index", "iteration_count"}};
    rows = Flatten[Table[
      Table[
        {levels[[k]]["level"], levels[[k]]["magnification"], i, levels[[k]]["iterField"][[i]]},
        {i, n}
      ],
      {k, Length[levels]}
    ], 1];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], 4]
  ];


(* PrintCorrectnessChecks — "Checks: 1[PASS] 2[FAIL] ..." line, consistent
   with the style used across the v1.5.0/v1.6.0 apps. *)
PrintCorrectnessChecks[escapeChk_Association, memberChk_Association,
                       cardioidChk_Association, complexityChk_Association] :=
  Print["  Checks: ",
    If[escapeChk["pass"],     "1[PASS]", "1[FAIL]"], " ",
    If[memberChk["pass"],     "2[PASS]", "2[FAIL]"], " ",
    If[cardioidChk["pass"],   "3[PASS]", "3[FAIL]"], " ",
    If[complexityChk["pass"], "4[PASS]", "4[FAIL]"]
  ];


PrintMandelbrotSummary[model_Association] :=
  Module[{inSet, escaped},
    inSet = Count[model["iterField"], model["maxIter"]];
    escaped = model["nPixels"] - inSet;
    STEMSection["Mandelbrot Summary"];
    STEMPrintN["Grid", model["size"] * model["size"], "pixels"];
    Print["  Window: real [", model["reMin"], ", ", model["reMax"], "]  imag [",
          model["imMin"], ", ", model["imMax"], "]"];
    Print["  Max iterations: ", model["maxIter"]];
    Print["  Non-escaping (in the set, within budget): ", inSet, " (",
          FmtN[100.0 * inSet / model["nPixels"], {5, 1}], "%)"];
    Print["  Escaped: ", escaped, " (", FmtN[100.0 * escaped / model["nPixels"], {5, 1}], "%)"];
  ];


PrintJuliaSummary[model_Association] :=
  Module[{inSet},
    inSet = Count[model["iterField"], model["maxIter"]];
    STEMSection["Julia Summary"];
    Print["  c = ", FmtN[model["cRe"], 4], " + ", FmtN[model["cIm"], 4], "i   (",
          If[model["cIsInterior"], "inside", "outside"], " the Mandelbrot set -> ",
          If[model["cIsInterior"], "connected", "disconnected"], " Julia set)"];
    STEMPrintN["Grid", model["size"] * model["size"], "pixels"];
    Print["  Max iterations: ", model["maxIter"]];
    Print["  Non-escaping z0 points: ", inSet, " (", FmtN[100.0 * inSet / model["nPixels"], {5, 1}], "%)"];
  ];


PrintZoomSummary[model_Association] :=
  Module[{},
    STEMSection["Zoom Summary"];
    Print["  Centre: c = ", FmtN[model["cRe"], 8], " + ", FmtN[model["cIm"], 8], "i  (seahorse valley)"];
    Print["  Levels: ", model["nLevels"]];
    Do[
      Print["    level ", model["levels"][[k]]["level"], ": half-width=",
            FmtN[model["levels"][[k]]["halfWidth"], 8], "  magnification=",
            FmtN[model["levels"][[k]]["magnification"], {8, 1}], "x"],
      {k, model["nLevels"]}
    ];
  ];

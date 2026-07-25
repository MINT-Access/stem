(* ========================================================
   grover/src/output.wl — CSV export and console summaries
   ======================================================== *)


(* ExportSearchCSV — iteration, P(marked) *)
ExportSearchCSV[model_Association, outCSV_String] :=
  Module[{n, header, rows},
    n = Length[model["kArr"]];
    header = {{"iteration", "P_marked"}};
    rows = Table[{model["kArr"][[i]], model["probArr"][[i]]}, {i, n}];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 2]
  ];


(* ExportCompareCSV — N, classical queries, quantum queries (across the swept range) *)
ExportCompareCSV[model_Association, outCSV_String] :=
  Module[{n, header, rows},
    n = Length[model["nArr"]];
    header = {{"N", "classical_queries", "quantum_queries"}};
    rows = Table[
      {model["nArr"][[i]], model["classicalArr"][[i]], model["quantumArr"][[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 3]
  ];


(* ExportGeometryCSV — iteration, angle, amplitude on marked state *)
ExportGeometryCSV[model_Association, outCSV_String] :=
  Module[{n, header, rows},
    n = Length[model["kArr"]];
    header = {{"iteration", "angle_rad", "amplitude_marked"}};
    rows = Table[
      {model["kArr"][[i]], model["angleArr"][[i]], model["ampMarkedArr"][[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 3]
  ];


(* PrintCorrectnessChecks — "Checks: 1[PASS] 2[FAIL] ..." line, consistent
   with the style used across the v1.5.0/v1.6.0 apps. *)
PrintCorrectnessChecks[rotChk_Association, optKChk_Association,
                       unitaryChk_Association, closedFormChk_Association] :=
  Print["  Checks: ",
    If[rotChk["pass"],        "1[PASS]", "1[FAIL]"], " ",
    If[optKChk["pass"],       "2[PASS]", "2[FAIL]"], " ",
    If[unitaryChk["pass"],    "3[PASS]", "3[FAIL]"], " ",
    If[closedFormChk["pass"], "4[PASS]", "4[FAIL]"]
  ];


PrintSearchSummary[model_Association] :=
  Module[{peakProb},
    peakProb = Max[model["probArr"]];
    STEMSection["Search Summary"];
    STEMPrintN["N (items)", model["nItems"]];
    Print["  Marked index: ", model["markedIdx"]];
    Print["  theta = ArcSin[1/Sqrt[N]]: ", FmtN[model["theta"], 6], " rad"];
    Print["  Optimal iteration k: ", model["optimalK"],
          "   P(marked) at optimum: ", FmtN[GroverProbMarked[model["nItems"], model["optimalK"]], 6]];
    Print["  P(marked) at final iteration shown (k=", Last[model["kArr"]], "): ", FmtN[Last[model["probArr"]], 6]];
  ];


PrintCompareSummary[model_Association] :=
  Module[{speedup},
    speedup = model["classicalAtN"] / Max[model["quantumAtN"], 1];
    STEMSection["Compare Summary"];
    STEMPrintN["N (items)", model["nItems"]];
    Print["  Classical (average-case linear search): ", FmtN[model["classicalAtN"], {8, 1}], " queries"];
    Print["  Quantum (Grover, optimal): ", model["quantumAtN"], " queries"];
    Print["  Speedup at this N: ", FmtN[speedup, 4], "x"];
  ];


PrintGeometrySummary[model_Association] :=
  Module[{},
    STEMSection["Geometry Summary"];
    STEMPrintN["N (items)", model["nItems"]];
    Print["  theta = ArcSin[1/Sqrt[N]]: ", FmtN[model["theta"], 6], " rad  (",
          FmtN[model["theta"] * 180.0 / Pi, {6, 3}], " deg)"];
    Print["  Rotation per iteration: 2*theta = ", FmtN[2.0 * model["theta"], 6], " rad"];
    Print["  Total rotation over ", model["nIterations"], " iterations: ",
          FmtN[Last[model["angleArr"]], {8, 3}], " rad"];
  ];

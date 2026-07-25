(* ========================================================
   bell/src/output.wl — CSV export and console summaries
   ======================================================== *)


(* ExportCorrelationsCSV — angle difference, quantum E, classical-model E *)
ExportCorrelationsCSV[model_Association, outCSV_String] :=
  Module[{n, header, rows},
    n = model["nSteps"];
    header = {{"delta_deg", "E_quantum", "E_classical"}};
    rows = Table[
      {model["deltaDegArr"][[i]], model["EQuantumArr"][[i]], model["EClassicalArr"][[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 3]
  ];


(* ExportChshCSV — the four correlation terms, S, and both bounds (single row) *)
ExportChshCSV[model_Association, outCSV_String] :=
  Module[{header, rows},
    header = {{"a_deg", "ap_deg", "b_deg", "bp_deg",
                "E_ab", "E_abp", "E_apb", "E_apbp",
                "S", "classical_bound", "quantum_bound"}};
    rows = {{model["aDeg"], model["apDeg"], model["bDeg"], model["bpDeg"],
              model["Eab"], model["Eabp"], model["Eapb"], model["Eapbp"],
              model["S"], model["classicalBound"], model["quantumBound"]}};
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, 1, 11]
  ];


(* ExportMeasurementCSV — trial, Alice outcome, Bob outcome, running correlation *)
ExportMeasurementCSV[model_Association, outCSV_String] :=
  Module[{n, header, rows},
    n = model["nTrials"];
    header = {{"trial", "alice_outcome", "bob_outcome", "running_correlation"}};
    rows = Table[
      {i, model["aOutcomes"][[i]], model["bOutcomes"][[i]], model["runningCorr"][[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 4]
  ];


(* PrintCorrectnessChecks — "Checks: 1[PASS] 2[FAIL] ..." line, consistent
   with the style used across the v1.5.0/v1.6.0 apps. *)
PrintCorrectnessChecks[normChk_Association, corrChk_Association,
                       chshChk_Association, lhvChk_Association] :=
  Print["  Checks: ",
    If[normChk["pass"], "1[PASS]", "1[FAIL]"], " ",
    If[corrChk["pass"], "2[PASS]", "2[FAIL]"], " ",
    If[chshChk["pass"], "3[PASS]", "3[FAIL]"], " ",
    If[lhvChk["pass"],  "4[PASS]", "4[FAIL]"]
  ];


PrintCorrelationsSummary[model_Association] :=
  Module[{},
    STEMSection["Correlations Summary"];
    STEMPrintN["Steps", model["nSteps"]];
    Print["  Bob's fixed angle: ", FmtN[model["bAngleDeg"], {6, 2}], " deg"];
    Print["  E(a,b) range: [", FmtN[Min[model["EQuantumArr"]], 4], ", ",
          FmtN[Max[model["EQuantumArr"]], 4], "]  (classical range: [",
          FmtN[Min[model["EClassicalArr"]], 4], ", ", FmtN[Max[model["EClassicalArr"]], 4], "])"];
  ];


PrintChshSummary[model_Association] :=
  Module[{},
    STEMSection["CHSH Summary"];
    Print["  Settings (deg): a=", FmtN[model["aDeg"], {6, 2}], "  a'=", FmtN[model["apDeg"], {6, 2}],
          "  b=", FmtN[model["bDeg"], {6, 2}], "  b'=", FmtN[model["bpDeg"], {6, 2}]];
    Print["  E(a,b)=", FmtN[model["Eab"], 4], "  E(a,b')=", FmtN[model["Eabp"], 4],
          "  E(a',b)=", FmtN[model["Eapb"], 4], "  E(a',b')=", FmtN[model["Eapbp"], 4]];
    Print["  S = ", FmtN[model["S"], 6], "   classical limit = ", FmtN[model["classicalBound"], 4],
          "   Tsirelson limit = ", FmtN[model["quantumBound"], 6]];
    Print["  S exceeds the classical limit by: ", FmtN[model["S"] - model["classicalBound"], 6]];
  ];


PrintMeasurementSummary[model_Association] :=
  Module[{},
    STEMSection["Measurement Summary"];
    STEMPrintN["Trials", model["nTrials"]];
    Print["  Settings: a=", FmtN[model["aDeg"], {6, 2}], " deg   b=", FmtN[model["bDeg"], {6, 2}], " deg"];
    Print["  True E(a,b): ", FmtN[model["trueE"], 6]];
    Print["  Empirical correlation (final): ", FmtN[Last[model["runningCorr"]], 6]];
    Print["  Alice's marginal frequency of +1: ", FmtN[model["marginalA"], 6],
          "   Bob's: ", FmtN[model["marginalB"], 6], "  (both should sit near 0.5 — no-signalling)"];
  ];

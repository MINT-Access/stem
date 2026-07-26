(* ========================================================
   qubit/src/output.wl — CSV export and console summaries
   ======================================================== *)


(* ExportGatesCSV — one row per gate (not per animation frame):
   gate name, resulting state, Bloch coordinates. Row 0 is the
   initial state before any gate is applied. *)
ExportGatesCSV[gatesResult_Association, outCSV_String] :=
  Module[{states, names, n, header, rows, r},
    states = gatesResult["states"];
    names  = gatesResult["gateNames"];
    n = Length[states];
    header = {{"n", "gate", "alpha_re", "alpha_im", "beta_re", "beta_im",
                "bloch_x", "bloch_y", "bloch_z"}};
    rows = Table[
      r = BlochVector[states[[i, 1]], states[[i, 2]]];
      {i - 1, If[i === 1, "(initial)", names[[i - 1]]],
       Re[states[[i, 1]]], Im[states[[i, 1]]], Re[states[[i, 2]]], Im[states[[i, 2]]],
       r[[1]], r[[2]], r[[3]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 9]
  ];


(* ExportRabiCSV — t, P(0), P(1) *)
ExportRabiCSV[tVals_List, p1Vals_List, outCSV_String] :=
  Module[{n, header, rows},
    n = Length[tVals];
    header = {{"t", "P0", "P1"}};
    rows = Table[{tVals[[i]], 1.0 - p1Vals[[i]], p1Vals[[i]]}, {i, n}];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 3]
  ];


(* ExportMeasurementCSV — trial, outcome, running frequency of outcome 0 *)
ExportMeasurementCSV[trialsResult_Association, outCSV_String] :=
  Module[{n, outcomes, runningFreq0, header, rows},
    n = trialsResult["nTrials"];
    outcomes = trialsResult["outcomes"];
    runningFreq0 = trialsResult["runningFreq0"];
    header = {{"trial", "outcome", "running_P0"}};
    rows = Table[{i, outcomes[[i]], runningFreq0[[i]]}, {i, n}];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 3]
  ];


(* PrintCorrectnessChecks — "Checks: 1[PASS] 2[FAIL] ..." line,
   consistent with the style used across the v1.5.0 apps. *)
PrintCorrectnessChecks[unitaryChk_Association, blochChk_Association,
                       rabiChk_Association, bornChk_Association] :=
  Print["  Checks: ",
    If[unitaryChk["pass"], "1[PASS]", "1[FAIL]"], " ",
    If[blochChk["pass"],   "2[PASS]", "2[FAIL]"], " ",
    If[rabiChk["pass"],    "3[PASS]", "3[FAIL]"], " ",
    If[bornChk["pass"],    "4[PASS]", "4[FAIL]"]
  ];


(* PrintGatesSummary *)
PrintGatesSummary[gatesResult_Association] :=
  Module[{finalState, finalR},
    finalState = Last[gatesResult["states"]];
    finalR = BlochVector[finalState[[1]], finalState[[2]]];
    STEMSection["Gates Summary"];
    Print["  Sequence: ", StringRiffle[gatesResult["gateNames"], ", "]];
    STEMPrintN["Gates applied", Length[gatesResult["gateNames"]]];
    Print["  Final state: ", FmtN[Re[finalState[[1]]], 4], "+", FmtN[Im[finalState[[1]]], 4],
          "i |0> + ", FmtN[Re[finalState[[2]]], 4], "+", FmtN[Im[finalState[[2]]], 4], "i |1>"];
    Print["  Final Bloch vector: (", FmtN[finalR[[1]], 4], ", ", FmtN[finalR[[2]], 4],
          ", ", FmtN[finalR[[3]], 4], ")   |r| = ", FmtN[Norm[finalR], 8]];
  ];


(* PrintRabiSummary *)
PrintRabiSummary[Omega_?NumericQ, tMax_?NumericQ] :=
  Module[{period},
    period = 2.0 * Pi / Omega;
    STEMSection["Rabi Summary"];
    Print["  Omega: ", FmtN[Omega, 4], "   Duration: ", FmtN[tMax, 4]];
    Print["  Rabi period 2*Pi/Omega: ", FmtN[period, 4],
          "  (", FmtN[tMax / period, 3], " periods shown)"];
  ];


(* PrintMeasurementSummary *)
PrintMeasurementSummary[trialsResult_Association] :=
  Module[{},
    STEMSection["Measurement Summary"];
    STEMPrintN["Trials", trialsResult["nTrials"]];
    Print["  True P(0) = |alpha|^2: ", FmtN[trialsResult["trueP0"], 6]];
    Print["  Empirical P(0) (final): ", FmtN[Last[trialsResult["runningFreq0"]], 6]];
    Print["  Empirical P(0) (after 10 trials): ",
          FmtN[trialsResult["runningFreq0"][[Min[10, trialsResult["nTrials"]]]], 6]];
  ];

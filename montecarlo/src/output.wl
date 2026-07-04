(* ========================================================
   montecarlo/src/output.wl — CSV export, correctness-check
   printing, and console summaries
   ======================================================== *)


(* ── Correctness checks (PASS/FAIL, printed every run) ───────────── *)

PrintOnsagerCheck[check_Association] :=
  Print["  [", If[check["pass"], "PASS", "FAIL"], "] Onsager T_c: computed = ",
        FmtN[check["computed"], 8], "  known = ", FmtN[check["known"], 8],
        "  (error ", FmtN[check["error"], 4], ")"];

PrintEnergyBoundsCheck[check_Association, jCoupling_?NumericQ] :=
  Print["  [", If[check["pass"], "PASS", "FAIL"], "] Energy bounds: min = ",
        FmtN[check["minE"], 5], "  max = ", FmtN[check["maxE"], 5],
        "  (expected within [-2J, ~0], J = ", jCoupling, ")"];

PrintDetailedBalanceCheck[check_Association] :=
  Print["  [", If[check["pass"], "PASS", "FAIL"], "] Detailed balance: dE = ",
        FmtN[check["dE"], 5], "  ratio = ", FmtN[check["ratio"], 6],
        "  Exp[-dE/T] = ", FmtN[check["expected"], 6]];

PrintMagnetisationConvergenceCheck[check_Association] :=
  Print["  [", If[check["pass"], "PASS", "FAIL"], "] Magnetisation convergence (T<1.0): ",
        "min |M| = ", If[Length[check["coldM"]] > 0, FmtN[Min[check["coldM"]], 4], "n/a"],
        "  across ", Length[check["coldM"]], " cold-temperature samples (expect > 0.8)"];


(* ── CSV export ───────────────────────────────────────────────────── *)

(* ExportSweepCSV — columns: sweep_index, T, M, E_per_spin, abs_dM,
   chi_estimate, articulated. chi_estimate is one value per temperature
   step (computed from that step's own measurement sweeps), repeated
   across every row in that step's block. *)
ExportSweepCSV[sweepResult_Association, articulated_List, outCSV_String] :=
  Module[{sweepIdx, TVals, MVals, EVals, chiPerStep, nMeasurement, n, chiExpanded,
          absDM, header, rows},
    sweepIdx     = sweepResult["sweepIdx"];
    TVals        = sweepResult["T"];
    MVals        = sweepResult["M"];
    EVals        = sweepResult["E"];
    chiPerStep   = sweepResult["chiPerStep"];
    nMeasurement = sweepResult["nMeasurement"];
    n = Length[sweepIdx];

    chiExpanded = Flatten[Table[ConstantArray[chiPerStep[[s]], nMeasurement], {s, Length[chiPerStep]}]];
    absDM = Prepend[Abs[Differences[MVals]], 0.0];

    header = {{"sweep_index", "T", "M", "E_per_spin", "abs_dM", "chi_estimate", "articulated"}};
    rows = Table[
      {sweepIdx[[i]], TVals[[i]], MVals[[i]], EVals[[i]], absDM[[i]], chiExpanded[[i]], articulated[[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 7]
  ];

(* ExportFixedTCSV — shared by critical and quench modes (both run at a
   single fixed temperature and record every sweep individually, unlike
   sweep mode's per-temperature-block structure). *)
ExportFixedTCSV[modeResult_Association, articulated_List, outCSV_String] :=
  Module[{sweepIdx, MVals, EVals, chiVals, T, n, absDM, header, rows},
    sweepIdx = modeResult["sweepIdx"];
    MVals    = modeResult["M"];
    EVals    = modeResult["E"];
    chiVals  = modeResult["chi"];
    T        = modeResult["T"];
    n = Length[sweepIdx];

    absDM = Prepend[Abs[Differences[MVals]], 0.0];
    header = {{"sweep_index", "T", "M", "E_per_spin", "abs_dM", "chi_estimate", "articulated"}};
    rows = Table[
      {sweepIdx[[i]], T, MVals[[i]], EVals[[i]], absDM[[i]], chiVals[[i]], articulated[[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 7]
  ];


(* ── Console summaries ───────────────────────────────────────────── *)

PrintSweepSummary[sweepResult_Association, Tc_?NumericQ, sonifyResult_Association] :=
  Module[{TVals = sweepResult["TVals"]},
    STEMSection["Sweep Summary"];
    Print["  Lattice: ", sweepResult["nSize"], " x ", sweepResult["nSize"]];
    Print["  T range: ", FmtN[First[TVals], 5], " -> ", FmtN[Last[TVals], 5],
          "  (", Length[TVals], " steps, crossing T_c = ", FmtN[Tc, 5], ")"];
    Print["  Final |M|: ", FmtN[Abs[Last[sweepResult["M"]]], 5]];
    Print["  T_c crossing event: ", If[Length[sonifyResult["tcCrossingIdx"]] > 0, "fired", "did not fire"]];
    Print["  Magnetisation sign flips: ", Length[sonifyResult["signFlipIdx"]]];
    Print["  Susceptibility peaks: ", Length[sonifyResult["susceptibilityPeakIdx"]]];
    Print["  Spatial-layer snapshots sonified: ", sonifyResult["nSpatialSnapshots"]]
  ];

PrintCriticalSummary[critResult_Association, Tc_?NumericQ, sonifyResult_Association] :=
  Module[{},
    STEMSection["Critical Summary"];
    Print["  Lattice: ", critResult["nSize"], " x ", critResult["nSize"], "   T = T_c = ", FmtN[Tc, 5]];
    Print["  Sweeps: ", Length[critResult["sweepIdx"]]];
    Print["  M range: ", FmtN[Min[critResult["M"]], 4], " -> ", FmtN[Max[critResult["M"]], 4]];
    Print["  Magnetisation sign flips: ", Length[sonifyResult["signFlipIdx"]]];
    Print["  Susceptibility peaks: ", Length[sonifyResult["susceptibilityPeakIdx"]]]
  ];

PrintQuenchSummary[quenchResult_Association, TCold_?NumericQ, sonifyResult_Association] :=
  Module[{},
    STEMSection["Quench Summary"];
    Print["  Lattice: ", quenchResult["nSize"], " x ", quenchResult["nSize"], "   T_cold = ", FmtN[TCold, 4]];
    Print["  Sweeps: ", Length[quenchResult["sweepIdx"]]];
    Print["  Initial |M|: ", FmtN[Abs[First[quenchResult["M"]]], 5]];
    Print["  Final |M|:   ", FmtN[Abs[Last[quenchResult["M"]]], 5]];
    Print["  Magnetisation sign flips (domain reversals): ", Length[sonifyResult["signFlipIdx"]]]
  ];

(* ========================================================
   quantum_tunnelling/src/output.wl — CSV export and console summaries
   ======================================================== *)


(* ── Mode 1: barrier ──────────────────────────────────────────────── *)

ExportBarrierCSV[model_Association, outCSV_String] :=
  Module[{header, row},
    header = {{"preset", "E_eV", "V0_eV", "L_nm", "mc2_eV", "T", "R", "regime"}};
    row = {{model["preset"], model["E"], model["V0"], model["L"], model["mc2"],
            model["T"], model["R"], model["regime"]}};
    ExportCSV[Join[header, row], outCSV];
    STEMDescribeCSV[outCSV, 1, 8]
  ];

PrintBarrierSummary[model_Association] :=
  Module[{},
    STEMSection["Barrier Summary"];
    Print["  Preset: ", model["preset"], "  (", model["regime"], " regime)"];
    STEMPrintN["Particle energy E",  model["E"],  "eV", 5];
    STEMPrintN["Barrier height V0",  model["V0"], "eV", 5];
    STEMPrintN["Barrier width L",    model["L"],  "nm", 6];
    STEMPrintN["Transmission T",     model["T"] * 100.0, "%", 6];
    STEMPrintN["Reflection R",       model["R"] * 100.0, "%", 6]
  ];


(* ── Mode 2: sweep ────────────────────────────────────────────────── *)

ExportSweepCSV[model_Association, outCSV_String] :=
  Module[{header, n, rows},
    header = {{"step", "width_nm", "T", "R"}};
    n = model["nSteps"];
    rows = Table[
      {i - 1, model["LArr"][[i]], model["TArr"][[i]], model["RArr"][[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 4]
  ];

PrintSweepSummary[model_Association] :=
  Module[{},
    STEMSection["Sweep Summary"];
    STEMPrintN["Particle energy E", model["E"],  "eV", 5];
    STEMPrintN["Barrier height V0", model["V0"], "eV", 5];
    Print["  Width range: ", FmtN[model["widthMin"], 4], " nm -> ", FmtN[model["widthMax"], 4], " nm"];
    Print["  T range: ", FmtN[First[model["TArr"]], 6], " -> ", FmtN[Last[model["TArr"]], 6]]
  ];


(* ── Mode 3: energy ───────────────────────────────────────────────── *)

ExportEnergyCSV[model_Association, outCSV_String] :=
  Module[{header, n, rows},
    header = {{"step", "E_eV", "T", "R", "regime"}};
    n = model["nSteps"];
    rows = Table[
      {i - 1, model["EArr"][[i]], model["TArr"][[i]], model["RArr"][[i]],
       If[model["EArr"][[i]] < model["V0"], "tunnelling", "above-barrier"]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 5]
  ];

PrintEnergySummary[model_Association] :=
  Module[{},
    STEMSection["Energy Summary"];
    STEMPrintN["Barrier height V0", model["V0"], "eV", 5];
    STEMPrintN["Barrier width L",   model["L"],  "nm", 6];
    Print["  Energy range: ", FmtN[model["EMin"], 4], " eV -> ", FmtN[model["EMax"], 4], " eV"];
    Print["  T range: ", FmtN[Min[model["TArr"]], 6], " -> ", FmtN[Max[model["TArr"]], 6]]
  ];

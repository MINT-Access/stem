(* ========================================================
   dynamical/src/output.wl — CSV export and console summary
   ======================================================== *)


(* PitchPanVolume
   Recomputes pitch/pan/volume for a parallel {xVals, speeds} pair,
   using the exact same formulas as sonify.wl's SynthesizeDiscreteNotes,
   for CSV export (kept separate from audio synthesis so CSV export
   doesn't need to carry per-note buffers around). *)
PitchPanVolume[xVals_List, speeds_List] :=
  Module[{pitchScale, rootHz, speedMax, pitches, pans, vols},
    pitchScale = PitchScale3Octaves[];
    rootHz     = $dynamicalRootHz;
    speedMax   = Max[speeds];
    If[speedMax <= 0, speedMax = 1.0];
    pitches = Map[ScaleLookup[#, 0.0, 1.0, pitchScale, rootHz] &, xVals];
    pans    = Map[Clip[Rescale[#, {0.0, 1.0}, {-1.0, 1.0}], {-1.0, 1.0}] &, xVals];
    vols    = Map[Clip[0.25 + 0.70 * (# / speedMax), {0.25, 0.95}] &, speeds];
    {pitches, pans, vols}
  ];


(* ExportSweepCSV
   Columns: r, iteration_index, x_n, pitch_hz, pan, volume, event_label *)
ExportSweepCSV[sweepResult_Association, rValues_List, outCSV_String] :=
  Module[{xVals, speeds, rVals, iterIdx, n, pitches, pans, vols,
          eventStepIndices, eventRValueOf, labels, header, rows},

    xVals   = sweepResult["xVals"];
    speeds  = sweepResult["speeds"];
    rVals   = sweepResult["rVals"];
    iterIdx = sweepResult["iterIdx"];
    eventStepIndices = sweepResult["eventStepIndices"];
    n = Length[xVals];

    {pitches, pans, vols} = PitchPanVolume[xVals, speeds];

    eventRValueOf = Association[Map[# -> rValues[[eventStepIndices[#]]] &, Keys[eventStepIndices]]];
    labels = Map[
      Function[rv,
        With[{hit = Select[Keys[eventRValueOf], eventRValueOf[#] === rv &]},
          If[Length[hit] > 0, First[hit], ""]
        ]
      ],
      rVals
    ];

    header = {{"r", "iteration_index", "x_n", "pitch_hz", "pan", "volume", "event_label"}};
    rows = Table[
      {rVals[[i]], iterIdx[[i]], xVals[[i]], pitches[[i]], pans[[i]], vols[[i]], labels[[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 7]
  ];


(* ExportIterateCSV
   Columns: n, x_n, pitch_hz, pan, volume *)
ExportIterateCSV[iterateResult_Association, outCSV_String] :=
  Module[{xVals, speeds, n, pitches, pans, vols, header, rows},
    xVals  = iterateResult["xVals"];
    speeds = iterateResult["speeds"];
    n = Length[xVals];

    {pitches, pans, vols} = PitchPanVolume[xVals, speeds];

    header = {{"n", "x_n", "pitch_hz", "pan", "volume"}};
    rows = Table[{i - 1, xVals[[i]], pitches[[i]], pans[[i]], vols[[i]]}, {i, n}];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 5]
  ];


(* PrintCorrectnessChecks
   Prints the "Checks: 1[PASS] 2[FAIL] ..." line, consistent with the
   style used in lagrange/relativity/cosmology/waves main.wl files. *)
PrintCorrectnessChecks[feigenbaum_Association, fixedPoint_Association,
                       period2_Association, lyapunov_Association] :=
  Print["  Checks: ",
    If[feigenbaum["pass"], "1[PASS]", "1[FAIL]"], " ",
    If[fixedPoint["pass"],  "2[PASS]", "2[FAIL]"], " ",
    If[period2["pass"],     "3[PASS]", "3[FAIL]"], " ",
    If[lyapunov["pass"],    "4[PASS]", "4[FAIL]"]
  ];


(* PrintSweepSummary *)
PrintSweepSummary[sweepModel_Association, eventRs_Association] :=
  Module[{rValues},
    rValues = sweepModel["rValues"];
    STEMSection["Sweep Summary"];
    STEMPrintN["r range", First[rValues], "", 4];
    Print["  r_end: ", FmtN[Last[rValues], 4]];
    STEMPrintN["r steps", Length[rValues]];
    Print["  First bifurcation r:  ", FmtN[eventRs["first_bifurcation"], 5]];
    Print["  Chaos onset r:        ", FmtN[eventRs["chaos_onset"], 5]];
    Print["  Period-3 window r:    ", FmtN[eventRs["period3_window"], 5]];
  ];


(* PrintIterateSummary *)
PrintIterateSummary[iterateModel_Association] :=
  Module[{traj, distinct},
    traj = iterateModel["trajectory"];
    STEMSection["Iterate Summary"];
    Print["  r: ", FmtN[iterateModel["r"], 6]];
    STEMPrintN["Iterations", iterateModel["nIterations"]];
    Print["  x range: [", FmtN[Min[traj], 4], ", ", FmtN[Max[traj], 4], "]"];
    distinct = Length[DeleteDuplicates[Round[traj[[-40 ;;]], 0.001]]];
    Print["  Distinct values in last 40 (rounded): ", distinct];
  ];

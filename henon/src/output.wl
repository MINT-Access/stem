(* ========================================================
   henon/src/output.wl — CSV export and console summaries
   ======================================================== *)


(* AttractorPitchPanVolume
   Recomputes, at the ORIGINAL per-iterate resolution (not the
   resampled audio-sample grid), the same pan/pitch/volume
   formulas stem-core's SpatialLayer applies inside
   SonifyTrajectory: pan from x's own MinMax rescaled into
   cfg's pan_range; pitch from y's own MinMax rescaled into
   cfg's [min_hz,max_hz]; volume from speed's own MinMax
   rescaled into cfg's [min_db,max_db]. Kept in output.wl,
   separate from sonify.wl, exactly as dynamical/'s
   PitchPanVolume is — CSV export shouldn't need to carry
   per-sample audio buffers around. *)
AttractorPitchPanVolume[trajectory_List, cfg_Association] :=
  Module[{xs, ys, speeds, panRange, pitchRange, volRange, pans, pitches, vols},
    xs     = trajectory[[All, 2]];
    ys     = trajectory[[All, 3]];
    speeds = trajectory[[All, 5]];

    panRange   = CfgAt[cfg, {"sonification", "spatial", "pan_range"}, {-1.0, 1.0}];
    pitchRange = {CfgAt[cfg, {"sonification", "pitch", "min_hz"}, 110],
                  CfgAt[cfg, {"sonification", "pitch", "max_hz"}, 880]};
    volRange   = {CfgAt[cfg, {"sonification", "volume", "min_db"}, -24],
                  CfgAt[cfg, {"sonification", "volume", "max_db"},   0]};

    pans    = Clip[Rescale[xs, MinMax[xs], panRange], panRange];
    pitches = Rescale[ys, MinMax[ys], pitchRange];
    vols    = Rescale[speeds, MinMax[speeds], volRange];
    {pitches, pans, vols}
  ];

(* CfgAt duplicated from stem-core/sonification.wl's private helper —
   needed here since that symbol isn't exported by the package, and
   this is the one place outside stem-core that needs the same
   nested-key-path lookup for CSV export purposes. *)
CfgAt[cfg_Association, keys_List, default_] :=
  With[{inner = Fold[Lookup[#1, #2, <||>] &, cfg, Most[keys]]},
    Lookup[inner, Last[keys], default]
  ];


(* ExportAttractorCSV — columns: n, x, y, pitch_hz, pan, volume_db *)
ExportAttractorCSV[trajectory_List, cfg_Association, outCSV_String] :=
  Module[{n, pitches, pans, vols, header, rows},
    n = Length[trajectory];
    {pitches, pans, vols} = AttractorPitchPanVolume[trajectory, cfg];
    header = {{"n", "x", "y", "pitch_hz", "pan", "volume_db"}};
    rows = Table[
      {i - 1, trajectory[[i, 2]], trajectory[[i, 3]], pitches[[i]], pans[[i]], vols[[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 6]
  ];


(* ExportSweepCSV — columns: a, iteration_index, x_n, y_n, pitch_hz, pan, volume, event_label *)
ExportSweepCSV[sweepResult_Association, aValues_List, outCSV_String] :=
  Module[{xVals, yVals, speeds, aVals, iterIdx, n, pitchScale, speedMax,
          pitchRange, panRange, pitches, pans, vols,
          eventStepIndices, eventAValueOf, labels, header, rows},

    xVals   = sweepResult["xVals"];
    yVals   = sweepResult["yVals"];
    speeds  = sweepResult["speeds"];
    aVals   = sweepResult["aVals"];
    iterIdx = sweepResult["iterIdx"];
    eventStepIndices = sweepResult["eventStepIndices"];
    n = Length[xVals];

    pitchScale = HenonPitchScale[];
    speedMax   = Max[speeds];
    If[speedMax <= 0, speedMax = 1.0];
    pitchRange = MinMax[xVals];
    panRange   = MinMax[yVals];
    pitches = Map[ScaleLookup[#, pitchRange[[1]], pitchRange[[2]], pitchScale, $henonRootHz] &, xVals];
    pans    = Map[Clip[Rescale[#, panRange, {-1.0, 1.0}], {-1.0, 1.0}] &, yVals];
    vols    = Map[Clip[0.25 + 0.70 * (# / speedMax), {0.25, 0.95}] &, speeds];

    eventAValueOf = Association[Map[# -> aValues[[eventStepIndices[#]]] &, Keys[eventStepIndices]]];
    labels = Map[
      Function[av,
        With[{hit = Select[Keys[eventAValueOf], eventAValueOf[#] === av &]},
          If[Length[hit] > 0, First[hit], ""]
        ]
      ],
      aVals
    ];

    header = {{"a", "iteration_index", "x_n", "y_n", "pitch_hz", "pan", "volume", "event_label"}};
    rows = Table[
      {aVals[[i]], iterIdx[[i]], xVals[[i]], yVals[[i]], pitches[[i]], pans[[i]], vols[[i]], labels[[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 8]
  ];


(* ExportReverseCSV — columns: n, x, y, direction *)
ExportReverseCSV[reverseResult_Association, outCSV_String] :=
  Module[{xVals, yVals, labels, n, header, rows},
    xVals  = reverseResult["xVals"];
    yVals  = reverseResult["yVals"];
    labels = reverseResult["phaseLabels"];
    n = Length[xVals];
    header = {{"n", "x", "y", "direction"}};
    rows = Table[{i - 1, xVals[[i]], yVals[[i]], labels[[i]]}, {i, n}];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 4]
  ];


(* PrintCorrectnessChecks
   Prints the "Checks: 1[PASS] 2[FAIL] ..." line, consistent with the
   style used across the v1.5.0 apps (dynamical/relativity/cosmology). *)
PrintCorrectnessChecks[jacobian_Association, lyapSum_Association,
                       lyapBenchmark_Association, inverseExact_Association] :=
  Print["  Checks: ",
    If[jacobian["pass"],      "1[PASS]", "1[FAIL]"], " ",
    If[lyapSum["pass"],       "2[PASS]", "2[FAIL]"], " ",
    If[lyapBenchmark["pass"], "3[PASS]", "3[FAIL]"], " ",
    If[inverseExact["pass"],  "4[PASS]", "4[FAIL]"]
  ];


(* PrintAttractorSummary *)
PrintAttractorSummary[attractorModel_Association, dimension_?NumericQ] :=
  Module[{traj},
    traj = attractorModel["trajectory"];
    STEMSection["Attractor Summary"];
    Print["  a: ", FmtN[attractorModel["a"], 4], "   b: ", FmtN[attractorModel["b"], 4]];
    STEMPrintN["Points on attractor", Length[traj]];
    Print["  x range: [", FmtN[Min[traj[[All, 1]]], 4], ", ", FmtN[Max[traj[[All, 1]]], 4], "]"];
    Print["  y range: [", FmtN[Min[traj[[All, 2]]], 4], ", ", FmtN[Max[traj[[All, 2]]], 4], "]"];
    Print["  Box-counting dimension estimate: ", FmtN[dimension, 4],
          "  (diagnostic only — commonly cited range ~1.25-1.28)"];
  ];


(* PrintSweepSummary *)
PrintSweepSummary[sweepModel_Association, landmarks_Association] :=
  Module[{aValues},
    aValues = sweepModel["aValues"];
    STEMSection["Sweep Summary"];
    STEMPrintN["a range", First[aValues], "", 4];
    Print["  a_end: ", FmtN[Last[aValues], 4]];
    STEMPrintN["a steps", Length[aValues]];
    Print["  First bifurcation a (period 1->2, exact):  ", FmtN[landmarks["first_bifurcation"], 5]];
    Print["  Second bifurcation a (period 2->4, empirical): ", FmtN[landmarks["second_bifurcation"], 5]];
    Print["  Third bifurcation a (period 4->8, empirical):  ", FmtN[landmarks["third_bifurcation"], 5]];
    Print["  Chaos onset a (empirical):    ", FmtN[landmarks["chaos_onset"], 5]];
    Print["  Periodic window a (period ", landmarks["periodic_window_period"],
          ", empirical): ", FmtN[landmarks["periodic_window"], 5]];
    Print["  Feigenbaum-like ratio (informational, not a pass/fail check): ",
          FmtN[landmarks["feigenbaum_ratio"], 5], "   (universal delta = 4.6692...)"];
  ];


(* PrintReverseSummary *)
PrintReverseSummary[reverseModel_Association] :=
  Module[{},
    STEMSection["Reverse Summary"];
    Print["  a: ", FmtN[reverseModel["a"], 4], "   b: ", FmtN[reverseModel["b"], 4]];
    STEMPrintN["Forward segment points", Length[reverseModel["forwardSeg"]]];
    STEMPrintN["Inverse-demo steps", reverseModel["reverseSteps"]];
    Print["  Inverse-demo round-trip max error: ", FmtN[reverseModel["inverseDemoMaxError"], 12],
          "  (amplified from ~1e-16 by the area-expanding inverse map — see AGENTS.md)"];
  ];

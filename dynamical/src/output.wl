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
                       period2_Association, lyapunov_Association,
                       lyapunovCurve_Association, divergence_Association] :=
  Print["  Checks: ",
    If[feigenbaum["pass"], "1[PASS]", "1[FAIL]"], " ",
    If[fixedPoint["pass"],  "2[PASS]", "2[FAIL]"], " ",
    If[period2["pass"],     "3[PASS]", "3[FAIL]"], " ",
    If[lyapunov["pass"],    "4[PASS]", "4[FAIL]"], " ",
    If[lyapunovCurve["pass"], "5[PASS]", "5[FAIL]"], " ",
    If[divergence["pass"],    "6[PASS]", "6[FAIL]"]
  ];

(* PrintDivergenceCheck — check 6, one self-contained sentence per r. *)
PrintDivergenceCheck[chk_Association] :=
  MapIndexed[
    Function[{c, idx},
      Print["    6", FromCharacterCode[96 + idx[[1]]], ". ", If[c["pass"], "[PASS] ", "[FAIL] "],
        "At r = ", FmtDec[c["r"], 3], " two orbits started ", FmtN[N[chk["delta"]], 2],
        " apart ", If[c["lambda"] > 0, "separate", "converge"], " with a fitted slope of ",
        FmtN[c["slope"], 4], " per iteration (iterations 0 to ", c["fit"]["nEnd"],
        ") and LyapunovExponent predicts ", FmtN[c["lambda"], 4], "; they differ by ",
        FmtDec[100 * c["relError"], 1], " percent, ", If[c["pass"], "within", "outside"],
        " the tolerance of ", FmtDec[100 * chk["tolerance"]], " percent."]],
    chk["cases"]];

(* PrintLyapunovCurveCheck
   Check 5, one self-contained sentence per r value. *)
PrintLyapunovCurveCheck[chk_Association] :=
  Module[{tol = FmtDec[chk["tolerance"], 3]},
    MapIndexed[
      Function[{c, idx},
        Print["    5", FromCharacterCode[96 + idx[[1]]], ". ", If[c["pass"], "[PASS] ", "[FAIL] "],
          "At r = ", FmtDec[c["r"], 3], " the Lyapunov exponent is ", FmtN[c["lambda"], 6],
          If[NumericQ[c["expected"]],
            " and " <> c["what"] <> " is " <> FmtN[c["expected"], 6] <> "; they differ by " <>
              FmtN[Abs[c["lambda"] - c["expected"]], 3] <>
              If[c["pass"], ", within", ", outside"] <> " the tolerance of " <> tol <> ".",
            ", and " <> c["what"] <> If[c["pass"], "; it is.", "; it is not."]]]],
      chk["cases"]]
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


(* ── Lyapunov mode ─────────────────────────────────────────────────── *)

(* ExportLyapunovCSV
   Columns: r, lambda, at_floor, sweep_time_s, audio_time_s, lambda_tone_hz *)
ExportLyapunovCSV[sweep_List, floor_?NumericQ, durSec_?NumericQ, introSec_?NumericQ,
                  refHz_?NumericQ, octavesPerUnit_?NumericQ, outCSV_String] :=
  Module[{rMin = sweep[[1, 1]], rMax = sweep[[-1, 1]], rows},
    rows = Map[
      Function[{row},
        With[{t = LyapunovTimeOfR[row[[1]], rMin, rMax, durSec]},
          {row[[1]], row[[2]], If[row[[2]] <= floor, 1, 0], t, introSec + t,
           LyapunovToneHz[row[[2]], refHz, octavesPerUnit]}]],
      sweep];
    ExportCSV[Join[{{"r", "lambda", "at_floor", "sweep_time_s", "audio_time_s", "lambda_tone_hz"}}, rows],
              outCSV];
    STEMDescribeCSV[outCSV, Length[rows], 6]
  ];

(* PrintLyapunovSummary
   One sentence per line: every zero crossing with its r and audio time,
   the minimum and maximum lambda with their r, and the number of steps
   at the floor. introSec is the time before the sweep starts in the WAV. *)
PrintLyapunovSummary[sweep_List, crossings_List, floor_?NumericQ,
                     durSec_?NumericQ, introSec_?NumericQ] :=
  Module[{rs = sweep[[All, 1]], lams = sweep[[All, 2]], rMin, rMax, t,
          iMin, iMax, nFloor},
    rMin = First[rs]; rMax = Last[rs];
    STEMSection["Lyapunov Summary"];
    If[crossings === {},
      Print["  The Lyapunov exponent does not cross zero between r = ", FmtDec[rMin, 3],
            " and r = ", FmtDec[rMax, 3], "."]];
    Scan[
      Function[c,
        t = LyapunovTimeOfR[c["r"], rMin, rMax, durSec];
        Print["  The Lyapunov exponent crosses zero ", c["direction"], " at r = ",
              ToString[NumberForm[c["r"], {5, 3}], OutputForm], ", heard ",
              FmtDec[introSec + t, 2], " s into the audio (", FmtDec[t, 2],
              " s into the sweep)."]],
      crossings];
    iMin = First[Ordering[lams, 1]];
    iMax = First[Ordering[lams, -1]];
    nFloor = Count[lams, l_ /; l <= floor];
    Print["  The minimum Lyapunov exponent is ", FmtDec[lams[[iMin]], 3],
          If[lams[[iMin]] <= floor, " (the floor), first reached", ", reached"],
          " at r = ", ToString[NumberForm[rs[[iMin]], {5, 3}], OutputForm], "."];
    Print["  The maximum Lyapunov exponent is ", FmtDec[lams[[iMax]], 3],
          ", reached at r = ", ToString[NumberForm[rs[[iMax]], {5, 3}], OutputForm], "."];
    Print["  ", nFloor, " of ", Length[lams], " r steps sit at the floor of ",
          FmtDec[floor, 3], ", where the exponent was clipped."];
  ];

(* PrintLoudnessLine
   Measures the written WAV and prints its integrated loudness and peak. *)
PrintLoudnessLine[wavPath_String, targetLUFS_?NumericQ] :=
  Module[{data, sr, lufs, peak},
    data = Import[wavPath, "Data"]; sr = Import[wavPath, "SampleRate"];
    If[VectorQ[data], data = {data}];
    lufs = MeasureIntegratedLoudness[Audio[data, SampleRate -> sr]];
    peak = 20.0 * Log10[Max[Abs[Flatten[data]]]];
    Print["  Loudness: the WAV was normalised to ", FmtDec[targetLUFS, 1],
          " LUFS and measures ", FmtDec[lufs, 2], " LUFS integrated, with a peak of ",
          FmtDec[peak, 2], " dBFS."];
    <|"lufs" -> lufs, "peakDB" -> peak|>
  ];


(* ── Divergence mode ───────────────────────────────────────────────── *)

(* ExportDivergenceCSV
   Columns: n, x_n, y_n, separation, log10_separation, in_fit, note_start_s
   (seconds into the WAV), pitch_x_hz, pitch_y_hz, volume_x, volume_y *)
ExportDivergenceCSV[orbits_Association, fit_Association, mapping_Association,
                    noteDuration_?NumericQ, introSec_?NumericQ, outCSV_String] :=
  Module[{xs = orbits["x"], ys = orbits["y"], sep = orbits["separation"], rows},
    rows = Table[
      {i - 1, xs[[i]], ys[[i]], sep[[i]],
       If[sep[[i]] > 0, Log10[sep[[i]]], ""], If[i - 1 <= fit["nEnd"], 1, 0],
       introSec + (i - 1) * noteDuration,
       mapping["freqX"][[i]], mapping["freqY"][[i]], mapping["ampX"][[i]], mapping["ampY"][[i]]},
      {i, Length[xs]}];
    ExportCSV[Join[{{"n", "x_n", "y_n", "separation", "log10_separation", "in_fit",
                     "note_start_s", "pitch_x_hz", "pitch_y_hz", "volume_x", "volume_y"}}, rows],
              outCSV];
    STEMDescribeCSV[outCSV, Length[rows], 11]
  ];

(* PrintDivergenceSummary — one sentence per line. *)
PrintDivergenceSummary[orbits_Association, fit_Association, lambda_?NumericQ,
                       predicted_, saturation_?NumericQ, mapping_Association] :=
  Module[{sep = orbits["separation"], n = orbits["n"], iMax, nZero},
    STEMSection["Divergence Summary"];
    If[fit["saturated"],
      Print["  The separation first exceeded ", FmtDec[saturation], " at iteration ", fit["nSat"],
            "; the Lyapunov exponent predicts iteration ", FmtDec[predicted, 1],
            " (Log[", FmtDec[saturation], "/delta]/lambda)."],
      nZero = FirstPosition[sep, 0., {Missing[]}, {1}][[1]];
      Print["  The separation never exceeded ", FmtDec[saturation], " in ", n,
            " iterations; the final separation is ",
            If[IntegerQ[nZero], "exactly 0, reached at iteration " <> ToString[nZero - 1],
               FmtN[Last[sep], 3]], "."];
      Print["  ", If[NumericQ[predicted],
        "The Lyapunov exponent " <> FmtN[lambda, 3] <> " predicts saturation after " <>
          FmtDec[predicted, 0] <> " iterations, beyond the " <> ToString[n] <> " computed.",
        "The Lyapunov exponent " <> FmtN[lambda, 3] <> " is negative, so it predicts that " <>
          "the separation shrinks and never saturates."]]];
    Print["  The fitted slope is ", FmtN[fit["slope"], 4], " per iteration over iterations 0 to ",
          fit["nEnd"], ", the predicted Lyapunov exponent is ", FmtN[lambda, 4],
          ", and their ratio is ", FmtN[fit["slope"] / lambda, 3], "."];
    iMax = First[Ordering[sep, -1]];
    Print["  The maximum separation reached is ", FmtN[sep[[iMax]], 3], ", at iteration ", iMax - 1, "."];
    Print["  The note mapping's resolution is ", FmtN[mapping["resolution"], 3],
          " (pitch bin ", FmtN[mapping["pitchBin"], 3], " in x, volume bin ",
          FmtN[mapping["volumeBin"], 3], " in step size); ",
          If[IntegerQ[mapping["firstDifferentNote"]],
            "the two orbits first get different notes at iteration " <>
              ToString[mapping["firstDifferentNote"]] <> ", where the separation is " <>
              FmtN[sep[[mapping["firstDifferentNote"] + 1]], 3] <> ".",
            "the two orbits get the same note at every iteration, so the left and right " <>
              "channels are identical throughout."]];
  ];

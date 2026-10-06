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

(* PrintFeigenbaumCheck
   Check 1, one self-contained sentence per line: the five bisected
   period-doubling points, then each ratio delta_k with its difference
   from the constant, then the verdict. *)
PrintFeigenbaumCheck[chk_Association] :=
  Module[{d = $FeigenbaumConstant, dTxt = "4.669201609", pts = chk["points"], side},
    If[!TrueQ[chk["resolved"]],
      Print["    1. [FAIL] The period-doubling points r1 to r5 could not all be located; the search stopped at ",
            ToString[Select[pts, !AssociationQ[#] &]], "."];
      Return[Null]];
    Print["    1a. The period-doubling points, located by bisection where the cycle's multiplier reaches -1 ",
          "(each to a half-width below ", FmtN[chk["maxHalfWidth"], 2], " in r), are ",
          StringRiffle[MapIndexed["r" <> ToString[#2[[1]]] <> " = " <> ToString[NumberForm[#1["r"], {9, 7}], OutputForm] <>
            " (period " <> ToString[#1["periodBorn"]] <> " born)" &, pts], ", "], "."];
    side[x_] := If[x > 0, " above ", " below "];
    MapIndexed[
      Print["    1", FromCharacterCode[97 + #2[[1]]], ". delta_", #2[[1]], " = (r", #2[[1]] + 1, " - r", #2[[1]],
            ") / (r", #2[[1]] + 2, " - r", #2[[1]] + 1, ") = ", ToString[NumberForm[#1, {6, 5}], OutputForm],
            ", which is ", FmtN[Abs[#1 - d], 3], side[#1 - d], dTxt, " (", FmtN[100 Abs[#1 - d] / d, 3], " percent)."] &,
      chk["deltas"]];
    Print["    1e. ", If[chk["pass"], "[PASS] ", "[FAIL] "], "The differences from the Feigenbaum constant ",
          If[chk["monotone"], "shrink at every step", "do not shrink at every step"], " (",
          StringRiffle[FmtN[Abs[#], 3] & /@ chk["diffs"], ", "], "), so the ratios ",
          If[chk["monotone"], "approach", "do not steadily approach"], " the constant, and delta_3 is ",
          FmtN[100 chk["relError"], 3], " percent from it, ", If[chk["relError"] < chk["tolerance"], "within", "outside"],
          " the tolerance of ", FmtDec[100 chk["tolerance"], 2], " percent. The constant itself is the limit of ",
          "these ratios; no finite ratio equals it."];
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


(* PrintSweepSummary
   One self-contained sentence per line: the range, then each marker
   with its r and the time it is heard. introSec is the time before the
   first note in the WAV. *)
PrintSweepSummary[sweepModel_Association, sweepResult_Association, introSec_?NumericQ] :=
  Module[{rValues = sweepModel["rValues"], what},
    what = <|"first_bifurcation" -> "the first period-doubling bifurcation, where one note becomes two",
             "chaos_onset" -> "the onset of chaos, beyond which long-term prediction is impossible",
             "period3_window" -> "the period-3 window, a brief return to order inside the chaos"|>;
    STEMSection["Sweep Summary"];
    Print["  The sweep covered r from ", FmtDec[First[rValues], 4], " to ", FmtDec[Last[rValues], 4],
          " in ", Length[rValues], " steps."];
    If[sweepResult["eventTimes"] === <||>,
      Print["  No sweep marker falls inside this r range."]];
    KeyValueMap[
      Print["  The ", FmtDec[sweepResult["eventFreqs"][#1]], " Hz marker for ", what[#1],
            ", sounds at r = ", FmtDec[sweepResult["eventRs"][#1], 4], ", ",
            FmtDec[introSec + #2, 2], " s into the audio."] &,
      sweepResult["eventTimes"]];
  ];


(* PrintIterateSummary
   One self-contained sentence per line, including the fixed point and
   its stability (FixedPointStability). *)
PrintIterateSummary[iterateModel_Association] :=
  Module[{traj, distinct, fp, r},
    traj = iterateModel["trajectory"];
    r    = iterateModel["r"];
    fp   = FixedPointStability[r];
    STEMSection["Iterate Summary"];
    Print["  Over ", iterateModel["nIterations"], " iterations at r = ", FmtDec[r, 4],
          " the population x ranged from ", FmtN[Min[traj], 4], " to ", FmtN[Max[traj], 4], "."];
    distinct = Length[DeleteDuplicates[Round[traj[[-40 ;;]], 0.001]]];
    Print["  The last 40 iterations at r = ", FmtDec[r, 4], " take ", distinct,
          If[distinct === 1, " distinct value", " distinct values"], " when rounded to 0.001."];
    Print["  At r = ", FmtDec[r, 4], " the fixed point x* = 1 - 1/r is ", FmtDec[fp["xStar"], 4],
          " and |f'(x*)| = |2 - r| = ", FmtDec[fp["slope"], 4], ", ",
          Which[fp["slope"] < 1, "below 1, so it attracts", fp["slope"] > 1, "above 1, so it repels",
                True, "exactly 1, so the first-order test is inconclusive"],
          If[fp["xStar"] < 0,
            "; x* is negative, and the fixed point x = 0 has |f'(0)| = r = " <> FmtDec[fp["zeroSlope"], 4] <>
              If[fp["zeroSlope"] < 1, ", below 1, so it attracts.", ", not below 1, so it does not attract."],
            "."]];
  ];


(* ── Narrated WAV (all modes) ──────────────────────────────────────── *)

$dynamicalSpeechPause = 0.4;   (* s of silence between speech and notes *)

(* ExportNarratedWAV
   Joins intro speech, a pause, the notes, a pause and outro speech,
   normalises to targetLUFS and writes the WAV. Speech buffers are padded
   with silence to introSlot / outroSlot samples when those are larger
   (divergence mode pads its presets to the same length); a missing
   speech buffer drops its pause too. Returns the timing of the parts in
   seconds: <|"introSpeech", "intro" (speech slot + pause, i.e. the time
   of the first note), "notes", "outro" (pause + speech slot),
   "outroSpeech", "total"|>. *)
ExportNarratedWAV[outWAV_String, introBuf_List, leftBuf_List, rightBuf_List, outroBuf_List,
                  sr_Integer, Optional[introSlot_Integer, 0], Optional[outroSlot_Integer, 0],
                  Optional[targetLUFS_?NumericQ, -17.0]] :=
  Module[{pause = ConstantArray[0.0, Round[sr * $dynamicalSpeechPause]], introPart, outroPart,
          left, right},
    introPart = If[Length[introBuf] > 0,
      Join[PadRight[introBuf, Max[introSlot, Length[introBuf]], 0.0], pause], {}];
    outroPart = If[Length[outroBuf] > 0,
      Join[pause, PadRight[outroBuf, Max[outroSlot, Length[outroBuf]], 0.0]], {}];
    left  = Join[introPart, leftBuf,  outroPart];
    right = Join[introPart, rightBuf, outroPart];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[NormalizeToLoudness[{left, right}, targetLUFS, 0.97, sr], sr]], "WAV"];
    <|"introSpeech" -> N[Length[introBuf]] / sr, "intro" -> N[Length[introPart]] / sr,
      "notes" -> N[Length[leftBuf]] / sr, "outro" -> N[Length[outroPart]] / sr,
      "outroSpeech" -> N[Length[outroBuf]] / sr, "total" -> N[Length[left]] / sr|>
  ];

(* PrintTimingLine — where the parts of the WAV lie, one sentence. *)
PrintTimingLine[t_Association] :=
  Module[{p = $dynamicalSpeechPause, introSlot, outroSlot, padded},
    introSlot = If[t["intro"] > 0, t["intro"] - p, 0.0];
    outroSlot = If[t["outro"] > 0, t["outro"] - p, 0.0];
    padded[slot_, speech_] := If[slot > speech + 10^-9, " padded to " <> FmtDec[slot, 2] <> " s", ""];
    Print["  Timing: the WAV holds ", FmtDec[t["introSpeech"], 2], " s of spoken intro",
          padded[introSlot, t["introSpeech"]], " and a ", FmtDec[p, 1], " s pause, then ",
          FmtDec[t["notes"], 2], " s of notes from ", FmtDec[t["intro"], 2], " s, then a ",
          FmtDec[p, 1], " s pause and ", FmtDec[t["outroSpeech"], 2], " s of spoken outro",
          padded[outroSlot, t["outroSpeech"]], ", ", FmtDec[t["total"], 2], " s in total."]
  ];

(* PrintNarration — the spoken text, the TTS cache counts, and a warning
   for any sentence that breaks the capital-letter / full-stop rule. *)
PrintNarration[introText_String, outroText_String] :=
  Module[{issues = Join[NarrationConventionIssues[introText], NarrationConventionIssues[outroText]]},
    Print["  Spoken intro: ", introText];
    Print["  Spoken outro: ", outroText];
    Print["  Speech synthesis: ", $dynamicalSpeechRequests, " sentences requested so far in this run, ",
          $dynamicalSpeechCalls, " synthesised and ", $dynamicalSpeechRequests - $dynamicalSpeechCalls,
          " taken from the cache."];
    Scan[Print["  [WARNING] This narration sentence does not start with a capital letter ",
               "and end with a full stop: \"", #, "\""] &, issues];
  ];


(* ── Lyapunov mode ─────────────────────────────────────────────────── *)

(* ExportLyapunovCSV
   Columns: r, lambda, at_floor, sweep_time_s, audio_time_s, lambda_tone_hz,
   crossing, crossing_r, bifurcation_period_born, bifurcation_r. A zero
   crossing (LyapunovZeroCrossings) lies between two steps; it is recorded
   on the row of the step before it: crossing is "upward" or "downward"
   and crossing_r its interpolated r. The period-doubling points r1 .. r5
   (check 1's bisection) are recorded the same way: the period born and r
   (9 decimals), several joined by ";" if they share a step. Empty on
   other rows. *)
ExportLyapunovCSV[sweep_List, floor_?NumericQ, durSec_?NumericQ, introSec_?NumericQ,
                  refHz_?NumericQ, octavesPerUnit_?NumericQ, crossings_List, outCSV_String,
                  Optional[doublings_List, {}]] :=
  Module[{rMin = sweep[[1, 1]], rMax = sweep[[-1, 1]], rs = sweep[[All, 1]], byIndex, bifByIndex, rows},
    byIndex = Association[#["index"] -> # & /@ crossings];
    (* each in-range period-doubling point on the row of the step before it *)
    bifByIndex = GroupBy[Select[doublings, rMin <= #["r"] < rMax &],
      Function[d, Max[1, Length[Select[rs, # <= d["r"] &]]]]];
    rows = MapIndexed[
      Function[{row, idx},
        With[{t = LyapunovTimeOfR[row[[1]], rMin, rMax, durSec], c = Lookup[byIndex, idx[[1]], None],
              bs = Lookup[bifByIndex, idx[[1]], {}]},
          {row[[1]], row[[2]], If[row[[2]] <= floor, 1, 0], t, introSec + t,
           LyapunovToneHz[row[[2]], refHz, octavesPerUnit],
           If[c === None, "", c["direction"]], If[c === None, "", c["r"]],
           StringRiffle[ToString /@ bs[[All, "periodBorn"]], ";"],
           StringRiffle[ToString[NumberForm[#, {10, 9}], OutputForm] & /@ bs[[All, "r"]], ";"]}]],
      sweep];
    ExportCSV[Join[{{"r", "lambda", "at_floor", "sweep_time_s", "audio_time_s", "lambda_tone_hz",
                     "crossing", "crossing_r", "bifurcation_period_born", "bifurcation_r"}}, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], 10]
  ];

(* PrintLyapunovSummary
   One sentence per line: the first upward zero crossing as the onset of
   chaos, then each window of order (LyapunovWindows: a downward crossing
   followed by an upward one) with its r values, its width in r and in
   audio seconds and its period, any downward crossing left without an
   upward one, the minimum and maximum lambda, and the number of steps at
   the floor. introSec is the time before the sweep starts in the WAV.
   Every crossing is also in the CSV (crossing, crossing_r). *)
PrintLyapunovSummary[sweep_List, crossings_List, windows_List, floor_?NumericQ,
                     durSec_?NumericQ, introSec_?NumericQ] :=
  Module[{rs = sweep[[All, 1]], lams = sweep[[All, 2]], rMin, rMax, tOf, r3,
          firstUp, lastC, iMin, iMax, nFloor},
    rMin = First[rs]; rMax = Last[rs];
    tOf[r_] := introSec + LyapunovTimeOfR[r, rMin, rMax, durSec];
    r3[r_] := ToString[NumberForm[r, {5, 3}], OutputForm];
    STEMSection["Lyapunov Summary"];
    firstUp = SelectFirst[crossings, #["direction"] === "upward" &, None];
    If[firstUp === None,
      Print["  The Lyapunov exponent never rises above zero between r = ", FmtDec[rMin, 3],
            " and r = ", FmtDec[rMax, 3], ", so this range has no onset of chaos."],
      Print["  The onset of chaos: the Lyapunov exponent first crosses zero upward at r = ",
            r3[firstUp["r"]], ", heard ", FmtDec[tOf[firstUp["r"]], 2], " s into the audio."]];
    If[windows === {},
      Print["  There is no window of order (a downward zero crossing followed by an upward one) ",
            "between r = ", FmtDec[rMin, 3], " and r = ", FmtDec[rMax, 3], "."]];
    Scan[
      Function[w, Print["  ",
        If[w["steps"] === 1,
          "A window of order at r = " <> r3[rs[[w["downIndex"] + 1]]] <>
            " spans a single r step of the sweep: the exponent is below zero only at that step" <>
            ", so its width is less than the grid spacing of " <> FmtDec[(rMax - rMin) / (Length[rs] - 1), 4] <>
            " in r and " <> FmtDec[durSec / (Length[rs] - 1), 2] <> " s in the audio; it is heard from " <>
            FmtDec[tOf[w["rStart"]], 2] <> " s, ",
          "A window of order runs from r = " <> r3[w["rStart"]] <> " to r = " <> r3[w["rEnd"]] <>
            ", " <> FmtDec[w["width"], 4] <> " wide in r and " <>
            FmtDec[w["width"] / (rMax - rMin) * durSec, 2] <> " s long in the audio from " <>
            FmtDec[tOf[w["rStart"]], 2] <> " s, "] <>
        If[IntegerQ[w["period"]],
          "and it is the period-" <> ToString[w["period"]] <> " window.",
          "and its period was not identified."]]],
      windows];
    lastC = If[crossings === {}, None, Last[crossings]];
    If[AssociationQ[lastC] && lastC["direction"] === "downward",
      Print["  The Lyapunov exponent crosses zero downward at r = ", r3[lastC["r"]],
            ", heard ", FmtDec[tOf[lastC["r"]], 2], " s into the audio, and is still below zero at r = ",
            FmtDec[rMax, 3], ", the end of the range."]];
    iMin = First[Ordering[lams, 1]];
    iMax = First[Ordering[lams, -1]];
    nFloor = Count[lams, l_ /; l <= floor];
    Print["  The minimum Lyapunov exponent is ", FmtDec[lams[[iMin]], 3],
          If[lams[[iMin]] <= floor, " (the floor), first reached", ", reached"],
          " at r = ", r3[rs[[iMin]]], "."];
    Print["  The maximum Lyapunov exponent is ", FmtDec[lams[[iMax]], 3],
          ", reached at r = ", r3[rs[[iMax]]], "."];
    Print["  ", nFloor, " of ", Length[lams], " r steps sit at the Lyapunov floor of ",
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
          ", and their ratio is ", FmtDec[fit["slope"] / lambda, 4], "."];
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

#!/usr/bin/env wolframscript

(* dynamical/tests/test_model.wl — Unit tests for the logistic map model *)

$projectRoot  = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "speech.wl"}]];

passed = 0; failed = 0;
AssertTrue[label_String, condition_] :=
  If[TrueQ[condition],
    Print["  PASS  ", label]; passed++,
    Print["  FAIL  ", label]; failed++
  ];

Print["=== dynamical/src/model.wl unit tests ==="];
Print[""];

(* ── LogisticMap basics ──────────────────────────────────────────── *)
Print["-- LogisticMap --"];
AssertTrue["F[0.5, 4] = 1.0", Abs[LogisticMap[0.5, 4.0] - 1.0] < 10^-9];
AssertTrue["F[0, r] = 0 for any r",  LogisticMap[0.0, 3.5] === 0.0];
AssertTrue["F[1, r] = 0 for any r",  LogisticMap[1.0, 3.5] === 0.0];
Print[""];

(* ── SafeX0 ───────────────────────────────────────────────────────── *)
Print["-- SafeX0 --"];
AssertTrue["SafeX0 nudges exact 0.5", SafeX0[0.5] =!= 0.5];
AssertTrue["SafeX0 nudge is small (<1e-4)", Abs[SafeX0[0.5] - 0.5] < 10^-4];
AssertTrue["SafeX0 leaves other values unchanged", SafeX0[0.3] === 0.3];
Print[""];

(* ── Fixed-point formula (r = 2.8) ───────────────────────────────────
   Required: verify 1 - 1/r matches the iterated value to within 1e-6. *)
Print["-- Fixed-point formula (r=2.8) --"];
Module[{r = 2.8, attractor, xstar, err},
  attractor = AttractorPoints[0.5, r, 200, 50];
  xstar     = 1.0 - 1.0/r;
  err       = Max[Abs[attractor - xstar]];
  AssertTrue["all attractor points within 1e-6 of 1 - 1/r", err < 10^-6];
  AssertTrue["FixedPointCheck[] agrees", FixedPointCheck[2.8]["pass"]];
];
Print[""];

(* ── Period-2 values (r = 3.2) ───────────────────────────────────────
   Required: the two attractor values sum to (r+1)/r. *)
Print["-- Period-2 values (r=3.2) --"];
Module[{r = 3.2, attractor, distinct, sum, expected},
  attractor = AttractorPoints[0.5, r, 200, 100];
  distinct  = DeleteDuplicates[Round[attractor, 10^-4]];
  AssertTrue["exactly 2 distinct attractor values", Length[distinct] === 2];
  sum      = Total[distinct];
  expected = (r + 1.0) / r;
  AssertTrue["the two values sum to (r+1)/r = " <> ToString[expected],
    Abs[sum - expected] < 10^-3];
  AssertTrue["Period2Check[] agrees", Period2Check[3.2]["pass"]];
];
Print[""];

(* ── Feigenbaum check ─────────────────────────────────────────────── *)
Print["-- Feigenbaum constant check --"];
Module[{fc},
  fc = FeigenbaumCheck[];
  Print["  r1 = ", FmtN[fc["r1"], 6], "   r2 = ", FmtN[fc["r2"], 6],
        "   r3 = ", FmtN[fc["r3"], 6]];
  Print["  ratio = ", FmtN[fc["ratio"], 6], "   delta = ", FmtN[$FeigenbaumConstant, 6],
        "   error = ", FmtN[fc["relError"] * 100, 4], "%"];
  AssertTrue["r1 is close to the known value 3.0", Abs[fc["r1"] - 3.0] < 0.01];
  AssertTrue["r2 is close to the known value 3.449", Abs[fc["r2"] - 3.449] < 0.01];
  AssertTrue["r3 is close to the known value 3.544", Abs[fc["r3"] - 3.544] < 0.01];
  AssertTrue["ratio within 5% of the Feigenbaum constant", fc["pass"]];
];
Print[""];

(* ── Lyapunov exponent (r = 4.0) ─────────────────────────────────────
   Required: within 5% of log(2). *)
Print["-- Lyapunov exponent (r=4.0) --"];
Module[{lc},
  lc = LyapunovCheck[];
  Print["  lambda = ", FmtN[lc["lambda"], 6], "   log(2) = ", FmtN[lc["expected"], 6],
        "   error = ", FmtN[lc["relError"] * 100, 4], "%"];
  AssertTrue["lambda is positive (signature of chaos)", lc["lambda"] > 0];
  AssertTrue["lambda within 5% of log(2)", lc["pass"]];
];
Print[""];

(* ── Presets ──────────────────────────────────────────────────────── *)
Print["-- Presets --"];
AssertTrue["fixed_point preset resolves to r=2.8", PresetR["fixed_point", 999] === 2.8];
AssertTrue["period2 preset resolves to r=3.2",     PresetR["period2", 999] === 3.2];
AssertTrue["period4 preset resolves to r=3.5",      PresetR["period4", 999] === 3.5];
AssertTrue["chaos preset resolves to r=4.0",        PresetR["chaos", 999] === 4.0];
AssertTrue["unknown preset falls back to default",  PresetR["nonexistent", 3.14] === 3.14];
AssertTrue["empty preset falls back to default",    PresetR["", 3.14] === 3.14];
AssertTrue["preset description is non-empty for known preset",
  StringLength[PresetDescription["chaos"]] > 0];
AssertTrue["preset description is empty for unknown preset",
  PresetDescription["nonexistent"] === ""];
AssertTrue["extinction preset resolves to r=0.8", PresetR["extinction", 999] === 0.8];
AssertTrue["growth preset resolves to r=2.0, starting from x0=0.1",
  PresetR["growth", 999] === 2.0 && PresetX0["growth", 0.5] === 0.1];
AssertTrue["presets without their own x0 use the configured x0", PresetX0["period2", 0.37] === 0.37];
AssertTrue["extinction: the population dies out (x_300 < 1e-20)",
  Last[IterateTrajectory[0.5, 0.8, 300]] < 10^-20];
AssertTrue["growth: the population settles at 1 - 1/r = 0.5 (last 40 within 1e-9)",
  Max[Abs[IterateTrajectory[0.1, 2.0, 300][[-40 ;;]] - 0.5]] < 10^-9];
Print[""];

(* ── Fixed-point stability, |f'(x_star)| = |2 - r| ──────────────────── *)
Print["-- FixedPointStability --"];
Module[{fp},
  fp = FixedPointStability[2.8];
  AssertTrue["r = 2.8: x* = 0.642857, |2 - r| = 0.8, attracts",
    Abs[fp["xStar"] - 0.642857] < 10^-6 && Abs[fp["slope"] - 0.8] < 10^-12 && fp["verdict"] === "attracts"];
  AssertTrue["|2 - r| equals |f'(x*)| = |r (1 - 2 x*)| at r = 3.83",
    With[{f = FixedPointStability[3.83]}, Abs[f["slope"] - Abs[3.83 (1 - 2 f["xStar"])]] < 10^-12]];
  AssertTrue["r = 3.2 and r = 4: the fixed point repels",
    FixedPointStability[3.2]["verdict"] === "repels" && FixedPointStability[4.0]["verdict"] === "repels"];
  AssertTrue["r = 2: slope 0, attracts (superstable)",
    FixedPointStability[2.0]["slope"] == 0 && FixedPointStability[2.0]["verdict"] === "attracts"];
  fp = FixedPointStability[0.8];
  AssertTrue["r = 0.8: x* = -0.25 repels (|2 - r| = 1.2), zero attracts (|f'(0)| = 0.8)",
    Abs[fp["xStar"] + 0.25] < 10^-12 && fp["verdict"] === "repels" && fp["zeroVerdict"] === "attracts"];
];
Print[""];

(* ── SweepModel / IterateModelData shape ─────────────────────────── *)
Print["-- SweepModel --"];
Module[{sm},
  sm = SweepModel[2.5, 4.0, 20, 0.5, 50, 10];
  AssertTrue["rValues has 20 entries", Length[sm["rValues"]] === 20];
  AssertTrue["attractors has 20 entries", Length[sm["attractors"]] === 20];
  AssertTrue["each attractor has 10 points", Length[sm["attractors"][[1]]] === 10];
  AssertTrue["rValues starts at r_start", sm["rValues"][[1]] === 2.5];
  AssertTrue["rValues ends at r_end", Last[sm["rValues"]] === 4.0];
];
Print[""];

Print["-- IterateModelData --"];
Module[{im},
  im = IterateModelData[3.5, 0.5, 50, "period4"];
  AssertTrue["trajectory has 51 entries (x0 plus 50 iterations)",
    Length[im["trajectory"]] === 51];
  AssertTrue["r is stored correctly", im["r"] === 3.5];
  AssertTrue["preset is stored correctly", im["preset"] === "period4"];
];
Print[""];

(* ── SweepEventRValues ─────────────────────────────────────────────── *)
Print["-- SweepEventRValues --"];
Module[{ev},
  ev = SweepEventRValues[];
  AssertTrue["first_bifurcation close to 3.0", Abs[ev["first_bifurcation"] - 3.0] < 0.01];
  AssertTrue["chaos_onset in (3.5, 3.6)", 3.5 < ev["chaos_onset"] < 3.6];
  AssertTrue["period3_window in (3.8, 3.85)", 3.8 < ev["period3_window"] < 3.85];
];
Print[""];

(* ── Lyapunov mode: LyapunovExponent / LyapunovSweep ─────────────────── *)
Print["-- LyapunovExponent (lyapunov mode) --"];
AssertTrue["lambda(2.8) equals Log[0.8] within 0.01", Abs[LyapunovExponent[2.8] - Log[0.8]] < 0.01];
AssertTrue["lambda(4.0) equals Log[2] within 0.01",   Abs[LyapunovExponent[4.0] - Log[2.0]] < 0.01];
AssertTrue["the default floor of -0.5 clips lambda(3.2) (true value -0.916)",
  LyapunovExponent[3.2] === -0.5];
AssertTrue["with a low floor lambda(3.2) equals the closed-form period-2 value within 0.01",
  Abs[LyapunovExponent[3.2, 0.5, 1000, 10000, -100.0] - Period2LyapunovExact[3.2]] < 0.01];
AssertTrue["Period2LyapunovExact[3.2] = 0.5 Log[0.16] (f'(x1) f'(x2) = 4 + 2r - r^2)",
  Abs[Period2LyapunovExact[3.2] - 0.5 Log[0.16]] < 10^-12];
AssertTrue["lambda(3.835), in the period-3 window, is negative without a floor",
  LyapunovExponent[3.835, 0.5, 1000, 10000, -100.0] < 0];
AssertTrue["LyapunovCurveCheck[] (check 5) passes", LyapunovCurveCheck[]["pass"]];
Module[{sw = LyapunovSweep[3.4, 3.9, 11, 0.5, 200, 1000, -0.5]},
  AssertTrue["LyapunovSweep returns steps {r, lambda} pairs", Dimensions[sw] === {11, 2}];
  AssertTrue["LyapunovSweep spans r_min to r_max", sw[[1, 1]] === 3.4 && sw[[-1, 1]] === 3.9];
  AssertTrue["no lambda in the sweep is below the floor", Min[sw[[All, 2]]] >= -0.5];
];
Module[{cr = LyapunovZeroCrossings[{{1.0, -1.0}, {2.0, 1.0}, {3.0, 3.0}, {4.0, -1.0}}]},
  AssertTrue["LyapunovZeroCrossings finds one upward and one downward crossing",
    cr[[All, "direction"]] === {"upward", "downward"}];
  AssertTrue["crossings are placed by linear interpolation (r = 1.5 and 3.75)",
    Abs[cr[[1, "r"]] - 1.5] < 10^-12 && Abs[cr[[2, "r"]] - 3.75] < 10^-12];
];
Module[{cr, w},
  cr = {<|"r" -> 3.57, "direction" -> "upward"|>, <|"r" -> 3.628, "direction" -> "downward"|>,
        <|"r" -> 3.634, "direction" -> "upward"|>, <|"r" -> 3.70, "direction" -> "downward"|>,
        <|"r" -> 3.701, "direction" -> "upward"|>, <|"r" -> 3.83, "direction" -> "downward"|>};
  w = LyapunovWindows[cr];
  AssertTrue["LyapunovWindows pairs each downward crossing with the next upward one (2 windows)",
    Length[w] === 2 && Abs[w[[1, "width"]] - 0.006] < 10^-12];
  AssertTrue["a window within 0.005 of a known start gets its period (3.628 -> 6)", w[[1, "period"]] === 6];
  AssertTrue["a window far from every known start has no period (3.70)", MissingQ[w[[2, "period"]]]];
];
AssertTrue["PeriodDoublingRs gives 3, 3.449 and 3.544",
  Max[Abs[PeriodDoublingRs[] - {3.0, 3.44949, 3.54409}]] < 10^-4];
AssertTrue["lyapunov_window preset: r 3.40 to 3.90, 500 steps, 40 s",
  Lookup[$lyapunovPresets["lyapunov_window"], {"r_min", "r_max", "steps", "duration_seconds"}] ===
    {3.40, 3.90, 500, 40.0}];
Print[""];

(* ── Lyapunov mode: sonification invariants ───────────────────────────── *)
Print["-- Lyapunov sonification --"];
(* False-unison guard. The lambda tone's harmonic k sits at
   k * reference * 2^(lambda * octaves_per_unit); if lambda could fall to
   -log2(k) / octaves_per_unit, that harmonic would meet the reference and
   the listener would hear beating as if lambda were crossing zero. The
   floor is what prevents this, so the test reads floor and
   octaves_per_unit from config.json: a config change that reintroduces
   the false unison fails here. It demands at least a semitone of
   clearance, enough that no slow beating can arise. *)
Module[{cfgJSON, ly, clearance},
  cfgJSON = Import[FileNameJoin[{$projectRoot, "config.json"}], "RawJSON"];
  ly = cfgJSON["simulation"]["dynamical"]["lyapunov"];
  clearance = LyapunovHarmonicClearance[N[ly["floor"]], N[ly["octaves_per_unit"]]];
  Print["  config floor ", ly["floor"], ", octaves_per_unit ", ly["octaves_per_unit"],
        ": harmonic clearance above the reference ", clearance, " semitones"];
  AssertTrue["octaves_per_unit is positive", ly["octaves_per_unit"] > 0];
  AssertTrue["no harmonic of the lambda tone reaches the reference (>= 1 semitone clear)",
    Min[Values[clearance]] >= 1.0];
  AssertTrue["the clearance check does flag a floor of -1 (2nd harmonic in unison)",
    Min[Values[LyapunovHarmonicClearance[-1.0, 1.0]]] < 1.0];
];
AssertTrue["loudness gain is 1 at the reference frequency",
  Abs[LyapunovLoudnessGain[220.0, 220.0] - 1.0] < 10^-12];
AssertTrue["loudness gain rises below the reference and falls above it",
  LyapunovLoudnessGain[155.0, 220.0] > 1 && LyapunovLoudnessGain[350.0, 220.0] < 1];
AssertTrue["A-weighting is about -8.6 dB at 250 Hz relative to 1 kHz",
  Abs[20 Log10[AWeightingResponse[250.0] / AWeightingResponse[1000.0]] + 8.6] < 0.1];
Module[{mk = LyapunovMarkers[]},
  AssertTrue["four markers in ascending r", Length[mk] === 4 && OrderedQ[mk[[All, "r"]]]];
  AssertTrue["period-4 marker at r = 3.449, 880 Hz",
    SelectFirst[mk, #["key"] === "period4" &][[{"r", "freq"}]] === <|"r" -> 3.449, "freq" -> 880.0|>];
];
Module[{res = SonifyLyapunov[{{3.4, -0.2}, {3.6, 0.1}, {3.8, 0.4}}, 1.0, 220.0, 1.0, 8000]},
  AssertTrue["SonifyLyapunov returns duration * sr samples per channel",
    Length[res["leftBuf"]] === 8000 && Length[res["rightBuf"]] === 8000];
  AssertTrue["markers inside the range only (chaos onset at 3.5699)",
    res["markers"][[All, "key"]] === {"period4", "chaos_onset"}];
  AssertTrue["no click at the first or last sample (edge fade)",
    Abs[res["leftBuf"][[1]]] < 10^-9 && Abs[res["leftBuf"][[-1]]] < 0.01];
];
Print[""];

(* ── Divergence mode ──────────────────────────────────────────────── *)
Print["-- Divergence mode --"];
Module[{orb = DivergenceOrbits[4.0, 0.3, 10^-6, 150]},
  AssertTrue["DivergenceOrbits returns n + 1 values per orbit",
    Length[orb["x"]] === 151 && Length[orb["y"]] === 151 && Length[orb["separation"]] === 151];
  AssertTrue["the orbits start exactly delta apart (no SafeX0 nudge)",
    Abs[orb["separation"][[1]] - 10^-6] < 10^-15];
];
Module[{sep = 10^-6 * Exp[0.5 * Range[0, 40]], fit},
  fit = DivergenceFit[N[sep], 0.1];
  AssertTrue["DivergenceFit recovers slope 0.5 from exact exponential growth", Abs[fit["slope"] - 0.5] < 10^-9];
  AssertTrue["DivergenceFit reports the first n above saturation (24)", fit["nSat"] === 24 && fit["nEnd"] === 24];
];
Module[{sep = Join[N[10^-6 * 0.5^Range[0, 30]], ConstantArray[0., 10]], fit},
  fit = DivergenceFit[sep, 0.1];
  AssertTrue["without saturation the fit stops before the 1e-12 floor (n = 19)",
    !fit["saturated"] && fit["nEnd"] === 19 && Abs[fit["slope"] - Log[0.5]] < 10^-9];
];
AssertTrue["predicted saturation Log[0.1/1e-6]/Log[2] = 16.61",
  Abs[DivergencePredictedSaturation[Log[2.], 10^-6, 0.1] - 16.6096] < 10^-3];
AssertTrue["no predicted saturation for negative lambda",
  MissingQ[DivergencePredictedSaturation[-0.2, 10^-6, 0.1]]];
AssertTrue["DivergenceCheck[] (check 6) passes", DivergenceCheck[]["pass"]];
AssertTrue["the classifier agrees with the four presets' cases",
  AllTrue[Values[$divergencePresets],
    DivergenceCase[#["r"], LyapunovExponent[#["r"], 0.3, 1000, 10000, -100.0]] === #["case"] &]];
AssertTrue["presets set only r, the case and optionally x0, so all four play the same number of notes",
  AllTrue[Values[$divergencePresets], SubsetQ[{"case", "r", "x0"}, Keys[#]] &]];
AssertTrue["divergence_periodic starts on the 2-cycle: x0 = 0.513 within 1e-4 of ((r+1) - Sqrt[(r+1)(r-3)])/2r",
  Abs[$divergencePresets["divergence_periodic"]["x0"] - (4.2 - Sqrt[4.2 * 0.2]) / 6.4] < 10^-4];
Module[{orb = DivergenceOrbits[3.2, 0.513, 10^-6, 120], fit, lam},
  fit = DivergenceFit[orb["separation"], 0.1];
  lam = LyapunovExponent[3.2, 0.513, 1000, 10000, -100.0];
  AssertTrue["from the 2-cycle the fitted slope matches lambda within 1 percent (was 0.44 of it from 0.3)",
    Abs[fit["slope"] / lam - 1] < 0.01];
];
AssertTrue["the saturation marker (1320 Hz) is not used by any other marker",
  !MemberQ[Join[LyapunovMarkers[][[All, "freq"]], {660.0, 440.0, 528.0}], $divergenceSaturationMarker["freq"]]];
AssertTrue["the saturation marker is in the family: 1320 / 440 = 3",
  $divergenceSaturationMarker["freq"] / 440.0 == 3];
AssertTrue["separation pitch: delta -> 220 Hz, 1 -> 880 Hz, 0 -> 55 Hz (floor 1e-12)",
  Max[Abs[DivergenceSeparationHz[{10^-6, 1.0, 0.0}, 10^-6] - {220., 880., 55.}]] < 10^-9];
Module[{m},
  m = DivergenceNoteMapping[{0.2, 0.5, 0.8}, {0.2, 0.5, 0.8}];
  AssertTrue["identical orbits get identical notes", MissingQ[m["firstDifferentNote"]]];
  AssertTrue["pitch resolution is one scale degree, 1/15 of the x range", Abs[m["pitchBin"] - 1/15] < 10^-12];
];
Module[{orb = DivergenceOrbits[2.8, 0.3, 10^-6, 40], res},
  res = SonifyDivergence[orb, 0.05, 0.1, True, 8000];
  AssertTrue["converging orbits (r = 2.8) give sample-identical left and right buffers",
    res["leftBuf"] === res["rightBuf"]];
  AssertTrue["no saturation marker when the separation never exceeds saturation",
    MissingQ[res["markerTime"]]];
];
Module[{orb = DivergenceOrbits[4.0, 0.3, 10^-6, 40], res},
  res = SonifyDivergence[orb, 0.05, 0.1, False, 8000];
  AssertTrue["saturation marker at nSat * note_duration (18 * 0.05 s)", Abs[res["markerTime"] - 0.9] < 10^-12];
  AssertTrue["buffers last (n + 1) * note_duration", Length[res["leftBuf"]] === Round[41 * 0.05 * 8000] + 1];
];
Print[""];

(* ── Narration conventions (text only, no speech synthesis) ─────────── *)
Print["-- Narration --"];
AssertTrue["NarrationSentences splits at sentence ends, not inside 3.449",
  NarrationSentences["At r equals 3.449 it doubles. Then 3.544."] === {"At r equals 3.449 it doubles.", "Then 3.544."}];
AssertTrue["NarrationConventionIssues flags a lower-case start and a missing full stop",
  NarrationConventionIssues["Fine. a fragment. Also fine. No stop"] === {"a fragment.", "No stop"}];
Module[{texts, divTexts, windows},
  windows = {<|"rStart" -> 3.628, "rEnd" -> 3.634, "width" -> 0.006, "period" -> 6|>,
             <|"rStart" -> 3.7, "rEnd" -> 3.701, "width" -> 0.001, "period" -> Missing[]|>};
  divTexts = Flatten @ KeyValueMap[
    With[{d = DivergenceNarration[#2["r"], #2["case"], Lookup[#2, "x0", 0.3], 10^-6, 120, 0.1]},
      {d["intro"], d["outro"]}] &, $divergencePresets];
  texts = Join[
    {BuildSweepIntroText[2.5, 4.0], BuildSweepOutroText[2.5, 4.0]},
    Flatten[{BuildIterateIntroText[PresetR[#, 3.8], PresetDescription[#], 300, PresetX0[#, 0.5]],
             BuildIterateOutroText[PresetR[#, 3.8]]} & /@ Prepend[Keys[$dynamicalPresets], ""]],
    {BuildLyapunovIntroText[2.5, 4.0, PeriodDoublingRs[]], BuildLyapunovIntroText[3.4, 3.9, PeriodDoublingRs[]],
     BuildLyapunovOutroText[2.5, 4.0, 3.57, windows], BuildLyapunovOutroText[2.5, 4.0, Missing[], {}]},
    divTexts];
  AssertTrue["every narration sentence of every mode and preset starts with a capital and ends with a full stop (" <>
      ToString[Length[texts]] <> " texts)",
    AllTrue[texts, NarrationConventionIssues[#] === {} &]];
  AssertTrue["sweep, iterate, lyapunov and divergence outros are spoken end markers (start with or contain \"End of the\")",
    AllTrue[{BuildSweepOutroText[2.5, 4.0], BuildIterateOutroText[2.8], BuildLyapunovOutroText[2.5, 4.0, 3.57, windows]},
      StringContainsQ[#, "End of the"] &] && AllTrue[divTexts[[2 ;; ;; 2]], StringStartsQ[#, "End of the"] &]];
  AssertTrue["the iterate outro states the fixed point and the attract/repel verdict, computed (r = 2.8 and 3.2)",
    StringContainsQ[BuildIterateOutroText[2.8], "0.643" ~~ __ ~~ "0.80, below one" ~~ __ ~~ "attracts"] &&
    StringContainsQ[BuildIterateOutroText[3.2], "0.688" ~~ __ ~~ "1.20, above one" ~~ __ ~~ "repels"]];
  AssertTrue["the lyapunov intro names only the doublings inside the range (3.40 to 3.90: 3.449 and 3.544)",
    StringContainsQ[BuildLyapunovIntroText[3.4, 3.9, PeriodDoublingRs[]], "at r equals 3.449 and 3.544,"]];
  AssertTrue["the lyapunov outro names windows with their period, or says it was not identified",
    StringContainsQ[BuildLyapunovOutroText[2.5, 4.0, 3.57, windows], "3.628 to 3.634, period 6"] &&
    StringContainsQ[BuildLyapunovOutroText[2.5, 4.0, 3.57, windows], "period not identified"]];
];
Print[""];

Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

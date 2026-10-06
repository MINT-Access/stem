(* ========================================================
   dynamical/src/speech.wl — Spoken orientation guidance

   Same three-tier fallback pattern established in
   images/src/speech.wl (SpeechSynthesize[] -> platform-native
   TTS -> text-only STEMSay fallback), adapted for this app's
   sweep/iterate intro text. Duplicated rather than shared
   because apps do not import each other's src/ files — only
   stem-core is shared. See images/AGENTS.md's TODO note: once
   a second and now third app needs this, it is a good
   candidate for stem-core consolidation in a future pass.

   Narration conventions (all modes): every sentence starts with a
   capital letter and ends with a full stop (NarrationConventionIssues
   checks this; tests run it over every mode and preset), and every
   mode has a spoken intro and a spoken outro, the outro being the
   audible end marker.
   ======================================================== *)


(* ResampleLinear — general linear-interpolation resampler, any ratio. *)
ResampleLinear[data_List, rawSr_?NumericQ, targetSr_?NumericQ] :=
  Module[{n = Length[data], newN, ratio, oldPos, lo, frac},
    If[n < 2 || Abs[N[rawSr] - N[targetSr]] < 1.0, Return[data]];
    ratio = N[targetSr] / N[rawSr];
    newN  = Max[1, Round[n * ratio]];
    Table[
      oldPos = (i - 1) * (n - 1.0) / Max[newN - 1, 1];
      lo     = Clip[Floor[oldPos], {0, n - 2}];
      frac   = oldPos - lo;
      (1 - frac) * data[[lo + 1]] + frac * data[[lo + 2]],
      {i, newN}
    ]
  ];


(* DynamicalSpeakToBufferPlatform — OS-native TTS -> mono PCM at targetSr. *)
DynamicalSpeakToBufferPlatform[text_String, targetSr_Integer] :=
  Module[{id, wavPath, snd, data, rawSr},
    id      = ToString[RandomInteger[999999]];
    wavPath = FileNameJoin[{$TemporaryDirectory, "stem_dynamical_say_" <> id <> ".wav"}];

    Switch[$OperatingSystem,

      "MacOSX",
        Module[{aiffPath, result, conv},
          aiffPath = FileNameJoin[{$TemporaryDirectory, "stem_dynamical_say_" <> id <> ".aiff"}];
          result = Quiet[RunProcess[{"say", "-o", aiffPath, text}]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[aiffPath],
            Quiet[DeleteFile /@ Select[{aiffPath, wavPath}, FileExistsQ]];
            Return[{}]];
          conv = Quiet[RunProcess[{"afconvert", aiffPath, wavPath, "-d", "LEI16", "-f", "WAVE"}]];
          Quiet[DeleteFile[aiffPath]];
          If[!AssociationQ[conv] || conv["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            Quiet[DeleteFile /@ Select[{wavPath}, FileExistsQ]];
            Return[{}]]],

      "Unix",
        Module[{result},
          result = Quiet[RunProcess[{"espeak-ng", "-w", wavPath, text}]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            result = Quiet[RunProcess[{"espeak", "-w", wavPath, text}]]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            Quiet[DeleteFile /@ Select[{wavPath}, FileExistsQ]];
            Return[{}]]],

      "Windows",
        Module[{psCmd, result},
          psCmd = "Add-Type -AssemblyName System.Speech; " <>
                  "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; " <>
                  "$s.SetOutputToWaveFile('" <>
                  StringReplace[wavPath, "\\" -> "/"] <> "'); " <>
                  "$s.Speak('" <> StringReplace[text, "'" -> "''"] <> "'); " <>
                  "$s.SetOutputToDefaultAudioDevice()";
          result = Quiet[RunProcess[{"powershell", "-NoProfile", "-Command", psCmd}]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            Quiet[DeleteFile /@ Select[{wavPath}, FileExistsQ]];
            Return[{}]]],

      _,
        Return[{}]
    ];

    snd = Quiet[Import[wavPath]];
    If[!AudioQ[snd], Quiet[DeleteFile[wavPath]]; Return[{}]];
    data  = Quiet[Flatten[N[AudioData[snd]]]];
    rawSr = Quiet[QuantityMagnitude[AudioSampleRate[snd]]];
    Quiet[DeleteFile[wavPath]];
    If[!ListQ[data] || Length[data] === 0 || !NumericQ[rawSr], Return[{}]];

    ResampleLinear[data, rawSr, targetSr]
  ];


(* BuildIntroBuffer — SpeechSynthesize[] -> platform TTS -> text-only. *)
BuildIntroBuffer[text_String, sr_Integer] :=
  Module[{buf, result, data, rawSr},

    buf = Quiet[Check[
      result = SpeechSynthesize[text];
      If[AudioQ[result],
        data  = Quiet[Flatten[N[AudioData[result]]]];
        rawSr = Quiet[QuantityMagnitude[AudioSampleRate[result]]];
        If[ListQ[data] && Length[data] > 0 && NumericQ[rawSr],
          ResampleLinear[data, rawSr, sr],
          {}
        ],
        {}
      ],
      {}
    ]];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    buf = DynamicalSpeakToBufferPlatform[text, sr];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    Print["[WARNING] Speech synthesis unavailable (SpeechSynthesize[] and " <>
          "platform TTS both failed) — spoken intro will be skipped. Text:"];
    STEMSay[text];
    {}
  ];


(* ── Sentence cache ────────────────────────────────────────────────
   Narration is synthesised one sentence at a time, and each distinct
   sentence only once per run: SpeakNarration looks every sentence up in
   $dynamicalSpeechCache before calling BuildIntroBuffer. Divergence mode
   synthesises the narration of all four presets to pad them to the same
   length, and they share their opening sentences. Sentences are joined
   with $dynamicalSentenceGap of silence, about the pause `say` leaves
   between sentences of one text (measured: two sentences 8.07 s apart,
   8.29 s together), and the joined narration is normalised to 0.95 peak,
   as a whole text was before. *)

$dynamicalSpeechCache    = <||>;
$dynamicalSpeechCalls    = 0;    (* sentences sent to TTS this run *)
$dynamicalSpeechRequests = 0;    (* sentences asked for, cached or not *)
$dynamicalSentenceGap    = 0.2;  (* s *)

(* NarrationSentences — split after each full stop that ends a sentence
   (a full stop followed by white space; "3.449" does not split). *)
NarrationSentences[text_String] :=
  Select[StringTrim /@ StringSplit[text, RegularExpression["(?<=\\.)\\s+"]], # =!= "" &];

(* NarrationConventionIssues — sentences that do not start with a capital
   letter or do not end with a full stop. {} when the text is clean. *)
NarrationConventionIssues[text_String] :=
  Select[NarrationSentences[text],
    !(UpperCaseQ[StringTake[#, 1]] && StringEndsQ[#, "."]) &];

SpeakSentence[sentence_String, sr_Integer] :=
  (
    $dynamicalSpeechRequests++;
    If[KeyExistsQ[$dynamicalSpeechCache, {sentence, sr}],
      $dynamicalSpeechCache[{sentence, sr}],
      $dynamicalSpeechCalls++;
      $dynamicalSpeechCache[{sentence, sr}] = BuildIntroBuffer[sentence, sr]]
  );

(* SpeakNarration — the whole text as one buffer, {} if nothing could be
   synthesised. *)
SpeakNarration[text_String, sr_Integer] :=
  Module[{bufs, gap},
    bufs = Select[SpeakSentence[#, sr] & /@ NarrationSentences[text], Length[#] > 0 &];
    If[bufs === {}, Return[{}]];
    gap = ConstantArray[0.0, Round[$dynamicalSentenceGap * sr]];
    NormalizeBuffer[Join @@ Riffle[bufs, {gap}], 0.95]
  ];


(* ── Spoken numbers ──────────────────────────────────────────────────── *)

(* SpokenDec — at most d decimals, no trailing zeros, "minus" for a
   negative number (2.8 -> "2.8", 4. -> "4", -0.25 -> "minus 0.25"). *)
SpokenDec[x_?NumericQ, d_Integer: 3] :=
  If[x < 0 && Round[Abs[x] * 10^d] != 0, "minus ", ""] <> FmtDec[Abs[x], d];

(* SpokenFixed — exactly d decimals (0.8 -> "0.80"), "minus" if negative. *)
SpokenFixed[x_?NumericQ, d_Integer] :=
  If[x < 0 && Round[Abs[x] * 10^d] != 0, "minus ", ""] <>
    ToString[NumberForm[Abs[N[x]], {12, d}], OutputForm];

(* SpokenList — {"a"} -> "a", {"a","b"} -> "a and b", {"a","b","c"} -> "a, b and c". *)
SpokenList[items_List] :=
  Switch[Length[items],
    0, "", 1, First[items],
    _, StringRiffle[Most[items], ", "] <> " and " <> Last[items]];

(* The sentences the sweep intro opens with; the iterate intro uses the
   first and says r's value in the second. *)
$populationMap = "The logistic map gives next year's population from this year's.";
$populationFraming = $populationMap <>
  " The population x is a fraction of the maximum; r is the growth rate.";


(* ── Sweep and iterate narration ─────────────────────────────────────── *)

(* BuildSweepIntroText — under 15 s of speech. *)
BuildSweepIntroText[rStart_?NumericQ, rEnd_?NumericQ] :=
  $populationFraming <> " As r rises from " <> SpokenDec[rStart, 2] <> " to " <>
  SpokenDec[rEnd, 2] <> ", the rhythm doubles, then turns chaotic, with a brief return to order.";

BuildSweepOutroText[rStart_?NumericQ, rEnd_?NumericQ] :=
  "End of the sweep from r equals " <> SpokenDec[rStart, 2] <> " to " <> SpokenDec[rEnd, 2] <> ".";

(* BuildIterateIntroText — under 15 s of speech. presetDesc is a whole
   sentence or "". nIterations and x0 are not spoken, to keep the intro
   short; the console prints both. *)
BuildIterateIntroText[r_?NumericQ, presetDesc_String, nIterations_Integer, x0_?NumericQ] :=
  $populationMap <> " The population x is a fraction of the maximum, and r, the growth rate, is " <>
  SpokenDec[r, 4] <> ". " <> If[presetDesc =!= "", presetDesc <> " ", ""] <> "Each note is one year.";

(* FixedPointSentences — the fixed point and its stability, from
   FixedPointStability (|f'(x_star)| = |2 - r|), as spoken sentences. *)
FixedPointSentences[r_?NumericQ] :=
  Module[{fp = FixedPointStability[r], cmp, what},
    cmp[v_] := Which[v < 1, "below one", v > 1, "above one", True, "exactly one"];
    what[v_] := Switch[v, "attracts", "attracts", "repels", "repels",
                       _, "neither attracts nor repels to first order"];
    If[fp["xStar"] >= 0,
      "The fixed point is " <> SpokenFixed[fp["xStar"], 3] <> ". " <>
      "There the slope, 2 minus r in size, is " <> SpokenFixed[fp["slope"], 2] <> ", " <>
      cmp[fp["slope"]] <> ", so the fixed point " <> what[fp["verdict"]] <> ".",
      "The fixed point is " <> SpokenFixed[fp["xStar"], 3] <> ", which is not a population. " <>
      "There the slope, 2 minus r in size, is " <> SpokenFixed[fp["slope"], 2] <> ", " <>
      cmp[fp["slope"]] <> ", so it " <> what[fp["verdict"]] <> ". " <>
      "At zero the slope is r, " <> SpokenFixed[fp["zeroSlope"], 2] <> ", " <> cmp[fp["zeroSlope"]] <>
      If[fp["zeroVerdict"] === "attracts", ", so the population dies out.",
         ", so zero " <> what[fp["zeroVerdict"]] <> "."]]
  ];

BuildIterateOutroText[r_?NumericQ] :=
  FixedPointSentences[r] <> " End of the iteration.";


(* ── Lyapunov narration ──────────────────────────────────────────────── *)

(* BuildLyapunovIntroText
   Says what is heard before the sweep starts, in at most 20 s of speech
   (measured 19.8 s with macOS say):
   what the two tones are, which side is chaotic, the touching at each
   period doubling (doublingRs, PeriodDoublingRs[]; only those inside
   the range are named), that later dips are windows of order, that
   beating announces a crossing and that short high tones mark
   bifurcations. The r range is said here and not again in the outro. *)
BuildLyapunovIntroText[rMin_?NumericQ, rMax_?NumericQ, doublingRs_List] :=
  Module[{inRange = Select[doublingRs, rMin <= # <= rMax &]},
    "Here r runs from " <> SpokenDec[rMin, 2] <> " to " <> SpokenDec[rMax, 2] <> ". " <>
    "The steady tone is zero, the moving tone the Lyapunov exponent: chaos above, order below. " <>
    If[inRange =!= {},
      "It touches zero at " <> If[Length[inRange] > 1, "each doubling: ", "a doubling: "] <>
        SpokenList[SpokenDec[#, 3] & /@ inRange] <> ". ",
      ""] <>
    "Later dips are windows of order. " <>
    "Beating means a crossing; short high tones mark bifurcations."
  ];

(* BuildLyapunovOutroText
   One sentence, at most 15 s of speech: the end marker, where the
   exponent first rose above zero (firstUp, or Missing[] when the range
   has none) and the widest (at most three) windows from LyapunovWindows
   in ascending r, each with its period. "period" is said once when every
   named window's period was identified. rMin and rMax are not spoken
   (the intro says the range). Measured with macOS say: three windows at
   three decimals take 14.8 s; the six window bounds alone take about
   9 s, so the wording is terse. *)
BuildLyapunovOutroText[rMin_?NumericQ, rMax_?NumericQ, firstUp_, windows_List] :=
  Module[{widest, allId, item},
    widest = SortBy[Take[ReverseSortBy[windows, #["width"] &], UpTo[3]], #["rStart"] &];
    allId  = AllTrue[widest, IntegerQ[#["period"]] &];
    item[w_, first_] :=
      If[IntegerQ[w["period"]],
        If[first || !allId, "period ", ""] <> ToString[w["period"]],
        "unidentified period"] <>
      " from " <> SpokenDec[w["rStart"], 3] <> " to " <> SpokenDec[w["rEnd"], 3];
    "End: " <>
    If[NumericQ[firstUp], "chaos from " <> SpokenDec[firstUp, 3], "the exponent never rose above zero"] <>
    Switch[Length[widest],
      0, ", and no window of order.",
      1, "; the only window " <> item[widest[[1]], True] <> ".",
      _, "; widest windows " <> StringRiffle[MapIndexed[item[#1, #2[[1]] === 1] &, Most[widest]], ", "] <>
           " and " <> item[Last[widest], False] <> "."]
  ];


(* ── Divergence mode narration ─────────────────────────────────────── *)

(* SpokenSmall — a small positive number as TTS-friendly words:
   1.*^-6 -> "one part in a million", 3.2*^-15 -> "3.2 times ten to the
   minus 15"; 0.1 -> "one tenth". *)
SpokenSmall[x_?NumericQ] :=
  Module[{e, m},
    Which[
      x == 0,        "zero",
      x == 10^-6,    "one part in a million",
      x == 10^-9,    "one part in a billion",
      x == 0.1,      "one tenth",
      x == 0.01,     "one hundredth",
      x >= 0.001,    ToString[NumberForm[N[x], 2]],
      True,
        e = Floor[Log10[x]]; m = x / 10.^e;
        ToString[NumberForm[m, 2]] <> " times ten to the minus " <> ToString[-e]]
  ];

(* DivergenceNarration
   Intro and outro text for one case, computed from its own orbits, fit
   and lambda. The intro is one shared sentence plus one case sentence,
   at most 12 s of speech (measured with macOS say: see VERIFICATION_narration.md); the
   outro is one sentence that starts with the end marker. main.wl calls it for the current run and for the four
   presets and pads the spoken intro and outro to the longest of them, so
   the four presets render to the same length. *)
DivergenceNarration[r_?NumericQ, case_String, x0_?NumericQ, delta_?NumericQ,
                    n_Integer, saturation_?NumericQ] :=
  Module[{orb, fit, lam, pred, rTxt, deltaTxt, satTxt, caseTxt, outro, period, nZero, caseName},
    orb  = DivergenceOrbits[r, x0, delta, n];
    fit  = DivergenceFit[orb["separation"], saturation];
    lam  = LyapunovExponent[r, x0, 1000, 10000, -100.0];
    pred = DivergencePredictedSaturation[lam, delta, saturation];
    rTxt = SpokenDec[r, 2];
    deltaTxt = SpokenSmall[delta];
    satTxt = SpokenSmall[saturation];
    caseTxt = Switch[case,
      "chaotic",
        "The chaotic case, r equals " <> rTxt <> ": the tone climbs" <>
        If[fit["saturated"], " to a high marker at iteration " <> ToString[fit["nSat"]] <> ".", "."],
      "edge",
        "The edge of chaos, r equals " <> rTxt <> ": the tone barely rises.",
      "periodic",
        period = AttractorPeriod[r];
        If[IntegerQ[period], "A period-" <> ToString[period] <> " case", "A periodic case"] <>
        ", r equals " <> rTxt <> ": the tone falls as both join the cycle.",
      _,
        "The stable case, r equals " <> rTxt <> ": the tone falls as both settle to one value."];
    caseName = Switch[case, "chaotic", "chaotic case", "edge", "edge of chaos",
                      "periodic", "periodic case", _, "stable case"];
    nZero = FirstPosition[orb["separation"], 0., {Missing[]}, {1}][[1]];
    outro = "End of the " <> caseName <> ": " <> If[fit["saturated"],
      "the separation passed " <> satTxt <> " at iteration " <> ToString[fit["nSat"]] <>
        ", and the Lyapunov exponent predicted iteration " <> SpokenFixed[pred, 1] <> ".",
      If[IntegerQ[nZero],
        "the separation shrank to zero by iteration " <> ToString[nZero - 1] <>
          ", as the Lyapunov exponent, " <> SpokenFixed[lam, 2] <> ", predicted.",
        "the separation never exceeded " <> satTxt <> "; its maximum was " <>
          SpokenSmall[Max[orb["separation"]]] <>
          If[NumericQ[pred], ", because the Lyapunov exponent, " <> SpokenFixed[lam, 3] <> ", is so small.",
             ", and the Lyapunov exponent, " <> SpokenFixed[lam, 2] <> ", predicted no growth."]]];
    <|"intro" ->
        "Two populations start " <> deltaTxt <> " apart, one in each ear; the middle tone is " <>
        "their distance. " <> caseTxt,
      "outro" -> outro, "lambda" -> lam, "fit" -> fit, "predicted" -> pred|>
  ];

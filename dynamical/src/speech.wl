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


(* BuildSweepIntroText *)
BuildSweepIntroText[rStart_?NumericQ, rEnd_?NumericQ] :=
  "Logistic map bifurcation sweep, r from " <> ToString[NumberForm[rStart, {3,2}]] <>
  " to " <> ToString[NumberForm[rEnd, {3,2}]] <> ". Listen for the rhythm doubling " <>
  "at r equals 3, then doubling again, before dissolving into chaos near r equals " <>
  "3.57. The period-3 window near r equals 3.83 produces a brief return to order. " <>
  "The Feigenbaum constant governing the doubling rate is approximately 4.669.";


(* BuildIterateIntroText *)
BuildIterateIntroText[r_?NumericQ, presetDesc_String, nIterations_Integer, x0_?NumericQ] :=
  "Logistic map iteration at r equals " <> ToString[NumberForm[r, {5,4}]] <> ". " <>
  If[presetDesc =!= "", presetDesc <> ". ", ""] <>
  ToString[nIterations] <> " iterations from x naught equals " <>
  ToString[NumberForm[N[x0], {3,2}]] <> ".";


(* BuildLyapunovIntroText
   Says what is heard before the sweep starts. Numbers in r are spoken
   with two decimals, as in BuildSweepIntroText. *)
BuildLyapunovIntroText[rMin_?NumericQ, rMax_?NumericQ] :=
  "Lyapunov exponent of the logistic map, r from " <> ToString[NumberForm[rMin, {3,2}]] <>
  " to " <> ToString[NumberForm[rMax, {3,2}]] <> ". The steady tone is zero. " <>
  "The moving tone is the Lyapunov exponent. Above the steady tone the orbit is chaotic, " <>
  "and nearby starting points separate exponentially. Below it they converge. " <>
  "Beating between the two tones means a crossing is near. " <>
  "Short high tones mark the bifurcation points.";


(* BuildLyapunovOutroText
   firstUp is the r of the first upward zero crossing, or Missing[] when
   the range has none. *)
BuildLyapunovOutroText[rMin_?NumericQ, rMax_?NumericQ, firstUp_] :=
  "End of the Lyapunov sweep from r equals " <> ToString[NumberForm[rMin, {3,2}]] <>
  " to " <> ToString[NumberForm[rMax, {3,2}]] <> ". " <>
  If[NumericQ[firstUp],
    "The exponent first rose above zero at r equals " <>
      ToString[NumberForm[firstUp, {4,3}]] <> ", where chaos begins.",
    "The exponent did not rise above zero in this range."];


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
   and lambda. main.wl calls it for the current run and for the four
   presets, and pads the spoken intro and outro to the longest of them, so
   the four presets render to the same length. *)
DivergenceNarration[r_?NumericQ, case_String, x0_?NumericQ, delta_?NumericQ,
                    n_Integer, saturation_?NumericQ] :=
  Module[{orb, fit, lam, pred, rTxt, deltaTxt, satTxt, caseTxt, outro, period, nZero},
    orb  = DivergenceOrbits[r, x0, delta, n];
    fit  = DivergenceFit[orb["separation"], saturation];
    lam  = LyapunovExponent[r, x0, 1000, 10000, -100.0];
    pred = DivergencePredictedSaturation[lam, delta, saturation];
    rTxt = ToString[NumberForm[N[r], {3, 2}]];
    deltaTxt = If[delta == 10^-6 || delta == 10^-9, SpokenSmall[delta],
                  "a difference of " <> SpokenSmall[delta]];
    satTxt = SpokenSmall[saturation];
    caseTxt = Switch[case,
      "chaotic",
        "This is the chaotic case, r equals " <> rTxt <> ". Expect the left and right " <>
        "tones to agree at first while the middle tone climbs steadily" <>
        If[fit["saturated"],
          "; after about " <> ToString[Round[fit["nSat"]]] <> " iterations the separation " <>
          "reaches " <> satTxt <> ", a marker sounds, and the two tones go their own ways.",
          "."],
      "edge",
        "This is the edge of chaos, r equals " <> rTxt <> ", where the exponent is close " <>
        "to zero. Expect the middle tone to drift slowly instead of climbing, and the left " <>
        "and right tones to stay together.",
      "periodic",
        period = AttractorPeriod[r];
        "This is a periodic case, r equals " <> rTxt <>
        If[IntegerQ[period], ", a cycle of period " <> ToString[period], ""] <>
        ". Expect the middle tone to fall as the two populations converge onto the same " <>
        "cycle, and the left and right tones to stay together.",
      _,
        "This is the stable case, r equals " <> rTxt <> ", a single fixed point. Expect " <>
        "the middle tone to fall steadily as both populations settle to the same value."];
    nZero = FirstPosition[orb["separation"], 0., {Missing[]}, {1}][[1]];
    outro = If[fit["saturated"],
      "The separation exceeded " <> satTxt <> " at iteration " <> ToString[fit["nSat"]] <>
        ". The Lyapunov exponent predicted iteration " <> ToString[NumberForm[pred, {4, 1}]] <> ".",
      "The separation never exceeded " <> satTxt <> " in " <> ToString[n] <> " iterations; " <>
        If[IntegerQ[nZero],
          "it shrank to zero, at machine precision, by iteration " <> ToString[nZero - 1] <> ".",
          "it ended at " <> SpokenSmall[Last[orb["separation"]]] <> "."] <>
        If[NumericQ[pred],
          " The Lyapunov exponent predicted it would take about " <> ToString[Round[pred]] <>
            " iterations.",
          " The Lyapunov exponent, " <> ToString[NumberForm[lam, {3, 2}]] <>
            ", is negative, so it predicted the separation would shrink."]];
    <|"intro" ->
        "Sensitive dependence on initial conditions in the logistic map. Two populations " <>
        "start with " <> deltaTxt <> " between them. The left tone follows the first, the " <>
        "right tone follows the second, and the middle tone rises as they separate. Its rate " <>
        "of rise is the Lyapunov exponent. " <> caseTxt,
      "outro" -> outro, "lambda" -> lam, "fit" -> fit, "predicted" -> pred|>
  ];

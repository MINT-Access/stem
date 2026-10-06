(* ========================================================
   henon/src/speech.wl — Spoken orientation guidance

   Same three-tier fallback pattern established in
   dynamical/src/speech.wl (SpeechSynthesize[] -> platform-native
   TTS -> text-only STEMSay fallback), duplicated per convention
   rather than shared — only stem-core is shared between apps.
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


(* HenonSpeakToBufferPlatform — OS-native TTS -> mono PCM at targetSr. *)
HenonSpeakToBufferPlatform[text_String, targetSr_Integer] :=
  Module[{id, wavPath, snd, data, rawSr},
    id      = ToString[RandomInteger[999999]];
    wavPath = FileNameJoin[{$TemporaryDirectory, "stem_henon_say_" <> id <> ".wav"}];

    Switch[$OperatingSystem,

      "MacOSX",
        Module[{aiffPath, result, conv},
          aiffPath = FileNameJoin[{$TemporaryDirectory, "stem_henon_say_" <> id <> ".aiff"}];
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

    buf = HenonSpeakToBufferPlatform[text, sr];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    Print["[WARNING] Speech synthesis unavailable (SpeechSynthesize[] and " <>
          "platform TTS both failed) — spoken intro will be skipped. Text:"];
    STEMSay[text];
    {}
  ];


(* BuildAttractorIntroText *)
BuildAttractorIntroText[a_?NumericQ, b_?NumericQ] :=
  "Hénon attractor, a equals " <> ToString[NumberForm[a, {3, 2}]] <>
  ", b equals " <> ToString[NumberForm[b, {3, 2}]] <>
  ". A two-dimensional invertible map, built by Michel Hénon as a simplified " <>
  "model of a cross-section through the Lorenz attractor. Listen for the " <>
  "stereo position tracing the fractal cross-section as the trajectory " <>
  "folds back on itself.";


(* BuildSweepIntroText
   Names only the landmarks inside [aMin, aMax]: the doublings (first,
   second, third bifurcation), the onset of chaos and the period-seven
   window. A zoomed sweep therefore no longer announces a doubling or a
   window it never reaches (sweep_chaos_zoom, a 1.05 to 1.4, used to say
   "doubling near a equals 0.37"; sweep_cascade_zoom, a 0.3 to 1.1, used
   to promise the window at 1.23). The full sweep's text is unchanged. *)
BuildSweepIntroText[aMin_?NumericQ, aMax_?NumericQ, landmarks_Association] :=
  Module[{f, inR, doublings, nLater, chaosIn, windowIn, doublingTxt},
    f[x_] := ToString[NumberForm[x, {3, 2}]];
    inR[k_] := aMin <= landmarks[k] <= aMax;
    doublings = Select[{"first_bifurcation", "second_bifurcation", "third_bifurcation"}, inR];
    chaosIn  = inR["chaos_onset"];
    windowIn = inR["periodic_window"];
    nLater   = Length[Select[doublings, # =!= "first_bifurcation" &]];
    doublingTxt = Which[
      MemberQ[doublings, "first_bifurcation"],
        "Listen for the rhythm doubling near a equals " <> f[landmarks["first_bifurcation"]] <>
        Switch[nLater, 2, ", doubling again twice more", 1, ", doubling again", _, ""],
      doublings =!= {},
        "Listen for the rhythm doubling again near a equals " <>
        StringRiffle[f[landmarks[#]] & /@ doublings, " and "],
      True, ""];
    "Hénon map bifurcation sweep, a from " <> f[aMin] <> " to " <> f[aMax] <> ". " <>
    Which[
      doublingTxt =!= "" && chaosIn,
        doublingTxt <> ", before dissolving into chaos near a equals " <> f[landmarks["chaos_onset"]] <> ". ",
      doublingTxt =!= "", doublingTxt <> ". ",
      chaosIn, "Listen for the rhythm dissolving into chaos near a equals " <> f[landmarks["chaos_onset"]] <> ". ",
      True, ""] <>
    If[windowIn,
      "A brief period-seven window near a equals " <> f[landmarks["periodic_window"]] <>
        " produces a surprising return to order.",
      If[doublingTxt === "" && !chaosIn, "No bifurcation landmark lies inside this range.", ""]] //
      StringTrim
  ];

(* Outros — a short spoken end marker for each mode. *)
BuildAttractorOutroText[] := "This is the end of the Hénon attractor.";
BuildSweepOutroText[aMin_?NumericQ, aMax_?NumericQ] :=
  "This is the end of the sweep from a equals " <> ToString[NumberForm[aMin, {3, 2}]] <>
  " to " <> ToString[NumberForm[aMax, {3, 2}]] <> ".";
BuildReverseOutroText[] := "This is the end of the reverse demonstration.";


(* BuildReverseIntroText *)
BuildReverseIntroText[reverseSteps_Integer] :=
  "Hénon reverse demonstration. First, a short forward segment on the " <>
  "attractor. Then, the same segment replayed in reverse order — a simple " <>
  "reversal, numerically exact. Finally, the last " <> ToString[reverseSteps] <>
  " points recovered by applying the exact inverse map formula, proving " <>
  "the Hénon map is genuinely invertible.";

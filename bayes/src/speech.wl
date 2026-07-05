(* ========================================================
   bayes/src/speech.wl — Spoken introduction synthesis

   Same three-tier fallback pattern established in images/src/speech.wl,
   dynamical/src/speech.wl, and thermo/src/speech.wl (SpeechSynthesize[]
   -> platform-native TTS -> text-only STEMSay fallback). Duplicated
   rather than shared because apps do not import each other's src/
   files — only stem-core is shared.
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


(* BayesSpeakToBufferPlatform — OS-native TTS -> mono PCM at targetSr. *)
BayesSpeakToBufferPlatform[text_String, targetSr_Integer] :=
  Module[{id, wavPath, snd, data, rawSr},
    id      = ToString[RandomInteger[999999]];
    wavPath = FileNameJoin[{$TemporaryDirectory, "stem_bayes_say_" <> id <> ".wav"}];

    Switch[$OperatingSystem,

      "MacOSX",
        Module[{aiffPath, result, conv},
          aiffPath = FileNameJoin[{$TemporaryDirectory, "stem_bayes_say_" <> id <> ".aiff"}];
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

    buf = BayesSpeakToBufferPlatform[text, sr];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    Print["[WARNING] Speech synthesis unavailable (SpeechSynthesize[] and " <>
          "platform TTS both failed) — spoken intro will be skipped. Text:"];
    STEMSay[text];
    {}
  ];


(* ── Intro text builders, one per mode ───────────────────────────── *)

BuildCoinIntroText[thetaTrue_?NumericQ, nFlips_Integer, audioFreqThetaTrue_?NumericQ] :=
  "Bayesian coin inference. True bias " <> ToString[NumberForm[N[thetaTrue], {3, 2}]] <>
  ", uniform prior, " <> ToString[nFlips] <> " flips. The sound begins broad -- all bias " <>
  "values are equally plausible. Listen for it narrowing to a focused tone near pitch " <>
  ToString[Round[audioFreqThetaTrue]] <> " Hertz as the data accumulates. Convergence " <>
  "milestone and completion are marked by accent tones.";

BuildGaussianIntroText[muTrue_?NumericQ, mu0_?NumericQ, sigma0_?NumericQ, sigma_?NumericQ,
                       nObs_Integer, audioFreqMu0_?NumericQ, audioFreqMuTrue_?NumericQ] :=
  "Bayesian Gaussian mean estimation. True mean " <> ToString[NumberForm[N[muTrue], {3, 2}]] <>
  ", prior centred at " <> ToString[NumberForm[N[mu0], {3, 2}]] <> " with standard deviation " <>
  ToString[NumberForm[N[sigma0], {3, 2}]] <> ", observation noise " <>
  ToString[NumberForm[N[sigma], {3, 2}]] <> ", " <> ToString[nObs] <> " observations. Listen " <>
  "for the pitch shifting from " <> ToString[Round[audioFreqMu0]] <> " Hertz toward " <>
  ToString[Round[audioFreqMuTrue]] <> " Hertz as the posterior mean moves toward the true " <>
  "value, and the sound narrowing as uncertainty shrinks.";

(* The expected drift direction depends on how thetaTrue relates to the
   two hypotheses (theta1=0.5 vs theta2=thetaAlt) — spelled out
   explicitly here (rather than hardcoding "toward the right", which is
   only true for the default thetaTrue=thetaAlt=0.7 configuration) so
   the spoken intro stays accurate if a listener overrides thetaTrue to
   favour hypothesis 1 instead. *)
BuildModelIntroText[nFlips_Integer, thetaAlt_?NumericQ, thetaTrue_?NumericQ] :=
  Module[{expectedLogKPerFlip, sideWord, sideDesc},
    expectedLogKPerFlip = thetaTrue * Log10[0.5 / thetaAlt] +
                          (1.0 - thetaTrue) * Log10[0.5 / (1.0 - thetaAlt)];
    {sideWord, sideDesc} = If[expectedLogKPerFlip >= 0,
      {"left", "the fair coin hypothesis"},
      {"right", "the biased coin hypothesis"}
    ];
    "Bayesian model comparison. " <> ToString[nFlips] <> " coin flips. Hypothesis 1: fair coin, " <>
    "theta equals 0.5. Hypothesis 2: biased coin, theta equals " <>
    ToString[NumberForm[N[thetaAlt], {3, 2}]] <> ". True data from theta equals " <>
    ToString[NumberForm[N[thetaTrue], {3, 2}]] <> ". Listen for the stereo position drifting " <>
    "toward the " <> sideWord <> " as evidence accumulates for " <> sideDesc <>
    ". Strong evidence is marked by accent tones."
  ];

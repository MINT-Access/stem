(* ========================================================
   blackbody/src/speech.wl — Spoken introduction synthesis

   Same three-tier fallback pattern established in images/src/speech.wl,
   dynamical/src/speech.wl, thermo/src/speech.wl, and hydrogen/src/speech.wl
   (SpeechSynthesize[] -> platform-native TTS -> text-only STEMSay
   fallback). Duplicated rather than shared because apps do not import
   each other's src/ files -- only stem-core is shared.
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


(* BlackbodySpeakToBufferPlatform — OS-native TTS -> mono PCM at targetSr. *)
BlackbodySpeakToBufferPlatform[text_String, targetSr_Integer] :=
  Module[{id, wavPath, snd, data, rawSr},
    id      = ToString[RandomInteger[999999]];
    wavPath = FileNameJoin[{$TemporaryDirectory, "stem_blackbody_say_" <> id <> ".wav"}];

    Switch[$OperatingSystem,

      "MacOSX",
        Module[{aiffPath, result, conv},
          aiffPath = FileNameJoin[{$TemporaryDirectory, "stem_blackbody_say_" <> id <> ".aiff"}];
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

    buf = BlackbodySpeakToBufferPlatform[text, sr];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    Print["[WARNING] Speech synthesis unavailable (SpeechSynthesize[] and " <>
          "platform TTS both failed) — spoken intro will be skipped. Text:"];
    STEMSay[text];
    {}
  ];


(* ── Intro text builders, one per mode ───────────────────────────── *)

BuildSpectrumIntroText[T_?NumericQ, nBins_Integer] :=
  "Planck black body spectrum at " <> ToString[Round[T]] <> " Kelvin, " <>
  ToString[nBins] <> " frequency bins from radio to X-ray. First, the full curve as " <>
  "a single chord -- every frequency sounding at once, weighted by the Planck curve " <>
  "itself. Two soft taps mark the edges of the narrow band of visible light. Then, " <>
  "the same bins swept one at a time from radio up to X-ray.";

BuildSpectrumOutroText[] :=
  "Notice how little of the sweep fell between the two taps -- that narrow sliver " <>
  "is all of the light a human eye can see. Everything else in the sweep is light " <>
  "this star emits that no eye can detect.";

BuildTemperatureIntroText[Tmin_?NumericQ, Tmax_?NumericQ] :=
  "Temperature sweep from " <> ToString[Round[Tmin]] <> " to " <> ToString[Round[Tmax]] <>
  " Kelvin, red dwarf to blue giant. Listen for the pitch of the marked peak rising " <>
  "as temperature increases -- that is Wien's displacement law. Listen for the " <>
  "overall loudness growing, compressed onto a manageable range -- the true growth, " <>
  "following the Stefan-Boltzmann law, is the fourth power of temperature.";

BuildStarIntroText[starName_String, T_?NumericQ] :=
  "Black body spectrum of " <> starName <> ", temperature " <> ToString[Round[T]] <>
  " Kelvin.";

BuildStarTourIntroText[] :=
  "A tour of six black bodies, from coolest to hottest: a red dwarf, Betelgeuse, " <>
  "the Sun, Sirius A, Rigel, and a white dwarf. Listen for the pitch of each " <>
  "chord's peak rising and the chord growing louder as temperature increases.";

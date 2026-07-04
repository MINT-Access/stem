(* ========================================================
   thermo/src/speech.wl — Spoken introduction synthesis

   Same three-tier fallback pattern established in images/src/speech.wl
   and dynamical/src/speech.wl (SpeechSynthesize[] -> platform-native
   TTS -> text-only STEMSay fallback). Duplicated rather than shared
   because apps do not import each other's src/ files — only stem-core
   is shared (see dynamical/AGENTS.md's note: a good candidate for
   stem-core consolidation once a fourth app needs it).
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


(* ThermoSpeakToBufferPlatform — OS-native TTS -> mono PCM at targetSr. *)
ThermoSpeakToBufferPlatform[text_String, targetSr_Integer] :=
  Module[{id, wavPath, snd, data, rawSr},
    id      = ToString[RandomInteger[999999]];
    wavPath = FileNameJoin[{$TemporaryDirectory, "stem_thermo_say_" <> id <> ".wav"}];

    Switch[$OperatingSystem,

      "MacOSX",
        Module[{aiffPath, result, conv},
          aiffPath = FileNameJoin[{$TemporaryDirectory, "stem_thermo_say_" <> id <> ".aiff"}];
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

    buf = ThermoSpeakToBufferPlatform[text, sr];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    Print["[WARNING] Speech synthesis unavailable (SpeechSynthesize[] and " <>
          "platform TTS both failed) — spoken intro will be skipped. Text:"];
    STEMSay[text];
    {}
  ];


(* ── Intro text builders, one per mode ───────────────────────────── *)

BuildDistributionIntroText[gasName_String, massAmu_?NumericQ, TStart_?NumericQ, TEnd_?NumericQ] :=
  "Maxwell-Boltzmann speed distribution for " <> gasName <> ", mass " <>
  ToString[NumberForm[N[massAmu], {3, 1}]] <> " atomic mass units. " <>
  "Temperature sweep from " <> ToString[Round[TStart]] <> " to " <> ToString[Round[TEnd]] <>
  " Kelvin. Listen for the spectrum broadening and rising in pitch as temperature increases. " <>
  "The three characteristic speeds -- most probable, mean, and R M S -- are marked by a soft " <>
  "triple-tap at each temperature step.";

BuildEnsembleIntroText[nParticles_Integer, gasName_String, T_?NumericQ] :=
  ToString[nParticles] <> " particles of " <> gasName <> " at " <> ToString[Round[T]] <>
  " Kelvin. Listen for the chord of " <> ToString[nParticles] <> " simultaneous tones, " <>
  "constantly reshuffling through elastic collisions while maintaining the same overall " <>
  "temperature. The whole is stable; the parts are restless.";

BuildCoolingIntroText[gasName_String, THot_?NumericQ, TCold_?NumericQ] :=
  gasName <> " cooling from " <> ToString[Round[THot]] <> " Kelvin to " <> ToString[Round[TCold]] <>
  " Kelvin. Listen for the sound contracting and darkening as molecules slow down, finally " <>
  "settling into a narrow low hum at thermal equilibrium.";

BuildEquipartitionIntroText[moleculeType_String, TStart_?NumericQ, TEnd_?NumericQ] :=
  "Equipartition theorem: " <> moleculeType <> " gas at " <> ToString[Round[TStart]] <> " to " <>
  ToString[Round[TEnd]] <> " Kelvin. Left channel: translational kinetic energy -- identical " <>
  "for all ideal gases at the same temperature. Right channel: rotational energy contribution " <>
  "-- present for diatomic gases, absent for monatomic. Listen for the right channel growing " <>
  "as temperature rises.";

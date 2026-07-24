(* ========================================================
   compton/src/speech.wl — Spoken introduction synthesis

   Same three-tier fallback pattern established in
   blackbody/src/speech.wl, thermo/src/speech.wl, and
   scattering/src/sonify.wl's identical pattern (SpeechSynthesize[] ->
   platform-native TTS -> text-only STEMSay fallback). Duplicated
   rather than shared because apps do not import each other's src/
   files -- only stem-core is shared.
   ======================================================== *)


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


ComptonSpeakToBufferPlatform[text_String, targetSr_Integer] :=
  Module[{id, wavPath, snd, data, rawSr},
    id      = ToString[RandomInteger[999999]];
    wavPath = FileNameJoin[{$TemporaryDirectory, "stem_compton_say_" <> id <> ".wav"}];

    Switch[$OperatingSystem,

      "MacOSX",
        Module[{aiffPath, result, conv},
          aiffPath = FileNameJoin[{$TemporaryDirectory, "stem_compton_say_" <> id <> ".aiff"}];
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

    buf = ComptonSpeakToBufferPlatform[text, sr];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    Print["[WARNING] Speech synthesis unavailable (SpeechSynthesize[] and " <>
          "platform TTS both failed) — spoken intro will be skipped. Text:"];
    STEMSay[text];
    {}
  ];


(* ── Intro/outro text builders, one per mode ─────────────────────── *)

BuildScatterIntroText[model_Association] :=
  "Compton scattering, 1923: an X-ray photon at " <> ToString[NumberForm[model["lambdaPm"], {4, 1}]] <>
  " picometres, " <> ToString[NumberForm[model["EKeV"], {4, 1}]] <>
  " kiloelectronvolts, scatters through " <> ToString[Round[model["thetaDeg"]]] <>
  " degrees. Listen for the incoming photon, a collision click, then the outgoing photon " <>
  "at a measurably lower pitch, panned according to the scattering angle, and a soft low thud " <>
  "for the recoiling electron.";

BuildScatterOutroText[model_Association] :=
  "Outgoing energy " <> ToString[NumberForm[model["EPrimeKeV"], {4, 1}]] <>
  " kiloelectronvolts, down from " <> ToString[NumberForm[model["EKeV"], {4, 1}]] <>
  ". The electron recoiled with " <> ToString[NumberForm[model["TKeV"], {4, 2}]] <>
  " kiloelectronvolts of kinetic energy. This is the measurement that proved light carries " <>
  "momentum like a particle.";

BuildSweepIntroText[model_Association] :=
  "Angle sweep from " <> ToString[Round[model["angleMin"]]] <> " to " <> ToString[Round[model["angleMax"]]] <>
  " degrees, incident wavelength " <> ToString[NumberForm[model["lambdaPm"], {4, 1}]] <>
  " picometres. Listen for the pitch dropping fastest through the middle of the sweep, near " <>
  "90 degrees, and slowest near the two ends -- the sine of the angle in Compton's own formula.";

BuildEnergyIntroText[model_Association] :=
  "Incident photon energy swept from " <> ToString[NumberForm[model["EMinKev"], {4, 1}]] <>
  " to " <> ToString[NumberForm[model["EMaxKev"], {5, 0}]] <>
  " kiloelectronvolts at a fixed " <> ToString[Round[model["angleDeg"]]] <>
  " degree scattering angle. Listen for the incoming and outgoing pitches starting in near " <>
  "unison at low energy, and pulling apart as energy rises past the electron's own rest energy, " <>
  "511 kiloelectronvolts, marked by an accent tone.";

BuildDiscoveryIntroText[] :=
  "Compton's 1923 measurement, binaural. Left channel: the classical Thomson prediction -- " <>
  "elastic scattering, the outgoing pitch always equal to the incoming pitch, at every angle. " <>
  "Right channel: the real, quantum result -- the outgoing pitch measurably drops as the angle " <>
  "increases. The two channels start in unison and pull apart as the sweep proceeds -- that gap " <>
  "is the evidence that decided the wave-particle debate.";

BuildDiscoveryOutroText[] :=
  "The right channel's pitch drop has no classical explanation. Arthur Compton's 1923 " <>
  "measurement of exactly this effect won him the 1927 Nobel Prize in Physics.";

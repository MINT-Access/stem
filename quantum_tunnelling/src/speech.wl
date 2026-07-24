(* ========================================================
   quantum_tunnelling/src/speech.wl — Spoken introduction synthesis

   Same three-tier fallback pattern established in
   compton/src/speech.wl, blackbody/src/speech.wl, and
   thermo/src/speech.wl (SpeechSynthesize[] -> platform-native TTS ->
   text-only STEMSay fallback). Duplicated rather than shared because
   apps do not import each other's src/ files -- only stem-core is
   shared.
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


TunnellingSpeakToBufferPlatform[text_String, targetSr_Integer] :=
  Module[{id, wavPath, snd, data, rawSr},
    id      = ToString[RandomInteger[999999]];
    wavPath = FileNameJoin[{$TemporaryDirectory, "stem_quantum_tunnelling_say_" <> id <> ".wav"}];

    Switch[$OperatingSystem,

      "MacOSX",
        Module[{aiffPath, result, conv},
          aiffPath = FileNameJoin[{$TemporaryDirectory, "stem_quantum_tunnelling_say_" <> id <> ".aiff"}];
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

    buf = TunnellingSpeakToBufferPlatform[text, sr];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    Print["[WARNING] Speech synthesis unavailable (SpeechSynthesize[] and " <>
          "platform TTS both failed) — spoken intro will be skipped. Text:"];
    STEMSay[text];
    {}
  ];


(* ── Intro/outro text builders, one per mode ─────────────────────── *)

BuildBarrierIntroText[model_Association] :=
  "Quantum tunnelling, " <> model["preset"] <> " preset: a particle at " <>
  ToString[NumberForm[model["E"], {5, 3}]] <> " electronvolts approaches a barrier " <>
  ToString[NumberForm[model["V0"], {5, 3}]] <> " electronvolts high, " <>
  ToString[NumberForm[model["L"], {5, 6}]] <> " nanometres wide. Classically, this " <>
  "particle cannot cross. Listen for the incoming tone, a marker at the barrier, then " <>
  "two simultaneous outcomes: a reflected tone bouncing back, and a transmitted tone " <>
  "passing through -- both genuinely happen, in proportion to their probability.";

BuildBarrierOutroText[model_Association] :=
  "Transmission probability " <> ToString[NumberForm[model["T"] * 100.0, {6, 4}]] <>
  " percent. Reflection probability " <> ToString[NumberForm[model["R"] * 100.0, {6, 4}]] <>
  " percent. The particle had zero classical chance of crossing, and yet quantum " <>
  "mechanically, sometimes, it does.";

BuildSweepIntroText[model_Association] :=
  "Barrier width swept from " <> ToString[NumberForm[model["widthMin"], {5, 3}]] <>
  " to " <> ToString[NumberForm[model["widthMax"], {5, 3}]] <>
  " nanometres, at a fixed particle energy below the barrier height. Listen for the " <>
  "tunnelling probability fading toward silence as the barrier grows thicker -- an " <>
  "exponential collapse, made audibly gradual across the whole sweep.";

BuildEnergyIntroText[model_Association] :=
  "Particle energy swept from " <> ToString[NumberForm[model["EMin"], {5, 3}]] <>
  " to " <> ToString[NumberForm[model["EMax"], {5, 3}]] <>
  " electronvolts, crossing the barrier height of " <> ToString[NumberForm[model["V0"], {5, 3}]] <>
  " electronvolts, marked by an accent tone. Below that mark, listen for the volume " <>
  "rising as tunnelling becomes easier. Above it, listen for a genuine wobble -- " <>
  "transmission oscillates with energy, reaching perfect, total transmission at " <>
  "specific resonant energies, the same standing-wave condition that quantizes a " <>
  "particle trapped in a box.";

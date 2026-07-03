(* ========================================================
   images/src/speech.wl — Spoken orientation guidance

   Builds a short spoken introduction (image, dimensions, mode, and
   the mapping the listener needs to interpret the audio) and returns
   it as a raw PCM buffer so main.wl can prepend it to the main
   sonification before a single WAV export.

   Three-tier fallback, most to least capable:
     1. SpeechSynthesize[] — Wolfram's built-in TTS (tried first, per
        design intent: works without shelling out to any external
        program). Not available on every Wolfram Engine install.
     2. Platform-native TTS — macOS `say` + `afconvert`, Linux
        espeak-ng/espeak, Windows PowerShell SpeechSynthesizer.
        Adapted from the equivalent helper in signal/src/sonify.wl.
     3. Text-only — if both audio paths fail, print the intro text via
        STEMSay and return an empty buffer so the caller can skip the
        prepend gracefully rather than crash or emit silence.

   TODO: SpeakToBuffer-style helpers are duplicated between signal/ and
   images/. Once this feature is verified, consolidate into stem-core
   (tracked as a follow-up per the images/ enhancement spec).
   ======================================================== *)


(* ResampleLinear
   General linear-interpolation resampler: rawSr -> targetSr, any ratio
   (not limited to integer doubling). Returns data unchanged if the two
   rates are already within 1 Hz of each other. *)

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


(* ImagesSpeakToBufferPlatform
   Synthesises speech via the OS-native TTS engine and returns a mono
   PCM list at targetSr. Returns {} (not silence) on any failure so the
   caller can distinguish "no audio available" from "silent by design". *)

ImagesSpeakToBufferPlatform[text_String, targetSr_Integer] :=
  Module[{id, wavPath, snd, data, rawSr},
    id      = ToString[RandomInteger[999999]];
    wavPath = FileNameJoin[{$TemporaryDirectory, "stem_images_say_" <> id <> ".wav"}];

    Switch[$OperatingSystem,

      (* ── macOS: say -> AIFF-C -> afconvert -> WAV ── *)
      "MacOSX",
        Module[{aiffPath, result, conv},
          aiffPath = FileNameJoin[{$TemporaryDirectory, "stem_images_say_" <> id <> ".aiff"}];
          result = Quiet[RunProcess[{"say", "-o", aiffPath, text}]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[aiffPath],
            Quiet[DeleteFile /@ Select[{aiffPath, wavPath}, FileExistsQ]];
            Return[{}]];
          conv = Quiet[RunProcess[{"afconvert", aiffPath, wavPath, "-d", "LEI16", "-f", "WAVE"}]];
          Quiet[DeleteFile[aiffPath]];
          If[!AssociationQ[conv] || conv["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            Quiet[DeleteFile /@ Select[{wavPath}, FileExistsQ]];
            Return[{}]]],

      (* ── Linux: espeak-ng or espeak -> WAV directly ── *)
      "Unix",
        Module[{result},
          result = Quiet[RunProcess[{"espeak-ng", "-w", wavPath, text}]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            result = Quiet[RunProcess[{"espeak", "-w", wavPath, text}]]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            Quiet[DeleteFile /@ Select[{wavPath}, FileExistsQ]];
            Return[{}]]],

      (* ── Windows: PowerShell SpeechSynthesizer -> WAV ── *)
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

      (* ── Unknown platform ── *)
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


(* BuildIntroBuffer
   Top-level entry point: tries SpeechSynthesize[] first, falls back to
   platform-native TTS, and finally falls back to text-only (STEMSay)
   with an empty buffer so the caller can skip the audio prepend. *)

BuildIntroBuffer[text_String, sr_Integer] :=
  Module[{buf, result, data, rawSr},

    (* 1. SpeechSynthesize[] — tried first per design intent *)
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

    (* 2. Platform-native TTS *)
    buf = ImagesSpeakToBufferPlatform[text, sr];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    (* 3. Text-only fallback — no audio prepend *)
    Print["[WARNING] Speech synthesis unavailable (SpeechSynthesize[] and " <>
          "platform TTS both failed) — spoken intro will be skipped. Text:"];
    STEMSay[text];
    {}
  ];


(* BuildIntroText
   Assembles the spoken introduction for a sonification run: image
   description, dimensions, mode, the mode's key mapping, optional
   colour-mode statistics, and the duration of the sonification to
   follow. colourStats is a <|"nDistinct"->.., "mostCommon"->..|>
   Association (colour mode only) or Missing[] otherwise. *)

BuildIntroText[mode_String, srcDesc_String, imgW_Integer, imgH_Integer,
               brightnessScale_String, sonificationDurSec_?NumericQ,
               colourStats_ : Missing[]] :=
  Module[{modeLabel, mappingText, statsText, durText},

    modeLabel = Switch[mode,
      "brightness",      "brightness",
      "scan_horizontal", "simple horizontal scan",
      "colour",          "colour",
      "hsb",             "hue, saturation, and brightness",
      _,                 mode
    ];

    mappingText = Switch[mode,
      "brightness" | "scan_horizontal",
        "Low pitch means dark pixels; high pitch means bright pixels. " <>
        "Brightness scaling: " <> brightnessScale <> ".",
      "colour",
        "Pitch follows the visible light spectrum: violet is the lowest " <>
        "note, red is the highest. A long held note means a large " <>
        "uniform colour region.",
      "hsb",
        "Pitch encodes colour: violet is lowest, red is highest. Richer " <>
        "tone means brighter pixel.",
      _,
        ""
    ];

    statsText = If[mode === "colour" && AssociationQ[colourStats],
      " Detected " <> ToString[colourStats["nDistinct"]] <>
      " distinct colour regions. The most common colour is " <>
      colourStats["mostCommon"] <> ".",
      ""
    ];

    durText = " Sonification duration: " <>
      ToString[Round[sonificationDurSec, 0.1]] <> " seconds.";

    "Sonifying " <> srcDesc <> ". Image size: " <> ToString[imgW] <> " by " <>
    ToString[imgH] <> " pixels. Mode: " <> modeLabel <> ". " <>
    mappingText <> statsText <> durText
  ];

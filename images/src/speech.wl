(* ========================================================
   images/src/speech.wl — Spoken orientation guidance

   Builds a short spoken introduction (image, dimensions, mode, and
   the mapping the listener needs to interpret the audio) and returns
   it as a raw PCM buffer so main.wl can prepend it to the main
   sonification before a single WAV export.

   Narration audio comes from stem-core's STEMSpeakToBuffer
   (SpeechSynthesize[] -> platform TTS -> text printed after a
   warning); this file holds only the app's narration text.
   ======================================================== *)


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

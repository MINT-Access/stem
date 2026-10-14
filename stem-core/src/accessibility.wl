(* ========================================================
   stem-core/src/accessibility.wl — Screen-reader-friendly output

   All public functions (STEM prefix) print a single complete
   line to stdout so VoiceOver / Orca / Narrator reads each
   chunk as one unit.

   Requires: utils.wl (for FmtN, FmtDec)

   Sections:
     1. Numeric formatting     — STEMPrintN
     2. Structured announcements — STEMHeading, STEMSection, STEMBullet
     3. Export metadata        — STEMDescribeCSV, STEMDescribeWAV, STEMDescribeGIF
     4. Speech integration     — $STEMSpeakEnabled, STEMSay
     5. Audio playback         — STEMPlayCmd, STEMPlay
   ======================================================== *)


(* ── 1. Numeric formatting ───────────────────────────────── *)

(* STEMPrintN
   Prints "  label: value unit" as one complete stdout line.
   spec is passed to FmtN: an integer for significant figures
   or {total, decimals} for fixed decimal places.
   Omit unit for dimensionless quantities; omit spec to use FmtN default (4 sig figs). *)

STEMPrintN[label_String, x_?NumericQ] :=
  Print["  ", label, ": ", FmtN[x]]

STEMPrintN[label_String, x_?NumericQ, unit_String] :=
  Print["  ", label, ": ", FmtN[x], " ", unit]

STEMPrintN[label_String, x_?NumericQ, unit_String, spec_] :=
  Print["  ", label, ": ", FmtN[x, spec], " ", unit]


(* ── 2. Structured announcements ─────────────────────────── *)

(* STEMHeading
   Prints "=== text ===" — major section titles.
   Matches the heading style used in project main.wl files so
   existing VoiceOver users recognise the delimiter pattern. *)

STEMHeading[text_String] :=
  Print["=== ", text, " ==="]


(* STEMSection
   Prints "-- title --" — sub-section markers within a heading block. *)

STEMSection[title_String] :=
  Print["-- ", title, " --"]


(* STEMBullet
   Prints "  * text" — list items within a section.
   Uses ASCII asterisk rather than a Unicode bullet because some terminal
   configurations cause VoiceOver to skip over non-ASCII punctuation. *)

STEMBullet[text_String] :=
  Print["  * ", text]


(* ── 3. Export metadata descriptions ─────────────────────── *)

(* STEMDescribeCSV
   Prints a single line summarising a completed CSV export.
   nRows is the data row count (excluding the header row);
   nCols is the column count. *)

STEMDescribeCSV[filePath_String] :=
  Print["  CSV: ", filePath]

STEMDescribeCSV[filePath_String, nRows_Integer, nCols_Integer] :=
  Print["  CSV: ", nRows, " rows, ", nCols, " columns — ", filePath]


(* STEMDescribeWAV
   Prints a single line summarising a completed WAV export.
   durationSec is the audio duration in seconds. *)

STEMDescribeWAV[filePath_String] :=
  Print["  Audio: ", filePath]

STEMDescribeWAV[filePath_String, durationSec_?NumericQ] :=
  Print["  Audio: ", FmtN[durationSec, 4], " s — ", filePath]


(* STEMDescribeGIF
   Prints a single line summarising a completed animated GIF export.
   nFrames is the total frame count; fps is the playback rate, printed
   with at most three decimals (FmtDec). *)

STEMDescribeGIF[filePath_String, ___] /; STEMGIFFailedQ[filePath] :=
  Print["  Animation: ", If[FileType[filePath] === File,
    "the export failed; only a diagnostic retry wrote the file", "not written (the GIF export failed, see above)"],
    " \[LongDash] ", filePath]

STEMDescribeGIF[filePath_String] :=
  Print["  Animation: ", filePath]

STEMDescribeGIF[filePath_String, nFrames_Integer, fps_?NumericQ] :=
  Print["  Animation: ", nFrames, " frames at ", FmtDec[fps], " fps — ", filePath]

(* STEMLoudnessLine
   Measures the written WAV (stem-core MeasureIntegratedLoudness, EBU
   R128, and the sample peak) and prints one sentence, the same wording
   as dynamical's loudness line:
     "  Loudness: the WAV was normalised to -17 LUFS and measures -17.02
      LUFS integrated, with a peak of -1.13 dBFS."
   targetLUFS is the target the app normalised to. Returns
   <|"lufs", "peakDB"|>. *)
STEMLoudnessLine[wavPath_String, targetLUFS_?NumericQ] :=
  Module[{data, sr, lufs, peak},
    data = Import[wavPath, "Data"]; sr = Import[wavPath, "SampleRate"];
    If[VectorQ[data], data = {data}];
    lufs = MeasureIntegratedLoudness[data, sr];
    peak = 20.0 * Log10[Max[Abs[Flatten[data]]]];
    Print["  Loudness: the WAV was normalised to ", FmtDec[targetLUFS, 1],
          " LUFS and measures ", FmtDec[lufs, 2], " LUFS integrated, with a peak of ",
          FmtDec[peak, 2], " dBFS."];
    <|"lufs" -> lufs, "peakDB" -> peak|>
  ];

(* STEMTimingLine
   One sentence giving the structure of a WAV, the same wording as
   dynamical's Timing line, with every part stated even when it is zero:
     "  Timing: the WAV holds 0 s of spoken intro and a 0 s pause, then
      20 s of notes from 0 s, then a 0 s pause and 0 s of spoken outro,
      20 s in total."
   t holds "intro" (speech), "introPause", "notes", "outroPause" and
   "outro" (speech), all in seconds; missing keys count as 0. The total
   is their sum. Returns the total. *)
STEMTimingLine[t_Association] :=
  Module[{g, total},
    g[k_] := N @ Lookup[t, k, 0.0];
    total = g["intro"] + g["introPause"] + g["notes"] + g["outroPause"] + g["outro"];
    Print["  Timing: the WAV holds ", FmtDec[g["intro"], 2], " s of spoken intro and a ",
          FmtDec[g["introPause"], 2], " s pause, then ", FmtDec[g["notes"], 2],
          " s of notes from ", FmtDec[g["intro"] + g["introPause"], 2], " s, then a ",
          FmtDec[g["outroPause"], 2], " s pause and ", FmtDec[g["outro"], 2],
          " s of spoken outro, ", FmtDec[total, 2], " s in total."];
    total
  ];


(* ── 4. Speech integration (optional) ───────────────────── *)

(* $STEMSpeakEnabled
   Read from the STEM_SPEAK environment variable at load time.
   Set STEM_SPEAK=1 to enable TTS alongside normal Print output.
   Platform support:
     macOS   — built-in `say` command
     Linux   — espeak-ng (preferred) or espeak; skips gracefully if absent
     Windows — PowerShell System.Speech.Synthesis.SpeechSynthesizer *)

$STEMSpeakEnabled = Environment["STEM_SPEAK"] === "1"

(* One-time warning flag so the "TTS not found" message prints only once. *)
$STEMSayWarned = False;


(* STEMSay
   Prints text as a single stdout line.
   When $STEMSpeakEnabled is True, also speaks text via a platform-
   appropriate TTS engine.  Falls back silently on any error. *)

STEMSay[text_String] :=
  (Print[text];
   If[$STEMSpeakEnabled,
     Switch[$OperatingSystem,

       "MacOSX",
         Quiet[RunProcess[{"/usr/bin/say", text}]],

       "Unix",
         Module[{r},
           (* Try espeak-ng first, then espeak *)
           r = Quiet[RunProcess[{"espeak-ng", text}]];
           If[!AssociationQ[r] || r["ExitCode"] =!= 0,
             r = Quiet[RunProcess[{"espeak", text}]]];
           If[(!AssociationQ[r] || r["ExitCode"] =!= 0) && !$STEMSayWarned,
             $STEMSayWarned = True;
             Print["[WARNING] STEM_SPEAK=1 but neither espeak-ng nor espeak found. " <>
                   "Install with: sudo apt install espeak-ng"]]],

       "Windows",
         (* Use PowerShell System.Speech — built into Windows 10/11 *)
         Quiet[RunProcess[{"powershell", "-NoProfile", "-Command",
           "Add-Type -AssemblyName System.Speech; " <>
           "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; " <>
           "$s.Speak('" <> StringReplace[text, "'" -> "''"] <> "')"}]],

       _,
         If[!$STEMSayWarned,
           $STEMSayWarned = True;
           Print["[WARNING] STEM_SPEAK=1 but platform \"",
                 $OperatingSystem, "\" has no TTS configured"]]
     ]
   ])


(* ── 5. Audio playback ───────────────────────────────────── *)

(* STEMPlayCmd
   Returns the platform-appropriate terminal command string to play a WAV
   file.  Used in completion messages so users know how to play the output.

   macOS   → "afplay <file>"
   Linux   → "aplay <file>"
   Windows → "(New-Object Media.SoundPlayer \"<file>\").PlaySync()" (PowerShell;
             plays the WAV in the terminal and waits; filePath is absolute)
   Audio plays only in an interactive desktop session, not over SSH. *)

STEMPlayCmd[filePath_String, os_String : $OperatingSystem] :=
  Switch[os,
    "MacOSX",  "afplay " <> filePath,
    "Unix",    "aplay "  <> filePath,
    "Windows", "(New-Object Media.SoundPlayer \"" <> filePath <> "\").PlaySync()",
    _,         "afplay " <> filePath
  ]


(* STEMPlay
   Plays a WAV file using the platform's audio command.
   Blocks on macOS (afplay) and Windows (SoundPlayer.PlaySync);
   on Linux aplay also blocks. Skips silently on unrecognised platforms. *)

STEMPlay[filePath_String] :=
  Switch[$OperatingSystem,
    "MacOSX",
      Quiet[RunProcess[{"afplay", filePath}]],
    "Unix",
      Quiet[RunProcess[{"aplay", filePath}]],
    "Windows",
      Quiet[RunProcess[{"powershell", "-NoProfile", "-Command",
        "(New-Object Media.SoundPlayer '" <>
        StringReplace[filePath, "\\" -> "/"] <>
        "').PlaySync()"}]],
    _,
      Print["[WARNING] STEMPlay: platform \"", $OperatingSystem,
            "\" not recognised; could not play ", filePath]
  ]

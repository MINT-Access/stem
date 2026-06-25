(* ========================================================
   stem-core/src/accessibility.wl — Screen-reader-friendly output

   All public functions (STEM prefix) print a single complete
   line to stdout so VoiceOver reads each chunk as one unit.

   Requires: utils.wl (for FmtN)

   Sections:
     1. Numeric formatting     — STEMPrintN
     2. Structured announcements — STEMHeading, STEMSection, STEMBullet
     3. Export metadata        — STEMDescribeCSV, STEMDescribeWAV, STEMDescribeGIF
     4. Speech integration     — $STEMSpeakEnabled, STEMSay
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
   nFrames is the total frame count; fps is the playback rate. *)

STEMDescribeGIF[filePath_String] :=
  Print["  Animation: ", filePath]

STEMDescribeGIF[filePath_String, nFrames_Integer, fps_?NumericQ] :=
  Print["  Animation: ", nFrames, " frames at ", fps, " fps — ", filePath]


(* ── 4. Speech integration (optional, macOS only) ─────────── *)

(* $STEMSpeakEnabled
   Set to True before loading this file (or any time after) to enable
   the macOS `say` command alongside normal Print output.
   Default False so the flag is always defined, but speech is strictly opt-in. *)

If[!ValueQ[$STEMSpeakEnabled], $STEMSpeakEnabled = False]


(* STEMSay
   Prints text as a single stdout line.
   When $STEMSpeakEnabled is True, also passes text to the macOS `say`
   command so it is spoken aloud through the system voice.
   RunProcess blocks until speech completes and avoids shell quoting issues. *)

STEMSay[text_String] :=
  (Print[text];
   If[$STEMSpeakEnabled,
     RunProcess[{"/usr/bin/say", text}]])

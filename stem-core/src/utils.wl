(* ========================================================
   stem-core/src/utils.wl — Shared filesystem utilities
   ======================================================== *)


(* EnsureDir
   Creates the parent directory of filePath if it does not exist.
   Safe to call when the directory already exists. *)

EnsureDir[filePath_String] :=
  If[!DirectoryQ[DirectoryName[filePath]],
    CreateDirectory[DirectoryName[filePath]]]


(* FmtN
   Formats x as a single-line string for use in Print statements.
   spec can be n (sig figs) or {total, decimals} — same as NumberForm.
   Use this instead of ToString[NumberForm[x,spec], OutputForm]: in
   headless wolframscript, OutputForm renders scientific notation as
   multi-line superscripts; this helper produces inline *^ notation
   instead (e.g. 3.498*^-7). *)

FmtN[x_?NumericQ, spec_:4] :=
  ToString[
    NumberForm[x, spec, NumberFormat -> (If[#3 == "", #1, #1 <> "*^" <> #3]&)],
    OutputForm]


(* FmtDec
   Formats x with at most maxDecimals decimal places, dropping trailing
   zeros (4.6078 -> "4.608", 0.22 -> "0.22", 2. -> "2"). Used for frame
   rates, frame delays and durations in console lines, where FmtN's
   significant-figure spec either truncates long durations ("344.")
   or prints noise digits for short ones. *)

FmtDec[x_?NumericQ, maxDecimals_Integer:3] :=
  Module[{scaled, intPart, fracPart, fracStr},
    scaled   = Round[Abs[x] * 10^maxDecimals];
    intPart  = Quotient[scaled, 10^maxDecimals];
    fracPart = Mod[scaled, 10^maxDecimals];
    fracStr  = If[fracPart == 0, "",
      "." <> StringReplace[IntegerString[fracPart, 10, maxDecimals],
                           "0" .. ~~ EndOfString -> ""]];
    If[x < 0 && scaled != 0, "-", ""] <> IntegerString[intPart] <> fracStr
  ]


(* LogError
   Appends a timestamped error line to a log file.
     message — human-readable description of the error
     logPath — destination log file (directory is created if needed) *)

LogError[message_String, logPath_String] :=
  Module[{stream, ts},
    ts = DateString[{"Year", "-", "Month", "-", "Day", " ",
                     "Hour", ":", "Minute", ":", "Second"}];
    EnsureDir[logPath];
    stream = OpenAppend[logPath];
    WriteString[stream, "[ERROR] " <> ts <> " " <> message <> "\n"];
    Close[stream]
  ]

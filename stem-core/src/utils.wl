(* ========================================================
   stem-core/src/utils.wl — Shared filesystem utilities
   ======================================================== *)


(* EnsureDir
   Creates the parent directory of filePath if it does not exist.
   Safe to call when the directory already exists. *)

EnsureDir[filePath_String] :=
  If[!DirectoryQ[DirectoryName[filePath]],
    CreateDirectory[DirectoryName[filePath]]]


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

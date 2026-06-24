(* ========================================================
   stem-core/src/export.wl — CSV and GIF file export helpers

   Requires: utils.wl (for EnsureDir)
   ======================================================== *)


(* ExportCSV
   Writes a list of rows (including header) to a CSV file.
   Creates the output directory if it does not exist.
   Returns filePath on success.

   rows     — list of lists, first element is the header row
   filePath — destination path, e.g. "data/results.csv" *)

ExportCSV[rows_List, filePath_String] :=
  (EnsureDir[filePath];
   Export[filePath, rows, "CSV"];
   filePath)


(* ExportGIF
   Exports a list of Graphics frames as a looping animated GIF.
   Creates the output directory if it does not exist.
   Returns filePath on success.

   frames    — list of Graphics or GraphicsGrid objects
   filePath  — destination path, e.g. "data/animation.gif"
   frameRate — playback speed in frames per second (default 25) *)

ExportGIF[frames_List, filePath_String, frameRate_:25] :=
  (EnsureDir[filePath];
   Export[filePath, frames, "GIF",
     "AnimationRepetitions" -> Infinity,
     "DisplayDurations"     -> 1.0 / frameRate];
   filePath)

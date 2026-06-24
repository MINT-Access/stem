#!/usr/bin/env wolframscript

(* ========================================================
   experiment.wl — Date range and filter experiments
   Edit the ACTIVE PRESET and run:
     wolframscript -file experiment.wl
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "fetch.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "analyse.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

(* -------------------------------------------------------
   PRESETS
   ------------------------------------------------------- *)

(* A: Last 7 days, all asteroids, minor pentatonic *)
(*
label     = "recent";
startDate = DateString[Today - Quantity[6,"Days"], "ISODate"];
endDate   = DateString[Today, "ISODate"];
filterFn  = Identity;          (* all asteroids *)
scaleName = "MinorPentatonic";
*)

(* B: Last 7 days, hazardous only — eerie Phrygian scale *)
(*
label     = "hazardous_only";
startDate = DateString[Today - Quantity[6,"Days"], "ISODate"];
endDate   = DateString[Today, "ISODate"];
filterFn  = HazardousAsteroids;
scaleName = "Phrygian";
*)

(* C: Last 7 days, large + enormous only (>=140 m) *)
(*
label     = "large_only";
startDate = DateString[Today - Quantity[6,"Days"], "ISODate"];
endDate   = DateString[Today, "ISODate"];
filterFn  = Function[a,
  Select[a, #["diamMeanKm"] >= 0.14 &]];
scaleName = "Minor";
*)

(* D: Specific historical date range — Chelyabinsk week (Feb 2013) *)
(*
label     = "chelyabinsk_week";
startDate = "2013-02-11";
endDate   = "2013-02-17";
filterFn  = Identity;
scaleName = "Phrygian";
*)

(* E: Major pentatonic — same data, brighter mood *)
(*
label     = "major_mood";
startDate = DateString[Today - Quantity[6,"Days"], "ISODate"];
endDate   = DateString[Today, "ISODate"];
filterFn  = Identity;
scaleName = "MajorPentatonic";
*)

(* -------------------------------------------------------
   ACTIVE PRESET
   ------------------------------------------------------- *)
label     = "recent";
startDate = DateString[Today - Quantity[6,"Days"], "ISODate"];
endDate   = DateString[Today, "ISODate"];
filterFn  = Identity;
scaleName = "MinorPentatonic";

(* -------------------------------------------------------
   Run
   ------------------------------------------------------- *)

Print["=== Asteroid Experiment: ", label, " ==="];
Print["  Date range: ", startDate, " to ", endDate];
Print["  Scale: ", scaleName];
Print[""];

Print["[1/4] Fetching..."];
allAsteroids = FetchAsteroids[startDate, endDate];
If[allAsteroids === $Failed, Print["Fetch failed."]; Exit[1]];

asteroids = filterFn[allAsteroids];
Print["  Total fetched: ",  Length[allAsteroids]];
Print["  After filter:  ",  Length[asteroids]];

If[Length[asteroids] == 0,
  Print["No asteroids match the filter. Exiting."];
  Exit[0]
];

Print[""];
Print["[2/4] Summary + CSV..."];
PrintSummary[asteroids, startDate, endDate];
outCSV = FileNameJoin[{$projectRoot, "data",
  "asteroids_" <> label <> ".csv"}];
ExportResults[asteroids, outCSV];
Print["  CSV: ", outCSV];

Print[""];
Print["[3/4] Animation..."];
outGIF = FileNameJoin[{$projectRoot, "data",
  "asteroids_" <> label <> ".gif"}];
ExportAnimation[asteroids, outGIF, startDate, endDate, 10];
Print["  GIF: ", outGIF];

Print[""];
Print["[4/4] Sonification..."];
outWAV = FileNameJoin[{$projectRoot, "data",
  "asteroids_" <> label <> ".wav"}];
ExportSonification[asteroids, outWAV, "Scale" -> scaleName];
Print["  WAV: ", outWAV];

Print[""];
Print["=== Done ==="];
Print["Play:  afplay ", outWAV];

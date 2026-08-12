#!/usr/bin/env wolframscript

(* ========================================================
   experiment.wl — Date range and filter experiments
   Edit the ACTIVE PRESET and run:
     wolframscript -file experiment.wl
   Override the preset's date range from the command line:
     wolframscript -file experiment.wl -- YYYY-MM-DD YYYY-MM-DD
   Any date range length is accepted; ranges longer than 7 days
   are split into multiple NeoWs requests automatically.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "fetch.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "analyse.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

(* Needed only to compute SonificationDuration for the GIF's targetDuration
   below — this script does not otherwise read config overrides. *)
cfg = LoadConfig["asteroids", {}];

(* -------------------------------------------------------
   PRESETS
   ------------------------------------------------------- *)

(* A: Last 7 days, all asteroids *)
(*
label     = "recent";
startDate = DateString[Today - Quantity[6,"Days"], "ISODate"];
endDate   = DateString[Today, "ISODate"];
filterFn  = Identity;          (* all asteroids *)
*)

(* B: Last 7 days, hazardous only *)
(*
label     = "hazardous_only";
startDate = DateString[Today - Quantity[6,"Days"], "ISODate"];
endDate   = DateString[Today, "ISODate"];
filterFn  = HazardousAsteroids;
*)

(* C: Last 7 days, large + enormous only (>=140 m) *)
(*
label     = "large_only";
startDate = DateString[Today - Quantity[6,"Days"], "ISODate"];
endDate   = DateString[Today, "ISODate"];
filterFn  = Function[a,
  Select[a, #["diamMeanKm"] >= 0.14 &]];
*)

(* D: Specific historical date range — Chelyabinsk week (Feb 2013) *)
(*
label     = "chelyabinsk_week";
startDate = "2013-02-11";
endDate   = "2013-02-17";
filterFn  = Identity;
*)

(* -------------------------------------------------------
   ACTIVE PRESET
   ------------------------------------------------------- *)
label     = "recent";
startDate = DateString[Today - Quantity[6,"Days"], "ISODate"];
endDate   = DateString[Today, "ISODate"];
filterFn  = Identity;

(* -------------------------------------------------------
   CLI overrides — take priority over the active preset.
   Drop script path and any bare "--" wolframscript may include.
   ------------------------------------------------------- *)
$cliArgs    = Select[Rest[$ScriptCommandLine], (# =!= "--") &];

Which[
  Length[$cliArgs] === 2,
    startDate = $cliArgs[[1]];
    endDate   = $cliArgs[[2]],
  Length[$cliArgs] === 0,
    Null,
  True,
    Print["Usage: wolframscript -file experiment.wl [-- YYYY-MM-DD YYYY-MM-DD]"];
    Exit[1]
];

With[{span = QuantityMagnitude[
    DateDifference[DateObject[startDate], DateObject[endDate], "Day"]]},
  If[span < 0,
    Print["Error: end date must be on or after start date."];
    Exit[1]
  ]
];

(* -------------------------------------------------------
   Run
   ------------------------------------------------------- *)

Print["=== Asteroid Experiment: ", label, " ==="];
Print["  Date range: ", startDate, " to ", endDate];
Print[""];

Print["[1/4] Fetching..."];
allAsteroids = FetchAsteroidsMulti[startDate, endDate];
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
outCSV = FileNameJoin[{$projectRoot, "output",
  "asteroids_" <> label <> ".csv"}];
ExportResults[asteroids, outCSV];
Print["  CSV: ", outCSV];

Print[""];
Print["[3/4] Animation..."];
outGIF = FileNameJoin[{$projectRoot, "output",
  "asteroids_" <> label <> ".gif"}];
trajDurationForGIF = SonificationDuration[Length[asteroids], cfg];
ExportAnimation[asteroids, outGIF, startDate, endDate, trajDurationForGIF];
Print["  GIF: ", outGIF];

Print[""];
Print["[4/4] Sonification..."];
outWAV = FileNameJoin[{$projectRoot, "output",
  "asteroids_" <> label <> ".wav"}];
ExportSonification[asteroids, cfg, outWAV];
Print["  WAV: ", outWAV];

Print[""];
Print["=== Done ==="];
Print["Play:  ", STEMPlayCmd[outWAV]];

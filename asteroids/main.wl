#!/usr/bin/env wolframscript

(* ========================================================
   Near-Earth Asteroid Tracker — Entry Point
   Usage: wolframscript -file main.wl [-- YYYY-MM-DD YYYY-MM-DD]
   Without arguments fetches the last 7 days (NeoWs max per request).
   With two ISO dates fetches that range (max 7 days).
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

Get[FileNameJoin[{$projectRoot, "src", "fetch.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "analyse.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

(* Date range: CLI args take priority, otherwise default to last 7 days.
   Drop script path and any bare "--" that wolframscript may include. *)
$cliDates = Select[Rest[$ScriptCommandLine], (# =!= "--") &];
Which[
  Length[$cliDates] === 2,
    startDate = $cliDates[[1]];
    endDate   = $cliDates[[2]],
  Length[$cliDates] === 0,
    endDate   = DateString[Today, "ISODate"];
    startDate = DateString[Today - Quantity[6, "Days"], "ISODate"],
  True,
    Print["Usage: wolframscript -file main.wl [-- YYYY-MM-DD YYYY-MM-DD]"];
    Exit[1]
];

(* Guard: NeoWs rejects ranges longer than 7 days *)
With[{span = QuantityMagnitude[
    DateDifference[DateObject[startDate], DateObject[endDate], "Day"]]},
  If[span < 0 || span > 7,
    Print["Error: date range must be 1-7 days (got ", span, " days)."];
    Exit[1]
  ]
];

STEMHeading["Near-Earth Asteroid Tracker"];
Print["  Date range: ", startDate, " to ", endDate];
Print[""];

(* 1. Fetch *)
Print["[1/4] Fetching data from NASA NeoWs API..."];
asteroids = FetchAsteroids[startDate, endDate];

If[asteroids === $Failed,
  Print["Aborting — could not fetch data."];
  Exit[1]
];
Print["  Retrieved ", Length[asteroids], " asteroids."];

(* 2. Analyse + CSV *)
Print[""];
Print["[2/4] Analysing and exporting CSV..."];
PrintSummary[asteroids, startDate, endDate];
outCSV = FileNameJoin[{$projectRoot, "data",
  "asteroids_" <> startDate <> "_" <> endDate <> ".csv"}];
ExportResults[asteroids, outCSV];
STEMDescribeCSV[outCSV, Length[asteroids], 12];

(* 3. Animation *)
Print[""];
Print["[3/4] Rendering solar system animation..."];
outGIF = FileNameJoin[{$projectRoot, "data",
  "asteroids_" <> startDate <> "_" <> endDate <> ".gif"}];
ExportAnimation[asteroids, outGIF, startDate, endDate, 10];
STEMDescribeGIF[outGIF, Length[asteroids] + 30, 10];

(* 4. Sonification *)
Print[""];
Print["[4/4] Synthesising audio..."];
outWAV = FileNameJoin[{$projectRoot, "data",
  "asteroids_" <> startDate <> "_" <> endDate <> ".wav"}];
ExportSonification[asteroids, outWAV,
  "Scale" -> "MinorPentatonic"];
STEMDescribeWAV[outWAV];

Print[""];
STEMHeading["Done"];
STEMSay["Play audio:  afplay " <> outWAV];

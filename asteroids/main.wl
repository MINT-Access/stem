#!/usr/bin/env wolframscript

(* ========================================================
   Near-Earth Asteroid Tracker — Entry Point
   Usage: wolframscript -file main.wl
   Fetches the last 7 days of asteroid data from NASA NeoWs.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

Get[FileNameJoin[{$projectRoot, "src", "fetch.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "analyse.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

(* Date range: last 7 days (NeoWs maximum per request) *)
endDate   = DateString[Today, "ISODate"];
startDate = DateString[Today - Quantity[6, "Days"], "ISODate"];

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

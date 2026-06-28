#!/usr/bin/env wolframscript

(* ========================================================
   Near-Earth Asteroid Tracker — Entry Point
   Usage: wolframscript -file main.wl [-- YYYY-MM-DD YYYY-MM-DD [Scale]]
          wolframscript -file main.wl -- --config-dump
          wolframscript -file main.wl -- 2026-01-01 2026-12-31 --simulation.days_ahead=14
   Without date arguments fetches the last days_ahead days (config default: 7).
   Optional Scale argument and --key=value config overrides may be combined.
   Note: --key value (space) also accepted in addition to --key=value.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

Get[FileNameJoin[{$projectRoot, "src", "fetch.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "analyse.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

(* Pre-process CLI args: convert "--key value" pairs to "--key=value"
   so both conventions work (ParseCliOverrides in stem-core requires =).
   Strip --no-orbital-elements first so it is never treated as a key. *)
$rawArgs           = Select[Rest[$ScriptCommandLine], # =!= "--" &];
$noOrbitalElements = MemberQ[$rawArgs, "--no-orbital-elements"];
$rawArgs           = Select[$rawArgs, # =!= "--no-orbital-elements" &];
$cliArgs           = Module[{result = {}, i = 1, arg, next},
  While[i <= Length[$rawArgs],
    arg = $rawArgs[[i]];
    If[StringStartsQ[arg, "--"] && !StringContainsQ[arg, "="] &&
       arg =!= "--config-dump" &&
       i < Length[$rawArgs] &&
       !StringStartsQ[$rawArgs[[i + 1]], "--"],
      next = $rawArgs[[i + 1]];
      AppendTo[result, arg <> "=" <> next];
      i += 2,
      AppendTo[result, arg];
      i++
    ]
  ];
  result
];

(* --- Load config (exits here if --config-dump is present) --- *)
cfg               = LoadConfig["asteroids", $cliArgs];

(* --- Positional args separated from --key=value flags --- *)
$posArgs     = Select[$cliArgs, !StringStartsQ[#, "--"] &];
$validScales = {"MinorPentatonic", "MajorPentatonic", "Major", "Minor",
                "WholeTone", "Phrygian"};

Which[
  Length[$posArgs] >= 3,
    startDate = $posArgs[[1]];
    endDate   = $posArgs[[2]];
    scaleName = $posArgs[[3]],
  Length[$posArgs] === 2,
    startDate = $posArgs[[1]];
    endDate   = $posArgs[[2]];
    scaleName = GetCfg[cfg, {"sonification","scale"}, "MinorPentatonic"],
  Length[$posArgs] === 0,
    endDate   = DateString[Today, "ISODate"];
    startDate = DateString[
      Today - Quantity[GetCfg[cfg, {"simulation","days_ahead"}, 7] - 1, "Days"],
      "ISODate"];
    scaleName = GetCfg[cfg, {"sonification","scale"}, "MinorPentatonic"],
  True,
    Print["Usage: wolframscript -file main.wl [-- YYYY-MM-DD YYYY-MM-DD [Scale]]"];
    Print["Scales: ", StringRiffle[$validScales, "  "]];
    Exit[1]
];

If[!MemberQ[$validScales, scaleName],
  Print["Error: unknown scale \"", scaleName, "\". Valid: ",
        StringRiffle[$validScales, "  "]];
  Exit[1]
];

With[{span = QuantityMagnitude[
    DateDifference[DateObject[startDate], DateObject[endDate], "Day"]]},
  If[span < 0,
    Print["Error: end date must be on or after start date."];
    Exit[1]
  ]
];

STEMHeading["Near-Earth Asteroid Tracker"];
Print["  Date range: ", startDate, " to ", endDate];
Print["  Scale:      ", scaleName];
Print[""];

(* 1. Fetch *)
Print["[1/4] Fetching data from NASA NeoWs API..."];
STEMSay["Fetching asteroid data from NASA"];
asteroids = FetchAsteroidsMulti[startDate, endDate];

If[asteroids === $Failed,
  Print["Aborting — could not fetch data."];
  Exit[1]
];
Print["  Retrieved ", Length[asteroids], " asteroids."];

(* 1b. Orbital elements from JPL SBDB — skipped with --no-orbital-elements *)
If[!$noOrbitalElements,
  Print[""];
  asteroids = FetchAllOrbitalElements[asteroids],
  Print["  Orbital elements: skipped (--no-orbital-elements)."]
];
asteroids = AugmentAsteroidsWithAngles[asteroids];

(* 2. Analyse + CSV *)
Print[""];
Print["[2/4] Analysing and exporting CSV..."];
STEMSay["Analysing trajectory data"];
PrintSummary[asteroids, startDate, endDate];
outCSV = FileNameJoin[{$projectRoot, "output",
  "asteroids_" <> startDate <> "_" <> endDate <> ".csv"}];
ExportResults[asteroids, outCSV];
STEMDescribeCSV[outCSV, Length[asteroids], 17];

(* 3. Animation *)
Print[""];
Print["[3/4] Rendering solar system animation..."];
STEMSay["Rendering solar system animation"];
outGIF = FileNameJoin[{$projectRoot, "output",
  "asteroids_" <> startDate <> "_" <> endDate <> ".gif"}];
ExportAnimation[asteroids, outGIF, startDate, endDate, 10];
STEMDescribeGIF[outGIF, Length[asteroids] + 30, 10];

(* 4. Sonification *)
Print[""];
Print["[4/4] Synthesising audio..."];
STEMSay["Synthesising audio"];
outWAV = FileNameJoin[{$projectRoot, "output",
  "asteroids_" <> startDate <> "_" <> endDate <> ".wav"}];
trajDuration = ExportSonification[asteroids, cfg, outWAV];
STEMDescribeWAV[outWAV, trajDuration];

Print[""];
STEMHeading["Done"];
STEMSay["Complete. Play audio: afplay " <> outWAV];

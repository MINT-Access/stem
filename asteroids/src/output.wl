(* ========================================================
   src/output.wl — CSV export and console summary
   ======================================================== *)


(* ExportResults
   Writes one row per asteroid to a CSV file. *)

ExportResults[asteroids_List, filePath_String] :=
  Module[{header, rows, allRows},

    header = {{
      "id", "name", "approachDate",
      "missDistanceKm", "missDistanceLunarD",
      "velocityKmS", "diamMinKm", "diamMaxKm", "diamMeanKm",
      "isHazardous", "absoluteMag", "sizeClass"
    }};

    rows = {
      #["id"],
      #["name"],
      #["approachDate"],
      ToString[NumberForm[#["missDistanceKm"],    {10, 1}], OutputForm],
      ToString[NumberForm[ToLunarDistances[#["missDistanceKm"]], {6, 3}], OutputForm],
      ToString[NumberForm[#["velocityKmS"],       {6, 3}],  OutputForm],
      ToString[NumberForm[#["diamMinKm"],         {6, 4}],  OutputForm],
      ToString[NumberForm[#["diamMaxKm"],         {6, 4}],  OutputForm],
      ToString[NumberForm[#["diamMeanKm"],        {6, 4}],  OutputForm],
      If[#["isHazardous"], "yes", "no"],
      ToString[NumberForm[#["absoluteMag"],       {5, 2}],  OutputForm],
      SizeClass[#["diamMeanKm"]]
    } & /@ asteroids;

    allRows = Join[header, rows];

    ExportCSV[allRows, filePath]
  ]


(* PrintSummary — structured console report, VoiceOver-friendly *)

PrintSummary[asteroids_List, startDate_String, endDate_String] :=
  Module[{hazardous, distStats, velStats, sizeDist},

    hazardous = HazardousAsteroids[asteroids];
    distStats  = MissDistanceStats[asteroids];
    velStats   = VelocityStats[asteroids];
    sizeDist   = SizeDistribution[asteroids];

    Print[""];
    Print["=== Near-Earth Asteroid Report: ",
          startDate, " to ", endDate, " ==="];
    Print[""];
    STEMPrintN["Total asteroids tracked", distStats["count"]];
    STEMPrintN["Potentially hazardous",  Length[hazardous]];
    Print[""];
    Print["-- Miss Distance --"];
    Print["  Closest:  ",
      IntegerString[Round[distStats["minKm"]]], " km  (",
      FmtN[ToLunarDistances[distStats["minKm"]], {5,2}], " LD)"];
    Print["  Farthest: ",
      IntegerString[Round[distStats["maxKm"]]], " km  (",
      FmtN[ToLunarDistances[distStats["maxKm"]], {5,2}], " LD)"];
    Print["  Mean:     ",
      IntegerString[Round[distStats["meanKm"]]], " km"];
    Print[""];
    Print["-- Velocity --"];
    STEMPrintN["Min velocity",  velStats["minKmS"],  "km/s", 4];
    STEMPrintN["Max velocity",  velStats["maxKmS"],  "km/s", 4];
    STEMPrintN["Mean velocity", velStats["meanKmS"], "km/s", 4];
    Print[""];
    Print["-- Size Distribution --"];
    KeyValueMap[
      Print["  ", #1, ": ", #2] &,
      sizeDist
    ];
    Print[""];
    Print["-- Closest Approach --"];
    Print["  ", ClosestApproachSummary[First[asteroids]]];
    If[Length[hazardous] > 0,
      Print[""];
      Print["-- Potentially Hazardous Asteroids --"];
      Scan[
        Print["  ", #["name"], "  dist=",
          IntegerString[Round[#["missDistanceKm"]]], " km  vel=",
          FmtN[#["velocityKmS"], {5,2}], " km/s"] &,
        hazardous
      ]
    ];
    Print[""];
  ]

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
      "isHazardous", "absoluteMag", "sizeClass",
      "semi_major_axis_au", "eccentricity", "inclination_deg",
      "orbital_period_days", "geocentric_angle_deg"
    }};

    rows = Function[ast,
      Module[{el, hasEl, ang},
        el    = Lookup[ast, "orbital_elements", $Failed];
        hasEl = AssociationQ[el];
        ang   = Lookup[ast, "geocentricAngle", $Failed];
        {
          ast["id"],
          ast["name"],
          ast["approachDate"],
          ToString[NumberForm[ast["missDistanceKm"],    {10, 1}], OutputForm],
          ToString[NumberForm[ToLunarDistances[ast["missDistanceKm"]], {6, 3}], OutputForm],
          ToString[NumberForm[ast["velocityKmS"],       {6, 3}],  OutputForm],
          ToString[NumberForm[ast["diamMinKm"],         {6, 4}],  OutputForm],
          ToString[NumberForm[ast["diamMaxKm"],         {6, 4}],  OutputForm],
          ToString[NumberForm[ast["diamMeanKm"],        {6, 4}],  OutputForm],
          If[ast["isHazardous"], "yes", "no"],
          ToString[NumberForm[ast["absoluteMag"],       {5, 2}],  OutputForm],
          SizeClass[ast["diamMeanKm"]],
          If[hasEl, ToString[NumberForm[Lookup[el,"a",  0], {6, 4}], OutputForm], ""],
          If[hasEl, ToString[NumberForm[Lookup[el,"e",  0], {6, 4}], OutputForm], ""],
          If[hasEl, ToString[NumberForm[Lookup[el,"i",  0], {6, 3}], OutputForm], ""],
          If[hasEl, ToString[NumberForm[Lookup[el,"per",0], {8, 2}], OutputForm], ""],
          If[NumericQ[ang],
            ToString[NumberForm[ang / Degree, {6, 2}], OutputForm],
            ""]
        }
      ]
    ] /@ asteroids;

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
    STEMHeading["Near-Earth Asteroid Report: " <> startDate <> " to " <> endDate];
    Print[""];
    STEMPrintN["Total asteroids tracked", distStats["count"]];
    STEMPrintN["Potentially hazardous",  Length[hazardous]];
    Print[""];
    STEMSection["Miss Distance"];
    Print["  Closest:  ",
      IntegerString[Round[distStats["minKm"]]], " km  (",
      FmtN[ToLunarDistances[distStats["minKm"]], {5,2}], " LD)"];
    Print["  Farthest: ",
      IntegerString[Round[distStats["maxKm"]]], " km  (",
      FmtN[ToLunarDistances[distStats["maxKm"]], {5,2}], " LD)"];
    Print["  Mean:     ",
      IntegerString[Round[distStats["meanKm"]]], " km"];
    Print[""];
    STEMSection["Velocity"];
    STEMPrintN["Min velocity",  velStats["minKmS"],  "km/s", 4];
    STEMPrintN["Max velocity",  velStats["maxKmS"],  "km/s", 4];
    STEMPrintN["Mean velocity", velStats["meanKmS"], "km/s", 4];
    Print[""];
    STEMSection["Size Distribution"];
    KeyValueMap[
      Print["  ", #1, ": ", #2] &,
      sizeDist
    ];
    Print[""];
    STEMSection["Closest Approach"];
    Print["  ", ClosestApproachSummary[First[asteroids]]];
    If[Length[hazardous] > 0,
      Print[""];
      STEMSection["Potentially Hazardous Asteroids"];
      Scan[
        Print["  ", #["name"], "  dist=",
          IntegerString[Round[#["missDistanceKm"]]], " km  vel=",
          FmtN[#["velocityKmS"], {5,2}], " km/s"] &,
        hazardous
      ]
    ];
    Print[""];
  ]

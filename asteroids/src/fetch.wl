(* ========================================================
   src/fetch.wl — Fetch and parse NASA NeoWs API data

   NASA Near Earth Object Web Service (NeoWs)
   Public endpoint — no API key required for demo key.
   Rate limit: 30 requests/hour with DEMO_KEY.
   Get a free personal key at: https://api.nasa.gov

   Main function:
     FetchAsteroids[startDate, endDate]
     e.g. FetchAsteroids["2026-06-16", "2026-06-23"]
     Returns a list of Associations, one per asteroid.
   ======================================================== *)

FetchError[msg_String] :=
  WriteString[$stderr, "[ERROR] " <> msg <> "\n"];


If[!ValueQ[$NasaApiKey],
  With[{envKey = Environment["NASA_API_KEY"]},
    $NasaApiKey = If[StringQ[envKey] && envKey =!= "", envKey, "DEMO_KEY"]
  ]
];

$NeoWsBaseUrl = "https://api.nasa.gov/neo/rest/v1/feed";


(* FetchRawJson
   Fetches the raw JSON string from the NeoWs API for a date range.
   NeoWs allows at most 7 days per request. *)

FetchRawJson[startDate_String, endDate_String] :=
  Module[{url, response},
    url = $NeoWsBaseUrl <>
      "?start_date=" <> startDate <>
      "&end_date="   <> endDate <>
      "&api_key="    <> $NasaApiKey;

    Print["  Fetching: ", url];
    With[{res = RunProcess[{"curl", "-s", "--max-time", "30", url}]},
      response = If[res["ExitCode"] === 0, res["StandardOutput"], $Failed]
    ];

    If[response === $Failed || StringLength[response] < 10,
      FetchError["Could not reach NASA API. Check your internet connection."];
      Return[$Failed]
    ];
    response
  ]


(* ParseAsteroid
   Extracts fields from one asteroid's JSON Association
   into a flat, typed Wolfram Association. *)

ParseAsteroid[raw_Association, approachDate_String] :=
  Module[{approach, diam},

    (* Take the first close-approach entry (closest to our date) *)
    approach = If[Length[raw["close_approach_data"]] > 0,
      raw["close_approach_data"][[1]],
      <| "miss_distance" -> <|"kilometers" -> "0"|>,
         "relative_velocity" -> <|"kilometers_per_second" -> "0"|>,
         "close_approach_date" -> approachDate |>
    ];

    (* Diameter: average of min and max estimate in km *)
    diam = raw["estimated_diameter"]["kilometers"];

    <|
      "id"              -> raw["id"],
      "name"            -> raw["name"],
      "approachDate"    -> approach["close_approach_date"],
      "missDistanceKm"  -> ToExpression[
                             approach["miss_distance"]["kilometers"]],
      "velocityKmS"     -> ToExpression[
                             approach["relative_velocity"]["kilometers_per_second"]],
      "diamMinKm"       -> diam["estimated_diameter_min"],
      "diamMaxKm"       -> diam["estimated_diameter_max"],
      "diamMeanKm"      -> Mean[{diam["estimated_diameter_min"],
                                  diam["estimated_diameter_max"]}],
      "isHazardous"     -> TrueQ[raw["is_potentially_hazardous_asteroid"]],
      "absoluteMag"     -> raw["absolute_magnitude_h"]
    |>
  ]


(* ChunkDateRange
   Splits [startDate, endDate] into consecutive windows of at most maxDays
   days (default 7, the NeoWs per-request limit).
   Returns a List of {startStr, endStr} string pairs. *)

ChunkDateRange[startDate_String, endDate_String, maxDays_Integer : 7] :=
  Module[{start, end, chunks, s, e, remaining},
    start  = DateObject[startDate];
    end    = DateObject[endDate];
    chunks = {};
    s      = start;
    While[True,
      remaining = QuantityMagnitude[DateDifference[s, end, "Day"]];
      If[remaining < 0, Break[]];
      e = If[remaining > maxDays - 1, s + Quantity[maxDays - 1, "Days"], end];
      AppendTo[chunks, {DateString[s, "ISODate"], DateString[e, "ISODate"]}];
      s = e + Quantity[1, "Days"]
    ];
    chunks
  ]


(* FetchAsteroidsMulti
   Fetches any date range by splitting it into ≤7-day chunks, calling
   FetchAsteroids for each, and merging the results.
   Returns a sorted list of asteroid Associations (closest first),
   or $Failed if any chunk fails. *)

FetchAsteroidsMulti[startDate_String, endDate_String] :=
  Module[{chunks, allAsteroids, batch},
    chunks = ChunkDateRange[startDate, endDate];
    If[Length[chunks] > 1,
      Print["  Splitting into ", Length[chunks],
            " requests (NeoWs limit: 7 days per request)..."]
    ];
    Catch[
      allAsteroids = {};
      Do[
        batch = FetchAsteroids[chunk[[1]], chunk[[2]]];
        If[batch === $Failed, Throw[$Failed]];
        allAsteroids = Join[allAsteroids, batch],
        {chunk, chunks}
      ];
      SortBy[allAsteroids, #["missDistanceKm"] &]
    ]
  ]


(* FetchAsteroids
   High-level entry point for a single ≤7-day window.
   Returns a sorted list of asteroid Associations (closest first).
   Use FetchAsteroidsMulti for ranges longer than 7 days. *)

FetchAsteroids[startDate_String, endDate_String] :=
  Module[{raw, json, dateGroups, allAsteroids, toAssoc},

    raw = FetchRawJson[startDate, endDate];
    If[raw === $Failed, Return[$Failed]];

    json = ConfigToAssoc[ImportString[raw, "JSON"]];
    dateGroups = json["near_earth_objects"];

    (* Flatten all dates into one list *)
    allAsteroids = Flatten[
      KeyValueMap[
        Function[{date, asteroids},
          ParseAsteroid[#, date] & /@ asteroids
        ],
        dateGroups
      ],
      1
    ];

    (* Sort by miss distance, closest first *)
    SortBy[allAsteroids, #["missDistanceKm"] &]
  ]


(* ========================================================
   Orbital element fetching — JPL Small Body Database (SBDB) API
   No API key required; rate-limited to 1 req/0.5 s.
   ======================================================== *)

$SBDBBaseUrl = "https://ssd-api.jpl.nasa.gov/sbdb.api";

If[!ValueQ[$OrbitalElementsCache], $OrbitalElementsCache = <||>];


(* ParseSBDBValue — convert a SBDB JSON string value to a machine real.
   The SBDB API returns values like ".576..." (no leading zero); ToExpression
   requires a leading zero, so we prepend "0" when the string starts with ".". *)

ParseSBDBValue[s_String] :=
  Module[{norm, v},
    norm = If[StringStartsQ[s, "."], "0" <> s,
            If[StringStartsQ[s, "-."], "-0" <> StringDrop[s, 1], s]];
    v = Quiet[N @ ToExpression[norm]];
    If[NumericQ[v], v, $Failed]
  ]
ParseSBDBValue[x_?NumericQ] := N[x]
ParseSBDBValue[_] := $Failed


(* FetchOrbitalElements
   Fetches Keplerian elements from the JPL SBDB API for one asteroid.
   spkid: SPK-ID string from the NeoWs "id" field.
   Returns <| "e","a","i","om","w","ma","per","epoch_jd"[,"tp"] |>
   or $Failed if the object is absent from the database or the request fails.
   Results are cached by SPK-ID to avoid duplicate requests within a session. *)

FetchOrbitalElements[spkid_String, name_String] :=
  Module[{url, res, response, json, orbitObj, elems, elemAssoc,
          e, a, i, om, w, ma, tp, per, epochJD, result},

    If[KeyExistsQ[$OrbitalElementsCache, spkid],
      Return[$OrbitalElementsCache[spkid]]
    ];

    Pause[0.5];

    url = $SBDBBaseUrl <> "?des=" <> spkid <> "&full-prec=true";
    Print["  Fetching orbital elements for ", name, " (", spkid, ")..."];

    With[{r = RunProcess[{"curl", "-s", "--max-time", "30", url}]},
      response = If[r["ExitCode"] === 0, r["StandardOutput"], $Failed]
    ];

    If[response === $Failed || StringLength[response] < 10,
      $OrbitalElementsCache[spkid] = $Failed;
      Return[$Failed]
    ];

    json = Quiet @ ConfigToAssoc[ImportString[response, "JSON"]];

    If[!AssociationQ[json] || !KeyExistsQ[json, "orbit"],
      $OrbitalElementsCache[spkid] = $Failed;
      Return[$Failed]
    ];

    orbitObj = json["orbit"];

    If[!AssociationQ[orbitObj] || !KeyExistsQ[orbitObj, "elements"],
      $OrbitalElementsCache[spkid] = $Failed;
      Return[$Failed]
    ];

    elems   = orbitObj["elements"];
    epochJD = ParseSBDBValue[orbitObj["epoch"]];

    If[!NumericQ[epochJD],
      $OrbitalElementsCache[spkid] = $Failed;
      Return[$Failed]
    ];

    elemAssoc = Association[
      If[AssociationQ[#] && KeyExistsQ[#, "label"] && KeyExistsQ[#, "value"],
        #["label"] -> ParseSBDBValue[#["value"]],
        Nothing
      ] & /@ elems
    ];

    (* SBDB uses "node" (Ω), "peri" (ω), "M" (mean anomaly), "period" *)
    {e, a, i, om, w, ma, tp, per} =
      Lookup[elemAssoc, {"e", "a", "i", "node", "peri", "M", "tp", "period"}, $Failed];

    If[!AllTrue[{e, a, i, om, w, ma, per}, NumericQ],
      $OrbitalElementsCache[spkid] = $Failed;
      Return[$Failed]
    ];

    result = <|
      "e"        -> e,
      "a"        -> a,
      "i"        -> i,
      "om"       -> om,
      "w"        -> w,
      "ma"       -> ma,
      "per"      -> per,
      "epoch_jd" -> epochJD
    |>;

    If[NumericQ[tp], result = Append[result, "tp" -> tp]];

    $OrbitalElementsCache[spkid] = result;
    result
  ]


(* FetchAllOrbitalElements
   Fetches orbital elements for every asteroid in the list, adding
   "orbital_elements" -> Association | $Failed to each asteroid Association. *)

FetchAllOrbitalElements[asteroids_List] :=
  Module[{n, fetched, result},
    n       = Length[asteroids];
    fetched = 0;
    Print["  Fetching orbital elements for ", n,
          " asteroids from JPL SBDB..."];

    result = Map[
      Function[ast,
        Module[{el},
          el = FetchOrbitalElements[ast["id"], ast["name"]];
          If[AssociationQ[el], fetched++];
          Append[ast, "orbital_elements" -> el]
        ]
      ],
      asteroids
    ];

    Print["  Orbital elements: ", fetched, " of ", n, " fetched successfully."];
    If[n - fetched > 0,
      Print["  ", n - fetched,
            " asteroid(s) will use seeded random angle fallback."]
    ];
    result
  ]

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

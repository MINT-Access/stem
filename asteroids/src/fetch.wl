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

(* LogError — write a one-line error to stderr.
   Distinct from stem-core's 2-arg file-based LogError. *)
LogError[msg_String] :=
  WriteString[$stderr, "[ERROR] " <> msg <> "\n"];


If[!ValueQ[$NasaApiKey], $NasaApiKey = "DEMO_KEY"];   (* override before loading, or set NASA_API_KEY env var *)

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
      LogError["Could not reach NASA API. Check your internet connection."];
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


(* FetchAsteroids
   High-level entry point. Returns a sorted list of asteroid Associations.
   Sorted by miss distance ascending (closest first). *)

FetchAsteroids[startDate_String, endDate_String] :=
  Module[{raw, json, dateGroups, allAsteroids, toAssoc},

    raw = FetchRawJson[startDate, endDate];
    If[raw === $Failed, Return[$Failed]];

    json       = ImportString[raw, "JSON"];
    (* ImportString returns nested lists-of-rules; convert in a single recursive pass *)
    toAssoc[l : {__Rule}] := Association[Map[(First[#] -> toAssoc[Last[#]]) &, l]];
    toAssoc[l_List]        := Map[toAssoc, l];
    toAssoc[x_]            := x;
    json = toAssoc[json];
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

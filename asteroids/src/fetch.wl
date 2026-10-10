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

(* FetchError — one "[ERROR] ..." line on the console. (It used to test
   StreamQ[$stderr]; StreamQ is not a function, so the If never
   evaluated and nothing was printed.) *)
FetchError[msg_String] := Print["[ERROR] " <> msg];


(* The key comes from NASA_API_KEY, with surrounding whitespace and
   quotes removed (a key pasted as "abc" or with a trailing newline
   would otherwise be sent as typed); DEMO_KEY when it is unset or
   empty. $NasaApiKeyNote is the sentence printed before the first
   request when something was trimmed. The key itself is never printed. *)
If[!ValueQ[$NasaApiKey],
  With[{envKey = Environment["NASA_API_KEY"]},
    Module[{trimmed = If[StringQ[envKey],
        StringTrim[envKey, (WhitespaceCharacter | "\"" | "'" | "\[OpenCurlyDoubleQuote]" |
          "\[CloseCurlyDoubleQuote]" | "\[OpenCurlyQuote]" | "\[CloseCurlyQuote]") ..], ""]},
      $NasaApiKey       = If[trimmed =!= "", trimmed, "DEMO_KEY"];
      $NasaApiKeySource = If[trimmed =!= "", "env", "demo"];
      $NasaApiKeyNote   = Which[
        !StringQ[envKey] || envKey === trimmed, None,
        trimmed === "",
          "NASA_API_KEY held only whitespace or quotes (" <>
          ToString[StringLength[envKey]] <> " characters), so DEMO_KEY is used instead.",
        True,
          "NASA_API_KEY had surrounding whitespace or quotes, which were removed: " <>
          ToString[StringLength[envKey]] <> " characters as set, " <>
          ToString[StringLength[trimmed]] <> " characters used."]
    ]
  ]
];
If[!ValueQ[$NasaApiKeySource], $NasaApiKeySource = If[$NasaApiKey === "DEMO_KEY", "demo", "env"]];
If[!ValueQ[$NasaApiKeyNote], $NasaApiKeyNote = None];

$NeoWsBaseUrl = "https://api.nasa.gov/neo/rest/v1/feed";


(* HideApiKey — a URL with the api_key value replaced, for printing *)
HideApiKey[s_String] :=
  StringReplace[s, "api_key=" ~~ Except["&"] .. -> "api_key=<hidden>"]

(* NasaKeyDescription — which key a request used, without the key *)
NasaKeyDescription[] :=
  If[$NasaApiKeySource === "env",
    "a key from NASA_API_KEY (" <> ToString[StringLength[$NasaApiKey]] <>
      If[StringLength[$NasaApiKey] === 1, " character)", " characters)"],
    "DEMO_KEY, because NASA_API_KEY is " <>
      If[StringQ[Environment["NASA_API_KEY"]], "empty", "not set"]]


(* FetchURLResponse
   GET a URL and return <|"status" -> HTTP code or None, "body" -> byte
   string (one character per UTF-8 byte, which is what
   ImportString[..., "JSON"] expects)|>, or $Failed when neither URLRead
   nor curl got a response. URLRead runs with $ProgressReporting = False:
   that, not Interactive -> False or blocking PrintTemporary, is what
   keeps its "Connecting... | Elapsed time" lines off the console. Only
   if URLRead gets no response at all is curl tried, with a sentence
   giving URLRead's failure message. *)

FetchURLResponse[url_String] :=
  Module[{resp, bytes, r, host, why, out, code},
    host  = Quiet[URLParse[url, "Domain"]];
    resp  = Quiet[Block[{$ProgressReporting = False},
      URLRead[HTTPRequest[url], TimeConstraint -> 30, Interactive -> False]]];
    If[Head[resp] === HTTPResponse,
      bytes = Quiet[resp["BodyByteArray"]];
      Return[<|"status" -> resp["StatusCode"],
               "body"   -> If[ByteArrayQ[bytes], FromCharacterCode[Normal[bytes]], ""]|>]];
    why = If[FailureQ[resp],
      Module[{tmpl = Quiet[resp[[2]]["MessageTemplate"]],
              pars = HideApiKey[ToString[#]] & /@ Replace[Quiet[resp[[2]]["MessageParameters"]], Except[_List] -> {}]},
        tmpl = Quiet[ReleaseHold[tmpl]];
        If[StringQ[tmpl], TemplateApply[StringTemplate[tmpl], pars], ToString[resp[[1]]]]],
      "URLRead returned " <> ToString[Head[resp]]];
    why = StringTrim[why, "."];
    Print["  URLRead got no response from ", host, " (", why,
          "), so the request is being retried with curl."];
    r = Quiet[RunProcess[{"curl", "-s", "--max-time", "30",
                          "-w", "\n%{http_code}", url}]];
    If[!AssociationQ[r] || r["ExitCode"] =!= 0, Return[$Failed]];
    out  = r["StandardOutput"];
    code = Quiet[ToExpression[Last[StringSplit[out, "\n", All]]]];
    If[!IntegerQ[code] || code === 0, Return[$Failed]];
    <|"status" -> code,
      "body"   -> StringDrop[out, -(StringLength[Last[StringSplit[out, "\n", All]]] + 1)]|>
  ]


(* FetchURLText
   The body of FetchURLResponse whatever the HTTP status, or $Failed
   when there was no response (used for the JPL SBDB requests). *)

FetchURLText[url_String] :=
  Module[{r = FetchURLResponse[url]},
    If[AssociationQ[r], r["body"], $Failed]]


(* NasaErrorText — " with error CODE (message)" from a JSON body whose
   "error" field is an object with code/message (api.nasa.gov key and
   rate-limit errors) or a string, or from NeoWs's own http_error and
   error_message fields (bad dates); "" if the body is not JSON or has
   none of these. *)

NasaErrorText[body_String] :=
  Module[{json = Quiet[ConfigToAssoc[ImportString[body, "JSON", CharacterEncoding -> "UTF8"]]], err},
    If[AssociationQ[json] && !KeyExistsQ[json, "error"] && KeyExistsQ[json, "error_message"],
      Return[" with error " <> ToString[Lookup[json, "http_error", "(no code)"]] <>
             " (" <> StringTrim[ToString[json["error_message"]], "."] <> ")"]];
    If[!AssociationQ[json] || !KeyExistsQ[json, "error"], Return[""]];
    err = json["error"];
    Which[
      AssociationQ[err],
        " with error " <> ToString[Lookup[err, "code", "(no code)"]] <>
        If[KeyExistsQ[err, "message"], " (" <> StringTrim[ToString[err["message"]], "."] <> ")", ""],
      StringQ[err], " with error \"" <> StringTrim[err, "."] <> "\"",
      True, " with error " <> ToString[err]]
  ]


(* FetchRawJson
   Fetches the raw JSON string from the NeoWs API for a date range.
   NeoWs allows at most 7 days per request. Any status other than 200
   ends the fetch with one sentence: the status, the server's error
   code and message when the body carries them, the host, and which
   key was used. *)

FetchRawJson[startDate_String, endDate_String] :=
  Module[{url, response, host},
    url = $NeoWsBaseUrl <>
      "?start_date=" <> startDate <>
      "&end_date="   <> endDate <>
      "&api_key="    <> $NasaApiKey;
    host = Quiet[URLParse[url, "Domain"]];

    If[StringQ[$NasaApiKeyNote], Print["  ", $NasaApiKeyNote]; $NasaApiKeyNote = None];
    Print["  Fetching: ", HideApiKey[url]];
    response = FetchURLResponse[url];

    If[response === $Failed,
      FetchError["The NASA NeoWs request to " <> host <> " got no response from URLRead or curl, using " <>
        NasaKeyDescription[] <> "; check the internet connection."];
      Return[$Failed]
    ];
    If[response["status"] =!= 200,
      FetchError["The NASA NeoWs request to " <> host <> " returned HTTP " <>
        ToString[response["status"]] <> NasaErrorText[response["body"]] <>
        ", using " <> NasaKeyDescription[] <> "."];
      Return[$Failed]
    ];
    response["body"]
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

    json = Quiet @ ConfigToAssoc[ImportString[raw, "JSON", CharacterEncoding -> "UTF8"]];

    (* Guard against API error responses (rate limit, bad key, etc.) *)
    If[!AssociationQ[json],
      FetchError["Could not parse API response as JSON."];
      Return[$Failed]
    ];
    If[!KeyExistsQ[json, "near_earth_objects"],
      FetchError["Unexpected API response — missing 'near_earth_objects'.\n" <>
        If[KeyExistsQ[json, "error"],
          "  API error: " <> ToString[json["error"]],
          "  Raw response (first 200 chars): " <> StringTake[raw, UpTo[200]]
        ]
      ];
      Return[$Failed]
    ];

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

    response = FetchURLText[url];

    If[response === $Failed || StringLength[response] < 10,
      $OrbitalElementsCache[spkid] = $Failed;
      Return[$Failed]
    ];

    json = Quiet @ ConfigToAssoc[ImportString[response, "JSON", CharacterEncoding -> "UTF8"]];

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

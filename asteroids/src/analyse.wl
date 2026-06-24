(* ========================================================
   src/analyse.wl — Statistical analysis of asteroid data

   All functions take the list of asteroid Associations
   returned by FetchAsteroids as input.
   ======================================================== *)


(* --- Basic filters --- *)

HazardousAsteroids[asteroids_List] :=
  Select[asteroids, #["isHazardous"] &]

SafeAsteroids[asteroids_List] :=
  Select[asteroids, !#["isHazardous"] &]

ClosestAsteroids[asteroids_List, n_Integer:5] :=
  Take[SortBy[asteroids, #["missDistanceKm"] &], Min[n, Length[asteroids]]]


(* --- Derived statistics --- *)

(* MissDistanceStats: min, max, mean, median in km *)
MissDistanceStats[asteroids_List] :=
  Module[{ds},
    ds = #["missDistanceKm"] & /@ asteroids;
    <|
      "count"    -> Length[ds],
      "minKm"    -> Min[ds],
      "maxKm"    -> Max[ds],
      "meanKm"   -> Mean[ds],
      "medianKm" -> Median[ds]
    |>
  ]


(* VelocityStats: in km/s *)
VelocityStats[asteroids_List] :=
  Module[{vs},
    vs = #["velocityKmS"] & /@ asteroids;
    <|
      "minKmS"    -> Min[vs],
      "maxKmS"    -> Max[vs],
      "meanKmS"   -> Mean[vs],
      "medianKmS" -> Median[vs]
    |>
  ]


(* SizeClass: classify by estimated mean diameter in km *)
SizeClass[dKm_?NumericQ] :=
  Which[
    dKm < 0.05,  "Small    (<50 m)",
    dKm < 0.14,  "Medium   (50-140 m)",
    dKm < 1.0,   "Large    (140 m - 1 km)",
    True,         "Enormous (>1 km)"
  ]

SizeDistribution[asteroids_List] :=
  Counts[SizeClass[#["diamMeanKm"]] & /@ asteroids]


(* LunarDistances: convert km to Lunar Distance (LD)
   1 LD = 384,400 km (mean Earth-Moon distance) *)

$LunarDistance = 384400.0;   (* km *)

ToLunarDistances[km_?NumericQ] := km / $LunarDistance


(* EarthRadii: convert km diameter to Earth radii
   1 Earth radius = 6371 km *)

$EarthRadius = 6371.0;   (* km *)

ToEarthRadii[km_?NumericQ] := km / $EarthRadius


(* ClosestApproachSummary
   Returns a human-readable string for the closest asteroid. *)

ClosestApproachSummary[asteroid_Association] :=
  StringJoin[
    "Closest: ", asteroid["name"],
    " on ",     asteroid["approachDate"],
    " at ",     IntegerString[Round[asteroid["missDistanceKm"]]],
    " km (",    ToString[NumberForm[ToLunarDistances[asteroid["missDistanceKm"]], {5,2}], OutputForm],
    " LD)",
    If[asteroid["isHazardous"], "  *** POTENTIALLY HAZARDOUS ***", ""]
  ]

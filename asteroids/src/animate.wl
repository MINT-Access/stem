(* ========================================================
   src/animate.wl — Solar system top-down view animation
   and orbital mechanics helpers for geocentric angle computation.

   Renders an animated GIF showing each asteroid's closest
   approach as a dot orbiting Earth, appearing one by one
   sorted from farthest to closest.

   Layout (top-down view, not to scale):
     - Earth at centre (blue dot)
     - Reference rings at 1 LD, 5 LD, 20 LD (1 LD ≈ Moon orbit)
     - Each asteroid: dot sized by diameter, coloured by
       hazard status (red = hazardous, cyan = safe),
       placed at its closest approach distance and a
       random angle (we only know distance, not direction)
   ======================================================== *)


(* --------------------------------------------------------
   Orbital mechanics helpers
   -------------------------------------------------------- *)

(* Earth's J2000.0 Keplerian elements — used to compute the geocentric
   position offset from Earth's own heliocentric position. *)
$EarthOrbitalElements = <|
  "a"        -> 1.00000011,
  "e"        -> 0.01671022,
  "i"        -> 0.00005,
  "om"       -> -11.26064,
  "w"        -> 102.94719,
  "ma"       -> 357.51716,
  "per"      -> 365.25636,
  "epoch_jd" -> 2451545.0
|>;


(* DateToJulianDate
   Converts "YYYY-MM-DD" to a Julian Date (noon UTC) via the standard
   proleptic Gregorian JDN formula.  No timezone handling needed because
   we only need day-level precision for the angle computation. *)

DateToJulianDate[dateStr_String] :=
  Module[{dl, y, m, d, a, b},
    dl = DateList[dateStr];
    {y, m, d} = {dl[[1]], dl[[2]], dl[[3]]};
    a = Floor[(14 - m) / 12];
    b = y + 4800 - a;
    N[d + Floor[(153*(m + 12*a - 3) + 2)/5] +
      365*b + Floor[b/4] - Floor[b/100] + Floor[b/400] - 32045]
  ]


(* SolveKepler
   Newton-Raphson solver for Kepler's equation  M = E - e sin E.
   Converges to 1e-10 in fewer than 10 iterations for e < 0.99. *)

SolveKepler[M_?NumericQ, e_?NumericQ] :=
  Module[{Mmod, E, dE},
    Mmod = Mod[N[M], 2.0*Pi];
    E    = Mmod;
    Do[
      dE = (Mmod - E + e*Sin[E]) / (1.0 - e*Cos[E]);
      E += dE;
      If[Abs[dE] < 1.0*^-10, Break[]],
      {50}
    ];
    E
  ]


(* OrbitalToEcliptic2D
   Transforms a perifocal-frame position {xOrb, yOrb} to heliocentric
   ecliptic {X, Y} using the standard three-angle rotation sequence
   (argument of perihelion ω, inclination i, longitude of ascending node Ω).
   All angle arguments are in degrees. *)

OrbitalToEcliptic2D[xOrb_?NumericQ, yOrb_?NumericQ,
                     iDeg_?NumericQ, omDeg_?NumericQ, wDeg_?NumericQ] :=
  Module[{i, om, w, ci, co, cw, si, so, sw, X, Y},
    i  = iDeg  * Degree;
    om = omDeg * Degree;
    w  = wDeg  * Degree;
    {ci, si} = {Cos[i],  Sin[i]};
    {co, so} = {Cos[om], Sin[om]};
    {cw, sw} = {Cos[w],  Sin[w]};
    X = (co*cw - so*sw*ci)*xOrb + (-co*sw - so*cw*ci)*yOrb;
    Y = (so*cw + co*sw*ci)*xOrb + (-so*sw + co*cw*ci)*yOrb;
    {X, Y}
  ]


(* KeplerPosition
   Heliocentric ecliptic {X, Y} in AU for an elements Association at
   Julian Date jd.  Uses "tp" (perihelion epoch JD) if present;
   otherwise propagates from "ma" + "epoch_jd". *)

KeplerPosition[elements_Association, jd_?NumericQ] :=
  Module[{a, e, i, om, w, per, n, M, E, xOrb, yOrb},
    a   = elements["a"];
    e   = elements["e"];
    i   = elements["i"];
    om  = elements["om"];
    w   = elements["w"];
    per = elements["per"];
    n   = 2.0*Pi / per;
    M   = If[KeyExistsQ[elements, "tp"] && NumericQ[elements["tp"]],
      Mod[n*(jd - elements["tp"]),                           2.0*Pi],
      Mod[(elements["ma"]*Degree) + n*(jd - elements["epoch_jd"]), 2.0*Pi]
    ];
    If[M < 0.0, M += 2.0*Pi];
    E    = SolveKepler[M, e];
    xOrb = a*(Cos[E] - e);
    yOrb = a*Sqrt[1.0 - e^2]*Sin[E];
    OrbitalToEcliptic2D[xOrb, yOrb, i, om, w]
  ]


(* ComputeGeocentricAngle
   Returns the geocentric ecliptic angle (radians, in (-Pi, Pi]) of an
   asteroid at its closest approach date.  approachDateStr is "YYYY-MM-DD"
   from the NeoWs API.  Returns $Failed on any error. *)

ComputeGeocentricAngle[elements_Association, approachDateStr_String] :=
  Quiet @ Check[
    Module[{jd, posAst, posEarth, dx, dy},
      jd       = DateToJulianDate[approachDateStr];
      posAst   = KeplerPosition[elements, jd];
      posEarth = KeplerPosition[$EarthOrbitalElements, jd];
      dx = posAst[[1]] - posEarth[[1]];
      dy = posAst[[2]] - posEarth[[2]];
      ArcTan[dx, dy]
    ],
    $Failed
  ]


(* AugmentAsteroidsWithAngles
   Adds "geocentricAngle" (radians) to every asteroid Association.
   Seeded random angles for all n asteroids are generated first so that
   fallback angles are deterministic regardless of which orbital element
   fetches succeed.  Computed angles replace the random baseline where
   valid orbital elements are present. *)

AugmentAsteroidsWithAngles[asteroids_List] :=
  Module[{n, randAngles},
    n          = Length[asteroids];
    SeedRandom[42];
    randAngles = RandomReal[{0, 2*Pi}, n];
    MapIndexed[
      Function[{ast, idx},
        Module[{el, ang, angle},
          el = Lookup[ast, "orbital_elements", $Failed];
          angle = If[AssociationQ[el],
            ang = ComputeGeocentricAngle[el, ast["approachDate"]];
            If[ang === $Failed,
              Print["  Warning: angle computation failed for ", ast["name"],
                    ", using seeded random fallback."];
              randAngles[[idx[[1]]]],
              ang
            ],
            randAngles[[idx[[1]]]]
          ];
          Append[ast, "geocentricAngle" -> angle]
        ]
      ],
      asteroids
    ]
  ]


(* --------------------------------------------------------
   Solar system animation
   -------------------------------------------------------- *)


(* ScaleDistance
   Maps a miss distance in km to a radius in plot units.
   Uses a square-root scale so close and far objects
   are both visible. plotMax = 1.0 corresponds to maxDist. *)

ScaleDistance[km_?NumericQ, maxDist_?NumericQ] :=
  Sqrt[km / maxDist]


(* AsteroidDot
   Returns graphics primitives for one asteroid. *)

AsteroidDot[asteroid_Association, angle_?NumericQ,
            maxDist_?NumericQ] :=
  Module[{r, x, y, col, sz},

    r   = ScaleDistance[asteroid["missDistanceKm"], maxDist];
    x   = r * Cos[angle];
    y   = r * Sin[angle];
    col = If[asteroid["isHazardous"],
           RGBColor[1.0, 0.25, 0.2],    (* red — hazardous *)
           RGBColor[0.3, 0.85, 1.0]     (* cyan — safe     *)
         ];

    (* Dot size proportional to log(diameter), clamped *)
    sz  = Clip[0.012 + 0.025 * Log10[
            Max[asteroid["diamMeanKm"] * 1000, 1]], {0.008, 0.045}];

    {col, PointSize[sz], Point[{x, y}]}
  ]


(* BuildFrame
   Renders the solar system view with k asteroids visible. *)

BuildFrame[asteroids_List, angles_List, k_Integer,
           maxDist_?NumericQ, dateRange_String] :=
  Module[
    {lunarRings, earthDot, dots, labels, visible},

    (* Reference rings: 1 LD, 5 LD, 20 LD *)
    lunarRings = Map[
      Function[ld,
        {Opacity[0.18], GrayLevel[0.7], Thickness[0.003],
         Circle[{0,0}, ScaleDistance[ld * $LunarDistance, maxDist]]}
      ],
      {1, 5, 20}
    ];

    (* Ring labels *)
    labels = Map[
      Function[ld,
        Text[
          Style[ToString[ld] <> " LD", White, 7],
          {ScaleDistance[ld * $LunarDistance, maxDist] * 0.72, 0.04}
        ]
      ],
      {1, 5, 20}
    ];

    (* Earth *)
    earthDot = {RGBColor[0.2, 0.5, 1.0], Disk[{0,0}, 0.025]};

    (* Asteroids visible so far *)
    visible = asteroids[[1 ;; k]];
    dots    = MapIndexed[
      AsteroidDot[#1, angles[[#2[[1]]]], maxDist] &,
      visible
    ];

    Graphics[
      {lunarRings, labels, earthDot, dots},
      PlotRange  -> {{-1.1, 1.1}, {-1.1, 1.1}},
      Background -> GrayLevel[0.07],
      ImageSize  -> {500, 500},
      Epilog     -> {
        (* Legend *)
        {RGBColor[0.3,0.85,1.0], PointSize[0.022],
         Point[{-0.95, -0.92}]},
        Style[Text["Safe",       {-0.83, -0.92}], White, 9],
        {RGBColor[1.0,0.25,0.2], PointSize[0.022],
         Point[{-0.60, -0.92}]},
        Style[Text["Hazardous",  {-0.43, -0.92}], White, 9],
        Style[Text["Earth at centre \[Bullet] " <> dateRange,
          {0.15, -0.92}], GrayLevel[0.6], 8]
      }
    ]
  ]


(* ExportAnimation *)

ExportAnimation[asteroids_List, filePath_String,
                startDate_String, endDate_String,
                frameRate_:12] :=
  Module[
    {maxDist, n, dateRange, angles, frames, holdFrames, allFrames},

    maxDist = Max[#["missDistanceKm"] & /@ asteroids] * 1.05;
    n       = Length[asteroids];
    dateRange = startDate <> " – " <> endDate;

    (* Use pre-computed geocentric angles if available (set by AugmentAsteroidsWithAngles
       in main.wl); fall back to seeded random for backward compatibility with
       experiment.wl and any other caller that skips the orbital elements step. *)
    angles = If[AllTrue[asteroids, KeyExistsQ[#, "geocentricAngle"] &],
      #["geocentricAngle"] & /@ asteroids,
      (SeedRandom[42]; RandomReal[{0, 2*Pi}, n])
    ];

    Print["  Rendering ", n + Round[frameRate * 3], " frames for ",
          n, " asteroids..."];

    (* One frame per asteroid appearing, farthest first (list is closest-first
       so we reverse for the reveal, then show full picture at end) *)
    frames = Table[
      BuildFrame[Reverse[asteroids], Reverse[angles], k,
                 maxDist, dateRange],
      {k, 1, n}
    ];

    (* Hold the final frame for 3 s *)
    holdFrames = ConstantArray[Last[frames], Round[frameRate * 3]];
    allFrames  = Join[frames, holdFrames];

    ExportGIF[allFrames, filePath, frameRate]
  ]

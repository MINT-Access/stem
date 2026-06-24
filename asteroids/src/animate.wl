(* ========================================================
   src/animate.wl — Solar system top-down view animation

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

    (* Assign each asteroid a fixed random angle (seed for repeatability) *)
    SeedRandom[42];
    angles = RandomReal[{0, 2 Pi}, n];

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

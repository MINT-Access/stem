(* ========================================================
   primes/model.wl — Prime number pattern models

   Public API:
     UlamModel[cfg]   — Ulam spiral prime grid
     GapsModel[cfg]   — Prime gap sequence analysis

   Both return an Association; downstream code branches on
   model["mode"] to distinguish them.
   ======================================================== *)


(* ── UlamCoords ──────────────────────────────────────────
   Generates the n×n Ulam spiral as a list of {row, col}
   positions indexed by integer value.  coords[[k]] is the
   grid position of integer k (1-indexed, top-left origin).

   Winding: start at centre, go right 1, up 1, left 2,
   down 2, right 3, up 3, ...  Segment length increments
   every two direction changes. ──────────────────────────── *)

UlamCoords[n_Integer] :=
  Module[{total, row, col, dirs, d, segLen, segsAtLen, stepsDone},
    total     = n * n;
    row       = Ceiling[n / 2];
    col       = Ceiling[n / 2];
    dirs      = {{0, 1}, {-1, 0}, {0, -1}, {1, 0}};  (* right, up, left, down *)
    d         = 1;
    segLen    = 1;
    segsAtLen = 0;
    stepsDone = 0;

    Reap[
      Sow[{row, col}];
      Do[
        row += dirs[[d, 1]];
        col += dirs[[d, 2]];
        Sow[{row, col}];
        stepsDone += 1;
        If[stepsDone === segLen,
          stepsDone  = 0;
          d          = Mod[d, 4] + 1;
          segsAtLen += 1;
          If[segsAtLen === 2, segsAtLen = 0; segLen += 1]
        ],
        {total - 1}
      ]
    ][[2, 1]]
  ]


(* ── UlamModel ───────────────────────────────────────────
   Constructs a size×size binary prime grid via Ulam spiral.
   PrimeQ tests each integer; no sieve is needed for n ≤ 201.

   Returns:
     "grid"          — {size × size} matrix: 1=prime, 0=composite
     "size"          — grid side length (always odd)
     "prime_count"   — total primes in the grid
     "prime_density" — fraction of cells that are prime
     "coords"        — list: coords[[k]] = {row,col} for integer k
     "mode"          — "ulam"
   ──────────────────────────────────────────────────────── *)

UlamModel[cfg_Association] :=
  Module[{size, n, coords, grid, primeCount, primeDensity},

    size = GetCfg[cfg, {"simulation","ulam","size"}, 101];

    If[EvenQ[size],
      size += 1;
      Print["  Warning: size must be odd — adjusted to ", size];
      STEMSay["Grid size was even, adjusted to " <> ToString[size]]
    ];

    n      = size;
    coords = UlamCoords[n];

    grid = ConstantArray[0, {n, n}];
    Do[
      With[{rc = coords[[k]]},
        If[PrimeQ[k], grid[[rc[[1]], rc[[2]]]] = 1]
      ],
      {k, 1, n * n}
    ];

    primeCount   = Total[grid, 2];
    primeDensity = N[primeCount / (n * n)];

    <| "grid"          -> grid,
       "size"          -> n,
       "prime_count"   -> primeCount,
       "prime_density" -> primeDensity,
       "coords"        -> coords,
       "mode"          -> "ulam" |>
  ]


(* ── GapsModel ───────────────────────────────────────────
   Computes the prime gap sequence for the first `count` primes.

   Returns:
     "primes"           — list of the first count primes
     "gaps"             — Differences[primes], length count-1
     "mean_gap"         — mean gap value
     "max_gap"          — largest gap in the sequence
     "twin_prime_count" — number of gaps equal to 2
     "gap_distribution" — Association: gap_value -> frequency
     "mode"             — "gaps"
   ──────────────────────────────────────────────────────── *)

GapsModel[cfg_Association] :=
  Module[{count, primes, gaps, meanGap, maxGap, twinCount, gapDist},

    count = GetCfg[cfg, {"simulation","gaps","count"}, 5000];
    count = Max[count, 10];

    Print["  Generating first ", count, " primes..."];
    primes = Table[Prime[n], {n, 1, count}];
    gaps   = Differences[primes];

    meanGap   = N[Mean[gaps]];
    maxGap    = Max[gaps];
    twinCount = Length[Select[gaps, # === 2 &]];
    gapDist   = Counts[gaps];

    <| "primes"           -> primes,
       "gaps"             -> gaps,
       "mean_gap"         -> meanGap,
       "max_gap"          -> maxGap,
       "twin_prime_count" -> twinCount,
       "gap_distribution" -> gapDist,
       "mode"             -> "gaps" |>
  ]

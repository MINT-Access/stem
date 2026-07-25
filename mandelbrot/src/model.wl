(* ========================================================
   mandelbrot/src/model.wl — Mandelbrot and Julia set iteration,
   Hilbert-traversal field computation

   For a complex parameter c, iterate z_{n+1} = z_n^2 + c from z_0 = 0.
   c is in the Mandelbrot set iff this sequence stays bounded forever;
   otherwise it "escapes," and the number of iterations before escape
   (capped at max_iterations) is the field this app sonifies and
   renders, via the same Hilbert-traversal + brightness-to-frequency
   technique images/ uses (HilbertTraversalOrder from stem-core,
   BrightnessToFreq-style log mapping, duplicated per this codebase's
   no-shared-src/ convention).

   Julia sets fix c and sweep the STARTING point z_0 instead — the
   deep connection to the Mandelbrot set: c inside the Mandelbrot set
   gives a connected Julia set, c outside gives a disconnected one
   ("Fatou dust") — see AGENTS.md design decision 2 for why this app's
   default Julia c was changed from the commonly-cited -0.7+0.27015i
   (verified here to actually be OUTSIDE the Mandelbrot set) to a
   genuinely verified-interior point.

   Escape radius 2 is DERIVED, not a received convention — see
   EscapeRadiusCheck and AGENTS.md design decision 1 for the argument
   and its direct numerical verification.

   Public API:
     MandelbrotEscapeIterations[c, maxIter]
     JuliaEscapeIterations[z0, c, maxIter]
     MainCardioidBoundary[theta]
     GridToComplex[col, row, gridSize, reMin, reMax, imMin, imMax]
     EscapeRadiusCheck[], MembershipFactsCheck[],
     MainCardioidBoundaryCheck[], BoundaryComplexityCheck[]
     MandelbrotModel[cfg], JuliaModel[cfg], ZoomModel[cfg]
   ======================================================== *)


(* ── Core iteration ───────────────────────────────────────────────── *)

(* MandelbrotEscapeIterations — number of iterations of z->z^2+c
   (starting z=0) before |z|>2, capped at maxIter (returned for points
   that never escape within the budget — i.e. treated as "in the set"
   for this app's purposes). *)
MandelbrotEscapeIterations[c_?NumericQ, maxIter_Integer] :=
  Module[{z = 0.0 + 0.0*I, n = 0},
    While[n < maxIter && Abs[z] <= 2.0, z = z^2 + c; n++];
    n
  ];

(* JuliaEscapeIterations — same iteration, fixed c, swept starting z0. *)
JuliaEscapeIterations[z0_?NumericQ, c_?NumericQ, maxIter_Integer] :=
  Module[{z = z0, n = 0},
    While[n < maxIter && Abs[z] <= 2.0, z = z^2 + c; n++];
    n
  ];

(* MainCardioidBoundary — DERIVED (see AGENTS.md design decision 3):
   fixed points of z->z^2+c satisfy z=z^2+c, i.e. c=z-z^2; stability
   requires |f'(z)|=|2z|<1, so the boundary of stability is |2z|=1,
   i.e. z=Exp[I theta]/2; substituting into c=z-z^2 gives the exact
   parametric boundary c(theta) = Exp[I theta]/2 - Exp[2 I theta]/4 —
   confirmed via Simplify in the derivation session, not merely
   plausible-looking. *)
MainCardioidBoundary[theta_?NumericQ] :=
  Exp[I*theta] / 2.0 - Exp[2.0*I*theta] / 4.0;

(* MainCardioidPointFromR — the same derivation's natural parametrization,
   z = r*Exp[I theta], c = z - z^2 (boundary at r=0.5). Used by
   MainCardioidBoundaryCheck to test points precisely inside/outside
   the boundary along the mathematically natural radial direction (not
   an arbitrary complex-plane-origin-relative scaling of c itself,
   which AGENTS.md design decision 3 documents as unreliable near
   bulb-attachment points). *)
MainCardioidPointFromR[r_?NumericQ, theta_?NumericQ] :=
  Module[{z = r * Exp[I*theta]}, z - z^2];

(* GridToComplex — maps 1-based {col,row} pixel coordinates on a
   gridSize x gridSize grid to a complex point linearly spanning
   [reMin,reMax] x [imMin,imMax]. Row 1 maps to imMin (bottom), matching
   images/'s own row/Raster orientation convention (see animate.wl). *)
GridToComplex[col_Integer, row_Integer, gridSize_Integer,
             reMin_?NumericQ, reMax_?NumericQ, imMin_?NumericQ, imMax_?NumericQ] :=
  (reMin + (col - 1.0) / (gridSize - 1.0) * (reMax - reMin)) +
  I * (imMin + (row - 1.0) / (gridSize - 1.0) * (imMax - imMin));


(* ── Correctness checks (diagnostic-only, printed PASS/FAIL) ──────── *)

(* Check 1: escape radius, derived and directly verified. If |z_n|>2
   AND |z_n|>=|c| (which holds automatically once |z_n|>2, given the
   standard |c|<=2 viewing region — see AGENTS.md design decision 1),
   then |z_{n+1}| = |z_n^2+c| >= |z_n|^2-|c| >= |z_n|^2-|z_n| =
   |z_n|(|z_n|-1) > |z_n| since |z_n|-1>1. Verified here by DIRECT
   numerical confirmation that |z_{n+1}|>|z_n| at several (c,z) pairs
   satisfying the hypothesis, not a restatement of the "radius=2"
   convention. *)
EscapeRadiusCheck[] :=
  Module[{testPairs, results, allIncreasing},
    testPairs = {
      {0.5 + 0.5*I, 2.1}, {0.5 + 0.5*I, 2.5*I}, {0.5 + 0.5*I, 3.0 + 1.0*I},
      {-1.0 + 0.3*I, 2.1}, {1.5, 2.1}, {-1.9, 2.1}
    };
    results = Map[
      Function[pair,
        Module[{c = pair[[1]], z = pair[[2]], zNext, hypothesisHolds},
          zNext = z^2 + c;
          hypothesisHolds = Abs[z] > 2.0 && Abs[z] >= Abs[c] && Abs[c] <= 2.0;
          <| "c" -> c, "z" -> z, "zNext" -> zNext,
             "hypothesisHolds" -> hypothesisHolds,
             "strictlyIncreasing" -> (Abs[zNext] > Abs[z]) |>
        ]
      ],
      testPairs
    ];
    allIncreasing = AllTrue[results, #["hypothesisHolds"] && #["strictlyIncreasing"] &];
    <| "results" -> results, "pass" -> allIncreasing |>
  ];

(* Check 2: known membership facts, exact. c=0 stays exactly 0 forever;
   c=-1 enters an exact period-2 cycle (0,-1,0,-1,...), verified over
   many iterations, never escaping; c=1 escapes
   (0->1->2->5->26->677->...), verified to exceed the escape radius. *)
MembershipFactsCheck[] :=
  Module[{seq0, seqM1, seq1, c0Stable, cM1Cycle, cM1Bounded, c1Escapes, pass},
    seq0  = NestList[#^2 + 0.0 &, 0.0 + 0.0*I, 20];
    seqM1 = NestList[#^2 - 1.0 &, 0.0 + 0.0*I, 50];
    seq1  = NestList[#^2 + 1.0 &, 0.0 + 0.0*I, 8];

    c0Stable = AllTrue[Abs /@ seq0, # == 0.0 &];
    cM1Cycle = AllTrue[Range[Length[seqM1]],
      Function[i, If[OddQ[i], seqM1[[i]] == 0.0, seqM1[[i]] == -1.0]]];
    cM1Bounded = Max[Abs /@ seqM1] <= 1.0 + 10^-9;
    c1Escapes = Max[Abs /@ seq1] > 2.0;

    pass = c0Stable && cM1Cycle && cM1Bounded && c1Escapes;
    <| "c0Stable" -> c0Stable, "cM1Cycle" -> cM1Cycle, "cM1Bounded" -> cM1Bounded,
       "c1Escapes" -> c1Escapes, "c1FinalMag" -> Abs[Last[seq1]], "pass" -> pass |>
  ];

(* Check 3: main cardioid boundary, exact — three points straddling the
   DERIVED boundary along the natural r-parametrization (r=0.5 is the
   boundary; see MainCardioidPointFromR): on the boundary (r=0.5) and
   10% further in (r=0.45) both stay non-escaping within the budget;
   10% further out (r=0.55) escapes distinctly faster. theta=1.0 chosen
   as a representative angle verified clear of the bulb-attachment
   cusps near theta=0 and theta=Pi, where radial perturbation can
   accidentally land inside a DIFFERENT component of the Mandelbrot
   set (a genuine subtlety discovered during derivation — see
   AGENTS.md design decision 3). *)
MainCardioidBoundaryCheck[Optional[theta_?NumericQ, 1.0],
                          Optional[maxIter_Integer, 300]] :=
  Module[{cOn, cOut, cIn, onIter, outIter, inIter, pass},
    cOn  = MainCardioidPointFromR[0.50, theta];
    cOut = MainCardioidPointFromR[0.55, theta];
    cIn  = MainCardioidPointFromR[0.45, theta];
    onIter  = MandelbrotEscapeIterations[cOn, maxIter];
    outIter = MandelbrotEscapeIterations[cOut, maxIter];
    inIter  = MandelbrotEscapeIterations[cIn, maxIter];
    pass = (onIter === maxIter) && (inIter === maxIter) && (outIter < maxIter / 2);
    <| "theta" -> theta, "maxIter" -> maxIter,
       "cOn" -> cOn, "cOut" -> cOut, "cIn" -> cIn,
       "onIter" -> onIter, "outIter" -> outIter, "inIter" -> inIter, "pass" -> pass |>
  ];

(* Check 4: "the boundary has the highest local complexity" — quantified,
   not merely asserted. Computes the default mandelbrot-mode field via
   the actual Hilbert traversal, classifies each pixel by its OWN
   iteration count (deep interior: >=95% of max; far exterior: <=5% of
   max; boundary zone: everything between — a classification
   independent of the adjacent-pixel deltas being measured, so this
   isn't circular), and compares the mean |delta(iteration count)| to
   the next Hilbert-adjacent pixel across the three classes. *)
BoundaryComplexityCheck[Optional[gridN_Integer, 6], Optional[maxIter_Integer, 300]] :=
  Module[{size, reMin = -2.0, reMax = 0.5, imMin = -1.25, imMax = 1.25,
          traversal, iterField, deltas, classOf, classes,
          interiorVals, boundaryVals, exteriorVals,
          meanInterior, meanBoundary, meanExterior, pass},
    size = 2^gridN;
    traversal = HilbertTraversalOrder[gridN];
    iterField = Table[
      MandelbrotEscapeIterations[
        GridToComplex[traversal[[i, 1]], traversal[[i, 2]], size, reMin, reMax, imMin, imMax],
        maxIter],
      {i, Length[traversal]}
    ];
    deltas = Abs[Differences[iterField]];
    classOf[v_] := Which[v >= 0.95 * maxIter, "interior", v <= 0.05 * maxIter, "exterior", True, "boundary"];
    classes = classOf /@ iterField[[1 ;; -2]];

    interiorVals = Extract[deltas, Position[classes, "interior"]];
    boundaryVals = Extract[deltas, Position[classes, "boundary"]];
    exteriorVals = Extract[deltas, Position[classes, "exterior"]];
    meanInterior = If[Length[interiorVals] > 0, N[Mean[interiorVals]], 0.0];
    meanBoundary = If[Length[boundaryVals] > 0, N[Mean[boundaryVals]], 0.0];
    meanExterior = If[Length[exteriorVals] > 0, N[Mean[exteriorVals]], 0.0];

    pass = meanBoundary > 2.0 * meanInterior && meanBoundary > 2.0 * meanExterior &&
           Length[boundaryVals] > 10;
    <| "gridN" -> gridN, "maxIter" -> maxIter,
       "nInterior" -> Length[interiorVals], "nBoundary" -> Length[boundaryVals], "nExterior" -> Length[exteriorVals],
       "meanInterior" -> meanInterior, "meanBoundary" -> meanBoundary, "meanExterior" -> meanExterior,
       "pass" -> pass |>
  ];


(* ========================================================
   Per-mode model builders
   ======================================================== *)

(* ── Mode 1: mandelbrot — the classic set over the standard window ─── *)

(* Standard viewing window real [-2,0.5], imag [-1.25,1.25] — verified
   to comfortably contain the whole set: the entire Mandelbrot set lies
   within |c|<=2 (a direct consequence of the escape-radius argument at
   n=1, where z_1=c already satisfies |z_1|=|c| and |z_1|>=|c|
   trivially, so |c|>2 alone is already sufficient for escape), and
   both window extremes satisfy |c|<=2 (|-2|=2, |0.5|=0.5, |1.25i|=1.25). *)
$mandelReMin = -2.0; $mandelReMax = 0.5;
$mandelImMin = -1.25; $mandelImMax = 1.25;

MandelbrotModel[cfg_Association] :=
  Module[{maxIter, gridN, size, traversal, nPixels, iterField},
    maxIter = GetCfg[cfg, {"simulation", "mandelbrot", "max_iterations"}, 300];
    gridN   = Log2[GetCfg[cfg, {"simulation", "mandelbrot", "grid_size"}, 64]];
    size = 2^gridN;
    traversal = HilbertTraversalOrder[gridN];
    nPixels = Length[traversal];
    iterField = Table[
      MandelbrotEscapeIterations[
        GridToComplex[traversal[[i, 1]], traversal[[i, 2]], size,
                      $mandelReMin, $mandelReMax, $mandelImMin, $mandelImMax],
        maxIter],
      {i, nPixels}
    ];
    <|
      "mode" -> "mandelbrot", "maxIter" -> maxIter, "gridN" -> gridN, "size" -> size,
      "reMin" -> $mandelReMin, "reMax" -> $mandelReMax, "imMin" -> $mandelImMin, "imMax" -> $mandelImMax,
      "traversal" -> traversal, "nPixels" -> nPixels, "iterField" -> iterField
    |>
  ];


(* ── Mode 2: julia — fixed c, sweep z0 ────────────────────────────── *)

(* Default Julia c = -0.123+0.745i, the "Douady rabbit" — chosen and
   VERIFIED, not assumed: confirmed genuinely inside the Mandelbrot set
   (bounded through 100000 iterations, and small perturbations in every
   direction remain bounded too, so it is not a knife-edge boundary
   point), giving a genuinely CONNECTED Julia set, with rich structure
   (31 distinct escape-iteration values over a 64x64 grid at
   maxIter=300). See AGENTS.md design decision 2 for why the more
   commonly-cited -0.7+0.27015i was rejected after verification showed
   it actually escapes (at iteration 96, independent of budget up to
   100000) — an exterior point, giving a technically DISCONNECTED
   ("Fatou dust") Julia set, the opposite of what this mode's own
   Mandelbrot-Julia connectivity story needs as its default example. *)
$juliaDefaultCRe = -0.123; $juliaDefaultCIm = 0.745;

JuliaModel[cfg_Association] :=
  Module[{maxIter, gridN, size, cRe, cIm, c, traversal, nPixels, iterField, cIsInterior},
    maxIter = GetCfg[cfg, {"simulation", "mandelbrot", "max_iterations"}, 300];
    gridN   = Log2[GetCfg[cfg, {"simulation", "mandelbrot", "grid_size"}, 64]];
    cRe = N @ GetCfg[cfg, {"simulation", "mandelbrot", "julia_c_real"}, $juliaDefaultCRe];
    cIm = N @ GetCfg[cfg, {"simulation", "mandelbrot", "julia_c_imag"}, $juliaDefaultCIm];
    c = cRe + I * cIm;
    size = 2^gridN;
    traversal = HilbertTraversalOrder[gridN];
    nPixels = Length[traversal];
    (* Julia sets are conventionally viewed on [-1.5,1.5]x[-1.5,1.5],
       independent of the Mandelbrot window (a different plane -- this
       one is the z0-plane, not the c-plane). *)
    iterField = Table[
      JuliaEscapeIterations[
        GridToComplex[traversal[[i, 1]], traversal[[i, 2]], size, -1.5, 1.5, -1.5, 1.5],
        c, maxIter],
      {i, nPixels}
    ];
    cIsInterior = MandelbrotEscapeIterations[c, 100000] === 100000;
    <|
      "mode" -> "julia", "maxIter" -> maxIter, "gridN" -> gridN, "size" -> size,
      "c" -> c, "cRe" -> cRe, "cIm" -> cIm, "cIsInterior" -> cIsInterior,
      "reMin" -> -1.5, "reMax" -> 1.5, "imMin" -> -1.5, "imMax" -> 1.5,
      "traversal" -> traversal, "nPixels" -> nPixels, "iterField" -> iterField
    |>
  ];


(* ── Mode 3: zoom — successively deeper magnification, same centre ─── *)

(* Default centre: c=-0.743643887037151+0.131825904205330i, a
   well-documented "seahorse valley" coordinate on the Mandelbrot
   boundary near the main-cardioid/period-2-bulb junction — VERIFIED
   (not assumed) to show sustained, genuine fine structure across four
   successive 4x-magnification levels (55 to 141 distinct
   iteration-count values per level on a 48x48 test grid; see
   AGENTS.md design decision 4 for the full verification transcript). *)
$zoomDefaultCRe = -0.743643887037151; $zoomDefaultCIm = 0.131825904205330;
$zoomBaseHalfWidth = 1.5;

ZoomModel[cfg_Association] :=
  Module[{maxIter, gridN, size, cRe, cIm, nLevels, traversal, nPixels, levels},
    maxIter = GetCfg[cfg, {"simulation", "mandelbrot", "max_iterations"}, 300];
    gridN   = Log2[GetCfg[cfg, {"simulation", "mandelbrot", "grid_size"}, 64]];
    cRe     = N @ GetCfg[cfg, {"simulation", "mandelbrot", "zoom_center_real"}, $zoomDefaultCRe];
    cIm     = N @ GetCfg[cfg, {"simulation", "mandelbrot", "zoom_center_imag"}, $zoomDefaultCIm];
    nLevels =     GetCfg[cfg, {"simulation", "mandelbrot", "zoom_levels"}, 4];
    size = 2^gridN;
    traversal = HilbertTraversalOrder[gridN];
    nPixels = Length[traversal];

    levels = Table[
      Module[{halfWidth, reMin, reMax, imMin, imMax, iterField},
        halfWidth = $zoomBaseHalfWidth / 4.0^(lvl - 1);
        reMin = cRe - halfWidth; reMax = cRe + halfWidth;
        imMin = cIm - halfWidth; imMax = cIm + halfWidth;
        iterField = Table[
          MandelbrotEscapeIterations[
            GridToComplex[traversal[[i, 1]], traversal[[i, 2]], size, reMin, reMax, imMin, imMax],
            maxIter],
          {i, nPixels}
        ];
        <| "level" -> lvl, "halfWidth" -> halfWidth, "magnification" -> $zoomBaseHalfWidth / halfWidth,
           "reMin" -> reMin, "reMax" -> reMax, "imMin" -> imMin, "imMax" -> imMax,
           "iterField" -> iterField |>
      ],
      {lvl, nLevels}
    ];

    <|
      "mode" -> "zoom", "maxIter" -> maxIter, "gridN" -> gridN, "size" -> size,
      "cRe" -> cRe, "cIm" -> cIm, "nLevels" -> nLevels,
      "traversal" -> traversal, "nPixels" -> nPixels, "levels" -> levels
    |>
  ];

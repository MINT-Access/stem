(* ========================================================
   henon/src/model.wl — Hénon map dynamics

   The Hénon map (Michel Hénon, 1976):
     x_{n+1} = 1 - a x_n^2 + y_n
     y_{n+1} = b x_n

   Hénon constructed this as a simplified model of the
   Poincaré section of the Lorenz system — the same 3D flow
   sonified in lorenz/ — reduced to the simplest 2D invertible
   map that still produces a genuine strange attractor. Unlike
   dynamical/'s logistic map (many-to-one, not invertible), the
   Hénon map is exactly invertible everywhere (see
   HenonMapInverse below), which is the whole reason a
   `reverse` mode is possible here at all.
   ======================================================== *)


(* HenonMap — one forward step. *)
HenonMap[{x_?NumericQ, y_?NumericQ}, a_?NumericQ, b_?NumericQ] :=
  {1.0 - a*x^2 + y, b*x};


(* HenonMapInverse — exact inverse step, derived algebraically
   from the forward equations:
     x_n = y_{n+1} / b
     y_n = x_{n+1} - 1 + a x_n^2
   Valid for any b != 0. The forward map is area-contracting
   (dissipative) whenever |b|<1 [see HenonJacobianDetAt], so the
   inverse map is area-EXPANDING — floating-point error that the
   forward map suppresses, the inverse map amplifies at the same
   rate. Safe for a handful of steps (see InverseExactnessCheck);
   NOT something to run for hundreds of iterations expecting a
   faithful "reverse trajectory" — see AGENTS.md. *)
HenonMapInverse[{X_?NumericQ, Y_?NumericQ}, a_?NumericQ, b_?NumericQ] :=
  Module[{x, y},
    x = Y / b;
    y = X - 1.0 + a*x^2;
    {x, y}
  ];


(* HenonJacobianAt — exact partial-derivative matrix at (x,y).
   Independent of the update rule above: this is the symbolic
   Jacobian of the map, not a re-statement of HenonMap. *)
HenonJacobianAt[x_?NumericQ, y_?NumericQ, a_?NumericQ, b_?NumericQ] :=
  {{-2.0*a*x, 1.0}, {b, 0.0}};


(* HenonJacobianDetAt — det of the Jacobian above. Algebraically
   this is (-2ax)*0 - 1*b = -b for EVERY (x,y): the x-dependence
   cancels exactly, so the map is area-contracting by the same
   constant factor everywhere on the plane, not just on average
   over the attractor. This is fact #1 the app verifies. *)
HenonJacobianDetAt[x_?NumericQ, y_?NumericQ, a_?NumericQ, b_?NumericQ] :=
  Det[HenonJacobianAt[x, y, a, b]];


(* HenonFixedPointX — the positive-branch fixed point x_fp,
   from solving a x_fp^2 + (1-b) x_fp - 1 == 0 (substitute the
   fixed-point condition y_fp = b x_fp into x_fp = 1 - a x_fp^2 + y_fp).
   Exact closed form, not a root-finder guess. *)
HenonFixedPointX[a_?NumericQ, b_?NumericQ] :=
  (-(1.0 - b) + Sqrt[(1.0 - b)^2 + 4.0*a]) / (2.0*a);


(* FirstFlipBifurcationA — the value of a (at fixed b) where the
   fixed point loses stability via a flip bifurcation (Jacobian
   eigenvalue crosses -1), i.e. period-1 -> period-2. Located by
   FindRoot on the simultaneous system {fixed-point condition,
   eigenvalue-equals(-1) condition}, NOT hardcoded — this
   independently confirms the closed form
   a = 3(1-b)^2/4 derived from substituting x*=(1-b)/(2a) (the
   eigenvalue=-1 root of lambda^2 + 2a*x* lambda - b = 0) back
   into the fixed-point equation. Both the numeric FindRoot
   result and the closed form are printed so they can be
   cross-checked (see tests/test_model.wl). *)
FirstFlipBifurcationA[b_?NumericQ] :=
  Module[{x, a, sol},
    sol = FindRoot[
      {a*x^2 + (1.0 - b)*x - 1.0 == 0,
       1.0 - 2.0*a*x - b == 0},
      {{x, 0.5}, {a, 0.4}}
    ];
    a /. sol
  ];

FirstFlipBifurcationAClosedForm[b_?NumericQ] := 3.0*(1.0 - b)^2 / 4.0;


(* ClassifyPeriod — settle onto the attractor from a fixed seed,
   then count distinct x-values (rounded) in the tail. Returns an
   integer period for periodic orbits, or a large sentinel (10^6)
   for divergence/aperiodic (chaotic) behaviour where the tail
   never repeats to within the rounding tolerance. Used both to
   empirically map the sweep's bifurcation structure and to
   bisect specific transition points below. *)
ClassifyPeriod[a_?NumericQ, b_?NumericQ, nTransient_Integer:2700, nTail_Integer:300] :=
  Module[{traj, tail, distinct},
    traj = NestList[HenonMap[#, a, b] &, {0.1, 0.1}, nTransient + nTail];
    tail = traj[[-nTail ;;, 1]];
    If[Max[Abs[tail]] > 1000 || !VectorQ[tail, NumericQ], Return[10^6]];
    distinct = Length[DeleteDuplicates[Round[tail, 10^-5]]];
    distinct
  ];


(* BisectPeriodDoubling — locate the a-value (between aLo, aHi)
   where the settled period first exceeds loPeriod, by bisection
   on ClassifyPeriod. This is the 2D-map analogue of dynamical/'s
   BifurcationPoint[FindRoot,...]: FindRoot needs a differentiable
   residual, which the higher (period-4, period-8, chaos-onset)
   transitions of a 2D map don't offer in closed form, so bisection
   on the empirically classified period is the appropriate
   numerical root-finding tool here instead. *)
BisectPeriodDoubling[aLo_?NumericQ, aHi_?NumericQ, b_?NumericQ, loPeriod_Integer, nSteps_Integer:60] :=
  Module[{lo = aLo, hi = aHi, mid, p},
    Do[
      mid = (lo + hi) / 2.0;
      p = ClassifyPeriod[mid, b];
      If[p <= loPeriod, lo = mid, hi = mid],
      {nSteps}
    ];
    (lo + hi) / 2.0
  ];


(* FindPeriodicWindowA — scans a fine grid of a in [aLo,aHi] and
   returns the a-value with the LOWEST settled period found, i.e.
   the most orderly point in an otherwise-chaotic stretch. This is
   how the "island of order" landmark below was actually located
   (a ~ 1.227, period 7) — an empirical scan, not an assumed value,
   the same discipline dynamical/AGENTS.md used to justify
   period3_window's r=3.830 rather than the textbook 3.8284. *)
FindPeriodicWindowA[aLo_?NumericQ, aHi_?NumericQ, b_?NumericQ, step_:0.001] :=
  Module[{aVals, periods, best},
    aVals = Range[aLo, aHi, step];
    periods = ClassifyPeriod[#, b] & /@ aVals;
    best = First[Ordering[periods, 1]];
    <| "a" -> aVals[[best]], "period" -> periods[[best]] |>
  ];


(* HenonSweepLandmarks — the empirically-located bifurcation
   cascade for a fixed b, bracketing each transition from bounds
   established by a coarse scan (see AGENTS.md for the scan that
   produced these brackets: period-1 up to a~0.37, period-2 up to
   a~0.91, period-4 up to a~1.03, period-8 up to a~1.05, chaotic
   beyond, with a period-7 window discovered near a~1.227 inside
   the chaotic region). The bracket bounds are specific to b=0.3's
   cascade location and are passed in via config rather than
   hardcoded inside this function. *)
HenonSweepLandmarks[b_?NumericQ] :=
  Module[{a1, a2, a3, aChaos, delta, window},
    a1     = FirstFlipBifurcationA[b];
    a2     = BisectPeriodDoubling[0.85, 0.95, b, 2];
    a3     = BisectPeriodDoubling[1.00, 1.04, b, 4];
    aChaos = BisectPeriodDoubling[1.04, 1.06, b, 8];
    window = FindPeriodicWindowA[1.18, 1.34, b, 0.001];
    delta  = If[Abs[a3 - a2] > 10^-12, (a2 - a1) / (a3 - a2), Missing["NotComputed"]];
    <|
      "first_bifurcation" -> a1,
      "second_bifurcation" -> a2,
      "third_bifurcation" -> a3,
      "chaos_onset" -> aChaos,
      "periodic_window" -> window["a"],
      "periodic_window_period" -> window["period"],
      "feigenbaum_ratio" -> delta
    |>
  ];


(* HenonTrajectory — iterate from (x0,y0), discard nTransient
   points to settle onto the attractor, keep the next nPoints.
   Returns the plain list of {x,y} pairs (no time/speed columns
   yet — that's added downstream in sonify.wl to match the
   {t,x,y,z,speed} shape SonifyTrajectory expects). *)
HenonTrajectory[x0_?NumericQ, y0_?NumericQ, a_?NumericQ, b_?NumericQ,
                nTransient_Integer, nPoints_Integer] :=
  Module[{full},
    full = NestList[HenonMap[#, a, b] &, {x0, y0}, nTransient + nPoints];
    full[[nTransient + 1 ;;]]
  ];


(* TrajectoryIsBounded — the Hénon map's bounded region depends on
   BOTH a and b together, not on either alone: (a,b)=(1.4,0.9), for
   instance, diverges to Overflow[] within a few hundred iterations,
   even though (1.4,0.3) and (0.4,0.9) are both perfectly well-behaved
   (verified while building this app — see AGENTS.md). A user who
   overrides just "b" via the CLI, leaving the config default a=1.4 in
   place, can silently hit this. Checked once, cheaply, right after
   generating a trajectory, rather than leaving a wall of Overflow[]
   messages to explain the failure instead. *)
(* NOTE: Overflow[] (WL's tag for a floating-point overflow) passes
   BOTH NumericQ and NumberQ as True — it is not distinguishable from
   a real number via those predicates, so checking magnitude directly
   would silently propagate it (Max[Abs[Overflow[]]] < limit stays an
   unevaluated symbolic comparison rather than True/False, discovered
   the hard way while building this app). FreeQ against the literal
   Overflow[] head is what actually catches it. *)
TrajectoryIsBounded[trajectory_List, limit_:1000] :=
  FreeQ[Last[trajectory], Overflow[] | Underflow[] | Indeterminate | ComplexInfinity | DirectedInfinity[___]] &&
  Max[Abs[Last[trajectory]]] < limit;


(* HenonLyapunovExponents — standard QR method for 2D maps.
   Iterates the map while propagating a tangent-space basis
   (starting from the identity) through the Jacobian at each
   visited point, re-orthonormalising via QRDecomposition (WL
   convention: m == q.r, q orthogonal, r upper-triangular) at
   every step to prevent the basis collapsing onto the dominant
   direction. The running sum of log|diagonal of r| divided by
   the iteration count gives the two Lyapunov exponents, largest
   first. A transient is discarded first so the tangent map is
   evaluated only along the attractor, not the approach to it. *)
HenonLyapunovExponents[a_?NumericQ, b_?NumericQ, nIter_Integer, nTransient_Integer:2000] :=
  Module[{state = {0.1, 0.1}, q = IdentityMatrix[2], r, jac, logSum = {0.0, 0.0}, m},
    Do[state = HenonMap[state, a, b], {nTransient}];
    Do[
      jac = HenonJacobianAt[state[[1]], state[[2]], a, b];
      m = jac . q;
      {q, r} = QRDecomposition[m];
      logSum += Log[Abs[Diagonal[r]]];
      state = HenonMap[state, a, b],
      {nIter}
    ];
    Sort[logSum / nIter, Greater]
  ];


(* ────────────────────────────────────────────────────────────
   Mode data-assembly — mirrors dynamical/'s SweepModel /
   IterateModelData: each mode gets one function that produces
   the exact Association its sonify.wl / animate.wl / output.wl
   functions consume.
   ──────────────────────────────────────────────────────────── *)

(* HenonAttractorModel — settles onto the attractor and keeps
   the trajectory for the continuous SonifyTrajectory pipeline. *)
HenonAttractorModel[x0_?NumericQ, y0_?NumericQ, a_?NumericQ, b_?NumericQ,
                    nTransient_Integer, nPoints_Integer] :=
  <|
    "trajectory" -> HenonTrajectory[x0, y0, a, b, nTransient, nPoints],
    "a" -> a, "b" -> b, "nTransient" -> nTransient, "nPoints" -> nPoints
  |>;


(* HenonSweepModel — settled attractor points at each of aSteps
   values of a between aStart and aEnd (b fixed), matching
   dynamical/SweepModel's {rValues, attractors} shape exactly
   (aValues here in place of rValues). *)
HenonSweepModel[aStart_?NumericQ, aEnd_?NumericQ, aSteps_Integer, b_?NumericQ,
                x0_?NumericQ, y0_?NumericQ, nTransient_Integer, nAttractor_Integer] :=
  Module[{aValues, attractors},
    aValues = N[Subdivide[aStart, aEnd, aSteps - 1]];
    attractors = Table[HenonTrajectory[x0, y0, a, b, nTransient, nAttractor], {a, aValues}];
    <| "aValues" -> aValues, "attractors" -> attractors, "b" -> b |>
  ];


(* HenonReverseModel — a short forward segment on the attractor,
   its simple array-reversal (numerically safe, no re-derivation),
   and a short exact-inverse demonstration: apply HenonMapInverse
   backward (reverseSteps) times starting from the segment's LAST
   point, and check each recovered point against the corresponding
   earlier point already computed during the forward run. This is
   the "proof of invertibility" moment — deliberately short. *)
HenonReverseModel[x0_?NumericQ, y0_?NumericQ, a_?NumericQ, b_?NumericQ,
                  nTransient_Integer, nForward_Integer, reverseSteps_Integer] :=
  Module[{forwardSeg, reversedSeg, lastPts, recovered, expectedOriginal, errs, maxErr},
    forwardSeg = HenonTrajectory[x0, y0, a, b, nTransient, nForward];
    reversedSeg = Reverse[forwardSeg];

    lastPts = forwardSeg[[-(reverseSteps + 1) ;;]];
    recovered = NestList[HenonMapInverse[#, a, b] &, Last[lastPts], reverseSteps];
    expectedOriginal = Reverse[lastPts];
    errs = MapThread[Norm[#1 - #2] &, {recovered, expectedOriginal}];
    maxErr = Max[errs];

    <|
      "forwardSeg" -> forwardSeg,
      "reversedSeg" -> reversedSeg,
      "inverseDemo" -> recovered,
      "inverseDemoExpected" -> expectedOriginal,
      "inverseDemoMaxError" -> maxErr,
      "a" -> a, "b" -> b, "reverseSteps" -> reverseSteps
    |>
  ];


(* ────────────────────────────────────────────────────────────
   Correctness checks — diagnostic-only (print PASS/FAIL, never
   abort), per blackbody/AGENTS.md §3 as corrected in
   compton/AGENTS.md. Checks 1, 2 and 4 test EXACT relations and
   use tight (near-machine-precision) tolerances; check 3 tests
   an empirical literature benchmark and deliberately uses a
   generous tolerance — see the comment at each check for why.
   ──────────────────────────────────────────────────────────── *)


(* Check 1 — constant Jacobian determinant.
   Evaluated at several ARBITRARY (x,y) points, not points drawn
   from the attractor, since the fact being tested (det == -b
   identically on the whole plane) says nothing special about
   the attractor itself. Tight tolerance: this is floating-point
   arithmetic on an exact algebraic identity, so any deviation
   above ~1e-9 would indicate a real bug, not numerical noise. *)
JacobianCheck[a_?NumericQ, b_?NumericQ, nTest_Integer:12] :=
  Module[{pts, dets, maxErr},
    SeedRandom[7];
    pts = Table[{RandomReal[{-5, 5}], RandomReal[{-5, 5}]}, {nTest}];
    dets = Map[HenonJacobianDetAt[#[[1]], #[[2]], a, b] &, pts];
    maxErr = Max[Abs[dets - (-b)]];
    <| "maxError" -> maxErr, "nTested" -> nTest, "pass" -> maxErr < 10^-9 |>
  ];


(* Check 2 — Lyapunov exponent sum equals log(b) exactly.
   Direct algebraic consequence of check 1 (the sum of Lyapunov
   exponents of a map equals the time-average log of the
   absolute Jacobian determinant, which here is the constant
   log|-b| = log(b) since b>0 in our regime). This is an EXACT
   relation independent of the specific attractor structure, so
   it gets the same tight tolerance as check 1 — any deviation
   beyond QR-accumulation floating point noise indicates a bug
   in the Lyapunov computation itself, not a modelling choice. *)
LyapunovSumCheck[lyaps_List, b_?NumericQ] :=
  Module[{sum, expected, err},
    sum = Total[lyaps];
    expected = Log[b];
    err = Abs[sum - expected];
    <| "sum" -> sum, "expected" -> expected, "absError" -> err, "pass" -> err < 10^-6 |>
  ];


(* Check 3 — largest Lyapunov exponent vs. the canonical literature
   benchmark lambda1 ~ 0.42 (a=1.4, b=0.3). This is an EMPIRICAL
   comparison, not an exact relation: the ~0.42 figure itself
   carries its own numerical-estimation uncertainty in the
   literature, and our own estimate depends on iteration count,
   transient length and starting point. Deliberately generous
   tolerance (30% relative) — the check only needs to confirm
   "positive, and in the right neighbourhood", not pin down a
   precise digit. Kept as a SEPARATE check from #2 specifically
   so the two different tolerance philosophies (exact relation
   vs. empirical benchmark) aren't blurred into one pass/fail. *)
LyapunovBenchmarkCheck[lyaps_List] :=
  Module[{lambda1 = Max[lyaps], benchmark = 0.42, relErr},
    relErr = Abs[lambda1 - benchmark] / benchmark;
    <| "lambda1" -> lambda1, "benchmark" -> benchmark, "relError" -> relErr,
       "pass" -> lambda1 > 0 && relErr < 0.30 |>
  ];


(* Check 4 — inverse map exactness. Forward-then-inverse on
   random test points must recover the original point to near
   machine precision. This validates `reverse` mode's core claim
   (the map IS exactly invertible) independently of any chaos or
   attractor computation — it holds for any (x,y), on or off the
   attractor, since it's an algebraic identity. Tight tolerance,
   same reasoning as check 1. *)
InverseExactnessCheck[a_?NumericQ, b_?NumericQ, nTest_Integer:20] :=
  Module[{pts, fwd, back, errs, maxErr},
    SeedRandom[42];
    pts = Table[{RandomReal[{-2, 2}], RandomReal[{-2, 2}]}, {nTest}];
    fwd = HenonMap[#, a, b] & /@ pts;
    back = HenonMapInverse[#, a, b] & /@ fwd;
    errs = MapThread[Norm[#1 - #2] &, {pts, back}];
    maxErr = Max[errs];
    <| "maxError" -> maxErr, "nTested" -> nTest, "pass" -> maxErr < 10^-9 |>
  ];


(* ────────────────────────────────────────────────────────────
   Correlation/box-counting dimension estimate — diagnostic only,
   printed as an informational figure (not one of the four
   PASS/FAIL checks). Dimension estimates from a finite point set
   carry inherent methodological uncertainty (grid alignment,
   choice of epsilon range, finite N) so this is reported as an
   estimate to compare against the commonly-cited ~1.25-1.28,
   never as a strict pass/fail.
   ──────────────────────────────────────────────────────────── *)

BoxCount[points_List, eps_?NumericQ] :=
  Module[{xs, ys, xmin, ymin},
    {xs, ys} = Transpose[points];
    {xmin, ymin} = {Min[xs], Min[ys]};
    Length[DeleteDuplicates[
      Table[{Floor[(xs[[i]] - xmin)/eps], Floor[(ys[[i]] - ymin)/eps]}, {i, Length[xs]}]
    ]]
  ];

(* BoxCountingDimension — N(eps) ~ eps^(-D), so D = -slope of a
   log N(eps) vs log eps least-squares fit. Epsilon range spans a
   decade-and-a-half in geometric steps (ratio 0.6) across the
   attractor's own bounding box, scaled from its extent so the
   estimate isn't tied to Hénon's specific (a,b)=(1.4,0.3) span. *)
BoxCountingDimension[points_List, nScales_Integer:9] :=
  Module[{xs, ys, extent, epsMax, epsList, counts, logEps, logN, n, slope},
    {xs, ys} = Transpose[points];
    extent = Max[Max[xs] - Min[xs], Max[ys] - Min[ys]];
    epsMax = 0.25 * extent;
    epsList = epsMax * (0.6)^Range[0, nScales - 1];
    counts = BoxCount[points, #] & /@ epsList;
    logEps = Log[epsList];
    logN = Log[N[counts]];
    n = Length[logEps];
    slope = (n*Total[logEps*logN] - Total[logEps]*Total[logN]) /
            (n*Total[logEps^2] - Total[logEps]^2);
    -slope
  ];

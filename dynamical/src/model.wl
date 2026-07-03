(* ========================================================
   dynamical/src/model.wl — Logistic map dynamics and
   period-doubling bifurcation analysis

   The logistic map:
       x_{n+1} = r * x_n * (1 - x_n),   x in [0,1], r in [0,4]

   Route to chaos (r increasing):
     r < 1            population collapses to zero
     1 < r < 3        single stable fixed point
     r ~ 3.0          first period-doubling bifurcation (period 2)
     r ~ 3.449        period 4
     r ~ 3.544        period 8
     r ~ 3.5644       Feigenbaum accumulation point (onset of chaos)
     r > 3.57         mostly chaotic, with periodic windows
     r ~ 3.8284       period-3 window (Li-Yorke: "period 3 implies chaos")
     r = 4            fully chaotic, ergodic on [0,1]
   ======================================================== *)


(* LogisticMap
   One iteration: x_{n+1} = r x_n (1 - x_n). *)

LogisticMap[x_, r_] := r * x * (1 - x);


(* SafeX0
   x0 = 0.5 is an exact pre-periodic point of the logistic map at r = 4:
   sin^2(pi/4) = 0.5, and x_n = sin^2(2^n pi/4) for n >= 2 is exactly 0
   (2^n/4 is an integer). A trajectory started at x0 = 0.5 with r = 4
   is therefore NOT chaotic — it lands on the repelling fixed point 0
   after exactly two steps and stays there. This is a real mathematical
   fact about this map, not a floating-point artifact, and it would
   silently break the "chaos" preset (r = 4), which is one of the five
   presets this app's recommended listening sequence depends on.
   Nudging x0 by a small epsilon is a standard, well-known trick when
   exploring the logistic map at r = 4 for exactly this reason; the
   nudge is far too small to change the qualitative behaviour of any
   other r value (attractors away from this single exact point are not
   sensitive to a 1e-6 change in x0 in a way that matters for what the
   listener hears).

   The epsilon must be at least ~1e-6, not smaller: F(0.5+eps, 4) =
   1 - 4 eps^2, and if eps is too small (e.g. 1e-9), eps^2 underflows
   relative to double-precision rounding at the 0.25 scale involved in
   the map, and the perturbed point collapses right back to exactly
   1.0 on the very first iteration — silently reproducing the exact
   same degenerate orbit this nudge exists to avoid. Verified
   empirically: 1e-9 fails (still collapses to the fixed point), 1e-6
   survives (produces a genuinely chaotic trajectory). *)

SafeX0[x0_?NumericQ] := If[Abs[x0 - 0.5] < 10^-6, x0 + 10^-6, x0];


(* ── Named presets (iterate mode) ────────────────────────────────── *)

$dynamicalPresets = <|
  "fixed_point" -> <|
    "r" -> 2.8,
    "desc" -> "a stable fixed point; the population settles to one value"
  |>,
  "period2" -> <|
    "r" -> 3.2,
    "desc" -> "a period-2 cycle; the population alternates between two values"
  |>,
  "period4" -> <|
    "r" -> 3.5,
    "desc" -> "a period-4 cycle; two period-doublings have occurred"
  |>,
  (* r = 3.8284 is the textbook-cited value for the period-3 window, but
     it is the window's exact tangent-bifurcation opening edge, where
     convergence to the 3-cycle is pathologically slow ("intermittency":
     verified numerically — at 300 iterations from x0=0.5, r=3.8284 has
     not converged at all, while r=3.830, just 0.0016 further into the
     window's interior, converges to machine precision by iteration
     ~270). 3.830 is used here so the preset actually sounds like a
     clean three-note cycle within the default n_iterations budget. *)
  "period3_window" -> <|
    "r" -> 3.830,
    "desc" -> "the period-3 window; a surprising island of order inside the chaotic region"
  |>,
  "chaos" -> <|
    "r" -> 4.0,
    "desc" -> "full chaos; the sequence never repeats"
  |>
|>;

(* PresetR
   Resolves a preset name to its r value; falls back to rDefault
   (the explicit --simulation.dynamical.r value) if preset is "" or
   unrecognised. *)
PresetR[preset_String, rDefault_?NumericQ] :=
  If[KeyExistsQ[$dynamicalPresets, preset],
    $dynamicalPresets[preset]["r"],
    rDefault
  ];

PresetDescription[preset_String] :=
  If[KeyExistsQ[$dynamicalPresets, preset],
    $dynamicalPresets[preset]["desc"],
    ""
  ];


(* ── Iteration ────────────────────────────────────────────────────── *)

(* IterateTrajectory
   Returns n+1 values: {x0, x1, ..., xn}. *)
IterateTrajectory[x0_?NumericQ, r_?NumericQ, n_Integer] :=
  NestList[LogisticMap[#, r] &, SafeX0[N[x0]], n];

(* AttractorPoints
   Runs nTransient iterations to let transients die out, then returns
   the next nAttractor iterates as the long-term attractor. *)
AttractorPoints[x0_?NumericQ, r_?NumericQ, nTransient_Integer, nAttractor_Integer] :=
  Module[{afterTransient},
    afterTransient = Nest[LogisticMap[#, r] &, SafeX0[N[x0]], nTransient];
    Rest[NestList[LogisticMap[#, r] &, afterTransient, nAttractor]]
  ];


(* ── Bifurcation point finder (Feigenbaum check) ─────────────────────
   The r value at which the fixed point of the nFold-times-iterated
   map loses stability (derivative = -1) is exactly the r value at
   which the next period-doubling is born:
     nFold = 1  ->  r where period 1 loses stability  (period 2 born),  r1 ~ 3.0
     nFold = 2  ->  r where period 2 loses stability  (period 4 born),  r2 ~ 3.449
     nFold = 4  ->  r where period 4 loses stability  (period 8 born),  r3 ~ 3.544
   Solved as a 2-unknown system {x, r} via FindRoot rather than
   hardcoded, per the correctness-check requirement. ─────────────────── *)

BifurcationPoint[nFold_Integer, rGuess_?NumericQ, Optional[xGuess_?NumericQ, 0.5]] :=
  Module[{Fn, sol},
    Fn[x_, r_] := Nest[LogisticMap[#, r] &, x, nFold];
    sol = FindRoot[
      {Fn[x, r] - x == 0, D[Fn[x, r], x] + 1 == 0},
      {x, xGuess}, {r, rGuess}
    ];
    {x, r} /. sol
  ];

$FeigenbaumConstant = 4.66920160910299;

(* FeigenbaumCheck
   Locates r1, r2, r3 numerically and verifies the ratio of successive
   bifurcation intervals is within tolerance (default 5%) of delta. *)
FeigenbaumCheck[Optional[tolerance_?NumericQ, 0.05]] :=
  Module[{r1sol, r2sol, r3sol, r1, r2, r3, ratio, relErr},
    r1sol = BifurcationPoint[1, 2.9];
    r2sol = BifurcationPoint[2, 3.449];
    r3sol = BifurcationPoint[4, 3.544];
    r1 = r1sol[[2]]; r2 = r2sol[[2]]; r3 = r3sol[[2]];
    ratio  = (r2 - r1) / (r3 - r2);
    relErr = Abs[ratio - $FeigenbaumConstant] / $FeigenbaumConstant;
    <|
      "r1" -> r1, "r2" -> r2, "r3" -> r3,
      "ratio" -> ratio, "relError" -> relErr,
      "pass" -> (relErr < tolerance)
    |>
  ];


(* ── Fixed-point check (r = 2.8) ──────────────────────────────────── *)
FixedPointCheck[Optional[r_?NumericQ, 2.8], Optional[x0_?NumericQ, 0.5],
               Optional[nTransient_Integer, 200], Optional[nAttractor_Integer, 50],
               Optional[tolerance_?NumericQ, 10^-6]] :=
  Module[{attractor, analytic, numeric, err},
    attractor = AttractorPoints[x0, r, nTransient, nAttractor];
    analytic  = 1.0 - 1.0/r;
    numeric   = Mean[attractor];
    err       = Abs[numeric - analytic];
    <|
      "analytic" -> analytic, "numeric" -> numeric, "error" -> err,
      "pass" -> (err < tolerance)
    |>
  ];


(* ── Period-2 check (r = 3.2) ──────────────────────────────────────── *)
Period2Check[Optional[r_?NumericQ, 3.2], Optional[x0_?NumericQ, 0.5],
            Optional[nTransient_Integer, 200], Optional[nAttractor_Integer, 100],
            Optional[tolerance_?NumericQ, 10^-4]] :=
  Module[{attractor, distinct, sum, expected, err},
    attractor = AttractorPoints[x0, r, nTransient, nAttractor];
    distinct  = DeleteDuplicates[Round[attractor, tolerance]];
    sum       = If[Length[distinct] === 2, Total[distinct], Missing["NotPeriod2"]];
    expected  = (r + 1.0) / r;
    err       = If[NumericQ[sum], Abs[sum - expected], Infinity];
    <|
      "distinctValues" -> distinct, "nDistinct" -> Length[distinct],
      "sum" -> sum, "expected" -> expected, "error" -> err,
      "pass" -> (Length[distinct] === 2 && err < 10^-3)
    |>
  ];


(* ── Lyapunov exponent check (r = 4.0) ───────────────────────────────
   lambda = mean(log|F'(x_n)|) = mean(log|r(1-2x_n)|) over a long
   trajectory. Positive lambda is the signature of chaos: nearby
   trajectories diverge at rate e^(lambda n). For r = 4 exactly,
   lambda = log(2) analytically. *)
LyapunovExponent[r_?NumericQ, x0_?NumericQ, nIter_Integer] :=
  Module[{traj},
    traj = IterateTrajectory[x0, r, nIter];
    Mean[Log[Abs[r * (1.0 - 2.0 * #)]] & /@ Most[traj]]
  ];

LyapunovCheck[Optional[r_?NumericQ, 4.0], Optional[x0_?NumericQ, 0.5],
             Optional[nIter_Integer, 10000], Optional[tolerance_?NumericQ, 0.05]] :=
  Module[{lambda, expected, relErr},
    lambda   = LyapunovExponent[r, x0, nIter];
    expected = Log[2.0];
    relErr   = Abs[lambda - expected] / expected;
    <|
      "lambda" -> lambda, "expected" -> expected, "relError" -> relErr,
      "pass" -> (lambda > 0 && relErr < tolerance)
    |>
  ];


(* SweepEventRValues
   The three r values marked with accent tones during the sweep.
   "first_bifurcation" is located via BifurcationPoint (same numerical
   root-finder used by the Feigenbaum check) for precision; the other
   two are well-established literature values for this map (the
   Feigenbaum accumulation point / onset of chaos, and the start of
   the period-3 window) rather than root-finding targets, since
   neither has as simple a closed-form stability condition as a
   period-doubling boundary. *)
SweepEventRValues[] :=
  <|
    "first_bifurcation" -> BifurcationPoint[1, 2.9][[2]],
    "chaos_onset"        -> 3.5699,
    "period3_window"      -> 3.8284
  |>;


(* ── Sweep model (sweep mode) ─────────────────────────────────────────
   Samples rSteps values of r from rStart to rEnd. At each r, records
   the attractor (nAttractor points after nTransient transient steps).
   Returns an Association with parallel lists so downstream code can
   zip rValues[[i]] with attractors[[i]]. *)
SweepModel[rStart_?NumericQ, rEnd_?NumericQ, rSteps_Integer,
          x0_?NumericQ, nTransient_Integer, nAttractor_Integer] :=
  Module[{rValues, attractors},
    rValues    = N[Subdivide[rStart, rEnd, rSteps - 1]];
    attractors = Map[AttractorPoints[x0, #, nTransient, nAttractor] &, rValues];
    <|
      "rValues"     -> rValues,
      "attractors"  -> attractors,
      "rStart"      -> rStart,
      "rEnd"        -> rEnd,
      "nTransient"  -> nTransient,
      "nAttractor"  -> nAttractor,
      "x0"          -> x0
    |>
  ];


(* ── Iterate model (iterate mode) ─────────────────────────────────────── *)
IterateModelData[r_?NumericQ, x0_?NumericQ, nIterations_Integer, preset_String] :=
  Module[{trajectory},
    trajectory = IterateTrajectory[x0, r, nIterations];
    <|
      "r"            -> r,
      "x0"           -> x0,
      "nIterations"  -> nIterations,
      "preset"       -> preset,
      "trajectory"   -> trajectory
    |>
  ];

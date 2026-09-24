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


(* ── Named presets (lyapunov mode) ─────────────────────────────────
   Each overrides the sweep range, step count and duration of
   simulation.dynamical.lyapunov; transient, averaging length and floor
   stay as configured. lyapunov_window reproduces the range, steps and
   duration of prototype_lyapunov.wl so the two can be compared directly
   (the prototype averaged over 500 + 2000 iterations with a floor of -1). *)

$lyapunovPresets = <|
  "lyapunov_window" -> <|
    "r_min" -> 3.40, "r_max" -> 3.90, "steps" -> 500, "duration_seconds" -> 40.0,
    "desc" -> "the window from r equals 3.40 to 3.90, as in the listening prototype"
  |>
|>;


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


(* ── Lyapunov exponent ────────────────────────────────────────────────
   lambda = mean(log|F'(x_n)|) = mean(log|r(1-2x_n)|) over a long
   trajectory. Positive lambda is the signature of chaos: nearby
   trajectories diverge at rate e^(lambda n); negative lambda means they
   converge onto a periodic attractor.

   LyapunovExponent discards `transient` iterations, averages over the
   next `nAverage`, and returns Max[floor, mean]. The floor exists for
   the lyapunov mode's sonification: at superstable parameters (x = 0.5
   on the cycle) the true exponent is -Infinity, and a finite average
   near them plunges arbitrarily low. |F'| is clamped at
   $MinMachineNumber before the Log because Log[0.] is Indeterminate,
   not -Infinity, in machine arithmetic. The orbit starts from SafeX0[x0]
   via AttractorPoints, as the rest of the app does. *)
LyapunovExponent[r_?NumericQ, Optional[x0_?NumericQ, 0.5],
                 Optional[transient_Integer, 1000], Optional[nAverage_Integer, 10000],
                 Optional[floor_?NumericQ, -0.5]] :=
  Module[{pts},
    pts = AttractorPoints[x0, r, transient, nAverage];
    Max[floor, Mean[Log[Max[Abs[r * (1.0 - 2.0 * #)], $MinMachineNumber]] & /@ pts]]
  ];

(* LyapunovSweep
   lambda at `steps` equally spaced r values from rMin to rMax (both
   ends included). Returns {{r1, lambda1}, {r2, lambda2}, ...}. *)
LyapunovSweep[rMin_?NumericQ, rMax_?NumericQ, steps_Integer,
              Optional[x0_?NumericQ, 0.5], Optional[transient_Integer, 1000],
              Optional[nAverage_Integer, 10000], Optional[floor_?NumericQ, -0.5]] :=
  Map[{#, LyapunovExponent[#, x0, transient, nAverage, floor]} &,
      N[Subdivide[rMin, rMax, steps - 1]]];

(* LyapunovZeroCrossings
   Sign changes of lambda between consecutive sweep points, located by
   linear interpolation between them — the same interpolation the
   lyapunov-mode audio uses for its glide, so the crossing time is exact
   for the audio. Returns a list of <|"r", "direction" ("upward" or
   "downward"), "index" (the step just before the crossing)|>. *)
LyapunovZeroCrossings[sweep_List] :=
  Module[{rs = sweep[[All, 1]], lams = sweep[[All, 2]], idx},
    idx = Flatten @ Position[Sign[Most[lams]] * Sign[Rest[lams]], -1];
    Map[
      <|"r" -> rs[[#]] - lams[[#]] * (rs[[# + 1]] - rs[[#]]) / (lams[[# + 1]] - lams[[#]]),
        "direction" -> If[lams[[# + 1]] > lams[[#]], "upward", "downward"],
        "index" -> #|> &,
      idx]
  ];

(* Period2LyapunovExact
   Closed-form lambda of the period-2 cycle: the two cycle points are
   x = ((r+1) +- Sqrt[(r+1)(r-3)]) / (2r), and lambda =
   0.5 Log|F'(x1) F'(x2)|. Valid for 3 < r < 1 + Sqrt[6]. *)
Period2LyapunovExact[r_?NumericQ] :=
  Module[{d, x1, x2},
    d  = Sqrt[(r + 1.0) * (r - 3.0)];
    x1 = ((r + 1.0) + d) / (2.0 * r);
    x2 = ((r + 1.0) - d) / (2.0 * r);
    0.5 * Log[Abs[r * (1.0 - 2.0 * x1) * r * (1.0 - 2.0 * x2)]]
  ];

(* LyapunovCheck — check 4, r = 4.0. For r = 4 exactly, lambda = log(2)
   analytically. Averages over the whole trajectory from x0 (no
   transient), as it has since the check was introduced. *)
LyapunovCheck[Optional[r_?NumericQ, 4.0], Optional[x0_?NumericQ, 0.5],
             Optional[nIter_Integer, 10000], Optional[tolerance_?NumericQ, 0.05]] :=
  Module[{traj, lambda, expected, relErr},
    traj     = IterateTrajectory[x0, r, nIter];
    lambda   = Mean[Log[Abs[r * (1.0 - 2.0 * #)]] & /@ Most[traj]];
    expected = Log[2.0];
    relErr   = Abs[lambda - expected] / expected;
    <|
      "lambda" -> lambda, "expected" -> expected, "relError" -> relErr,
      "pass" -> (lambda > 0 && relErr < tolerance)
    |>
  ];

(* LyapunovCurveCheck — check 5, the lambda(r) curve the lyapunov mode
   sonifies, at four r values with known answers:
     r = 2.8    fixed point, lambda = Log|2 - r| = Log[0.8]
     r = 3.2    period-2 cycle, lambda = Period2LyapunovExact[3.2]
     r = 3.835  inside the period-3 window, lambda < 0
     r = 4.0    lambda = Log[2]
   Uses LyapunovExponent with the mode's transient and averaging lengths
   but a floor of -100 rather than the mode's -0.5: the period-2 value
   at r = 3.2 is -0.916, below the sonification floor, and a floored
   value at r = 3.835 would be negative whatever the orbit did. *)
LyapunovCurveCheck[Optional[transient_Integer, 1000], Optional[nAverage_Integer, 10000],
                   Optional[tolerance_?NumericQ, 0.01]] :=
  Module[{lam, cases},
    lam[r_] := LyapunovExponent[r, 0.5, transient, nAverage, -100.0];
    cases = {
      <|"r" -> 2.8,   "lambda" -> lam[2.8],   "expected" -> Log[0.8],
        "what" -> "the fixed-point value Log[0.8]"|>,
      <|"r" -> 3.2,   "lambda" -> lam[3.2],   "expected" -> Period2LyapunovExact[3.2],
        "what" -> "the closed-form period-2 value 0.5 Log|f'(x1) f'(x2)|"|>,
      <|"r" -> 3.835, "lambda" -> lam[3.835], "expected" -> Missing["Negative"],
        "what" -> "inside the period-3 window it must be negative"|>,
      <|"r" -> 4.0,   "lambda" -> lam[4.0],   "expected" -> Log[2.0],
        "what" -> "the fully chaotic value Log[2]"|>
    };
    cases = Map[
      Append[#, "pass" -> If[NumericQ[#["expected"]],
        Abs[#["lambda"] - #["expected"]] < tolerance, #["lambda"] < 0]] &,
      cases];
    <|"cases" -> cases, "tolerance" -> tolerance,
      "pass" -> AllTrue[cases, #["pass"] &]|>
  ];


(* ── Divergence of two nearby orbits (divergence mode) ────────────────
   Sensitive dependence on initial conditions, the physical meaning of
   the Lyapunov exponent: two orbits at the same r, started at x0 and
   x0 + delta, separate (lambda > 0) or converge (lambda < 0) roughly as
   delta * e^(lambda n), until the separation saturates at the size of
   the attractor. *)

(* $divergenceSeparationFloor
   Separations below this are not used: converging orbits end on the same
   double, so the separation becomes exactly 0. (measured: from 1e-6 it
   reaches 0. by n = 150 at r = 2.8 and at r = 3.2), and Log[0.] is
   Indeterminate. 1e-12 is still about 10^4 units in the last place of an
   x near 0.5, so values above it are free of rounding. *)
$divergenceSeparationFloor = 10^-12;

(* DivergenceOrbits
   The two orbits (n + 1 values each, x_0 .. x_n) and their separation
   |x_n - y_n|. The orbits start exactly at x0 and x0 + delta — SafeX0 is
   not applied, since nudging one start would change delta. *)
DivergenceOrbits[r_?NumericQ, x0_?NumericQ, delta_?NumericQ, n_Integer] :=
  Module[{xs, ys},
    xs = NestList[LogisticMap[#, r] &, N[x0], n];
    ys = NestList[LogisticMap[#, r] &, N[x0 + delta], n];
    <|"r" -> r, "x0" -> x0, "delta" -> delta, "n" -> n,
      "x" -> xs, "y" -> ys, "separation" -> Abs[xs - ys]|>
  ];

(* DivergenceFit
   Least-squares line through Log[separation] against n, for n from 0 up
   to and including nSat, the first n at which the separation exceeds
   `saturation`. When it never does (lambda <= 0, or too few iterations),
   the fit runs to the last n before the separation first drops below
   `floor` ($divergenceSeparationFloor), or to the end of the list.
   The slope is a finite-time Lyapunov exponent, in nats per iteration.
   Returns <|"slope", "intercept", "nSat" (Missing[] when never
   saturated), "saturated", "nEnd" (last n in the fit)|>. *)
DivergenceFit[separations_List, saturation_?NumericQ,
              Optional[floor_?NumericQ, $divergenceSeparationFloor]] :=
  Module[{nSat, nLow, nEnd, ns, a, b},
    nSat = FirstPosition[separations, v_ /; v > saturation, {Missing[]}, {1}][[1]];
    nSat = If[IntegerQ[nSat], nSat - 1, Missing[]];
    nLow = FirstPosition[separations, v_ /; v < floor, {Missing[]}, {1}][[1]];
    nEnd = Which[
      IntegerQ[nSat], nSat,
      IntegerQ[nLow], nLow - 2,
      True,           Length[separations] - 1];
    ns = Range[0, Max[nEnd, 1]];
    {a, b} = LeastSquares[Transpose[{ConstantArray[1.0, Length[ns]], N[ns]}],
                          Log[Max[#, $MinMachineNumber] & /@ separations[[ns + 1]]]];
    <|"slope" -> b, "intercept" -> a, "nSat" -> nSat,
      "saturated" -> IntegerQ[nSat], "nEnd" -> Max[nEnd, 1]|>
  ];

(* DivergencePredictedSaturation
   Iterations for delta to grow to saturation at rate lambda:
   Log[saturation/delta]/lambda. Missing[] when lambda <= 0. *)
DivergencePredictedSaturation[lambda_?NumericQ, delta_?NumericQ, saturation_?NumericQ] :=
  If[lambda > 0, Log[saturation / delta] / lambda, Missing["NoGrowth"]];

(* AttractorPeriod — smallest period 1..64 of the attractor at r (from
   x0 = 0.5, 2000 transient iterations), else Missing[]. *)
AttractorPeriod[r_?NumericQ] :=
  Module[{pts = AttractorPoints[0.5, r, 2000, 128]},
    SelectFirst[Range[64], Max[Abs[pts[[# + 1 ;;]] - pts[[;; -# - 1]]]] < 10^-6 &, Missing[]]
  ];

(* DivergenceCase
   "chaotic", "edge", "periodic" or "stable" for an r without a preset:
   lambda > 0.05 is chaotic; otherwise an attractor of period 1 is
   stable, of period 2..64 periodic, and anything else (the accumulation
   of period doublings, lambda near 0) the edge of chaos. *)
DivergenceCase[r_?NumericQ, lambda_?NumericQ] :=
  Module[{period},
    If[lambda > 0.05, Return["chaotic"]];
    period = AttractorPeriod[r];
    Which[period === 1, "stable", IntegerQ[period], "periodic", True, "edge"]
  ];

(* DivergenceCheck — check 6.
   At r = 4.0 and r = 2.8, with delta = 1e-6 and saturation 0.1 from
   x0 = 0.3, the fitted slope must agree with LyapunovExponent (1000
   transient + 10000 averaged iterations, no floor) within 25 percent:
   Log[2] for growth at r = 4, Log[0.8] for shrinking at r = 2.8.

   Why 25 percent: a single pair of orbits followed for a few dozen
   iterations gives a finite-time exponent — the mean of Log|f'(x_n)|
   along that one short stretch of orbit — not the long-run average
   LyapunovExponent computes. It depends on where the orbit happens to
   be (measured: 0.671 against 0.693 at r = 4 over 18 iterations; at
   r = 3.2 the orbit first lingers near the unstable fixed point, where
   |f'| = 1.2, and the fit gives -0.40 against -0.92). 25 percent passes
   the finite-time scatter while still failing a wrong sign, a wrong
   base of logarithm (a factor of 2.3) or a missing factor of 2. *)
DivergenceCheck[Optional[x0_?NumericQ, 0.3], Optional[delta_?NumericQ, 10^-6],
                Optional[saturation_?NumericQ, 0.1], Optional[n_Integer, 150],
                Optional[tolerance_?NumericQ, 0.25]] :=
  Module[{cases},
    cases = Map[
      Function[{r},
        Module[{orb, fit, lam},
          orb = DivergenceOrbits[r, x0, delta, n];
          fit = DivergenceFit[orb["separation"], saturation];
          lam = LyapunovExponent[r, x0, 1000, 10000, -100.0];
          <|"r" -> r, "slope" -> fit["slope"], "lambda" -> lam, "fit" -> fit,
            "relError" -> Abs[fit["slope"] - lam] / Abs[lam],
            "pass" -> (Abs[fit["slope"] - lam] <= tolerance * Abs[lam])|>]],
      {4.0, 2.8}];
    <|"cases" -> cases, "tolerance" -> tolerance, "delta" -> delta,
      "saturation" -> saturation, "pass" -> AllTrue[cases, #["pass"] &]|>
  ];

(* ── Named presets (divergence mode) ────────────────────────────────
   The four cases of a talk sequence. Each sets only r (and the case, so
   the narration does not depend on the classifier); x0, delta,
   iterations, saturation and tempo come from simulation.dynamical.
   divergence, so all four render to the same length. *)
$divergencePresets = <|
  "divergence_chaotic"  -> <|"r" -> 4.0,  "case" -> "chaotic"|>,
  "divergence_edge"     -> <|"r" -> 3.57, "case" -> "edge"|>,
  "divergence_periodic" -> <|"r" -> 3.2,  "case" -> "periodic"|>,
  "divergence_stable"   -> <|"r" -> 2.8,  "case" -> "stable"|>
|>;


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

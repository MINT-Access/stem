(* ========================================================
   src/model.wl — Lorenz system ODE definition and solver

   The Lorenz equations (Lorenz, 1963):
       x'(t) = sigma * (y - x)
       y'(t) = x * (rho - z) - y
       z'(t) = x * y - beta * z

   Classic chaotic parameters: sigma=10, rho=28, beta=8/3.
   The solution forms a strange attractor — bounded but
   never periodic, sensitive to initial conditions.
   ======================================================== *)


(* SolveLorenz
   Input:  params — Association with keys:
             Sigma, Rho, Beta,
             InitX, InitY, InitZ,
             TimeEnd, TimeStep
   Output: list of {t, x, y, z} quadruples *)

SolveLorenz[params_Association] := Module[
  {sigma, rho, beta, x0, y0, z0, tEnd, dt, sol, times},

  sigma = params["Sigma"];
  rho   = params["Rho"];
  beta  = params["Beta"];
  x0    = params["InitX"];
  y0    = params["InitY"];
  z0    = params["InitZ"];
  tEnd  = params["TimeEnd"];
  dt    = params["TimeStep"];

  sol = NDSolve[
    {
      x'[t] == sigma * (y[t] - x[t]),
      y'[t] == x[t] * (rho - z[t]) - y[t],
      z'[t] == x[t] * y[t] - beta * z[t],
      x[0]  == x0,
      y[0]  == y0,
      z[0]  == z0
    },
    {x, y, z},
    {t, 0, tEnd},
    MaxStepSize -> dt
  ];

  times = Range[0, tEnd, dt];

  {#,
   x[#] /. sol[[1]],
   y[#] /. sol[[1]],
   z[#] /. sol[[1]]
  } & /@ times
]


(* SolveRossler
   The Rössler system (Rössler, 1976):
       x'(t) = -y - z
       y'(t) = x + a·y
       z'(t) = b + z·(x - c)

   With classic parameters a=0.2, b=0.2, c=5.7 the system
   produces a strange attractor with a characteristic slow
   outward spiral in the x-y plane and a sharp return via
   z-excursions.  Not stiff, so no special solver method.

   Input:  params — Association with keys:
             A, B, C,
             InitX, InitY, InitZ,
             TimeEnd, TimeStep
   Output: list of {t, x, y, z} quadruples (same structure
           as SolveLorenz, so the rest of the pipeline is
           attractor-agnostic). *)

SolveRossler[params_Association] :=
  Module[{a, b, c, x0, y0, z0, tEnd, dt, sol, times},

    a    = params["A"];
    b    = params["B"];
    c    = params["C"];
    x0   = params["InitX"];
    y0   = params["InitY"];
    z0   = params["InitZ"];
    tEnd = params["TimeEnd"];
    dt   = params["TimeStep"];

    sol = NDSolve[
      {
        x'[t] == -y[t] - z[t],
        y'[t] == x[t] + a * y[t],
        z'[t] == b + z[t] * (x[t] - c),
        x[0]  == x0,
        y[0]  == y0,
        z[0]  == z0
      },
      {x, y, z},
      {t, 0, tEnd},
      MaxStepSize -> dt
    ];

    times = Range[0, tEnd, dt];

    {#,
     x[#] /. sol[[1]],
     y[#] /. sol[[1]],
     z[#] /. sol[[1]]
    } & /@ times
  ]


(* SolveLorenzPair
   Solves two trajectories with nearly identical initial conditions.
   Used to demonstrate sensitive dependence (butterfly effect).
   epsilon — tiny perturbation added to InitX of the second trajectory.
   Returns {solution1, solution2}. *)

SolveLorenzPair[params_Association, epsilon_:0.001] := Module[
  {params2},
  params2 = ReplacePart[params,
    Key["InitX"] -> params["InitX"] + epsilon];
  {SolveLorenz[params], SolveLorenz[params2]}
]


(* LorenzDivergence
   Computes Euclidean distance between two trajectories at each time step.
   Input:  sol1, sol2 — outputs of SolveLorenz
   Output: list of {t, distance} pairs *)

LorenzDivergence[sol1_List, sol2_List] :=
  MapThread[
    {#1[[1]],
     Sqrt[
       (#1[[2]] - #2[[2]])^2 +
       (#1[[3]] - #2[[3]])^2 +
       (#1[[4]] - #2[[4]])^2
     ]
    } &,
    {sol1, sol2}
  ]


(* ────────────────────────────────────────────────────────────
   Correctness checks — diagnostic-only (print PASS/FAIL, never
   abort), per blackbody/AGENTS.md §3. `lorenz` and `rossler` have
   genuinely different mathematical structure (Lorenz's phase-space
   divergence is position-independent; Rossler's is not), so checks
   are NOT assumed to transfer between systems without verification
   — see AGENTS.md for what was actually checked before writing
   these.
   ──────────────────────────────────────────────────────────── *)

(* Check 1 (exact, but a DIFFERENT claim per system) — phase-space
   divergence nabla.f = d(fx)/dx + d(fy)/dy + d(fz)/dz. For Lorenz this
   is position-INDEPENDENT, equal to -(sigma+1+beta) everywhere; for
   Rossler it is NOT constant, equal to a+x-c (genuinely depends on
   x — verified symbolically before writing this check, see AGENTS.md).
   Both LorenzDivergenceCheck and RosslerDivergenceCheck redefine their
   system's fx,fy,fz symbolically (the same functional form
   SolveLorenz/SolveRossler's NDSolve equations use) and take the
   partial derivatives via D[], rather than hardcoding either closed
   form as the computation itself — an independent calculus check of
   the claimed formula, not a restatement of it. Evaluated at several
   ARBITRARY (x,y,z) points, not points on the attractor, since neither
   claim says anything special about the attractor itself. Do NOT
   write a "constant divergence" check for Rossler — that claim is
   simply false for it; RosslerDivergenceCheck instead verifies the
   position-DEPENDENT formula holds at each test point independently
   (not that the values agree with each other, which they should not). *)
LorenzDivergenceAt[a_?NumericQ, b_?NumericQ, c_?NumericQ,
                   sigma_?NumericQ, rho_?NumericQ, beta_?NumericQ] :=
  Module[{xs, ys, zs, fx, fy, fz},
    fx = sigma * (ys - xs);
    fy = xs * (rho - zs) - ys;
    fz = xs * ys - beta * zs;
    (D[fx, xs] + D[fy, ys] + D[fz, zs]) /. {xs -> a, ys -> b, zs -> c}
  ];

LorenzDivergenceCheck[sigma_?NumericQ, rho_?NumericQ, beta_?NumericQ,
                      nTest_Integer:6, tolerance_:10^-9] :=
  Module[{testPoints, divergences, expected, maxErr},
    testPoints = {{0.0, 0.0, 0.0}, {10.0, -10.0, 20.0}, {-15.0, 25.0, 5.0},
                  {1.0, 1.0, 1.0}, {-30.0, -30.0, 50.0}, {7.5, -12.3, 33.1}}[[1 ;; nTest]];
    divergences = Map[LorenzDivergenceAt[#[[1]], #[[2]], #[[3]], sigma, rho, beta] &, testPoints];
    expected = -(sigma + 1.0 + beta);
    maxErr = Max[Abs[divergences - expected]];
    <| "testPoints" -> testPoints, "divergences" -> divergences,
       "expected" -> expected, "maxError" -> maxErr, "pass" -> maxErr < tolerance |>
  ];

RosslerDivergenceAt[a_?NumericQ, b_?NumericQ, c_?NumericQ,
                    aP_?NumericQ, bP_?NumericQ, cP_?NumericQ] :=
  Module[{xs, ys, zs, gx, gy, gz},
    gx = -ys - zs;
    gy = xs + aP * ys;
    gz = bP + zs * (xs - cP);
    (D[gx, xs] + D[gy, ys] + D[gz, zs]) /. {xs -> a, ys -> b, zs -> c}
  ];

RosslerDivergenceCheck[aP_?NumericQ, bP_?NumericQ, cP_?NumericQ,
                       nTest_Integer:6, tolerance_:10^-9] :=
  Module[{testPoints, divergences, expectedPerPoint, maxErr},
    testPoints = {{0.0, 0.0, 0.0}, {10.0, -10.0, 20.0}, {-15.0, 25.0, 5.0},
                  {1.0, 1.0, 1.0}, {-30.0, -30.0, 50.0}, {7.5, -12.3, 33.1}}[[1 ;; nTest]];
    divergences = Map[RosslerDivergenceAt[#[[1]], #[[2]], #[[3]], aP, bP, cP] &, testPoints];
    expectedPerPoint = Map[aP + #[[1]] - cP &, testPoints];
    maxErr = Max[Abs[divergences - expectedPerPoint]];
    <| "testPoints" -> testPoints, "divergences" -> divergences,
       "expectedPerPoint" -> expectedPerPoint, "maxError" -> maxErr, "pass" -> maxErr < tolerance |>
  ];


(* Check 2 (both systems, exact) — known equilibria satisfy f=0. *)
LorenzRHSAt[{x_?NumericQ, y_?NumericQ, z_?NumericQ},
           sigma_?NumericQ, rho_?NumericQ, beta_?NumericQ] :=
  {sigma * (y - x), x * (rho - z) - y, x * y - beta * z};

(* LorenzEquilibriumCheck — origin (trivial) plus the nonzero pair
   C+/C- = (+-Sqrt[beta(rho-1)], +-Sqrt[beta(rho-1)], rho-1), the more
   informative equilibria (they exist only for rho>1, and are exactly
   the two points the strange attractor's two "wings" wind around for
   rho>24.74). *)
LorenzEquilibriumCheck[sigma_?NumericQ, rho_?NumericQ, beta_?NumericQ,
                       tolerance_:10^-8] :=
  Module[{originVal, r, cPlus, cMinus, cPlusVal, cMinusVal, maxErr},
    originVal = LorenzRHSAt[{0.0, 0.0, 0.0}, sigma, rho, beta];
    r      = Sqrt[beta * (rho - 1.0)];
    cPlus  = {r, r, rho - 1.0};
    cMinus = {-r, -r, rho - 1.0};
    cPlusVal  = LorenzRHSAt[cPlus, sigma, rho, beta];
    cMinusVal = LorenzRHSAt[cMinus, sigma, rho, beta];
    maxErr = Max[Abs[Join[originVal, cPlusVal, cMinusVal]]];
    <| "origin" -> originVal, "cPlus" -> cPlus, "cPlusVal" -> cPlusVal,
       "cMinus" -> cMinus, "cMinusVal" -> cMinusVal,
       "maxError" -> maxErr, "pass" -> maxErr < tolerance |>
  ];

RosslerRHSAt[{x_?NumericQ, y_?NumericQ, z_?NumericQ},
            a_?NumericQ, b_?NumericQ, c_?NumericQ] :=
  {-y - z, x + a * y, b + z * (x - c)};

(* RosslerEquilibriumCheck — derived (not assumed) from setting all
   three RHS components to zero: -y-z=0 => z=-y; x+a*y=0 => y=-x/a
   (so z=x/a); substituting into b+z(x-c)=0 gives a quadratic in x,
   a*x^2 - c*x + a*b == 0 (equivalently the y-quadratic
   a*y^2+c*y+b==0 falls out the same way — verified both forms agree
   via WL's own Solve before writing this closed form), with roots
   x = (c +- Sqrt[c^2-4ab])/2. *)
RosslerEquilibria[a_?NumericQ, b_?NumericQ, c_?NumericQ] :=
  Module[{disc, xPlus, xMinus},
    disc   = c^2 - 4.0 * a * b;
    xPlus  = (c + Sqrt[disc]) / 2.0;
    xMinus = (c - Sqrt[disc]) / 2.0;
    {{xPlus, -xPlus / a, xPlus / a}, {xMinus, -xMinus / a, xMinus / a}}
  ];

RosslerEquilibriumCheck[a_?NumericQ, b_?NumericQ, c_?NumericQ, tolerance_:10^-6] :=
  Module[{equilibria, vals, maxErr},
    equilibria = RosslerEquilibria[a, b, c];
    vals   = RosslerRHSAt[#, a, b, c] & /@ equilibria;
    maxErr = Max[Abs[Flatten[vals]]];
    <| "equilibria" -> equilibria, "vals" -> vals,
       "maxError" -> maxErr, "pass" -> maxErr < tolerance |>
  ];


(* Check 3 (both systems, empirical benchmark, generous tolerance) —
   largest Lyapunov exponent via Benettin's renormalization method:
   integrate a reference and a perturbed trajectory forward by a
   fixed short interval, measure the perturbation's growth factor,
   renormalize it back to the original small size (keeping its new
   direction), repeat, and average the log-growth rate over many
   renormalization steps. A NAIVE single-perturbation growth-rate fit
   (integrate once, measure once) is NOT reliable here — verified
   this empirically while building this check: an early attempt
   without periodic renormalization was sensitive to the initial
   transient before the perturbation aligns with the dominant
   Lyapunov direction, and underestimated lambda1 substantially.
   A FIXED (not random) initial perturbation direction converges
   just as reliably as a random one, since Benettin's method aligns
   any generic direction with the dominant Lyapunov direction within
   a handful of renormalization steps — verified across multiple
   random seeds and a fixed direction while calibrating dtRenorm/
   nSteps below; using a fixed direction makes this check fully
   deterministic (no SeedRandom needed). *)
BenettinLyapunov[stepFn_, state0_List, dtRenorm_?NumericQ, nSteps_Integer, d0_?NumericQ] :=
  Module[{ref, pert, sumLog = 0.0, refNext, pertNext, d1, dir},
    ref  = state0;
    pert = state0 + d0 * Normalize[{1.0, 0.0, 0.0}];
    Do[
      refNext  = stepFn[ref, dtRenorm];
      pertNext = stepFn[pert, dtRenorm];
      d1  = Norm[pertNext - refNext];
      sumLog += Log[d1 / d0];
      dir  = (pertNext - refNext) / d1;
      ref  = refNext;
      pert = refNext + d0 * dir,
      {nSteps}
    ];
    sumLog / (nSteps * dtRenorm)
  ];

(* Single-step integrators for BenettinLyapunov, dt-parametrised
   (independent of SolveLorenz/SolveRossler's own fixed-TimeEnd
   solvers — these integrate a short, caller-chosen dt each call). *)
LorenzStep[state_List, dt_?NumericQ, sigma_?NumericQ, rho_?NumericQ, beta_?NumericQ] :=
  Module[{x0, y0, z0, sol},
    {x0, y0, z0} = state;
    sol = NDSolve[
      {x'[t] == sigma * (y[t] - x[t]), y'[t] == x[t] * (rho - z[t]) - y[t],
       z'[t] == x[t] * y[t] - beta * z[t], x[0] == x0, y[0] == y0, z[0] == z0},
      {x, y, z}, {t, 0, dt}, MaxStepSize -> dt / 20.0];
    {x[dt], y[dt], z[dt]} /. First[sol]
  ];

RosslerStep[state_List, dt_?NumericQ, a_?NumericQ, b_?NumericQ, c_?NumericQ] :=
  Module[{x0, y0, z0, sol},
    {x0, y0, z0} = state;
    sol = NDSolve[
      {x'[t] == -y[t] - z[t], y'[t] == x[t] + a * y[t], z'[t] == b + z[t] * (x[t] - c),
       x[0] == x0, y[0] == y0, z[0] == z0},
      {x, y, z}, {t, 0, dt}, MaxStepSize -> dt / 20.0];
    {x[dt], y[dt], z[dt]} /. First[sol]
  ];

(* LorenzLyapunovCheck — settles onto the attractor (20 time-unit
   transient from (1,1,1)) before renormalizing, dtRenorm/nSteps
   calibrated across 3 fixed-direction and 3 random-direction trials
   to converge consistently to within ~3% of the commonly-cited
   lambda1~0.905 (sigma=10,rho=28,beta=8/3) — generous 30% tolerance
   deliberately, since this is an empirical literature comparison,
   not an exact relation (contrast with checks 1-2's tight
   tolerances). *)
LorenzLyapunovCheck[sigma_?NumericQ, rho_?NumericQ, beta_?NumericQ,
                    Optional[benchmark_?NumericQ, 0.905], Optional[tolerance_?NumericQ, 0.30]] :=
  Module[{start, lambda1, relErr},
    start   = LorenzStep[{1.0, 1.0, 1.0}, 20.0, sigma, rho, beta];
    lambda1 = BenettinLyapunov[LorenzStep[#1, #2, sigma, rho, beta] &, start, 0.2, 400, 10^-8];
    relErr  = Abs[lambda1 - benchmark] / benchmark;
    <| "lambda1" -> lambda1, "benchmark" -> benchmark, "relError" -> relErr,
       "pass" -> lambda1 > 0 && relErr < tolerance |>
  ];

(* RosslerLyapunovCheck — same method, different transient/renormal-
   ization timescale: Rossler's slow spiral-and-fold dynamics need a
   longer settle time (100 vs 20 time units) and a longer
   renormalization interval (dtRenorm=2.0 vs 0.2) to converge —
   verified empirically: dtRenorm=1.0 gave noisier, seed-dependent
   estimates (~0.065-0.094 spread), while dtRenorm=2.0 converged
   consistently to ~0.065-0.069 across both fixed and random initial
   perturbation directions, matching the commonly-cited lambda1~0.07
   (a=b=0.2,c=5.7) within the same generous tolerance. *)
RosslerLyapunovCheck[a_?NumericQ, b_?NumericQ, c_?NumericQ,
                     Optional[benchmark_?NumericQ, 0.07], Optional[tolerance_?NumericQ, 0.30]] :=
  Module[{start, lambda1, relErr},
    start   = RosslerStep[{1.0, 1.0, 1.0}, 100.0, a, b, c];
    lambda1 = BenettinLyapunov[RosslerStep[#1, #2, a, b, c] &, start, 2.0, 400, 10^-8];
    relErr  = Abs[lambda1 - benchmark] / benchmark;
    <| "lambda1" -> lambda1, "benchmark" -> benchmark, "relError" -> relErr,
       "pass" -> lambda1 > 0 && relErr < tolerance |>
  ];


(* Check 4 (both systems, sanity) — trajectory stays bounded: no
   Overflow[]/Underflow[]/Indeterminate/ComplexInfinity anywhere in
   the solution, and no coordinate exceeds a generous magnitude limit.
   NOTE: Overflow[] passes BOTH NumericQ and NumberQ as True in WL —
   a naive `Max[Abs[...]] < limit` comparison would silently fail to
   catch it (the comparison itself stays unevaluated rather than
   returning True/False), discovered and worked around in henon/'s
   own TrajectoryIsBounded. FreeQ against the literal head is what
   actually catches it, checked first. *)
TrajectoryBoundedCheck[solution_List, limit_:1000] :=
  Module[{allCoords = Flatten[solution[[All, 2 ;; 4]]]},
    <| "pass" ->
      FreeQ[allCoords, Overflow[] | Underflow[] | Indeterminate | ComplexInfinity | DirectedInfinity[___]] &&
      Max[Abs[allCoords]] < limit |>
  ];

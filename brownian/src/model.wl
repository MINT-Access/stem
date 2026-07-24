(* ========================================================
   brownian/src/model.wl — Brownian motion: the random walk,
   the diffusion coefficient, and four correctness checks.

   Robert Brown observed pollen grains jiggling erratically in water
   in 1827; Einstein (1905) showed the motion was the visible signature
   of countless invisible collisions with individual water molecules —
   direct evidence for the molecular-kinetic theory of heat at a time
   when the physical reality of atoms was still disputed. Jean Perrin's
   1908-1909 experiments quantitatively confirmed Einstein's
   predictions (Perrin, Nobel Prize 1926).

   Each small time step dt, a particle's displacement in x and y is an
   independent draw from Normal(0, sqrt(2 D dt)), D the diffusion
   coefficient. A sum of independent Gaussians is EXACTLY Gaussian (not
   just asymptotically, unlike clt/'s general sources — see check 3),
   so x(t), y(t) ~ Normal(0, 2Dt) exactly, and <r^2(t)> = 4Dt exactly.
   ======================================================== *)


(* $kB — Boltzmann constant, J/K. Exact by the 2019 SI redefinition
   (not measured, not rounded — this is the DEFINED value). *)
$kB = 1.380649*^-23;


(* StokesEinsteinD — diffusion coefficient of a sphere of radius
   rParticle (m) in a fluid of viscosity eta (Pa s) at temperature T
   (K). SI units throughout (D in m^2/s). Real simplification, stated
   here and in README.md/AGENTS.md: water's own viscosity is itself
   temperature-dependent (it drops by a FACTOR OF ~2.7, not merely
   "halving", from 0C to 40C — see AGENTS.md for the corrected figure
   and where the original build note's "roughly halving" undersold
   it); `temperature` mode holds eta fixed while sweeping T, rather
   than also modelling eta(T). *)
StokesEinsteinD[T_?NumericQ, eta_?NumericQ, rParticle_?NumericQ] :=
  $kB * T / (6.0 * Pi * eta * rParticle);


(* NetDisplacementSample — nWalkers independent final (x,y)
   displacements after nSteps steps of size dt each, diffusion
   coefficient D. Actually accumulates nSteps individual Gaussian
   draws per walker (Total along the step axis) rather than shortcutting
   through the closed-form single-draw Normal(0, sigma*Sqrt[nSteps]) —
   this is what makes the correctness checks below genuine validations
   of the step-generation code, not restatements of the math it's
   supposed to reproduce. Returns {xVals, yVals}, each length nWalkers. *)
NetDisplacementSample[nWalkers_Integer, nSteps_Integer, D_?NumericQ, dt_?NumericQ] :=
  Module[{sigma, dx, dy},
    sigma = Sqrt[2.0 * D * dt];
    dx = RandomVariate[NormalDistribution[0.0, sigma], {nWalkers, nSteps}];
    dy = RandomVariate[NormalDistribution[0.0, sigma], {nWalkers, nSteps}];
    {Total[dx, {2}], Total[dy, {2}]}
  ];


(* WalkTrajectory — a single 2D random walk, nSteps steps of size dt,
   diffusion coefficient D. Returns the FULL path (not just the
   endpoint) as an {nSteps+1} x 4 table of {t,x,y,r}, t starting at 0.
   Used by `walk` mode's continuous-trajectory sonification and by
   `temperature` mode's short representative snippets. *)
WalkTrajectory[nSteps_Integer, D_?NumericQ, dt_?NumericQ] :=
  Module[{sigma, dx, dy, x, y, r, t},
    sigma = Sqrt[2.0 * D * dt];
    dx = RandomVariate[NormalDistribution[0.0, sigma], nSteps];
    dy = RandomVariate[NormalDistribution[0.0, sigma], nSteps];
    x = Prepend[Accumulate[dx], 0.0];
    y = Prepend[Accumulate[dy], 0.0];
    r = Sqrt[x^2 + y^2];
    t = N[Range[0, nSteps]] * dt;
    Transpose[{t, x, y, r}]
  ];


(* EnsembleModel — nWalkers independent walks of nSteps steps each,
   diffusion coefficient D, step duration dt. Computes the REAL,
   empirical ensemble mean-squared-displacement at every time step
   (not the 4Dt formula) — this is what `ensemble` mode sonifies, and
   what makes its "displacement grows as sqrt(t)" audible signature an
   actual Monte Carlo result rather than a plotted equation. Also keeps
   a handful of individual walker paths for the animation's faint
   individual-walker overlay (echoing thermo/ensemble's own
   individual-vs-aggregate contrast). *)
EnsembleModel[nWalkers_Integer, nSteps_Integer, D_?NumericQ, dt_?NumericQ,
             nSamplePaths_Integer:8] :=
  Module[{sigma, allDx, allDy, allX, allY, allR2, msd, rms, t, samplePaths},
    sigma = Sqrt[2.0 * D * dt];
    allDx = RandomVariate[NormalDistribution[0.0, sigma], {nWalkers, nSteps}];
    allDy = RandomVariate[NormalDistribution[0.0, sigma], {nWalkers, nSteps}];
    allX = Prepend[#, 0.0] & /@ Accumulate /@ allDx;
    allY = Prepend[#, 0.0] & /@ Accumulate /@ allDy;
    allR2 = allX^2 + allY^2;
    msd = Mean[allR2];
    rms = Sqrt[msd];
    t = N[Range[0, nSteps]] * dt;
    samplePaths = Table[Transpose[{allX[[k]], allY[[k]]}], {k, Min[nSamplePaths, nWalkers]}];
    <|
      "t" -> t, "msd" -> msd, "rms" -> rms,
      "nWalkers" -> nWalkers, "nSteps" -> nSteps, "D" -> D, "dt" -> dt,
      "samplePaths" -> samplePaths
    |>
  ];


(* ────────────────────────────────────────────────────────────
   Correctness checks — diagnostic-only (print PASS/FAIL, never
   abort), per blackbody/AGENTS.md §3 as corrected in
   compton/AGENTS.md. All four exercise the ACTUAL Monte Carlo
   step-generation code (NetDisplacementSample), not a restatement
   of the formulas they validate.
   ──────────────────────────────────────────────────────────── *)


(* Check 1 — <r^2(t)> = 4Dt, the mean-squared-displacement formula,
   tested at a single specific time via a real ensemble. Tolerance
   calibrated across 5 seeds at nWalkers=50000, nSteps=200: relative
   error never exceeded ~0.63%, so a 5% tolerance has ample margin
   without being vacuous. *)
MSDScalingCheck[D_?NumericQ, dt_?NumericQ, nSteps_Integer:200,
                nWalkers_Integer:50000, tolerance_:0.05] :=
  Module[{x, y, r2, empMSD, t, predicted, relErr},
    SeedRandom[42];
    {x, y} = NetDisplacementSample[nWalkers, nSteps, D, dt];
    r2 = x^2 + y^2;
    empMSD = Mean[r2];
    t = N[nSteps] * dt;
    predicted = 4.0 * D * t;
    relErr = Abs[empMSD - predicted] / predicted;
    <| "empMSD" -> empMSD, "predicted" -> predicted, "t" -> t,
       "relError" -> relErr, "pass" -> relErr < tolerance |>
  ];


(* Check 2 — Stokes-Einstein produces physically realistic numbers.
   At representative micron-particle, room-temperature, water-
   viscosity parameters (r=1 micron, T=293.15K, eta=1e-3 Pa s), D
   should land in the well-known ~1e-13 to 1e-12 m^2/s range for
   Brownian motion of micron-sized particles in water (verified here:
   D ~ 2.15e-13 m^2/s at these exact parameters) — the same "does this
   produce physically real numbers" spirit as blackbody/star mode's
   realistic-stellar-scale sanity check. *)
StokesEinsteinScaleCheck[] :=
  Module[{T = 293.15, eta = 1.0*^-3, rParticle = 1.0*^-6, D},
    D = StokesEinsteinD[T, eta, rParticle];
    <| "T" -> T, "eta" -> eta, "rParticle" -> rParticle, "D" -> D,
       "pass" -> (1.0*^-13 <= D <= 1.0*^-12) |>
  ];


(* Check 3 — exact-zero excess kurtosis of the net displacement, even
   at SMALL N. Unlike clt/'s general sources (KurtosisDecayCheck),
   where excess kurtosis only decays asymptotically as
   (source kurtosis)/N, a sum of iid GAUSSIAN steps is exactly Gaussian
   at every N >= 1 — its excess kurtosis should already be
   (statistically) zero at N=8, not merely closer to zero than at N=1.
   This is a genuinely different and stronger claim than clt/'s check:
   clt/'s own KurtosisDecayCheck at N=30 with a uniform source predicts
   (and finds) excess kurtosis around -1.2/30 ~= -0.04, clearly nonzero
   — here, at a much smaller N=8, the prediction is exactly 0. Tolerance
   (0.03 absolute) calibrated across 5 seeds at nWalkers=500000: the
   empirical value never exceeded ~0.011 in magnitude, comfortably
   inside Fisher's asymptotic standard-error estimate for a kurtosis
   statistic (sqrt(24/n) ~= 0.007 at this sample size) times ~4. *)
ExactGaussianKurtosisCheck[D_?NumericQ, dt_?NumericQ, nSteps_Integer:8,
                          nWalkers_Integer:500000, tolerance_:0.03] :=
  Module[{x, y, empKurt},
    SeedRandom[43];
    {x, y} = NetDisplacementSample[nWalkers, nSteps, D, dt];
    empKurt = Kurtosis[x] - 3.0;
    <| "nSteps" -> nSteps, "empKurt" -> empKurt, "pass" -> Abs[empKurt] < tolerance |>
  ];


(* Check 4 — RMS(t) grows as sqrt(t), NOT linearly in t (the "wrong"
   alternative a naive ballistic-motion intuition would predict).
   Compares RMS at two different step counts (a factor of 4 apart, so
   the predicted ratio is a clean sqrt(4)=2) via a fresh ensemble at
   each. This tests the SHAPE of the growth curve, distinct from check
   1's single-point magnitude match. Tolerance calibrated across 5
   seeds: relative error never exceeded ~0.53%. *)
SqrtGrowthCheck[D_?NumericQ, dt_?NumericQ, nSteps1_Integer:250, nSteps2_Integer:1000,
               nWalkers_Integer:50000, tolerance_:0.05] :=
  Module[{x1, y1, x2, y2, rms1, rms2, ratio, predicted, relErr},
    SeedRandom[44];
    {x1, y1} = NetDisplacementSample[nWalkers, nSteps1, D, dt];
    {x2, y2} = NetDisplacementSample[nWalkers, nSteps2, D, dt];
    rms1 = Sqrt[Mean[x1^2 + y1^2]];
    rms2 = Sqrt[Mean[x2^2 + y2^2]];
    ratio = rms2 / rms1;
    predicted = Sqrt[N[nSteps2] / N[nSteps1]];
    relErr = Abs[ratio - predicted] / predicted;
    <| "ratio" -> ratio, "predicted" -> predicted, "relError" -> relErr,
       "pass" -> relErr < tolerance |>
  ];

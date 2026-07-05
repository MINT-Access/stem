(* ========================================================
   scattering/src/model.wl — Rutherford alpha-particle scattering

   Scaled units throughout (see AGENTS.md): the head-on (b=0)
   distance of closest approach d = k*q1*q2/(2E) is set to 1, and the
   asymptotic speed v_inf is set to 1. With m=1 (dimensionless, same
   convention as magnetic/ and lagrange/), the conserved specific
   energy is exactly 1/2 and the conserved specific angular momentum
   is exactly b (the impact parameter itself):

     (1/2)(rDot^2 + r^2 phiDot^2) + 1/r = 1/2      (energy)
     r^2 phiDot = b                                 (angular momentum)

   which combine to the radial equation of motion used below:
     r'' = r*phi'^2 + 1/r^2,   phi' = b/r^2

   NOTE the +1/r^2 (not -1/r^2): this is a REPULSIVE Coulomb force
   (V(r)=+1/r, matching the energy equation above and the r_min
   formula below). The build spec's own text gives this as
   "r'' - r*phi'^2 = -1/r^2" -- the standard ATTRACTIVE (Kepler)
   radial equation sign, not the repulsive one. Using it as written
   fails the energy-conservation check (verified: max deviation ~0.58
   from the supposedly-conserved 0.5, and a ~6 deg error in the
   measured vs analytic scattering angle) because it integrates the
   wrong force direction. See AGENTS.md design decision 7.

   Scattering angle (analytic, exact): theta = 2*ArcCot[b]  (d=1)
   Distance of closest approach:       r_min = 1 + Sqrt[1 + b^2]

   Public API:
     RutherfordFormulaCheck[]   -- check 1 (fixed b=1 -> theta=90 deg)
     ScatterModel[cfg]          -- scatter mode: NDSolve trajectory,
                                    checks 2 (angular momentum) and 3
                                    (energy conservation)
     DistributionModel[cfg]     -- distribution mode: beam of impact
                                    parameters, check 4 (cross-section)
     DiscoveryModel[cfg]        -- discovery mode: Thomson vs Rutherford
                                    angle distributions, same random
                                    seed for both channels
   ======================================================== *)


(* ── Check 1: Rutherford formula, b=1 -> theta=90 deg exactly ──────
   cot(theta/2) = b/d = 1/1 = 1  =>  theta/2 = Pi/4  =>  theta = Pi/2. *)
RutherfordFormulaCheck[] :=
  Module[{thetaDeg, err, pass},
    thetaDeg = 2.0 * ArcCot[1.0] * 180.0 / Pi;
    err  = Abs[thetaDeg - 90.0];
    pass = err < 0.01;
    Print["  [", If[pass, "PASS", "FAIL"], "] Rutherford formula: b=1.0 (scaled) gives theta=",
      FmtN[thetaDeg, {6, 4}], " deg vs expected 90.0 deg (within 0.01 deg)"];
    <| "thetaDeg" -> thetaDeg, "err" -> err, "pass" -> pass |>
  ]


(* ========================================================
   SCATTER MODE — single trajectory, NDSolve in polar coordinates
   ======================================================== *)

ScatterModel[cfg_Association] :=
  Module[{
    b, rInit, nPts, d, thetaAnalyticRad, thetaAnalyticDeg, rMin,
    rInitEff, phi0, phiDot0, especific, rDot0sq, rDot0, rDot0Clipped,
    maxStep, tMaxCap, sol, rFn, phiFn, tActual,
    tArr, rArr, phiArr, rDotArr, phiDotArr, xArr, yArr, speedArr,
    idxPeriapsis, tPeriapsis, rAtPeriapsis,
    vxInit, vyInit, vxFinal, vyFinal, thetaMeasuredDeg,
    checkIdx, LArr, angMomAbsErr, angMomPass,
    EArr, energyAbsErr, energyPass
  },

    b     = N @ GetCfg[cfg, {"simulation", "scattering", "b"},          1.0];
    rInit = N @ GetCfg[cfg, {"simulation", "scattering", "r_initial"}, 20.0];
    nPts  =     GetCfg[cfg, {"simulation", "scattering", "n_points"},   500];

    d = 1.0;
    thetaAnalyticRad = 2.0 * ArcCot[b];
    thetaAnalyticDeg = thetaAnalyticRad * 180.0 / Pi;
    rMin = d + Sqrt[d^2 + b^2];

    (* Safety margin on r_initial: the incoming asymptote is only valid
       once the b/r^2 (angular) and 1/r (potential) terms are small
       compared to the total specific energy (1/2); for large b this
       needs more room than the configured r_initial may provide. *)
    rInitEff = Max[rInit, 3.0 * b + 5.0];
    If[rInitEff > rInit,
      Print["  [note] r_initial raised from ", FmtN[rInit, {5, 2}], " to ",
        FmtN[rInitEff, {5, 2}], " to keep the incoming asymptote valid for b=",
        FmtN[b, {5, 2}]]
    ];

    phi0      = Pi;
    phiDot0   = b / rInitEff^2;
    especific = 0.5;
    rDot0sq   = 1.0 - 2.0 / rInitEff - (b / rInitEff)^2;
    rDot0Clipped = rDot0sq < 1.0*^-6;
    rDot0     = -Sqrt[Max[rDot0sq, 1.0*^-6]];
    If[rDot0Clipped,
      Print["  [WARNING] initial radial speed-squared clipped to a small positive floor -- ",
        "r_initial is too small for this b; increase r_initial."]
    ];

    maxStep = Clip[rMin / 25.0, {0.005, 2.0}];
    tMaxCap = 10.0 * rInitEff + 100.0;

    sol = Quiet @ NDSolve[
      {r''[t] == r[t] * phi'[t]^2 + 1.0 / r[t]^2,
       phi'[t] == b / r[t]^2,
       r[0] == rInitEff, r'[0] == rDot0, phi[0] == phi0,
       WhenEvent[r[t] > rInitEff && r'[t] > 0, "StopIntegration"]},
      {r, phi}, {t, 0, tMaxCap},
      MaxStepSize -> maxStep, PrecisionGoal -> 10, AccuracyGoal -> 10
    ];

    {rFn, phiFn} = {r, phi} /. First[sol];
    tActual = rFn["Domain"][[1, 2]];

    tArr     = N @ Subdivide[0.0, tActual, nPts - 1];
    rArr     = rFn /@ tArr;
    phiArr   = phiFn /@ tArr;
    rDotArr  = (rFn') /@ tArr;
    phiDotArr = (phiFn') /@ tArr;
    xArr     = rArr * Cos[phiArr];
    yArr     = rArr * Sin[phiArr];
    speedArr = Sqrt[rDotArr^2 + (rArr * phiDotArr)^2];

    idxPeriapsis = First[Ordering[rArr, 1]];
    tPeriapsis   = tArr[[idxPeriapsis]];
    rAtPeriapsis = rArr[[idxPeriapsis]];

    (* Measured scattering angle: angle between initial and final
       velocity vectors (not the polar angle swept -- see AGENTS.md). *)
    vxInit  = rDotArr[[1]] * Cos[phiArr[[1]]] - rArr[[1]] * phiDotArr[[1]] * Sin[phiArr[[1]]];
    vyInit  = rDotArr[[1]] * Sin[phiArr[[1]]] + rArr[[1]] * phiDotArr[[1]] * Cos[phiArr[[1]]];
    vxFinal = rDotArr[[-1]] * Cos[phiArr[[-1]]] - rArr[[-1]] * phiDotArr[[-1]] * Sin[phiArr[[-1]]];
    vyFinal = rDotArr[[-1]] * Sin[phiArr[[-1]]] + rArr[[-1]] * phiDotArr[[-1]] * Cos[phiArr[[-1]]];
    thetaMeasuredDeg = VectorAngle[{vxInit, vyInit}, {vxFinal, vyFinal}] * 180.0 / Pi;

    Print["-- Scatter parameters --"];
    STEMPrintN["Impact parameter b",            b,                "(scaled)", {6, 4}];
    STEMPrintN["Analytic scattering angle",     thetaAnalyticDeg,  "deg",     {6, 3}];
    STEMPrintN["Measured scattering angle",     thetaMeasuredDeg,  "deg",     {6, 3}];
    STEMPrintN["Distance of closest approach",  rMin,              "(scaled)", {6, 4}];
    Print[""];

    (* Check 2: angular momentum conservation, r^2*phi' == b, sampled
       at 10 points across the trajectory. Absolute (not relative)
       tolerance scaled to Max[|b|,1] so the b=0 (backscatter) case,
       where L is identically zero, is handled without dividing by zero. *)
    checkIdx = Round[N @ Subdivide[1, nPts, 9]];
    LArr = rArr[[checkIdx]]^2 * phiDotArr[[checkIdx]];
    angMomAbsErr = Max[Abs[LArr - b]];
    angMomPass = angMomAbsErr < 0.001 * Max[Abs[b], 1.0];
    Print["  [", If[angMomPass, "PASS", "FAIL"], "] Angular momentum conservation: r^2*dphi/dt max deviation ",
      FmtN[angMomAbsErr, {6, 4}], " from b=", FmtN[b, {6, 4}], " (within 0.1%)"];

    (* Check 3: energy conservation, (1/2)(rDot^2+(r*phiDot)^2)+1/r == 1/2 *)
    EArr = 0.5 * (rDotArr[[checkIdx]]^2 + (rArr[[checkIdx]] * phiDotArr[[checkIdx]])^2) +
           1.0 / rArr[[checkIdx]];
    energyAbsErr = Max[Abs[EArr - especific]];
    energyPass = energyAbsErr < 0.001 * especific;
    Print["  [", If[energyPass, "PASS", "FAIL"], "] Energy conservation: max deviation ",
      FmtN[energyAbsErr, {6, 4}], " from E=0.5 (within 0.1%)"];
    Print[""];

    <|
      "mode" -> "scatter",
      "t" -> tArr, "x" -> xArr, "y" -> yArr, "r" -> rArr, "phi" -> phiArr,
      "rDot" -> rDotArr, "phiDot" -> phiDotArr, "speed" -> speedArr,
      "b" -> b, "rInit" -> rInit, "rInitEff" -> rInitEff, "nPts" -> nPts,
      "tActual" -> tActual,
      "thetaAnalyticDeg" -> thetaAnalyticDeg, "thetaMeasuredDeg" -> thetaMeasuredDeg,
      "rMin" -> rMin, "tPeriapsis" -> tPeriapsis, "rAtPeriapsis" -> rAtPeriapsis,
      "idxPeriapsis" -> idxPeriapsis,
      "vInit" -> {vxInit, vyInit}, "vFinal" -> {vxFinal, vyFinal},
      "angMomPass" -> angMomPass, "energyPass" -> energyPass
    |>
  ]


(* ========================================================
   DISTRIBUTION MODE — beam of particles, realistic b sampling
   ======================================================== *)

DistributionModel[cfg_Association] :=
  Module[{
    n, bmax, seed, bRaw, bSorted, thetaRad, thetaDeg, weight,
    pitchMinHz, pitchMaxHz, pitchHz, pan, ampNorm,
    nBackscatter, b90, predictedFrac, expectedCount, sigma, tolCount,
    crossSectionPass
  },

    n    =     GetCfg[cfg, {"simulation", "scattering", "n_particles"}, 200];
    bmax = N @ GetCfg[cfg, {"simulation", "scattering", "b_max"},       8.0];
    seed =     GetCfg[cfg, {"simulation", "scattering", "random_seed"}, 42 ];

    (* Uniform over the beam's cross-sectional AREA: b ~ sqrt(Uniform[0,bmax^2]),
       so dN/db is proportional to b (annular ring area 2*Pi*b*db). *)
    SeedRandom[seed];
    bRaw    = Sqrt[RandomReal[{0.0, bmax^2}, n]];
    bSorted = Clip[Reverse[Sort[bRaw]], {1.0*^-6, bmax}];   (* farthest (largest b) first *)

    thetaRad = 2.0 * ArcCot[bSorted];
    thetaDeg = thetaRad * 180.0 / Pi;

    (* Differential-cross-section weight: 1/sin^4(theta/2) is dSigma/dOmega;
       the extra sin(theta) is the solid-angle Jacobian for an azimuthally
       symmetric beam (dN proportional to dSigma/dOmega * 2*Pi*sin(theta)*dtheta). *)
    weight = (1.0 / Sin[thetaRad / 2.0]^4) * Sin[thetaRad];

    (* Fixed (not per-run-rescaled) domains for pitch and pan, so the
       mapping is the same absolute meaning across every run regardless
       of which random b's happened to be drawn. *)
    pitchMinHz = 220.0;
    pitchMaxHz = 1760.0;
    pitchHz = Rescale[thetaDeg, {0.0, 180.0}, {pitchMinHz, pitchMaxHz}];
    pan     = Rescale[bSorted, {0.0, bmax},   {1.0, -1.0}];      (* large b=left, small b=right *)
    ampNorm = If[Max[weight] - Min[weight] < 1.0*^-9,
      ConstantArray[0.5, n],
      Rescale[weight, MinMax[weight], {0.05, 0.9}]];

    Print["-- Distribution parameters --"];
    STEMPrintN["Beam particles",     n,    "", {4, 0}];
    STEMPrintN["Max impact parameter b_max", bmax, "(scaled)", {6, 3}];
    Print[""];

    (* Check 4: cross-section check. Since theta(b) = 2*ArcCot[b] is a
       monotonic bijection and d=1, theta > 90 deg iff b < b_90 = 1.0
       exactly (cot(45 deg) = 1) -- a universal constant of this app,
       independent of b_max. With b ~ sqrt(Uniform[0,bmax^2]),
       P(b < 1) = 1/bmax^2. At the defaults (n=200, bmax=8) the expected
       backscatter count is only ~3.1 particles, so a flat "within 20%"
       relative tolerance is not statistically meaningful (Poisson noise
       alone is ~57% relative at this count) -- see AGENTS.md. Instead
       this checks the observed count against a >=3-sigma binomial band
       around the expectation (with 20%-of-expectation and a 1-particle
       floor, so the tolerance never collapses to zero). *)
    b90 = 1.0;
    nBackscatter  = Count[thetaDeg, x_ /; x > 90.0];
    predictedFrac = Min[1.0, (b90 / bmax)^2];
    expectedCount = n * predictedFrac;
    sigma    = Sqrt[Max[expectedCount * (1.0 - predictedFrac), 1.0*^-9]];
    tolCount = Max[3.0 * sigma, 0.2 * expectedCount, 1.0];
    crossSectionPass = Abs[nBackscatter - expectedCount] <= tolCount;

    Print["  [", If[crossSectionPass, "PASS", "FAIL"], "] Cross-section check: ",
      nBackscatter, " of ", n, " particles backscattered (theta>90 deg) vs expected ",
      FmtN[expectedCount, {6, 3}], " +/- ", FmtN[tolCount, {5, 2}],
      " (predicted fraction 1/b_max^2 = ", FmtN[predictedFrac, {6, 5}], ")"];
    Print[""];

    <|
      "mode" -> "distribution",
      "n" -> n, "bmax" -> bmax, "seed" -> seed,
      "b" -> bSorted, "thetaDeg" -> thetaDeg, "weight" -> weight,
      "pitchHz" -> pitchHz, "pan" -> pan, "ampNorm" -> ampNorm,
      "nBackscatter" -> nBackscatter, "predictedFrac" -> predictedFrac,
      "expectedCount" -> expectedCount, "crossSectionPass" -> crossSectionPass
    |>
  ]


(* ========================================================
   DISCOVERY MODE — Thomson vs Rutherford, binaural comparison

   N=100 particles per model, fixed regardless of the
   n_particles config key -- this mode recreates one specific
   historical comparison, not a tunable beam size.
   ======================================================== *)

$ScatteringThomsonThetaMaxRad = 0.01;  (* ~0.57 deg -- gold, ~5 MeV alpha, R_atom~1 Angstrom *)

DiscoveryModel[cfg_Association] :=
  Module[{
    nDisc, bmax, seed, thomsonThetaRad, thomsonThetaDeg,
    bDisc, rutherfordThetaRad, rutherfordThetaDeg,
    nBackThomson, nBackRutherford
  },

    nDisc = 100;
    bmax  = N @ GetCfg[cfg, {"simulation", "scattering", "b_max"},       8.0];
    seed  =     GetCfg[cfg, {"simulation", "scattering", "random_seed"}, 42 ];

    (* Same seed for both channels -- reproducible "fair" comparison
       (same beam geometry draw sequence), even though the two models'
       angle distributions are structurally unrelated. *)
    SeedRandom[seed];
    thomsonThetaRad = RandomReal[{0.0, $ScatteringThomsonThetaMaxRad}, nDisc];
    thomsonThetaDeg = thomsonThetaRad * 180.0 / Pi;

    SeedRandom[seed];
    bDisc = Sqrt[RandomReal[{0.0, bmax^2}, nDisc]];
    rutherfordThetaRad = 2.0 * ArcCot[bDisc];
    rutherfordThetaDeg = rutherfordThetaRad * 180.0 / Pi;

    nBackThomson    = Count[thomsonThetaDeg,    x_ /; x > 90.0];
    nBackRutherford = Count[rutherfordThetaDeg, x_ /; x > 90.0];

    Print["-- Discovery parameters --"];
    STEMPrintN["Particles per model", nDisc, "", {4, 0}];
    STEMPrintN["Thomson max angle",   $ScatteringThomsonThetaMaxRad * 180.0 / Pi, "deg", {5, 3}];
    Print["  Thomson backscatter events (theta>90 deg): ", nBackThomson];
    Print["  Rutherford backscatter events (theta>90 deg): ", nBackRutherford];
    Print[""];

    <|
      "mode" -> "discovery",
      "n" -> nDisc, "bmax" -> bmax, "seed" -> seed,
      "thetaMaxThomsonDeg" -> $ScatteringThomsonThetaMaxRad * 180.0 / Pi,
      "bRutherford" -> bDisc,
      "thomsonThetaDeg" -> thomsonThetaDeg, "rutherfordThetaDeg" -> rutherfordThetaDeg,
      "nBackThomson" -> nBackThomson, "nBackRutherford" -> nBackRutherford
    |>
  ]

(* ========================================================
   magnetic/src/model.wl — Lorentz-force equations of motion

   Public API:
     IntegrateCyclotron[cfg]   -- uniform B, no E   (cyclotron mode)
     IntegrateDrift[cfg]       -- uniform B and E   (drift mode)
     IntegrateMirror[cfg]      -- non-uniform B(z)  (mirror mode)
     BuildMultiModel[cfg]      -- proton/alpha/electron chord (multi mode)

   Units: dimensionless, SI-inspired.  q/m is supplied directly as
   "charge_mass_ratio" (equivalently m=1), so the cyclotron frequency
   is simply omega_c = charge_mass_ratio * B_z.

   Force law (standard Lorentz force, B along/near z):
     dv/dt = k (E + v x B),   k = q/m

   For uniform B = Bz zhat this reduces to:
     dvx/dt = k (Ex + vy Bz)
     dvy/dt = -k vx Bz
     dvz/dt = 0
   which gives the textbook E x B drift v_d = -Ex/Bz yhat (the
   build note's "+Ex/Bz" differs only by the arbitrary sign/handedness
   convention picked for the axes; see AGENTS.md design decision 1).

   For the mirror mode, Bz(z) = B0(1+alpha z^2) alone cannot produce
   the mirroring force (dvz/dt would be identically zero for any
   z-only field).  A real axisymmetric mirror field must also satisfy
   div B = 0, which -- expanded near the axis -- requires a small
   radial component Br(r,z) = -(r/2) dBz/dz.  In Cartesian form:
     Bx = -(alpha B0) x z,  By = -(alpha B0) y z,  Bz = B0(1+alpha z^2)
   This is the standard near-axis expansion used in magnetic-bottle
   / mirror-machine particle simulations (see AGENTS.md).
   ======================================================== *)


(* ── Zero-crossing detection (positive-going, linear interpolation) ── *)
PositiveZeroCrossings[tArr_List, xArr_List] :=
  Module[{idx},
    idx = Select[Range[2, Length[xArr]], xArr[[# - 1]] < 0 && xArr[[#]] >= 0 &];
    Map[
      Function[i,
        tArr[[i - 1]] + (0.0 - xArr[[i - 1]]) *
          (tArr[[i]] - tArr[[i - 1]]) / (xArr[[i]] - xArr[[i - 1]])],
      idx]
  ]

(* ── Sign-change detection (for mirror-point / bounce detection) ── *)
SignChangeTimes[tArr_List, vArr_List] :=
  Module[{idx},
    idx = Select[Range[2, Length[vArr]], vArr[[# - 1]] * vArr[[#]] < 0 &];
    Map[
      Function[i,
        tArr[[i - 1]] + (0.0 - vArr[[i - 1]]) *
          (tArr[[i]] - tArr[[i - 1]]) / (vArr[[i]] - vArr[[i - 1]])],
      idx]
  ]


(* ========================================================
   CYCLOTRON MODE — uniform B, no E
   ======================================================== *)

IntegrateCyclotron[cfg_Association] :=
  Module[{
    Bz, k, vPerp, vPar, nPeriods,
    omegaC, Tc, tMax, nPts,
    sol, xFn, yFn, zFn, vxFn, vyFn, vzFn,
    tArr, xArr, yArr, zArr, vxArr, vyArr, vzArr, speedArr, keArr,
    rc, crossTimes, periodMeasured, periodPass,
    keMin, keMax, keMean, energyPass
  },

    Bz       = N @ GetCfg[cfg, {"simulation", "magnetic", "B_z"},                1.0];
    k        = N @ GetCfg[cfg, {"simulation", "magnetic", "charge_mass_ratio"},  1.0];
    vPerp    = N @ GetCfg[cfg, {"simulation", "magnetic", "v_perp"},             1.0];
    vPar     = N @ GetCfg[cfg, {"simulation", "magnetic", "v_parallel"},         0.0];
    nPeriods =     GetCfg[cfg, {"simulation", "magnetic", "n_periods"},          5];

    omegaC = k * Bz;
    Tc     = 2.0 Pi / Abs[omegaC];
    tMax   = N[nPeriods * Tc];
    nPts   = Clip[Round[200 * nPeriods], {500, 8000}];
    rc     = vPerp / Abs[omegaC];

    Print["-- Cyclotron parameters --"];
    STEMPrintN["Cyclotron frequency omega_c", omegaC, "rad/time", {6, 4}];
    STEMPrintN["Cyclotron period T_c",         Tc,     "time",     {6, 4}];
    STEMPrintN["Larmor radius r_c",            rc,     "length",   {6, 4}];
    Print[""];

    sol = Quiet @ NDSolve[
      {x''[t] == k * (y'[t] * Bz),
       y''[t] == -k * x'[t] * Bz,
       z''[t] == 0,
       x[0] == 0.0, y[0] == 0.0, z[0] == 0.0,
       x'[0] == vPerp, y'[0] == 0.0, z'[0] == vPar},
      {x, y, z}, {t, 0, tMax},
      MaxStepSize -> Tc / 50.0, PrecisionGoal -> 8, AccuracyGoal -> 8
    ];

    {xFn, yFn, zFn} = {x, y, z} /. First[sol];
    vxFn = xFn'; vyFn = yFn'; vzFn = zFn';

    tArr  = N @ Subdivide[0.0, tMax, nPts - 1];
    xArr  = xFn /@ tArr;  yArr = yFn /@ tArr;  zArr = zFn /@ tArr;
    vxArr = vxFn /@ tArr; vyArr = vyFn /@ tArr; vzArr = vzFn /@ tArr;
    speedArr = Sqrt[vxArr^2 + vyArr^2 + vzArr^2];
    keArr    = 0.5 * speedArr^2;

    (* Check 1: measured cyclotron period from x zero-crossings *)
    crossTimes = PositiveZeroCrossings[tArr, xArr];
    periodMeasured = If[Length[crossTimes] >= 2, Mean[Differences[crossTimes]], $Failed];
    periodPass = NumericQ[periodMeasured] && Abs[periodMeasured - Tc] < 0.01 * Tc;

    Print["  [", If[periodPass, "PASS", "FAIL"], "] Cyclotron period: measured ",
      If[NumericQ[periodMeasured], FmtN[periodMeasured, {6, 4}], "n/a"],
      " vs expected ", FmtN[Tc, {6, 4}], " (within 1%)"];

    (* Check 4: energy conservation (no E field -- |v| exactly constant) *)
    keMin = Min[keArr]; keMax = Max[keArr]; keMean = Mean[keArr];
    energyPass = (keMax - keMin) < 0.001 * keMean;
    Print["  [", If[energyPass, "PASS", "FAIL"],
      "] Energy conservation: KE range ", FmtN[(keMax - keMin) / keMean * 100.0, 4],
      "% of mean (within 0.1%)"];
    Print[""];

    <|
      "mode" -> "cyclotron",
      "t" -> tArr, "x" -> xArr, "y" -> yArr, "z" -> zArr,
      "vx" -> vxArr, "vy" -> vyArr, "vz" -> vzArr,
      "speed" -> speedArr, "ke" -> keArr,
      "xFn" -> xFn, "yFn" -> yFn, "zFn" -> zFn,
      "vxFn" -> vxFn, "vyFn" -> vyFn, "vzFn" -> vzFn,
      "Bz" -> Bz, "k" -> k, "vPerp" -> vPerp, "vPar" -> vPar,
      "omegaC" -> omegaC, "Tc" -> Tc, "tMax" -> tMax, "rc" -> rc,
      "nPeriods" -> nPeriods, "isHelix" -> (vPar != 0.0),
      "periodMeasured" -> periodMeasured, "periodPass" -> periodPass,
      "energyPass" -> energyPass
    |>
  ]


(* ========================================================
   DRIFT MODE — uniform B and E (E x B drift, cycloidal motion)
   ======================================================== *)

IntegrateDrift[cfg_Association] :=
  Module[{
    Bz, Ex, k, vPerp, nPeriods,
    omegaC, Tc, tMax, nPts, vDrift,
    sol, xFn, yFn, vxFn, vyFn,
    tArr, xArr, yArr, zArr, vxArr, vyArr, vzArr, speedArr, keArr,
    driftMeasured, driftPass,
    ke0, keEnd, energyPass
  },

    Bz       = N @ GetCfg[cfg, {"simulation", "magnetic", "B_z"},               1.0];
    Ex       = N @ GetCfg[cfg, {"simulation", "magnetic", "E_x"},               0.5];
    k        = N @ GetCfg[cfg, {"simulation", "magnetic", "charge_mass_ratio"}, 1.0];
    vPerp    = N @ GetCfg[cfg, {"simulation", "magnetic", "v_perp"},            1.0];
    nPeriods =     GetCfg[cfg, {"simulation", "magnetic", "n_periods"},         8];

    omegaC = k * Bz;
    Tc     = 2.0 Pi / Abs[omegaC];
    tMax   = N[nPeriods * Tc];
    nPts   = Clip[Round[200 * nPeriods], {500, 8000}];
    vDrift = -Ex / Bz;   (* E x B drift velocity, standard Lorentz-force sign *)

    Print["-- E x B drift parameters --"];
    STEMPrintN["Cyclotron frequency omega_c", omegaC, "rad/time", {6, 4}];
    STEMPrintN["Drift velocity v_d",           vDrift, "length/time", {6, 4}];
    Print[""];

    sol = Quiet @ NDSolve[
      {x''[t] == k * (Ex + y'[t] * Bz),
       y''[t] == -k * x'[t] * Bz,
       x[0] == 0.0, y[0] == 0.0,
       x'[0] == vPerp, y'[0] == 0.0},
      {x, y}, {t, 0, tMax},
      MaxStepSize -> Tc / 50.0, PrecisionGoal -> 8, AccuracyGoal -> 8
    ];

    {xFn, yFn} = {x, y} /. First[sol];
    vxFn = xFn'; vyFn = yFn';

    tArr  = N @ Subdivide[0.0, tMax, nPts - 1];
    xArr  = xFn /@ tArr; yArr = yFn /@ tArr; zArr = ConstantArray[0.0, nPts];
    vxArr = vxFn /@ tArr; vyArr = vyFn /@ tArr; vzArr = ConstantArray[0.0, nPts];
    speedArr = Sqrt[vxArr^2 + vyArr^2];
    keArr    = 0.5 * speedArr^2;

    (* Check 2: measured mean drift velocity vs analytic prediction *)
    driftMeasured = Mean[vyArr];
    driftPass = Abs[driftMeasured - vDrift] < 0.02 * Abs[vDrift];
    Print["  [", If[driftPass, "PASS", "FAIL"], "] E x B drift velocity: measured ",
      FmtN[driftMeasured, {6, 4}], " vs expected ", FmtN[vDrift, {6, 4}], " (within 2%)"];

    (* Check 4: E does work on the cycloid, but the motion (and hence KE)
       is exactly periodic with period Tc -- KE at t=0 and t=tMax
       (an integer number of periods later) must match. *)
    ke0 = First[keArr]; keEnd = Last[keArr];
    energyPass = Abs[keEnd - ke0] < 0.001 * ke0;
    Print["  [", If[energyPass, "PASS", "FAIL"],
      "] Energy periodicity: KE(0)=", FmtN[ke0, 4], " vs KE(t_max)=", FmtN[keEnd, 4],
      " (within 0.1% -- E does work instantaneously but not net, over whole periods)"];
    Print[""];

    <|
      "mode" -> "drift",
      "t" -> tArr, "x" -> xArr, "y" -> yArr, "z" -> zArr,
      "vx" -> vxArr, "vy" -> vyArr, "vz" -> vzArr,
      "speed" -> speedArr, "ke" -> keArr,
      "xFn" -> xFn, "yFn" -> yFn,
      "Bz" -> Bz, "Ex" -> Ex, "k" -> k, "vPerp" -> vPerp,
      "omegaC" -> omegaC, "Tc" -> Tc, "tMax" -> tMax, "vDrift" -> vDrift,
      "nPeriods" -> nPeriods,
      "driftMeasured" -> driftMeasured, "driftPass" -> driftPass,
      "energyPass" -> energyPass
    |>
  ]


(* ========================================================
   MIRROR MODE — non-uniform B(z), magnetic bottle
   ======================================================== *)

IntegrateMirror[cfg_Association] :=
  Module[{
    B0, alpha, k, vPerp, vPar, duration,
    zScale, Bmax, sin2Theta0, analyticTrapped,
    nPts, sol, xFn, yFn, zFn, vxFn, vyFn, vzFn,
    tArr, xArr, yArr, zArr, vxArr, vyArr, vzArr, speedArr, keArr, BzOfT,
    bounceTimes, nBounces, maxAbsZ, simTrapped, trapPass,
    keMin, keMax, keMean, energyPass, Tc0
  },

    B0       = N @ GetCfg[cfg, {"simulation", "magnetic", "B_0"},                1.0];
    alpha    = N @ GetCfg[cfg, {"simulation", "magnetic", "alpha"},              0.5];
    k        = N @ GetCfg[cfg, {"simulation", "magnetic", "charge_mass_ratio"},  1.0];
    vPerp    = N @ GetCfg[cfg, {"simulation", "magnetic", "v_perp"},             1.5];
    vPar     = N @ GetCfg[cfg, {"simulation", "magnetic", "v_parallel"},         0.8];
    duration = N @ GetCfg[cfg, {"simulation", "magnetic", "mirror_duration"},   30.0];

    (* Analytic trapping prediction.
       zScale = 3/sqrt(alpha) is the axial extent treated as the physical
       length of the simulated mirror (the region beyond which the field
       model is no longer considered representative of the machine).  This
       choice makes B_max = B0(1+alpha*zScale^2) = 10*B0 for ANY alpha, so
       the trapping threshold sin^2(theta0) > B0/Bmax = 0.1 is a universal
       constant of this app (see AGENTS.md). *)
    zScale = 3.0 / Sqrt[alpha];
    Bmax   = B0 * (1.0 + alpha * zScale^2);
    sin2Theta0 = vPerp^2 / (vPerp^2 + vPar^2);
    analyticTrapped = sin2Theta0 > B0 / Bmax;

    Tc0 = 2.0 Pi / Abs[k * B0];   (* gyro-period at the field minimum *)

    Print["-- Magnetic mirror parameters --"];
    STEMPrintN["Pitch angle sin^2(theta_0)", sin2Theta0, "", {6, 4}];
    STEMPrintN["Trapping threshold B0/Bmax",  B0 / Bmax,  "", {6, 4}];
    Print["  Analytic prediction: particle is ", If[analyticTrapped, "TRAPPED", "ESCAPING"]];
    Print[""];

    nPts = 4000;

    sol = Quiet @ NDSolve[
      {x''[t] == k * ( y'[t] * (B0 (1.0 + alpha z[t]^2)) - z'[t] * (-alpha B0 y[t] z[t]) ),
       y''[t] == k * ( z'[t] * (-alpha B0 x[t] z[t]) - x'[t] * (B0 (1.0 + alpha z[t]^2)) ),
       z''[t] == k * ( x'[t] * (-alpha B0 y[t] z[t]) - y'[t] * (-alpha B0 x[t] z[t]) ),
       x[0] == 0.0, y[0] == 0.0, z[0] == 0.0,
       x'[0] == vPerp, y'[0] == 0.0, z'[0] == vPar},
      {x, y, z}, {t, 0, duration},
      MaxStepSize -> Tc0 / 40.0, PrecisionGoal -> 7, AccuracyGoal -> 7
    ];

    {xFn, yFn, zFn} = {x, y, z} /. First[sol];
    vxFn = xFn'; vyFn = yFn'; vzFn = zFn';

    tArr  = N @ Subdivide[0.0, duration, nPts - 1];
    xArr  = xFn /@ tArr; yArr = yFn /@ tArr; zArr = zFn /@ tArr;
    vxArr = vxFn /@ tArr; vyArr = vyFn /@ tArr; vzArr = vzFn /@ tArr;
    speedArr = Sqrt[vxArr^2 + vyArr^2 + vzArr^2];
    keArr    = 0.5 * speedArr^2;
    BzOfT    = B0 * (1.0 + alpha * zArr^2);

    (* Check 3: trapping -- does the simulated trajectory actually
       reflect (v_parallel changes sign) within the observation window?
       A single sign change already proves a real physical reflection
       (energy + magnetic-moment conservation forced v_parallel through
       zero); requiring >=2 additionally confirms genuine back-and-forth
       bouncing rather than a one-off numerical edge effect.  Note this
       does NOT require max|z| to stay below zScale -- zScale is only
       the length scale used to derive the analytic Bmax prediction
       above, not a hard wall the true (adiabatic-or-not) dynamics are
       bound to respect. *)
    bounceTimes = SignChangeTimes[tArr, vzArr];
    nBounces    = Length[bounceTimes];
    maxAbsZ     = Max[Abs[zArr]];
    simTrapped  = nBounces >= 2;
    trapPass    = simTrapped === analyticTrapped;

    Print["  [", If[trapPass, "PASS", "FAIL"], "] Mirror trapping: analytic=",
      If[analyticTrapped, "TRAPPED", "ESCAPING"], "  simulated=",
      If[simTrapped, "TRAPPED", "ESCAPING"], "  (", nBounces, " reflection(s) in ",
      FmtN[duration, {5, 2}], " time units, max|z|=", FmtN[maxAbsZ, {5, 3}], ")"];

    (* Check 4: energy conservation (no E field) *)
    keMin = Min[keArr]; keMax = Max[keArr]; keMean = Mean[keArr];
    energyPass = (keMax - keMin) < 0.001 * keMean;
    Print["  [", If[energyPass, "PASS", "FAIL"],
      "] Energy conservation: KE range ", FmtN[(keMax - keMin) / keMean * 100.0, 4],
      "% of mean (within 0.1%)"];
    Print[""];

    <|
      "mode" -> "mirror",
      "t" -> tArr, "x" -> xArr, "y" -> yArr, "z" -> zArr,
      "vx" -> vxArr, "vy" -> vyArr, "vz" -> vzArr,
      "speed" -> speedArr, "ke" -> keArr, "Bfield" -> BzOfT,
      "xFn" -> xFn, "yFn" -> yFn, "zFn" -> zFn,
      "vxFn" -> vxFn, "vyFn" -> vyFn, "vzFn" -> vzFn,
      "B0" -> B0, "alpha" -> alpha, "k" -> k, "vPerp" -> vPerp, "vPar" -> vPar,
      "duration" -> duration, "zScale" -> zScale, "Bmax" -> Bmax,
      "sin2Theta0" -> sin2Theta0, "analyticTrapped" -> analyticTrapped,
      "simTrapped" -> simTrapped, "trapPass" -> trapPass,
      "bounceTimes" -> bounceTimes, "nBounces" -> nBounces, "maxAbsZ" -> maxAbsZ,
      "energyPass" -> energyPass
    |>
  ]


(* ========================================================
   MULTI MODE — proton, alpha particle, electron chord

   Closed-form solution (uniform B, no E -- exact for all three
   particles).  Used instead of NDSolve because the electron's
   charge-to-mass ratio is 1836x the proton's: resolving its
   gyration numerically over the same time window as the proton
   would need ~1836x finer steps for no physical benefit, since the
   uniform-field cyclotron solution is exact in closed form anyway.
   ======================================================== *)

MultiParticleOrbit[label_String, kRatio_?NumericQ, Bz_?NumericQ,
                    vPerp_?NumericQ, tArr_List] :=
  Module[{omega, r, xArr, yArr, vxArr, vyArr},
    omega = kRatio * Bz;
    r     = vPerp / Abs[omega];
    xArr  = r * Sin[omega * tArr];
    yArr  = r * (Cos[omega * tArr] - 1.0);
    vxArr = vPerp * Cos[omega * tArr];
    vyArr = -vPerp * Sin[omega * tArr];
    <| "label" -> label, "kRatio" -> kRatio, "omega" -> omega, "r" -> r,
       "x" -> xArr, "y" -> yArr, "vx" -> vxArr, "vy" -> vyArr,
       "speed" -> ConstantArray[vPerp, Length[tArr]] |>
  ]

(* Check 5 (multi mode, exact) — each particle's cyclotron frequency
   ratio matches its charge-to-mass ratio EXACTLY. NOT a re-statement
   of "omega=kRatio*Bz" (checking that against itself would be
   tautological — omega_i/omega_j = kRatio_i/kRatio_j cancels Bz
   trivially by construction). Instead verifies that
   MultiParticleOrbit's CLOSED-FORM x(t)=r*Sin[omega*t],
   y(t)=r*(Cos[omega*t]-1) actually SOLVES the Lorentz-force ODE
   (x''=k*y'*Bz, y''=-k*x'*Bz) for each particle's own (kRatio,Bz) —
   an independent calculus check of the claimed solution against the
   differential equation it's supposed to satisfy, not the formula
   used to build it. A numerical (sampled) frequency measurement was
   considered and rejected: the electron's period is 1836x shorter
   than the proton's, so on the SAME time grid used to render all
   three particles (~300 points per PROTON period), the electron gets
   under 1 sample per its own period — far below Nyquist, making any
   zero-crossing-based period measurement meaningless for it without a
   separate, dedicated fine grid. The symbolic ODE-residual check
   sidesteps this sampling problem entirely (no numerical trajectory
   involved, exact for any kRatio). *)
MultiClosedFormResidual[kRatio_?NumericQ, Bz_?NumericQ] :=
  Module[{omega, r, xFn, yFn, residX, residY, tt},
    omega = kRatio * Bz;
    r     = 1.0 / Abs[omega];  (* vPerp cancels out of the residual; use 1.0 *)
    xFn[s_] := r * Sin[omega * s];
    yFn[s_] := r * (Cos[omega * s] - 1.0);
    residX = Simplify[D[xFn[tt], {tt, 2}] - kRatio * D[yFn[tt], tt] * Bz];
    residY = Simplify[D[yFn[tt], {tt, 2}] + kRatio * D[xFn[tt], tt] * Bz];
    Max[Abs[{residX /. tt -> 1.0, residY /. tt -> 1.0,
              residX /. tt -> 3.7, residY /. tt -> 3.7}]]
  ];

MultiFrequencyRatioCheck[Bz_?NumericQ, Optional[tolerance_?NumericQ, 10^-6]] :=
  Module[{kProton = 1.0, kAlpha = 0.5, kElectron = 1836.0, residProton, residAlpha, residElectron, maxResid},
    residProton   = MultiClosedFormResidual[kProton, Bz];
    residAlpha    = MultiClosedFormResidual[kAlpha, Bz];
    residElectron = MultiClosedFormResidual[kElectron, Bz];
    maxResid = Max[residProton, residAlpha, residElectron];
    <| "residProton" -> residProton, "residAlpha" -> residAlpha, "residElectron" -> residElectron,
       "maxResid" -> maxResid, "pass" -> maxResid < tolerance |>
  ];

BuildMultiModel[cfg_Association] :=
  Module[{
    Bz, vPerp, baseFreqHz, nPeriods,
    kProton, kAlpha, kElectron,
    omegaProton, TProton, tMax, nPts, tArr,
    proton, alphaP, electron,
    fProton, fAlpha, fElectronScaled, fElectronActual, electronRatio,
    freqRatioChk
  },

    Bz         = N @ GetCfg[cfg, {"simulation", "magnetic", "B_z"},         1.0];
    vPerp      = N @ GetCfg[cfg, {"simulation", "magnetic", "v_perp"},      1.0];
    baseFreqHz = N @ GetCfg[cfg, {"simulation", "magnetic", "base_freq_hz"}, 110.0];
    nPeriods   =     GetCfg[cfg, {"simulation", "magnetic", "n_periods"},   10];

    kProton   = 1.0;
    kAlpha    = 0.5;
    kElectron = 1836.0;

    omegaProton = kProton * Bz;
    TProton     = 2.0 Pi / Abs[omegaProton];
    tMax        = N[nPeriods * TProton];
    nPts        = Clip[Round[300 * nPeriods], {600, 6000}];
    tArr        = N @ Subdivide[0.0, tMax, nPts - 1];

    proton   = MultiParticleOrbit["proton",   kProton,   Bz, vPerp, tArr];
    alphaP   = MultiParticleOrbit["alpha",    kAlpha,    Bz, vPerp, tArr];
    electron = MultiParticleOrbit["electron", kElectron, Bz, vPerp, tArr];

    fProton         = baseFreqHz;
    fAlpha          = baseFreqHz / 2.0;
    fElectronScaled = baseFreqHz * 8.0;
    fElectronActual = baseFreqHz * kElectron;
    electronRatio   = kElectron;

    Print["-- Multi-particle chord parameters --"];
    STEMPrintN["Proton frequency (audio)",         fProton,         "Hz", {6, 2}];
    STEMPrintN["Alpha frequency (audio)",           fAlpha,          "Hz", {6, 2}];
    STEMPrintN["Electron frequency (audio, scaled)", fElectronScaled, "Hz", {6, 2}];
    STEMPrintN["Electron frequency (actual)",        fElectronActual, "Hz", {8, 1}];
    Print["  Electron/proton frequency ratio: ", FmtN[electronRatio, {6, 1}], "x"];
    Print[""];

    (* Check 4 (energy conservation): exact by construction (closed-form
       uniform-field cyclotron motion), but verify to numerical precision. *)
    With[{allSpeeds = Join[proton["speed"], alphaP["speed"], electron["speed"]]},
      Print["  [", If[Max[allSpeeds] - Min[allSpeeds] < 0.001 * Mean[allSpeeds], "PASS", "FAIL"],
        "] Energy conservation: all three particles' |v| constant (within 0.1%)"]];

    (* Check 5 (frequency ratios, exact — see MultiFrequencyRatioCheck's
       docstring for why this is a symbolic ODE-residual check, not a
       sampled-period measurement). *)
    freqRatioChk = MultiFrequencyRatioCheck[Bz];
    Print["  [", If[freqRatioChk["pass"], "PASS", "FAIL"],
      "] Cyclotron frequency ratios: each particle's closed-form orbit exactly solves ",
      "the Lorentz-force ODE at its own charge-to-mass ratio (max residual ",
      FmtN[freqRatioChk["maxResid"], 3], ")"];
    Print[""];

    <|
      "mode" -> "multi",
      "t" -> tArr, "proton" -> proton, "alpha" -> alphaP, "electron" -> electron,
      "Bz" -> Bz, "vPerp" -> vPerp, "baseFreqHz" -> baseFreqHz,
      "nPeriods" -> nPeriods, "tMax" -> tMax, "TProton" -> TProton,
      "fProton" -> fProton, "fAlpha" -> fAlpha,
      "fElectronScaled" -> fElectronScaled, "fElectronActual" -> fElectronActual,
      "electronRatio" -> electronRatio, "freqRatioChk" -> freqRatioChk
    |>
  ]

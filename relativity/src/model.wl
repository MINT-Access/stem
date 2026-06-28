(* ========================================================
   relativity/src/model.wl — Post-Newtonian binary inspiral model

   Public API:
     ChirpModel[cfg]

   Returns an Association:
     "time"             — full time array (inspiral + ringdown), seconds
     "strain"           — h(t): raw gravitational wave strain (~1e-21)
     "frequency"        — f(t): instantaneous GW frequency in Hz
     "amplitude"        — A(t): strain amplitude envelope
     "merger_index"     — index of the first ringdown sample
     "chirp_mass_solar" — chirp mass ℳ in solar masses
     "coalescence_time" — tc in seconds (inspiral duration)
     "peak_frequency"   — maximum frequency reached before clipping
     "mode"             — "chirp"

   Physics: post-Newtonian (PN) approximation, valid during the
   inspiral phase.  G = c = 1 internally; SI constants used for
   converting chirp mass and distance to seconds / metres.
   ======================================================== *)


ChirpModel[cfg_Association] :=
  Module[{
    (* SI physical constants *)
    G, c, Msun,
    (* config parameters *)
    m1, m2, distMpc, sampleRate, fMin, fMax, ringdownDur,
    (* derived mass quantities *)
    D, Mtotal, mu, Mchirp, MchirpSec,
    (* time arrays *)
    tc, dt, tArr, n,
    (* inspiral arrays *)
    tau, fArr, phiArr, AArr, hArr,
    (* ringdown *)
    Mfinal, fQnm, tauRd, nRD, tRD, hRD, AMerger,
    (* combined output *)
    mergerIdx, tFull, hFull, fFull, AFull,
    (* physical checks *)
    fStart, fMono, aMono, dcOffset, checkRange, eps
  },

  (* ── SI physical constants ──────────────────────────── *)
  G    = 6.674*^-11;    (* m³ kg⁻¹ s⁻² *)
  c    = 2.998*^8;      (* m s⁻¹ *)
  Msun = 1.989*^30;     (* kg *)

  (* ── Configuration ──────────────────────────────────── *)
  m1          = N @ GetCfg[cfg, {"simulation","chirp","mass1_solar"},       36.0];
  m2          = N @ GetCfg[cfg, {"simulation","chirp","mass2_solar"},       29.0];
  distMpc     = N @ GetCfg[cfg, {"simulation","chirp","distance_mpc"},     410.0];
  sampleRate  =     GetCfg[cfg, {"simulation","chirp","sample_rate"},       4096];
  fMin        = N @ GetCfg[cfg, {"simulation","chirp","frequency_min_hz"},   20.0];
  fMax        = N @ GetCfg[cfg, {"simulation","chirp","frequency_max_hz"},  500.0];
  ringdownDur = N @ GetCfg[cfg, {"simulation","chirp","ringdown_duration"},   0.05];

  D = distMpc * 3.0857*^22;   (* Mpc → metres *)

  (* ── Chirp mass and time scale ──────────────────────── *)
  Mtotal    = m1 + m2;
  mu        = N[m1 * m2 / Mtotal];
  Mchirp    = N[mu^(3/5) * Mtotal^(2/5)];        (* solar masses *)
  MchirpSec = N[G * Mchirp * Msun / c^3];       (* chirp mass in seconds *)

  (* Coalescence time from starting frequency f_min (Peters 1964)
     t_c = (5/256) · ℳ_sec^(-5/3) · (π f_min)^(-8/3) *)
  tc = N[(5.0/256.0) * MchirpSec^(-5/3) * (Pi * fMin)^(-8/3)];
  dt = N[1.0 / sampleRate];

  Print["-- Chirp model parameters --"];
  Print["  m1 = ", FmtN[m1, {5,2}], " M☉,  m2 = ", FmtN[m2, {5,2}], " M☉"];
  STEMPrintN["Chirp mass",       Mchirp,     "M☉", {5,3}];
  STEMPrintN["Chirp mass (time)",MchirpSec, "s",  6];
  STEMPrintN["Coalescence time", tc,          "s",  {6,4}];
  STEMPrintN["Distance",         distMpc,     "Mpc",{6,1}];
  Print[""];

  (* ── Time array: t ∈ [0, tc)  (stop before singularity) ── *)
  tArr = N @ Range[0, tc - dt, dt];
  n    = Length[tArr];

  (* ── PN frequency evolution ─────────────────────────── *)
  (* f(t) = (1/π)(5/256)^(3/8) ℳ_sec^(-5/8) (tc - t)^(-3/8) *)
  tau  = tc - tArr;    (* time remaining to merger, {n} *)
  fArr = N[(1.0/Pi) * (5.0/256.0)^(3/8) * MchirpSec^(-5/8) * tau^(-3/8)];

  (* Clip at fMax — PN approximation breaks down near merger *)
  fArr = Clip[fArr, {0.0, fMax}];

  (* ── Phase by cumulative summation ──────────────────── *)
  (* φ(t) = ∫ f(t) dt ≈ Σ f(tᵢ) · dt *)
  phiArr = N[Accumulate[fArr] * dt];

  (* ── Strain amplitude ────────────────────────────────── *)
  (* A(t) = (4/D)(G ℳ M☉/c²)(π G ℳ M☉ f(t)/c³)^(2/3)
     With MchirpSec = G ℳ M☉/c³:
       G ℳ M☉/c² = MchirpSec · c
       π G ℳ M☉/c³ · f = π MchirpSec · f *)
  AArr = N[(4.0/D) * (MchirpSec * c) * (Pi * MchirpSec * fArr)^(2/3)];

  (* ── Strain ──────────────────────────────────────────── *)
  hArr = N[AArr * Cos[2.0 Pi * phiArr]];

  (* ── Ringdown ────────────────────────────────────────── *)
  (* Final black-hole mass ≈ 95% of total mass (radiated away) *)
  Mfinal = 0.95 * Mtotal;

  (* Quasi-normal mode frequency (Echeverria 1989; a=0 non-spinning)
     f_qnm = c³/(2π G M_final) · (1 - 0.63·(1-a)^0.3)   with a=0 *)
  fQnm = N[c^3 / (2.0 Pi * G * Mfinal * Msun) * (1.0 - 0.63)];

  (* Ringdown damping time: τ_rd ≈ 10 G M_final / c³ *)
  tauRd = N[10.0 * G * Mfinal * Msun / c^3];

  nRD     = Round[ringdownDur * sampleRate];
  tRD     = N @ Range[0, nRD - 1] / sampleRate;
  AMerger = Last[AArr];

  (* Exponentially damped sinusoid at the QNM frequency,
     starting from the merger amplitude so there is no discontinuity *)
  hRD = N[AMerger * Exp[-tRD / tauRd] * Cos[2.0 Pi * fQnm * tRD]];

  (* ── Assemble full signal ────────────────────────────── *)
  mergerIdx = n;   (* first ringdown sample index *)

  tFull = Join[tArr, tc + tRD];
  hFull = Join[hArr, hRD];
  fFull = Join[fArr, ConstantArray[fQnm, nRD]];
  AFull = Join[AArr, AMerger * Exp[-tRD / tauRd]];

  Print["-- Signal summary --"];
  STEMPrintN["Inspiral samples", n,         "",  1];
  STEMPrintN["Ringdown samples", nRD,       "",  1];
  STEMPrintN["Peak frequency",   Max[fArr], "Hz",{5,1}];
  STEMPrintN["QNM frequency",    fQnm,      "Hz",{5,1}];
  STEMPrintN["Ringdown tau",     tauRd,     "s", 5];
  Print[""];

  (* ── Physical correctness checks ────────────────────── *)
  eps    = 1.0*^-30;
  fStart = N @ First[fArr];

  (* Only check monotonicity up to the clipping onset (if any).
     FirstPosition returns a list like {k}; pos[[1]] extracts the integer. *)
  checkRange = With[{pos = FirstPosition[fArr, _?(# >= fMax - eps &)]},
    If[MissingQ[pos] || Length[pos] === 0, Length[fArr], pos[[1]]]];

  (* Min of differences: negative means non-monotone.
     Efficient even for large arrays (no Thread over 700k elements). *)
  fMono    = Min[N @ Differences[fArr[[;; checkRange]]]] >= -eps;
  aMono    = Min[N @ Differences[AArr[[;; checkRange]]]] >= -eps;
  dcOffset = Abs @ Mean[hArr];

  Print["-- Physical correctness checks --"];
  Print["  [", If[Abs[fStart - fMin] < 0.25 * fMin, "PASS", "FAIL"],
        "] Frequency at t=0: ", FmtN[fStart, 5], " Hz  (expected ~", fMin, " Hz)"];
  Print["  [", If[fMono, "PASS", "FAIL"],
        "] Frequency monotonically increasing to clipping point"];
  Print["  [", If[aMono, "PASS", "FAIL"],
        "] Amplitude monotonically increasing to clipping point"];
  Print["  [", If[dcOffset < 0.01 * Max[Abs[hArr]], "PASS", "FAIL"],
        "] Strain DC offset: ", FmtN[dcOffset / Max[Abs[hArr]], 4], " (fraction of peak)"];
  Print[""];

  If[!fMono || !aMono,
    STEMSay["Physical correctness check failed. Frequency or amplitude not monotone. Aborting."];
    Exit[1]
  ];

  <| "time"             -> tFull,
     "strain"           -> hFull,
     "frequency"        -> fFull,
     "amplitude"        -> AFull,
     "merger_index"     -> mergerIdx,
     "chirp_mass_solar" -> Mchirp,
     "coalescence_time" -> tc,
     "peak_frequency"   -> N @ Max[fArr],
     "sample_rate"      -> sampleRate,
     "mode"             -> "chirp" |>
]


(* ========================================================
   GeodesicModel — Schwarzschild geodesic for test particle or photon

   orbit_type = "bound":    massive particle elliptical orbit
                            (GR periapsis precession produces a rosette)
   orbit_type = "plunging": massive particle spiralling past event horizon
   orbit_type = "photon":   photon trajectory (gravitational lensing)

   Integration in dimensionless units: r̃ = r/M, τ̃ = τ/M.
   Schwarzschild radius r_s = 2M, so r̃ = 2 corresponds to the horizon.

   Returns an Association:
     "tau"           — proper-time array (units of M)
     "r"             — radial coordinate (units of M)
     "phi"           — azimuthal angle (radians)
     "x", "y"        — Cartesian equivalents (units of M)
     "redshift"      — sqrt(1−2/r̃), gravitational redshift factor
     "dphi_dtau"     — dφ/dτ angular velocity (rad/M)
     "omega_mean"    — mean |dφ/dτ| over the trajectory
     "merger_index"  — first index with r̃ ≤ 2, or Length[r] if no crossing
     "r_min","r_max" — trajectory extrema (units of M)
     "r_start"       — initial r̃ (units of M)
     "L_tilde"       — dimensionless angular momentum L/M
     "E"             — dimensionless energy
     "orbit_type"    — "bound" | "plunging" | "photon"
     "mass_solar"    — black hole mass in solar masses
     "r_s_km"        — Schwarzschild radius in km
     "tau_max"       — actual integration end (units of M)
     "n_revolutions" — total φ / 2π
     "mode"          — "geodesic"
   ======================================================== *)

GeodesicModel[cfg_Association] :=
  Module[{
    G, c, Msun,
    massSolar, orbitType, tauMaxM, nSteps,
    rStartRs, lFactor, bFactor,
    Mm, rSm,
    rTilde0, lCirc, LTilde, ETilde, bCrit, bTilde, v0, lambdaMax,
    sol, rFunc, phiFunc, tauEnd,
    tauArr, rArr, phiArr, xArr, yArr,
    redshiftArr, dphiArr, dtauArr, omegaMean,
    mergerIdx, rMin, rMax, nRevolutions
  },

  G    = 6.674*^-11;
  c    = 2.998*^8;
  Msun = 1.989*^30;

  massSolar = N @ GetCfg[cfg, {"simulation","geodesic","mass_solar"},   10.0];
  orbitType =     GetCfg[cfg, {"simulation","geodesic","orbit_type"}, "bound"];
  tauMaxM   = N @ GetCfg[cfg, {"simulation","geodesic","tau_max_m"},  3000.0];
  nSteps    =     GetCfg[cfg, {"simulation","geodesic","n_steps"},     50000];

  Mm  = G * massSolar * Msun / c^2;   (* gravitational radius G·M/c² in metres *)
  rSm = 2.0 * Mm;                    (* Schwarzschild radius in metres *)

  Print["-- Schwarzschild geodesic parameters --"];
  STEMPrintN["Mass",              massSolar,    "M\[SmallCircle]", {5,2}];
  STEMPrintN["Schwarzschild r_s", rSm / 1000, "km",              {8,3}];
  Print["  Orbit type: ", orbitType];
  Print[""];

  Which[

    (* ── Bound massive-particle elliptical orbit ── *)
    orbitType === "bound",
      rStartRs = N @ GetCfg[cfg, {"simulation","geodesic","bound","r_start_rs"},             10.0];
      lFactor  = N @ GetCfg[cfg, {"simulation","geodesic","bound","angular_momentum_factor"}, 0.85];
      rTilde0  = rStartRs * 2.0;   (* r̃₀ = r₀/M = r_start_rs · r_s/M = r_start_rs · 2 *)

      If[rTilde0 <= 6.0,
        Print["Error: r_start_rs must be > 3 for bound orbit (ISCO at r̃=6). Got r̃₀=", rTilde0];
        Exit[1]
      ];

      lCirc  = Sqrt[rTilde0^2 / (rTilde0 - 3.0)];   (* L̃ for circular orbit at r̃₀ *)
      LTilde = N[lFactor * lCirc];
      ETilde = N[Sqrt[(1.0 - 2.0/rTilde0) * (1.0 + LTilde^2/rTilde0^2)]];

      If[LTilde^2 < 12.0,
        Print["  Warning: L̃² = ", FmtN[LTilde^2, {5,3}],
              " < 12 (ISCO threshold). Orbit may plunge. ",
              "Increase r_start_rs or angular_momentum_factor."]
      ];

      Print["  r̃₀ = ", FmtN[rTilde0, {5,2}], " M  =  ", FmtN[rTilde0/2.0, {5,2}], " r_s"];
      STEMPrintN["L̃",            LTilde, "M",      {6,4}];
      STEMPrintN["L̃_circ(r̃₀)",  lCirc,  "M",      {6,4}];
      STEMPrintN["E",             ETilde, "(dim)",  {7,6}];
      Print[""];

      (* Massive-particle geodesic equations (M=1, proper time τ):
           r''(τ) = −1/r² + L̃²/r³ − 3L̃²/r⁴
           φ'(τ)  = L̃/r²
         Start at apoapsis r̃₀ with dr/dτ = 0. *)
      sol = Quiet @ NDSolve[
        {r''[\[Tau]] == -1.0/r[\[Tau]]^2 + LTilde^2/r[\[Tau]]^3 - 3.0*LTilde^2/r[\[Tau]]^4,
         \[Phi]'[\[Tau]] == LTilde / r[\[Tau]]^2,
         r[0] == rTilde0, r'[0] == 0.0, \[Phi][0] == 0.0,
         WhenEvent[r[\[Tau]] < 2.01, "StopIntegration"]},
        {r, \[Phi]}, {\[Tau], 0, tauMaxM},
        MaxSteps -> 6*nSteps, PrecisionGoal -> 6, AccuracyGoal -> 6
      ];
      rFunc   = r        /. First[sol];
      phiFunc = \[Phi]   /. First[sol];
      tauEnd  = rFunc["Domain"][[1, 2]],

    (* ── Plunging massive-particle orbit ── *)
    orbitType === "plunging",
      rStartRs = N @ GetCfg[cfg, {"simulation","geodesic","plunging","r_start_rs"},             10.0];
      lFactor  = N @ GetCfg[cfg, {"simulation","geodesic","plunging","angular_momentum_factor"}, 0.30];
      rTilde0  = rStartRs * 2.0;
      lCirc    = If[rTilde0 > 3.0, Sqrt[rTilde0^2 / (rTilde0 - 3.0)], 1.0];
      LTilde   = N[lFactor * lCirc];
      ETilde   = N[Sqrt[(1.0 - 2.0/rTilde0) * (1.0 + LTilde^2/rTilde0^2)]];

      Print["  r̃₀ = ", FmtN[rTilde0, {5,2}], " M  =  ", FmtN[rTilde0/2.0, {5,2}], " r_s"];
      STEMPrintN["L̃",  LTilde, "M",     {6,4}];
      STEMPrintN["E",   ETilde, "(dim)", {7,6}];
      Print["  L̃² = ", FmtN[LTilde^2, {5,3}],
            If[LTilde^2 < 12.0, " < 12 — no potential barrier, particle plunges.",
                                 " > 12 — potential barrier present (unexpected for plunging mode)."]];
      Print[""];

      sol = Quiet @ NDSolve[
        {r''[\[Tau]] == -1.0/r[\[Tau]]^2 + LTilde^2/r[\[Tau]]^3 - 3.0*LTilde^2/r[\[Tau]]^4,
         \[Phi]'[\[Tau]] == LTilde / r[\[Tau]]^2,
         r[0] == rTilde0, r'[0] == 0.0, \[Phi][0] == 0.0,
         WhenEvent[r[\[Tau]] < 2.01, "StopIntegration"]},
        {r, \[Phi]}, {\[Tau], 0, tauMaxM},
        MaxSteps -> 6*nSteps, PrecisionGoal -> 6, AccuracyGoal -> 6
      ];
      rFunc   = r        /. First[sol];
      phiFunc = \[Phi]   /. First[sol];
      tauEnd  = rFunc["Domain"][[1, 2]];
      LTilde  = LTilde;
      ETilde  = ETilde,

    (* ── Photon orbit (massless, affine parameter λ) ── *)
    orbitType === "photon",
      rStartRs = N @ GetCfg[cfg, {"simulation","geodesic","photon","r_start_rs"},              50.0];
      bFactor  = N @ GetCfg[cfg, {"simulation","geodesic","photon","impact_parameter_factor"}, 1.5];
      rTilde0  = rStartRs * 2.0;
      bCrit    = N[3.0 * Sqrt[3.0]];   (* critical impact parameter = 3√3 M ≈ 5.196 M *)
      bTilde   = N[bFactor * bCrit];
      LTilde   = bTilde;
      ETilde   = 1.0;
      (* Initial dr/dλ (photon moving inward): (dr/dλ)² = 1 − (1−2/r₀)·b²/r₀² *)
      v0       = N[-Sqrt[Max[0.0, 1.0 - (1.0 - 2.0/rTilde0)*bTilde^2/rTilde0^2]]];
      lambdaMax = N[4.0 * rTilde0];   (* affine-parameter range; generously covers one pass *)

      Print["  r̃₀ = ", FmtN[rTilde0, {5,2}], " M  =  ", FmtN[rTilde0/2.0, {5,2}], " r_s"];
      STEMPrintN["b_crit",           bCrit,  "M", {5,3}];
      STEMPrintN["Impact parameter b", bTilde, "M", {5,3}];
      Print["  b/b_crit = ", FmtN[bFactor, {4,2}],
            "  →  ", If[bFactor > 1.0, "deflected (escapes)", "captured (absorbed)"]];
      Print[""];

      (* Massless geodesic equations (M=1, affine parameter λ, E=1, L̃=b):
           r''(λ) = b²/r³ − 3b²/r⁴
           φ'(λ)  = b/r²
         Photon enters from r̃₀ moving inward (dr/dλ < 0). *)
      sol = Quiet @ NDSolve[
        {r''[\[Lambda]] == bTilde^2/r[\[Lambda]]^3 - 3.0*bTilde^2/r[\[Lambda]]^4,
         \[Phi]'[\[Lambda]] == bTilde / r[\[Lambda]]^2,
         r[0] == rTilde0, r'[0] == v0, \[Phi][0] == 0.0,
         WhenEvent[r[\[Lambda]] < 2.01, "StopIntegration"]},
        {r, \[Phi]}, {\[Lambda], 0, lambdaMax},
        MaxSteps -> 6*nSteps, PrecisionGoal -> 6, AccuracyGoal -> 6
      ];
      rFunc   = r        /. First[sol];
      phiFunc = \[Phi]   /. First[sol];
      tauEnd  = rFunc["Domain"][[1, 2]],

    True,
      Print["Error: unknown geodesic orbit_type \"", orbitType,
            "\" — expected bound, plunging, or photon."];
      Exit[1]
  ];

  (* ── Sample solution at nSteps uniformly-spaced points ── *)
  tauArr  = N @ Subdivide[0.0, tauEnd, nSteps - 1];
  rArr    = rFunc[tauArr];
  phiArr  = phiFunc[tauArr];
  xArr    = N[rArr * Cos[phiArr]];
  yArr    = N[rArr * Sin[phiArr]];

  (* Gravitational redshift factor as seen from infinity *)
  redshiftArr = N @ Sqrt @ Clip[1.0 - 2.0/rArr, {0.0, 1.0}];

  (* Angular velocity: central differences; prepend 0 for first point *)
  dtauArr  = N @ Differences[tauArr];
  dphiArr  = Prepend[N @ Abs[Differences[phiArr]] / dtauArr, 0.0];
  omegaMean = N @ Mean[Rest[dphiArr]];

  mergerIdx = With[{pos = FirstPosition[rArr, _?(# <= 2.0 &)]},
    If[MissingQ[pos] || Length[pos] === 0, Length[rArr], pos[[1]]]
  ];

  rMin = N @ Min[rArr];
  rMax = N @ Max[rArr];
  nRevolutions = N[Last[phiArr] / (2.0 Pi)];

  Print["-- Geodesic summary --"];
  STEMPrintN["τ_max integrated",  tauEnd,           "M",   {8,2}];
  STEMPrintN["r_min",             rMin / 2.0,       "r_s", {6,3}];
  STEMPrintN["r_max",             rMax / 2.0,       "r_s", {6,2}];
  STEMPrintN["Δφ total",          Last[phiArr],     "rad", {7,3}];
  STEMPrintN["Revolutions",       nRevolutions,     "",    {5,2}];
  If[mergerIdx < Length[rArr],
    STEMPrintN["Horizon crossing τ", tauArr[[mergerIdx]], "M", {7,2}]
  ];
  Print[""];

  <|
    "tau"           -> tauArr,
    "r"             -> rArr,
    "phi"           -> phiArr,
    "x"             -> xArr,
    "y"             -> yArr,
    "redshift"      -> redshiftArr,
    "dphi_dtau"     -> dphiArr,
    "omega_mean"    -> omegaMean,
    "merger_index"  -> mergerIdx,
    "r_min"         -> rMin,
    "r_max"         -> rMax,
    "r_start"       -> rTilde0,
    "L_tilde"       -> LTilde,
    "E"             -> ETilde,
    "orbit_type"    -> orbitType,
    "mass_solar"    -> massSolar,
    "r_s_km"        -> rSm / 1000.0,
    "tau_max"       -> tauEnd,
    "n_revolutions" -> nRevolutions,
    "mode"          -> "geodesic"
  |>
]

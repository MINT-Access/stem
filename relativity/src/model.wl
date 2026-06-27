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

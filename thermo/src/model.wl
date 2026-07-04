(* ========================================================
   thermo/src/model.wl — Classical statistical mechanics model

   Maxwell-Boltzmann speed distribution, characteristic speeds,
   equipartition theorem, elastic-collision ensemble dynamics, and
   Newton's-law-of-cooling relaxation. Purely classical — no quantum
   statistics (Fermi-Dirac/Bose-Einstein) anywhere in this app.

     f(v) = 4 pi (m / 2 pi k T)^(3/2) v^2 exp(-m v^2 / 2 k T)

   is the probability density of molecular speed v at temperature T
   for molecular mass m. This is exactly the PDF of WL's built-in
   MaxwellDistribution[sigma] with sigma = Sqrt[k T / m] (verified
   algebraically: 4 pi (m/2 pi k T)^(3/2) = Sqrt[2/pi] / sigma^3 when
   sigma^2 = kT/m) — RandomVariate[MaxwellDistribution[...]] is used
   for ensemble sampling below rather than hand-rolled rejection
   sampling, since it is the same distribution and Wolfram's own
   numerics are more robust than a bespoke rejection sampler.
   ======================================================== *)


$kB      = 1.380649*^-23;    (* Boltzmann constant, J/K *)
$amuToKg = 1.66053906660*^-27; (* kg per atomic mass unit *)

(* ── Named gas presets: mass in atomic mass units ────────────────── *)
$thermoGasPresets = <|
  "hydrogen" -> 2,
  "helium"   -> 4,
  "nitrogen" -> 28,
  "oxygen"   -> 32,
  "argon"    -> 40
|>;

(* Monatomic gases have only translational DOF (3); diatomic gases
   additionally have 2 rotational DOF at room temperature (vibrational
   modes only activate at much higher temperatures — out of scope
   here, see AGENTS.md). *)
$monatomicGases = {"helium", "argon"};
$diatomicGases  = {"hydrogen", "nitrogen", "oxygen"};

GasMassAmu[preset_String, massDefault_?NumericQ] :=
  Lookup[$thermoGasPresets, preset, massDefault];

GasDisplayName[preset_String] :=
  If[KeyExistsQ[$thermoGasPresets, preset], preset, "custom gas"];

MoleculeTypeOfGas[preset_String] :=
  Which[
    MemberQ[$monatomicGases, preset], "monatomic",
    MemberQ[$diatomicGases,  preset], "diatomic",
    True,                             "monatomic"
  ];

(* RepresentativeGasForMoleculeType
   Used by equipartition mode when a molecule type (not a specific gas)
   is selected via --simulation.thermo.molecule. *)
RepresentativeGasForMoleculeType[moleculeType_String] :=
  If[moleculeType === "diatomic", "nitrogen", "helium"];


(* ── Maxwell-Boltzmann speed distribution ────────────────────────── *)

MBDensity[v_?NumericQ, massAmu_?NumericQ, T_?NumericQ] :=
  Module[{m = massAmu * $amuToKg, k = $kB},
    4.0 * Pi * (m / (2.0 * Pi * k * T))^1.5 * v^2 * Exp[-m * v^2 / (2.0 * k * T)]
  ];

MostProbableSpeed[massAmu_?NumericQ, T_?NumericQ] :=
  Sqrt[2.0 * $kB * T / (massAmu * $amuToKg)];

MeanSpeed[massAmu_?NumericQ, T_?NumericQ] :=
  Sqrt[8.0 * $kB * T / (Pi * massAmu * $amuToKg)];

RMSSpeed[massAmu_?NumericQ, T_?NumericQ] :=
  Sqrt[3.0 * $kB * T / (massAmu * $amuToKg)];

(* MaxSpeed — 4x RMS speed captures >99.9% of the distribution's
   probability mass (the MB distribution's upper tail decays as a
   Gaussian in v^2, so this is a very safe truncation point). *)
MaxSpeed[massAmu_?NumericQ, T_?NumericQ] :=
  4.0 * RMSSpeed[massAmu, T];

MBSigma[massAmu_?NumericQ, T_?NumericQ] :=
  Sqrt[$kB * T / (massAmu * $amuToKg)];


(* ── Correctness checks (Physical/mathematical, printed PASS/FAIL) ── *)

(* Check 1: normalisation of f(v) over [0, v_max] *)
NormalizationCheck[massAmu_?NumericQ, T_?NumericQ, Optional[tolerance_?NumericQ, 0.001]] :=
  Module[{vmax, integral, err},
    vmax     = MaxSpeed[massAmu, T];
    integral = NIntegrate[MBDensity[v, massAmu, T], {v, 0, vmax}];
    err      = Abs[integral - 1.0];
    <| "integral" -> integral, "error" -> err, "pass" -> (err < tolerance) |>
  ];

(* Check 2: characteristic speed ratios (exact algebraic identities,
   v_mean/v_p = Sqrt[4/Pi], v_rms/v_p = Sqrt[3/2] — independent of T
   and mass since both speeds scale identically with Sqrt[T/m]). *)
SpeedRatioCheck[massAmu_?NumericQ, T_?NumericQ, Optional[tolerance_?NumericQ, 0.001]] :=
  Module[{vp, vmean, vrms, meanRatio, rmsRatio, expMeanRatio, expRmsRatio, err1, err2},
    vp    = MostProbableSpeed[massAmu, T];
    vmean = MeanSpeed[massAmu, T];
    vrms  = RMSSpeed[massAmu, T];
    meanRatio    = vmean / vp;
    rmsRatio     = vrms / vp;
    expMeanRatio = Sqrt[4.0 / Pi];
    expRmsRatio  = Sqrt[3.0 / 2.0];
    err1 = Abs[meanRatio - expMeanRatio] / expMeanRatio;
    err2 = Abs[rmsRatio  - expRmsRatio]  / expRmsRatio;
    <|
      "vp" -> vp, "vmean" -> vmean, "vrms" -> vrms,
      "meanRatio" -> meanRatio, "rmsRatio" -> rmsRatio,
      "expectedMeanRatio" -> expMeanRatio, "expectedRmsRatio" -> expRmsRatio,
      "error1" -> err1, "error2" -> err2,
      "pass" -> (err1 < tolerance && err2 < tolerance)
    |>
  ];

(* Check 3: ensemble equilibration — mean speed of a simulated particle
   ensemble (after all collision timesteps) within tolerance of the
   analytic mean speed at the ensemble's temperature. *)
EnsembleEquilibrationCheck[speeds_List, massAmu_?NumericQ, T_?NumericQ,
                           Optional[tolerance_?NumericQ, 0.10]] :=
  Module[{meanSpeed, analyticMean, relErr},
    meanSpeed    = Mean[speeds];
    analyticMean = MeanSpeed[massAmu, T];
    relErr       = Abs[meanSpeed - analyticMean] / analyticMean;
    <|
      "meanSpeed" -> meanSpeed, "analyticMean" -> analyticMean,
      "relError" -> relErr, "pass" -> (relErr < tolerance)
    |>
  ];

(* Check 4: equipartition — mean translational KE of the MB
   distribution equals (3/2)kT, verified by numerical integration
   (not just asserted), for both monatomic and diatomic mass values. *)
EquipartitionCheck[massAmu_?NumericQ, T_?NumericQ, Optional[tolerance_?NumericQ, 0.01]] :=
  Module[{m, vmax, meanKE, expected, relErr},
    m        = massAmu * $amuToKg;
    vmax     = MaxSpeed[massAmu, T];
    meanKE   = NIntegrate[(0.5 * m * v^2) * MBDensity[v, massAmu, T], {v, 0, vmax}];
    expected = 1.5 * $kB * T;
    relErr   = Abs[meanKE - expected] / expected;
    <|
      "meanKE" -> meanKE, "expected" -> expected,
      "relError" -> relErr, "pass" -> (relErr < tolerance)
    |>
  ];


(* ── Equipartition theorem energetics ────────────────────────────── *)

(* Always (3/2)kT — translational DOF are identical for every ideal
   gas regardless of molecular structure. *)
TranslationalMeanEnergy[T_?NumericQ] := 1.5 * $kB * T;

(* 2 rotational DOF x (1/2)kT = kT for diatomic gases at room
   temperature; 0 for monatomic gases (no rotational DOF — a point
   mass has no moment of inertia to store rotational energy in). *)
RotationalMeanEnergy[T_?NumericQ, moleculeType_String] :=
  If[moleculeType === "diatomic", $kB * T, 0.0];

TotalMeanEnergy[T_?NumericQ, moleculeType_String] :=
  TranslationalMeanEnergy[T] + RotationalMeanEnergy[T, moleculeType];

(* Fraction of total mean energy stored rotationally: 0 for monatomic,
   kT / (2.5 kT) = 0.4 for diatomic at room temperature. *)
RotationalFraction[T_?NumericQ, moleculeType_String] :=
  RotationalMeanEnergy[T, moleculeType] / TotalMeanEnergy[T, moleculeType];

HeatCapacityRatio[moleculeType_String] :=
  If[moleculeType === "diatomic", 7.0/5.0, 5.0/3.0];


(* ── Ensemble mode: particle sampling and elastic collisions ─────── *)

(* SampleMBSpeeds — see file header: RandomVariate on the exact-match
   built-in MaxwellDistribution, not a hand-rolled sampler. *)
SampleMBSpeeds[n_Integer, massAmu_?NumericQ, T_?NumericQ] :=
  RandomVariate[MaxwellDistribution[MBSigma[massAmu, T]], n];

(* ElasticCollision1D
   Equal-mass 1D elastic collision: velocities exchange exactly. This
   is not a simplification — for equal masses in 1D, a fully elastic
   collision *always* results in a complete velocity exchange (a
   standard result of simultaneously conserving momentum and kinetic
   energy for equal masses). Trivially conserves the pair's total KE
   since it is the same two values, swapped. *)
ElasticCollision1D[v1_?NumericQ, v2_?NumericQ] := {v2, v1};

(* SimulateEnsemble
   Initialises nParticles speeds from the MB distribution at T, then
   runs nTimesteps collision steps: each step picks one random pair of
   distinct particles and exchanges their speeds (ElasticCollision1D).
   Because a swap only permutes which particle holds which speed value
   — it never changes the underlying multiset — the ensemble's speed
   distribution is exactly conserved at every step: the "equilibrium"
   here is trivially exact, which is precisely the point (see
   LISTENING_GUIDE.md's "ensemble paradox" — the macroscopic
   distribution is fixed while the microscopic assignment shuffles
   continuously). Returns the full speed history (nTimesteps+1 states)
   and the collision log, so sonify.wl/animate.wl can render both the
   continuous chord and each individual collision event. *)
SimulateEnsemble[nParticles_Integer, massAmu_?NumericQ, T_?NumericQ, nTimesteps_Integer] :=
  Module[{initialSpeeds, speeds, history, collisionLog, pair, i, j},
    initialSpeeds = SampleMBSpeeds[nParticles, massAmu, T];
    speeds        = initialSpeeds;
    history       = {speeds};
    collisionLog  = {};
    Do[
      pair = RandomSample[Range[nParticles], 2];
      {i, j} = pair;
      {speeds[[i]], speeds[[j]]} = ElasticCollision1D[speeds[[i]], speeds[[j]]];
      AppendTo[collisionLog, pair];
      AppendTo[history, speeds],
      {nTimesteps}
    ];
    <|
      "initialSpeeds" -> initialSpeeds,
      "speedsHistory" -> history,
      "collisionLog"  -> collisionLog,
      "nParticles"    -> nParticles,
      "massAmu"       -> massAmu,
      "T"             -> T,
      "nTimesteps"    -> nTimesteps
    |>
  ];


(* ── Cooling mode: Newton's law of cooling ───────────────────────── *)

CoolingTemperature[t_?NumericQ, THot_?NumericQ, TCold_?NumericQ, tau_?NumericQ] :=
  TCold + (THot - TCold) * Exp[-t / tau];

(* DefaultCoolingTau
   Chooses tau so that T(duration) is within fracRemaining (default
   5%) of TCold: Exp[-duration/tau] = fracRemaining. *)
DefaultCoolingTau[duration_?NumericQ, Optional[fracRemaining_?NumericQ, 0.05]] :=
  -duration / Log[fracRemaining];

(* ThermalEquilibriumTime — the time t* at which T(t) first comes
   within frac (default 10%) of TCold, i.e. Exp[-t*/tau] = frac. *)
ThermalEquilibriumTime[tau_?NumericQ, Optional[frac_?NumericQ, 0.10]] :=
  -tau * Log[frac];

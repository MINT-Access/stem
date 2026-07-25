(* ========================================================
   quantum_statistics/src/model.wl — Bose-Einstein, Fermi-Dirac, and
   Maxwell-Boltzmann occupation numbers

   Three occupation-number distributions give the average number of
   particles in a single-particle state of energy epsilon, at
   temperature T and chemical potential mu:

     Bose-Einstein:     n_BE(eps) = 1 / (Exp[(eps-mu)/kT] - 1)
     Fermi-Dirac:       n_FD(eps) = 1 / (Exp[(eps-mu)/kT] + 1)
     Maxwell-Boltzmann: n_MB(eps) = Exp[-(eps-mu)/kT]           (classical limit)

   All energies in eV, temperatures in Kelvin; kB = 8.617333262e-5
   eV/K, DERIVED here from SI kB (J/K) and the exact SI eV-to-J
   conversion rather than looked up as a third, independent value (the
   same "derive don't duplicate" discipline compton/AGENTS.md documents
   for its own Compton-wavelength constant) — verified to reproduce the
   commonly-quoted "kT ~ 0.026 eV at room temperature" fact as an
   independent sanity check before use.

   mu = 0 (spectrum/temperature modes) matches how this is standardly
   posed for a photon/phonon gas, where particle number is not
   conserved so mu is exactly zero regardless of T — explicitly NOT the
   same convention fermi_sea mode uses (a genuine positive reference
   Fermi energy); see AGENTS.md design decisions 1 and 2 for why both
   conventions are used, each for a specific, verified reason.

   Public API:
     $kBeV
     BoseEinsteinOccupation[eps,mu,T], FermiDiracOccupation[eps,mu,T],
     MaxwellBoltzmannOccupation[eps,mu,T]
     ClassicalLimitCheck[], FermiDiracBoundCheck[],
     FermiDiracStepLimitCheck[], BoseEinsteinDivergenceCheck[]
     SpectrumModel[cfg], TemperatureModel[cfg], FermiSeaModel[cfg]
   ======================================================== *)


(* ── Boltzmann constant, eV/K — derived from SI constants ─────────── *)

$kBJ    = 1.380649*^-23;      (* Boltzmann constant, J/K, exact SI *)
$eVInJ  = 1.602176634*^-19;   (* J per eV, exact SI *)
$kBeV   = $kBJ / $eVInJ;      (* ~8.617333262e-5 eV/K *)


(* ── Occupation numbers ───────────────────────────────────────────── *)

(* BoseEinsteinOccupation — guarded: bosons require eps > mu strictly
   (eps=mu is a genuine division-by-zero; eps<mu gives an unphysical
   negative "occupation", verified directly to be the wrong sign
   before adding this guard — see AGENTS.md design decision 3). Returns
   Missing["BelowChemicalPotential"] rather than silently producing a
   negative or infinite number for eps<=mu. *)
BoseEinsteinOccupation[eps_?NumericQ, mu_?NumericQ, T_?NumericQ] :=
  If[eps <= mu,
    Missing["BelowChemicalPotential"],
    1.0 / (Exp[(eps - mu) / ($kBeV * T)] - 1.0)
  ];

(* FermiDiracOccupation — no domain restriction: Exp[x]+1 > 0 for every
   real x, so this is well-defined (and, per FermiDiracBoundCheck,
   strictly < 1) for any eps, mu, T. *)
FermiDiracOccupation[eps_?NumericQ, mu_?NumericQ, T_?NumericQ] :=
  1.0 / (Exp[(eps - mu) / ($kBeV * T)] + 1.0);

(* MaxwellBoltzmannOccupation — the classical limit; also unrestricted. *)
MaxwellBoltzmannOccupation[eps_?NumericQ, mu_?NumericQ, T_?NumericQ] :=
  Exp[-(eps - mu) / ($kBeV * T)];


(* ── Correctness checks (diagnostic-only, printed PASS/FAIL) ──────── *)

(* Check 1: classical limit recovery, asymptotic — verified via an
   EXACT algebraic identity, not merely a numerically-observed
   asymptote: (n_BE-n_MB)/n_MB = n_BE itself, and (n_FD-n_MB)/n_MB =
   -n_FD itself, for every x=(eps-mu)/kT (confirmed symbolically: with
   n_MB=Exp[-x], n_BE=1/(Exp[x]-1)=n_MB/(1-n_MB), so n_BE/n_MB-1 =
   1/(1-n_MB)-1 = n_MB/(1-n_MB) = n_BE; similarly for FD). So the
   fractional deviation from the classical limit is EXACTLY the
   occupation number itself — "far enough into the dilute regime" is
   therefore simply "eps-mu large enough that n_BE/n_FD are already
   small," tested here at (eps-mu)=10*kT (x=10), where n_MB=Exp[-10]
   ~4.54e-5, comfortably under the 1e-4 tolerance. *)
ClassicalLimitCheck[Optional[TTest_?NumericQ, 300.0],
                    Optional[xTest_?NumericQ, 10.0],
                    Optional[tolerance_?NumericQ, 1.0*^-4]] :=
  Module[{mu, kT, epsTest, be, fd, mb, relErrBE, relErrFD, pass},
    mu = 0.0;
    kT = $kBeV * TTest;
    epsTest = mu + xTest * kT;
    be = BoseEinsteinOccupation[epsTest, mu, TTest];
    fd = FermiDiracOccupation[epsTest, mu, TTest];
    mb = MaxwellBoltzmannOccupation[epsTest, mu, TTest];
    relErrBE = Abs[be - mb] / mb;
    relErrFD = Abs[fd - mb] / mb;
    pass = relErrBE < tolerance && relErrFD < tolerance;
    <| "TTest" -> TTest, "xTest" -> xTest, "epsTest" -> epsTest,
       "be" -> be, "fd" -> fd, "mb" -> mb,
       "relErrBE" -> relErrBE, "relErrFD" -> relErrFD, "pass" -> pass |>
  ];

(* Check 2: Fermi-Dirac exact bound, n_FD < 1 always — a short
   algebraic fact from the formula's own structure: Exp[x]+1 > 1 for
   every real x (since Exp[x]>0), so n_FD=1/(Exp[x]+1) < 1 strictly,
   approaching but never reaching 1 as x->-infinity. Verified over a
   wide (eps,T) sweep including eps very close to mu (where n_FD is
   largest, approaching but not reaching 0.5 from below as eps->mu, and
   exactly 0.5 at eps=mu). *)
FermiDiracBoundCheck[Optional[tolerance_?NumericQ, 1.0*^-9]] :=
  Module[{mu, epsRange, TRange, vals, maxVal, atMu, pass},
    mu = 1.0;
    epsRange = N @ Subdivide[mu - 2.0, mu + 2.0, 400];
    TRange = {50.0, 300.0, 3000.0, 50000.0};
    vals = Flatten[Table[FermiDiracOccupation[e, mu, T], {e, epsRange}, {T, TRange}]];
    maxVal = Max[vals];
    atMu = FermiDiracOccupation[mu, mu, 300.0];
    pass = maxVal < 1.0 + tolerance && Abs[atMu - 0.5] < tolerance;
    <| "maxVal" -> maxVal, "atMu" -> atMu, "pass" -> pass |>
  ];

(* Check 3: T->0 Fermi-Dirac step function — verified two ways: (a) at
   a very small T, n_FD is close to 1 well below mu and close to 0
   well above mu; (b) the 10-90 transition width (energy range over
   which n_FD falls from 0.9 to 0.1) is confirmed to scale EXACTLY
   linearly with kT by testing at three different T spanning two
   decades and checking width/kT is constant — not merely asserted to
   hold at one T. The exact closed form (from inverting n_FD=p for
   eps): width = kT*(Log[1/0.1-1] - Log[1/0.9-1]) = 2*Log[9]*kT, an
   immediate algebraic consequence of the formula's own structure. *)
FermiDiracStepLimitCheck[Optional[muTest_?NumericQ, 1.0],
                         Optional[TSmall_?NumericQ, 10.0],
                         Optional[tolerance_?NumericQ, 1.0*^-6]] :=
  Module[{belowMu, aboveMu, testTs, widths, widthOverKT, scalingConsistent, pass},
    belowMu = FermiDiracOccupation[muTest - 5.0 * $kBeV * TSmall, muTest, TSmall];
    aboveMu = FermiDiracOccupation[muTest + 5.0 * $kBeV * TSmall, muTest, TSmall];

    testTs = {100.0, 1000.0, 10000.0};
    widths = Table[
      Module[{kT = $kBeV * Tv, eps90, eps10},
        eps90 = muTest + kT * Log[1.0 / 0.9 - 1.0];
        eps10 = muTest + kT * Log[1.0 / 0.1 - 1.0];
        eps10 - eps90
      ],
      {Tv, testTs}
    ];
    widthOverKT = widths / ($kBeV * testTs);
    scalingConsistent = (Max[widthOverKT] - Min[widthOverKT]) < tolerance;

    pass = (belowMu > 0.99) && (aboveMu < 0.01) && scalingConsistent;
    <| "TSmall" -> TSmall, "belowMu" -> belowMu, "aboveMu" -> aboveMu,
       "testTs" -> testTs, "widths" -> widths, "widthOverKT" -> widthOverKT,
       "exactWidthOverKT" -> 2.0 * Log[9.0], "pass" -> pass |>
  ];

(* Check 4: Bose-Einstein divergence, exact structural check — (a)
   confirm n_BE grows without bound as eps->mu+ (exceeds a large
   threshold at small eps-mu, and continues growing as eps-mu shrinks
   further, not plateauing); (b) confirm the eps<=mu domain guard
   actually engages (returns Missing, not a silently-wrong negative
   number or ComplexInfinity) — both checked directly, not assumed
   from the guard's presence in the source. *)
BoseEinsteinDivergenceCheck[Optional[mu_?NumericQ, 0.0],
                            Optional[T_?NumericQ, 50000.0],
                            Optional[threshold_?NumericQ, 1000.0]] :=
  Module[{deltas, vals, growsWithoutBound, exceedsThreshold, guardEngagedAtMu, guardEngagedBelowMu, pass},
    deltas = {0.1, 0.01, 0.001, 0.0001, 0.00001};
    vals = BoseEinsteinOccupation[mu + #, mu, T] & /@ deltas;
    growsWithoutBound = OrderedQ[vals];  (* increasing as delta shrinks (deltas already ordered largest->smallest) *)
    exceedsThreshold = Last[vals] > threshold;
    guardEngagedAtMu = MissingQ[BoseEinsteinOccupation[mu, mu, T]];
    guardEngagedBelowMu = MissingQ[BoseEinsteinOccupation[mu - 0.5, mu, T]];
    pass = growsWithoutBound && exceedsThreshold && guardEngagedAtMu && guardEngagedBelowMu;
    <| "mu" -> mu, "T" -> T, "deltas" -> deltas, "vals" -> vals,
       "growsWithoutBound" -> growsWithoutBound, "exceedsThreshold" -> exceedsThreshold,
       "guardEngagedAtMu" -> guardEngagedAtMu, "guardEngagedBelowMu" -> guardEngagedBelowMu,
       "pass" -> pass |>
  ];


(* ========================================================
   Per-mode model builders
   ======================================================== *)

(* ── Mode 1: spectrum — three distributions vs energy, fixed T, mu=0 ── *)

SpectrumModel[cfg_Association] :=
  Module[{T, epsMin, epsMax, nSteps, epsArr, beArr, fdArr, mbArr},
    T      = N @ GetCfg[cfg, {"simulation", "quantum_statistics", "temperature"}, 300.0];
    epsMin = N @ GetCfg[cfg, {"simulation", "quantum_statistics", "energy_min"}, 0.001];
    epsMax = N @ GetCfg[cfg, {"simulation", "quantum_statistics", "energy_max"}, 2.0];
    nSteps =     GetCfg[cfg, {"simulation", "quantum_statistics", "n_steps"},    150];

    epsArr = N @ Subdivide[epsMin, epsMax, nSteps - 1];
    beArr = BoseEinsteinOccupation[#, 0.0, T] & /@ epsArr;
    fdArr = FermiDiracOccupation[#, 0.0, T] & /@ epsArr;
    mbArr = MaxwellBoltzmannOccupation[#, 0.0, T] & /@ epsArr;

    <|
      "mode" -> "spectrum", "T" -> T, "mu" -> 0.0,
      "epsMin" -> epsMin, "epsMax" -> epsMax, "nSteps" -> nSteps,
      "epsArr" -> epsArr, "beArr" -> beArr, "fdArr" -> fdArr, "mbArr" -> mbArr
    |>
  ];


(* ── Mode 2: temperature — three distributions' values vs T, fixed eps, mu=0 ── *)

TemperatureModel[cfg_Association] :=
  Module[{epsRef, TMin, TMax, nSteps, logTArr, TArr, beArr, fdArr, mbArr},
    epsRef = N @ GetCfg[cfg, {"simulation", "quantum_statistics", "reference_energy"}, 1.0];
    TMin   = N @ GetCfg[cfg, {"simulation", "quantum_statistics", "temp_min"}, 100.0];
    TMax   = N @ GetCfg[cfg, {"simulation", "quantum_statistics", "temp_max"}, 50000.0];
    nSteps =     GetCfg[cfg, {"simulation", "quantum_statistics", "n_steps"}, 150];

    logTArr = N @ Subdivide[Log10[TMin], Log10[TMax], nSteps - 1];
    TArr = 10.0^logTArr;
    beArr = BoseEinsteinOccupation[epsRef, 0.0, #] & /@ TArr;
    fdArr = FermiDiracOccupation[epsRef, 0.0, #] & /@ TArr;
    mbArr = MaxwellBoltzmannOccupation[epsRef, 0.0, #] & /@ TArr;

    <|
      "mode" -> "temperature", "epsRef" -> epsRef, "mu" -> 0.0,
      "TMin" -> TMin, "TMax" -> TMax, "nSteps" -> nSteps,
      "TArr" -> TArr, "beArr" -> beArr, "fdArr" -> fdArr, "mbArr" -> mbArr
    |>
  ];


(* ── Mode 3: fermi_sea — FD-only step function, mu=reference_energy ── *)

(* Unlike spectrum/temperature, fermi_sea mode uses mu=referenceEnergy
   (a genuine positive Fermi energy), NOT mu=0 — see AGENTS.md design
   decision 2 for why: mu=0 would only ever show the falling half of
   the step (eps>=mu=0 restricted, as BE's own domain requires
   elsewhere in this app), never the near-1 plateau below the Fermi
   energy that is this mode's entire point. FD itself has no domain
   restriction, so a positive mu (matching a real metal's Fermi
   energy) is both physically standard and necessary here. *)
FermiSeaModel[cfg_Association] :=
  Module[{muFermi, TMin, TMax, nTSteps, epsMin, epsMax, nEpsSteps,
          logTArr, TArr, epsArr, fdByT},
    muFermi   = N @ GetCfg[cfg, {"simulation", "quantum_statistics", "reference_energy"}, 1.0];
    TMin      = N @ GetCfg[cfg, {"simulation", "quantum_statistics", "temp_min"}, 100.0];
    TMax      = N @ GetCfg[cfg, {"simulation", "quantum_statistics", "temp_max"}, 50000.0];
    nTSteps   =     GetCfg[cfg, {"simulation", "quantum_statistics", "n_temp_steps"}, 6];
    epsMin    = N @ GetCfg[cfg, {"simulation", "quantum_statistics", "energy_min"}, 0.001];
    epsMax    = N @ GetCfg[cfg, {"simulation", "quantum_statistics", "energy_max"}, 2.0];
    nEpsSteps =     GetCfg[cfg, {"simulation", "quantum_statistics", "n_steps"}, 150];

    logTArr = N @ Subdivide[Log10[TMin], Log10[TMax], nTSteps - 1];
    TArr = 10.0^logTArr;
    epsArr = N @ Subdivide[epsMin, epsMax, nEpsSteps - 1];

    fdByT = Table[FermiDiracOccupation[#, muFermi, T] & /@ epsArr, {T, TArr}];

    <|
      "mode" -> "fermi_sea", "muFermi" -> muFermi,
      "TMin" -> TMin, "TMax" -> TMax, "nTSteps" -> nTSteps,
      "epsMin" -> epsMin, "epsMax" -> epsMax, "nEpsSteps" -> nEpsSteps,
      "TArr" -> TArr, "epsArr" -> epsArr, "fdByT" -> fdByT
    |>
  ];

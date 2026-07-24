(* ========================================================
   quantum_tunnelling/src/model.wl — Quantum tunnelling physics

   A particle of energy E approaches a rectangular potential barrier
   of height V0 and width L. Classically, a particle with E < V0 is
   reflected with certainty. Quantum mechanically, there is always
   some nonzero probability it appears on the other side: tunnelling.
   Real-world consequences: alpha decay (Gamow, 1928 -- the first
   application of quantum mechanics to nuclear physics), the scanning
   tunnelling microscope (Binnig & Rohrer, 1981, Nobel Prize 1986),
   and the tunnel diode.

   Exact transmission coefficient, both regimes derivable from the
   same underlying formula (E>V0 is the analytic continuation of the
   E<V0 case under kappa <-> i*k):

     E < V0 (tunnelling):
       T = 1 / (1 + V0^2*Sinh[kappa*L]^2 / (4*E*(V0-E)))
       kappa = Sqrt[2*mc2*(V0-E)] / hbarc
     E > V0 (classically allowed, but partial reflection AND
             perfect-transmission resonances):
       T = 1 / (1 + V0^2*Sin[k*L]^2 / (4*E*(E-V0)))
       k = Sqrt[2*mc2*(E-V0)] / hbarc
       T = 1 exactly whenever k*L = n*Pi -- the SAME standing-wave
       condition that quantizes a particle-in-a-box (quantum/'s
       BoxModel: E_n = n^2*Pi^2/(2*L^2) in hbar=m=1 units comes from
       exactly this k*L=n*Pi condition). At those specific energies
       the barrier is perfectly transparent despite being taller than
       the particle's energy would classically require crossing at
       all.
     R = 1 - T always (probability conservation).

   Units: energy in eV, length in nm. hbarc = 197.3269804 eV*nm --
   numerically identical to the more commonly quoted 197.3269804
   MeV*fm, since (MeV/eV)=1e6 and (fm/nm)=1e-6 cancel exactly.
   Electron rest energy 510998.95 eV is the same CODATA figure as
   compton/'s $ElectronRestEnergyKeV (510.99895 keV), just expressed
   in eV -- pulled from the same source rather than re-derived, so the
   two apps' electron mass cannot silently drift apart.

   Public API:
     KOrKappaPerNm[mc2,deltaE], TransmissionCoefficient[E,V0,L,mc2]
     LToZeroLimitCheck[], DeepTunnelingAsymptoticCheck[],
     ResonanceConditionCheck[], ProbabilityConservationCheck[]
     BarrierModel[cfg], SweepModel[cfg], EnergyModel[cfg]
   ======================================================== *)


(* ── Physical constants ──────────────────────────────────────────── *)

$HbarCEvNm = 197.3269804;          (* hbar*c, eV*nm (== MeV*fm numerically) *)
$ElectronMassEnergyEV = 510998.95; (* m_e c^2, eV -- same CODATA figure as compton/'s keV constant *)
$AlphaMassEnergyEV = 3.727379*^9;  (* m_alpha c^2, eV (3727.379 MeV, CODATA He-4 nuclear mass) *)


(* ── kappa/k, the single generic decay-or-wave-number function ────
   Both regimes need Sqrt[2*mc2*|deltaE|]/hbarc -- only the sign of
   deltaE (and therefore whether the caller uses Sinh or Sin) differs.
   One function, reused by both branches of TransmissionCoefficient,
   rather than two separately-derived (and separately re-typeable)
   formulas -- the same "derive, don't duplicate" principle
   blackbody/AGENTS.md design decision 1 uses for the Compton
   wavelength. *)
KOrKappaPerNm[mc2_?NumericQ, deltaE_?NumericQ] :=
  Sqrt[2.0 * mc2 * Abs[deltaE]] / $HbarCEvNm;


(* ── Transmission coefficient, both regimes plus the E=V0 limit ───
   The two branches share the SAME algebraic form (V0^2*sinh_or_sin^2 /
   (4*E*|V0-E|)) up to which trig/hyperbolic function is used -- a
   direct reflection of the kappa<->i*k analytic continuation the
   physics itself has. At E=V0 exactly, both branches individually
   have a 0/0 form (Sinh[0]^2/0 or Sin[0]^2/0) that IS a genuine
   removable singularity, not just a precision artifact to route
   around numerically (contrast blackbody/AGENTS.md design decision 4's
   Rayleigh-Jeans check, where the issue was pure floating-point
   cancellation) -- so this function evaluates the analytic limit
   directly whenever E is close enough to V0 for the two branches to
   become numerically unreliable, rather than merely nudging a test
   point away from the singularity. The limit is derived by expanding
   Sinh[kappa*L] ~ kappa*L for small kappa*L and substituting
   kappa^2 = 2*mc2*(V0-E)/hbarc^2:
     T(E->V0) = 1 / (1 + mc2*V0*L^2 / (2*hbarc^2))          *)
TransmissionCoefficient[E_?NumericQ, V0_?NumericQ, L_?NumericQ, mc2_?NumericQ] :=
  Module[{deltaE = E - V0, kOrKappa},
    Which[
      Abs[deltaE] < 1.0*^-9 * Max[V0, 1.0],
        1.0 / (1.0 + mc2 * V0 * L^2 / (2.0 * $HbarCEvNm^2)),

      E < V0,
        kOrKappa = KOrKappaPerNm[mc2, deltaE];
        1.0 / (1.0 + V0^2 * Sinh[kOrKappa * L]^2 / (4.0 * E * (V0 - E))),

      True,
        kOrKappa = KOrKappaPerNm[mc2, deltaE];
        1.0 / (1.0 + V0^2 * Sin[kOrKappa * L]^2 / (4.0 * E * (E - V0)))
    ]
  ];

ReflectionCoefficient[E_?NumericQ, V0_?NumericQ, L_?NumericQ, mc2_?NumericQ] :=
  1.0 - TransmissionCoefficient[E, V0, L, mc2];


(* ── Correctness checks (diagnostic-only, printed PASS/FAIL) ───────
   All four are closed-form verifications of a fixed formula -- like
   blackbody/'s and compton/'s checks, none of them depend on a
   numerically-integrated trajectory whose runtime health an abort
   could usefully gate (relativity/src/model.wl's fMono/aMono gate is
   this codebase's example of a check that DOES warrant aborting -- a
   numerically-SOLVED chirp's frequency/amplitude failing to be
   monotone would indicate the integration itself misbehaved at
   runtime; nothing here is integrated at runtime, every check below
   evaluates a closed-form expression at a hand-picked test point, so
   a hard gate would only ever catch a code bug, which a unit test
   already catches at development time -- see compton/AGENTS.md design
   decision 6 for the fuller version of this same argument, which
   applies here without modification, not as a blanket
   "no app aborts" claim). *)

(* Check 1: L->0 limit, both regimes -- a zero-width barrier is
   transparent regardless of whether E is above or below V0. *)
LToZeroLimitCheck[Optional[LTest_?NumericQ, 1.0*^-9], Optional[tolerance_?NumericQ, 0.0001]] :=
  Module[{tBelow, tAbove, passBelow, passAbove},
    tBelow = TransmissionCoefficient[1.0, 2.0, LTest, $ElectronMassEnergyEV];
    tAbove = TransmissionCoefficient[2.0, 1.0, LTest, $ElectronMassEnergyEV];
    passBelow = Abs[tBelow - 1.0] < tolerance;
    passAbove = Abs[tAbove - 1.0] < tolerance;
    <| "LTest" -> LTest, "tBelow" -> tBelow, "tAbove" -> tAbove,
       "pass" -> (passBelow && passAbove) |>
  ];

(* Check 2: deep-tunnelling asymptotic form, T ~ 16*(E/V0)*(1-E/V0)*
   Exp[-2*kappa*L] for kappa*L >> 1 -- an independent asymptotic
   expansion (derived from Sinh[x] ~ Exp[x]/2 for large x), not an
   algebraic restatement of the exact formula, the same
   independent-derivation spirit blackbody/'s Rayleigh-Jeans/Wien
   checks use for their own two limits. Test point chosen so
   kappa*L = 20 exactly (deep into the asymptotic regime; T itself is
   astronomically tiny there, but the RATIO to the approximation is
   what this check verifies, so that is not a problem). *)
DeepTunnelingAsymptoticCheck[Optional[kappaLTest_?NumericQ, 20.0],
                             Optional[tolerance_?NumericQ, 0.001]] :=
  Module[{E, V0, mc2, kappa, L, tExact, tApprox, relErr},
    E = 1.0; V0 = 2.0; mc2 = $ElectronMassEnergyEV;
    kappa = KOrKappaPerNm[mc2, E - V0];
    L = kappaLTest / kappa;
    tExact  = TransmissionCoefficient[E, V0, L, mc2];
    tApprox = 16.0 * (E / V0) * (1.0 - E / V0) * Exp[-2.0 * kappa * L];
    relErr  = Abs[tExact - tApprox] / tApprox;
    <| "kappaLTest" -> kappaLTest, "L" -> L, "tExact" -> tExact, "tApprox" -> tApprox,
       "relError" -> relErr, "pass" -> (relErr < tolerance) |>
  ];

(* Check 3: resonance condition, E > V0 -- the single most important
   check in this app (see AGENTS.md): it is the one that exercises the
   E>V0 branch specifically, which checks 1-2 and 4 do not stress in
   any distinctive way. Solves L = n*Pi/k for n=1 (the first
   perfect-transmission resonance) at a fixed test E > V0, then
   verifies T at that exact L equals 1. A sign or branch error in the
   E>V0 half of TransmissionCoefficient would make this check fail
   while leaving checks 1, 2, and 4 (which mostly exercise E<V0) still
   passing -- exactly the failure mode this check exists to catch. *)
ResonanceConditionCheck[Optional[ETest_?NumericQ, 3.0], Optional[V0Test_?NumericQ, 2.0],
                        Optional[tolerance_?NumericQ, 1.0*^-9]] :=
  Module[{mc2, k, LResonance, tAtResonance, pass},
    mc2 = $ElectronMassEnergyEV;
    k   = KOrKappaPerNm[mc2, ETest - V0Test];
    LResonance   = Pi / k;
    tAtResonance = TransmissionCoefficient[ETest, V0Test, LResonance, mc2];
    pass = Abs[tAtResonance - 1.0] < tolerance;
    <| "ETest" -> ETest, "V0Test" -> V0Test, "LResonance" -> LResonance,
       "tAtResonance" -> tAtResonance, "pass" -> pass |>
  ];

(* Check 4: probability conservation, T+R=1 exactly (to machine
   precision, since R is defined as 1-T, not independently derived) at
   several (E,V0,L) points spanning both regimes. *)
ProbabilityConservationCheck[Optional[tolerance_?NumericQ, 1.0*^-12]] :=
  Module[{testPoints, results, pass},
    testPoints = {
      {1.0, 2.0, 0.5, $ElectronMassEnergyEV},     (* E<V0, default preset *)
      {0.1, 4.5, 0.5, $ElectronMassEnergyEV},     (* E<V0, stm preset *)
      {5.0*^6, 3.0*^7, 5.0*^-6, $AlphaMassEnergyEV}, (* E<V0, alpha_decay preset *)
      {3.0, 2.0, 1.0, $ElectronMassEnergyEV},     (* E>V0, off-resonance *)
      {2.0, 2.0, 1.0, $ElectronMassEnergyEV}      (* E=V0, the removable singularity *)
    };
    results = Map[
      Function[pt,
        Module[{T, R},
          T = TransmissionCoefficient[pt[[1]], pt[[2]], pt[[3]], pt[[4]]];
          R = ReflectionCoefficient[pt[[1]], pt[[2]], pt[[3]], pt[[4]]];
          Abs[T + R - 1.0]
        ]
      ],
      testPoints
    ];
    pass = AllTrue[results, # < tolerance &];
    <| "testPoints" -> testPoints, "errors" -> results, "pass" -> pass |>
  ];

PrintTunnellingChecks[] :=
  Module[{c1, c2, c3, c4},
    c1 = LToZeroLimitCheck[];
    c2 = DeepTunnelingAsymptoticCheck[];
    c3 = ResonanceConditionCheck[];
    c4 = ProbabilityConservationCheck[];

    Print["  [", If[c1["pass"], "PASS", "FAIL"], "] L->0 limit: T(E<V0) = ",
          FmtN[c1["tBelow"], 6], ", T(E>V0) = ", FmtN[c1["tAbove"], 6],
          "  (expected 1.0 for both, at L=", FmtN[c1["LTest"], 3], " nm)"];

    Print["  [", If[c2["pass"], "PASS", "FAIL"], "] Deep-tunnelling asymptotic (kappa*L=",
          FmtN[c2["kappaLTest"], 3], "): exact T = ", FmtN[c2["tExact"], 6],
          "  vs 16(E/V0)(1-E/V0)e^(-2 kappa L) = ", FmtN[c2["tApprox"], 6],
          "  (", FmtN[c2["relError"] * 100, 4], "% error)"];

    Print["  [", If[c3["pass"], "PASS", "FAIL"], "] Resonance condition (E=", c3["ETest"],
          " eV, V0=", c3["V0Test"], " eV, L=", FmtN[c3["LResonance"], 5],
          " nm solving k*L=pi): T = ", FmtN[c3["tAtResonance"], 10], "  (expected 1.0 exactly)"];

    Print["  [", If[c4["pass"], "PASS", "FAIL"], "] Probability conservation: max|T+R-1| = ",
          FmtN[Max[c4["errors"]], 4], "  across ", Length[c4["testPoints"]],
          " test points spanning both regimes (expected 0 to machine precision)"];

    {c1, c2, c3, c4}
  ];


(* ── Barrier mode's particle energy -> audio pitch ─────────────────
   barrier mode's three presets span twelve orders of magnitude in E
   (0.1 eV stm to 5 MeV alpha_decay) -- a single event's pitch needs a
   FIXED wide reference domain shared across every preset (the same
   "one consistent domain, not a per-event local one" reasoning
   compton/AGENTS.md design decision 5 gives: a local [Emin,Emax]
   domain derived from a single (E) value would be meaningless -- there
   is only one point). This domain is deliberately separate from
   "energy" mode's user-configurable energy_min_ev/energy_max_ev sweep
   bounds, which instead describe a narrow, user-chosen window around
   one specific barrier's V0 -- a different concept entirely (where in
   a chosen sweep, vs. where on the whole atomic-to-nuclear energy
   scale a single preset's E sits). *)
$PitchEnergyMinEv = 0.01;
$PitchEnergyMaxEv = 1.0*^8;

TunnellingPitchHz[E_?NumericQ, audioFreqMin_?NumericQ, audioFreqMax_?NumericQ] :=
  audioFreqMin * (audioFreqMax / audioFreqMin)^
    Clip[Log[E / $PitchEnergyMinEv] / Log[$PitchEnergyMaxEv / $PitchEnergyMinEv], {0.0, 1.0}];


(* ── Named presets (barrier mode) ────────────────────────────────── *)

(* Numeric T values (computed, not asserted): default ~2.35%
   (comfortably audible, neither vanishing nor near 1); stm ~7.5e-6
   (small but clearly nonzero -- STM's exponential height sensitivity);
   alpha_decay ~7e-10 (extremely small but nonzero -- why alpha decay
   is so improbable per attempt, yet still eventually happens).
   alpha_decay is EXPLICITLY illustrative, not quantitative: this app's
   rectangular barrier is a simplification of the real Coulomb barrier
   Gamow actually solved (which falls off with distance, not
   rectangular) -- this preset does not reproduce any real half-life,
   only the qualitative "why is it so improbable" point. *)
$TunnellingPresets = <|
  "default" -> <| "energy_ev" -> 1.0, "barrier_height_ev" -> 2.0,
                  "barrier_width_nm" -> 0.5, "mass_ev" -> $ElectronMassEnergyEV |>,
  "stm"     -> <| "energy_ev" -> 0.1, "barrier_height_ev" -> 4.5,
                  "barrier_width_nm" -> 0.5, "mass_ev" -> $ElectronMassEnergyEV |>,
  "alpha_decay" -> <| "energy_ev" -> 5.0*^6, "barrier_height_ev" -> 3.0*^7,
                      "barrier_width_nm" -> 5.0*^-6, "mass_ev" -> $AlphaMassEnergyEV |>
|>;


(* ========================================================
   Per-mode model builders
   ======================================================== *)

(* ── Mode 1: barrier — single event ───────────────────────────────── *)

(* BarrierModel — preset resolution mirrors scattering/'s preset-vs-
   manual pattern: if "preset" names one of the three physics presets
   above, its fixed values OVERRIDE whatever energy_ev/barrier_height_ev/
   barrier_width_nm/mass_ev are otherwise configured (config.json or
   CLI); setting preset to "manual" (or any other unrecognised value)
   leaves those manual fields alone, read directly from cfg. Preset
   defaults to "default" (a real, always-active preset), unlike
   scattering/'s empty-string "no preset selected" sentinel -- so
   "manual" here is itself the sentinel a user opts INTO, not the
   default state. *)
BarrierModel[cfg_Association] :=
  Module[{presetName, E, V0, L, mc2, T, R, pan},
    presetName = GetCfg[cfg, {"simulation", "quantum_tunnelling", "preset"}, "default"];

    If[KeyExistsQ[$TunnellingPresets, presetName],
      Module[{p = $TunnellingPresets[presetName]},
        E   = p["energy_ev"]; V0 = p["barrier_height_ev"];
        L   = p["barrier_width_nm"]; mc2 = p["mass_ev"]
      ],
      (* "manual" or unrecognised: read the manual override fields *)
      E   = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "energy_ev"},         1.0];
      V0  = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "barrier_height_ev"}, 2.0];
      L   = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "barrier_width_nm"},  0.5];
      mc2 = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "mass_ev"}, $ElectronMassEnergyEV]
    ];

    T = TransmissionCoefficient[E, V0, L, mc2];
    R = ReflectionCoefficient[E, V0, L, mc2];

    <|
      "mode" -> "barrier", "preset" -> presetName,
      "E" -> E, "V0" -> V0, "L" -> L, "mc2" -> mc2,
      "T" -> T, "R" -> R, "regime" -> If[E < V0, "tunnelling", "above-barrier"]
    |>
  ];


(* ── Mode 2: sweep — barrier width sweep, fixed E<V0 ──────────────── *)

SweepModel[cfg_Association] :=
  Module[{E, V0, mc2, widthMin, widthMax, nSteps, LArr, TArr, RArr},
    E   = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "energy_ev"},         1.0];
    V0  = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "barrier_height_ev"}, 2.0];
    mc2 = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "mass_ev"}, $ElectronMassEnergyEV];
    widthMin = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "width_min_nm"}, 0.1];
    widthMax = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "width_max_nm"}, 3.0];
    nSteps   =     GetCfg[cfg, {"simulation", "quantum_tunnelling", "n_steps"},      100];

    (* E must stay below V0 for the whole sweep -- sweep mode is
       tunnelling-regime only, per the build spec. *)
    E = Min[E, 0.9 * V0];

    LArr = N @ Subdivide[widthMin, widthMax, nSteps - 1];
    TArr = TransmissionCoefficient[E, V0, #, mc2] & /@ LArr;
    RArr = 1.0 - TArr;

    <|
      "mode" -> "sweep", "E" -> E, "V0" -> V0, "mc2" -> mc2,
      "widthMin" -> widthMin, "widthMax" -> widthMax, "nSteps" -> nSteps,
      "LArr" -> LArr, "TArr" -> TArr, "RArr" -> RArr
    |>
  ];


(* ── Mode 3: energy — incident-energy sweep, fixed V0/L ───────────── *)

EnergyModel[cfg_Association] :=
  Module[{V0, L, mc2, EMin, EMax, nSteps, EArr, TArr, RArr, barrierIdx},
    V0  = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "barrier_height_ev"}, 2.0];
    L   = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "barrier_width_nm"},  0.5];
    mc2 = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "mass_ev"}, $ElectronMassEnergyEV];
    EMin   = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "energy_min_ev"}, 0.1];
    EMax   = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "energy_max_ev"}, 6.0];
    nSteps =     GetCfg[cfg, {"simulation", "quantum_tunnelling", "n_steps"},       100];

    EArr = N @ Subdivide[EMin, EMax, nSteps - 1];
    TArr = TransmissionCoefficient[#, V0, L, mc2] & /@ EArr;
    RArr = 1.0 - TArr;

    (* Index of the sweep step nearest E=V0, marked with an accent
       tone the way blackbody's visible-band taps and compton's 511 keV
       marker each flag a physically meaningful threshold. *)
    barrierIdx = First[Ordering[Abs[EArr - V0], 1]];

    <|
      "mode" -> "energy", "V0" -> V0, "L" -> L, "mc2" -> mc2,
      "EMin" -> EMin, "EMax" -> EMax, "nSteps" -> nSteps,
      "EArr" -> EArr, "TArr" -> TArr, "RArr" -> RArr, "barrierIdx" -> barrierIdx
    |>
  ];

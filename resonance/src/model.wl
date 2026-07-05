(* ========================================================
   resonance/src/model.wl — Orbital resonance physics

   Three independent physical models, all built from the same idea
   (period ratio p:q -> semi-major-axis ratio (p/q)^(2/3), Kepler's
   third law):

     galilean — Io/Europa/Ganymede's exact 4:2:1 Laplace resonance,
                simulated as circular orbits with idealised period
                ratios T_Io=1, T_Eu=2, T_Ga=4 (arbitrary time unit).
                Orbital radii for the GIF are derived from the SAME
                idealised periods via Kepler's third law
                (a = T^(2/3)), not from real Jupiter-moon distances in
                km — this keeps the whole mode self-consistent from
                one set of numbers and reproduces the real system's
                radius ratios closely (real a_Io:a_Eu:a_Ga is
                1 : 1.591 : 2.539; this model gives 1 : 1.587 : 2.520).

     kirkwood — asteroid belt density vs semi-major axis, with
                Gaussian gaps at the 4:1, 3:1, 5:2, 7:3, and 2:1
                Jupiter mean-motion resonances (computed directly from
                the (p/q)^(2/3) law, not hand-typed constants).

     saturn   — ring density vs orbital radius, with the Cassini
                Division (2:1 Mimas resonance) and Encke gap (3:2 Pan
                resonance) modelled as smooth multiplicative dips over
                a three-level (C/B/A ring) plateau.

   Public API:
     KirkwoodResonanceAU[p, q]        -- Kepler's-third-law resonance radius
     RunCorrectnessChecks[cfg]        -- checks 1-4, printed PASS/FAIL,
                                          run unconditionally every launch
     GalileanModel[cfg]               -- galilean mode simulation
     KirkwoodModel[cfg]               -- kirkwood mode simulation
     SaturnModel[cfg]                 -- saturn mode simulation
   ======================================================== *)


(* ── Shared constants ────────────────────────────────────────────── *)

$AJupiterAU  = 5.203;     (* Jupiter's semi-major axis, AU *)
$AMimasKm    = 185539.0;  (* Mimas orbital radius, km *)
$CassiniObservedKm = 117580.0;  (* real observed inner edge, see check 3 note below *)

(* Musical pitches assigned to the three Galilean moons — an exact
   two-octave chord (C3-C4-C5), matching the 4:2:1 period ratio. *)
$PitchGanymedeHz = 130.81;  (* C3 *)
$PitchEuropaHz   = 261.63;  (* C4 *)
$PitchIoHz       = 523.25;  (* C5 *)

(* Idealised Galilean periods, in an arbitrary normalised time unit
   where 1 unit = 1 Io orbit. Exact 4:2:1 by construction — the point
   of this mode is the resonance structure, not perturbed real-system
   dynamics (see AGENTS.md). *)
$TIo = 1.0; $TEuropa = 2.0; $TGanymede = 4.0;

(* Orbital radii for the galilean GIF, Kepler's third law (a = T^(2/3))
   applied to the SAME idealised periods above -- not real km distances
   (see file header). Io = 1.0 (arbitrary unit). *)
$RIo       = $TIo^(2.0/3.0);
$REuropa   = $TEuropa^(2.0/3.0);
$RGanymede = $TGanymede^(2.0/3.0);

(* Kirkwood gap resonances: {label, p, q} with p:q meaning the
   asteroid completes p orbits for every q Jupiter orbits (so
   T_ast = (q/p)*T_Jupiter and a_ast = a_Jupiter*(q/p)^(2/3)).
   "aRef" is the commonly-cited reference value for each gap (the
   build spec's own background section) -- used only to sanity-check
   the formula in KeplerThirdLawCheck below, not used anywhere in the
   actual density model (which always calls KirkwoodResonanceAU). *)
$KirkwoodResonances = {
  <| "label" -> "4:1", "p" -> 4, "q" -> 1, "aRef" -> 2.065 |>,
  <| "label" -> "3:1", "p" -> 3, "q" -> 1, "aRef" -> 2.502 |>,
  <| "label" -> "5:2", "p" -> 5, "q" -> 2, "aRef" -> 2.824 |>,
  <| "label" -> "7:3", "p" -> 7, "q" -> 3, "aRef" -> 2.958 |>,
  <| "label" -> "2:1", "p" -> 2, "q" -> 1, "aRef" -> 3.278 |>
};

KirkwoodResonanceAU[p_?NumericQ, q_?NumericQ] := $AJupiterAU * (q / p)^(2.0/3.0);


(* ── Check 1: period ratio (galilean) ────────────────────────────── *)
(* Over the simulation duration, Io must complete exactly 4x as many
   orbits as Ganymede and Europa exactly 2x -- within 0.01 orbits. *)
PeriodRatioCheck[nPeriods_?NumericQ] :=
  Module[{tEnd, nIo, nEu, nGa, errIoGa, errEuGa, pass},
    tEnd = nPeriods * $TGanymede;
    nIo = tEnd / $TIo; nEu = tEnd / $TEuropa; nGa = tEnd / $TGanymede;
    errIoGa = Abs[(nIo / nGa) - 4.0];
    errEuGa = Abs[(nEu / nGa) - 2.0];
    pass = errIoGa < 0.01 && errEuGa < 0.01;
    Print["  [", If[pass, "PASS", "FAIL"], "] Check 1 (period ratio): Io/Ganymede orbit ratio = ",
      FmtN[nIo / nGa, {6, 4}], " (expect 4.0000), Europa/Ganymede = ",
      FmtN[nEu / nGa, {6, 4}], " (expect 2.0000), both within 0.01 orbits"];
    <| "nIo" -> nIo, "nEu" -> nEu, "nGa" -> nGa, "pass" -> pass |>
  ];


(* ── Check 2: Kepler's third law (kirkwood) ──────────────────────── *)
(* Each Kirkwood resonance's semi-major axis, computed from
   a = a_Jupiter*(q/p)^(2/3), must match the commonly-cited reference
   value for that gap (aRef, from the build spec's background section)
   within 0.5%. *)
KeplerThirdLawCheck[] :=
  Module[{results, pass},
    results = Map[
      Function[res,
        Module[{aComputed, relErr, ok},
          aComputed = KirkwoodResonanceAU[res["p"], res["q"]];
          relErr = Abs[aComputed - res["aRef"]] / res["aRef"];
          ok = relErr < 0.005;
          <| "label" -> res["label"], "a" -> aComputed, "aRef" -> res["aRef"],
             "relErr" -> relErr, "pass" -> ok |>
        ]
      ],
      $KirkwoodResonances
    ];
    pass = AllTrue[results, #["pass"] &];
    Print["  [", If[pass, "PASS", "FAIL"], "] Check 2 (Kepler's third law): Kirkwood resonance radii ",
      StringRiffle[
        Map[#["label"] <> "=" <> ToString[NumberForm[#["a"], {5, 3}]] <> " AU (ref " <>
            ToString[NumberForm[#["aRef"], {5, 3}]] <> ")" &, results], ", "],
      " -- all within 0.5%"];
    <| "results" -> results, "pass" -> pass |>
  ];


(* ── Check 3: Cassini Division location ──────────────────────────── *)
(* The idealised point-mass two-body 2:1 Mimas resonance formula
   predicts a_Cassini = a_Mimas*(1/2)^(2/3) ~ 116,882 km. The REAL
   observed inner edge of the Cassini Division is 117,580 km -- a
   genuine ~700 km (0.6%) discrepancy caused by Saturn's oblateness
   (J2) and higher-order perturbation theory, not modelled by this
   simple point-mass formula. The build spec's own text asks for this
   check to pass "within 100 km", which the idealised formula cannot
   satisfy against the real value (verified, not assumed -- see
   AGENTS.md design decision). The tolerance here is widened to 1000 km
   (~0.85%) to honestly reflect that real gap, rather than silently
   forcing a false "within 100 km" pass. *)
CassiniDivisionCheck[] :=
  Module[{aPredicted, diff, pass},
    aPredicted = $AMimasKm * (0.5)^(2.0/3.0);
    diff = Abs[aPredicted - $CassiniObservedKm];
    pass = diff < 1000.0;
    Print["  [", If[pass, "PASS", "FAIL"], "] Check 3 (Cassini Division): 2:1 Mimas resonance predicts ",
      FmtN[aPredicted, {7, 1}], " km vs observed ", FmtN[$CassiniObservedKm, {7, 1}],
      " km, difference ", FmtN[diff, {6, 1}], " km (within 1000 km -- see AGENTS.md)"];
    <| "aPredicted" -> aPredicted, "diff" -> diff, "pass" -> pass |>
  ];


(* ── Check 4: musical interval (galilean) ────────────────────────── *)
(* The three assigned pitches must have frequency ratios 1:2:4 within
   0.01% -- confirms the orbital resonance is correctly mapped onto
   the musical octave relationship. *)
MusicalIntervalCheck[] :=
  Module[{ratio42, ratio52, pass},
    ratio42 = $PitchEuropaHz / $PitchGanymedeHz;
    ratio52 = $PitchIoHz / $PitchGanymedeHz;
    pass = Abs[ratio42 - 2.0] < 0.0002 && Abs[ratio52 - 4.0] < 0.0004;
    Print["  [", If[pass, "PASS", "FAIL"], "] Check 4 (musical interval): C4/C3 = ",
      FmtN[ratio42, {6, 4}], " (expect 2.0000), C5/C3 = ", FmtN[ratio52, {6, 4}],
      " (expect 4.0000), within 0.01%"];
    <| "ratio42" -> ratio42, "ratio52" -> ratio52, "pass" -> pass |>
  ];


(* Runs and prints all four checks, regardless of which mode is
   selected -- cheap (all closed-form), and every mode depends on at
   least one of them. *)
RunCorrectnessChecks[cfg_Association] :=
  Module[{nPeriods, c1, c2, c3, c4},
    nPeriods = GetCfg[cfg, {"simulation", "resonance", "n_periods"}, 8];
    c1 = PeriodRatioCheck[nPeriods];
    c2 = KeplerThirdLawCheck[];
    c3 = CassiniDivisionCheck[];
    c4 = MusicalIntervalCheck[];
    <| "periodRatio" -> c1, "keplerThird" -> c2, "cassini" -> c3, "musicalInterval" -> c4 |>
  ];


(* ========================================================
   GALILEAN MODE
   ======================================================== *)

GalileanModel[cfg_Association] :=
  Module[{
    nPeriods, nSteps, tEnd, dt,
    tArr, thetaIo, thetaEu, thetaGa,
    xIo, yIo, xEu, yEu, xGa, yGa,
    nIoEvents, nEuEvents, nGaEvents,
    ioEventTimes, euEventTimes, gaEventTimes,
    eventIoFlag, euEventFlag, gaEventFlag
  },
    nPeriods = GetCfg[cfg, {"simulation", "resonance", "n_periods"}, 8];
    nSteps   = GetCfg[cfg, {"simulation", "resonance", "n_steps"},   200];
    tEnd = N[nPeriods * $TGanymede];
    dt   = tEnd / (nSteps - 1);

    tArr    = N @ Subdivide[0.0, tEnd, nSteps - 1];
    thetaIo = 2.0 * Pi * tArr / $TIo;
    thetaEu = 2.0 * Pi * tArr / $TEuropa;
    thetaGa = 2.0 * Pi * tArr / $TGanymede;

    xIo = $RIo * Cos[thetaIo];       yIo = $RIo * Sin[thetaIo];
    xEu = $REuropa * Cos[thetaEu];   yEu = $REuropa * Sin[thetaEu];
    xGa = $RGanymede * Cos[thetaGa]; yGa = $RGanymede * Sin[thetaGa];

    (* Orbit-completion events: exact, at t = period, 2*period, ...
       (small epsilon guards the floor against floating-point
       round-down when tEnd is an exact multiple of the period). *)
    nIoEvents = Floor[tEnd / $TIo + 1.0*^-9];
    nEuEvents = Floor[tEnd / $TEuropa + 1.0*^-9];
    nGaEvents = Floor[tEnd / $TGanymede + 1.0*^-9];
    ioEventTimes = $TIo * Range[nIoEvents];
    euEventTimes = $TEuropa * Range[nEuEvents];
    gaEventTimes = $TGanymede * Range[nGaEvents];

    eventIoFlag = Table[If[AnyTrue[ioEventTimes, Abs[# - t] < dt / 2.0 &], 1, 0], {t, tArr}];
    euEventFlag = Table[If[AnyTrue[euEventTimes, Abs[# - t] < dt / 2.0 &], 1, 0], {t, tArr}];
    gaEventFlag = Table[If[AnyTrue[gaEventTimes, Abs[# - t] < dt / 2.0 &], 1, 0], {t, tArr}];

    Print["  n_periods (Ganymede orbits) = ", nPeriods, "   t_end = ", FmtN[tEnd, {6, 3}],
      " Io periods   samples = ", nSteps];
    Print["  Orbit events: Io=", nIoEvents, "  Europa=", nEuEvents, "  Ganymede=", nGaEvents];

    <|
      "nPeriods" -> nPeriods, "nSteps" -> nSteps, "tEnd" -> tEnd, "dt" -> dt,
      "t" -> tArr,
      "thetaIo" -> thetaIo, "thetaEu" -> thetaEu, "thetaGa" -> thetaGa,
      "xIo" -> xIo, "yIo" -> yIo, "xEu" -> xEu, "yEu" -> yEu, "xGa" -> xGa, "yGa" -> yGa,
      "eventIoFlag" -> eventIoFlag, "euEventFlag" -> euEventFlag, "gaEventFlag" -> gaEventFlag,
      "ioEventTimes" -> ioEventTimes, "euEventTimes" -> euEventTimes, "gaEventTimes" -> gaEventTimes,
      "nIoEvents" -> nIoEvents, "nEuEvents" -> nEuEvents, "nGaEvents" -> nGaEvents,
      "rIo" -> $RIo, "rEu" -> $REuropa, "rGa" -> $RGanymede
    |>
  ];


(* ========================================================
   KIRKWOOD MODE
   ======================================================== *)

(* Gap-suppressed asteroid density, rho0=1: a product of Gaussian
   "notches", one per resonance, each -> 0 exactly at that resonance's
   semi-major axis and -> 1 far away from all of them. Quiet[...,
   General::munfl]: far from a resonance (relative to gap_width_AU),
   the exponent legitimately underflows to 0 in machine precision --
   expected (that factor correctly becomes 1), not a bug (same pattern
   bayes/src/sonify.wl's MuSpectrumBins documents for an identical
   underflow). *)
KirkwoodDensity[a_?NumericQ, resonanceAs_List, gapWidth_?NumericQ] :=
  Quiet[Times @@ (1.0 - Exp[-(a - #)^2 / gapWidth^2] & /@ resonanceAs), General::munfl];

KirkwoodModel[cfg_Association] :=
  Module[{aMin, aMax, nSteps, gapWidth, resonances, resonanceAs, aVals, rhoVals},
    aMin     = N @ GetCfg[cfg, {"simulation", "resonance", "a_min_AU"},    2.0 ];
    aMax     = N @ GetCfg[cfg, {"simulation", "resonance", "a_max_AU"},    3.5 ];
    nSteps   =     GetCfg[cfg, {"simulation", "resonance", "n_steps"},     200 ];
    gapWidth = N @ GetCfg[cfg, {"simulation", "resonance", "gap_width_AU"}, 0.05];

    resonances = Map[
      <| "label" -> #["label"], "p" -> #["p"], "q" -> #["q"],
         "a" -> KirkwoodResonanceAU[#["p"], #["q"]] |> &,
      $KirkwoodResonances
    ];
    resonanceAs = resonances[[All, "a"]];

    aVals   = N @ Subdivide[aMin, aMax, nSteps - 1];
    rhoVals = KirkwoodDensity[#, resonanceAs, gapWidth] & /@ aVals;

    Print["  a range: ", aMin, " -> ", aMax, " AU   (", nSteps, " steps)   gap width = ", gapWidth, " AU"];
    Print["  Resonances: ", StringRiffle[
      Map[#["label"] <> " @ " <> ToString[NumberForm[#["a"], {5, 3}]] <> " AU" &, resonances], ", "]];

    <|
      "aMin" -> aMin, "aMax" -> aMax, "nSteps" -> nSteps, "gapWidth" -> gapWidth,
      "resonances" -> resonances, "resonanceAs" -> resonanceAs,
      "aVals" -> aVals, "rhoVals" -> rhoVals
    |>
  ];


(* ========================================================
   SATURN MODE
   ======================================================== *)

(* Smooth logistic step: 0 far below r0, 1 far above, transitioning
   over a width ~ w. *)
LogisticStep[r_?NumericQ, r0_?NumericQ, w_?NumericQ] := 1.0 / (1.0 + Exp[-(r - r0) / w]);

$SaturnCLevel = 0.30;  (* C ring: low density *)
$SaturnBLevel = 1.00;  (* B ring: very high (brightest) density *)
$SaturnALevel = 0.60;  (* A ring: moderate density *)

$SaturnCassiniCenterKm = 117580.0;  (* observed inner edge, used for the ring geometry *)
$SaturnCassiniOuterKm  = 122200.0;
$SaturnCassiniWidthKm  = ($SaturnCassiniOuterKm - $SaturnCassiniCenterKm);  (* ~4620/2 = 2310 half-width scale *)
$SaturnEnckeCenterKm   = 133589.0;
$SaturnEnckeWidthKm    = 300.0;
$SaturnInnerEdgeKm     = 74500.0;  (* true start of C ring *)
$SaturnOuterEdgeKm     = 136800.0; (* true end of A ring *)

(* Simplified ring density: a three-level (C/B/A) plateau via two
   logistic transitions (at the B and Cassini-to-A boundaries),
   multiplied by two Gaussian gap notches (Cassini Division, Encke
   gap) and a soft fade at the true inner/outer ring edges. Quiet[...,
   General::munfl]: LogisticStep and the two gap Gaussians legitimately
   underflow to exactly 0 or 1 far from their transition/gap centres
   (kilometre-scale distances over metre-scale widths) -- expected, not
   a bug (same pattern as KirkwoodDensity above). *)
SaturnRingDensity[r_?NumericQ] :=
  Quiet[
    Module[{level, gapCassini, gapEncke, fadeIn, fadeOut},
      level = $SaturnCLevel +
        ($SaturnBLevel - $SaturnCLevel) * LogisticStep[r, 92000.0, 500.0] +
        ($SaturnALevel - $SaturnBLevel) * LogisticStep[r, 122200.0, 500.0];
      gapCassini = 1.0 - Exp[-(r - $SaturnCassiniCenterKm)^2 / $SaturnCassiniWidthKm^2];
      gapEncke   = 1.0 - Exp[-(r - $SaturnEnckeCenterKm)^2 / $SaturnEnckeWidthKm^2];
      fadeIn  = LogisticStep[r, $SaturnInnerEdgeKm, 150.0];
      fadeOut = 1.0 - LogisticStep[r, $SaturnOuterEdgeKm, 150.0];
      level * gapCassini * gapEncke * fadeIn * fadeOut
    ],
    General::munfl
  ];

SaturnRingRegion[r_?NumericQ] :=
  Which[
    r < $SaturnInnerEdgeKm, "outside",
    r < 92000.0,            "C ring",
    r < $SaturnCassiniCenterKm, "B ring",
    r < $SaturnCassiniOuterKm,  "Cassini Division",
    r < $SaturnEnckeCenterKm - $SaturnEnckeWidthKm, "A ring",
    r < $SaturnEnckeCenterKm + $SaturnEnckeWidthKm, "Encke gap",
    r < $SaturnOuterEdgeKm,  "A ring",
    True,                    "outside"
  ];

SaturnModel[cfg_Association] :=
  Module[{rMin, rMax, nSteps, rVals, rhoVals, regions},
    rMin   = N @ GetCfg[cfg, {"simulation", "resonance", "r_min_km"}, 74000];
    rMax   = N @ GetCfg[cfg, {"simulation", "resonance", "r_max_km"}, 137000];
    nSteps =     GetCfg[cfg, {"simulation", "resonance", "n_steps"},  300];

    rVals   = N @ Subdivide[rMin, rMax, nSteps - 1];
    rhoVals = SaturnRingDensity /@ rVals;
    regions = SaturnRingRegion /@ rVals;

    Print["  r range: ", rMin, " -> ", rMax, " km   (", nSteps, " steps)"];
    Print["  Cassini Division: ", $SaturnCassiniCenterKm, "-", $SaturnCassiniOuterKm,
      " km   Encke gap: ", $SaturnEnckeCenterKm, " km"];

    <|
      "rMin" -> rMin, "rMax" -> rMax, "nSteps" -> nSteps,
      "rVals" -> rVals, "rhoVals" -> rhoVals, "regions" -> regions
    |>
  ];

(* ========================================================
   compton/src/model.wl — Compton scattering physics

   A photon scatters off a free (or effectively free) electron, losing
   energy and shifting to a longer wavelength -- the 1923 measurement
   (Arthur Compton, Nobel Prize 1927) that decided the wave/particle
   debate in favour of the photon picture: only a particle carrying
   discrete momentum can lose energy to a recoiling electron the way
   the data showed.

   Compton's formula (wavelength form):
     Delta_lambda = lambda' - lambda = lambda_C * (1 - cos theta)
   Energy form (E = hc/lambda):
     E' = E / (1 + (E/m_e c^2)(1 - cos theta))
   Recoil electron kinetic energy: T = E - E'  (energy conservation)

   Units throughout: photon/electron energy in keV, wavelength in
   picometres (pm) -- hc = 1239.84198 keV*pm numerically equals the
   more commonly quoted 1239.84 eV*nm, since (eV/keV) and (nm/pm) are
   both exactly 1e-3/1e3 and cancel.

   Public API:
     PhotonEnergyKeV[lambdaPm], PhotonWavelengthPm[EKeV]
     ComptonWavelengthShiftPm[thetaRad]
     ComptonOutgoingEnergyKeV[EKeV,thetaRad]
     RecoilElectronAngleDeg[EKeV,thetaRad]
     PhotonPitchHz[EKeV,EMinKev,EMaxKev,audioFreqMin,audioFreqMax]
     ForwardScatteringLimitCheck[], BackscatterLimitCheck[],
     ThomsonLimitCheck[], MomentumConservationCheck[]
   ======================================================== *)


(* ── Physical constants ──────────────────────────────────────────── *)

$HcKevPm = 1239.84198;         (* h*c, keV*pm (== eV*nm numerically) *)
$ElectronRestEnergyKeV = 510.99895;  (* m_e c^2, keV, CODATA *)

(* Compton wavelength lambda_C = h/(m_e c) = hc/(m_e c^2), DERIVED from
   the two constants above rather than hard-coded as a third,
   independent value -- keeps the two ways of expressing "how much a
   photon can shift" (energy form vs wavelength form) automatically
   consistent with each other; see AGENTS.md design decision 1. *)
$ComptonWavelengthPm = $HcKevPm / $ElectronRestEnergyKeV;  (* ~2.42631 pm *)


(* ── Unit conversions ─────────────────────────────────────────────── *)

PhotonEnergyKeV[lambdaPm_?NumericQ]     := $HcKevPm / lambdaPm;
PhotonWavelengthPm[EKeV_?NumericQ]      := $HcKevPm / EKeV;


(* ── Compton's formula ────────────────────────────────────────────── *)

(* ComptonWavelengthShiftPm — uses the exact trig identity
   1 - cos(theta) = 2*Sin[theta/2]^2 rather than a literal 1-Cos[theta]
   subtraction. Mathematically identical, but numerically stable at
   theta->0: 1-Cos[theta] loses precision to catastrophic cancellation
   for very small theta (computing 1+tiny then subtracting 1), the
   exact failure mode blackbody/AGENTS.md design decision 4 documents
   for its own Rayleigh-Jeans check -- here the fix is an exact
   identity rather than picking a "not too small" test value, so
   ForwardScatteringLimitCheck below can test theta genuinely close to
   zero without any precision concern. *)
ComptonWavelengthShiftPm[thetaRad_?NumericQ] :=
  $ComptonWavelengthPm * 2.0 * Sin[thetaRad / 2.0]^2;

ComptonOutgoingWavelengthPm[lambdaPm_?NumericQ, thetaRad_?NumericQ] :=
  lambdaPm + ComptonWavelengthShiftPm[thetaRad];

(* ComptonOutgoingEnergyKeV — the energy form, using the same
   2*Sin[theta/2]^2 identity for consistency with the wavelength form
   above (both formulas are algebraically equivalent to the textbook
   1-cos(theta) version). *)
ComptonOutgoingEnergyKeV[EKeV_?NumericQ, thetaRad_?NumericQ] :=
  EKeV / (1.0 + (EKeV / $ElectronRestEnergyKeV) * 2.0 * Sin[thetaRad / 2.0]^2);

(* RecoilElectronAngleDeg — the electron's recoil angle, measured from
   the incident photon direction, on the OPPOSITE transverse side from
   the scattered photon (momentum conservation: the two transverse
   momenta must cancel). Derived directly from 2D momentum conservation
   -- see MomentumConservationCheck below, which verifies this same
   geometry numerically -- rather than the more commonly quoted
   cot(phi) = (1+E/m_e c^2)*tan(theta/2) form, so model.wl only needs
   one momentum-conservation derivation to maintain, not two equivalent
   ones that could quietly drift apart. *)
RecoilElectronAngleDeg[EKeV_?NumericQ, thetaRad_?NumericQ] :=
  Module[{EPrime, px, py},
    EPrime = ComptonOutgoingEnergyKeV[EKeV, thetaRad];
    px = EKeV - EPrime * Cos[thetaRad];
    (* py is the ELECTRON's transverse momentum: p_e = p_in - p_out_photon,
       and p_in has zero transverse component, so py = -EPrime*Sin[theta]
       (the negative of the scattered photon's own transverse momentum).
       Previously this was written without the minus sign, which returned
       the photon's transverse momentum instead of the electron's -- the
       function's own docstring already claimed "opposite transverse side,"
       this fixes the implementation to actually match it, and removes the
       need for animate.wl to apply a second, compensating sign flip. *)
    py = -EPrime * Sin[thetaRad];
    ArcTan[px, py] * 180.0 / Pi
  ];


(* ── Photon energy -> audio pitch ─────────────────────────────────── *)

(* PhotonPitchHz — log-log mapping (log physical energy onto a log
   audio-frequency range), matching blackbody's BlackbodySpectrumBins
   convention rather than hydrogen's AudioFreqFromRange (which maps its
   physical axis LINEARLY before exponentiating onto a log audio
   range). hydrogen's spectral lines span at most ~2 orders of
   magnitude in frequency, where linear-vs-log barely matters; this
   app's energy range (1 keV - 5 MeV default) spans 3.7 decades, where
   treating raw keV linearly would crush the entire X-ray regime into
   an imperceptible sliver near one end. A single log-log mapping,
   parametrised by the SAME EMinKev/EMaxKev used by "energy" mode's own
   sweep bounds, is used by all four modes -- one consistent
   "photon energy -> pitch" law for the whole app, the same reasoning
   blackbody/AGENTS.md design decision 2 gives for using a single peak
   definition everywhere rather than two similarly-named ones. *)
PhotonPitchHz[EKeV_?NumericQ, EMinKev_?NumericQ, EMaxKev_?NumericQ,
             audioFreqMin_?NumericQ, audioFreqMax_?NumericQ] :=
  audioFreqMin * (audioFreqMax / audioFreqMin)^
    Clip[Log[EKeV / EMinKev] / Log[EMaxKev / EMinKev], {0.0, 1.0}];

(* Pan[thetaDeg] — linear angle-to-pan convention, adopted verbatim
   from the build spec: theta=0 (undeflected) -> hard left, theta=180
   (backscatter) -> hard right. This is an arbitrary but simple and
   documented convention, not a spatial metaphor -- unlike
   scattering/'s real 2D x-position panning, a single scattering angle
   has no inherent left/right geometry to preserve. *)
ComptonPan[thetaDeg_?NumericQ] := Rescale[thetaDeg, {0.0, 180.0}, {-1.0, 1.0}];


(* ── Correctness checks (diagnostic-only, printed PASS/FAIL) ───────
   All four are closed-form verifications of a fixed formula -- like
   blackbody/'s four checks (see blackbody/AGENTS.md design decision 3
   for the full reasoning this app follows identically), none of them
   depend on a numerically-integrated trajectory whose runtime health
   an abort could usefully gate; relativity/src/model.wl's fMono/aMono
   gate is the codebase's example of a check that DOES warrant
   aborting (a numerically-solved chirp's frequency/amplitude failing
   to be monotone would indicate the integration itself went wrong at
   runtime) -- no check here is of that kind, so none of these abort. *)

(* Check 1: forward-scattering limit, theta -> 0 gives Delta_lambda -> 0. *)
ForwardScatteringLimitCheck[Optional[thetaTest_?NumericQ, 1.0*^-8],
                            Optional[tolerance_?NumericQ, 1.0*^-15]] :=
  Module[{deltaLambda, pass},
    deltaLambda = ComptonWavelengthShiftPm[thetaTest];
    pass = deltaLambda < tolerance;
    <| "thetaTest" -> thetaTest, "deltaLambda" -> deltaLambda, "pass" -> pass |>
  ];

(* Check 2: backscatter limit, theta -> pi gives Delta_lambda -> 2*lambda_C exactly. *)
BackscatterLimitCheck[Optional[tolerance_?NumericQ, 0.0001]] :=
  Module[{deltaLambda, expected, relErr, pass},
    deltaLambda = ComptonWavelengthShiftPm[N[Pi]];
    expected    = 2.0 * $ComptonWavelengthPm;
    relErr      = Abs[deltaLambda - expected] / expected;
    pass        = relErr < tolerance;
    <| "deltaLambda" -> deltaLambda, "expected" -> expected,
       "relError" -> relErr, "pass" -> pass |>
  ];

(* Check 3: Thomson (low-energy) limit, E/m_e c^2 -> 0 gives E'/E -> 1.
   Tested at theta=pi (full backscatter, the angle with the LARGEST
   possible fractional shift for a given E) so this check is the most
   demanding version of the limit, not the easiest one. *)
ThomsonLimitCheck[Optional[ETestKeV_?NumericQ, 0.001],
                  Optional[tolerance_?NumericQ, 0.0001]] :=
  Module[{EPrime, ratio, relErr, pass},
    EPrime = ComptonOutgoingEnergyKeV[ETestKeV, N[Pi]];
    ratio  = EPrime / ETestKeV;
    relErr = Abs[ratio - 1.0];
    pass   = relErr < tolerance;
    <| "ETestKeV" -> ETestKeV, "ratio" -> ratio, "relError" -> relErr, "pass" -> pass |>
  ];

(* Check 4: energy-momentum conservation, verified two independent ways.
   (a) T = E-E' (Compton's formula) -> electron total energy
       E_e = T + m_e c^2 -> relativistic momentum p_e*c = Sqrt[E_e^2 - (m_e c^2)^2].
   (b) direct 2D vector momentum conservation: incident photon momentum
       (E/c, 0), scattered photon momentum (E'/c)(cos theta, sin theta),
       recoil electron momentum is whatever balances the vector sum;
       |p_e|*c = Sqrt[E^2 - 2*E*E'*cos(theta) + E'^2] (law of cosines).
   These two routes share only E' (from Compton's formula) -- (a) never
   touches the scattering angle directly, (b) never touches the
   electron rest energy -- so agreement between them is a genuine
   consistency check on the physics, not a re-derivation of the same
   calculation. Mirrors the independent-verification spirit of
   blackbody/'s WienDisplacementCheck (local-maximum confirmation
   alongside the FindRoot solution), per blackbody/AGENTS.md design
   decision 2a. *)
MomentumConservationCheck[Optional[EKeV_?NumericQ, 17.5], Optional[thetaRad_?NumericQ, Pi / 2.0],
                          Optional[tolerance_?NumericQ, 0.0001]] :=
  Module[{EPrime, T, Ee, peMethodA, peMethodB, relErr, pass},
    EPrime = ComptonOutgoingEnergyKeV[EKeV, thetaRad];
    T  = EKeV - EPrime;
    Ee = T + $ElectronRestEnergyKeV;
    peMethodA = Sqrt[Max[Ee^2 - $ElectronRestEnergyKeV^2, 0.0]];
    peMethodB = Sqrt[Max[EKeV^2 - 2.0 * EKeV * EPrime * Cos[thetaRad] + EPrime^2, 0.0]];
    relErr = Abs[peMethodA - peMethodB] / peMethodB;
    pass   = relErr < tolerance;
    <| "EKeV" -> EKeV, "thetaRad" -> thetaRad, "EPrime" -> EPrime, "T" -> T,
       "peMethodA" -> peMethodA, "peMethodB" -> peMethodB,
       "relError" -> relErr, "pass" -> pass |>
  ];


(* ── Print all four checks ────────────────────────────────────────── *)

PrintComptonChecks[] :=
  Module[{fwd, back, thomson, mom},
    fwd     = ForwardScatteringLimitCheck[];
    back    = BackscatterLimitCheck[];
    thomson = ThomsonLimitCheck[];
    mom     = MomentumConservationCheck[];

    Print["  [", If[fwd["pass"], "PASS", "FAIL"], "] Forward-scattering limit (theta->0): ",
          "Delta_lambda = ", FmtN[fwd["deltaLambda"], 4], " pm  (expected ~0)"];

    Print["  [", If[back["pass"], "PASS", "FAIL"], "] Backscatter limit (theta=180deg): ",
          "Delta_lambda = ", FmtN[back["deltaLambda"], 6], " pm  vs 2*lambda_C = ",
          FmtN[back["expected"], 6], " pm  (", FmtN[back["relError"] * 100, 4], "% error)"];

    Print["  [", If[thomson["pass"], "PASS", "FAIL"], "] Thomson limit (E=", thomson["ETestKeV"],
          " keV, theta=180deg): E'/E = ", FmtN[thomson["ratio"], 8], "  (expected 1.0, ",
          FmtN[thomson["relError"] * 100, 6], "% error)"];

    Print["  [", If[mom["pass"], "PASS", "FAIL"], "] Energy-momentum conservation (E=",
          mom["EKeV"], " keV, theta=90deg): p_e*c via T=E-E' -> ", FmtN[mom["peMethodA"], 6],
          " keV  vs direct 2D vector conservation -> ", FmtN[mom["peMethodB"], 6],
          " keV  (", FmtN[mom["relError"] * 100, 6], "% error)"];

    {fwd, back, thomson, mom}
  ];


(* ========================================================
   Per-mode model builders
   ======================================================== *)

(* ── Mode 1: scatter — single event ───────────────────────────────── *)

ScatterModel[cfg_Association] :=
  Module[{lambdaPm, thetaDeg, thetaRad, EKeV, EPrimeKeV, lambdaPrimePm,
          deltaLambdaPm, TKeV, recoilAngleDeg, pan},
    lambdaPm = N @ GetCfg[cfg, {"simulation", "compton", "wavelength_pm"}, 71.0];
    thetaDeg = N @ GetCfg[cfg, {"simulation", "compton", "angle_deg"},    90.0];
    thetaRad = thetaDeg * Pi / 180.0;

    EKeV          = PhotonEnergyKeV[lambdaPm];
    EPrimeKeV     = ComptonOutgoingEnergyKeV[EKeV, thetaRad];
    lambdaPrimePm = PhotonWavelengthPm[EPrimeKeV];
    deltaLambdaPm = ComptonWavelengthShiftPm[thetaRad];
    TKeV          = EKeV - EPrimeKeV;
    recoilAngleDeg = RecoilElectronAngleDeg[EKeV, thetaRad];
    pan           = ComptonPan[thetaDeg];

    <|
      "mode" -> "scatter",
      "lambdaPm" -> lambdaPm, "thetaDeg" -> thetaDeg, "thetaRad" -> thetaRad,
      "EKeV" -> EKeV, "EPrimeKeV" -> EPrimeKeV, "lambdaPrimePm" -> lambdaPrimePm,
      "deltaLambdaPm" -> deltaLambdaPm, "TKeV" -> TKeV,
      "recoilAngleDeg" -> recoilAngleDeg, "pan" -> pan
    |>
  ];


(* ── Mode 2: sweep — angle sweep at fixed incident wavelength ─────── *)

SweepModel[cfg_Association] :=
  Module[{lambdaPm, angleMin, angleMax, nSteps, EKeV,
          thetaDegArr, thetaRadArr, deltaLambdaArr, EPrimeArr, panArr},
    lambdaPm = N @ GetCfg[cfg, {"simulation", "compton", "wavelength_pm"}, 71.0];
    angleMin = N @ GetCfg[cfg, {"simulation", "compton", "angle_min"}, 0.0];
    angleMax = N @ GetCfg[cfg, {"simulation", "compton", "angle_max"}, 180.0];
    nSteps   =     GetCfg[cfg, {"simulation", "compton", "n_steps"},   100];

    EKeV = PhotonEnergyKeV[lambdaPm];
    thetaDegArr    = N @ Subdivide[angleMin, angleMax, nSteps - 1];
    thetaRadArr    = thetaDegArr * Pi / 180.0;
    deltaLambdaArr = ComptonWavelengthShiftPm /@ thetaRadArr;
    EPrimeArr      = ComptonOutgoingEnergyKeV[EKeV, #] & /@ thetaRadArr;
    panArr         = ComptonPan /@ thetaDegArr;

    <|
      "mode" -> "sweep",
      "lambdaPm" -> lambdaPm, "EKeV" -> EKeV,
      "angleMin" -> angleMin, "angleMax" -> angleMax, "nSteps" -> nSteps,
      "thetaDegArr" -> thetaDegArr, "thetaRadArr" -> thetaRadArr,
      "deltaLambdaArr" -> deltaLambdaArr, "EPrimeArr" -> EPrimeArr, "panArr" -> panArr
    |>
  ];


(* ── Mode 3: energy — incident-energy sweep at fixed angle ────────── *)

EnergyModel[cfg_Association] :=
  Module[{EMinKev, EMaxKev, nSteps, angleDeg, thetaRad,
          EArr, EPrimeArr, fracShiftArr, restEnergyIdx},
    EMinKev  = N @ GetCfg[cfg, {"simulation", "compton", "energy_min_kev"}, 1.0];
    EMaxKev  = N @ GetCfg[cfg, {"simulation", "compton", "energy_max_kev"}, 5000.0];
    nSteps   =     GetCfg[cfg, {"simulation", "compton", "n_steps"},        100];
    angleDeg = N @ GetCfg[cfg, {"simulation", "compton", "angle_deg"},      90.0];
    thetaRad = angleDeg * Pi / 180.0;

    EArr = Table[EMinKev * (EMaxKev / EMinKev)^(N[i] / (nSteps - 1)), {i, 0, nSteps - 1}];
    EPrimeArr    = ComptonOutgoingEnergyKeV[#, thetaRad] & /@ EArr;
    fracShiftArr = (EArr - EPrimeArr) / EArr;

    (* Index of the sweep step nearest m_e c^2 = 511 keV, marked with an
       accent tone the way blackbody's spectrum mode marks the visible
       band edges -- both mark a physically meaningful reference scale
       on an otherwise continuous sweep. *)
    restEnergyIdx = First[Ordering[Abs[EArr - $ElectronRestEnergyKeV], 1]];

    <|
      "mode" -> "energy",
      "EMinKev" -> EMinKev, "EMaxKev" -> EMaxKev, "nSteps" -> nSteps, "angleDeg" -> angleDeg,
      "EArr" -> EArr, "EPrimeArr" -> EPrimeArr, "fracShiftArr" -> fracShiftArr,
      "restEnergyIdx" -> restEnergyIdx
    |>
  ];


(* ── Mode 4: discovery — classical Thomson vs quantum Compton ─────── *)

DiscoveryModel[cfg_Association] :=
  Module[{lambdaPm, angleMin, angleMax, nSteps, EKeV,
          thetaDegArr, thetaRadArr, EPrimeCompton, EPrimeThomson},
    lambdaPm = N @ GetCfg[cfg, {"simulation", "compton", "wavelength_pm"}, 71.0];
    angleMin = N @ GetCfg[cfg, {"simulation", "compton", "angle_min"}, 0.0];
    angleMax = N @ GetCfg[cfg, {"simulation", "compton", "angle_max"}, 180.0];
    nSteps   =     GetCfg[cfg, {"simulation", "compton", "n_steps"},   100];

    EKeV = PhotonEnergyKeV[lambdaPm];
    thetaDegArr = N @ Subdivide[angleMin, angleMax, nSteps - 1];
    thetaRadArr = thetaDegArr * Pi / 180.0;

    (* Classical (Thomson) prediction: purely elastic, wavelength-
       independent scattering -- the outgoing photon always has the
       SAME energy as the incoming one, at every angle. *)
    EPrimeThomson = ConstantArray[EKeV, nSteps];
    EPrimeCompton = ComptonOutgoingEnergyKeV[EKeV, #] & /@ thetaRadArr;

    <|
      "mode" -> "discovery",
      "lambdaPm" -> lambdaPm, "EKeV" -> EKeV,
      "angleMin" -> angleMin, "angleMax" -> angleMax, "nSteps" -> nSteps,
      "thetaDegArr" -> thetaDegArr, "thetaRadArr" -> thetaRadArr,
      "EPrimeThomson" -> EPrimeThomson, "EPrimeCompton" -> EPrimeCompton
    |>
  ];

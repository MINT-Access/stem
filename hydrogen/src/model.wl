(* ========================================================
   hydrogen/src/model.wl — Hydrogen atom physics

   Atomic units throughout (a0 = hbar = m_e = e = 1) for the wave
   functions; SI-adjacent units (eV, nm, Hz, s) for energy levels
   and spectroscopy, matching how these numbers are quoted in real
   atomic physics and astronomy.

   Public API:
     EnergyLevelEV[n]                       -- E_n in eV
     TransitionEnergyEV[nHi,nLo]             -- photon energy in eV
     PhotonFrequencyHz[nHi,nLo]              -- photon frequency in Hz
     PhotonWavelengthNm[nHi,nLo]              -- photon wavelength in nm
     SeriesName[nLo]                          -- "Lyman"/"Balmer"/"Paschen"/...
     EinsteinA[nHi,nLo]                       -- transition rate, s^-1
     BuildSpectralLines[nMax]                 -- all n_upper->n_lower lines
     HydrogenRadialR[n,l,r]                   -- radial wavefunction R_nl(r)
     HydrogenPsi[n,l,m,r,theta,phi]           -- full wavefunction (complex)
     OrbitalPointDensity[n,l,m,x,z]           -- |psi|^2 on the xz cross-section
     BuildOrbitalGrid[orbitalKey,gridSize]     -- 2D density grid
     ComputeOrbitalTraversal[orbitalKey,gridSize] -- + Hilbert traversal
     SelectionRuleAllowedQ[lHi,lLo]             -- Delta l = +-1 test
     AllowedTransitionsFrom[n,l]               -- selection-rule-filtered targets
     SimulateCascade[nStart,lStart,maxSteps]   -- one random decay path
     EnergyLevelCheck[], RydbergCheck[],
     WaveFunctionNormalizationCheck[orbitalKey],
     SelectionRuleCheck[cascadeSteps]          -- correctness checks, {"pass"->..}
   ======================================================== *)


(* ── Constants ────────────────────────────────────────────────────── *)

$RydbergEV    = 13.6057;        (* Rydberg energy, infinite nuclear mass, eV *)
$PlanckEVs    = 4.13567*^-15;   (* Planck's constant, eV s *)
$SpeedOfLight = 2.99792458*^8;  (* m/s *)
$BohrRadiusA  = 0.529177;       (* Angstrom; a0 = 1 in the atomic units used below *)


(* ── Energy levels and spectral lines ────────────────────────────── *)

EnergyLevelEV[n_Integer] := -$RydbergEV / N[n]^2;

(* Photon energy for n_upper -> n_lower (n_upper > n_lower); positive. *)
TransitionEnergyEV[nHi_Integer, nLo_Integer] :=
  $RydbergEV * (1.0/N[nLo]^2 - 1.0/N[nHi]^2);

PhotonFrequencyHz[nHi_Integer, nLo_Integer] :=
  TransitionEnergyEV[nHi, nLo] / $PlanckEVs;

PhotonWavelengthNm[nHi_Integer, nLo_Integer] :=
  ($SpeedOfLight / PhotonFrequencyHz[nHi, nLo]) * 1.0*^9;

SeriesName[nLo_Integer] := Switch[nLo,
  1, "Lyman", 2, "Balmer", 3, "Paschen", 4, "Brackett", 5, "Pfund", 6, "Humphreys",
  _, "n" <> ToString[nLo] <> "-series"
];


(* ── Einstein A coefficients ──────────────────────────────────────
   Hard-coded values are the four given Balmer lines (the only ones
   this app needs at literal textbook accuracy). Every other
   n_upper->n_lower pair -- other series, and every transition used by
   the cascade in "transitions" mode -- falls back to the approximation
   A ~ (deltaE)^3 / n_upper^3, scaled by $AApproxScale so its order of
   magnitude roughly tracks the four known Balmer values (scale fit by
   geometric mean of A_actual/A_formula across the four Balmer lines --
   see hydrogen/AGENTS.md for the fit). This is explicitly an approximation
   "for sonification purposes" (per spec), not a matrix-element calculation. *)

$BalmerA = <|
  {3, 2} -> 4.41*^7,
  {4, 2} -> 8.42*^6,
  {5, 2} -> 2.53*^6,
  {6, 2} -> 9.73*^5
|>;

$AApproxScale = 2.77*^7;

EinsteinA[nHi_Integer, nLo_Integer] :=
  Lookup[$BalmerA, Key[{nHi, nLo}],
    $AApproxScale * TransitionEnergyEV[nHi, nLo]^3 / N[nHi]^3];

(* BuildSpectralLines
   All n_upper -> n_lower lines for n_upper = 2..nMax (no selection-rule
   filtering -- the emission spectrum is an ensemble average over many
   atoms in many l states, so every n_upper->n_lower pair contributes). *)
BuildSpectralLines[nMax_Integer] :=
  Flatten[
    Table[
      <|
        "n_upper"    -> nHi,
        "n_lower"    -> nLo,
        "series"     -> SeriesName[nLo],
        "lambda_nm"  -> PhotonWavelengthNm[nHi, nLo],
        "nu_Hz"      -> PhotonFrequencyHz[nHi, nLo],
        "nu_THz"     -> PhotonFrequencyHz[nHi, nLo] / 1.0*^12,
        "einstein_A" -> EinsteinA[nHi, nLo]
      |>,
      {nHi, 2, nMax}, {nLo, 1, nHi - 1}
    ],
    1
  ];


(* ── Wave functions ────────────────────────────────────────────────
   Atomic units: a0 = 1. R_nl normalised so Integrate[R^2 r^2, {r,0,Infinity}] = 1
   (verified numerically in tests/test_model.wl and by WaveFunctionNormalizationCheck). *)

HydrogenRadialR[n_Integer, l_Integer, r_?NumericQ] :=
  Sqrt[(2.0/n)^3 * (n - l - 1)! / (2.0 * n * (n + l)!)] *
    Exp[-r/n] * (2.0 * r / n)^l * LaguerreL[n - l - 1, 2 l + 1, 2.0 * r / n];

HydrogenPsi[n_Integer, l_Integer, m_Integer,
            r_?NumericQ, theta_?NumericQ, phi_?NumericQ] :=
  HydrogenRadialR[n, l, r] * SphericalHarmonicY[l, m, theta, phi];

(* $Orbitals — the six orbitals exposed via --simulation.hydrogen.orbital *)
$Orbitals = <|
  "100" -> {1, 0, 0},
  "200" -> {2, 0, 0},
  "210" -> {2, 1, 0},
  "300" -> {3, 0, 0},
  "320" -> {3, 2, 0},
  "321" -> {3, 2, 1}
|>;

OrbitalDisplayName[key_String] := Switch[key,
  "100", "1s",
  "200", "2s",
  "210", "2p (m=0, p_z)",
  "300", "3s",
  "320", "3d (m=0, d_z^2)",
  "321", "3d (m=\[PlusMinus]1 clover)",
  _, key
];

(* OrbitalPointDensity
   |psi|^2 at Cartesian (x, z) in the y=0 cross-section (phi = 0 for
   x>=0, phi = Pi for x<0; theta = ArcCos[z/r], with r=0 handled
   separately since ArcCos[z/0] is undefined -- harmless because for
   l>0 the radial factor r^l vanishes there anyway, and for l=0 the
   angular part is constant).

   For m != 0 orbitals ("321"), the task's literal real combination
   (psi_m + psi_-m)/Sqrt[2] is the d_yz-type orbital, which is
   identically zero everywhere in the y=0 plane we sonify (verified
   numerically: Y_l^m + Y_l^-m is proportional to Sin[m*phi], which
   vanishes at phi = 0 and Pi for every integer m). The DIFFERENCE
   combination (psi_m - psi_-m)/Sqrt[2] is the d_xz-type orbital instead
   -- non-zero in the xz-plane, and it is what actually produces the
   four-lobe clover pattern the spec describes. Both combinations are
   equally valid real orbitals and have identical 3D normalisation (the
   cross term integrates to zero either way since Y_l^m and Y_l^-m are
   orthogonal), so only the choice of which one is visible in THIS
   cross-section differs. *)
OrbitalPointDensity[n_Integer, l_Integer, m_Integer, x_?NumericQ, z_?NumericQ] :=
  Module[{r, theta, phi, psiPos, psiNeg},
    r     = Sqrt[x^2 + z^2];
    theta = If[r < 1.0*^-9, 0.0, ArcCos[Clip[z/r, {-1.0, 1.0}]]];
    phi   = If[x >= 0, 0.0, Pi];
    If[m == 0,
      Abs[HydrogenPsi[n, l, 0, r, theta, phi]]^2,
      psiPos = HydrogenPsi[n, l,  m, r, theta, phi];
      psiNeg = HydrogenPsi[n, l, -m, r, theta, phi];
      Abs[(psiPos - psiNeg) / Sqrt[2.0]]^2
    ]
  ];

(* BuildOrbitalGrid
   density[[row,col]] with row indexing z (top to bottom as listed),
   col indexing x -- same [row,col] = [z-index, x-index] convention as
   images/src/model.wl's rgbData, so ComputeOrbitalTraversal's
   traversal[[i,2]] (row) / traversal[[i,1]] (col) lookup matches. *)
BuildOrbitalGrid[orbitalKey_String, gridSize_Integer] :=
  Module[{nlm, n, l, m, rMax, xVals, zVals, density, imgN},
    nlm = Lookup[$Orbitals, orbitalKey, {2, 1, 0}];
    {n, l, m} = nlm;
    rMax  = 3.0 * n^2;
    imgN  = Round[Log2[N[gridSize]]];
    xVals = N[Subdivide[-rMax, rMax, gridSize - 1]];
    zVals = N[Subdivide[-rMax, rMax, gridSize - 1]];
    density = Table[OrbitalPointDensity[n, l, m, x, z], {z, zVals}, {x, xVals}];
    <|
      "orbitalKey" -> orbitalKey, "n" -> n, "l" -> l, "m" -> m,
      "rMax" -> rMax, "gridSize" -> gridSize, "imgN" -> imgN,
      "xVals" -> xVals, "zVals" -> zVals, "density" -> density
    |>
  ];

(* ComputeOrbitalTraversal
   Adds a Hilbert traversal (from stem-core) over the grid, plus the
   flattened per-pixel density in traversal order -- the shape sonify.wl
   and animate.wl and output.wl consume. *)
ComputeOrbitalTraversal[orbitalKey_String, gridSize_Integer] :=
  Module[{grid, imgN, traversal, nPixels, densityFlat},
    grid      = BuildOrbitalGrid[orbitalKey, gridSize];
    imgN      = grid["imgN"];
    traversal = HilbertTraversalOrder[imgN];
    nPixels   = Length[traversal];
    densityFlat = Table[
      grid["density"][[ traversal[[i, 2]], traversal[[i, 1]] ]],
      {i, nPixels}
    ];
    Join[grid, <|
      "traversal"   -> traversal,
      "nPixels"     -> nPixels,
      "densityFlat" -> densityFlat
    |>]
  ];


(* ── Selection rules and cascade simulation ──────────────────────── *)

(* SelectionRuleAllowedQ
   The electric-dipole selection rule: a transition between angular
   momentum quantum numbers lHi and lLo is allowed only if they differ
   by exactly 1 (angular momentum conservation with the photon, which
   carries one unit of angular momentum). Delta l = 0 (e.g. 2s -> 1s)
   or |Delta l| > 1 are forbidden. *)
SelectionRuleAllowedQ[lHi_Integer, lLo_Integer] := Abs[lHi - lLo] == 1;

(* AllowedTransitionsFrom
   All {n_lower, l_lower} reachable from {n,l} by an electric-dipole
   (Delta l = +-1, n_lower < n) transition. {2,0} (the 2s state) is
   excluded as a candidate LOWER state: 2s is metastable under Delta
   l=+-1 (it can only reach 1s via a much slower two-photon process,
   which this cascade does not model), so allowing it as a target would
   occasionally strand a cascade in a state with zero further allowed
   transitions, breaking the "every cascade reaches the ground state"
   guarantee. Real hydrogen atoms landing in 2s do get stuck exactly
   like this on E1-transition timescales -- see LISTENING_GUIDE.md. *)
AllowedTransitionsFrom[n_Integer, l_Integer] :=
  Select[
    Flatten[Table[{nLower, lLower}, {nLower, 1, n - 1}, {lLower, {l - 1, l + 1}}], 1],
    (0 <= #[[2]] <= #[[1]] - 1 && SelectionRuleAllowedQ[l, #[[2]]] && # =!= {2, 0}) &
  ];

(* $CascadeSoftPower
   Raw Einstein-A ratios between competing transitions from a given
   state span 2-4 orders of magnitude (e.g. from {5,2}, A{2,1}=2.53e6 vs
   A{4,1}=A{4,3}~6*10^3), which would make branch selection
   essentially deterministic across only 20 realisations -- defeating
   the "20 different quantum melodies" premise of this mode. Raising
   weights to this power before normalising compresses the dynamic
   range (still favouring brighter transitions on average, matching
   "notice which notes appear in most realisations... and which are
   rare" in LISTENING_GUIDE.md) while keeping every allowed branch
   audibly reachable. Chosen empirically: 0.3 gives the dominant branch
   from the default {5,2} start a comfortable ~55% share rather than
   ~92% (p=1, raw A) or a flat ~25% (p->0). *)
$CascadeSoftPower = 0.3;

(* SimulateCascade
   One random decay path from {nStart,lStart} to the ground state {1,0},
   picking among AllowedTransitionsFrom at each step with probability
   proportional to EinsteinA[n, nLower]^$CascadeSoftPower (l-independent,
   since the approximation formula only depends on n -- when two lLower
   options share the same nLower they are equally likely). Stops early
   (returning fewer than the state's natural path length) only if
   maxSteps is exceeded, which should not happen in practice since every
   reachable state has a path to {1,0} of length <= n-1. *)
SimulateCascade[nStart_Integer, lStart_Integer, maxSteps_Integer] :=
  Module[{n = nStart, l = lStart, steps = {}, options, weights, totalW, r, cum, chosen, i},
    While[!(n == 1 && l == 0) && Length[steps] < maxSteps,
      options = AllowedTransitionsFrom[n, l];
      If[Length[options] == 0, Break[]];
      weights = Map[EinsteinA[n, #[[1]]]^$CascadeSoftPower &, options];
      totalW  = Total[weights];
      r       = RandomReal[{0.0, totalW}];
      cum     = 0.0;
      chosen  = Last[options];
      Do[
        cum += weights[[i]];
        If[r <= cum, chosen = options[[i]]; Break[]],
        {i, Length[options]}
      ];
      AppendTo[steps, <|
        "n_upper"    -> n,           "l_upper"    -> l,
        "n_lower"    -> chosen[[1]], "l_lower"    -> chosen[[2]],
        "series"     -> SeriesName[chosen[[1]]],
        "lambda_nm"  -> PhotonWavelengthNm[n, chosen[[1]]],
        "einstein_A" -> EinsteinA[n, chosen[[1]]]
      |>];
      {n, l} = chosen
    ];
    steps
  ];


(* ── Correctness checks (Physical/mathematical, printed PASS/FAIL) ──
   Tolerances: the app's energy formula uses the infinite-nuclear-mass
   Rydberg constant (13.6057 eV, as specified), while the textbook
   "656.279 nm" / "121.567 nm" reference wavelengths are the real,
   reduced-mass-and-air-refraction values. The mismatch this introduces
   is a fixed ~0.03-0.05% (dominated by the electron/proton reduced-mass
   correction, ~1/1836), so these checks use a 0.1% tolerance rather
   than a stricter one -- see hydrogen/AGENTS.md for the numeric
   derivation. *)

EnergyLevelCheck[] :=
  Module[{ns, errs, pass},
    ns   = {1, 2, 3, 4};
    errs = Map[Abs[EnergyLevelEV[#] * #^2 + $RydbergEV] &, ns];
    pass = AllTrue[errs, # < 0.0001 * $RydbergEV &];
    <| "ns" -> ns, "errors" -> errs, "pass" -> pass |>
  ];

RydbergCheck[Optional[tolerance_?NumericQ, 0.001]] :=
  Module[{lambda, expected, relErr},
    lambda   = PhotonWavelengthNm[3, 2];
    expected = 656.279;
    relErr   = Abs[lambda - expected] / expected;
    <| "lambda_nm" -> lambda, "expected_nm" -> expected,
       "relError" -> relErr, "pass" -> (relErr < tolerance) |>
  ];

(* WaveFunctionNormalizationCheck
   Two-part check for a given orbital key:
     (a) the full 3D integral Integrate[|psi|^2 dV] (proper r^2 Sin[theta]
         volume element), taken out to a generous cutoff rMaxCheck, equals
         1, the defining normalisation condition. rMaxCheck deliberately
         differs from the sonification grid's rMax = 3n^2: for n=1, 3n^2=3
         Bohr radii only encloses ~94% of |1s|^2's probability (the
         exponential tail is not yet negligible that close in), so this
         check needs a wider net than the grid itself does to isolate
         "is the wavefunction formula normalised" from "how much of the
         tail does the sonified box happen to show".
     (b) the discrete Riemann sum over the ACTUAL sonification grid
         (Total[density]*dx*dz, at the real rMax = 3n^2) agrees with the
         continuum NIntegrate of that same 2D xz-plane slice -- a
         numerical-consistency check on the grid discretisation itself
         (catches indexing/grid bugs), independent of (a).
   Both must pass for this check to pass. *)
WaveFunctionNormalizationCheck[orbitalKey_String, Optional[gridSize_Integer, 64]] :=
  Module[{nlm, n, l, m, rMax, rMaxCheck, grid, xVals, zVals, dx, dz, gridSum,
          contInt2D, threeDInt, err2D, err3D, pass},
    nlm = Lookup[$Orbitals, orbitalKey, {2, 1, 0}];
    {n, l, m} = nlm;
    rMax      = 3.0 * n^2;
    rMaxCheck = Max[rMax, 8.0 * n];
    grid  = BuildOrbitalGrid[orbitalKey, gridSize];
    xVals = grid["xVals"]; zVals = grid["zVals"];
    dx    = xVals[[2]] - xVals[[1]];
    dz    = zVals[[2]] - zVals[[1]];
    gridSum = Total[Flatten[grid["density"]]] * dx * dz;

    contInt2D = NIntegrate[
      OrbitalPointDensity[n, l, m, x, z], {x, -rMax, rMax}, {z, -rMax, rMax},
      PrecisionGoal -> 3, MaxRecursion -> 8
    ];

    threeDInt = 2.0 * Pi * NIntegrate[
      (If[m == 0,
         Abs[HydrogenPsi[n, l, 0, r, th, 0.0]]^2,
         (Abs[HydrogenPsi[n, l, m, r, th, 0.0]]^2 +
          Abs[HydrogenPsi[n, l, -m, r, th, 0.0]]^2) / 2.0
       ]) * r^2 * Sin[th],
      {r, 0, rMaxCheck}, {th, 0, Pi},
      PrecisionGoal -> 4, MaxRecursion -> 10
    ];

    err2D = If[contInt2D > 0.0, Abs[gridSum - contInt2D] / contInt2D, Abs[gridSum]];
    err3D = Abs[threeDInt - 1.0];
    pass  = (err2D < 0.05) && (err3D < 0.05);

    <| "orbitalKey" -> orbitalKey, "gridSum" -> gridSum, "contInt2D" -> contInt2D,
       "threeDInt" -> threeDInt, "err2D" -> err2D, "err3D" -> err3D, "pass" -> pass |>
  ];

(* SelectionRuleCheck
   Verifies every step of a simulated cascade satisfies |Delta l| = 1. *)
SelectionRuleCheck[cascadeSteps_List] :=
  Module[{deltaLs, pass},
    deltaLs = Map[Abs[#["l_upper"] - #["l_lower"]] &, cascadeSteps];
    pass = Length[cascadeSteps] > 0 && AllTrue[deltaLs, # == 1 &];
    <| "nSteps" -> Length[cascadeSteps], "deltaLs" -> deltaLs, "pass" -> pass |>
  ];

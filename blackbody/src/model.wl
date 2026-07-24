(* ========================================================
   blackbody/src/model.wl — Planck black body radiation physics

   Planck's law gives the spectral radiance of a black body at
   temperature T as a function of photon frequency nu:

     B(nu,T) = (2 h nu^3 / c^2) / (exp(h nu / k T) - 1)

   Two classical limits (both checked against the exact formula
   below): Rayleigh-Jeans (low frequency, the historical "ultraviolet
   catastrophe" approximation) and Wien's approximation (high
   frequency). Two integral laws: Wien's displacement law (the peak
   wavelength scales as b/T) and the Stefan-Boltzmann law (total
   emitted power scales as T^4).

   Public API:
     PlanckRadianceFreq[nu,T]         -- exact B(nu,T), W/sr/m^2/Hz
     RayleighJeansFreq[nu,T]          -- low-frequency approximation
     WienApproxFreq[nu,T]             -- high-frequency approximation
     PlanckRadianceWavelength[lam,T]  -- exact B(lambda,T), W/sr/m^3
     WienPeakWavelength[T]            -- analytic peak, b/T
     PeakFrequencyFromWavelength[T]   -- c / WienPeakWavelength[T]
     RayleighJeansCheck[], WienApproxCheck[],
     WienDisplacementCheck[], StefanBoltzmannCheck[] -- correctness checks
     StefanBoltzmannLoudness[T,Tmin,Tmax] -- log-compressed T^4 loudness
     $StarPresets, StarDisplayName[key], StarOrder[]
   ======================================================== *)


(* ── Physical constants (SI) ─────────────────────────────────────── *)

$PlanckH = 6.62607015*^-34;   (* Planck constant, J s *)
$SpeedC  = 2.99792458*^8;     (* speed of light, m/s *)
$BoltzK  = 1.380649*^-23;     (* Boltzmann constant, J/K *)

(* Wien displacement constant, m K. 2.8978e-3 to the precision the
   task spec quotes; CODATA gives 2.897771955e-3 -- the extra digits
   here just make WienDisplacementCheck's tolerance meaningfully
   tighter than 4 significant figures would allow. *)
$WienB = 2.8977719*^-3;

(* Stefan-Boltzmann constant, W/m^2/K^4 -- not used by any correctness
   check (StefanBoltzmannCheck compares a T^4 *ratio*, which needs no
   absolute constant), but retained for CSV/console output since it is
   the standard reference value quoted alongside T^4 growth. *)
$StefanBoltzmannSigma = 5.670374419*^-8;


(* ── Planck's law, frequency and wavelength forms ────────────────── *)

PlanckRadianceFreq[nu_?NumericQ, T_?NumericQ] :=
  Module[{x = $PlanckH * nu / ($BoltzK * T)},
    (2.0 * $PlanckH * nu^3 / $SpeedC^2) / (Exp[x] - 1.0)
  ];

RayleighJeansFreq[nu_?NumericQ, T_?NumericQ] :=
  2.0 * nu^2 * $BoltzK * T / $SpeedC^2;

WienApproxFreq[nu_?NumericQ, T_?NumericQ] :=
  Module[{x = $PlanckH * nu / ($BoltzK * T)},
    (2.0 * $PlanckH * nu^3 / $SpeedC^2) * Exp[-x]
  ];

(* PlanckRadianceWavelength — the wavelength-density form, related to
   the frequency form by B_lambda = B_nu * |dnu/dlambda| = B_nu * c/lambda^2,
   NOT simply B_nu[c/lambda, T]. Its peak sits at a different location
   than B_nu's peak (the classic "two Wien peaks" subtlety) -- Wien's
   displacement law as usually quoted (lambda_peak*T = b) is a property
   of THIS wavelength form, so WienDisplacementCheck below maximises
   this function, not PlanckRadianceFreq. *)
PlanckRadianceWavelength[lambda_?NumericQ, T_?NumericQ] :=
  Module[{x = $PlanckH * $SpeedC / (lambda * $BoltzK * T)},
    (2.0 * $PlanckH * $SpeedC^2 / lambda^5) / (Exp[x] - 1.0)
  ];

WienPeakWavelength[T_?NumericQ] := $WienB / T;

(* PeakFrequencyFromWavelength — the photon frequency corresponding to
   the wavelength-domain peak via c = lambda*nu (an exact, unambiguous
   unit conversion of a single wavelength value). This is deliberately
   NOT the separate frequency-domain peak of PlanckRadianceFreq (which
   sits at a different nu due to the same Jacobian subtlety noted
   above) -- using the wavelength-law peak everywhere (spectrum mode's
   visible-band edges, temperature mode's Wien's-law pitch mapping)
   keeps a single, consistent "where does emission peak" answer across
   this app rather than mixing two different but similarly-named
   quantities. *)
PeakFrequencyFromWavelength[T_?NumericQ] := $SpeedC / WienPeakWavelength[T];

(* Visible-light band edges (400-700 nm) as photon frequencies. *)
$VisibleFreqLo = $SpeedC / 700.0*^-9;   (* ~4.283e14 Hz, red edge *)
$VisibleFreqHi = $SpeedC / 400.0*^-9;   (* ~7.495e14 Hz, violet edge *)


(* ── Correctness checks (physical/mathematical, printed PASS/FAIL) ──
   Following the pattern used throughout the codebase (see
   thermo/src/model.wl, hydrogen/src/model.wl): each check returns an
   Association with a "pass" key; main.wl prints PASS/FAIL every run
   but does not abort on failure (no app in this codebase does --
   correctness checks are a printed diagnostic, not a hard gate). *)

(* Check 1: Rayleigh-Jeans limit. Chooses the test frequency as a tiny
   multiple of k*T/h (x = h*nu/(k*T) = 1e-6), analogous to
   WienApproxCheck's x-parametrisation, rather than a fixed Hz value --
   both because the relevant regime is "x small" regardless of T, and
   because a fixed nu=1 Hz makes x itself so far below machine epsilon
   (~1e-15 at T~5778K) that Exp[x]-1 loses almost all precision to
   catastrophic cancellation (computing 1+tiny then subtracting 1).
   At x=1e-6, x is still ~1e10 times machine epsilon (negligible
   cancellation loss) while remaining deep in the regime where
   dropping the "-1" is itself only an x/2 ~ 5e-7 relative effect. *)
RayleighJeansCheck[T_?NumericQ, Optional[xTest_?NumericQ, 0.000001],
                   Optional[tolerance_?NumericQ, 0.001]] :=
  Module[{nuTest, exact, approx, relErr},
    nuTest = xTest * $BoltzK * T / $PlanckH;
    exact  = PlanckRadianceFreq[nuTest, T];
    approx = RayleighJeansFreq[nuTest, T];
    relErr = Abs[exact - approx] / approx;
    <| "nuTest" -> nuTest, "xTest" -> xTest, "exact" -> exact, "approx" -> approx,
       "relError" -> relErr, "pass" -> (relErr < tolerance) |>
  ];

(* Check 2: Wien approximation limit. Chooses the test frequency as a
   multiple of k*T/h (x = h*nu/(k*T) = 40) rather than a fixed Hz value,
   so the check probes the same *relative* position on the curve
   regardless of T. At x=40, the true relative error of the Wien
   approximation is exactly Exp[-x] (algebraically: exact/approx =
   1/(1-Exp[-x]), so approx/exact = 1-Exp[-x], relErr = Exp[-x] ~ 4e-18
   at x=40) -- deep in the regime where dropping the "-1" in the
   denominator is negligible. *)
WienApproxCheck[T_?NumericQ, Optional[xTest_?NumericQ, 40.0],
                Optional[tolerance_?NumericQ, 0.000001]] :=
  Module[{nuTest, exact, approx, relErr},
    nuTest = xTest * $BoltzK * T / $PlanckH;
    exact  = PlanckRadianceFreq[nuTest, T];
    approx = WienApproxFreq[nuTest, T];
    relErr = Abs[exact - approx] / exact;
    <| "nuTest" -> nuTest, "xTest" -> xTest, "exact" -> exact, "approx" -> approx,
       "relError" -> relErr, "pass" -> (relErr < tolerance) |>
  ];

(* Check 3: Wien's displacement law. Two independent numerical steps,
   neither of which re-evaluates the closed-form WienPeakWavelength
   (checking that against itself would be tautological):
     (a) FindRoot solves the well-known dimensionless peak equation
         x = 5*(1-Exp[-x]) (from setting d/dlambda of
         PlanckRadianceWavelength to zero and substituting
         x = hc/(lambda*k*T), so lambda = hc/(k*T*x)) for x* -- a
         well-scaled O(1) search, unlike searching directly over
         lambda (~1e-6, with function values ~1e-30ish) where an
         earlier attempt using FindMaximum directly on
         PlanckRadianceWavelength[lambda,T] failed to converge
         (FindMaximum::lstol) because both the domain and range are so
         far from order-1 scale.
     (b) for each T, lambda_peak = h*c/(k*T*xStar) is then verified to be
         an actual local maximum of PlanckRadianceWavelength by
         confirming the curve is lower at lambda_peak*(1 +/- 2%) on
         both sides -- catching a wrong-root or sign error that
         part (a) alone could not. *)
WienDisplacementCheck[Optional[Ts_List, {2500.0, 5778.0, 10000.0, 25000.0}],
                      Optional[tolerance_?NumericQ, 0.001]] :=
  Module[{xStar, bNumeric, lambdaPeaks, isLocalMax, products, relErrs, pass},
    xStar    = x /. FindRoot[x - 5.0 * (1.0 - Exp[-x]) == 0, {x, 5.0}];
    bNumeric = $PlanckH * $SpeedC / ($BoltzK * xStar);
    lambdaPeaks = bNumeric / # & /@ Ts;
    isLocalMax  = MapThread[
      Function[{lambda, T},
        PlanckRadianceWavelength[lambda, T] > PlanckRadianceWavelength[lambda * 1.02, T] &&
        PlanckRadianceWavelength[lambda, T] > PlanckRadianceWavelength[lambda * 0.98, T]
      ],
      {lambdaPeaks, Ts}
    ];
    products = MapThread[#1 * #2 &, {lambdaPeaks, Ts}];
    relErrs  = Map[Abs[# - $WienB] / $WienB &, products];
    pass     = AllTrue[relErrs, # < tolerance &] && AllTrue[isLocalMax, TrueQ];
    <| "Ts" -> Ts, "xStar" -> xStar, "bNumeric" -> bNumeric,
       "lambdaPeaks" -> lambdaPeaks, "isLocalMax" -> isLocalMax,
       "products" -> products, "relErrors" -> relErrs, "pass" -> pass |>
  ];

(* Check 4: Stefan-Boltzmann law. Numerically integrates B(nu,T) over
   all nu (to a generous cutoff -- 500*k*T/h makes Exp[-500] the
   smallest neglected term, far below double precision) for two
   temperatures and verifies the ratio of integrals matches (T1/T2)^4. *)
StefanBoltzmannCheck[Optional[T1_?NumericQ, 5778.0], Optional[T2_?NumericQ, 2889.0],
                     Optional[tolerance_?NumericQ, 0.001]] :=
  Module[{cutoff1, cutoff2, I1, I2, ratio, expected, relErr},
    cutoff1  = 500.0 * $BoltzK * T1 / $PlanckH;
    cutoff2  = 500.0 * $BoltzK * T2 / $PlanckH;
    I1       = Quiet[NIntegrate[PlanckRadianceFreq[nu, T1], {nu, 0, cutoff1}], General::munfl];
    I2       = Quiet[NIntegrate[PlanckRadianceFreq[nu, T2], {nu, 0, cutoff2}], General::munfl];
    ratio    = I1 / I2;
    expected = (T1 / T2)^4;
    relErr   = Abs[ratio - expected] / expected;
    <| "T1" -> T1, "T2" -> T2, "I1" -> I1, "I2" -> I2,
       "ratio" -> ratio, "expected" -> expected,
       "relError" -> relErr, "pass" -> (relErr < tolerance) |>
  ];


(* ── Stefan-Boltzmann loudness mapping (temperature mode) ─────────
   Total emitted power grows as T^4, spanning several orders of
   magnitude across a 2500K-40000K sweep -- a linear volume mapping
   would be silent at the cool end or clipped at the hot end. Loudness
   is log-compressed in T^4 (equivalently, linear in log T -- written
   with the explicit T^4 to keep the Stefan-Boltzmann law visible in
   the code, matching this codebase's preference for physically
   explicit formulas over algebraically pre-simplified ones) and
   rescaled onto [floor, 1.0]. *)
StefanBoltzmannLoudness[T_?NumericQ, Tmin_?NumericQ, Tmax_?NumericQ,
                        Optional[floor_?NumericQ, 0.15]] :=
  floor + (1.0 - floor) *
    Clip[(Log[T^4] - Log[Tmin^4]) / (Log[Tmax^4] - Log[Tmin^4]), {0.0, 1.0}];


(* ── Named star presets (star mode) ──────────────────────────────── *)

$StarPresets = <|
  "red_dwarf"   -> 3200.0,
  "betelgeuse"  -> 3500.0,
  "sun"         -> 5778.0,
  "sirius_a"    -> 9940.0,
  "rigel"       -> 12100.0,
  "white_dwarf" -> 25000.0
|>;

StarDisplayName[key_String] := Switch[key,
  "red_dwarf",   "a red dwarf",
  "betelgeuse",  "Betelgeuse, a red supergiant",
  "sun",         "the Sun",
  "sirius_a",    "Sirius A",
  "rigel",       "Rigel, a blue supergiant",
  "white_dwarf", "a white dwarf",
  _,             key
];

(* StarShortName — compact labels for plot annotations, where
   StarDisplayName's full narration phrasing ("Rigel, a blue
   supergiant") would overlap badly at small font sizes. *)
StarShortName[key_String] := Switch[key,
  "red_dwarf",   "Red Dwarf",
  "betelgeuse",  "Betelgeuse",
  "sun",         "Sun",
  "sirius_a",    "Sirius A",
  "rigel",       "Rigel",
  "white_dwarf", "White Dwarf",
  _,             key
];

(* StarOrder — preset keys sorted by ascending temperature, the order
   the "all" tour visits them in (red dwarf -> white dwarf). *)
StarOrder[] := Keys[SortBy[Normal[$StarPresets], Last]];

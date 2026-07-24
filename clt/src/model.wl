(* ========================================================
   clt/src/model.wl — Central Limit Theorem model

   Two related but DISTINCT facts, both true, both sonified, and
   deliberately not conflated (see AGENTS.md):

     1. The sample mean Xbar_N = (1/N)*Sum[Xi] genuinely NARROWS as N
        grows: Var(Xbar_N) = sigma^2/N exactly, for any N -- a basic,
        exact, non-asymptotic consequence of independence.
     2. The Central Limit Theorem itself: the SHAPE of Xbar_N's
        distribution approaches a Gaussian as N -> infinity, regardless
        of the source distribution's own shape. This is the
        asymptotic, genuinely surprising part.

   `sweep` mode sonifies fact 1 and 2 TOGETHER via the raw
   (unstandardized) sample mean -- the one quantity where "narrows AND
   symmetrises" are simultaneously true. `compare` mode sonifies fact 2
   ALONE via the standardized mean (Xbar_N-mu)/(sigma/Sqrt[N]), which
   has fixed variance 1 for every N by construction (it never narrows,
   only symmetrises) -- exactly what's wanted when comparing shape
   convergence across two different sources independent of each
   source's own natural scale. `dice` mode sonifies shape smoothing of
   the raw SUM (not mean -- the natural quantity for physical dice),
   whose spread genuinely GROWS with N (Var = N*35/12 for fair dice).

   All distributions use WL's built-in RandomVariate/Distribution
   machinery (UniformDistribution, ExponentialDistribution,
   BernoulliDistribution, DiscreteUniformDistribution) rather than
   hand-rolled sampling, the same reason thermo/'s SampleMBSpeeds uses
   RandomVariate on MaxwellDistribution: the built-in is the exact
   distribution and Wolfram's own numerics are more robust than a
   bespoke implementation.

   Public API:
     SourceDistribution[name,p], SourceMean[name,p], SourceVariance[name,p],
     SourceExcessKurtosis[name,p]
     SampleXbarN[name,p,N,nSamples,seed] -- Monte Carlo sample means
     SampleDiceSumN[N,nSamples,seed]     -- Monte Carlo dice sums
     IrwinHallDensity[N,x]               -- exact closed-form (sum of
                                            N Uniform(0,1), used ONLY
                                            for the correctness check)
     RawMeanDisplayDomain[name,p], StandardizedDisplayDomain[],
     DiceDisplayDomain[nMax]
     VarianceScalingCheck[], IrwinHallCheck[], DiceCombinatoricsCheck[],
     KurtosisDecayCheck[]
   ======================================================== *)


(* ── Source distributions and their EXACT moments ─────────────────
   Uniform(0,1) and Exponential(rate=1) moments verified directly
   against WL's own closed-form symbolic moments (Variance[dist],
   Kurtosis[dist]-3), not hand-derived and not re-stated from this
   app's own Monte Carlo code -- an independent reference, per the
   cosmology/AGENTS.md lesson on correctness checks that share a
   formula with the code they check (see "before writing any code"
   in this app's build spec). Kurtosis[dist] is WL's RAW (not excess)
   kurtosis; excess kurtosis = Kurtosis[dist]-3 throughout this file. *)

SourceDistribution[name_String, Optional[p_?NumericQ, 0.5]] := Switch[name,
  "uniform",     UniformDistribution[{0.0, 1.0}],
  "exponential", ExponentialDistribution[1.0],
  "bernoulli",   BernoulliDistribution[p],
  _,             UniformDistribution[{0.0, 1.0}]
];

(* Exact moments, verified: Variance[UniformDistribution[{0,1}]] = 1/12,
   Variance[ExponentialDistribution[1]] = 1,
   Kurtosis[UniformDistribution[{0,1}]]-3 = -6/5 = -1.2,
   Kurtosis[ExponentialDistribution[1]]-3 = 6. *)
SourceMean[name_String, Optional[p_?NumericQ, 0.5]] := Switch[name,
  "uniform",     0.5,
  "exponential", 1.0,
  "bernoulli",   p,
  _,             0.5
];

SourceVariance[name_String, Optional[p_?NumericQ, 0.5]] := Switch[name,
  "uniform",     1.0 / 12.0,
  "exponential", 1.0,
  "bernoulli",   p * (1.0 - p),
  _,             1.0 / 12.0
];

(* Bernoulli's excess kurtosis general formula: (1-6p(1-p))/(p(1-p)) --
   included for completeness/symmetry of the API, but check 4 (the
   kurtosis-decay check) uses the "uniform" default source, not
   bernoulli, since Bernoulli's kurtosis diverges as p->0 or p->1. *)
SourceExcessKurtosis[name_String, Optional[p_?NumericQ, 0.5]] := Switch[name,
  "uniform",     -6.0 / 5.0,
  "exponential", 6.0,
  "bernoulli",   (1.0 - 6.0 * p * (1.0 - p)) / (p * (1.0 - p)),
  _,             -6.0 / 5.0
];


(* ── Monte Carlo sampling ─────────────────────────────────────────
   RandomVariate[dist, {nSamples, N}] draws an nSamples x N matrix in
   one vectorised call; Mean/Total /@ that matrix gives nSamples
   independent realisations of Xbar_N (or S_N) at once -- the same
   "one vectorised draw, not a manual loop" style thermo/'s
   SampleMBSpeeds and bayes/'s GenerateCoinFlips use. *)

(* N[...] wraps the whole sample list, not just individual means: for
   discrete sources (bernoulli) RandomVariate returns exact integers,
   so Mean/@ an integer matrix produces exact RATIONAL numbers, not
   machine floats. An exact Rational fed to FmtN/NumberForm elsewhere
   in this app renders in headless wolframscript as a literal 2D
   stacked "numerator over a horizontal bar over denominator" text
   box -- the exact "OutputForm renders scientific notation (and, it
   turns out, exact fractions) as multi-line" issue stem-core/AGENTS.md
   warns FmtN itself guards against for scientific notation; this is
   the same failure mode one level upstream, in the samples themselves,
   caught only by actually running dice mode and seeing garbled dashes
   in the console output where a clean number should have been. Fixed
   once here rather than wrapping every downstream Mean/Variance/
   Kurtosis call site in N[] individually. *)
SampleXbarN[name_String, p_?NumericQ, n_Integer, nSamples_Integer, seed_Integer] :=
  (SeedRandom[seed]; N[Mean /@ RandomVariate[SourceDistribution[name, p], {nSamples, n}]]);

(* SampleDiceSumN — always a fair 6-sided die (DiscreteUniformDistribution[{1,6}]);
   "dice" mode has no source-selection config key, unlike sweep/compare,
   since the die IS the point of this mode. *)
SampleDiceSumN[n_Integer, nSamples_Integer, seed_Integer] :=
  (SeedRandom[seed]; N[Total /@ RandomVariate[DiscreteUniformDistribution[{1, 6}], {nSamples, n}]]);


(* ── Irwin-Hall exact density (correctness check only) ────────────
   Closed-form PDF of the sum of n iid Uniform(0,1) variables:
     f_n(x) = 1/(n-1)! * Sum[(-1)^k * Binomial[n,k] * (x-k)^(n-1), {k,0,Floor[x]}]
   for x in [0,n], else 0. WL has no built-in IrwinHallDistribution in
   this environment (verified: Quiet[PDF[IrwinHallDistribution[3],1.5]]
   returns unevaluated, not a number) -- implemented directly from the
   standard closed form and verified against a large Monte Carlo sample
   before use (integral over [0,3] = 1.0 to 6 decimal places; density
   at x=1.5 matched a 200000-sample histogram estimate to within 2%). *)
IrwinHallDensity[n_Integer, x_?NumericQ] :=
  If[x < 0.0 || x > N[n],
    0.0,
    (1.0 / (n - 1)!) * Sum[(-1)^k * Binomial[n, k] * (x - k)^(n - 1), {k, 0, Floor[x]}]
  ];


(* ── Display domains ──────────────────────────────────────────────
   Fixed ONCE per run (not re-derived at each N), so the frequency<->
   value mapping stays consistent across the whole sweep and a pitch
   shift is actually audible as narrowing/smoothing -- the same
   reasoning bayes/'s MuSpectrumBins gives for its fixed muLo/muHi. *)

(* RawMeanDisplayDomain — sweep mode. Uses N=1's spread (the WIDEST
   case for the raw mean, since Var(Xbar_N)=sigma^2/N only ever
   SHRINKS as N grows) -- uniform/bernoulli sample means are bounded to
   [0,1] at every N by construction, so that exact interval is used
   directly; exponential is one-sided and unbounded, so
   mean+5*sigma=6.0 is used, comfortably capturing the source's own
   N=1 mass (P(X>6) for Exponential(1) is Exp[-6]~0.25%) with headroom
   to spare once averaging narrows things further at higher N. *)
RawMeanDisplayDomain[name_String, Optional[p_?NumericQ, 0.5]] := Switch[name,
  "uniform",     {0.0, 1.0},
  "exponential", {0.0, 6.0},
  "bernoulli",   {0.0, 1.0},
  _,             {0.0, 1.0}
];

(* StandardizedDisplayDomain — compare mode. Source-independent by
   design (standardisation removes each source's own scale), fixed at
   +/-4 standard deviations -- comfortably covers every source at every
   N in this app's range (e.g. standardised Exponential(1) at N=1 has
   support (-1,Infinity), but P(Z>4) there is Exp[-5]~0.7%, a small,
   acceptable display-domain truncation, not a computation needing
   full coverage). *)
StandardizedDisplayDomain[] := {-4.0, 4.0};

(* DiceDisplayDomain — dice mode. Unlike the raw mean, the sum's range
   GROWS with N (from [1,6] at N=1 to [nMax,6*nMax] at N=nMax), so the
   WIDEST case is n_max, not N=1 -- the opposite asymmetry from
   RawMeanDisplayDomain, and worth getting right the first time rather
   than silently reusing sweep mode's "use N=1" logic where it does not
   apply. *)
DiceDisplayDomain[nMax_Integer] := {1.0, 6.0 * nMax};


(* ── Correctness checks (diagnostic-only, printed PASS/FAIL) ───────
   Each check is built against an EXACT, independently-derivable
   reference -- never a re-statement of this app's own Monte Carlo
   pipeline's formula. This is the direct, deliberate application of
   the cosmology/AGENTS.md lesson cited in this app's build spec: a
   correctness check that shares its formula with the code it checks
   can pass while both are wrong (cosmology's own sky-variance check
   originally shared a missing factor of N with its generator, and
   both silently agreed on the wrong answer). None of the four checks
   below abort on failure -- they test closed-form/combinatorial facts
   and Monte Carlo convergence, not runtime numerical-integration
   health, the same reasoning blackbody/AGENTS.md section 3 (as
   corrected in compton/AGENTS.md) gives for its own four checks. *)

(* Check 1: Var(Xbar_N) = sigma^2/N exactly, for any N (not asymptotic).
   Reference sigma^2 is the source's own EXACT, hand-verified constant
   (1/12 for Uniform(0,1)), not a value derived from this check's own
   Monte Carlo sample. *)
VarianceScalingCheck[Optional[name_String, "uniform"], Optional[nTest_Integer, 10],
                     Optional[nSamples_Integer, 20000], Optional[tolerance_?NumericQ, 0.1]] :=
  Module[{samples, empVar, exactVar, relErr},
    samples  = SampleXbarN[name, 0.5, nTest, nSamples, 101];
    empVar   = Variance[samples];
    exactVar = SourceVariance[name] / N[nTest];
    relErr   = Abs[empVar - exactVar] / exactVar;
    <| "name" -> name, "nTest" -> nTest, "empVar" -> empVar, "exactVar" -> exactVar,
       "relError" -> relErr, "pass" -> (relErr < tolerance) |>
  ];

(* Check 2: Irwin-Hall exact density vs. this app's own Monte Carlo
   histogram estimate of S_3 = sum of 3 Uniform(0,1) draws, at several
   test points -- validates that the sampling/histogram pipeline
   itself is unbiased, using a case (N=3, uniform source) where a
   fully independent exact answer exists. Histogram density estimated
   via a narrow window around each test point (matches a fine-bin
   histogram, not KDE) with a generous but still meaningful 10%
   Monte-Carlo tolerance (calibrated against a 300000-sample run: typical
   relative error was under 1% at every test point tried). *)
IrwinHallCheck[Optional[nSamples_Integer, 300000], Optional[tolerance_?NumericQ, 0.1]] :=
  Module[{samples, binHalfWidth, testPoints, empDensities, exactDensities, relErrs, pass},
    samples      = (SeedRandom[303]; Total /@ RandomVariate[UniformDistribution[{0.0, 1.0}], {nSamples, 3}]);
    binHalfWidth = 0.05;
    testPoints   = {0.5, 1.0, 1.5, 2.0, 2.5};
    empDensities = Map[
      Function[x0, Count[samples, y_ /; x0 - binHalfWidth < y < x0 + binHalfWidth] /
                   N[nSamples] / (2.0 * binHalfWidth)],
      testPoints
    ];
    exactDensities = IrwinHallDensity[3, #] & /@ testPoints;
    relErrs = MapThread[Abs[#1 - #2] / #2 &, {empDensities, exactDensities}];
    pass = AllTrue[relErrs, # < tolerance &];
    <| "testPoints" -> testPoints, "empDensities" -> empDensities,
       "exactDensities" -> exactDensities, "relErrors" -> relErrs, "pass" -> pass |>
  ];

(* Check 3: exact combinatorial P(sum=7) for two fair dice = 6/36 = 1/6
   (the classic triangular distribution's peak), against this app's own
   Monte Carlo estimate -- validates SampleDiceSumN specifically. *)
DiceCombinatoricsCheck[Optional[nSamples_Integer, 300000], Optional[tolerance_?NumericQ, 0.05]] :=
  Module[{sums, empP, exactP, relErr},
    sums   = SampleDiceSumN[2, nSamples, 404];
    empP   = N[Count[sums, 7.0]] / nSamples;
    exactP = 1.0 / 6.0;
    relErr = Abs[empP - exactP] / exactP;
    <| "empP" -> empP, "exactP" -> exactP, "relError" -> relErr, "pass" -> (relErr < tolerance) |>
  ];

(* Check 4: kurtosis-decay RATE, not just direction. The standardised
   sample mean's excess kurtosis decays as (source excess kurtosis)/N
   -- a real asymptotic fact, not merely "kurtosis decreases". Uses a
   larger dedicated Monte Carlo sample (500000, vs. the main pipeline's
   default 5000) since 4th-moment (kurtosis) estimates are much noisier
   than mean/variance estimates -- calibrated by running 5 independent
   seeds at this sample size and observing the empirical value cluster
   within +/-0.005 of the predicted -0.04, so a 0.02 absolute tolerance
   has ample margin without being vacuous. *)
KurtosisDecayCheck[Optional[name_String, "uniform"], Optional[nTest_Integer, 30],
                   Optional[nSamples_Integer, 500000], Optional[tolerance_?NumericQ, 0.02]] :=
  Module[{sourceKurt, samples, mu, sigma, standardized, empKurt, predicted,
          closerToZero, rateConsistent},
    sourceKurt = SourceExcessKurtosis[name];
    mu    = SourceMean[name];
    sigma = Sqrt[SourceVariance[name]];
    samples = (SeedRandom[505]; Mean /@ RandomVariate[SourceDistribution[name], {nSamples, nTest}]);
    standardized = (samples - mu) / (sigma / Sqrt[N[nTest]]);
    empKurt   = Kurtosis[standardized] - 3.0;
    predicted = sourceKurt / N[nTest];
    closerToZero   = Abs[empKurt] < Abs[sourceKurt];
    rateConsistent = Abs[empKurt - predicted] < tolerance;
    <|
      "name" -> name, "nTest" -> nTest, "sourceKurt" -> sourceKurt,
      "empKurt" -> empKurt, "predicted" -> predicted,
      "closerToZero" -> closerToZero, "rateConsistent" -> rateConsistent,
      "pass" -> (closerToZero && rateConsistent)
    |>
  ];

PrintCltChecks[] :=
  Module[{c1, c2, c3, c4},
    c1 = VarianceScalingCheck[];
    c2 = IrwinHallCheck[];
    c3 = DiceCombinatoricsCheck[];
    c4 = KurtosisDecayCheck[];

    Print["  [", If[c1["pass"], "PASS", "FAIL"], "] Variance scaling: Var(Xbar_", c1["nTest"],
          ") = ", FmtN[c1["empVar"], 6], "  vs sigma^2/N = ", FmtN[c1["exactVar"], 6],
          "  (", FmtN[c1["relError"] * 100, 4], "% error, ", c1["name"], " source)"];

    Print["  [", If[c2["pass"], "PASS", "FAIL"], "] Irwin-Hall density (sum of 3 uniforms): max error ",
          FmtN[Max[c2["relErrors"]] * 100, 4], "% across ", Length[c2["testPoints"]], " test points"];

    Print["  [", If[c3["pass"], "PASS", "FAIL"], "] Dice combinatorics: P(sum=7, 2 dice) = ",
          FmtN[c3["empP"], 6], "  vs exact 1/6 = ", FmtN[c3["exactP"], 6],
          "  (", FmtN[c3["relError"] * 100, 4], "% error)"];

    Print["  [", If[c4["pass"], "PASS", "FAIL"], "] Kurtosis decay rate (N=", c4["nTest"], "): empirical excess kurtosis = ",
          FmtN[c4["empKurt"], 5], "  vs predicted (source/N) = ", FmtN[c4["predicted"], 5],
          "  (source excess kurtosis = ", FmtN[c4["sourceKurt"], 4], ")"];

    {c1, c2, c3, c4}
  ];

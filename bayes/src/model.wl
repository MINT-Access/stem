(* ========================================================
   bayes/src/model.wl — Bayesian inference model

   Three conjugate-update scenarios, all analytic (no numerical
   integration required for the posteriors themselves — NIntegrate is
   used only in the normalisation correctness check below):

     coin     — Beta-Binomial: unknown coin bias theta in [0,1],
                Beta(alpha,beta) prior/posterior.
     gaussian — Normal-Normal: unknown mean mu, known observation
                variance sigma^2, Normal prior/posterior on mu.
     model    — Bayes factor: two point hypotheses about a coin's
                bias, log10(K) accumulated flip-by-flip.

   Beta and Normal PDFs/statistics use WL's built-in
   BetaDistribution/NormalDistribution rather than hand-rolled
   formulas, for the same reason thermo/src/model.wl uses
   MaxwellDistribution for sampling: the built-in is the same
   distribution and Wolfram's own numerics are more robust than a
   bespoke implementation.
   ======================================================== *)


(* ── Coin mode: Beta-Binomial conjugate model ────────────────────── *)

(* BetaPosteriorParams
   Uniform prior Beta(1,1) updated by h heads, t tails ->
   Beta(1+h, 1+t). Exposed with an explicit prior so tests/experiments
   can use a non-uniform prior if ever needed. *)
BetaPosteriorParams[h_Integer, t_Integer, Optional[alpha0_?NumericQ, 1.0],
                    Optional[beta0_?NumericQ, 1.0]] :=
  {alpha0 + h, beta0 + t};

BetaMean[alpha_?NumericQ, beta_?NumericQ] := alpha / (alpha + beta);

BetaVariance[alpha_?NumericQ, beta_?NumericQ] :=
  (alpha * beta) / ((alpha + beta)^2 * (alpha + beta + 1.0));

(* BetaMode
   (alpha-1)/(alpha+beta-2) for alpha,beta > 1 (the interior-mode
   case). When alpha=beta=1 (still uniform — no flips observed yet)
   every theta is equally likely, so 0.5 is returned as the
   conventional midpoint rather than an undefined 0/0. When exactly
   one of alpha,beta is <= 1 the density is monotonic and the mode
   sits at the corresponding boundary. *)
BetaMode[alpha_?NumericQ, beta_?NumericQ] :=
  Which[
    alpha <= 1.0 && beta <= 1.0, 0.5,
    alpha <= 1.0,                0.0,
    beta  <= 1.0,                1.0,
    True,                        (alpha - 1.0) / (alpha + beta - 2.0)
  ];

BetaDensity[theta_?NumericQ, alpha_?NumericQ, beta_?NumericQ] :=
  PDF[BetaDistribution[alpha, beta], theta];

(* GenerateCoinFlips
   n_flips Bernoulli(thetaTrue) draws, seeded for reproducibility.
   1 = heads, 0 = tails. *)
GenerateCoinFlips[n_Integer, thetaTrue_?NumericQ, seed_Integer] :=
  (SeedRandom[seed]; RandomVariate[BernoulliDistribution[thetaTrue], n]);

(* CoinPosteriorSequence
   Running (alpha,beta,mean,variance,mode) after each of the n flips.
   Returns a list of associations, one per flip (1-indexed). *)
CoinPosteriorSequence[flips_List, Optional[alpha0_?NumericQ, 1.0],
                      Optional[beta0_?NumericQ, 1.0]] :=
  Module[{hCum, tCum, n = Length[flips]},
    hCum = Accumulate[flips];
    tCum = Range[n] - hCum;
    Table[
      Module[{alpha, beta},
        {alpha, beta} = BetaPosteriorParams[hCum[[k]], tCum[[k]], alpha0, beta0];
        <|
          "flip" -> k, "outcome" -> flips[[k]], "h" -> hCum[[k]], "t" -> tCum[[k]],
          "alpha" -> alpha, "beta" -> beta,
          "mean" -> BetaMean[alpha, beta], "variance" -> BetaVariance[alpha, beta],
          "mode" -> BetaMode[alpha, beta]
        |>
      ],
      {k, n}
    ]
  ];


(* ── Gaussian mode: Normal-Normal conjugate model ─────────────────── *)

GaussianPosteriorMean[mu0_?NumericQ, sigma0_?NumericQ, sigma_?NumericQ,
                      n_?NumericQ, xbar_?NumericQ] :=
  (mu0 / sigma0^2 + n * xbar / sigma^2) / (1.0 / sigma0^2 + n / sigma^2);

GaussianPosteriorVariance[sigma0_?NumericQ, sigma_?NumericQ, n_?NumericQ] :=
  1.0 / (1.0 / sigma0^2 + n / sigma^2);

(* GenerateGaussianObservations — n_obs draws from N(muTrue, sigma^2). *)
GenerateGaussianObservations[n_Integer, muTrue_?NumericQ, sigma_?NumericQ, seed_Integer] :=
  (SeedRandom[seed]; RandomVariate[NormalDistribution[muTrue, sigma], n]);

(* GaussianPosteriorSequence
   Running posterior after each of the n observations. Sequential and
   batch conjugate Gaussian updating are equivalent (the running
   sample mean of the first k observations, applied once with n=k,
   gives the same posterior as k successive single-observation
   updates) so a running mean is used directly rather than an
   explicit sequential loop. *)
GaussianPosteriorSequence[obs_List, mu0_?NumericQ, sigma0_?NumericQ, sigma_?NumericQ] :=
  Module[{n = Length[obs], runningMean},
    runningMean = Accumulate[obs] / Range[n];
    Table[
      Module[{postMean, postVar, postSD},
        postMean = GaussianPosteriorMean[mu0, sigma0, sigma, k, runningMean[[k]]];
        postVar  = GaussianPosteriorVariance[sigma0, sigma, k];
        postSD   = Sqrt[postVar];
        <|
          "observation" -> k, "x_obs" -> obs[[k]],
          "mean" -> postMean, "variance" -> postVar,
          "ci_low"  -> postMean - 1.96 * postSD,
          "ci_high" -> postMean + 1.96 * postSD
        |>
      ],
      {k, n}
    ]
  ];


(* ── Model mode: Bayes factor for two coin hypotheses ─────────────── *)

(* LogBayesFactor10
   log10 K = log10( P(data|H1) / P(data|H2) ) for two point hypotheses
   theta1 (H1), theta2 (H2) about a Bernoulli coin, given h heads and
   t tails. Positive => evidence favours H1; negative => favours H2. *)
LogBayesFactor10[h_?NumericQ, t_?NumericQ, theta1_?NumericQ, theta2_?NumericQ] :=
  h * Log10[theta1 / theta2] + t * Log10[(1.0 - theta1) / (1.0 - theta2)];

(* ModelPosteriorSequence
   Running log10(K) after each flip, plus the pan/pitch/evidence
   mappings sonify.wl and output.wl both need (computed here so
   model.wl is the single source of truth for the statistics, and
   sonify.wl only handles audio synthesis from these numbers). *)
ModelPosteriorSequence[flips_List, theta1_?NumericQ, theta2_?NumericQ] :=
  Module[{hCum, tCum, n = Length[flips], logK},
    hCum = Accumulate[flips];
    tCum = Range[n] - hCum;
    logK = Table[LogBayesFactor10[hCum[[k]], tCum[[k]], theta1, theta2], {k, n}];
    Table[
      <|
        "flip" -> k, "outcome" -> flips[[k]], "log_bayes_factor" -> logK[[k]]
      |>,
      {k, n}
    ]
  ];

(* EvidenceLevel — Wagenmakers et al.'s commonly used verbal labels
   for the Bayes factor K = 10^|log10K| ("Jeffreys' scale" as usually
   cited in practice: 1-3 anecdotal, 3-10 moderate, 10-30 strong,
   >=30 very strong). Distinct from the two specific EventLayer accent
   thresholds (|log10K| crossing 1 and 2, i.e. K=10 and K=100) used in
   sonify.wl — those mark two fixed audio milestones, not this
   four-band verbal classification; see AGENTS.md for the full note on
   why the two do not share thresholds. *)
EvidenceLevel[logK_?NumericQ] :=
  Module[{K = 10.0^Abs[logK]},
    Which[
      K < 3.0,  "anecdotal",
      K < 10.0, "moderate",
      K < 30.0, "strong",
      True,     "very_strong"
    ]
  ];


(* ── Correctness checks (Physical/mathematical, printed PASS/FAIL) ── *)

(* Check 1: Beta posterior mean & mode, h=7 t=3, uniform prior. *)
BetaPosteriorCheck[Optional[tolerance_?NumericQ, 0.001]] :=
  Module[{alpha, beta, mean, mode, errMean, errMode},
    {alpha, beta} = BetaPosteriorParams[7, 3];
    mean = BetaMean[alpha, beta];
    mode = BetaMode[alpha, beta];
    errMean = Abs[mean - 8.0/12.0];
    errMode = Abs[mode - 0.7];
    <|
      "alpha" -> alpha, "beta" -> beta, "mean" -> mean, "mode" -> mode,
      "errMean" -> errMean, "errMode" -> errMode,
      "pass" -> (errMean < tolerance && errMode < tolerance)
    |>
  ];

(* Check 2: Gaussian posterior mean & variance, prior N(0,4), sigma=1,
   one observation x=3. *)
GaussianPosteriorCheck[Optional[tolerance_?NumericQ, 0.001]] :=
  Module[{mean, var, errMean, errVar},
    mean = GaussianPosteriorMean[0.0, 2.0, 1.0, 1, 3.0];
    var  = GaussianPosteriorVariance[2.0, 1.0, 1];
    errMean = Abs[mean - 2.4];
    errVar  = Abs[var - 0.8];
    <|
      "mean" -> mean, "variance" -> var,
      "errMean" -> errMean, "errVariance" -> errVar,
      "pass" -> (errMean < tolerance && errVar < tolerance)
    |>
  ];

(* Check 3: Bayes factor direction & value, h=7 t=3, H1 theta=0.5,
   H2 theta=0.7 -> log10K = 7*log10(0.5/0.7) + 3*log10(0.5/0.3) =
   -0.35735 (verified via N[7*Log10[0.5/0.7]+3*Log10[0.5/0.3]] —
   the build spec's own worked example cites -0.5686 for this same
   h/t/theta1/theta2, which does not match; -0.35735 is what the
   stated formula actually evaluates to). Either way, H2 is
   correctly favoured (log10K < 0), matching theta_true=0.7. *)
BayesFactorCheck[Optional[tolerance_?NumericQ, 0.001]] :=
  Module[{logK, err},
    logK = LogBayesFactor10[7, 3, 0.5, 0.7];
    err  = Abs[logK - (-0.35735)];
    <| "logK" -> logK, "error" -> err, "pass" -> (err < tolerance) |>
  ];

(* Check 4: statistical convergence — 5 independent 100-flip
   realisations at thetaTrue=0.7, at least 4/5 should have a posterior
   mode within 0.1 of thetaTrue. This is a check on the simulation
   itself (is the random data generation + update loop behaving as
   probability theory predicts), not an exact analytic identity, so
   it is run across several seeds rather than asserted for one. *)
ConvergenceCheck[Optional[thetaTrue_?NumericQ, 0.7], Optional[nFlips_Integer, 100],
                 Optional[nRealizations_Integer, 5], Optional[tolerance_?NumericQ, 0.1]] :=
  Module[{results, nConverged},
    results = Table[
      Module[{flips, seq, finalMode},
        flips     = GenerateCoinFlips[nFlips, thetaTrue, 1000 + s];
        seq       = CoinPosteriorSequence[flips];
        finalMode = Last[seq]["mode"];
        Abs[finalMode - thetaTrue] < tolerance
      ],
      {s, nRealizations}
    ];
    nConverged = Count[results, True];
    <|
      "nConverged" -> nConverged, "nRealizations" -> nRealizations,
      "results" -> results,
      "pass" -> (nConverged >= 4)
    |>
  ];

(* NormalizationCheck — Beta(3,2) density integrates to 1.0 over
   [0,1], via NIntegrate (unit test coverage; not run as a per-run
   console check since Beta is a built-in distribution and this is
   really a sanity check on BetaDensity's wiring, not the model). *)
BetaNormalizationCheck[Optional[tolerance_?NumericQ, 0.001]] :=
  Module[{integral, err},
    integral = NIntegrate[BetaDensity[theta, 3.0, 2.0], {theta, 0, 1}];
    err = Abs[integral - 1.0];
    <| "integral" -> integral, "error" -> err, "pass" -> (err < tolerance) |>
  ];

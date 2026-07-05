#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the Bayesian inference model
   Usage: wolframscript -file tests/test_model.wl
   ======================================================== *)

$projectRoot  = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];

passed = 0;
failed = 0;

AssertTrue[label_String, condition_] :=
  If[TrueQ[condition],
    Print["  PASS  ", label];
    passed++,
    Print["  FAIL  ", label];
    failed++
  ]

Print["Running tests..."];
Print[""];

(* --- Test 1: Beta posterior mean --- *)
Module[{alpha, beta, mean},
  {alpha, beta} = BetaPosteriorParams[3, 1];
  mean = BetaMean[alpha, beta];
  AssertTrue["Beta posterior mean (h=3,t=1): 4/6 = 0.667 within 0.001",
    Abs[mean - 4.0/6.0] < 0.001];
];

(* --- Test 2: Beta posterior variance --- *)
Module[{alpha, beta, var},
  {alpha, beta} = BetaPosteriorParams[3, 1];
  var = BetaVariance[alpha, beta];
  AssertTrue["Beta posterior variance (h=3,t=1): (4*2)/(6^2*7) = 0.0317 within 0.001",
    Abs[var - (4.0 * 2.0) / (36.0 * 7.0)] < 0.001];
];

(* --- Test 3: Gaussian posterior --- *)
Module[{mean, var},
  mean = GaussianPosteriorMean[0.0, 1.0, 1.0, 1, 2.0];
  var  = GaussianPosteriorVariance[1.0, 1.0, 1];
  AssertTrue["Gaussian posterior mean (prior N(0,1), x=2): 1.0 within 0.001",
    Abs[mean - 1.0] < 0.001];
  AssertTrue["Gaussian posterior variance (prior N(0,1), 1 obs): 0.5 within 0.001",
    Abs[var - 0.5] < 0.001];
];

(* --- Test 4: Bayes factor direction --- *)
Module[{logK},
  logK = LogBayesFactor10[8, 2, 0.5, 0.8];
  AssertTrue["Bayes factor direction (h=8/10, H1:0.5 vs H2:0.8): log10K < 0 (H2 favoured)",
    logK < 0];
];

(* --- Test 5: Beta normalisation --- *)
AssertTrue["Beta(3,2) density integrates to 1.0 over [0,1] within 0.001",
  BetaNormalizationCheck[]["pass"]];

(* --- Additional coverage: correctness-check functions themselves --- *)
Print[""];
Print["-- Correctness check functions --"];
AssertTrue["BetaPosteriorCheck passes (h=7,t=3)", BetaPosteriorCheck[]["pass"]];
AssertTrue["GaussianPosteriorCheck passes (prior N(0,4), x=3)", GaussianPosteriorCheck[]["pass"]];
AssertTrue["BayesFactorCheck passes (h=7,t=3, H1:0.5 vs H2:0.7)", BayesFactorCheck[]["pass"]];
AssertTrue["ConvergenceCheck passes (theta_true=0.7, 100 flips, 5 realisations)",
  ConvergenceCheck[0.7, 100]["pass"]];

(* --- BetaMode edge cases --- *)
Print[""];
Print["-- BetaMode edge cases --"];
AssertTrue["BetaMode(1,1) = 0.5 (uniform prior, no flips)", BetaMode[1.0, 1.0] === 0.5];
AssertTrue["BetaMode(1,5) = 0.0 (all tails, alpha<=1)", BetaMode[1.0, 5.0] === 0.0];
AssertTrue["BetaMode(5,1) = 1.0 (all heads, beta<=1)", BetaMode[5.0, 1.0] === 1.0];
AssertTrue["BetaMode(8,4) = 0.7 (interior mode)", Abs[BetaMode[8.0, 4.0] - 0.7] < 10^-9];

(* --- Sequence builders --- *)
Print[""];
Print["-- Posterior sequences --"];
Module[{flips, seq},
  SeedRandom[42];
  flips = GenerateCoinFlips[20, 0.7, 42];
  seq   = CoinPosteriorSequence[flips];
  AssertTrue["CoinPosteriorSequence has one entry per flip", Length[seq] === 20];
  AssertTrue["CoinPosteriorSequence alpha+beta grows by 1 each flip",
    AllTrue[Range[2, 20], (seq[[#]]["alpha"] + seq[[#]]["beta"]) ===
      (seq[[# - 1]]["alpha"] + seq[[# - 1]]["beta"]) + 1 &]];
  AssertTrue["Posterior variance is non-increasing on average (last < first)",
    Last[seq]["variance"] < First[seq]["variance"]];
];

Module[{obs, seq},
  obs = GenerateGaussianObservations[10, 2.5, 1.0, 42];
  seq = GaussianPosteriorSequence[obs, 0.0, 2.0, 1.0];
  AssertTrue["GaussianPosteriorSequence has one entry per observation", Length[seq] === 10];
  AssertTrue["Gaussian posterior variance shrinks monotonically",
    AllTrue[Range[2, 10], seq[[#]]["variance"] < seq[[# - 1]]["variance"] &]];
];

Module[{flips, seq},
  flips = GenerateCoinFlips[30, 0.7, 42];
  seq   = ModelPosteriorSequence[flips, 0.5, 0.7];
  AssertTrue["ModelPosteriorSequence has one entry per flip", Length[seq] === 30];
];

(* --- EvidenceLevel labels --- *)
Print[""];
Print["-- EvidenceLevel labels --"];
AssertTrue["EvidenceLevel(0) = anecdotal (K=1)", EvidenceLevel[0.0] === "anecdotal"];
AssertTrue["EvidenceLevel(1.3) = strong (K~20)", EvidenceLevel[1.3] === "strong"];
AssertTrue["EvidenceLevel(3.0) = very_strong (K=1000)", EvidenceLevel[3.0] === "very_strong"];

(* --- Summary --- *)
Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

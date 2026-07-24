#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the CLT model
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

(* --- Test 1: variance scaling --- *)
AssertTrue["Variance scaling: Var(Xbar_N) = sigma^2/N for uniform source",
  VarianceScalingCheck[]["pass"]];
AssertTrue["Variance scaling holds for the exponential source too",
  VarianceScalingCheck["exponential"]["pass"]];

(* --- Test 2: Irwin-Hall (validates the sampling/histogram pipeline) --- *)
AssertTrue["Irwin-Hall exact density matches this app's own Monte Carlo histogram",
  IrwinHallCheck[]["pass"]];
AssertTrue["Irwin-Hall density integrates to 1 over [0,3]",
  Abs[NIntegrate[IrwinHallDensity[3, x], {x, 0, 3}] - 1.0] < 0.0001];
AssertTrue["Irwin-Hall density is 0 outside [0,N]",
  IrwinHallDensity[3, -0.1] === 0.0 && IrwinHallDensity[3, 3.1] === 0.0];

(* --- Test 3: dice combinatorics (validates SampleDiceSumN) --- *)
AssertTrue["Dice combinatorics: empirical P(sum=7, 2 dice) matches exact 1/6",
  DiceCombinatoricsCheck[]["pass"]];

(* --- Test 4: kurtosis decay rate --- *)
AssertTrue["Kurtosis decay: empirical rate matches (source kurtosis)/N",
  KurtosisDecayCheck[]["pass"]];

(* --- Test 5: exact moments (independent of the MC pipeline) --- *)
Print[""];
Print["-- Exact moments --"];
AssertTrue["Uniform(0,1) variance is exactly 1/12",
  SourceVariance["uniform"] === 1.0 / 12.0];
AssertTrue["Exponential(1) variance is exactly 1",
  SourceVariance["exponential"] === 1.0];
AssertTrue["Uniform(0,1) excess kurtosis is exactly -1.2",
  Abs[SourceExcessKurtosis["uniform"] - (-1.2)] < 1.0*^-9];
AssertTrue["Exponential(1) excess kurtosis is exactly 6",
  Abs[SourceExcessKurtosis["exponential"] - 6.0] < 1.0*^-9];
AssertTrue["Bernoulli(0.5) variance is exactly 0.25",
  SourceVariance["bernoulli", 0.5] === 0.25];
AssertTrue["Bernoulli(0.5) excess kurtosis matches the general formula (-2, a fair coin)",
  Abs[SourceExcessKurtosis["bernoulli", 0.5] - (-2.0)] < 1.0*^-9];

(* --- Test 6: known statistical facts --- *)
Print[""];
Print["-- Known statistical facts --"];
Module[{samplesN1, samplesN20},
  samplesN1  = SampleXbarN["exponential", 0.5, 1, 5000, 1];
  samplesN20 = SampleXbarN["exponential", 0.5, 20, 5000, 2];
  AssertTrue["Variance of Xbar_N shrinks as N grows (exponential source)",
    Variance[samplesN20] < Variance[samplesN1]];
  AssertTrue["Mean of Xbar_N stays near the source mean regardless of N",
    Abs[Mean[samplesN20] - 1.0] < 0.1];
];
Module[{diceN1, diceN10},
  diceN1  = SampleDiceSumN[1, 5000, 3];
  diceN10 = SampleDiceSumN[10, 5000, 4];
  AssertTrue["Dice sum's variance GROWS with N (opposite of the mean's variance)",
    Variance[diceN10] > Variance[diceN1]];
  AssertTrue["Mean dice sum scales linearly with N (N=10 mean near 10*3.5=35)",
    Abs[Mean[diceN10] - 35.0] < 2.0];
];
AssertTrue["Samples from SampleXbarN are machine floats, not exact rationals (bernoulli source)",
  Module[{s = SampleXbarN["bernoulli", 0.5, 3, 100, 5]}, AllTrue[s, (Head[#] === Real || IntegerQ[#]) &]]];

(* --- Test 7: display domains --- *)
Print[""];
Print["-- Display domains --"];
AssertTrue["RawMeanDisplayDomain for uniform is exactly [0,1]",
  RawMeanDisplayDomain["uniform"] === {0.0, 1.0}];
AssertTrue["RawMeanDisplayDomain for exponential extends well past the mean",
  Last[RawMeanDisplayDomain["exponential"]] > SourceMean["exponential"] + 3.0];
AssertTrue["StandardizedDisplayDomain is symmetric about 0",
  With[{d = StandardizedDisplayDomain[]}, First[d] == -Last[d]]];
AssertTrue["DiceDisplayDomain widens with n_max (opposite of RawMeanDisplayDomain)",
  Last[DiceDisplayDomain[20]] > Last[DiceDisplayDomain[10]]];
AssertTrue["DiceDisplayDomain lower bound is always 1 (minimum possible single-die sum)",
  First[DiceDisplayDomain[10]] === 1.0];

(* --- Summary --- *)
Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

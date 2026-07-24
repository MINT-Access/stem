#!/usr/bin/env wolframscript

(* brownian/tests/test_model.wl — Unit tests for the Brownian motion model *)

$projectRoot  = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];

passed = 0; failed = 0;
AssertTrue[label_String, condition_] :=
  If[TrueQ[condition],
    Print["  PASS  ", label]; passed++,
    Print["  FAIL  ", label]; failed++
  ];

Print["=== brownian/src/model.wl unit tests ==="];
Print[""];

(* ── $kB ──────────────────────────────────────────────────────────── *)
Print["-- $kB --"];
AssertTrue["kB is the exact 2019 SI value", $kB === 1.380649*^-23];
Print[""];

(* ── StokesEinsteinD ──────────────────────────────────────────────── *)
Print["-- StokesEinsteinD --"];
Module[{D = StokesEinsteinD[293.15, 1.0*^-3, 1.0*^-6]},
  AssertTrue["D is positive", D > 0];
  AssertTrue["D lands in the realistic micron/water/room-temp range (1e-13 to 1e-12 m^2/s)",
    1.0*^-13 <= D <= 1.0*^-12];
];
AssertTrue["D scales linearly with T (doubling T doubles D)",
  Abs[StokesEinsteinD[586.3, 1.0*^-3, 1.0*^-6] / StokesEinsteinD[293.15, 1.0*^-3, 1.0*^-6] - 2.0] < 10^-9];
AssertTrue["D scales inversely with viscosity",
  Abs[StokesEinsteinD[293.15, 2.0*^-3, 1.0*^-6] / StokesEinsteinD[293.15, 1.0*^-3, 1.0*^-6] - 0.5] < 10^-9];
AssertTrue["D scales inversely with particle radius",
  Abs[StokesEinsteinD[293.15, 1.0*^-3, 2.0*^-6] / StokesEinsteinD[293.15, 1.0*^-3, 1.0*^-6] - 0.5] < 10^-9];
Print[""];

(* ── WalkTrajectory ───────────────────────────────────────────────── *)
Print["-- WalkTrajectory --"];
Module[{wt = WalkTrajectory[500, 1.0*^-13, 0.01]},
  AssertTrue["trajectory has nSteps+1 rows", Length[wt] === 501];
  AssertTrue["trajectory starts at the origin", wt[[1]] === {0.0, 0.0, 0.0, 0.0}];
  AssertTrue["t column is monotonically increasing", wt[[-1, 1]] > wt[[1, 1]]];
  AssertTrue["r column is non-negative throughout", AllTrue[wt[[All, 4]], # >= 0 &]];
  AssertTrue["r column matches x,y at every row",
    AllTrue[wt, Abs[#[[4]] - Sqrt[#[[2]]^2 + #[[3]]^2]] < 10^-15 &]];
];
Print[""];

(* ── EnsembleModel ────────────────────────────────────────────────── *)
Print["-- EnsembleModel --"];
Module[{em = EnsembleModel[50, 300, 1.0*^-13, 0.01]},
  AssertTrue["t has nSteps+1 entries", Length[em["t"]] === 301];
  AssertTrue["msd has nSteps+1 entries", Length[em["msd"]] === 301];
  AssertTrue["rms = Sqrt[msd] pointwise", Max[Abs[em["rms"] - Sqrt[em["msd"]]]] < 10^-15];
  AssertTrue["msd starts at 0 (all walkers begin at the origin)", em["msd"][[1]] === 0.0];
  AssertTrue["msd is non-decreasing on average (allowing float noise)", em["msd"][[-1]] > em["msd"][[1]]];
  AssertTrue["8 sample paths kept by default", Length[em["samplePaths"]] === 8];
];
Print[""];

(* ── The four correctness checks, run directly ───────────────────── *)
Print["-- Correctness checks --"];
Module[{D = StokesEinsteinD[293.15, 1.0*^-3, 1.0*^-6], dt = 0.01},
  AssertTrue["MSDScalingCheck passes", MSDScalingCheck[D, dt]["pass"]];
  AssertTrue["StokesEinsteinScaleCheck passes", StokesEinsteinScaleCheck[]["pass"]];
  AssertTrue["ExactGaussianKurtosisCheck passes", ExactGaussianKurtosisCheck[D, dt]["pass"]];
  AssertTrue["SqrtGrowthCheck passes", SqrtGrowthCheck[D, dt]["pass"]];
];
Print[""];

(* ── Contrast with clt/'s kurtosis-decay check ───────────────────────
   clt/'s KurtosisDecayCheck (uniform source, N=30) predicts excess
   kurtosis around (source excess kurtosis)/N = -1.2/30 = -0.04 — small,
   but clearly nonzero. Here, at a much smaller N=8, the exact-Gaussian
   prediction is 0. Both facts hold simultaneously precisely because a
   sum of Gaussians is exactly Gaussian at any N, while a sum of
   uniforms is only asymptotically so. *)
Print["-- Contrast with clt/'s kurtosis-decay check --"];
Module[{D = StokesEinsteinD[293.15, 1.0*^-3, 1.0*^-6], dt = 0.01, kurtChk},
  kurtChk = ExactGaussianKurtosisCheck[D, dt];
  AssertTrue["empirical excess kurtosis at N=8 is much closer to 0 than clt/'s -0.04 at N=30",
    Abs[kurtChk["empKurt"]] < 0.02];
];
Print[""];

(* ── Temperature-range physical sanity (see AGENTS.md correction) ──── *)
Print["-- Temperature range stays liquid --"];
AssertTrue["default temp_min (275K) is above water's freezing point (273.15K)", 275.0 > 273.15];
AssertTrue["default temp_max (350K) is below water's boiling point (373.15K)", 350.0 < 373.15];
Print[""];

Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the thermo statistical
   mechanics model
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

mass = 4.0;   (* helium *)
T    = 300.0;

(* --- Test 1: MB normalisation --- *)
(* NIntegrate[f(v), {v, 0, Infinity}] = 1.0 for T=300K, mass=4amu, within 0.001 *)
integralToInfinity = NIntegrate[MBDensity[v, mass, T], {v, 0, Infinity}];
AssertTrue["MB normalisation: integral over [0, Infinity] = 1.0 within 0.001",
  Abs[integralToInfinity - 1.0] < 0.001];

(* --- Test 2: characteristic speed ratios --- *)
speedRatios = SpeedRatioCheck[mass, T, 0.0001];
AssertTrue["v_mean/v_p matches Sqrt[4/pi] within 0.01%",
  Abs[speedRatios["meanRatio"] - Sqrt[4.0/Pi]] / Sqrt[4.0/Pi] < 0.0001];
AssertTrue["v_rms/v_p matches Sqrt[3/2] within 0.01%",
  Abs[speedRatios["rmsRatio"] - Sqrt[3.0/2.0]] / Sqrt[3.0/2.0] < 0.0001];
AssertTrue["v_p < v_mean < v_rms", speedRatios["vp"] < speedRatios["vmean"] < speedRatios["vrms"]];

(* --- Test 3: speed sampling --- *)
SeedRandom[42];
samples     = SampleMBSpeeds[1000, mass, T];
sampleMean  = Mean[samples];
analyticVMean = MeanSpeed[mass, T];
AssertTrue["1000 MB samples: sample mean within 5% of analytic v_mean",
  Abs[sampleMean - analyticVMean] / analyticVMean < 0.05];
AssertTrue["all 1000 samples are non-negative", AllTrue[samples, # >= 0 &]];

(* --- Test 4: elastic collision conservation --- *)
Module[{v1 = 500.0, v2 = 1200.0, v1p, v2p, keBefore, keAfter},
  {v1p, v2p} = ElasticCollision1D[v1, v2];
  keBefore = 0.5 * (v1^2 + v2^2);
  keAfter  = 0.5 * (v1p^2 + v2p^2);
  AssertTrue["ElasticCollision1D exchanges speeds", v1p === v2 && v2p === v1];
  AssertTrue["ElasticCollision1D conserves total KE of the pair exactly",
    keBefore === keAfter];
];

(* --- Test 5: cooling curve --- *)
Module[{THot = 1000.0, TCold = 50.0, tau, tFinal, TAtFinal, fracOfRange},
  tau      = DefaultCoolingTau[5.0];
  tFinal   = 3.0 * tau;
  TAtFinal = CoolingTemperature[tFinal, THot, TCold, tau];
  fracOfRange = (TAtFinal - TCold) / (THot - TCold);
  AssertTrue["T(3*tau) is within 5% of T_cold (relative to the full T_hot-T_cold range)",
    fracOfRange < 0.05];
  AssertTrue["T(0) equals T_hot exactly",
    Abs[CoolingTemperature[0.0, THot, TCold, tau] - THot] < 10^-9];
];

(* --- Additional coverage: correctness-check functions themselves --- *)
Print[""];
Print["-- Correctness check functions --"];
AssertTrue["NormalizationCheck passes for helium at 300K", NormalizationCheck[4.0, 300.0]["pass"]];
AssertTrue["NormalizationCheck passes for nitrogen at 1000K", NormalizationCheck[28.0, 1000.0]["pass"]];
AssertTrue["EquipartitionCheck passes for helium at 300K", EquipartitionCheck[4.0, 300.0]["pass"]];
AssertTrue["EquipartitionCheck passes for nitrogen at 300K", EquipartitionCheck[28.0, 300.0]["pass"]];
Module[{ens, finalSpeeds},
  SeedRandom[7];
  ens = SimulateEnsemble[20, 4.0, 300.0, 200];
  finalSpeeds = Last[ens["speedsHistory"]];
  AssertTrue["EnsembleEquilibrationCheck passes after 200 collision timesteps",
    EnsembleEquilibrationCheck[finalSpeeds, 4.0, 300.0]["pass"]];
  AssertTrue["Ensemble collision swap conserves the speed multiset exactly",
    Sort[ens["initialSpeeds"]] === Sort[finalSpeeds]];
];

(* --- Gas presets --- *)
Print[""];
Print["-- Gas presets --"];
AssertTrue["hydrogen preset resolves to 2 amu", GasMassAmu["hydrogen", 999] === 2];
AssertTrue["helium preset resolves to 4 amu", GasMassAmu["helium", 999] === 4];
AssertTrue["nitrogen preset resolves to 28 amu", GasMassAmu["nitrogen", 999] === 28];
AssertTrue["oxygen preset resolves to 32 amu", GasMassAmu["oxygen", 999] === 32];
AssertTrue["argon preset resolves to 40 amu", GasMassAmu["argon", 999] === 40];
AssertTrue["unknown preset falls back to default", GasMassAmu["xenon", 131] === 131];
AssertTrue["helium is monatomic", MoleculeTypeOfGas["helium"] === "monatomic"];
AssertTrue["nitrogen is diatomic", MoleculeTypeOfGas["nitrogen"] === "diatomic"];

(* --- Equipartition energetics --- *)
Print[""];
Print["-- Equipartition energetics --"];
AssertTrue["monatomic total energy = (3/2)kT",
  Abs[TotalMeanEnergy[300.0, "monatomic"] - 1.5 * $kB * 300.0] < 10^-30];
AssertTrue["diatomic total energy = (5/2)kT",
  Abs[TotalMeanEnergy[300.0, "diatomic"] - 2.5 * $kB * 300.0] < 10^-30];
AssertTrue["diatomic rotational fraction is 0.4 (2 of 5 DOF)",
  Abs[RotationalFraction[300.0, "diatomic"] - 0.4] < 10^-9];
AssertTrue["monatomic rotational fraction is 0",
  RotationalFraction[300.0, "monatomic"] === 0.0];

(* --- Summary --- *)
Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

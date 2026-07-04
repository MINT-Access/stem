#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the 2D Ising model
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

(* --- Test 1: Onsager formula --- *)
onsagerKnown = 2.269185314213022;   (* 2/Log[1+Sqrt[2]] to 16 sig figs *)
AssertTrue["Onsager T_c formula matches known value to 6 significant figures",
  Abs[$OnsagerTc[1.0] - onsagerKnown] < 10^-6];
AssertTrue["OnsagerTcCheck[] agrees", OnsagerTcCheck[]["pass"]];

(* --- Test 2: all-up 4x4 lattice energy --- *)
allUp4 = AllUpGrid[4];
AssertTrue["all-up 4x4 lattice: E = -2*J*N^2",
  Abs[EnergyPerSpin[allUp4, 1.0] * 16 - (-2.0 * 1.0 * 16)] < 10^-9];

(* --- Test 3: checkerboard 4x4 lattice energy --- *)
checkerboard4 = Table[(-1)^(i + j), {i, 4}, {j, 4}];
AssertTrue["checkerboard 4x4 lattice: E = +2*J*N^2",
  Abs[EnergyPerSpin[checkerboard4, 1.0] * 16 - (2.0 * 1.0 * 16)] < 10^-9];

(* --- Test 4: Metropolis acceptance probability --- *)
Tc = $OnsagerTc[1.0];
expectedAcceptance = Exp[-2.0 * 1.0 / Tc];
AssertTrue["Metropolis acceptance for dE=2J at T=T_c matches Exp[-2J/T_c] to 6 decimal places",
  Abs[MetropolisAcceptanceProbability[2.0, Tc] - expectedAcceptance] < 10^-6];
AssertTrue["Metropolis acceptance for dE<=0 is always 1 (unconditional accept)",
  MetropolisAcceptanceProbability[-3.5, Tc] === 1.0 && MetropolisAcceptanceProbability[0.0, Tc] === 1.0];

(* --- Test 5: magnetisation range at very low T --- *)
SeedRandom[7];
lowTGrid = AllUpGrid[4];
Do[lowTGrid = RunOneSweep[lowTGrid, 4, 0.1, 1.0], {10}];
AssertTrue["10 sweeps at T=0.1 from all-up 4x4: |M| > 0.9",
  Abs[Magnetisation[lowTGrid]] > 0.9];

(* --- Additional coverage: energy bounds and detailed balance --- *)
Print[""];
Print["-- Additional model checks --"];
SeedRandom[123];
randomEnergies = EnergyPerSpin[RandomSpinGrid[32], 1.0] & /@ Range[20];
AssertTrue["EnergyBoundsCheck passes for a batch of random 32x32 configurations",
  EnergyBoundsCheck[randomEnergies, 1.0]["pass"]];
AssertTrue["EnergyBoundsCheck flags a value clearly outside [-2J, ~0]",
  !EnergyBoundsCheck[{1.5}, 1.0]["pass"]];

dbCheck = DetailedBalanceCheck[4, 1.0, Tc];
AssertTrue["DetailedBalanceCheck: forward/reverse acceptance ratio equals Exp[-dE/T]",
  dbCheck["pass"]];

(* --- Grid construction and observables --- *)
Print[""];
Print["-- Grid construction and observables --"];
grid8 = RandomSpinGrid[8];
AssertTrue["RandomSpinGrid[8] has shape {8,8}", Dimensions[grid8] === {8, 8}];
AssertTrue["RandomSpinGrid values are only +1 or -1", Complement[Union[Flatten[grid8]], {-1, 1}] === {}];
AssertTrue["Magnetisation of all-up grid is exactly 1", Magnetisation[AllUpGrid[6]] === 1.0];
AssertTrue["Magnetisation of checkerboard grid is 0",
  Abs[Magnetisation[Table[(-1)^(i + j), {i, 6}, {j, 6}]]] < 10^-9];

(* --- NearestPowerOfTwo --- *)
Print[""];
Print["-- NearestPowerOfTwo --"];
AssertTrue["32 stays 32 (already a power of 2)", NearestPowerOfTwo[32] === 32];
AssertTrue["50 rounds to 64 (nearest power of 2 by log-distance)", NearestPowerOfTwo[50] === 64];
AssertTrue["17 rounds to 16", NearestPowerOfTwo[17] === 16];

(* --- SusceptibilityEstimate --- *)
Print[""];
Print["-- SusceptibilityEstimate --"];
AssertTrue["chi is 0 for a constant magnetisation series (no fluctuation)",
  SusceptibilityEstimate[ConstantArray[0.5, 10], 8, 2.0] === 0.0];
AssertTrue["chi is positive for a fluctuating magnetisation series",
  SusceptibilityEstimate[{0.1, -0.2, 0.3, -0.1, 0.2}, 8, 2.0] > 0];

Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

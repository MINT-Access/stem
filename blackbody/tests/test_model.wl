#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the blackbody Planck
   radiation model
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

(* --- Test 1: Rayleigh-Jeans limit --- *)
rjCheck = RayleighJeansCheck[5778.0];
AssertTrue["Rayleigh-Jeans limit matches exact Planck formula within 0.1% as nu->0",
  rjCheck["pass"]];
AssertTrue["Rayleigh-Jeans check passes at a very different temperature (40000K)",
  RayleighJeansCheck[40000.0]["pass"]];

(* --- Test 2: Wien approximation limit --- *)
wienCheck = WienApproxCheck[5778.0];
AssertTrue["Wien approximation matches exact Planck formula within 0.0001% as nu->infinity",
  wienCheck["pass"]];
AssertTrue["Wien approximation check passes at 2500K",
  WienApproxCheck[2500.0]["pass"]];

(* --- Test 3: Wien's displacement law --- *)
dispCheck = WienDisplacementCheck[];
AssertTrue["Wien's displacement law: lambda_peak*T matches b within 0.1% for all test temperatures",
  dispCheck["pass"]];
AssertTrue["Peak wavelength decreases as temperature increases",
  OrderedQ[Reverse[dispCheck["lambdaPeaks"]]]];

(* --- Test 4: Stefan-Boltzmann law --- *)
sbCheck = StefanBoltzmannCheck[];
AssertTrue["Stefan-Boltzmann law: integral ratio matches (T1/T2)^4 within 0.1%",
  sbCheck["pass"]];
Module[{sb2 = StefanBoltzmannCheck[10000.0, 5000.0]},
  AssertTrue["Stefan-Boltzmann law holds for a different temperature pair (10000K/5000K = 16x)",
    sb2["pass"] && Abs[sb2["ratio"] - 16.0] / 16.0 < 0.01];
];

(* --- Test 5: known physical facts --- *)
Print[""];
Print["-- Known physical facts --"];
AssertTrue["Solar temperature (5778K) peaks in the visible band (400-700nm)",
  With[{lam = WienPeakWavelength[5778.0] * 1.0*^9}, 400.0 < lam < 700.0]];
AssertTrue["Solar peak wavelength is close to the textbook ~502nm",
  Abs[WienPeakWavelength[5778.0] * 1.0*^9 - 502.0] < 5.0];
AssertTrue["A cool red dwarf (3200K) peaks in the infrared, not visible",
  WienPeakWavelength[3200.0] * 1.0*^9 > 700.0];
AssertTrue["A hot white dwarf (25000K) peaks in the ultraviolet, not visible",
  WienPeakWavelength[25000.0] * 1.0*^9 < 400.0];

(* --- Test 6: Stefan-Boltzmann loudness mapping --- *)
Print[""];
Print["-- Stefan-Boltzmann loudness mapping --"];
AssertTrue["Loudness at Tmin equals the floor value",
  Abs[StefanBoltzmannLoudness[2500.0, 2500.0, 40000.0] - 0.15] < 10^-9];
AssertTrue["Loudness at Tmax equals 1.0",
  Abs[StefanBoltzmannLoudness[40000.0, 2500.0, 40000.0] - 1.0] < 10^-9];
AssertTrue["Loudness is monotonically increasing with T",
  StefanBoltzmannLoudness[10000.0, 2500.0, 40000.0] <
  StefanBoltzmannLoudness[20000.0, 2500.0, 40000.0]];

(* --- Test 7: star presets --- *)
Print[""];
Print["-- Star presets --"];
AssertTrue["Six named star presets are defined", Length[$StarPresets] === 6];
AssertTrue["StarOrder is sorted ascending by temperature",
  OrderedQ[$StarPresets[#] & /@ StarOrder[]]];
AssertTrue["Sun preset is 5778K", $StarPresets["sun"] === 5778.0];
AssertTrue["Red dwarf is the coolest preset", First[StarOrder[]] === "red_dwarf"];
AssertTrue["White dwarf is the hottest preset", Last[StarOrder[]] === "white_dwarf"];

(* --- Test 8: visible band edges --- *)
Print[""];
Print["-- Visible band edges --"];
AssertTrue["700nm (red edge) converts to ~4.28e14 Hz",
  Abs[$VisibleFreqLo - 4.2828*^14] / 4.2828*^14 < 0.001];
AssertTrue["400nm (violet edge) converts to ~7.49e14 Hz",
  Abs[$VisibleFreqHi - 7.4948*^14] / 7.4948*^14 < 0.001];
AssertTrue["Violet edge frequency exceeds red edge frequency",
  $VisibleFreqHi > $VisibleFreqLo];

(* --- Summary --- *)
Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

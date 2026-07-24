#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the compton scattering model
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

(* --- Test 1: forward-scattering limit --- *)
AssertTrue["Forward-scattering limit: Delta_lambda -> 0 as theta -> 0",
  ForwardScatteringLimitCheck[]["pass"]];
AssertTrue["Delta_lambda is exactly 0 at theta=0",
  ComptonWavelengthShiftPm[0.0] === 0.0];

(* --- Test 2: backscatter limit --- *)
AssertTrue["Backscatter limit: Delta_lambda -> 2*lambda_C as theta -> pi",
  BackscatterLimitCheck[]["pass"]];
AssertTrue["Compton wavelength matches the textbook 2.42631 pm within 0.001%",
  Abs[$ComptonWavelengthPm - 2.42631] / 2.42631 < 0.00001];

(* --- Test 3: Thomson (low-energy) limit --- *)
AssertTrue["Thomson limit: E'/E -> 1 as E/(m_e c^2) -> 0",
  ThomsonLimitCheck[]["pass"]];
AssertTrue["A visible-light photon (2 eV) loses a negligible energy fraction at 180 deg",
  (1.0 - ComptonOutgoingEnergyKeV[0.002, N[Pi]] / 0.002) < 0.0001];

(* --- Test 4: energy-momentum conservation --- *)
AssertTrue["Energy-momentum conservation holds at Compton's own 1923 values (17.5 keV, 90 deg)",
  MomentumConservationCheck[]["pass"]];
AssertTrue["Energy-momentum conservation holds at a gamma-ray energy (1000 keV, 45 deg)",
  MomentumConservationCheck[1000.0, Pi / 4.0]["pass"]];
AssertTrue["Energy-momentum conservation holds at backscatter (500 keV, 180 deg)",
  MomentumConservationCheck[500.0, N[Pi]]["pass"]];

(* --- Test 5: unit conversions --- *)
Print[""];
Print["-- Unit conversions --"];
AssertTrue["71.0 pm converts to ~17.46 keV",
  Abs[PhotonEnergyKeV[71.0] - 17.463] < 0.01];
AssertTrue["Round-trip: wavelength -> energy -> wavelength is the identity",
  Abs[PhotonWavelengthPm[PhotonEnergyKeV[71.0]] - 71.0] < 1.0*^-9];
AssertTrue["hc constant matches the textbook 1239.84 eV*nm within 0.001%",
  Abs[$HcKevPm - 1239.84] / 1239.84 < 0.0001];

(* --- Test 6: known physical facts --- *)
Print[""];
Print["-- Known physical facts --"];
AssertTrue["Compton's own 1923 measurement (71pm, 90deg) shifts by ~2.43 pm",
  Abs[ComptonWavelengthShiftPm[Pi / 2.0] - 2.42631] < 0.001];
AssertTrue["Outgoing energy is always less than incoming energy for theta in (0,pi]",
  AllTrue[Range[10, 170, 10], ComptonOutgoingEnergyKeV[100.0, #* Pi/180.0] < 100.0 &]];
AssertTrue["Outgoing energy equals incoming energy exactly at theta=0 (no shift)",
  ComptonOutgoingEnergyKeV[100.0, 0.0] === 100.0];
AssertTrue["A high-energy gamma ray (10 MeV) loses the majority of its energy at backscatter",
  (10000.0 - ComptonOutgoingEnergyKeV[10000.0, N[Pi]]) / 10000.0 > 0.9];

(* --- Test 7: recoil electron angle --- *)
Print[""];
Print["-- Recoil electron angle --"];
AssertTrue["Recoil angle is 45 deg (bisecting incident/scattered directions) in the Thomson limit at 90 deg scattering",
  Abs[RecoilElectronAngleDeg[0.0001, Pi / 2.0] - 45.0] < 1.0];
AssertTrue["Recoil angle is between 0 and 90 degrees for any forward-scattering event",
  With[{phi = RecoilElectronAngleDeg[17.5, Pi / 4.0]}, 0.0 < phi < 90.0]];
AssertTrue["Recoil angle approaches 0 deg (straight forward) at theta -> pi (backscatter)",
  RecoilElectronAngleDeg[17.5, N[Pi] - 0.001] < 1.0];

(* --- Test 8: pitch/pan mapping helpers --- *)
Print[""];
Print["-- Pitch/pan mapping helpers --"];
AssertTrue["PhotonPitchHz at E=EMin returns audioFreqMin",
  Abs[PhotonPitchHz[1.0, 1.0, 5000.0, 200.0, 3000.0] - 200.0] < 1.0*^-6];
AssertTrue["PhotonPitchHz at E=EMax returns audioFreqMax",
  Abs[PhotonPitchHz[5000.0, 1.0, 5000.0, 200.0, 3000.0] - 3000.0] < 1.0*^-6];
AssertTrue["PhotonPitchHz is monotonically increasing with energy",
  PhotonPitchHz[10.0, 1.0, 5000.0, 200.0, 3000.0] < PhotonPitchHz[100.0, 1.0, 5000.0, 200.0, 3000.0]];
AssertTrue["ComptonPan(0 deg) is hard left (-1)", ComptonPan[0.0] === -1.0];
AssertTrue["ComptonPan(180 deg) is hard right (+1)", ComptonPan[180.0] === 1.0];
AssertTrue["ComptonPan(90 deg) is centred (0)", Abs[ComptonPan[90.0]] < 1.0*^-9];

(* --- Summary --- *)
Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

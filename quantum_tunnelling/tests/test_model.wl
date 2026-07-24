#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the quantum tunnelling model
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

(* --- Test 1: L->0 limit --- *)
AssertTrue["L->0 limit: T->1 for both E<V0 and E>V0",
  LToZeroLimitCheck[]["pass"]];

(* --- Test 2: deep-tunnelling asymptotic --- *)
AssertTrue["Deep-tunnelling asymptotic form matches exact T within 0.1%",
  DeepTunnelingAsymptoticCheck[]["pass"]];

(* --- Test 3: resonance condition (the most important check) --- *)
AssertTrue["Resonance condition: T=1 exactly at k*L=pi (default test point)",
  ResonanceConditionCheck[]["pass"]];
AssertTrue["Resonance condition holds at a different (E,V0) pair",
  ResonanceConditionCheck[5.0, 3.0]["pass"]];
AssertTrue["Second resonance (n=2, k*L=2*pi) is also perfect transmission",
  Module[{mc2 = $ElectronMassEnergyEV, E = 3.0, V0 = 2.0, k, L2},
    k  = KOrKappaPerNm[mc2, E - V0];
    L2 = 2.0 * Pi / k;
    Abs[TransmissionCoefficient[E, V0, L2, mc2] - 1.0] < 1.0*^-9
  ]];

(* --- Test 4: probability conservation --- *)
AssertTrue["Probability conservation: T+R=1 across both regimes",
  ProbabilityConservationCheck[]["pass"]];

(* --- Test 5: known physical facts --- *)
Print[""];
Print["-- Known physical facts --"];
AssertTrue["A classically forbidden particle (E<V0) still has T>0 (genuine tunnelling)",
  TransmissionCoefficient[1.0, 2.0, 0.5, $ElectronMassEnergyEV] > 0.0];
AssertTrue["Thicker barriers transmit less (E<V0, monotonic decrease)",
  TransmissionCoefficient[1.0, 2.0, 1.0, $ElectronMassEnergyEV] <
  TransmissionCoefficient[1.0, 2.0, 0.5, $ElectronMassEnergyEV]];
AssertTrue["A taller barrier (same E, same L) transmits less",
  TransmissionCoefficient[1.0, 3.0, 0.5, $ElectronMassEnergyEV] <
  TransmissionCoefficient[1.0, 2.0, 0.5, $ElectronMassEnergyEV]];
AssertTrue["A heavier particle tunnels less easily than a lighter one (same E,V0,L)",
  TransmissionCoefficient[5.0*^6, 3.0*^7, 5.0*^-6, $AlphaMassEnergyEV] <
  TransmissionCoefficient[5.0*^6, 3.0*^7, 5.0*^-6, $ElectronMassEnergyEV]];
AssertTrue["Well above the barrier (E>>V0), transmission approaches 1 on average",
  TransmissionCoefficient[1000.0, 2.0, 0.5, $ElectronMassEnergyEV] > 0.99];

(* --- Test 6: presets --- *)
Print[""];
Print["-- Named presets --"];
AssertTrue["default preset gives a comfortably audible T (1%-10%)",
  With[{p = $TunnellingPresets["default"]},
    With[{T = TransmissionCoefficient[p["energy_ev"], p["barrier_height_ev"],
                                       p["barrier_width_nm"], p["mass_ev"]]},
      0.01 < T < 0.10
    ]
  ]];
AssertTrue["stm preset gives a small but clearly nonzero T (1e-8 to 1e-3)",
  With[{p = $TunnellingPresets["stm"]},
    With[{T = TransmissionCoefficient[p["energy_ev"], p["barrier_height_ev"],
                                       p["barrier_width_nm"], p["mass_ev"]]},
      1.0*^-8 < T < 1.0*^-3
    ]
  ]];
AssertTrue["alpha_decay preset gives an extremely small but nonzero T (< 1e-6)",
  With[{p = $TunnellingPresets["alpha_decay"]},
    With[{T = TransmissionCoefficient[p["energy_ev"], p["barrier_height_ev"],
                                       p["barrier_width_nm"], p["mass_ev"]]},
      0.0 < T < 1.0*^-6
    ]
  ]];
AssertTrue["All three presets are in the tunnelling regime (E<V0)",
  AllTrue[Values[$TunnellingPresets], #["energy_ev"] < #["barrier_height_ev"] &]];

(* --- Test 7: constants --- *)
Print[""];
Print["-- Constants --"];
AssertTrue["hbarc matches the textbook 197.3269804 eV*nm within 1e-9",
  Abs[$HbarCEvNm - 197.3269804] < 1.0*^-9];
AssertTrue["Electron mass matches compton/'s constant (510.99895 keV = 510998.95 eV)",
  Abs[$ElectronMassEnergyEV - 510998.95] < 1.0*^-6];
AssertTrue["Alpha particle mass is roughly 4x the proton mass scale (~3727 MeV)",
  3700.0*^6 < $AlphaMassEnergyEV < 3750.0*^6];

(* --- Test 8: pitch mapping --- *)
Print[""];
Print["-- Pitch mapping --"];
AssertTrue["TunnellingPitchHz at the domain floor returns audioFreqMin",
  Abs[TunnellingPitchHz[0.01, 150.0, 2500.0] - 150.0] < 1.0*^-6];
AssertTrue["TunnellingPitchHz is monotonically increasing with energy",
  TunnellingPitchHz[1.0, 150.0, 2500.0] < TunnellingPitchHz[1000.0, 150.0, 2500.0]];

(* --- Summary --- *)
Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the hydrogen atom model
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

(* --- Test 1: Lyman alpha wavelength ---
   Reference 121.567 nm is the real (reduced-mass, air-refraction)
   value; this app's energy formula uses the infinite-nuclear-mass
   Rydberg constant 13.6057 eV exactly as specified, which is inherently
   ~0.05% off from that reference (dominated by the electron/proton
   reduced-mass correction, ~1/1836) -- see hydrogen/AGENTS.md for the
   derivation. 0.1% is the tightest tolerance achievable with the
   specified formula, so tests use that rather than 0.01%. *)
lyAlpha = PhotonWavelengthNm[2, 1];
AssertTrue["Lyman alpha (n=2->1) wavelength = 121.567 nm within 0.1%",
  Abs[lyAlpha - 121.567] / 121.567 < 0.001];

(* --- Test 2: Balmer alpha wavelength --- *)
hAlpha = PhotonWavelengthNm[3, 2];
AssertTrue["Balmer alpha (n=3->2) wavelength = 656.279 nm within 0.1%",
  Abs[hAlpha - 656.279] / 656.279 < 0.001];

(* --- Test 3: energy level ratio --- *)
AssertTrue["E_2/E_1 = 1/4 exactly",
  EnergyLevelEV[2] / EnergyLevelEV[1] === 0.25];

(* --- Test 4: selection rule enforcement --- *)
AssertTrue["2s -> 1s (Delta l = 0) is correctly identified as forbidden",
  !SelectionRuleAllowedQ[0, 0]];
AssertTrue["2p -> 1s (Delta l = 1) is correctly identified as allowed",
  SelectionRuleAllowedQ[1, 0]];
AssertTrue["AllowedTransitionsFrom[2,0] (2s) has no allowed targets (metastable)",
  AllowedTransitionsFrom[2, 0] === {}];
AssertTrue["AllowedTransitionsFrom[2,1] (2p) allows decay to {1,0}",
  MemberQ[AllowedTransitionsFrom[2, 1], {1, 0}]];

(* --- Test 5: wave function mirror symmetry ---
   |psi_210(r,theta=0,phi=0)| at a point on the +x axis should equal
   |psi_210| at the mirrored point across the xy-plane -- i.e. z -> -z,
   equivalently theta -> Pi - theta at the same phi. This is a genuine
   symmetry of the 2p_z (m=0) orbital: |psi|^2 depends on cos(theta)
   only through an even power for l=1,m=0 (Y_1^0 ~ cos(theta), and
   |cos(theta)|^2 = |cos(Pi-theta)|^2 only up to sign -- checked via
   OrbitalPointDensity directly at mirrored (x,z) and (x,-z) points,
   which is exactly the symmetry the orbitals-mode cross-section relies
   on to look like two symmetric lobes). *)
densityAtPosZ = OrbitalPointDensity[2, 1, 0, 3.0,  4.0];
densityAtNegZ = OrbitalPointDensity[2, 1, 0, 3.0, -4.0];
AssertTrue["|psi_210(x=3,z=4)|^2 = |psi_210(x=3,z=-4)|^2 (mirror symmetry across xy-plane)",
  Abs[densityAtPosZ - densityAtNegZ] < 1.0*^-12];

(* --- Additional coverage --- *)
Print[""];
Print["-- Additional coverage --"];

AssertTrue["EnergyLevelCheck passes", EnergyLevelCheck[]["pass"]];
AssertTrue["RydbergCheck passes at 0.1% tolerance", RydbergCheck[0.001]["pass"]];

AssertTrue["HydrogenRadialR[1,0,r] normalises to 1 over [0,50]",
  Abs[NIntegrate[HydrogenRadialR[1, 0, r]^2 * r^2, {r, 0, 50}] - 1.0] < 0.001];
AssertTrue["HydrogenRadialR[3,2,r] normalises to 1 over [0,80]",
  Abs[NIntegrate[HydrogenRadialR[3, 2, r]^2 * r^2, {r, 0, 80}] - 1.0] < 0.001];

AssertTrue["SeriesName[1] is Lyman", SeriesName[1] === "Lyman"];
AssertTrue["SeriesName[2] is Balmer", SeriesName[2] === "Balmer"];
AssertTrue["SeriesName[3] is Paschen", SeriesName[3] === "Paschen"];

AssertTrue["EinsteinA[3,2] returns the hard-coded Balmer-alpha value",
  EinsteinA[3, 2] === 4.41*^7];
AssertTrue["EinsteinA[10,7] (uncatalogued pair) falls back to the approximation formula",
  EinsteinA[10, 7] =!= 4.41*^7 && EinsteinA[10, 7] > 0];

lines8 = BuildSpectralLines[8];
AssertTrue["BuildSpectralLines[8] returns 28 lines (Sum_{k=1}^{7} k)",
  Length[lines8] === 28];
AssertTrue["Every spectral line has n_upper > n_lower",
  AllTrue[lines8, #["n_upper"] > #["n_lower"] &]];

grid210 = ComputeOrbitalTraversal["210", 16];
AssertTrue["ComputeOrbitalTraversal[\"210\",16] returns 256 pixels",
  grid210["nPixels"] === 256];
AssertTrue["Orbital density values are all non-negative",
  Min[Flatten[grid210["density"]]] >= 0.0];

SeedRandom[42];
cascade = SimulateCascade[5, 2, 50];
AssertTrue["SimulateCascade[5,2,50] reaches the ground state {1,0}",
  Last[cascade]["n_lower"] === 1 && Last[cascade]["l_lower"] === 0];
AssertTrue["SimulateCascade steps all satisfy the selection rule",
  SelectionRuleCheck[cascade]["pass"]];

(* --- Summary --- *)
Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

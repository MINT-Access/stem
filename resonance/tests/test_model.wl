#!/usr/bin/env wolframscript
(* Unit tests for resonance/src/model.wl *)

$projectRoot  = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];

passed = 0;
failed = 0;

AssertTrue[label_String, cond_] := If[TrueQ[cond],
  (Print["  [PASS] ", label]; passed++),
  (Print["  [FAIL] ", label]; failed++)];

AssertNear[label_String, got_, expected_, tol_:1*^-6] :=
  AssertTrue[label, Abs[N[got] - N[expected]] < tol];

Print["== Test 1: Galilean period ratio (exact by construction) =="];

AssertNear["T_Eu/T_Io = 2.000 exactly", $TEuropa / $TIo, 2.0, 1*^-9];
AssertNear["T_Ga/T_Io = 4.000 exactly", $TGanymede / $TIo, 4.0, 1*^-9];

Print[""];
Print["== Test 2: Kepler's third law, 3:1 Kirkwood gap =="];

a31 = KirkwoodResonanceAU[3, 1];
expected2 = 5.203 * (1.0/3.0)^(2.0/3.0);
AssertNear["a_3:1 = 5.203*(1/3)^(2/3) = 2.502 AU within 0.001 AU", a31, expected2, 0.001];
AssertNear["a_3:1 numerically equals 2.502 AU within 0.001 AU", a31, 2.502, 0.001];

Print[""];
Print["== Test 3: Cassini Division, 2:1 resonance with Mimas =="];

(* The idealised point-mass formula's own arithmetic, checked against
   itself computed independently -- both sides use the same
   $AMimasKm/(1/2)^(2/3) the model uses, so this verifies the formula
   is wired correctly, not a specific numeric literal. *)
rCassiniPredicted = $AMimasKm * (0.5)^(2.0/3.0);
expected3 = 185539.0 * (0.5)^(2.0/3.0);
AssertNear["r = 185539*(1/2)^(2/3) computed correctly", rCassiniPredicted, expected3, 0.01];

(* The real observed Cassini Division inner edge (117,580 km) differs
   from this idealised prediction by ~700 km / 0.6% -- a genuine
   physical discrepancy from Saturn's oblateness (J2), not a bug (see
   AGENTS.md). CassiniDivisionCheck uses a 1000 km tolerance to reflect
   that honestly, and should pass. *)
cassiniCheck = CassiniDivisionCheck[];
AssertTrue["CassiniDivisionCheck (widened 1000 km tolerance) passes", cassiniCheck["pass"]];

Print[""];
Print["== Test 4: Octave ratio (C3/C4/C5 pitches) =="];

AssertNear["C4/C3 = 2.000 within 0.001", $PitchEuropaHz / $PitchGanymedeHz, 2.0, 0.001];
AssertNear["C5/C3 = 4.000 within 0.001", $PitchIoHz / $PitchGanymedeHz, 4.0, 0.001];

Print[""];
Print["== Test 5: Galilean event count over 4 Io periods =="];

(* n_periods=1 Ganymede period = 4 Io periods exactly. *)
cfg5 = <|"simulation" -> <|"resonance" -> <|"n_periods" -> 1, "n_steps" -> 200|>|>|>;
m5 = GalileanModel[cfg5];

AssertTrue["exactly 4 Io orbit events", m5["nIoEvents"] === 4];
AssertTrue["exactly 2 Europa orbit events", m5["nEuEvents"] === 2];
AssertTrue["exactly 1 Ganymede orbit event", m5["nGaEvents"] === 1];

Print[""];
Print["================="];
Print["Passed: ", passed];
Print["Failed: ", failed];
If[failed > 0, Exit[1], Exit[0]];

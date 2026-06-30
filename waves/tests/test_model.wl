#!/usr/bin/env wolframscript

(* waves/tests/test_model.wl — Unit tests for model.wl *)

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

Print["=== waves/src/model.wl unit tests ==="];
Print[""];

(* Build a minimal test config with fast settings *)
testCfg = <|"simulation" -> <|"waves" -> <|
  "wave_speed" -> 1.0,
  "membrane_radius" -> 1.0,
  "tank_width" -> 2.0,
  "tank_height" -> 1.0,
  "source_frequency" -> 2.0,
  "duration" -> 2.0,      (* shorter duration for test speed *)
  "listening_points" -> 2  (* fewer LPs for test speed *)
|>|>|>;

(* ── RippleModel ────────────────────────────────────────────────── *)
Print["-- RippleModel --"];
rippleModel = RippleModel[testCfg];
AssertTrue["returns Association",           AssociationQ[rippleModel]];
AssertTrue["solR key exists",               KeyExistsQ[rippleModel, "solR"]];
AssertTrue["lpDisp key exists",             KeyExistsQ[rippleModel, "lpDisp"]];
AssertTrue["nLP = 2",                       rippleModel["nLP"] === 2];
AssertTrue["nT = 300",                      rippleModel["nT"] === 300];
AssertTrue["tVals starts at 0",             rippleModel["tVals"][[1]] < 0.02];
AssertTrue["tVals ends at tEnd",
  Abs[Last[rippleModel["tVals"]] - 2.0] < 0.05];
AssertTrue["lpDisp has nLP entries",        Length[rippleModel["lpDisp"]] === 2];
AssertTrue["lpDisp has nT time steps",      Length[rippleModel["lpDisp"][[1]]] === 300];
AssertTrue["maxR > 0 (wave propagates)",    rippleModel["maxR"] > 0.0];
AssertTrue["lpX all in (0, r]",
  AllTrue[rippleModel["lpX"], 0.0 < # <= 1.0 &]];
AssertTrue["lpPans in [-1, 1]",
  AllTrue[rippleModel["lpPans"], -1.0 <= # <= 1.0 &]];
Print[""];

(* ── InterferenceModel ──────────────────────────────────────────── *)
Print["-- InterferenceModel --"];
interferenceModel = InterferenceModel[testCfg];
AssertTrue["returns Association",             AssociationQ[interferenceModel]];
AssertTrue["solI key exists",                 KeyExistsQ[interferenceModel, "solI"]];
AssertTrue["dispMoving key exists",           KeyExistsQ[interferenceModel, "dispMoving"]];
AssertTrue["dispFixed key exists",            KeyExistsQ[interferenceModel, "dispFixed"]];
AssertTrue["nT = 300",                        interferenceModel["nT"] === 300];
AssertTrue["dispMoving has nT entries",       Length[interferenceModel["dispMoving"]] === 300];
AssertTrue["xMoving has nT entries",          Length[interferenceModel["xMoving"]] === 300];
AssertTrue["maxI > 0 (interference present)", interferenceModel["maxI"] > 0.0];
AssertTrue["x1s < 0 (source on left)",        interferenceModel["x1s"] < 0.0];
AssertTrue["x2s > 0 (source on right)",       interferenceModel["x2s"] > 0.0];
AssertTrue["sources symmetric",
  Abs[interferenceModel["x1s"] + interferenceModel["x2s"]] < 1.0*^-10];
Print[""];

Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]]

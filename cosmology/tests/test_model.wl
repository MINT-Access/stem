#!/usr/bin/env wolframscript

(* cosmology/tests/test_model.wl — Unit tests for model.wl and fetch.wl *)

$projectRoot  = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "fetch.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];

passed = 0; failed = 0;
AssertTrue[label_String, condition_] :=
  If[TrueQ[condition],
    Print["  PASS  ", label]; passed++,
    Print["  FAIL  ", label]; failed++
  ];

Print["=== cosmology/src/model.wl unit tests ==="];
Print[""];

(* ── $cmbPeakSpecs ─────────────────────────────────────────────── *)
Print["-- Peak specifications --"];
AssertTrue["5 peak entries", Length[$cmbPeakSpecs] === 5];
AssertTrue["all peaks have positive l_center", AllTrue[$cmbPeakSpecs, #[[1]] > 0 &]];
AssertTrue["all peaks have positive amplitude", AllTrue[$cmbPeakSpecs, #[[2]] > 0 &]];
AssertTrue["peaks in ascending l order",
  AllTrue[Differences[$cmbPeakSpecs[[All, 1]]], # > 0 &]];
Print[""];

(* ── SimulatedDl ───────────────────────────────────────────────── *)
Print["-- SimulatedDl --"];
AssertTrue["SimulatedDl(2) >= 0",  SimulatedDl[2]    >= 0.0];
AssertTrue["D_l >= 0 at l=220",   SimulatedDl[220]  >= 0.0];
AssertTrue["D_l >= 0 at l=2000",  SimulatedDl[2000] >= 0.0];
AssertTrue["first peak at l~220 is a local max",
  SimulatedDl[220] > SimulatedDl[180] && SimulatedDl[220] > SimulatedDl[260]];
AssertTrue["D_l at l=220 > D_l at l=540 (first > second peak)",
  SimulatedDl[220] > SimulatedDl[540]];
AssertTrue["Sachs-Wolfe plateau: D_l at l=10 > 500 muK^2",
  SimulatedDl[10] > 500.0];
Print[""];

(* ── DlToCl ────────────────────────────────────────────────────── *)
Print["-- DlToCl --"];
AssertTrue["DlToCl(l=0, ...) = 0",  DlToCl[0, 100.0] === 0.0];
AssertTrue["DlToCl(l=1, ...) = 0",  DlToCl[1, 100.0] === 0.0];
AssertTrue["DlToCl(l=2, ...) > 0",  DlToCl[2, 100.0] > 0.0];
AssertTrue["DlToCl(l=220, D=5400) matches formula",
  Abs[DlToCl[220, 5400] - 2 Pi * 5400 / (220 * 221)] < 1.0*^-6];
Print[""];

(* ── LoadSpectrum (simulated) ───────────────────────────────────── *)
Print["-- LoadSpectrum (simulated) --"];
{lArr, dlArr, clArr} = LoadSpectrum["simulated", 500];
AssertTrue["lArr starts at 2",          First[lArr] === 2];
AssertTrue["lArr ends at 500",          Last[lArr] === 500];
AssertTrue["lArr length = 499",         Length[lArr] === 499];
AssertTrue["dlArr all non-negative",    AllTrue[dlArr, # >= 0.0 &]];
AssertTrue["clArr length matches lArr", Length[clArr] === Length[lArr]];
AssertTrue["clArr at l=2 > 0",         clArr[[1]] > 0.0];
Print[""];

(* ── CMBPhysicsChecks ───────────────────────────────────────────── *)
Print["-- CMBPhysicsChecks --"];
{lArr2, dlArr2, clArr2} = LoadSpectrum["simulated", 2000];
checks = CMBPhysicsChecks[lArr2, dlArr2];
AssertTrue["checks is Association",       AssociationQ[checks]];
AssertTrue["peakIdxs key exists",         KeyExistsQ[checks, "peakIdxs"]];
AssertTrue["peakLVals key exists",        KeyExistsQ[checks, "peakLVals"]];
AssertTrue["peakDlVals key exists",       KeyExistsQ[checks, "peakDlVals"]];
AssertTrue["at least 3 peaks detected",   Length[checks["peakIdxs"]] >= 3];
AssertTrue["first peak near l=220",
  Abs[First[checks["peakLVals"]] - 220] < 40];
AssertTrue["peak amplitudes > 0",
  AllTrue[checks["peakDlVals"], # > 0 &]];
Print[""];

Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]]

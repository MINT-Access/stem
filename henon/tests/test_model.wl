#!/usr/bin/env wolframscript

(* henon/tests/test_model.wl — Unit tests for the Hénon map model *)

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

Print["=== henon/src/model.wl unit tests ==="];
Print[""];

(* ── HenonMap basics ─────────────────────────────────────────────── *)
Print["-- HenonMap --"];
AssertTrue["F[{0,0},1.4,0.3] = {1,0}", HenonMap[{0.0, 0.0}, 1.4, 0.3] === {1.0, 0.0}];
Module[{r = HenonMap[{0.5, 0.2}, 1.4, 0.3]},
  AssertTrue["F[{0.5,0.2},1.4,0.3] matches hand calc",
    Abs[r[[1]] - (1.0 - 1.4*0.25 + 0.2)] < 10^-12 && Abs[r[[2]] - 0.3*0.5] < 10^-12]
];
Print[""];

(* ── HenonMapInverse round trip ──────────────────────────────────── *)
Print["-- HenonMapInverse --"];
Module[{pt = {0.37, -0.21}, fwd, back},
  fwd  = HenonMap[pt, 1.4, 0.3];
  back = HenonMapInverse[fwd, 1.4, 0.3];
  AssertTrue["forward-then-inverse recovers the original point", Norm[pt - back] < 10^-9]
];
Print[""];

(* ── Jacobian: exact -b everywhere, including off-attractor points ── *)
Print["-- HenonJacobianDetAt --"];
AssertTrue["det = -b at the origin",       Abs[HenonJacobianDetAt[0.0, 0.0, 1.4, 0.3] - (-0.3)] < 10^-12];
AssertTrue["det = -b at an arbitrary point", Abs[HenonJacobianDetAt[3.7, -2.2, 1.4, 0.3] - (-0.3)] < 10^-12];
AssertTrue["det = -b for a different b too", Abs[HenonJacobianDetAt[1.0, 1.0, 1.4, 0.7] - (-0.7)] < 10^-12];
Print[""];

(* ── Fixed point: a x*^2 + (1-b) x* - 1 == 0 ─────────────────────── *)
Print["-- HenonFixedPointX --"];
Module[{a = 1.4, b = 0.3, xfp},
  xfp = HenonFixedPointX[a, b];
  AssertTrue["fixed point solves its defining quadratic",
    Abs[a*xfp^2 + (1.0 - b)*xfp - 1.0] < 10^-9];
  AssertTrue["fixed point is an actual fixed point of the map",
    Norm[HenonMap[{xfp, b*xfp}, a, b] - {xfp, b*xfp}] < 10^-9]
];
Print[""];

(* ── First flip bifurcation: closed form vs FindRoot agree ───────── *)
Print["-- FirstFlipBifurcationA --"];
Module[{b = 0.3, aRoot, aClosed},
  aRoot   = FirstFlipBifurcationA[b];
  aClosed = FirstFlipBifurcationAClosedForm[b];
  AssertTrue["FindRoot result matches the closed form 3(1-b)^2/4",
    Abs[aRoot - aClosed] < 10^-9];
  AssertTrue["just below a1: period 1", ClassifyPeriod[aRoot - 0.02, b] === 1];
  AssertTrue["just above a1: period 2", ClassifyPeriod[aRoot + 0.02, b] === 2]
];
Print[""];

(* ── ClassifyPeriod at known landmark points ─────────────────────── *)
Print["-- ClassifyPeriod --"];
AssertTrue["a=0.2 settles to period 1",  ClassifyPeriod[0.2, 0.3] === 1];
AssertTrue["a=0.6 settles to period 2",  ClassifyPeriod[0.6, 0.3] === 2];
AssertTrue["a=0.95 settles to period 4", ClassifyPeriod[0.95, 0.3] === 4];
AssertTrue["a=1.4 (canonical) is far from any low period (chaotic)",
  ClassifyPeriod[1.4, 0.3] > 20];
Print[""];

(* ── Sweep landmarks: ordering and plausibility ──────────────────── *)
Print["-- HenonSweepLandmarks --"];
Module[{lm = HenonSweepLandmarks[0.3]},
  AssertTrue["first_bifurcation < second_bifurcation",
    lm["first_bifurcation"] < lm["second_bifurcation"]];
  AssertTrue["second_bifurcation < third_bifurcation",
    lm["second_bifurcation"] < lm["third_bifurcation"]];
  AssertTrue["third_bifurcation < chaos_onset",
    lm["third_bifurcation"] < lm["chaos_onset"]];
  AssertTrue["chaos_onset < periodic_window",
    lm["chaos_onset"] < lm["periodic_window"]];
  AssertTrue["periodic_window has a low settled period (< 20)",
    lm["periodic_window_period"] < 20];
  AssertTrue["Feigenbaum-like ratio is within 10% of the universal 4.6692",
    Abs[lm["feigenbaum_ratio"] - 4.6692] / 4.6692 < 0.10]
];
Print[""];

(* ── Lyapunov exponents at canonical parameters ──────────────────── *)
Print["-- HenonLyapunovExponents --"];
Module[{lyaps = HenonLyapunovExponents[1.4, 0.3, 20000, 2000]},
  AssertTrue["two exponents returned", Length[lyaps] === 2];
  AssertTrue["largest exponent is positive (chaos signature)", First[lyaps] > 0];
  AssertTrue["sum equals log(b) to tight tolerance",
    Abs[Total[lyaps] - Log[0.3]] < 10^-6];
  AssertTrue["largest exponent within 20% of the ~0.42 literature benchmark",
    Abs[First[lyaps] - 0.42] / 0.42 < 0.20]
];
Print[""];

(* ── The four correctness checks, run directly ───────────────────── *)
Print["-- Correctness checks --"];
AssertTrue["JacobianCheck passes at canonical parameters", JacobianCheck[1.4, 0.3]["pass"]];
Module[{lyaps = HenonLyapunovExponents[1.4, 0.3, 50000, 2000]},
  AssertTrue["LyapunovSumCheck passes",       LyapunovSumCheck[lyaps, 0.3]["pass"]];
  AssertTrue["LyapunovBenchmarkCheck passes", LyapunovBenchmarkCheck[lyaps]["pass"]]
];
AssertTrue["InverseExactnessCheck passes", InverseExactnessCheck[1.4, 0.3]["pass"]];
Print[""];

(* ── Mode data-assembly shapes ────────────────────────────────────── *)
Print["-- HenonAttractorModel / HenonSweepModel / HenonReverseModel --"];
Module[{am = HenonAttractorModel[0.1, 0.1, 1.4, 0.3, 200, 500]},
  AssertTrue["attractor trajectory has nPoints+1 entries", Length[am["trajectory"]] === 501]
];
Module[{sm = HenonSweepModel[0.2, 1.4, 15, 0.3, 0.1, 0.1, 200, 20]},
  AssertTrue["aValues has 15 entries", Length[sm["aValues"]] === 15];
  AssertTrue["attractors has 15 entries", Length[sm["attractors"]] === 15];
  AssertTrue["each attractor step has 21 points (nAttractor+1)", Length[sm["attractors"][[1]]] === 21];
  AssertTrue["aValues starts at a_start", sm["aValues"][[1]] === 0.2];
  AssertTrue["aValues ends at a_end", Last[sm["aValues"]] === 1.4]
];
Module[{rm = HenonReverseModel[0.1, 0.1, 1.4, 0.3, 200, 30, 8]},
  AssertTrue["forwardSeg has nForward+1 entries", Length[rm["forwardSeg"]] === 31];
  AssertTrue["reversedSeg is the exact reverse of forwardSeg",
    rm["reversedSeg"] === Reverse[rm["forwardSeg"]]];
  AssertTrue["inverse-demo round-trip error is tiny", rm["inverseDemoMaxError"] < 10^-6]
];
Print[""];

(* ── Box-counting dimension: sanity range only (diagnostic estimate) ── *)
Print["-- BoxCountingDimension --"];
Module[{am = HenonAttractorModel[0.1, 0.1, 1.4, 0.3, 500, 4000], dim},
  dim = BoxCountingDimension[am["trajectory"]];
  AssertTrue["dimension estimate lands in a plausible range (1.0, 1.6)", 1.0 < dim < 1.6]
];
Print[""];

Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

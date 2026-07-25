#!/usr/bin/env wolframscript

(* mandelbrot/tests/test_model.wl — Unit tests for the mandelbrot model *)

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

Print["=== mandelbrot/src/model.wl unit tests ==="];
Print[""];

(* ── Core iteration ────────────────────────────────────────────────── *)
Print["-- MandelbrotEscapeIterations / JuliaEscapeIterations --"];
AssertTrue["c=0 never escapes (returns maxIter)", MandelbrotEscapeIterations[0.0, 100] === 100];
AssertTrue["c=1 escapes almost immediately", MandelbrotEscapeIterations[1.0, 100] < 10];
AssertTrue["c=-1 never escapes (period-2 cycle)", MandelbrotEscapeIterations[-1.0, 100] === 100];
AssertTrue["c=2.1 (outside |c|<=2) escapes immediately", MandelbrotEscapeIterations[2.1, 100] <= 2];
AssertTrue["JuliaEscapeIterations at z0=0, c=0 never escapes", JuliaEscapeIterations[0.0, 0.0, 100] === 100];
AssertTrue["JuliaEscapeIterations at large z0 escapes immediately", JuliaEscapeIterations[10.0, 0.1, 100] <= 2];
Print[""];

(* ── Main cardioid boundary derivation ────────────────────────────── *)
Print["-- MainCardioidBoundary --"];
AssertTrue["c(theta) matches the symbolic derivation z-z^2 at z=Exp[I theta]/2, several theta",
  Module[{thetas = {0.3, 1.0, 2.0, 4.0}, results},
    results = Table[
      Module[{z = Exp[I*th]/2.0, cDirect, cFormula},
        cDirect = z - z^2;
        cFormula = MainCardioidBoundary[th];
        Abs[cDirect - cFormula] < 10^-9
      ],
      {th, thetas}
    ];
    AllTrue[results, TrueQ]]];
AssertTrue["MainCardioidPointFromR at r=0.5 matches MainCardioidBoundary (same curve)",
  Abs[MainCardioidPointFromR[0.5, 1.3] - MainCardioidBoundary[1.3]] < 10^-9];
AssertTrue["cusp point c=-0.75 at theta=Pi", Abs[MainCardioidBoundary[Pi] - (-0.75)] < 10^-9];
Print[""];

(* ── GridToComplex ─────────────────────────────────────────────────── *)
Print["-- GridToComplex --"];
AssertTrue["col=1,row=1 maps to (reMin,imMin)",
  GridToComplex[1, 1, 64, -2.0, 0.5, -1.25, 1.25] === (-2.0 - 1.25*I)];
AssertTrue["col=size,row=size maps to (reMax,imMax)",
  Abs[GridToComplex[64, 64, 64, -2.0, 0.5, -1.25, 1.25] - (0.5 + 1.25*I)] < 10^-9];
Print[""];

(* ── The four correctness checks, run directly ────────────────────── *)
Print["-- Correctness checks --"];
AssertTrue["EscapeRadiusCheck passes", EscapeRadiusCheck[]["pass"]];
AssertTrue["MembershipFactsCheck passes", MembershipFactsCheck[]["pass"]];
AssertTrue["MainCardioidBoundaryCheck passes", MainCardioidBoundaryCheck[]["pass"]];
AssertTrue["BoundaryComplexityCheck passes", BoundaryComplexityCheck[]["pass"]];
Print[""];

(* ── Julia default c verification ─────────────────────────────────── *)
Print["-- Julia default c --"];
AssertTrue["default Julia c is genuinely inside the Mandelbrot set (bounded to 20000 iterations)",
  MandelbrotEscapeIterations[$juliaDefaultCRe + I*$juliaDefaultCIm, 20000] === 20000];
AssertTrue["default Julia c is safely interior: small perturbations remain bounded too",
  Module[{c = $juliaDefaultCRe + I*$juliaDefaultCIm, perts = {0.001, -0.001, 0.001*I, -0.001*I}},
    AllTrue[perts, MandelbrotEscapeIterations[c + #, 5000] === 5000 &]]];
AssertTrue["the commonly-cited -0.7+0.27015i is verified OUTSIDE the set (rejected as default for this reason)",
  MandelbrotEscapeIterations[-0.7 + 0.27015*I, 20000] < 20000];
Print[""];

(* ── Zoom centre verification ─────────────────────────────────────── *)
Print["-- Zoom centre --"];
AssertTrue["zoom centre is on/near the Mandelbrot boundary (slow to escape, not trivially fast)",
  MandelbrotEscapeIterations[$zoomDefaultCRe + I*$zoomDefaultCIm, 2000] > 500];
Print[""];

(* ── Model builders ───────────────────────────────────────────────── *)
Print["-- Model builders --"];
Module[{mm = MandelbrotModel[<||>]},
  AssertTrue["MandelbrotModel iterField has nPixels entries", Length[mm["iterField"]] === mm["nPixels"]];
  AssertTrue["MandelbrotModel iterField values all in [1,maxIter]",
    AllTrue[mm["iterField"], 1 <= # <= mm["maxIter"] &]];
  AssertTrue["MandelbrotModel finds a nontrivial fraction inside the set",
    0.05 < N[Count[mm["iterField"], mm["maxIter"]] / mm["nPixels"]] < 0.6];
];
Module[{jm = JuliaModel[<||>]},
  AssertTrue["JuliaModel iterField has nPixels entries", Length[jm["iterField"]] === jm["nPixels"]];
  AssertTrue["JuliaModel cIsInterior is True for the default c", jm["cIsInterior"]];
];
Module[{zm = ZoomModel[<||>]},
  AssertTrue["ZoomModel has nLevels level entries", Length[zm["levels"]] === zm["nLevels"]];
  AssertTrue["ZoomModel half-widths shrink by 4x per level",
    Module[{hws = zm["levels"][[All, "halfWidth"]]},
      AllTrue[Range[2, Length[hws]], Abs[hws[[#-1]]/hws[[#]] - 4.0] < 10^-9 &]]];
  AssertTrue["ZoomModel every level's iterField has nPixels entries",
    AllTrue[zm["levels"], Length[#["iterField"]] === zm["nPixels"] &]];
];
Print[""];

Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

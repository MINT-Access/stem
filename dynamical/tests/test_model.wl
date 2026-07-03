#!/usr/bin/env wolframscript

(* dynamical/tests/test_model.wl — Unit tests for the logistic map model *)

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

Print["=== dynamical/src/model.wl unit tests ==="];
Print[""];

(* ── LogisticMap basics ──────────────────────────────────────────── *)
Print["-- LogisticMap --"];
AssertTrue["F[0.5, 4] = 1.0", Abs[LogisticMap[0.5, 4.0] - 1.0] < 10^-9];
AssertTrue["F[0, r] = 0 for any r",  LogisticMap[0.0, 3.5] === 0.0];
AssertTrue["F[1, r] = 0 for any r",  LogisticMap[1.0, 3.5] === 0.0];
Print[""];

(* ── SafeX0 ───────────────────────────────────────────────────────── *)
Print["-- SafeX0 --"];
AssertTrue["SafeX0 nudges exact 0.5", SafeX0[0.5] =!= 0.5];
AssertTrue["SafeX0 nudge is small (<1e-4)", Abs[SafeX0[0.5] - 0.5] < 10^-4];
AssertTrue["SafeX0 leaves other values unchanged", SafeX0[0.3] === 0.3];
Print[""];

(* ── Fixed-point formula (r = 2.8) ───────────────────────────────────
   Required: verify 1 - 1/r matches the iterated value to within 1e-6. *)
Print["-- Fixed-point formula (r=2.8) --"];
Module[{r = 2.8, attractor, xstar, err},
  attractor = AttractorPoints[0.5, r, 200, 50];
  xstar     = 1.0 - 1.0/r;
  err       = Max[Abs[attractor - xstar]];
  AssertTrue["all attractor points within 1e-6 of 1 - 1/r", err < 10^-6];
  AssertTrue["FixedPointCheck[] agrees", FixedPointCheck[2.8]["pass"]];
];
Print[""];

(* ── Period-2 values (r = 3.2) ───────────────────────────────────────
   Required: the two attractor values sum to (r+1)/r. *)
Print["-- Period-2 values (r=3.2) --"];
Module[{r = 3.2, attractor, distinct, sum, expected},
  attractor = AttractorPoints[0.5, r, 200, 100];
  distinct  = DeleteDuplicates[Round[attractor, 10^-4]];
  AssertTrue["exactly 2 distinct attractor values", Length[distinct] === 2];
  sum      = Total[distinct];
  expected = (r + 1.0) / r;
  AssertTrue["the two values sum to (r+1)/r = " <> ToString[expected],
    Abs[sum - expected] < 10^-3];
  AssertTrue["Period2Check[] agrees", Period2Check[3.2]["pass"]];
];
Print[""];

(* ── Feigenbaum check ─────────────────────────────────────────────── *)
Print["-- Feigenbaum constant check --"];
Module[{fc},
  fc = FeigenbaumCheck[];
  Print["  r1 = ", FmtN[fc["r1"], 6], "   r2 = ", FmtN[fc["r2"], 6],
        "   r3 = ", FmtN[fc["r3"], 6]];
  Print["  ratio = ", FmtN[fc["ratio"], 6], "   delta = ", FmtN[$FeigenbaumConstant, 6],
        "   error = ", FmtN[fc["relError"] * 100, 4], "%"];
  AssertTrue["r1 is close to the known value 3.0", Abs[fc["r1"] - 3.0] < 0.01];
  AssertTrue["r2 is close to the known value 3.449", Abs[fc["r2"] - 3.449] < 0.01];
  AssertTrue["r3 is close to the known value 3.544", Abs[fc["r3"] - 3.544] < 0.01];
  AssertTrue["ratio within 5% of the Feigenbaum constant", fc["pass"]];
];
Print[""];

(* ── Lyapunov exponent (r = 4.0) ─────────────────────────────────────
   Required: within 5% of log(2). *)
Print["-- Lyapunov exponent (r=4.0) --"];
Module[{lc},
  lc = LyapunovCheck[];
  Print["  lambda = ", FmtN[lc["lambda"], 6], "   log(2) = ", FmtN[lc["expected"], 6],
        "   error = ", FmtN[lc["relError"] * 100, 4], "%"];
  AssertTrue["lambda is positive (signature of chaos)", lc["lambda"] > 0];
  AssertTrue["lambda within 5% of log(2)", lc["pass"]];
];
Print[""];

(* ── Presets ──────────────────────────────────────────────────────── *)
Print["-- Presets --"];
AssertTrue["fixed_point preset resolves to r=2.8", PresetR["fixed_point", 999] === 2.8];
AssertTrue["period2 preset resolves to r=3.2",     PresetR["period2", 999] === 3.2];
AssertTrue["period4 preset resolves to r=3.5",      PresetR["period4", 999] === 3.5];
AssertTrue["chaos preset resolves to r=4.0",        PresetR["chaos", 999] === 4.0];
AssertTrue["unknown preset falls back to default",  PresetR["nonexistent", 3.14] === 3.14];
AssertTrue["empty preset falls back to default",    PresetR["", 3.14] === 3.14];
AssertTrue["preset description is non-empty for known preset",
  StringLength[PresetDescription["chaos"]] > 0];
AssertTrue["preset description is empty for unknown preset",
  PresetDescription["nonexistent"] === ""];
Print[""];

(* ── SweepModel / IterateModelData shape ─────────────────────────── *)
Print["-- SweepModel --"];
Module[{sm},
  sm = SweepModel[2.5, 4.0, 20, 0.5, 50, 10];
  AssertTrue["rValues has 20 entries", Length[sm["rValues"]] === 20];
  AssertTrue["attractors has 20 entries", Length[sm["attractors"]] === 20];
  AssertTrue["each attractor has 10 points", Length[sm["attractors"][[1]]] === 10];
  AssertTrue["rValues starts at r_start", sm["rValues"][[1]] === 2.5];
  AssertTrue["rValues ends at r_end", Last[sm["rValues"]] === 4.0];
];
Print[""];

Print["-- IterateModelData --"];
Module[{im},
  im = IterateModelData[3.5, 0.5, 50, "period4"];
  AssertTrue["trajectory has 51 entries (x0 plus 50 iterations)",
    Length[im["trajectory"]] === 51];
  AssertTrue["r is stored correctly", im["r"] === 3.5];
  AssertTrue["preset is stored correctly", im["preset"] === "period4"];
];
Print[""];

(* ── SweepEventRValues ─────────────────────────────────────────────── *)
Print["-- SweepEventRValues --"];
Module[{ev},
  ev = SweepEventRValues[];
  AssertTrue["first_bifurcation close to 3.0", Abs[ev["first_bifurcation"] - 3.0] < 0.01];
  AssertTrue["chaos_onset in (3.5, 3.6)", 3.5 < ev["chaos_onset"] < 3.6];
  AssertTrue["period3_window in (3.8, 3.85)", 3.8 < ev["period3_window"] < 3.85];
];
Print[""];

Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

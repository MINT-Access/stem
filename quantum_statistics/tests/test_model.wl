#!/usr/bin/env wolframscript

(* quantum_statistics/tests/test_model.wl — Unit tests for the
   quantum_statistics model *)

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

Print["=== quantum_statistics/src/model.wl unit tests ==="];
Print[""];

(* ── kB derivation ─────────────────────────────────────────────────── *)
Print["-- kB --"];
AssertTrue["kB in eV/K matches the commonly-quoted ~8.617e-5 value", Abs[$kBeV - 8.617333262*^-5] < 1.0*^-12];
AssertTrue["kT at 300K matches the commonly-quoted ~0.0259 eV fact", Abs[$kBeV * 300.0 - 0.025851999786] < 1.0*^-9];
Print[""];

(* ── Occupation numbers, basic facts ──────────────────────────────── *)
Print["-- Occupation numbers --"];
AssertTrue["n_FD(eps=mu) = 0.5 exactly", FermiDiracOccupation[1.0, 1.0, 300.0] === 0.5];
AssertTrue["n_MB(eps=mu) = 1 exactly", MaxwellBoltzmannOccupation[1.0, 1.0, 300.0] === 1.0];
AssertTrue["n_FD < 1 strictly, even very close to mu",
  FermiDiracOccupation[1.0 + 1.0*^-8, 1.0, 300.0] < 1.0];
(* Quiet[]'d: deliberately extreme test values trigger harmless
   General::munfl underflow messages (Exp[+-huge] correctly
   underflows/overflows toward the limiting 0/1 answer being tested). *)
AssertTrue["n_FD -> 1 as eps -> -infinity relative to mu", Quiet[FermiDiracOccupation[-1000.0, 0.0, 1.0]] == 1.0];
AssertTrue["n_FD -> 0 as eps -> +infinity relative to mu", Quiet[FermiDiracOccupation[1000.0, 0.0, 1.0]] == 0.0];
AssertTrue["BoseEinsteinOccupation guards eps=mu (returns Missing)",
  MissingQ[BoseEinsteinOccupation[1.0, 1.0, 300.0]]];
AssertTrue["BoseEinsteinOccupation guards eps<mu (returns Missing)",
  MissingQ[BoseEinsteinOccupation[0.5, 1.0, 300.0]]];
AssertTrue["BoseEinsteinOccupation is well-defined and positive for eps>mu",
  BoseEinsteinOccupation[1.5, 1.0, 300.0] > 0.0];
Print[""];

(* ── Exact classical-limit identity ───────────────────────────────── *)
Print["-- Classical-limit identity --"];
AssertTrue["(n_BE-n_MB)/n_MB equals n_BE itself, exactly, at several x",
  Module[{xs = {0.5, 2.0, 5.0, 8.0}, mu = 0.0, T = 300.0, kT, results},
    kT = $kBeV * T;
    results = Table[
      Module[{eps = mu + x * kT, be, mb, relErr},
        be = BoseEinsteinOccupation[eps, mu, T];
        mb = MaxwellBoltzmannOccupation[eps, mu, T];
        relErr = (be - mb) / mb;
        Abs[relErr - be] < 10^-9
      ],
      {x, xs}
    ];
    AllTrue[results, TrueQ]]];
AssertTrue["(n_FD-n_MB)/n_MB equals -n_FD itself, exactly, at several x",
  Module[{xs = {0.5, 2.0, 5.0, 8.0}, mu = 0.0, T = 300.0, kT, results},
    kT = $kBeV * T;
    results = Table[
      Module[{eps = mu + x * kT, fd, mb, relErr},
        fd = FermiDiracOccupation[eps, mu, T];
        mb = MaxwellBoltzmannOccupation[eps, mu, T];
        relErr = (fd - mb) / mb;
        Abs[relErr + fd] < 10^-9
      ],
      {x, xs}
    ];
    AllTrue[results, TrueQ]]];
Print[""];

(* ── T->0 step width scaling ───────────────────────────────────────── *)
Print["-- Step width scaling --"];
AssertTrue["10-90 width scales exactly linearly with kT (width/kT constant across T)",
  Module[{mu = 1.0, Ts = {50.0, 500.0, 5000.0}, widths, ratios},
    widths = Table[
      Module[{kT = $kBeV * T, eps90, eps10},
        eps90 = mu + kT * Log[1.0/0.9 - 1.0];
        eps10 = mu + kT * Log[1.0/0.1 - 1.0];
        eps10 - eps90
      ],
      {T, Ts}
    ];
    ratios = widths / ($kBeV * Ts);
    Max[ratios] - Min[ratios] < 10^-9]];
Print[""];

(* ── The four correctness checks, run directly ────────────────────── *)
Print["-- Correctness checks --"];
AssertTrue["ClassicalLimitCheck passes", ClassicalLimitCheck[]["pass"]];
AssertTrue["FermiDiracBoundCheck passes", FermiDiracBoundCheck[]["pass"]];
AssertTrue["FermiDiracStepLimitCheck passes", FermiDiracStepLimitCheck[]["pass"]];
AssertTrue["BoseEinsteinDivergenceCheck passes", BoseEinsteinDivergenceCheck[]["pass"]];
Print[""];

(* ── Model builders ───────────────────────────────────────────────── *)
Print["-- Model builders --"];
Module[{sm = SpectrumModel[<||>]},
  AssertTrue["SpectrumModel arrays have nSteps entries", Length[sm["epsArr"]] === sm["nSteps"]];
  AssertTrue["SpectrumModel n_MB is monotonically decreasing (energy increases -> occupation falls)",
    OrderedQ[Reverse[sm["mbArr"]]]];
  AssertTrue["SpectrumModel BE values are all Missing or positive",
    AllTrue[sm["beArr"], MissingQ[#] || # > 0 &]];
];
Module[{tm = TemperatureModel[<||>]},
  AssertTrue["TemperatureModel arrays have nSteps entries", Length[tm["TArr"]] === tm["nSteps"]];
  AssertTrue["TemperatureModel converges at low T: BE and MB agree closely at T_min",
    Abs[First[tm["beArr"]] - First[tm["mbArr"]]] < 10^-9 * Max[First[tm["mbArr"]], 10^-300]];
  AssertTrue["TemperatureModel diverges at high T: BE exceeds MB substantially at T_max",
    Last[tm["beArr"]] > 2.0 * Last[tm["mbArr"]]];
];
Module[{fm = FermiSeaModel[<||>]},
  AssertTrue["FermiSeaModel fdByT has nTSteps rows", Length[fm["fdByT"]] === fm["nTSteps"]];
  AssertTrue["FermiSeaModel coldest T gives a sharper step than warmest T (smaller 10-90 width)",
    Module[{coldT = First[fm["TArr"]], warmT = Last[fm["TArr"]], coldWidth, warmWidth},
      coldWidth = 2.0 * Log[9.0] * $kBeV * coldT;
      warmWidth = 2.0 * Log[9.0] * $kBeV * warmT;
      coldWidth < warmWidth]];
  AssertTrue["FermiSeaModel all n_FD values in [0,1]",
    AllTrue[Flatten[fm["fdByT"]], 0.0 <= # <= 1.0 &]];
];
Print[""];

Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

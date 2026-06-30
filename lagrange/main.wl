#!/usr/bin/env wolframscript

(* ========================================================
   Lagrange Points — main.wl

   Simulates test-particle motion in the circular restricted
   three-body problem (CR3BP) in the co-rotating frame.

   Units: total mass = 1, primary separation = 1,
          angular velocity omega_0 = 1  (one orbit = 2pi time units).
   mu = m2/(m1+m2) is the mass parameter (small body fraction).

   Modes:
     l4  -- stable tadpole/horseshoe libration near L4 (default)
     l5  -- same at L5 (symmetric counterpart)
     l1  -- unstable saddle escape from L1

   Presets (--simulation.lagrange.preset):
     sun_jupiter  -- mu = 0.000954  (default)
     earth_moon   -- mu = 0.01215
     sun_earth    -- mu = 3.003e-6

   CLI examples:
     wolframscript -file main.wl -- --simulation.mode=l1
     wolframscript -file main.wl -- --simulation.lagrange.preset=earth_moon
     wolframscript -file main.wl -- --simulation.lagrange.perturbation=0.05
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];

$rawArgs = Select[Rest[$ScriptCommandLine], # =!= "--" &];
$cliArgs = Module[{result = {}, i = 1, arg, next},
  While[i <= Length[$rawArgs],
    arg = $rawArgs[[i]];
    If[StringStartsQ[arg, "--"] && !StringContainsQ[arg, "="] &&
       arg =!= "--config-dump" &&
       i < Length[$rawArgs] &&
       !StringStartsQ[$rawArgs[[i + 1]], "--"],
      next = $rawArgs[[i + 1]];
      AppendTo[result, arg <> "=" <> next];
      i += 2,
      AppendTo[result, arg];
      i += 1
    ]
  ];
  result
];

cfg  = LoadConfig["lagrange", $cliArgs];
mode = GetCfg[cfg, {"simulation","mode"}, "l4"];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

(* ── Preset resolution ──────────────────────────────────────────── *)
$presets = <|
  "sun_jupiter" -> 0.000954,
  "earth_moon"  -> 0.012151,
  "sun_earth"   -> 3.003*^-6
|>;

Module[{preset, muFromPreset},
  preset = GetCfg[cfg, {"simulation","lagrange","preset"}, "sun_jupiter"];
  If[StringQ[preset] && preset =!= "" && KeyExistsQ[$presets, preset],
    muFromPreset = $presets[preset];
    cfg = DeepMerge[cfg, <|"simulation" -> <|"lagrange" -> <|"mass_ratio" -> muFromPreset|>|>|>];
    Print["  Preset: ", preset, "  mu = ", muFromPreset]
  ]
];

(* ── Physical parameters ────────────────────────────────────────── *)
$mu      = N @ GetCfg[cfg, {"simulation","lagrange","mass_ratio"},      0.000954];
$pert    = N @ GetCfg[cfg, {"simulation","lagrange","perturbation"},    0.02    ];
$durP    =     GetCfg[cfg, {"simulation","lagrange","duration_periods"}, 6      ];
$presetLabel = GetCfg[cfg, {"simulation","lagrange","preset"},          "sun_jupiter"];

(* ── Find Lagrange points (uses $mu set above) ──────────────────── *)
Print["Finding Lagrange point positions..."];
$lpts  = FindLagrangePoints[];
$c2Pass = GeometryCheck[$lpts];
Print[""];

(* ── Mode dispatch ──────────────────────────────────────────────── *)
Which[

  mode === "l4" || mode === "l5",
  With[{lLabel = ToUpperCase[mode]},

    STEMHeading["Lagrange Points: CR3BP " <> lLabel <> " Libration"];
    Print["  mu = ", FmtN[$mu, {8,6}], "   perturbation = ", $pert, " units"];
    Print["  Integration duration: ", $durP, " orbital periods (",
          FmtN[N[$durP * 2 * Pi], {5,2}], " time units)"];
    Print["  ", lLabel, " position: (",
          FmtN[$lpts[lLabel][[1]], {7,5}], ", ",
          FmtN[$lpts[lLabel][[2]], {7,5}], ")"];
    Print[""];

    Print["[1/5] Integrating CR3BP equations of motion..."];
    STEMSay["Integrating trajectory near Lagrange point " <> lLabel];
    model = LibrationModel[mode, $lpts, $c2Pass, cfg];
    Print[""];

    Print["[2/5] Sanity checks..."];
    Print["  Checks: ",
      If[model["c1Pass"], "1[PASS]", "1[FAIL]"], " ",
      If[model["c2Pass"], "2[PASS]", "2[FAIL]"], " ",
      If[model["c3Pass"], "3[PASS]", "3[FAIL]"], " ",
      If[model["c4Pass"], "4[PASS]", "4[FAIL]"]];
    Print[""];

    Print["[3/5] Exporting CSV..."];
    ExportLibrationTrajectory[model, FileNameJoin[{$outDir, mode <> "_trajectory.csv"}]];
    Print[""];

    Print["[4/5] Rendering PNG and GIF..."];
    STEMSay["Rendering trajectory animation"];
    AnimateLibration[model, $outDir, $lpts, $mu, $presetLabel];
    Print[""];

    Print["[5/5] Sonifying trajectory..."];
    STEMSay["Sonifying " <> lLabel <> " libration: pitch from angular velocity, pan from x-position"];
    SonifyLibration[model, mode, cfg, FileNameJoin[{$outDir, mode <> "_audio.wav"}]];
    Print[""];

    STEMHeading["Done"];
    STEMSay[
      lLabel <> " libration complete. " <>
      "Mass parameter mu = " <> ToString[NumberForm[$mu, {6,5}]] <> ". " <>
      "Duration: " <> ToString[$durP] <> " orbital periods. " <>
      "Particle stayed within " <>
      ToString[NumberForm[model["maxDist"], {4,3}]] <> " units of " <> lLabel <>
      " (bounded stable libration). " <>
      "Jacobi drift: " <>
      If[model["jacRel"] * 100 < 0.001, "< 0.001",
         ToString[NumberForm[model["jacRel"] * 100, {4,2}]]] <> "%. " <>
      "Play audio: " <> STEMPlayCmd[FileNameJoin[{$outDir, mode <> "_audio.wav"}]]
    ]
  ],

  mode === "l1",

    STEMHeading["Lagrange Points: CR3BP L1 Saddle Point (Unstable Escape)"];
    Print["  mu = ", FmtN[$mu, {8,6}], "   perturbation = ", $pert, " units"];
    Print["  L1 position: (", FmtN[$lpts["L1"][[1]], {7,5}], ", 0)"];
    Print["  Integration limit: ", FmtN[N[3 * 2 * Pi], {5,2}],
          " time units (stops earlier on escape)"];
    Print[""];

    Print["[1/5] Integrating CR3BP equations of motion (escape expected)..."];
    STEMSay["Integrating L1 escape trajectory"];
    model = EscapeModel[$lpts, $c2Pass, cfg];
    Print[""];

    Print["[2/5] Sanity checks..."];
    Print["  Checks: ",
      If[model["c1Pass"], "1[PASS]", "1[FAIL]"], " ",
      If[model["c2Pass"], "2[PASS]", "2[FAIL]"], " ",
      If[model["c3Pass"], "3[PASS]", "3[FAIL]"], " ",
      If[model["c4Pass"], "4[PASS]", "4[WARN]"]];
    Print[""];

    Print["[3/5] Exporting CSV..."];
    ExportEscapeTrajectory[model, FileNameJoin[{$outDir, "l1_trajectory.csv"}]];
    Print[""];

    Print["[4/5] Rendering PNG and GIF..."];
    STEMSay["Rendering L1 escape animation"];
    AnimateEscape[model, $outDir, $lpts, $mu, $presetLabel];
    Print[""];

    Print["[5/5] Sonifying escape trajectory..."];
    STEMSay["Sonifying L1 escape: rising pitch and fading volume as particle departs"];
    SonifyEscape[model, cfg, FileNameJoin[{$outDir, "l1_audio.wav"}]];
    Print[""];

    STEMHeading["Done"];
    STEMSay[
      "L1 escape complete. " <>
      "Mass parameter mu = " <> ToString[NumberForm[$mu, {6,5}]] <> ". " <>
      "Integration ran " <> ToString[NumberForm[model["tActual"], {5,3}]] <> " time units. " <>
      "Distance grew by factor " <> ToString[NumberForm[model["distGrowth"], {4,1}]] <> ". " <>
      "Jacobi drift: " <>
      If[model["jacRel"] * 100 < 0.001, "< 0.001",
         ToString[NumberForm[model["jacRel"] * 100, {4,2}]]] <> "%. " <>
      "Play audio: " <> STEMPlayCmd[FileNameJoin[{$outDir, "l1_audio.wav"}]]
    ],

  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" -- expected \"l4\", \"l5\", or \"l1\"."];
    Exit[1]
]

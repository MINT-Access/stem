#!/usr/bin/env wolframscript

(* ========================================================
   experiments.wl — Quantum mechanics parameter experiments

   Run all experiments:
     wolframscript -file experiments.wl

   Each experiment writes density GIF, snapshot PNG, time-series CSV,
   and audio WAV to output/ so results can be compared directly.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];


(* --- Helper: run one QHO or Box experiment --- *)

RunQuantumExperiment[name_String, label_String, modelFn_, cfg_Association] :=
  Module[{solution, traj, csvPath},
    Print[""];
    Print[">>> Experiment: ", name, "  — ", label];

    solution = modelFn[cfg];
    STEMPrintN["Mean energy", solution["mean_energy"], "(natural units)", {6,4}];
    Print["  Timesteps:   ", Length[solution["t"]]];
    Print["  Norm OK:     ", If[solution["norm_ok"], "yes", "WARNING"]];

    traj    = DensityToTrajectory[solution];
    csvPath = FileNameJoin[{$outDir, name <> "_timeseries.csv"}];
    ExportCSV[
      Join[
        {{"t", "mean_x", "variance_x", "speed"}},
        Map[{#[[1]], #[[2]], #[[3]], #[[5]]} &, traj]
      ],
      csvPath];
    Print["    CSV -> ", csvPath];

    AnimateQuantum[solution, cfg, $outDir];
    SonifyQuantum[solution, cfg, $outDir];
    Print["    GIF/WAV in output/", solution["mode"], "_*"]
  ]


(* ================================================================
   EXPERIMENT DEFINITIONS
   ================================================================ *)

(* --- qho_coherent: default coherent state, alpha=2, one full period --- *)
(* The default QHO run. alpha=2 means mean energy <E>=4.5.
   The wave packet oscillates cleanly at frequency omega=1, returning
   to its initial shape after time T = 2*pi. Sonification: smooth
   periodic pitch variation mimicking a sine wave. *)
RunQuantumExperiment["qho", "Default coherent state: alpha=2, one period",
  QHOModel,
  <| "simulation" -> <|
    "mode" -> "qho",
    "qho" -> <|
      "alpha"    -> 2.0,
      "omega"    -> 1.0,
      "n_modes"  -> 20,
      "x_range"  -> {-8.0, 8.0},
      "n_points" -> 200,
      "duration" -> 6.28318,
      "timestep" -> 0.05
    |>
  |>,
  "sonification" -> <| "pitch" -> <| "min_hz" -> 110, "max_hz" -> 880 |> |> |>
];


(* --- qho_tight: alpha=1, smaller oscillation amplitude --- *)
(* A more tightly bound coherent state. alpha=1 gives <E>=1.5.
   The packet travels a smaller range in position space — the sonification
   pitch variation is compressed into a narrower band. *)
RunQuantumExperiment["qho", "Tight coherent state: alpha=1",
  QHOModel,
  <| "simulation" -> <|
    "mode" -> "qho",
    "qho" -> <|
      "alpha"    -> 1.0,
      "omega"    -> 1.0,
      "n_modes"  -> 15,
      "x_range"  -> {-6.0, 6.0},
      "n_points" -> 200,
      "duration" -> 6.28318,
      "timestep" -> 0.05
    |>
  |>,
  "sonification" -> <| "pitch" -> <| "min_hz" -> 110, "max_hz" -> 880 |> |> |>
];


(* --- box_low: particle in a box, ground+first excited state --- *)
(* The standard superposition: (phi_1 + phi_2)/sqrt(2).
   The probability density oscillates back and forth between the left
   and right halves of the box at the Bohr frequency (E_2 - E_1).
   Sonification: pan oscillates left/right in sync with the density sloshing. *)
RunQuantumExperiment["box", "Standard box superposition: phi_1 + phi_2",
  BoxModel,
  <| "simulation" -> <|
    "mode" -> "box",
    "box" -> <|
      "L"        -> 10.0,
      "n_modes"  -> 10,
      "n_points" -> 200,
      "duration" -> 20.0,
      "timestep" -> 0.05
    |>
  |>,
  "sonification" -> <| "pitch" -> <| "min_hz" -> 110, "max_hz" -> 880 |> |> |>
];


(* --- box_superposition: wider box — lower Bohr frequency, slower oscillation --- *)
(* A larger box L=20 has smaller energy spacings (E_n ~ 1/L^2), so the
   probability density oscillates more slowly. The audio has a distinctly
   lower beat frequency. *)
RunQuantumExperiment["box", "Wide box: L=20, slower oscillation",
  BoxModel,
  <| "simulation" -> <|
    "mode" -> "box",
    "box" -> <|
      "L"        -> 20.0,
      "n_modes"  -> 10,
      "n_points" -> 200,
      "duration" -> 80.0,
      "timestep" -> 0.2
    |>
  |>,
  "sonification" -> <| "pitch" -> <| "min_hz" -> 110, "max_hz" -> 880 |> |> |>
];


(* --- box_spread: very wide box — energy levels nearly continuous --- *)
(* L=50 pushes the discrete energy levels so close together that the
   superposition looks almost like a free-particle wave packet.
   The variance oscillation becomes very slow; the audio sounds like a
   deep, barely-fluctuating tone. *)
RunQuantumExperiment["box", "Very wide box: L=50, near-continuum",
  BoxModel,
  <| "simulation" -> <|
    "mode" -> "box",
    "box" -> <|
      "L"        -> 50.0,
      "n_modes"  -> 10,
      "n_points" -> 200,
      "duration" -> 500.0,
      "timestep" -> 1.0
    |>
  |>,
  "sonification" -> <| "pitch" -> <| "min_hz" -> 110, "max_hz" -> 880 |> |> |>
];


Print[""];
Print["=== All experiments complete. Files are in output/ ==="];

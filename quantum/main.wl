#!/usr/bin/env wolframscript

(* ========================================================
   Quantum Mechanics — Entry Point

   Usage:
     wolframscript -file main.wl [-- [--key=value ...]]
     wolframscript -file main.wl -- --config-dump
     wolframscript -file main.wl -- --simulation.mode=qho
     wolframscript -file main.wl -- --simulation.mode=box
     wolframscript -file main.wl -- --simulation.qho.alpha=3.0
     wolframscript -file main.wl -- --simulation.mode qho   (space form also accepted)

   Modes:
     qho — coherent state in a quantum harmonic oscillator (hbar=m=1)
     box — (phi_1 + phi_2)/sqrt(2) superposition in a particle-in-a-box
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

(* Pre-process CLI args: convert "--key value" pairs to "--key=value"
   so both conventions work (ParseCliOverrides in stem-core requires =). *)
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

cfg  = LoadConfig["quantum", $cliArgs];
mode = GetCfg[cfg, {"simulation","mode"}, "qho"];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

Which[

  (* ══════════════════════════════════════════════════════
     QHO MODE — Quantum Harmonic Oscillator
     ══════════════════════════════════════════════════════ *)
  mode === "qho",

    With[{
      alpha  = GetCfg[cfg, {"simulation","qho","alpha"},    2.0],
      omega  = GetCfg[cfg, {"simulation","qho","omega"},    1.0],
      nModes = GetCfg[cfg, {"simulation","qho","n_modes"},  20],
      dur    = GetCfg[cfg, {"simulation","qho","duration"}, 12.56637]
    },
    STEMHeading["Quantum Mechanics: Harmonic Oscillator (Coherent State)"];
    Print["  Coherent amplitude alpha:   ", FmtN[alpha, {4,2}]];
    Print["  Oscillator frequency omega: ", FmtN[omega, {4,2}]];
    Print["  Basis modes: ", nModes];
    Print["  Duration:    ", FmtN[dur, {6,3}], " (natural units)"];
    Print[""]];

    Print["[1/4] Solving time evolution..."];
    STEMSay["Solving quantum harmonic oscillator"];
    solution = QHOModel[cfg];
    STEMPrintN["Mean energy", solution["mean_energy"], "(natural units)", {5,3}];
    Print["  Timesteps:   ", Length[solution["t"]]];
    Print["  Grid points: ", Length[solution["x"]]];
    If[solution["norm_ok"],
      Print["  Normalisation: OK (all sampled norms within 1%)"],
      Print["  Normalisation: WARNING — some norms outside 1%"]];
    Print[""];

    Print["[2/4] Exporting time-series CSV..."];
    With[{
      csvPath = FileNameJoin[{$outDir, "qho_timeseries.csv"}],
      traj    = DensityToTrajectory[solution]},
      ExportCSV[
        Join[
          {{"t", "mean_x", "variance_x", "speed"}},
          Map[{#[[1]], #[[2]], #[[3]], #[[5]]} &, traj]
        ],
        csvPath];
      STEMDescribeCSV[csvPath, Length[solution["t"]], 4]];
    Print[""];

    Print["[3/4] Rendering animation..."];
    STEMSay["Rendering quantum animation"];
    AnimateQuantum[solution, cfg, $outDir];
    Print[""];

    Print["[4/4] Sonifying..."];
    SonifyQuantum[solution, cfg, $outDir];
    Print[""];

    STEMHeading["Done"];
    STEMSay["Complete. Play audio: afplay " <>
      FileNameJoin[{$outDir, "qho_audio.wav"}]],


  (* ══════════════════════════════════════════════════════
     BOX MODE — Particle in a Box
     ══════════════════════════════════════════════════════ *)
  mode === "box",

    With[{
      L      = GetCfg[cfg, {"simulation","box","L"},        10.0],
      nModes = GetCfg[cfg, {"simulation","box","n_modes"},  10],
      dur    = GetCfg[cfg, {"simulation","box","duration"}, 20.0]
    },
    STEMHeading["Quantum Mechanics: Particle in a Box"];
    Print["  Box length L:   ", FmtN[L, {4,2}], " (natural units)"];
    Print["  Basis modes:    ", nModes];
    Print["  Initial state:  (phi_1 + phi_2) / sqrt(2)"];
    Print["  Duration:       ", FmtN[dur, {5,2}], " (natural units)"];
    Print[""]];

    Print["[1/4] Solving time evolution..."];
    STEMSay["Solving particle in a box"];
    solution = BoxModel[cfg];
    STEMPrintN["Mean energy", solution["mean_energy"], "(natural units)", {5,4}];
    Print["  Timesteps:   ", Length[solution["t"]]];
    Print["  Grid points: ", Length[solution["x"]]];
    If[solution["norm_ok"],
      Print["  Normalisation: OK (all sampled norms within 1%)"],
      Print["  Normalisation: WARNING — some norms outside 1%"]];
    Print[""];

    Print["[2/4] Exporting time-series CSV..."];
    With[{
      csvPath = FileNameJoin[{$outDir, "box_timeseries.csv"}],
      traj    = DensityToTrajectory[solution]},
      ExportCSV[
        Join[
          {{"t", "mean_x", "variance_x", "speed"}},
          Map[{#[[1]], #[[2]], #[[3]], #[[5]]} &, traj]
        ],
        csvPath];
      STEMDescribeCSV[csvPath, Length[solution["t"]], 4]];
    Print[""];

    Print["[3/4] Rendering animation..."];
    STEMSay["Rendering quantum animation"];
    AnimateQuantum[solution, cfg, $outDir];
    Print[""];

    Print["[4/4] Sonifying..."];
    SonifyQuantum[solution, cfg, $outDir];
    Print[""];

    STEMHeading["Done"];
    STEMSay["Complete. Play audio: afplay " <>
      FileNameJoin[{$outDir, "box_audio.wav"}]],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"qho\" or \"box\"."];
    Exit[1]
]

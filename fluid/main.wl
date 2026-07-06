#!/usr/bin/env wolframscript

(* ========================================================
   Karman Vortex Street — main.wl

   Simulates and sonifies vortex shedding behind a bluff body
   using a simplified discrete-vortex (vortex particle) method,
   making the Strouhal frequency -- the pitch a wire or flagpole
   sings in the wind -- directly audible.

   Three modes:
     karman   (default) -- Karman vortex street at a fixed Reynolds
                            number; periodic lift-force oscillation
                            sonified as a steady Strouhal tone plus
                            alternating shed-event clicks
     strouhal            -- sweeps Reynolds number from onset through
                            the laminar regime toward turbulence;
                            silence -> sudden tone -> broadening
     flag                 -- a flexible flag flapping in flow; the
                            flutter frequency pans left-right at the
                            flag's own flapping rate

   Usage:
     wolframscript -file fluid/main.wl
     wolframscript -file fluid/main.wl -- --simulation.mode=strouhal
     wolframscript -file fluid/main.wl -- --simulation.mode=flag
     wolframscript -file fluid/main.wl -- --simulation.fluid.Re=80
     wolframscript -file fluid/main.wl -- --simulation.fluid.Re=250
     wolframscript -file fluid/main.wl -- --simulation.fluid.audio_freq_target=440
     wolframscript -file fluid/main.wl -- --simulation.fluid.flag_length=10.0
     wolframscript -file fluid/main.wl -- --simulation.fluid.duration=80
     wolframscript -file fluid/main.wl -- --config-dump

   New to this app? Start with fluid/LISTENING_GUIDE.md.

   Outputs (fluid/output/):
     karman_audio.wav   / karman.gif   / karman_data.csv
     strouhal_audio.wav / strouhal.gif / strouhal_data.csv
     flag_audio.wav     / flag.gif     / flag_data.csv

   Educational approximation, not a CFD tool: the wake is modelled
   as a handful of discrete point vortices shed at the Strouhal
   frequency and advected by mutual Biot-Savart induction -- this
   reproduces the correct shedding frequency and the alternating
   staggered-row structure, but is not a Navier-Stokes solver (no
   viscous core diffusion, no resolved boundary layer). See
   fluid/README.md and fluid/AGENTS.md for the full list of
   simplifications.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];

(* ── CLI preprocessing ──────────────────────────────────────────── *)
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

cfg  = LoadConfig["fluid", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "karman"];

(* flag mode's own "duration" default (30) differs from config.json's
   single shared block (40, tuned for karman/strouhal's convective
   time units) -- same cross-mode-default pattern as magnetic's
   mirror v_perp/v_parallel; apply flag's own default only when the
   user has not explicitly overridden --simulation.fluid.duration. *)
If[mode === "flag" && !AnyTrue[$cliArgs, StringStartsQ[#, "--simulation.fluid.duration="] &],
  cfg = DeepMerge[cfg, <|"simulation" -> <|"fluid" -> <|"duration" -> 30.0|>|>|>]
];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

outWAV = FileNameJoin[{$outDir, mode <> "_audio.wav"}];
outGIF = FileNameJoin[{$outDir, mode <> ".gif"}];
outCSV = FileNameJoin[{$outDir, mode <> "_data.csv"}];

STEMHeading["Karman Vortex Street: " <> Capitalize[mode] <> " Mode"];
Print["  Mode: ", mode];
Print[""];

(* Checks 1-4 run and print regardless of mode -- all four are
   self-contained (each supplies its own reference parameters,
   matching dynamical/main.wl's precedent) and cheap. *)
STEMSection["Correctness checks (all modes)"];
$c1 = StrouhalFrequencyCheck[];
$c2 = OnsetReynoldsCheck[];
$c3 = StrouhalRangeCheck[];
$c4 = FlagFrequencyCheck[];
PrintFluidChecks[$c1, $c2, $c3, $c4];
Print[""];

STEMSay["Starting Karman vortex street sonification: " <> mode];

Which[

  (* ══════════════════════════════════════════════════════
     KARMAN MODE
     ══════════════════════════════════════════════════════ *)
  mode === "karman",

    STEMSection["Karman Vortex Street"];
    Print["  Reynolds number: ", FmtN[N @ GetCfg[cfg, {"simulation", "fluid", "Re"}, 150.0], {5,1}]];
    Print["  Freestream U:    ", FmtN[N @ GetCfg[cfg, {"simulation", "fluid", "U"}, 1.0], {4,2}]];
    Print["  Cylinder D:      ", FmtN[N @ GetCfg[cfg, {"simulation", "fluid", "D"}, 1.0], {4,2}]];
    Print["  Duration:        ", FmtN[N @ GetCfg[cfg, {"simulation", "fluid", "duration"}, 40.0], {5,1}], " (convective units, T=D/U)"];
    Print[""];

    Print["[1/4] Simulating vortex shedding (discrete-vortex method)..."];
    STEMSay["Simulating Karman vortex shedding"];
    model = KarmanModel[cfg];
    Print[""];

    Print["[2/4] Exporting data table..."];
    ExportKarmanCSV[model, outCSV];
    Print[""];

    Print["[3/4] Rendering vortex street animation..."];
    STEMSay["Rendering the vortex street animation"];
    AnimateKarman[model, $outDir];
    Print[""];

    Print["[4/4] Sonifying: Strouhal tone + lift oscillation + shed clicks..."];
    STEMSay["Sonifying: a steady tone at the Strouhal frequency, with clicks marking each vortex shed"];
    SonifyKarman[model, cfg, outWAV];
    Print[""];

    STEMHeading["Done"];
    STEMSay[
      "Karman vortex street complete. Reynolds number " <> ToString[NumberForm[model["Re"], {5,1}]] <>
      ". Shedding frequency " <> ToString[NumberForm[model["sim"]["fShed"], {5,4}]] <>
      " simulation units, mapped to " <> ToString[NumberForm[model["audioFreq"], {5,1}]] <>
      " hertz. Play audio: " <> STEMPlayCmd[outWAV]
    ],


  (* ══════════════════════════════════════════════════════
     STROUHAL MODE
     ══════════════════════════════════════════════════════ *)
  mode === "strouhal",

    STEMSection["Reynolds Number Sweep"];
    Print["  Re: ", FmtN[N @ GetCfg[cfg, {"simulation", "fluid", "Re_start"}, 20.0], {5,1}],
          " -> ", FmtN[N @ GetCfg[cfg, {"simulation", "fluid", "Re_end"}, 300.0], {5,1}],
          "  (", GetCfg[cfg, {"simulation", "fluid", "Re_steps"}, 50], " steps)"];
    Print[""];

    Print["[1/4] Sweeping Reynolds number and recording shedding onset..."];
    STEMSay["Sweeping Reynolds number from onset through the laminar regime"];
    model = StrouhalSweepModel[cfg];
    Print[""];

    Print["[2/4] Exporting data table..."];
    ExportStrouhalCSV[model, outCSV];
    Print[""];

    Print["[3/4] Rendering flow + Strouhal-curve animation..."];
    STEMSay["Rendering the flow and Strouhal curve animation"];
    AnimateStrouhal[model, $outDir];
    Print[""];

    Print["[4/4] Sonifying: silence, onset, then evolving tone..."];
    SonifyStrouhal[model, cfg, outWAV];
    Print[""];

    STEMHeading["Done"];
    STEMSay[
      "Strouhal sweep complete. Reynolds number ranged from " <>
      ToString[NumberForm[model["reStart"], {5,1}]] <> " to " <>
      ToString[NumberForm[model["reEnd"], {5,1}]] <> ". Play audio: " <> STEMPlayCmd[outWAV]
    ],


  (* ══════════════════════════════════════════════════════
     FLAG MODE
     ══════════════════════════════════════════════════════ *)
  mode === "flag",

    STEMSection["Flag Flutter"];
    Print["  Flag length:      ", FmtN[N @ GetCfg[cfg, {"simulation", "fluid", "flag_length"}, 5.0], {5,2}]];
    Print["  Freestream U:     ", FmtN[N @ GetCfg[cfg, {"simulation", "fluid", "U"}, 1.0], {4,2}]];
    Print["  Flag stiffness:   ", FmtN[N @ GetCfg[cfg, {"simulation", "fluid", "flag_stiffness"}, 0.1], {5,3}]];
    Print["  Duration:         ", FmtN[N @ GetCfg[cfg, {"simulation", "fluid", "duration"}, 30.0], {5,1}]];
    Print[""];

    Print["[1/4] Solving the damped-driven flag oscillator..."];
    STEMSay["Solving the flag flutter oscillator"];
    model = FlagModel[cfg];
    Print[""];

    Print["[2/4] Exporting data table..."];
    ExportFlagCSV[model, outCSV];
    Print[""];

    Print["[3/4] Rendering flag animation..."];
    STEMSay["Rendering the flag animation"];
    AnimateFlag[model, $outDir];
    Print[""];

    Print["[4/4] Sonifying: flutter tone panning with the flap..."];
    STEMSay["Sonifying the flag flutter: pitch and pan follow the tip, panning left and right with each flap"];
    SonifyFlag[model, cfg, outWAV];
    Print[""];

    STEMHeading["Done"];
    STEMSay[
      "Flag flutter complete. Flutter frequency " <>
      ToString[NumberForm[model["model"]["fFlag"], {5,4}]] <> ", mapped to " <>
      ToString[NumberForm[model["audioFreq"], {5,1}]] <> " hertz. Play audio: " <> STEMPlayCmd[outWAV]
    ],


  (* ══════════════════════════════════════════════════════
     UNKNOWN MODE
     ══════════════════════════════════════════════════════ *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" -- expected \"karman\", \"strouhal\", or \"flag\"."];
    Exit[1]
]

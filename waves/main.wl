#!/usr/bin/env wolframscript

(* ========================================================
   2D Wave Propagation — main.wl

   Simulates and sonifies 2D wave propagation using the
   finite element method (NDSolveValue on a spatial Region).

   Two modes:
     ripple       -- single Gaussian impulse on a circular membrane;
                     3-4 listening points at increasing radii reveal
                     the wavefront arriving later at each in sequence
     interference -- two coherent point sources in a rectangular tank;
                     a sweeping listening point crosses the fringe bands,
                     making constructive/destructive interference audible

   Usage:
     wolframscript -file waves/main.wl
     wolframscript -file waves/main.wl -- --simulation.mode=interference
     wolframscript -file waves/main.wl -- --simulation.waves.wave_speed=1.5
     wolframscript -file waves/main.wl -- --simulation.waves.source_frequency=3.0
     wolframscript -file waves/main.wl -- --simulation.waves.listening_points=6
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
       arg =!= "--config-dump" && i < Length[$rawArgs] &&
       !StringStartsQ[$rawArgs[[i + 1]], "--"],
      next = $rawArgs[[i + 1]];
      AppendTo[result, arg <> "=" <> next]; i += 2,
      AppendTo[result, arg]; i += 1]]; result];

cfg  = LoadConfig["waves", $cliArgs];
mode = GetCfg[cfg, {"simulation","mode"}, "ripple"];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

outWAV = FileNameJoin[{$outDir, mode <> "_audio.wav"}];
outCSV = FileNameJoin[{$outDir, mode <> "_data.csv"}];

$c     = N @ GetCfg[cfg, {"simulation","waves","wave_speed"},        1.0];
$r     = N @ GetCfg[cfg, {"simulation","waves","membrane_radius"},   1.0];
$tankW = N @ GetCfg[cfg, {"simulation","waves","tank_width"},        2.0];
$tankH = N @ GetCfg[cfg, {"simulation","waves","tank_height"},       1.0];
$freq  = N @ GetCfg[cfg, {"simulation","waves","source_frequency"},  2.0];
$tEnd  = N @ GetCfg[cfg, {"simulation","waves","duration"},          4.0];
$nLP   = GetCfg[cfg, {"simulation","waves","listening_points"},      4];

Which[

  mode === "ripple",
    STEMHeading["2D Wave Propagation: Ripple Mode"];
    Print["  Membrane radius:  ", FmtN[$r, {4,2}], " (units)"];
    Print["  Wave speed:       ", FmtN[$c, {4,2}], " (units/s)"];
    Print["  Duration:         ", FmtN[$tEnd, {4,2}], " s"];
    Print["  Listening points: ", $nLP];
    Print[""];

    Print["[1/4] Solving 2D wave equation on circular membrane (FEM)..."];
    STEMSay["Solving 2D wave equation -- circular membrane"];
    model = RippleModel[cfg];
    Print[""];

    Print["[2/4] Sonifying ", $nLP, " listening points..."];
    STEMSay["Sonifying wave propagation at listening points"];
    SonifyRipple[model, cfg, outWAV];
    Print[""];

    Print["[3/4] Exporting ripple animation..."];
    STEMSay["Rendering ripple animation"];
    AnimateRipple[model, $outDir];
    Print[""];

    Print["[4/4] Exporting data table (CSV)..."];
    ExportRippleData[model, outCSV];
    Print[""],

  mode === "interference",
    STEMHeading["2D Wave Propagation: Interference Mode"];
    Print["  Tank:          ", FmtN[$tankW, {4,2}], " x ", FmtN[$tankH, {4,2}], " (units)"];
    Print["  Wave speed:    ", FmtN[$c, {4,2}], " (units/s)"];
    Print["  Source freq:   ", FmtN[$freq, {4,2}], " Hz   (lambda = ",
          FmtN[$c/$freq, {4,2}], " units)"];
    Print["  Duration:      ", FmtN[$tEnd, {4,2}], " s"];
    Print[""];

    Print["[1/4] Solving wave equation with two coherent sources (FEM)..."];
    STEMSay["Solving interference wave equation"];
    model = InterferenceModel[cfg];
    Print[""];

    Print["[2/4] Sonifying moving listening point..."];
    STEMSay["Sonifying wave interference pattern"];
    SonifyInterference[model, cfg, outWAV];
    Print[""];

    Print["[3/4] Exporting interference animation..."];
    STEMSay["Rendering interference pattern animation"];
    AnimateInterference[model, $outDir];
    Print[""];

    Print["[4/4] Exporting data table (CSV)..."];
    ExportInterferenceData[model, outCSV];
    Print[""],

  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" -- expected \"ripple\" or \"interference\"."];
    Exit[1]

];

STEMHeading["Done"];
STEMSay["Wave simulation complete. Play audio: " <>
  STEMPlayCmd[FileNameJoin[{$outDir, mode <> "_audio.wav"}]]]

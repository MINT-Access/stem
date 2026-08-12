#!/usr/bin/env wolframscript

(* ========================================================
   Orbital Resonance — Entry Point

   Sonifies orbital resonance across the solar system: the exact
   4:2:1 Laplace resonance locking Jupiter's Galilean moons together,
   the Kirkwood gaps Jupiter clears in the asteroid belt, and the
   Cassini Division Mimas clears in Saturn's rings. Integer period
   ratios are where planetary mechanics and music theory meet most
   precisely -- a 2:1 orbital resonance IS a musical octave.

   Usage:
     wolframscript -file main.wl                                       # galilean, 8 Ganymede periods
     wolframscript -file main.wl -- --simulation.mode=kirkwood         # asteroid belt gaps
     wolframscript -file main.wl -- --simulation.mode=saturn           # Saturn ring structure
     wolframscript -file main.wl -- --simulation.resonance.n_periods=4    # shorter galilean
     wolframscript -file main.wl -- --simulation.resonance.n_periods=16   # longer, more repetitions
     wolframscript -file main.wl -- --simulation.resonance.gap_width_AU=0.02  # narrower Kirkwood gaps
     wolframscript -file main.wl -- --config-dump

   New to this app? Start with resonance/LISTENING_GUIDE.md.

   Modes:
     galilean (default) -- Io/Europa/Ganymede 4:2:1 Laplace resonance;
                           rhythmic canon (event layer) + constant
                           4:2:1-ratio drone (trajectory layer)
     kirkwood            -- asteroid belt density vs semi-major axis;
                           spectral chord, then a sweep with the
                           Kirkwood gaps audible as silences
     saturn              -- Saturn ring density vs orbital radius;
                           same chord+sweep, Cassini Division audible
                           as a distinct gap in the sweep

   Outputs (resonance/output/):
     galilean_audio.wav / galilean.gif / galilean_data.csv
     kirkwood_audio.wav / kirkwood.gif / kirkwood_data.csv
     saturn_audio.wav   / saturn.gif   / saturn_data.csv
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

cfg  = LoadConfig["resonance", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "galilean"];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

outWAV = FileNameJoin[{$outDir, mode <> "_audio.wav"}];
outGIF = FileNameJoin[{$outDir, mode <> ".gif"}];
outCSV = FileNameJoin[{$outDir, mode <> "_data.csv"}];

STEMHeading["Orbital Resonance: " <> Capitalize[mode]];
Print["  Mode: ", mode];
Print[""];

(* Checks 1-4 run and print regardless of mode -- all four are cheap
   closed-form evaluations, and every mode depends on at least one. *)
Print["-- Correctness checks (all modes) --"];
$checks = RunCorrectnessChecks[cfg];
Print[""];

STEMSay["Starting orbital resonance sonification: " <> mode];

Which[

  (* ══════════════════════════════════════════════════════
     GALILEAN MODE
     ══════════════════════════════════════════════════════ *)
  mode === "galilean",

    STEMSection["Galilean Moons: 4:2:1 Laplace Resonance"];
    Print[""];

    Print["[1/4] Simulating circular orbits..."];
    model = GalileanModel[cfg];
    Print[""];

    Print["[2/4] Exporting data table..."];
    ExportGalileanCSV[model, outCSV];
    Print[""];

    Print["[3/4] Rendering orbital animation..."];
    STEMSay["Rendering the Galilean moon orbital animation"];
    {nFrames, gifFps} = AnimateGalilean[model, outGIF, GalileanMainDurationSec[model]];
    STEMDescribeGIF[outGIF, nFrames, gifFps];
    Print[""];

    Print["[4/4] Sonifying: event canon (C3/C4/C5, 4:2:1 ratio) + trajectory drone..."];
    STEMSay["Sonifying: Ganymede plays C3, Europa plays C4, Io plays C5 -- " <>
      "a two-octave chord locked in place by gravity"];
    SonifyGalilean[model, cfg, outWAV];
    Print[""];

    STEMHeading["Done"];
    STEMSay[
      "Galilean resonance complete. " <> ToString[model["nPeriods"]] <>
      " Ganymede periods (" <> ToString[model["nIoEvents"]] <> " Io events, " <>
      ToString[model["nEuEvents"]] <> " Europa events, " <> ToString[model["nGaEvents"]] <>
      " Ganymede events). Pitches: Ganymede C3 = " <> ToString[$PitchGanymedeHz] <>
      " Hz, Europa C4 = " <> ToString[$PitchEuropaHz] <> " Hz, Io C5 = " <> ToString[$PitchIoHz] <>
      " Hz -- ratio 1:2:4. Play audio: " <> STEMPlayCmd[outWAV]
    ],


  (* ══════════════════════════════════════════════════════
     KIRKWOOD MODE
     ══════════════════════════════════════════════════════ *)
  mode === "kirkwood",

    STEMSection["Asteroid Belt: Kirkwood Gaps"];
    Print[""];

    Print["[1/4] Computing asteroid density vs semi-major axis..."];
    model = KirkwoodModel[cfg];
    Print[""];

    Print["[2/4] Exporting data table..."];
    ExportKirkwoodCSV[model, outCSV];
    Print[""];

    Print["[3/4] Rendering belt-density sweep animation..."];
    STEMSay["Rendering the asteroid belt density sweep"];
    {nFrames, gifFps} = AnimateKirkwood[model, outGIF, ChordSweepMainDurationSec[model, cfg]];
    STEMDescribeGIF[outGIF, nFrames, gifFps];
    Print[""];

    Print["[4/4] Sonifying: chord, then sweep with gap silences..."];
    STEMSay["Sonifying the asteroid belt: chord, then a sweep with the Kirkwood gaps audible as silences"];
    SonifyKirkwood[model, cfg, outWAV];
    Print[""];

    STEMHeading["Done"];
    STEMSay[
      "Kirkwood gap sonification complete. Five resonance gaps: " <>
      StringRiffle[model["resonances"][[All, "label"]], ", "] <>
      ". Play audio: " <> STEMPlayCmd[outWAV]
    ],


  (* ══════════════════════════════════════════════════════
     SATURN MODE
     ══════════════════════════════════════════════════════ *)
  mode === "saturn",

    STEMSection["Saturn's Rings: the Cassini Division"];
    Print[""];

    Print["[1/4] Computing ring density vs orbital radius..."];
    model = SaturnModel[cfg];
    Print[""];

    Print["[2/4] Exporting data table..."];
    ExportSaturnCSV[model, cfg, outCSV];
    Print[""];

    Print["[3/4] Rendering ring-density sweep animation..."];
    STEMSay["Rendering the Saturn ring density sweep"];
    {nFrames, gifFps} = AnimateSaturn[model, outGIF, ChordSweepMainDurationSec[model, cfg]];
    STEMDescribeGIF[outGIF, nFrames, gifFps];
    Print[""];

    Print["[4/4] Sonifying: chord, then sweep with the Cassini Division as a gap..."];
    STEMSay["Sonifying Saturn's rings: chord, then a sweep with the Cassini Division audible as a gap"];
    SonifySaturn[model, cfg, outWAV];
    Print[""];

    STEMHeading["Done"];
    STEMSay[
      "Saturn ring sonification complete. Cassini Division at " <>
      ToString[NumberForm[$SaturnCassiniCenterKm, {7, 1}]] <>
      " km, a 2:1 resonance with Mimas. Play audio: " <> STEMPlayCmd[outWAV]
    ],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" -- expected \"galilean\", \"kirkwood\", or \"saturn\"."];
    Exit[1]
]

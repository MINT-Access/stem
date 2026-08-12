#!/usr/bin/env wolframscript

(* ========================================================
   Magnetic — Entry Point

   Charged particle motion in magnetic and electric fields:
   cyclotron orbits, E x B drift, magnetic mirror trapping, and
   multi-particle cyclotron chords.

   Usage:
     wolframscript -file main.wl                                          # cyclotron, default
     wolframscript -file main.wl -- --simulation.mode=drift                # E x B drift cycloid
     wolframscript -file main.wl -- --simulation.mode=mirror               # magnetic mirror
     wolframscript -file main.wl -- --simulation.mode=multi                # proton+alpha+electron
     wolframscript -file main.wl -- --simulation.magnetic.v_parallel=0.5   # helix orbit
     wolframscript -file main.wl -- --simulation.magnetic.E_x=1.0          # faster drift
     wolframscript -file main.wl -- --simulation.magnetic.alpha=1.0        # stronger mirror
     wolframscript -file main.wl -- --simulation.magnetic.B_z=2.0          # stronger field
     wolframscript -file main.wl -- --simulation.magnetic.base_freq_hz=220 # higher pitch base
     wolframscript -file main.wl -- --config-dump

   Modes:
     cyclotron (default) -- uniform B, circular/helical orbit at omega_c
     drift               -- uniform B and E, E x B cycloidal drift
     mirror               -- non-uniform B(z), magnetic bottle trapping
     multi                 -- proton/alpha/electron cyclotron chord

   Outputs (magnetic/output/):
     <mode>_audio.wav / <mode>.gif / <mode>_data.csv
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

cfg  = LoadConfig["magnetic", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "cyclotron"];

(* ── Mirror-mode default resolution ─────────────────────────────────
   config.json's v_perp/v_parallel (1.0/0.0) are shared across all
   modes to match the single JSON block in the spec exactly, but they
   describe cyclotron/drift's "pure circular orbit" default -- mirror
   mode's own prose wants v_perp=1.5, v_parallel=0.8 (a trapped-particle
   pitch angle) as ITS default. Since both would otherwise come from
   the same merged cfg with no way to tell "config.json default" apart
   from "explicit CLI override," apply mirror's own defaults here,
   but only for keys the user did not explicitly pass on the CLI. *)
If[mode === "mirror",
  If[!AnyTrue[$cliArgs, StringStartsQ[#, "--simulation.magnetic.v_perp="] &],
    cfg = DeepMerge[cfg, <|"simulation" -> <|"magnetic" -> <|"v_perp" -> 1.5|>|>|>]];
  If[!AnyTrue[$cliArgs, StringStartsQ[#, "--simulation.magnetic.v_parallel="] &],
    cfg = DeepMerge[cfg, <|"simulation" -> <|"magnetic" -> <|"v_parallel" -> 0.8|>|>|>]];
];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

outWAV = FileNameJoin[{$outDir, mode <> "_audio.wav"}];
outGIF = FileNameJoin[{$outDir, mode <> ".gif"}];
outCSV = FileNameJoin[{$outDir, mode <> "_data.csv"}];

Which[

  (* ══════════════════════════════════════════════════════
     CYCLOTRON MODE
     ══════════════════════════════════════════════════════ *)
  mode === "cyclotron",

    STEMHeading["Charged Particle Dynamics: Cyclotron Orbit"];
    Print[""];

    STEMSay["Integrating cyclotron orbit"];
    Print["[1/4] Integrating equations of motion..."];
    model = IntegrateCyclotron[cfg];

    Print["[2/4] Exporting data table..."];
    ExportCyclotronCSV[model, outCSV];
    Print[""];

    (* Audio synthesised BEFORE the animation: the GIF's frame rate/count
       are solved FROM the WAV's actual total duration (intro + pause +
       tone), so sonify must run first -- see AGENTS.md, "GIF/WAV
       duration sync". *)
    Print["[3/4] Sonifying..."];
    STEMSay["Sonifying cyclotron orbit: pitch is the cyclotron frequency, pan tracks x-position"];
    wavDuration = SonifyCyclotron[model, cfg, outWAV];
    Print[""];

    Print["[4/4] Rendering animation..."];
    STEMSay["Rendering cyclotron orbit animation"];
    {nFrames, gifFps} = AnimateCyclotron[model, outGIF, wavDuration];
    STEMDescribeGIF[outGIF, nFrames, gifFps];
    Print[""];

    STEMHeading["Done"];
    STEMSay["Cyclotron orbit complete. Cyclotron frequency " <>
      ToString[NumberForm[model["omegaC"], {5, 3}]] <> " radians per unit time. Period " <>
      ToString[NumberForm[model["Tc"], {5, 3}]] <> " time units. Play audio: " <>
      STEMPlayCmd[outWAV]],


  (* ══════════════════════════════════════════════════════
     DRIFT MODE
     ══════════════════════════════════════════════════════ *)
  mode === "drift",

    STEMHeading["Charged Particle Dynamics: E x B Drift"];
    Print[""];

    STEMSay["Integrating E cross B drift trajectory"];
    Print["[1/4] Integrating equations of motion..."];
    model = IntegrateDrift[cfg];

    Print["[2/4] Exporting data table..."];
    ExportDriftCSV[model, outCSV];
    Print[""];

    (* Audio synthesised BEFORE the animation -- see the cyclotron mode
       block above for why the numbered steps are swapped. *)
    Print["[3/4] Sonifying..."];
    STEMSay["Sonifying E cross B drift: pitch tracks x-position, pan tracks the drift in y"];
    wavDuration = SonifyDrift[model, cfg, outWAV];
    Print[""];

    Print["[4/4] Rendering animation..."];
    STEMSay["Rendering E cross B drift animation"];
    {nFrames, gifFps} = AnimateDrift[model, outGIF, wavDuration];
    STEMDescribeGIF[outGIF, nFrames, gifFps];
    Print[""];

    STEMHeading["Done"];
    STEMSay["E cross B drift complete. Drift velocity " <>
      ToString[NumberForm[model["vDrift"], {5, 3}]] <> " length units per time unit. Play audio: " <>
      STEMPlayCmd[outWAV]],


  (* ══════════════════════════════════════════════════════
     MIRROR MODE
     ══════════════════════════════════════════════════════ *)
  mode === "mirror",

    STEMHeading["Charged Particle Dynamics: Magnetic Mirror"];
    Print[""];

    STEMSay["Integrating magnetic mirror trajectory"];
    Print["[1/4] Integrating equations of motion..."];
    model = IntegrateMirror[cfg];

    Print["[2/4] Exporting data table..."];
    ExportMirrorCSV[model, outCSV];
    Print[""];

    (* Audio synthesised BEFORE the animation -- see the cyclotron mode
       block above for why the numbered steps are swapped. *)
    Print["[3/4] Sonifying..."];
    STEMSay["Sonifying magnetic mirror: pitch tracks distance from the midplane, " <>
      "accents mark each reflection"];
    wavDuration = SonifyMirror[model, cfg, outWAV];
    Print[""];

    Print["[4/4] Rendering animation..."];
    STEMSay["Rendering magnetic mirror animation"];
    {nFrames, gifFps} = AnimateMirror[model, outGIF, wavDuration];
    STEMDescribeGIF[outGIF, nFrames, gifFps];
    Print[""];

    STEMHeading["Done"];
    STEMSay["Magnetic mirror complete. Particle " <>
      If[model["analyticTrapped"], "is trapped", "escapes"] <> ", " <>
      ToString[model["nBounces"]] <> " reflections observed. Play audio: " <>
      STEMPlayCmd[outWAV]],


  (* ══════════════════════════════════════════════════════
     MULTI MODE
     ══════════════════════════════════════════════════════ *)
  mode === "multi",

    STEMHeading["Charged Particle Dynamics: Multi-Particle Chord"];
    Print[""];

    STEMSay["Computing proton, alpha particle, and electron cyclotron orbits"];
    Print["[1/4] Computing closed-form cyclotron orbits..."];
    model = BuildMultiModel[cfg];

    Print["[2/4] Exporting data table..."];
    ExportMultiCSV[model, outCSV];
    Print[""];

    (* Audio synthesised BEFORE the animation -- see the cyclotron mode
       block above for why the numbered steps are swapped. *)
    Print["[3/4] Sonifying..."];
    STEMSay["Sonifying the cyclotron chord: proton left, alpha centre, electron right"];
    wavDuration = SonifyMulti[model, cfg, outWAV];
    Print[""];

    Print["[4/4] Rendering animation..."];
    STEMSay["Rendering multi-particle animation"];
    {nFrames, gifFps} = AnimateMulti[model, outGIF, wavDuration];
    STEMDescribeGIF[outGIF, nFrames, gifFps];
    Print[""];

    STEMHeading["Done"];
    STEMSay["Multi-particle chord complete. Proton " <>
      ToString[NumberForm[model["fProton"], {5, 1}]] <> " hertz, alpha " <>
      ToString[NumberForm[model["fAlpha"], {5, 1}]] <> " hertz, electron scaled to " <>
      ToString[NumberForm[model["fElectronScaled"], {5, 1}]] <> " hertz. Play audio: " <>
      STEMPlayCmd[outWAV]],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"cyclotron\", \"drift\", \"mirror\", or \"multi\"."];
    Exit[1]
]

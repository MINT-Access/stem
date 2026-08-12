#!/usr/bin/env wolframscript

(* ========================================================
   Scattering — Entry Point

   Rutherford alpha-particle scattering: the 1909-1911 Geiger-Marsden
   experiment that discovered the atomic nucleus. Simulates a single
   hyperbolic trajectory, a realistic beam distribution, and a
   binaural Thomson-vs-Rutherford model comparison.

   Usage:
     wolframscript -file main.wl                                          # scatter, b=1.0 (90 deg)
     wolframscript -file main.wl -- --simulation.scattering.preset=headon
     wolframscript -file main.wl -- --simulation.scattering.preset=backscatter
     wolframscript -file main.wl -- --simulation.scattering.preset=glancing
     wolframscript -file main.wl -- --simulation.scattering.b=2.0          # custom b
     wolframscript -file main.wl -- --simulation.mode=distribution         # beam of 200 particles
     wolframscript -file main.wl -- --simulation.mode=discovery            # Thomson vs Rutherford
     wolframscript -file main.wl -- --simulation.scattering.n_particles=500
     wolframscript -file main.wl -- --simulation.scattering.b_max=12.0
     wolframscript -file main.wl -- --config-dump

   Modes:
     scatter (default) -- single trajectory, NDSolve in polar coordinates
     distribution        -- beam of particles, realistic impact-parameter sampling
     discovery            -- Thomson vs Rutherford, binaural comparison

   Outputs (scattering/output/):
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

cfg  = LoadConfig["scattering", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "scatter"];

(* ── Preset resolution (scatter mode only) ──────────────────────── *)
$presets = <|
  "glancing"    -> 5.0,
  "moderate"    -> 1.0,
  "headon"      -> 0.1,
  "backscatter" -> 0.0
|>;

Module[{preset},
  preset = GetCfg[cfg, {"simulation", "scattering", "preset"}, ""];
  If[StringQ[preset] && preset =!= "" && KeyExistsQ[$presets, preset],
    cfg = DeepMerge[cfg, <|"simulation" -> <|"scattering" -> <|"b" -> $presets[preset]|>|>|>];
    Print["  Preset: ", preset, "  b = ", $presets[preset]]
  ]
];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

outWAV = FileNameJoin[{$outDir, mode <> "_audio.wav"}];
outGIF = FileNameJoin[{$outDir, mode <> ".gif"}];
outCSV = FileNameJoin[{$outDir, mode <> "_data.csv"}];

STEMHeading["Rutherford Alpha-Particle Scattering"];
Print[""];
Print["-- Correctness check 1 (formula, all modes) --"];
RutherfordFormulaCheck[];
Print[""];

Which[

  (* ══════════════════════════════════════════════════════
     SCATTER MODE
     ══════════════════════════════════════════════════════ *)
  mode === "scatter",

    STEMSection["Single Trajectory"];
    Print[""];

    STEMSay["Integrating the alpha particle trajectory"];
    Print["[1/4] Integrating equations of motion (polar coordinates, NDSolve)..."];
    model = ScatterModel[cfg];

    Print["[2/4] Exporting data table..."];
    ExportScatterCSV[model, outCSV];
    Print[""];

    Print["[3/4] Rendering animation..."];
    STEMSay["Rendering the hyperbolic trajectory animation"];
    {nFrames, gifFps} = AnimateScatter[model, outGIF, ScatterMainDuration[model]];
    STEMDescribeGIF[outGIF, nFrames, gifFps];
    Print[""];

    Print["[4/4] Sonifying..."];
    STEMSay["Sonifying: pitch is one over r, volume is speed, " <>
      "accent tone marks closest approach"];
    SonifyScatter[model, cfg, outWAV];
    Print[""];

    STEMHeading["Done"];
    STEMSay["Scattering complete. Impact parameter " <>
      ToString[NumberForm[model["b"], {5, 3}]] <> ". Scattering angle " <>
      ToString[NumberForm[model["thetaAnalyticDeg"], {5, 1}]] <> " degrees. Play audio: " <>
      STEMPlayCmd[outWAV]],


  (* ══════════════════════════════════════════════════════
     DISTRIBUTION MODE
     ══════════════════════════════════════════════════════ *)
  mode === "distribution",

    STEMSection["Beam Distribution"];
    Print[""];

    STEMSay["Sampling a beam of alpha particles with random impact parameters"];
    Print["[1/4] Sampling impact parameters and computing scattering angles..."];
    model = DistributionModel[cfg];

    Print["[2/4] Exporting data table..."];
    ExportDistributionCSV[model, outCSV];
    Print[""];

    Print["[3/4] Rendering animation..."];
    STEMSay["Rendering the impact parameter versus scattering angle animation"];
    {nFrames, gifFps} = AnimateDistribution[model, outGIF, DistributionMainDuration[model, cfg]];
    STEMDescribeGIF[outGIF, nFrames, gifFps];
    Print[""];

    Print["[4/4] Sonifying..."];
    STEMSay["Sonifying the beam: a dense quiet stream of small-angle events, " <>
      "punctuated by rare loud backscatter accents"];
    SonifyDistribution[model, cfg, outWAV];
    Print[""];

    STEMHeading["Done"];
    STEMSay[ToString[model["n"]] <> " particles simulated. " <>
      ToString[model["nBackscatter"]] <> " backscattered beyond 90 degrees. Play audio: " <>
      STEMPlayCmd[outWAV]],


  (* ══════════════════════════════════════════════════════
     DISCOVERY MODE
     ══════════════════════════════════════════════════════ *)
  mode === "discovery",

    STEMSection["Geiger-Marsden Discovery: Thomson vs Rutherford"];
    Print[""];

    STEMSay["Building the Thomson and Rutherford model predictions"];
    Print["[1/4] Sampling both models' angle distributions (same random seed)..."];
    model = DiscoveryModel[cfg];

    Print["[2/4] Exporting data table..."];
    ExportDiscoveryCSV[model, outCSV];
    Print[""];

    Print["[3/4] Rendering animation..."];
    STEMSay["Rendering the side-by-side angular distribution histograms"];
    {nFrames, gifFps} = AnimateDiscovery[model, outGIF, DiscoveryMainDuration[cfg]];
    STEMDescribeGIF[outGIF, nFrames, gifFps];
    Print[""];

    Print["[4/4] Sonifying (binaural: Thomson left, Rutherford right)..."];
    STEMSay["Sonifying: Thomson model left channel, Rutherford model right channel"];
    SonifyDiscovery[model, cfg, outWAV];
    Print[""];

    STEMHeading["Done"];
    STEMSay["Discovery comparison complete. Thomson: " <>
      ToString[model["nBackThomson"]] <> " backscatter events. Rutherford: " <>
      ToString[model["nBackRutherford"]] <> " backscatter events. Play audio: " <>
      STEMPlayCmd[outWAV]],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"scatter\", \"distribution\", or \"discovery\"."];
    Exit[1]
]
